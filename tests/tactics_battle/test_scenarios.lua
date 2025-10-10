local Scenarios = require("tactics_battle.scenarios")
local Grid = require("tactics_battle.world.Grid")
local Battlefield = require("tactics_battle.world.Battlefield")
local Unit = require("tactics_battle.world.Unit")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")

describe("Scenario configuration", function()
    it("exposes the default training ground scenario", function()
        local scenario = Scenarios.getDefaultScenario()
        assertTrue(scenario ~= nil, "default scenario should exist")
        assertEquals(scenario.id, "training_ground")
        assertTrue(scenario.grid ~= nil, "scenario defines grid")
        assertEquals(scenario.grid.width, 10)
        assertEquals(scenario.grid.height, 8)
        assertEquals(#(scenario.units or {}), 4)
        assertTrue(type(scenario.hooks.onTurnStart) == "function", "turn start hook available")
        assertTrue(type(scenario.victoryConditions[1]) == "function", "victory evaluator available")
    end)

    it("allows scenario-specific victory to override default elimination", function()
        local scenarioState = {}
        local scenario = {
            id = "flag_capture",
            grid = { width = 4, height = 4, tileSize = 32 },
            units = {},
            victoryConditions = {
                function(context)
                    if context.scenarioState.flagCaptured then
                        return { winner = "allies", draw = false, reason = "Flag secured." }
                    end
                end
            }
        }

        local grid = Grid.new(4, 4, 32)
        local battlefield = Battlefield.new(grid)
        local units = {
            Unit.new({ id = "ally", faction = "allies", col = 1, row = 1, speed = 5 }),
            Unit.new({ id = "enemy", faction = "enemies", col = 2, row = 1, speed = 4 })
        }

        for _, unit in ipairs(units) do
            battlefield:addUnit(unit, unit.col, unit.row)
        end

        local turnManager = TurnManager.new(units)
        local battleSystem = BattleSystem.new({
            battlefield = battlefield,
            turnManager = turnManager,
            scenario = scenario,
            scenarioState = scenarioState
        })

        assertTrue(battleSystem:checkBattleOutcome() == nil, "no victory before flag captured")

        scenarioState.flagCaptured = true
        local outcome = battleSystem:checkBattleOutcome()
        assertTrue(outcome ~= nil, "scenario victory should trigger")
        assertEquals(outcome.winner, "allies")
        assertEquals(outcome.reason, "Flag secured.")
    end)
end)
