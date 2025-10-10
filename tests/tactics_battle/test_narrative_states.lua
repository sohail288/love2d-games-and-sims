local DialogueSystem = require("tactics_battle.systems.DialogueSystem")
local CutsceneState = require("tactics_battle.states.CutsceneState")
local StartMenuState = require("tactics_battle.states.StartMenuState")
local WorldMapState = require("tactics_battle.states.WorldMapState")
local WorldMap = require("tactics_battle.world.WorldMap")
local Game = require("tactics_battle.Game")
local BattleState = require("tactics_battle.states.BattleState")

local function ensureStubLove()
    if _G.love then
        return
    end
    _G.love = {
        graphics = {
            clear = function() end,
            setColor = function() end,
            print = function() end,
            getWidth = function() return 800 end,
            getHeight = function() return 600 end,
            newFont = function()
                return { stub = true }
            end
        },
        event = {
            quit = function()
                _G.__quit_called = true
            end
        }
    }
end

ensureStubLove()

local function buildWorldConfig()
    return {
        locations = {
            { id = "first_town", name = "First Town", type = "town", mandatory = true, script = { { text = "Welcome" } } },
            { id = "crossroads", name = "Crossroads", type = "town", mandatory = false, script = { { text = "Safe travels" } } },
            { id = "battlefield", name = "Battlefield", type = "battlefield", scenario = "training_ground", battleChance = 1, victoryScript = { { text = "Won" } } },
            { id = "second_town", name = "Second Town", type = "town", script = { { text = "Hello" } } }
        },
        paths = {
            { from = "first_town", to = "crossroads" },
            { from = "crossroads", to = "battlefield" },
            { from = "battlefield", to = "second_town" }
        }
    }
end

describe("DialogueSystem", function()
    it("advances through entries and reports completion", function()
        local script = {
            { speaker = "Narrator", text = "Line one" },
            { speaker = "Hero", text = "Line two" }
        }
        local dialogue = DialogueSystem.new(script)
        local first = dialogue:current()
        assertEquals(first.text, "Line one")
        dialogue:advance()
        local second = dialogue:current()
        assertEquals(second.text, "Line two")
        dialogue:advance()
        assertTrue(dialogue:isFinished(), "dialogue should finish after advancing past last line")
    end)
end)

describe("CutsceneState", function()
    it("fires completion callback when dialogue ends", function()
        local state = CutsceneState.new()
        local completed = false
        local game = {}
        state:enter(game, {
            script = { { text = "Only line" } },
            onComplete = function(arg)
                completed = arg == game
            end
        })
        state:keypressed(game, "return")
        assertTrue(completed, "expected cutscene to trigger completion when dialogue finishes")
    end)
end)

describe("StartMenuState", function()
    it("creates world map context and transitions into campaign", function()
        local state = StartMenuState.new()
        local config = buildWorldConfig()
        local createdWorld = WorldMap.new(config)
        state.createWorld = function()
            return createdWorld
        end
        state.introScript = { { text = "Intro" } }

        local context = {}
        local transitions = {}
        local game = {
            getContext = function()
                return context
            end,
            changeState = function(_, name, params)
                table.insert(transitions, { name = name, params = params })
            end
        }

        state:enter(game)
        state:keypressed(game, "return")

        assertEquals(#transitions, 1)
        assertEquals(transitions[0 + 1].name, "cutscene")
        assertTrue(context.world ~= nil and context.world.map == createdWorld, "world map should be stored in context")

        local onComplete = transitions[1].params.onComplete
        assertTrue(type(onComplete) == "function", "start cutscene should supply a completion handler")
        onComplete(game)

        assertEquals(#transitions, 2)
        assertEquals(transitions[2].name, "world_map")
        assertEquals(transitions[2].params.world, createdWorld)
    end)
end)

describe("WorldMapState", function()
    it("travels shortest paths, pauses for battles, and opens town menus on arrival", function()
        local config = buildWorldConfig()
        local world = WorldMap.new(config)
        local state = WorldMapState.new()
        state.travelDuration = 0.01
        local transitions = {}
        local game = {
            getContext = function()
                return { world = { map = world } }
            end,
            changeState = function(_, name, params)
                table.insert(transitions, { name = name, params = params })
            end
        }

        state:enter(game, { world = world })

        local destinationIndex = world:getIndexById("second_town")
        world:setSelectedIndex(destinationIndex)
        state:activateSelection(game)

        -- pass through crossroads automatically
        state:update(game, 0.02)
        assertEquals(#transitions, 0)
        assertEquals(world:getCurrent().id, "crossroads")

        -- arrival at battlefield triggers battle
        state:update(game, 0.02)
        assertEquals(transitions[1].name, "battle")
        local battleParams = transitions[1].params
        assertEquals(world:getCurrent().id, "battlefield")
        battleParams.onComplete(game, { winner = "players", draw = false })

        -- battle victory triggers aftermath cutscene before returning to world map with resume data
        assertEquals(transitions[2].name, "cutscene")
        transitions[2].params.onComplete(game)
        assertEquals(transitions[3].name, "world_map")

        -- resume travel from world map after battle
        state:enter(game, transitions[3].params)
        state:update(game, 0.02)
        local current = world:getCurrent()
        assertEquals(current.id, "second_town")
        assertTrue(state.awaitingTownMenu, "arriving at town should enable town menu")

        state:keypressed(game, "space")
        assertEquals(transitions[4].name, "cutscene")
        assertTrue(type(transitions[4].params.onComplete) == "function")
    end)
end)

describe("BattleState", function()
    it("invokes onComplete callback when battle outcome is determined", function()
        local game = Game.new({ font = { stub = true } })
        local battleState = BattleState.new()
        game:registerState("battle", battleState)

        local callbackOutcome
        game:changeState("battle", {
            scenario = {
                id = "empty", name = "Empty", grid = { width = 2, height = 2, tileSize = 32 }, units = {}
            },
            onComplete = function(_, outcome)
                callbackOutcome = outcome
            end
        })

        battleState:update(game, 0)
        assertTrue(callbackOutcome ~= nil, "battle completion callback should receive an outcome")
    end)
end)
