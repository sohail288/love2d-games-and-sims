local Grid = require("world.Grid")
local Battlefield = require("world.Battlefield")
local Unit = require("world.Unit")
local TurnManager = require("systems.TurnManager")
local BattleSystem = require("systems.BattleSystem")
local EnemyAI = require("systems.EnemyAI")

local function setupScenario(args)
    args = args or {}
    local grid = Grid.new(6, 6, 32)
    local battlefield = Battlefield.new(grid)
    local ally = Unit.new({ id = "ally", faction = "allies", col = args.allyCol or 2, row = args.allyRow or 3, hp = 60, maxHp = 60 })
    local enemy = Unit.new({ id = "enemy", faction = "enemies", col = args.enemyCol or 5, row = args.enemyRow or 3, move = 3, attackPower = args.attackPower or 20 })
    local units = { ally, enemy }

    for _, unit in ipairs(units) do
        battlefield:addUnit(unit, unit.col, unit.row)
    end

    local turnManager = TurnManager.new(units)
    local battleSystem = BattleSystem.new({
        battlefield = battlefield,
        turnManager = turnManager,
        random = function()
            return 1
        end
    })
    battleSystem:startTurn(enemy)
    local ai = EnemyAI.new({ battleSystem = battleSystem })

    return {
        grid = grid,
        battlefield = battlefield,
        ally = ally,
        enemy = enemy,
        turnManager = turnManager,
        battleSystem = battleSystem,
        ai = ai
    }
end

describe("EnemyAI", function()
    it("attacks in place when a target is already in range", function()
        local context = setupScenario({ enemyCol = 3, attackPower = 18 })
        assertTrue(context.battleSystem:canAttack(context.enemy, context.ally), "enemy should be able to attack without moving")
        local result = context.ai:takeTurn(context.enemy)
        assertTrue(result.attacked, "enemy should attack the adjacent ally")
        assertTrue(not result.moved, "enemy should not move when already in range")
        assertTrue(context.ally.hp < context.ally.maxHp, "ally should take damage")
    end)

    it("moves closer to the nearest opponent when out of range", function()
        local context = setupScenario({})
        local startCol, startRow = context.enemy.col, context.enemy.row
        local startDistance = math.abs(startCol - context.ally.col) + math.abs(startRow - context.ally.row)
        local result = context.ai:takeTurn(context.enemy)
        local newDistance = math.abs(context.enemy.col - context.ally.col) + math.abs(context.enemy.row - context.ally.row)
        assertTrue(result.moved, "enemy should move towards ally")
        assertTrue(newDistance < startDistance, "enemy should be closer after moving")
        assertTrue(result.path ~= nil and #result.path >= 2, "enemy movement should expose the travelled path")
        assertEquals(result.path[1].col, startCol)
        assertEquals(result.path[1].row, startRow)
        assertEquals(result.path[#result.path].col, context.enemy.col)
        assertEquals(result.path[#result.path].row, context.enemy.row)
    end)

    it("follows up with an attack after moving into range", function()
        local context = setupScenario({ enemyCol = 4, attackPower = 25 })
        local result = context.ai:takeTurn(context.enemy)
        assertTrue(result.moved, "enemy should move before attacking")
        assertTrue(result.attacked, "enemy should attack after moving")
        assertTrue(context.ally.hp < context.ally.maxHp, "ally should take damage from follow-up attack")
    end)
end)
