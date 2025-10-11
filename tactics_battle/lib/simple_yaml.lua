-- simple_yaml.lua
-- A very simple Lua table to YAML encoder.

local SimpleYaml = {}

local function encode_value(value, indent_level)
    local indent = string.rep("  ", indent_level)
    if type(value) == "string" then
        if value:find("\n") then
            local indented_value = indent .. "  " .. value:gsub("\n", "\n" .. indent .. "  ")
            return "|\n" .. indented_value
        else
            return value
        end
    elseif type(value) == "table" then
        local lines = {}
        -- Check if it's an array-like table
        local is_array = #value > 0 and value[1] ~= nil
        for i = 1, #value do
            if value[i] == nil then
                is_array = false
                break
            end
        end

        if is_array then
            for _, item in ipairs(value) do
                table.insert(lines, "\n" .. indent .. "- " .. encode_value(item, indent_level + 1))
            end
        else -- It's a map-like table
            for key, val in pairs(value) do
                table.insert(lines, "\n" .. indent .. key .. ": " .. encode_value(val, indent_level + 1))
            end
        end
        return table.concat(lines)
    else
        return tostring(value)
    end
end

function SimpleYaml.encode(data, ordered_keys)
    local yaml_lines = {}
    for _, key in ipairs(ordered_keys) do
        local value = data[key]
        if value then
            table.insert(yaml_lines, key .. ": " .. encode_value(value, 1))
        end
    end
    return table.concat(yaml_lines, "\n")
end

return SimpleYaml
