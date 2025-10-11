local ApiClient = require("tactics_battle.lib.api_client")
local SimpleYaml = require("tactics_battle.lib.simple_yaml")

local DevMenuState = {}
DevMenuState.__index = DevMenuState

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
        love.graphics.print("Content Generation Dev Menu", 80, 80)
        local y = 120
        for index, step in ipairs(self.generationSteps) do
            local label = string.format("%d. %s: %s", index, step, self.generatedContent[step] or "...")
            if self.editMode and index == self.selectedIndex then
                label = label .. " [EDITING]"
            end
            drawOption(label, 80, y, index == self.selectedIndex)
            y = y + 28
        end

        if self.saveStatus then
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(self.saveStatus, 80, y + 28)
        end
    end
end

function DevMenuState:keypressed(game, key)
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
                context_prompt = context_prompt .. prev_step .. ": " .. content .. "\n"
            end
        end

        local prompt = context_prompt .. "\nNow, generate the " .. step .. "."

        local response = self.apiClient:generate_text(prompt)
        if response and response.choices and response.choices[1] then
            self.generatedContent[step] = response.choices[1].message.content
        else
            self.generatedContent[step] = "Error generating content."
        end
    elseif key == "e" then
        self.editMode = not self.editMode
    elseif key == "escape" then
        if self.editMode then
            self.editMode = false
        else
            game:changeState("start_menu")
        end
    elseif key == "backspace" and self.editMode then
        local step = self.generationSteps[self.selectedIndex]
        local current_text = self.generatedContent[step] or ""
        self.generatedContent[step] = current_text:sub(1, -2)
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
        local step = self.generationSteps[self.selectedIndex]
        local current_text = self.generatedContent[step] or ""
        self.generatedContent[step] = current_text .. t
    end
end

return DevMenuState
