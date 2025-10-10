local Game = require("tactics_battle.Game")
local BattleState = require("tactics_battle.states.BattleState")
local Scenarios = require("tactics_battle.scenarios.init")

local function createStubLove()
    if _G.love then
        return
    end
    _G.love = {
        graphics = {
            newFont = function()
                return { stub = true }
            end,
            getWidth = function()
                return 800
            end,
            getHeight = function()
                return 600
            end,
            setLineWidth = function() end,
            setColor = function() end,
            rectangle = function() end,
            print = function() end,
            setFont = function() end
        },
        event = {
            quit = function()
                _G.__quit_called = true
            end
        }
    }
end

createStubLove()

describe("Game", function()
    it("transitions between registered states", function()
        local events = {}
        local stateA = {
            enter = function(_, game, params)
                events[#events + 1] = { "enterA", params and params.flag }
                assertEquals(game:getContext().label, "context")
            end,
            exit = function()
                events[#events + 1] = { "exitA" }
            end,
            update = function()
                events[#events + 1] = { "updateA" }
            end
        }

        local stateB = {
            enter = function(_, _, params)
                events[#events + 1] = { "enterB", params and params.flag }
            end
        }

        local game = Game.new({ label = "context" })
        game:registerState("menu", stateA)
        game:registerState("battle", stateB)

        game:changeState("menu", { flag = "start" })
        game:update(0.16)
        game:changeState("battle", { flag = "next" })

        assertEquals(#events, 4)
        assertEquals(events[1][1], "enterA")
        assertEquals(events[1][2], "start")
        assertEquals(events[2][1], "updateA")
        assertEquals(events[3][1], "exitA")
        assertEquals(events[4][1], "enterB")
        assertEquals(events[4][2], "next")
    end)
end)

describe("BattleState", function()
    it("initializes the default scenario into the scene", function()
        local game = Game.new({ font = { stub = true } })
        local battleState = BattleState.new()
        game:registerState("battle", battleState)
        game:changeState("battle", { scenario = Scenarios.getDefaultScenario() })

        local scene = battleState:getScene()
        local _, currentName = game:getCurrentState()

        assertTrue(scene.grid ~= nil, "expected grid to be created")
        assertTrue(scene.battlefield ~= nil, "expected battlefield to be created")
        assertTrue(scene.turnManager ~= nil, "expected turn manager to be created")
        assertEquals(scene.scenario.id, "training_ground")
        assertTrue(scene.cursor ~= nil, "expected cursor to be created")
        assertTrue(scene.turnOrder ~= nil and #scene.turnOrder > 0, "expected turn order to be populated")
        assertTrue(scene.objectives ~= nil and #scene.objectives >= 1, "expected objectives to be populated")
        assertEquals(scene.font, game:getContext().font)
        assertEquals(currentName, "battle")
    end)

    it("ignores pause transitions when pause state is not registered", function()
        local game = Game.new({ font = { stub = true } })
        local battleState = BattleState.new()
        game:registerState("battle", battleState)
        game:changeState("battle", { scenario = Scenarios.getDefaultScenario() })

        battleState:keypressed(game, "p")
        -- No assertions required; the call should not error and should keep the scene intact.
        local _, currentName = game:getCurrentState()
        assertEquals(currentName, "battle")
    end)

    it("tracks elapsed time units when turns end", function()
        local customScenario = {
            id = "time_unit_demo",
            name = "Time Unit Demo",
            grid = { width = 4, height = 4, tileSize = 32 },
            units = {
                { id = "solo", name = "Solo", faction = "allies", col = 2, row = 2, move = 2, speed = 5 }
            }
        }

        local game = Game.new({ font = { stub = true } })
        local battleState = BattleState.new()
        game:registerState("battle", battleState)
        game:changeState("battle", { scenario = customScenario })

        local scene = battleState:getScene()
        assertEquals(scene.timeUnits, 0)

        battleState:keypressed(game, "tab")
        assertTrue(scene.timeUnits >= 1, "ending a turn should increase time units")
    end)
end)
