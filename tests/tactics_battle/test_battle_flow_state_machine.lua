local Grid = require("tactics_battle.world.Grid")
local Battlefield = require("tactics_battle.world.Battlefield")
local Unit = require("tactics_battle.world.Unit")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")
local BattleFlowStateMachine = require("tactics_battle.systems.BattleFlowStateMachine")

local function setupBattle()
    local grid = Grid.new(5, 5, 32)
    local battlefield = Battlefield.new(grid)
    local ally = Unit.new({ id = "ally", faction = "allies", col = 2, row = 2, move = 3, attackRange = 1, attackPower = 40, speed = 6 })
    local enemy = Unit.new({ id = "enemy", faction = "enemies", col = 4, row = 2, hp = 30, speed = 5 })
    battlefield:addUnit(ally, ally.col, ally.row)
    battlefield:addUnit(enemy, enemy.col, enemy.row)
    local turnManager = TurnManager.new({ ally, enemy })
    local battleSystem = BattleSystem.new({ battlefield = battlefield, turnManager = turnManager, random = function()
        return 1
    end })
    battleSystem:startTurn(ally)

    return {
        grid = grid,
        battlefield = battlefield,
        ally = ally,
        enemy = enemy,
        turnManager = turnManager,
        battleSystem = battleSystem
    }
end

describe("BattleFlowStateMachine", function()
    it("ends the turn automatically when movement and attack actions are exhausted", function()
        local context = setupBattle()
        local events = {}

        local machine = BattleFlowStateMachine.new({
            battleSystem = context.battleSystem,
            battlefield = context.battlefield,
            onAwaitingInput = function()
                events[#events + 1] = { "phase", "awaiting" }
            end,
            onActionComplete = function(actionType)
                events[#events + 1] = { "action", actionType }
            end,
            onNoActionsRemaining = function()
                events[#events + 1] = { "phase", "no_actions" }
            end,
            onOrientationPrompt = function(_, reason)
                events[#events + 1] = { "orientation", reason }
            end,
            onOrientationComplete = function(_, orientation, reason)
                events[#events + 1] = { "orientation_complete", orientation, reason }
            end,
            onTurnComplete = function(_, reason)
                events[#events + 1] = { "turn_complete", reason }
            end
        })

        machine:beginTurn(context.ally)
        assertEquals(events[1][1], "phase")
        assertEquals(events[1][2], "awaiting")

        context.battleSystem:move(context.ally, 3, 2)
        machine:onMoveCommitted(true)
        machine:onAnimationsComplete("move")
        machine:update(0)

        assertEquals(events[2][1], "action")
        assertEquals(events[2][2], "move")
        assertEquals(events[3][1], "phase")
        assertEquals(events[3][2], "awaiting")

        context.battleSystem:attack(context.ally, context.enemy)
        machine:onAttackCommitted(false)
        machine:onAnimationsComplete("attack")
        machine:update(0)

        assertEquals(events[4][1], "action")
        assertEquals(events[4][2], "attack")
        assertEquals(events[5][1], "phase")
        assertEquals(events[5][2], "no_actions")
        assertEquals(events[6][1], "orientation")
        assertEquals(events[6][2], "no_actions")

        context.ally:setOrientation("west")
        machine:onOrientationChosen("west")
        machine:update(0)

        assertEquals(events[7][1], "orientation_complete")
        assertEquals(events[7][2], "west")
        assertEquals(events[7][3], "no_actions")
        assertEquals(events[8][1], "turn_complete")
        assertEquals(events[8][2], "no_actions")
        assertEquals(machine.state, "idle")
    end)

    it("allows skipping a turn which immediately advances the initiative", function()
        local context = setupBattle()
        local events = {}

        local machine = BattleFlowStateMachine.new({
            battleSystem = context.battleSystem,
            battlefield = context.battlefield,
            onOrientationPrompt = function(_, reason)
                events[#events + 1] = { "orientation", reason }
            end,
            onOrientationComplete = function(_, orientation, reason)
                events[#events + 1] = { "orientation_complete", orientation, reason }
            end,
            onTurnComplete = function(_, reason)
                events[#events + 1] = { "turn_complete", reason }
            end
        })

        machine:beginTurn(context.ally)
        machine:skipTurn()
        machine:update(0)

        assertEquals(events[1][1], "orientation")
        assertEquals(events[1][2], "skipped")

        context.ally:setOrientation("south")
        machine:onOrientationChosen("south")
        machine:update(0)

        assertEquals(events[2][1], "orientation_complete")
        assertEquals(events[2][2], "south")
        assertEquals(events[2][3], "skipped")
        assertEquals(events[3][1], "turn_complete")
        assertEquals(events[3][2], "skipped")
        assertEquals(machine.state, "idle")
    end)

    it("immediately ends the turn when no valid actions remain at start", function()
        local context = setupBattle()
        context.ally.move = 0
        context.enemy.col = 5
        context.enemy.row = 5
        context.battlefield:moveUnit(context.enemy, context.enemy.col, context.enemy.row)

        local result = nil
        local orientationReason = nil
        local machine = BattleFlowStateMachine.new({
            battleSystem = context.battleSystem,
            battlefield = context.battlefield,
            onOrientationPrompt = function(_, reason)
                orientationReason = reason
            end,
            onTurnComplete = function(_, reason)
                result = reason
            end
        })

        machine:beginTurn(context.ally)
        machine:update(0)

        assertEquals(orientationReason, "no_actions")
        assertEquals(result, nil)

        context.ally:setOrientation("north")
        machine:onOrientationChosen("north")
        machine:update(0)

        assertEquals(result, "no_actions")
        assertEquals(machine.state, "idle")
    end)
end)
