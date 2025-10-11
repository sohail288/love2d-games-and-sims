local Game = require("tactics_battle.Game")
local BattleState = require("tactics_battle.states.BattleState")
local StartMenuState = require("tactics_battle.states.StartMenuState")
local WorldMapState = require("tactics_battle.states.WorldMapState")
local CutsceneState = require("tactics_battle.states.CutsceneState")
local DevMenuState = require("tactics_battle.states.DevMenuState")

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
