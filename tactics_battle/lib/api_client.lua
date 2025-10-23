-- a simple http client for making requests to an OpenAI-compatible API
local https = require("https")

local dkjson = require("lib.dkjson")

local config = require("config")

local ApiClient = {}
ApiClient.__index = ApiClient

local API_URL = "https://api.openai.com/v1/chat/completions"
local API_KEY = config.api_key

function ApiClient.new()
    local self = setmetatable({}, ApiClient)
    return self
end

function ApiClient:generate_text(prompt, schema, step_name)
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

    local code, body, headers_or_err = https.request(API_URL, {
        method = "POST",
        headers = headers,
        data = body_json
    })

    if not code then
        local err_message = tostring(body or headers_or_err or "Unknown error")
        return { error = { message = "HTTP request failed: " .. err_message } }
    end

    local numeric_code = tonumber(code) or code
    if numeric_code ~= 200 then
        local response_body = tostring(body or "")
        local message = string.format("API request failed with code %s", tostring(code))
        if response_body ~= "" then
            message = message .. ": " .. response_body
        end
        return { error = { message = message } }
    end

    local success, response_json = pcall(dkjson.decode, body)
    if success and response_json then
        return response_json
    end

    local decode_error = response_json or "Unknown decode error"
    return { error = { message = "Failed to decode JSON response: " .. tostring(decode_error) } }
end

return ApiClient
