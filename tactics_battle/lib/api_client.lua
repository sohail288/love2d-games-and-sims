local dkjson = require("lib.dkjson")
local HttpClient = require("lib.http_client")

local config = require("config")

local ApiClient = {}
ApiClient.__index = ApiClient

local API_URL = "https://api.openai.com/v1/chat/completions"
local API_KEY = config.api_key

local function build_error(message)
    return { error = { message = message } }
end

local function normalize_failure(message, detail)
    local parts = { message }
    if detail then
        parts[#parts + 1] = tostring(detail)
    end
    return build_error(table.concat(parts, ": "))
end

local function decode_response_body(body)
    local success, response_json = pcall(dkjson.decode, body)
    if success and response_json then
        return response_json
    end

    local decode_error = response_json or "Unknown decode error"
    return build_error("Failed to decode JSON response: " .. tostring(decode_error))
end

local function transport_requires_callback(http_client)
    if not http_client then
        return false
    end

    if type(http_client.uses_fetch) ~= "function" then
        return false
    end

    local ok, result = pcall(http_client.uses_fetch, http_client)
    if not ok then
        return false
    end

    return result
end

function ApiClient.new(http_client)
    local self = setmetatable({}, ApiClient)
    self.http = http_client or HttpClient.new()
    return self
end

function ApiClient:update(dt)
    if self.http and type(self.http.update) == "function" then
        self.http:update(dt)
    end
end

function ApiClient:_finalize_response(response)
    if not response or type(response.status) == "nil" then
        return build_error("Invalid HTTP response received")
    end

    if response.status ~= 200 then
        local response_body = tostring(response.body or "")
        local message = string.format("API request failed with code %s", tostring(response.status))
        if response_body ~= "" then
            message = message .. ": " .. response_body
        end
        return build_error(message)
    end

    return decode_response_body(response.body)
end

function ApiClient:generate_text(prompt, schema, step_name, callback)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. API_KEY
    }

    local body = {
        model = "got-5-mini",
        messages = {
            { role = "system", content = "You are a helpful assistant designed to output JSON." },
            { role = "user", content = prompt }
        },
        response_format = {
            type = "json_schema",
            json_schema = {
                name = step_name,
                strict = true,
                schema = schema
            }
        }
    }

    local body_json = dkjson.encode(body)
    local options = {
        method = "POST",
        headers = headers,
        body = body_json,
        data = body_json
    }

    if not callback and transport_requires_callback(self.http) then
        error("generate_text requires a callback when using fetch")
    end

    if callback then
        self.http:fetch(API_URL, options, function(err, response)
            if err then
                callback(normalize_failure("HTTP request failed", err))
                return
            end

            callback(self:_finalize_response(response))
        end)
        return nil
    end

    local ok, response_or_error = self.http:fetch(API_URL, options)
    if not ok then
        return normalize_failure("HTTP request failed", response_or_error)
    end

    return self:_finalize_response(response_or_error)
end

return ApiClient
