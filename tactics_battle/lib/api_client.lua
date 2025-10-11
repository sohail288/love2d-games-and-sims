-- a simple http client for making requests to an OpenAI-compatible API
-- assumes the existence of a `fetch` function for making http requests
-- and a `dkjson` library for json encoding/decoding

local https = require("ssl.https")
local ltn12 = require("ltn12")

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

    local response_body = {}
    local _, code, _, _ = https.request{
        url = API_URL,
        method = "POST",
        headers = headers,
        source = ltn12.source.string(body_json),
        sink = ltn12.sink.table(response_body)
    }

    if code == 200 then
        local response_string = table.concat(response_body)
        local success, response_json = pcall(dkjson.decode, response_string)
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
