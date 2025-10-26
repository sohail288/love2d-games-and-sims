local DialogueSystem = require("systems.DialogueSystem")

local CutsceneState = {}
CutsceneState.__index = CutsceneState

function CutsceneState.new()
    local self = setmetatable({}, CutsceneState)
    self.dialogue = DialogueSystem.new()
    self.title = nil
    self.onComplete = nil
    self.backgroundColor = { 0, 0, 0 }
    return self
end

function CutsceneState:enter(game, params)
    params = params or {}
    if params.script then
        self.dialogue:setScript(params.script)
    else
        self.dialogue:setScript({ { text = "..." } })
    end
    self.dialogue:reset()
    self.title = params.title
    self.onComplete = params.onComplete
    self.backgroundColor = params.backgroundColor or { 0, 0, 0 }
    self.game = game
end

function CutsceneState:update(_game, _dt)
end

local function callCompletion(self, game)
    if self.onComplete then
        local callback = self.onComplete
        self.onComplete = nil
        callback(game)
    end
end

function CutsceneState:advance(game)
    if self.dialogue:isFinished() then
        callCompletion(self, game)
        return
    end
    self.dialogue:advance()
    if self.dialogue:isFinished() then
        callCompletion(self, game)
    end
end

function CutsceneState:keypressed(game, key)
    if key == "return" or key == "space" or key == "kpenter" then
        self:advance(game)
    end
end

local function drawBackground(color)
    if love and love.graphics and love.graphics.clear then
        love.graphics.clear(color[1], color[2], color[3])
    end
end

local function drawDialogue(title, entry)
    if not (love and love.graphics) then
        return
    end
    local lg = love.graphics
    lg.setColor(1, 1, 1)
    local y = 80
    if title then
        lg.print(title, 64, y)
        y = y + 32
    end
    if entry then
        if entry.speaker then
            lg.print(entry.speaker .. ":", 64, y)
            y = y + 28
        end
        lg.print(entry.text, 64, y)
        y = y + 28
        lg.print("Press Enter to continue", 64, y + 24)
    else
        lg.print("Press Enter to continue", 64, y)
    end
end

function CutsceneState:render(_game)
    local current = self.dialogue:current()
    drawBackground(self.backgroundColor)
    drawDialogue(self.title, current)
end

return CutsceneState
