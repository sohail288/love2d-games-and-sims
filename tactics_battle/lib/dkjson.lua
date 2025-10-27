-- dkjson.lua
--
-- A very simple JSON module for Lua.
--
-- Copyright (c) 2011-2023 David Kolf
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.


-- When using this module, LPEG is an optional dependency. When LPeg is
-- available, it will be used to speed up decoding.

-- History:
--   2.8: Fix handling of decoding errors when Lua is compiled with
--        LUA_NOCVTN2S.
--   2.7: Enable working with newer versions of LPeg where the "version"
--        field is no longer a function.
--        Fix error messages when an encoding error happens in an ordered
--        dictionary.
--   2.6: The decode function is no longer automatically replaced by the
--        version implemented using LPeg, but an LPeg-enabled copy of the
--        module has to be requested explicitly with the function use_lpeg.
--        This was changed to improve the predictability of the code and make
--        audits more reliable.
--        The LPeg-version of the decode function now reports unterminated
--        strings, arrays and objects with the position where they started
-- an        rather than where parsing failed which was usually at the end of the
--        input string. This was already the behavior of the
--        pure-Lua-implementation.
--        Fixed a bug where entries in a dictionary were not put in the
--        desired order when their value was the boolean false.
--   2.5: Changed the meaning of the `null` field. Setting `json.null` to a
--        non-nil value will use this value for the JSON `null` literal during
--        decoding. The old `json.null` value (`light userdata`) is now
--        available as `json.null_LUD`.
--        When decoding JSON, `null` is now `nil` by default. This makes it
--        possible to use `pairs` to iterate over all non-null values of a
--        decoded object.
--        Fixed a bug when using LPeg where `decode` would not produce an
--        error on some invalid input.
--   2.4: Added `decode_file(filename, [options])` as a convenience function.
--        It is recommended for files with possibly untrusted content.
--        Changed the maximum nesting depth from 1000 to 2000 for `decode`.
--        Changed the `depth` parameter in `decode` to `maxdepth`.
--   2.3: Added `ipairs` support for ordered dictionaries.
--   2.2: Fixed decoding of empty arrays and objects when using LPeg.
--        They could be decoded as object and array respectively.
--   2.1: Use `error()` to report errors in `encode()`. `pcall()` can
--        be used to catch these errors. This can be more convenient than
--        passing an error handler.
--   2.0: Added options table for `decode`.
--        The `ordered` option can be used to decode objects as ordered
--        dictionaries. `__pairs` and `__ipairs` metamethods are available.
--   1.4: Using `__tostring` to encode values is now disabled by default for
--        security reasons. It can be enabled by passing `true` as the fifth
--        parameter to `encode`.
--   1.3: Speed improvements and reduction of memory usage.
--   1.2: Added `pairs` and `ipairs` to preserve the order of array items.
--        (Thanks to Norman Ramsey)
--   1.1: Initial release.

local json = { version = "2.8" }

-- Character code of the forward solidus.
local FWD_SOLIDUS = 47

-- Marker for JSON null
json.null_LUD = newproxy()
json.null = nil

-- Forward declarations
local encode_value, encode_string, encode_array, encode_object, encode_error
local decode_value, decode_whitespace

-- Simple string buffer
-- This is a bit faster than string concatenation.
local buffer = {}
local buffer_pos

local function buffer_add(s)
  buffer_pos = buffer_pos + 1
  buffer[buffer_pos] = s
end

local function buffer_dump()
  local s = table.concat(buffer, "", 1, buffer_pos)
  -- "clear" buffer
  for i=buffer_pos, 1, -1 do
    buffer[i] = nil
  end
  return s
end


-- UTF-8 processing
-- See http://www.lua.org/pil/24.1.html
--
-- Some speed improvements by Justin Bradford (Aspect)
-- http://justin.aspect.net.nz/code/json-and-utf8-in-lua

