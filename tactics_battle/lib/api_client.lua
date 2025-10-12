-- a simple http client for making requests to an OpenAI-compatible API
local https = require("https")

local dkjson = require("tactics_battle.lib.dkjson")

local config = require("tactics_battle.config")

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

    local code, body, _ = https.request(API_URL, {
        method = "POST",
        headers = headers,
        data = body_json
    })

    if code == 200 then
        local success, response_json = pcall(dkjson.decode, body)
        if success then
            return response_json
        else
            return { error = { message = "Failed to decode JSON response." } }
        end
    else
        return { error = { message = "API request failed with code " .. tostring(code) } }
    end
end

return ApiClient
