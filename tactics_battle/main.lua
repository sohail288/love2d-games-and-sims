local Game = require("tactics_battle.Game")
local BattleState = require("tactics_battle.states.BattleState")
local Scenarios = require("tactics_battle.scenarios.init")

local game

local function bootGame()
    love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
    local font = love.graphics.newFont(16)

    game = Game.new({ font = font })

    local battleState = BattleState.new()
    game:registerState("battle", battleState)

    game:changeState("battle", {
        scenario = Scenarios.getDefaultScenario()
    })
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
