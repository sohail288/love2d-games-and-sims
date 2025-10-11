-- a simple http client for making requests to an OpenAI-compatible API
local https = require("https")

local dkjson = require("tactics_battle.lib.dkjson")

local config = require("tactics_battle.config")

local ApiClient = {}
ApiClient.__index = ApiClient

local API_URL = "https://api.openai.com/v1/chat/completions"
local API_KEY = config.api_key

local schemas = {
    Theme = { type = "object", properties = { theme = { type = "string", description = "A brief summary of the game's central theme." } } },
    Setting = { type = "object", properties = { setting = { type = "string", description = "A description of the game's setting." } } },
    World = { type = "object", properties = { world_summary = { type = "string", description = "A summary of the game world." } } },
    ["Main Character Bios"] = { type = "object", properties = { characters = { type = "array", items = { type = "object", properties = { name = { type = "string" }, bio = { type = "string" } } } } } },
    Story = { type = "object", properties = { story_outline = { type = "string", description = "An outline of the main story." } } },
    Journey = { type = "object", properties = { journey_details = { type = "string", description = "Details about the player's journey." } } },
    Interactions = { type = "object", properties = { interactions = { type = "array", items = { type = "object", properties = { character = { type = "string" }, dialogue = { type = "string" } } } } } }
}

function ApiClient.new()
    local self = setmetatable({}, ApiClient)
    return self
end

function ApiClient:generate_text(prompt, step)
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
            type = "json_object",
            json_schema = schemas[step]
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
