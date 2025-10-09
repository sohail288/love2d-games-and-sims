local Grid = require("tactics_battle.world.Grid")
local Battlefield = require("tactics_battle.world.Battlefield")
local Unit = require("tactics_battle.world.Unit")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")
local EnemyAI = require("tactics_battle.systems.EnemyAI")

describe("EnemyAI", function()
    local function createContext()
        local grid = Grid.new(6, 6, 32)
        local battlefield = Battlefield.new(grid)
        return grid, battlefield
    end

    it("attacks enemies already in range", function()
        local _, battlefield = createContext()
        local attacker = Unit.new({ id = "enemy", faction = "enemies", col = 2, row = 2, speed = 12, attackPower = 18 })
        local target = Unit.new({ id = "ally", faction = "allies", col = 3, row = 2, speed = 8, hp = 40 })
        battlefield:addUnit(attacker, attacker.col, attacker.row)
        battlefield:addUnit(target, target.col, target.row)

        local turnManager = TurnManager.new({ attacker, target })
        local battleSystem = BattleSystem.new({ battlefield = battlefield, turnManager = turnManager })
        local ai = EnemyAI.new(battleSystem)

        battleSystem:startTurn(attacker)
        ai:takeTurn(attacker)

        assertTrue(battleSystem:hasActed(), "AI should perform an attack")
        assertEquals(target.hp, target.maxHp - attacker.attackPower)
        assertTrue(target:isAlive(), "target survives if damage not lethal")
    end)

    it("moves toward the closest opponent and attacks after moving", function()
        local _, battlefield = createContext()
        local attacker = Unit.new({ id = "enemy", faction = "enemies", col = 2, row = 2, speed = 12, move = 3, attackPower = 20 })
        local target = Unit.new({ id = "ally", faction = "allies", col = 5, row = 2, speed = 8, hp = 50 })
        battlefield:addUnit(attacker, attacker.col, attacker.row)
        battlefield:addUnit(target, target.col, target.row)

        local turnManager = TurnManager.new({ attacker, target })
        local battleSystem = BattleSystem.new({ battlefield = battlefield, turnManager = turnManager })
        local ai = EnemyAI.new(battleSystem)

        battleSystem:startTurn(attacker)
        ai:takeTurn(attacker)

        assertEquals(attacker.col, 4)
        assertEquals(attacker.row, 2)
        assertTrue(battleSystem:hasActed(), "AI attacks after moving into range")
        assertTrue(target.hp < target.maxHp, "target takes damage")
    end)
end)