local utf8_char_pattern = "[%z\x01-\x7F\xC2-\xF4][\x80-\xBF]*"
-- Per step, this function consumes one UTF-8 character.
-- It returns the code point and the number of bytes of the character.
local function utf8_next(s, pos)
  local c = s:byte(pos)

  if not c then
    return
  end

  local c2, c3, c4

  if c >= 0 and c <= 0x7f then -- 0xxxxxxx
    return c, 1
  elseif c >= 0xc2 and c <= 0xdf then -- 110xxxxx 10xxxxxx
    c2 = s:byte(pos + 1)
    if c2 and c2 >= 0x80 and c2 <= 0xbf then
      return (c - 0xc0) * 0x40 + (c2 - 0x80), 2
    end
  elseif c >= 0xe0 and c <= 0xef then -- 1110xxxx 10xxxxxx 10xxxxxx
    c2 = s:byte(pos + 1)
    c3 = s:byte(pos + 2)
    if c2 and c2 >= 0x80 and c2 <= 0xbf and c3 and c3 >= 0x80 and c3 <= 0xbf then
      return (c - 0xe0) * 0x1000 + (c2 - 0x80) * 0x40 + (c3 - 0x80), 3
    end
  elseif c >= 0xf0 and c <= 0xf4 then -- 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    c2 = s:byte(pos + 1)
    c3 = s:byte(pos + 2)
    c4 = s:byte(pos + 3)
    if c2 and c2 >= 0x80 and c2 <= 0xbf and c3 and c3 >= 0x80 and c3 <= 0xbf and
       c4 and c4 >= 0x80 and c4 <= 0xbf then
      return (c - 0xf0) * 0x40000 + (c2 - 0x80) * 0x1000 +
             (c3 - 0x80) * 0x40 + (c4 - 0x80), 4
    end
  end
end

-- Return the UTF-8 representation of a code point.
local function utf8_char(codepoint)
  local s
  if codepoint < 0x80 then
    s = string.char(codepoint)
  elseif codepoint < 0x800 then
    s = string.char(0xc0 + math.floor(codepoint / 0x40),
                    0x80 + (codepoint % 0x40))
  elseif codepoint < 0x10000 then
    s = string.char(0xe0 + math.floor(codepoint / 0x1000),
                    0x80 + math.floor(codepoint % 0x1000 / 0x40),
                    0x80 + (codepoint % 0x40))
  elseif codepoint < 0x200000 then
    s = string.char(0xf0 + math.floor(codepoint / 0x40000),
                    0x80 + math.floor(codepoint % 0x40000 / 0x1000),
                    0x80 + math.floor(codepoint % 0x1000 / 0x40),
                    0x80 + (codepoint % 0x40))
  else
    -- Codepoints this high are invalid.
    return ""
  end
  return s
end


-- The table `escape_map` contains the JSON escape sequences.
local escape_map = {
  ["\""] = "\\\"", ["\\"] = "\\\\", ["/"] = "\\/", ["\b"] = "\\b",
  ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"
}

-- The table `escape_char_map` contains the reverse escape sequences.
local escape_char_map = {}
for k,v in pairs(escape_map) do
  escape_char_map[v:sub(2,2)] = k
end


local function is_vis(byte)
  -- visible ASCII characters
  if byte >= 32 and byte <= 126 then
    return true
  else
    return false
  end
end

-- Return a string that can be used for error messages.
local function str_or_nil(s)
  if s then
    return s
  else
    return "(nil)"
  end
end

-- JSON backslash escape sequences and strings.
local function parse_string(s, pos)
  local has_escapes = false
  local i = pos
  local last_i
  while true do
    last_i = i
    i = s:find("[\"\\]", i)
    if not i then
      break
    end
    -- Also accept unterminated strings.
    if s:byte(i) == 34 then -- "
      -- The string ends here.
      local substr = s:sub(pos, i - 1)
      if has_escapes then
        -- process escape sequences
        substr = substr:gsub("\\(.)", escape_char_map)
        -- `gsub` does not support `\uXXXX` sequences, so they are handled
        -- separately.
        substr = substr:gsub("\\u([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])",
          function(hex)
            return utf8_char(tonumber(hex, 16))
          end)
      end
      return substr, i + 1
    else
      -- It is a backslash.
      -- Check the next character.
      local next_char = s:sub(i + 1, i + 1)
      if not next_char:match("[bfnrt/\"\\u]") then
        return nil, string.format("invalid escape sequence '\\%s' at pos %s",
                                  str_or_nil(next_char), i)
      end

      local advance = 1
      if next_char == 'u' then
        -- Test for `\uXXXX` sequence.
        if not s:sub(i + 2, i + 5):match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
          return nil, string.format("invalid hex code at pos %s", i)
        else
          advance = 5
        end
      end

      i = i + advance + 1
      has_escapes = true
    end
  end
  return nil, string.format("unterminated string starting at pos %s", pos)
