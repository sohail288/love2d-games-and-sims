local WorldMap = require("tactics_battle.world.WorldMap")
local defaultMapConfig = require("tactics_battle.world.default_map")

local StartMenuState = {}
StartMenuState.__index = StartMenuState

function StartMenuState.new()
    local self = setmetatable({}, StartMenuState)
    self.selectedIndex = 1
    self.options = {}
    self.createWorld = function()
        return WorldMap.new(defaultMapConfig)
    end
    self.introScript = defaultMapConfig.introScript
    return self
end

local function ensureWorldContext(game, state)
    local context = game:getContext()
    context.world = context.world or {}
    if not context.world.map then
        context.world.map = state.createWorld()
    end
    return context.world.map
end

function StartMenuState:enter(game)
    self.selectedIndex = 1
    local context = game:getContext()
    self.font = context.font
    self.options = {
        {
            label = "Start Adventure",
            action = function(g)
                local world = ensureWorldContext(g, self)
                local script = self.introScript or { { text = "The journey begins." } }
                g:changeState("cutscene", {
                    title = "Prologue",
                    script = script,
                    onComplete = function(innerGame)
                        innerGame:changeState("world_map", { world = world })
                    end
                })
            end
        },
        {
            label = "Quit",
            action = function()
                if love and love.event and love.event.quit then
                    love.event.quit()
                end
            end
        }
    }
end

function StartMenuState:update(_game, _dt)
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

function StartMenuState:render(_game)
    if love and love.graphics then
        love.graphics.clear(0.05, 0.06, 0.08)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Tactics Prototype", 80, 80)
        love.graphics.print("Press Enter to begin", 80, 110)
        local y = 160
        for index, option in ipairs(self.options) do
            drawOption(option.label, 80, y, index == self.selectedIndex)
            y = y + 28
        end
    end
end

function StartMenuState:keypressed(game, key)
    if key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then
            self.selectedIndex = #self.options
        end
    elseif key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.options then
            self.selectedIndex = 1
        end
    elseif key == "return" or key == "kpenter" then
        local option = self.options[self.selectedIndex]
        if option and option.action then
            option.action(game)
        end
    elseif key == "d" then
        game:changeState("dev_menu")
    end
end

return StartMenuState
