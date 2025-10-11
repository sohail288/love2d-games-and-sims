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

function ApiClient:generate_text(prompt)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. API_KEY
    }

    local body = {
        model = "gpt-3.5-turbo",
        messages = {
            { role = "system", content = "You are a creative assistant for a tactics RPG." },
            { role = "user", content = prompt }
        },
        temperature = 0.7
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