end

-- JSON numbers.
local function parse_number(s, pos)
  -- Support for hex numbers is disabled, because the JSON spec does not
  -- allow them.
  local match_end, match_start
  match_start, match_end = s:find("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
  if match_start == pos then
    local num_str = s:sub(match_start, match_end)
    local num = tonumber(num_str)
    if num then
      return num, match_end + 1
    elseif type(LUA_VERSION_NUM) == 'number' and LUA_VERSION_NUM < 503 and
           num_str:find('^0[xX]') then
      -- In Lua 5.2 and below, `tonumber` might not support hexadecimal
      -- numbers. It is therefore necessary to test for this case.
      -- Lua 5.1 seems to support hexadecimal numbers, but there is no
      -- `LUA_VERSION_NUM`, so this test should catch all relevant versions.
      return nil, "hex numbers not supported"
    elseif type(LUA_VERSION_NUM) == 'number' and LUA_VERSION_NUM >= 503 and
           (num_str:match("e") or num_str:match("E")) and
           string.format("%.16g", 0) ~= "0.0000000000000000" then
      -- The number contains an exponent, but the conversion from number to
      -- string might be broken.
      -- See http://lua-users.org/lists/lua-l/2015-01/msg00332.html
      -- This code might not work when this bug is resolved differently,
      -- because the detection of this bug depends on the behavior of
      -- `string.format()`.
      return nil, "cannot convert number with exponent"
    end
  end
end

-- JSON keywords.
local keywords = { ["true"] = true, ["false"] = false, ["null"] = json.null }
local function parse_keyword(s, pos)
  for keyword, value in pairs(keywords) do
    if s:sub(pos, pos + #keyword - 1) == keyword then
      return value, pos + #keyword
    end
  end
end


function encode_error(what, pos, value)
  local msg
  if pos then
    msg = string.format("Cannot encode %s at key/index %s: %s",
                        tostring(value), tostring(pos), what)
  else
    msg = string.format("Cannot encode %s: %s", tostring(value), what)
  end
  error(msg, 2)
end

function decode_error(what, pos, s)
  local line, row = 1, 1
  -- calculate line and row
  local last_nl = s:reverse():find("\n", #s - pos + 1)
  if last_nl then
    line = select(2, s:gsub("\n", "")) - select(2, s:sub(pos):gsub("\n", "")) + 1
    row = pos - last_nl + 1
  else
    row = pos
  end

  return nil, string.format("%s at line %s, row %s", what, line, row)
end


function encode_string(s)
  buffer_add('"')
  -- A pure-Lua string pattern is used to search for characters that
  -- need to be escaped.
  -- This is faster than iterating over the string character by character.
  local last_pos = 1
  while true do
    -- The pattern looks for the next control character or character that needs
    -- to be escaped.
    -- The forward solidus is also escaped even when it is not strictly
    -- required, because it is good practice and some JSON parsers might fail
    -- when it is not escaped.
    local next_pos, end_pos = s:find("[\"\\/\b\f\n\r\t]", last_pos)
    if next_pos then
      buffer_add(s:sub(last_pos, next_pos - 1))
      buffer_add(escape_map[s:sub(next_pos, end_pos)])
      last_pos = end_pos + 1
    else
      -- The rest of the string is scanned for multi-byte characters.
      -- These characters are not escaped.
      -- The string pattern `utf8_char_pattern` matches all valid characters.
      -- Invalid bytes are replaced by the replacement character `U+FFFD`.
      local sub = s:sub(last_pos)
      local last_utf8_pos = 1
      while true do
        local next_utf8_pos = sub:find(utf8_char_pattern, last_utf8_pos)
        if next_utf8_pos then
          if next_utf8_pos > last_utf8_pos then
            -- There are invalid bytes between the characters.
            for i=last_utf8_pos, next_utf8_pos - 1 do
              buffer_add("\\u00")
              buffer_add(string.format("%02x", sub:byte(i)))
            end
          end
          local char = sub:match(utf8_char_pattern, last_utf8_pos)
          local byte = char:byte()
          if is_vis(byte) and byte ~= FWD_SOLIDUS then
            buffer_add(char)
          else
            local codepoint, char_len = utf8_next(char, 1)
            if char_len and codepoint and codepoint <= 0xffff then
              buffer_add(string.format("\\u%04x", codepoint))
            else
              -- Characters outside the BMP are replaced by the replacement
              -- character.
              buffer_add(utf8_char(0xfffd))
            end
          end
          last_utf8_pos = next_utf8_pos + #char
        else
          -- all remaining bytes are invalid
          for i=last_utf8_pos, #sub do
            buffer_add("\\u00")
            buffer_add(string.format("%02x", sub:byte(i)))
          end
          break
        end
      end
      break
    end
  end
  buffer_add('"')
end

function encode_array(arr, state)
  buffer_add("[")
  local sep = false
  for i, val in ipairs(arr) do
    if sep then
      buffer_add(",")
    end
    encode_value(val, state, i)
    sep = true
  end
  buffer_add("]")
end

-- Return an iterator for a table that respects the `__pairs` metamethod.
local function get_pairs(t)
  if getmetatable(t) and getmetatable(t).__pairs then
    return getmetatable(t).__pairs(t)
  else
    return pairs(t)
  end
end

function encode_object(obj, state)
  buffer_add("{")
  local sep = false
  for key, val in get_pairs(obj) do
    if sep then
      buffer_add(",")
    end
    if type(key) ~= "string" then
      encode_error("object key must be a string", nil, key)
    end
    encode_string(key)
    buffer_add(":")
    encode_value(val, state, key)
    sep = true
  end
  buffer_add("}")
end

-- Test if a table is an array.
-- This test is not foolproof, but it should be sufficient for most cases.
local function is_array(t)
  local val, max, has_hole = nil, 0, false
  if #t > 0 then
    -- has_hole will be true when there are holes in the table
    -- (e.g. `{[1] = 1, [3] = 3}`).
    for i=1, #t do
      if t[i] == nil then
        has_hole = true
        break
      end
    end
  end
  if not has_hole then
    -- check for other keys
    for k,v in pairs(t) do
      if type(k) == "number" then
        if k > max then
          max = k
        end
      else
        -- not an array
        return false
      end
    end
    -- It is an array if the largest key is equal to the number of items.
    return max == #t, true
  else
    -- Holes were found, so it's not an array.
    return false
  end
end


function encode_value(val, state, pos)
  local val_type = type(val)
  if val_type == "string" then
    encode_string(val)
  elseif val_type == "number" then
    if val ~= val then
      -- NaN (not a number)
      encode_error("not a number", pos, val)
    elseif val == 1/0 or val == -1/0 then
      -- infinity
      encode_error("infinity", pos, val)
    else
      buffer_add(string.format("%.16g", val))
    end
  elseif val_type == "boolean" then
    buffer_add(tostring(val))
  elseif val == json.null or val_type == "nil" then
    buffer_add("null")
  elseif val_type == "table" then
    -- prevent circular references
    if state[val] then
      encode_error("circular reference", pos, val)
    end
    state[val] = true

    if getmetatable(val) and getmetatable(val).__json then
      local mt = getmetatable(val)
      local fun_type = type(mt.__json)
      local res
      if fun_type == "function" then
        res = mt.__json(val)
      elseif fun_type == "string" then
        res = mt.__json
      end
      encode_value(res, state)
    elseif is_array(val) then
      encode_array(val, state)
    else
      encode_object(val, state)
    end

    state[val] = nil
  else
    -- try to use `tostring`
    if state.use_tostring then
      local suc, res = pcall(tostring, val)
      if suc and type(res) == "string" then
        encode_string(res)
      else
        encode_error("unsupported value", pos, val)
      end
    else
      encode_error("unsupported value", pos, val)
    end
  end
end


-- `s` is the string to be decoded, `pos` is the current position.
-- `dep` is the nesting depth.
function decode_value(s, pos, dep, options)
  pos = decode_whitespace(s, pos)

  local char_byte = s:byte(pos)

  if not char_byte then
    return nil, "empty string"
  end

  if char_byte == 34 then -- "
    return parse_string(s, pos + 1)
  elseif char_byte == 123 then -- {
    local obj, new_pos, key, val, err = {}, pos + 1, nil, nil
    if options.ordered then
      setmetatable(obj, options.ordered_meta)
    end
    while true do
      new_pos = decode_whitespace(s, new_pos)
      if s:byte(new_pos) == 125 then -- }
        return obj, new_pos + 1
      end
      key, new_pos, err = decode_value(s, new_pos, dep + 1, options)
      if err then
        return nil, err
      end
      if type(key) ~= "string" then
        return nil, decode_error("object key must be a string", new_pos, s)
      end
      new_pos = decode_whitespace(s, new_pos)
      if s:sub(new_pos, new_pos) ~= ":" then
        return nil, decode_error("expected ':'", new_pos, s)
      end
      new_pos = decode_whitespace(s, new_pos + 1)
      val, new_pos, err = decode_value(s, new_pos, dep + 1, options)
      if err then
        return nil, err
      end
      if options.ordered then
        table.insert(obj, { key, val })
      else
        obj[key] = val
      end
      new_pos = decode_whitespace(s, new_pos)
      local next_char = s:sub(new_pos, new_pos)
      if next_char == "," then
        new_pos = new_pos + 1
      elseif next_char ~= "}" then
        return nil, decode_error("expected '}' or ','", new_pos, s)
      end
    end
  elseif char_byte == 91 then -- [
    local arr, new_pos, val, err = {}, pos + 1
    while true do
      new_pos = decode_whitespace(s, new_pos)
      if s:byte(new_pos) == 93 then -- ]
        return arr, new_pos + 1
      end
      val, new_pos, err = decode_value(s, new_pos, dep + 1, options)
      if err then
        return nil, err
      end
      table.insert(arr, val)
      new_pos = decode_whitespace(s, new_pos)
      local next_char = s:sub(new_pos, new_pos)
      if next_char == "," then
        new_pos = new_pos + 1
      elseif next_char ~= "]" then
        return nil, decode_error("expected ']' or ','", new_pos, s)
      end
    end
  elseif (char_byte >= 48 and char_byte <= 57) or char_byte == 45 then -- 0-9, -
    return parse_number(s, pos)
  else
    return parse_keyword(s, pos)
  end
end

function decode_whitespace(s, pos)
  -- This function is a bit faster than `string:match` or `string:gsub`.
  while true do
    local byte = s:byte(pos)
    if byte and (byte == 32 or (byte >= 9 and byte <= 13)) then
      pos = pos + 1
    else
      return pos
    end
  end
end


--- Encode a Lua value to JSON.
--
-- Three additional parameters can be used to control the encoding process:
--
-- @param value The value to encode.
-- @param state (`table`, optional) is used to detect circular references.
--   When it is omitted, a new table will be created.
-- @param depth (`number`, optional) is the current nesting depth.
-- @param use_tostring (`boolean`, optional) allows the encoder to use `tostring`
--   to encode functions, userdata and threads. It is disabled by default for
--   security reasons. It can be useful for debugging.
-- @return The JSON string or (nil, error message).
function json.encode(value, state, depth, use_tostring)
  buffer_pos = 0
  if type(state) == "boolean" then
    use_tostring = state
    state = nil
  end
  encode_value(value, state or { use_tostring = use_tostring })
  return buffer_dump()
end


--- Decode a JSON string to a Lua value.
--
-- @param s The string to decode.
-- @param options (`table`, optional) can be used to control the decoding
-- process. The following options are available:
-- * `ordered` (`boolean`): When it is `true`, JSON objects are decoded as
--   ordered dictionaries. The default is `false`.
-- @return The Lua value or (nil, error message).
function json.decode(s, options)
  local pos, err = 1, nil
  if type(s) ~= "string" then
    return nil, "expected a string"
  end

  local maxdepth = (options and options.maxdepth) or 2000

  if options and options.ordered then
    -- Create the metatable for ordered dictionaries.
    options.ordered_meta = {
      __index = {},
      __pairs = function(t)
        local i = 0
        return function()
          i = i + 1
          if t[i] then
            return t[i][1], t[i][2]
          end
        end
      end,
      __ipairs = function(t)
        local i = 0
        return function()
          i = i + 1
          if t[i] then
            return i, t[i]
          end
        end
      end
    }
  end

  local suc, res
  suc, res, pos, err = pcall(decode_value, s, pos, maxdepth, options or {})
  if suc then
    if err then
      return decode_error(err, pos, s)
    else
      pos = decode_whitespace(s, pos)
      if pos > #s then
        return res
      else
        return decode_error("trailing garbage", pos, s)
      end
    end
  else
    return nil, res
  end
end

--- Decode a JSON file.
-- This function is recommended for files with possibly untrusted content.
--
-- @param filename
-- @param options (`table`, optional) see `decode`.
function json.decode_file(filename, options)
  local f, err = io.open(filename, "rb")
  if not f then
    return nil, err
  end
  local s = f:read("*a")
  f:close()
  return json.decode(s, options)
end

-- Check for LPeg
local lpeg_present, lpeg = pcall(require, "lpeg")
local lpeg_decode_version

if lpeg_present and ((type(lpeg.version) == "function" and lpeg.version()) or
                     (type(lpeg.version) == "string" and lpeg.version)) then

  local P, S, R, V, C, Ct, Cg, Cb, Cf, Cc =
    lpeg.P, lpeg.S, lpeg.R, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cb, lpeg.Cf,
    lpeg.Cc

  local match = lpeg.match

  -- JSON grammar
  local Space = S(" \t\r\n")^0
  local LeftBrace, RightBrace = P("{") * Space, P("}") * Space
  local LeftBracket, RightBracket = P("[") * Space, P("]") * Space
  local Comma = P(",") * Space
  local Colon = P(":") * Space
  local String
  local Object
  local Array
  local Value
  local Keyword
  local Number

  local function build_grammar()
    local Unescaped = R("\x20\x21", "\x23\x5B", "\x5D\xFF") -- without ", \
    local Escaped = P("\\") * (P('"') + P("\\") + P("/") + P("b") + P("f") +
                               P("n") + P("r") + P("t")) / escape_char_map
    local Hex = P("u") * R("09", "af", "AF")^4 /
      function(hex)
        return utf8_char(tonumber(hex, 16))
      end
    String = P('"') * C((Unescaped + Escaped + P("\\") * Hex)^0) * P('"') * Space

    local Exponent = S("eE") * S("+-")^-1 * R("09")^1
    Number = P("-")^-1 * (P("0") + R("19") * R("09")^0) *
             (P(".") * R("09")^1)^-1 * Exponent^-1 * Space
    Number = C(Number) / tonumber

    Keyword = C(P("true")) / function() return true end * Space +
              C(P("false")) / function() return false end * Space +
              C(P("null")) / function() return json.null end * Space

    local function decode_error_lpeg(subject, pos)
      local err_pos = Cb("err_pos")
      -- search for first non-whitespace character
      pos = match(Space * P(1), subject, pos) or #subject + 1

      local err_msg = "expected value"
      local p_val = V("String") + V("Number") + V("Keyword") +
                    V("Object") + V("Array")

      -- Find out what went wrong.
      if match(p_val, subject, pos) then
        local p_keywords = (P("true") + P("false") + P("null")) * -P(1)
        local p_num = Number * -P(1)
        if match(p_keywords, subject, pos) then
          err_msg = "invalid keyword"
        elseif match(P('"'), subject, pos) then
          -- unterminated string
          err_msg = string.format("unterminated string starting at pos %s", pos)
          local p_term_str = String * Space
          if not match(p_term_str, subject, pos) then
            -- Let's see what's wrong with the string.
            local p_esc = P('\\') * P(1)
            local p_hex = P('\\u') * R('09', 'af', 'AF')^4
            local p_inv_esc = Cf(p_esc * C(P(1)),
              function(subject, pos, esc_char)
                if not esc_char:match('[bfnrt/\"\\\\]') then
                  return pos
                end
              end) * err_pos
            local p_inv_hex = Cf(p_hex,
              function(subject, pos)
                -- check length of hex sequence
                if not subject:sub(pos, pos+3):match('^[0-9a-fA-F]^4$') then
                  return pos
                end
              end) * err_pos
            local p_str = P('"') * ((Unescaped + Escaped)^0 * (p_inv_esc + p_inv_hex) +
                                    (Unescaped + Escaped)^-1)
            local res, e_pos = match(p_str, subject, pos)
            if res then
              local inv_char = subject:sub(e_pos-1, e_pos-1)
              if inv_char == 'u' then
                err_msg = string.format("invalid hex code at pos %s", e_pos-2)
              else
                err_msg = string.format("invalid escape sequence '\\%s' at pos %s",
                                        inv_char, e_pos-2)
              end
              pos = e_pos
            end
          end
        elseif match(P('{'), subject, pos) then
          err_msg = string.format("unterminated object starting at pos %s", pos)
        elseif match(P('['), subject, pos) then
          err_msg = string.format("unterminated array starting at pos %s", pos)
        elseif match(p_num, subject, pos) then
          err_msg = "invalid number"
        end
      end
      return decode_error(err_msg, pos, subject)
    end

    local function ordered_object_decoder(subject, pos)
      local err_pos = Cb("err_pos")
      local function get_pair(s)
        local key, val = match(V("KeyVal"), s)
        return { key, val }
      end
      local p_keyval = Cg(String * Colon * V("Value"), get_pair)
      local Grammar = P {
        "Object",
        Object = LeftBrace * Ct((V("KeyVal") * (Comma * V("KeyVal"))^0)^-1) *
                 RightBrace,
        KeyVal = p_keyval,
        Value = String + Number + Keyword + V("Object") + V("Array")
      }
      local suc, res = match(Grammar, subject, pos)
      if suc then
        setmetatable(res, options.ordered_meta)
        return res, suc
      else
        return decode_error_lpeg(subject, pos)
      end
    end

    local function object_decoder(subject, pos)
      local Grammar = P {
        "Object",
        Object = Cc(setmetatable) * P({}) * Cc(options.object_meta or nil) *
                 LeftBrace *
                 Cf(Ct((V("Key") * V("Value"))^0),
                    function(s, p, t)
                      for i=1, #t, 2 do
                        rawset(t, t[i], t[i+1])
                        t[i] = nil
                      end
                      return p, t
                    end) * RightBrace,
        Key = String * Colon,
        Value = String + Number + Keyword + V("Object") + V("Array")
      }
      local suc, res = match(Grammar, subject, pos)
      if suc then
        return res, suc
      else
        return decode_error_lpeg(subject, pos)
      end
    end

    local Grammar = P {
      "Value",
      Object = Cf(P(1)^0, options.ordered and ordered_object_decoder or object_decoder),
      Array = LeftBracket * Ct((V("Value") * (Comma * V("Value"))^0)^-1) *
              RightBracket,
      Value = Space * (String + Number + Keyword + V("Object") + V("Array"))
    }
    return Grammar
  end

  local function decode_lpeg(s, options)
    local maxdepth = (options and options.maxdepth) or 2000
    if maxdepth < 1 then
      return nil, "invalid maxdepth"
    end
    if options and options.ordered then
      -- create metatable
      options.ordered_meta = {
        __index = {},
        __pairs = function(t)
          local i = 0
          return function()
            i = i + 1
            if t[i] then
              return t[i][1], t[i][2]
            end
          end
        end,
        __ipairs = function(t)
          local i = 0
          return function()
            i = i + 1
            if t[i] then
              return i, t[i]
            end
          end
        end
      }
    end

    -- The grammar must be rebuilt for every call, because the table `options`
    -- can be different.
    local Grammar = build_grammar()
    local suc, res = match(Grammar, s)
    if suc then
      local suc_ws, pos = match(Space, s, suc)
      if suc_ws and pos > #s then
        return res
      else
        return decode_error("trailing garbage", suc, s)
      end
    else
      return res
    end
  end

  lpeg_decode_version = json.version
  -- Return a copy of the module that uses LPeg for decoding.
  function json.use_lpeg()
    local json_lpeg = {}
    for k,v in pairs(json) do
      json_lpeg[k] = v
    end
    json_lpeg.decode = decode_lpeg
    return json_lpeg
  end
end


return json
