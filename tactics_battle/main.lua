local Game = require("Game")
local BattleState = require("states.BattleState")
local StartMenuState = require("states.StartMenuState")
local WorldMapState = require("states.WorldMapState")
local CutsceneState = require("states.CutsceneState")
local DevMenuState = require("states.DevMenuState")

local game

local function bootGame()
    love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
    local font = love.graphics.newFont(16)

    game = Game.new({ font = font })

    local battleState = BattleState.new()
    local startMenuState = StartMenuState.new()
    local worldMapState = WorldMapState.new()
    local cutsceneState = CutsceneState.new()
    local devMenuState = DevMenuState.new()

    game:registerState("battle", battleState)
    game:registerState("start_menu", startMenuState)
    game:registerState("dev_menu", devMenuState)
    game:registerState("world_map", worldMapState)
    game:registerState("cutscene", cutsceneState)

    game:changeState("start_menu")
end

function love.load()
    bootGame()
end

function love.update(dt)
    if game then
        game:update(dt)
    end
end

function love.draw()
    if game then
        game:render()
    end
end

function love.keypressed(key)
    if game then
        game:keypressed(key)
    end
end

function love.textinput(t)
    if game then
        game:textinput(t)
    end
end
