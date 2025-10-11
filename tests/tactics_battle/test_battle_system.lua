local Grid = require("tactics_battle.world.Grid")
local Battlefield = require("tactics_battle.world.Battlefield")
local Unit = require("tactics_battle.world.Unit")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")

describe("BattleSystem", function()
    local function setupBattle(options)
        options = options or {}
        local grid = Grid.new(6, 6, 32)
        local battlefield = Battlefield.new(grid)
        local units = {
            Unit.new({ id = "ally", faction = "allies", col = 2, row = 2, move = 3, attackPower = 30, speed = 6 }),
            Unit.new({ id = "enemy", faction = "enemies", col = 4, row = 2, hp = 30, speed = 5 }),
            Unit.new({ id = "blocker", faction = "allies", col = 3, row = 2, speed = 4 })
        }
        for _, unit in ipairs(units) do
            battlefield:addUnit(unit, unit.col, unit.row)
        end
        local turnManager = TurnManager.new(units)
        local battleSystem = BattleSystem.new({
            battlefield = battlefield,
            turnManager = turnManager,
            random = options.random or function()
                return 1
            end
        })
        battleSystem:startTurn(units[1])
        return {
            grid = grid,
            battlefield = battlefield,
            battleSystem = battleSystem,
            units = units,
            turnManager = turnManager
        }
    end

    local function constantRandom(value)
        return function()
            return value
        end
    end

    describe("movement range", function()
        it("prevents moving through occupied tiles", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem
            local unit = context.units[1]

            local reachable = battleSystem:getReachableTiles(unit)
            local hasBlockedTile = false
            for _, tile in ipairs(reachable) do
                if tile.col == 3 and tile.row == 2 then
                    hasBlockedTile = true
                end
            end
            assertTrue(not hasBlockedTile, "should not include tile occupied by another unit")
            assertTrue(battleSystem:canMove(unit, 2, 2), "unit can stay in place")
            assertTrue(not battleSystem:canMove(unit, 4, 2), "blocked tile prevents passing through enemy")
        end)

        it("marks unit as moved after executing move", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem
            local unit = context.units[1]

            assertTrue(not battleSystem:hasMoved(), "unit should start unmoved")
            battleSystem:move(unit, 2, 2)
            assertTrue(battleSystem:hasMoved(), "unit should be marked as moved")
            assertTrue(not battleSystem:canMove(unit, 2, 3), "unit cannot move twice")
        end)

        it("generates a step-by-step path to a reachable tile", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem
            local unit = context.units[1]

            local path = battleSystem:findPath(unit, 2, 4)
            assertTrue(path ~= nil, "path should be returned for reachable destination")
            assertEquals(#path, 3)
            assertEquals(path[1].col, 2)
            assertEquals(path[1].row, 2)
            assertEquals(path[#path].col, 2)
            assertEquals(path[#path].row, 4)

            local blockedPath = battleSystem:findPath(unit, 4, 2)
            assertTrue(blockedPath == nil, "cannot path onto an occupied tile")
        end)
    end)

    describe("attacks", function()
        it("applies damage and removes defeated targets", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem
            local attacker = context.units[1]
            local target = context.units[2]

            context.turnManager:removeUnit(context.units[3])
            context.battlefield:removeUnit(context.units[3])
            context.battlefield:moveUnit(attacker, 3, 2)
            assertTrue(battleSystem:canAttack(attacker, target), "target should be in range")
            local result = battleSystem:attack(attacker, target)

            assertEquals(result.damage, attacker.attackPower)
            assertTrue(result.defeated, "target should be defeated")
            assertTrue(context.battlefield:getUnitAt(4, 2) == nil, "target removed from battlefield")
            assertEquals(context.turnManager:unitCount(), 1)
            assertTrue(battleSystem:hasActed(), "attacker cannot act twice in same turn")
            assertTrue(not battleSystem:canAttack(attacker, target), "attacker has already acted")
        end)

        it("returns all tiles within attack range including empty squares", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem
            local attacker = context.units[1]

            context.battlefield:moveUnit(attacker, 3, 3)

            local tiles = battleSystem:getAttackableTiles(attacker)
            table.sort(tiles, function(a, b)
                if a.col == b.col then
                    return a.row < b.row
                end
                return a.col < b.col
            end)

            local expected = {
                { col = 2, row = 3 },
                { col = 3, row = 2 },
                { col = 3, row = 4 },
                { col = 4, row = 3 }
            }

            assertEquals(#tiles, #expected)
            for index, tile in ipairs(expected) do
                assertEquals(tiles[index].col, tile.col)
                assertEquals(tiles[index].row, tile.row)
            end
        end)

        it("applies orientation-based critical chance modifiers", function()
            local function runAttack(targetOrientation, randomValue)
                local context = setupBattle({ random = constantRandom(randomValue) })
                local battleSystem = context.battleSystem
                local attacker = context.units[1]
                local target = context.units[2]

                context.turnManager:removeUnit(context.units[3])
                context.battlefield:removeUnit(context.units[3])
                context.battlefield:moveUnit(attacker, 3, 2)
                target:setOrientation(targetOrientation)

                assertTrue(battleSystem:canAttack(attacker, target), "target should be in range")
                local result = battleSystem:attack(attacker, target)
                return result
            end

            local front = runAttack("west", 0.1)
            assertTrue(not front.critical, "front attack should not crit at higher roll")
            assertEquals(front.facingRelation, "front")
            assertEquals(front.damage, 30)

            local side = runAttack("north", 0.15)
            assertTrue(side.critical, "side attack should crit when roll within threshold")
            assertEquals(side.facingRelation, "side")
            assertEquals(side.damage, 45)

            local back = runAttack("east", 0.35)
            assertTrue(back.critical, "back attack should crit with higher threshold")
            assertEquals(back.facingRelation, "back")
            assertEquals(back.damage, 45)
        end)
    end)

    describe("turn transitions", function()
        it("advances to next unit on end turn", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem

            local nextUnit = battleSystem:endTurn()
            assertTrue(nextUnit ~= nil, "should advance to next unit")
            assertEquals(nextUnit.id, context.units[2].id)
        end)

        it("tracks the highest action time cost during a turn", function()
            local grid = Grid.new(5, 5, 32)
            local battlefield = Battlefield.new(grid)
            local actor = Unit.new({ id = "actor", faction = "allies", col = 2, row = 2, move = 3, attackPower = 20, timeCosts = { move = 2, attack = 3 } })
            local enemy = Unit.new({ id = "enemy", faction = "enemies", col = 3, row = 2, hp = 20 })
            battlefield:addUnit(actor, actor.col, actor.row)
            battlefield:addUnit(enemy, enemy.col, enemy.row)
            local turnManager = TurnManager.new({ actor, enemy })
            local battleSystem = BattleSystem.new({ battlefield = battlefield, turnManager = turnManager })

            battleSystem:startTurn(actor)
            battleSystem:move(actor, 2, 3)
            assertEquals(battleSystem:getTurnTimeCost(), 2)

            battlefield:moveUnit(enemy, 3, 3)
            local result = battleSystem:attack(actor, enemy)
            assertTrue(result.defeated, "enemy should be defeated")
            assertEquals(battleSystem:getTurnTimeCost(), 3)

            local _, timeCost = battleSystem:endTurn()
            assertEquals(timeCost, 3)
        end)
    end)

    describe("outcome evaluation", function()
        it("provides elimination reasons when only one faction remains", function()
            local context = setupBattle()
            local battleSystem = context.battleSystem

            context.battlefield:removeUnit(context.units[2])
            context.turnManager:removeUnit(context.units[2])

            local outcome = battleSystem:checkBattleOutcome()
            assertTrue(outcome ~= nil, "battle should conclude when one faction remains")
            assertEquals(outcome.winner, "allies")
            assertEquals(outcome.reason, "Only the allies remain standing.")
        end)
    end)
end)
