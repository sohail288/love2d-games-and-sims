local ApiClient = require("tactics_battle.lib.api_client")
local SimpleYaml = require("tactics_battle.lib.simple_yaml")
local dkjson = require("tactics_battle.lib.dkjson")

local DevMenuState = {}
DevMenuState.__index = DevMenuState

local schemas = {
    Theme = {
        name = "theme",
        description = "A brief summary of the game's central theme.",
        schema = {
            type = "object",
            properties = { theme = { type = "string", description = "A brief summary of the game's central theme." } },
            required = { "theme" },
            additionalProperties = false
        }
    },
    Setting = {
        name = "setting",
        description = "A description of the game's setting.",
        schema = {
            type = "object",
            properties = { setting = { type = "string", description = "A description of the game's setting." } },
            required = { "setting" },
            additionalProperties = false
        }
    },
    World = {
        name = "world",
        description = "A summary of the game world.",
        schema = {
            type = "object",
            properties = { world_summary = { type = "string", description = "A summary of the game world." } },
            required = { "world_summary" },
            additionalProperties = false
        }
    },
    ["Main Character Bios"] = {
        name = "character_bios",
        description = "Biographies for the main characters.",
        schema = {
            type = "object",
            properties = {
                characters = {
                    type = "array",
                    items = {
                        type = "object",
                        properties = { name = { type = "string" }, bio = { type = "string" } },
                        required = { "name", "bio" },
                        additionalProperties = false
                    }
                }
            },
            required = { "characters" },
            additionalProperties = false
        }
    },
    Story = {
        name = "story_outline",
        description = "An outline of the main story.",
        schema = {
            type = "object",
            properties = { story_outline = { type = "string", description = "An outline of the main story." } },
            required = { "story_outline" },
            additionalProperties = false
        }
    },
    Journey = {
        name = "journey_details",
        description = "Details about the player's journey.",
        schema = {
            type = "object",
            properties = { journey_details = { type = "string", description = "Details about the player's journey." } },
            required = { "journey_details" },
            additionalProperties = false
        }
    },
    Interactions = {
        name = "interactions",
        description = "Dialogue interactions between characters.",
        schema = {
            type = "object",
            properties = {
                interactions = {
                    type = "array",
                    items = {
                        type = "object",
                        properties = { character = { type = "string" }, dialogue = { type = "string" } },
                        required = { "character", "dialogue" },
                        additionalProperties = false
                    }
                }
            },
            required = { "interactions" },
            additionalProperties = false
        }
    }
}

function DevMenuState.new()
    local self = setmetatable({}, DevMenuState)
    self.selectedIndex = 1
    self.generationSteps = {
        "Theme",
        "Setting",
        "World",
        "Main Character Bios",
        "Story",
        "Journey",
        "Interactions"
    }
    self.generatedContent = {}
    self.apiClient = ApiClient.new()
    self.saveStatus = ""
    self.editMode = false
    self.editText = ""
    return self
end

function DevMenuState:enter(game)
    local context = game:getContext()
    self.font = context.font
end

function DevMenuState:update(_game, _dt)
end

local function drawOption(label, x, y, selected)
    if love and love.graphics then
        if selected then
            love.graphics.setColor(0.9, 0.9, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.print(label, x, y)
    end
end

function DevMenuState:render(_game)
    if love and love.graphics then
        love.graphics.clear(0.05, 0.06, 0.08)
        love.graphics.setColor(1, 1, 1)

        if self.editMode then
            love.graphics.print("Editing JSON (Press ESC to save and exit)", 80, 80)
            love.graphics.print(self.editText, 80, 120)
        else
            love.graphics.print("Content Generation Dev Menu", 80, 80)
            local y = 120
            for index, step in ipairs(self.generationSteps) do
                local content_display = "..."
                if self.generatedContent[step] then
                    content_display = dkjson.encode(self.generatedContent[step], { indent = true })
                end
                local label = string.format("%d. %s: %s", index, step, content_display)
                drawOption(label, 80, y, index == self.selectedIndex)
                y = y + 28
            end

            if self.saveStatus then
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(self.saveStatus, 80, y + 28)
            end
        end
    end
end

function DevMenuState:keypressed(game, key)
    if self.editMode then
        if key == "escape" then
            self.editMode = false
            -- Try to parse the edited text back into a Lua table
            local step = self.generationSteps[self.selectedIndex]
            local success, decoded_json = pcall(dkjson.decode, self.editText)
            if success then
                self.generatedContent[step] = decoded_json
            else
                -- Handle parse error, maybe show a message
                self.saveStatus = "Error: Invalid JSON. Changes not saved."
            end
        elseif key == "backspace" then
            self.editText = self.editText:sub(1, -2)
        end
        return
    end

    if key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then
            self.selectedIndex = #self.generationSteps
        end
    elseif key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.generationSteps then
            self.selectedIndex = 1
        end
    elseif key == "return" or key == "kpenter" then
        local step = self.generationSteps[self.selectedIndex]

        local context_prompt = "You are generating a story for a tactics RPG. Here is the context so far:\n"
        for i = 1, self.selectedIndex - 1 do
            local prev_step = self.generationSteps[i]
            local content = self.generatedContent[prev_step]
            if content then
                context_prompt = context_prompt .. prev_step .. ": " .. dkjson.encode(content) .. "\n"
            end
        end

        local prompt = context_prompt .. "\nNow, generate the " .. step .. "."

        local schema = schemas[step]
        local response = self.apiClient:generate_text(prompt, schema)
        if response and response.choices and response.choices[1] then
            local content = response.choices[1].message.content
            local success, decoded_json = pcall(dkjson.decode, content)
            if success then
                self.generatedContent[step] = decoded_json
            else
                self.generatedContent[step] = { error = "Failed to decode JSON from API." }
            end
        else
            self.generatedContent[step] = { error = "Error generating content." }
        end
    elseif key == "e" then
        self.editMode = true
        local step = self.generationSteps[self.selectedIndex]
        local content = self.generatedContent[step]
        if content then
            self.editText = dkjson.encode(content, { indent = true })
        else
            self.editText = ""
        end
    elseif key == "escape" then
        game:changeState("start_menu")
    elseif key == "s" then
        local yaml_string = SimpleYaml.encode(self.generatedContent, self.generationSteps)
        local success, err = love.filesystem.write("generated_content.yaml", yaml_string)
        if success then
            self.saveStatus = "Content saved to generated_content.yaml"
        else
            self.saveStatus = "Error saving content: " .. tostring(err)
        end
    end
end

function DevMenuState:textinput(t)
    if self.editMode then
        self.editText = self.editText .. t
    end
end

return DevMenuState
