local dkjson = require("lib.dkjson")

local config = require("config")

local ApiClient = {}
ApiClient.__index = ApiClient

local API_URL = "https://api.openai.com/v1/chat/completions"
local API_KEY = config.api_key

local function load_https()
    local ok, https_module = pcall(require, "https")
    if ok and https_module and type(https_module.request) == "function" then
        return https_module
    end
    return nil
end

local function load_fetch()
    if love and type(love.fetch) == "table" then
        return love.fetch
    end

    local ok, fetch_module = pcall(require, "fetch")
    if ok and type(fetch_module) == "table" then
        if love and love.fetch == nil then
            love.fetch = fetch_module
        end
        return fetch_module
    end

    return nil
end

local function is_web_platform()
    if not love or not love.system or type(love.system.getOS) ~= "function" then
        return false
    end

    local ok, platform = pcall(love.system.getOS)
    if not ok then
        return false
    end

    return platform == "Web"
end

function ApiClient.new()
    local self = setmetatable({}, ApiClient)
    self.https = load_https()
    self.fetch = load_fetch()
    return self
end

function ApiClient:should_use_fetch()
    if not self.fetch then
        return false
    end

    if not self.https then
        return true
    end

    return is_web_platform()
end

function ApiClient:update(dt)
    if self:should_use_fetch() and self.fetch and type(self.fetch.update) == "function" then
        self.fetch.update(dt)
    end
end

local function build_error(message)
    return { error = { message = message } }
end

local function decode_response_body(body)
    local success, response_json = pcall(dkjson.decode, body)
    if success and response_json then
        return response_json
    end

    local decode_error = response_json or "Unknown decode error"
    return build_error("Failed to decode JSON response: " .. tostring(decode_error))
end

local function normalize_failure(message, detail)
    local parts = { message }
    if detail then
        table.insert(parts, tostring(detail))
    end
    return build_error(table.concat(parts, ": "))
end

local function https_request(https_module, headers, body_json)
    local code, body, headers_or_err = https_module.request(API_URL, {
        method = "POST",
        headers = headers,
        data = body_json
    })

    if not code then
        local err_message = tostring(body or headers_or_err or "Unknown error")
        return build_error("HTTP request failed: " .. err_message)
    end

    local numeric_code = tonumber(code) or code
    if numeric_code ~= 200 then
        local response_body = tostring(body or "")
        local message = string.format("API request failed with code %s", tostring(code))
        if response_body ~= "" then
            message = message .. ": " .. response_body
        end
        return build_error(message)
    end

    return decode_response_body(body)
end

local function invoke_fetch_request(fetch_module, url, options, on_success, on_error)
    if not fetch_module or type(fetch_module.request) ~= "function" then
        return false, "fetch.request is unavailable"
    end

    local errors = {}

    local function record_failure(err)
        if err then
            table.insert(errors, tostring(err))
        end
    end

    local wrapped_success = function(...)
        on_success(...)
    end

    local wrapped_error = function(err)
        on_error(err)
    end

    local ok, result = pcall(fetch_module.request, url, options, wrapped_success, wrapped_error)
    if ok then
        return true
    end
    record_failure(result)

    local request_table = {}
    for key, value in pairs(options) do
        request_table[key] = value
    end
    request_table.url = url
    request_table.success = wrapped_success
    request_table.callback = wrapped_success
    request_table.onSuccess = wrapped_success
    request_table.error = wrapped_error
    request_table.failure = wrapped_error
    request_table.onError = wrapped_error

    ok, result = pcall(fetch_module.request, request_table)
    if ok then
        return true
    end
    record_failure(result)

    ok, result = pcall(fetch_module.request, url, wrapped_success, wrapped_error, options)
    if ok then
        return true
    end
    record_failure(result)

    local message = table.concat(errors, "; ")
    if message == "" then
        message = "fetch.request invocation failed"
    end
    return false, message
end

local function fetch_request(fetch_module, headers, body_json, callback)
    local options = {
        method = "POST",
        headers = headers,
        data = body_json,
        body = body_json
    }

    local completed = false

    local function complete_with_error(err)
        if completed then
            return
        end
        completed = true
        callback(normalize_failure("HTTP request failed", err))
    end

    local ok, err = invoke_fetch_request(fetch_module, API_URL, options, function(code, body)
        if completed then
            return
        end
        completed = true

        local status_code = tonumber(code) or code
        if not status_code then
            callback(normalize_failure("Invalid HTTP status from fetch", code))
            return
        end

        if status_code ~= 200 then
            local response_body = tostring(body or "")
            local message = string.format("API request failed with code %s", tostring(code))
            if response_body ~= "" then
                message = message .. ": " .. response_body
            end
            callback(build_error(message))
            return
        end

        callback(decode_response_body(body))
    end, function(errmsg)
        complete_with_error(errmsg)
    end)

    if not ok then
        complete_with_error(err)
    end
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

    if self:should_use_fetch() then
        assert(type(callback) == "function", "generate_text requires a callback when using fetch")
        fetch_request(self.fetch, headers, body_json, callback)
        return nil
    end

    if not self.https then
        local failure = build_error("HTTPS module is unavailable")
        if callback then
            callback(failure)
        end
        return failure
    end

    local response = https_request(self.https, headers, body_json)
    if callback then
        callback(response)
        return nil
    end
    return response
end

return ApiClient
