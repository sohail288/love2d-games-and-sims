local BattleSystem = {}
BattleSystem.__index = BattleSystem

local function tileKey(col, row)
    return string.format("%d_%d", col, row)
end

local function neighbors(col, row)
    return {
        { col = col + 1, row = row },
        { col = col - 1, row = row },
        { col = col, row = row + 1 },
        { col = col, row = row - 1 }
    }
end

local function copyTile(tile)
    return { col = tile.col, row = tile.row, distance = tile.distance }
end

function BattleSystem.new(args)
    assert(args and args.battlefield, "battlefield required")
    assert(args.turnManager, "turn manager required")

    local instance = {
        battlefield = args.battlefield,
        turnManager = args.turnManager,
        currentUnit = nil,
        moved = false,
        acted = false,
        outcome = nil
    }

    return setmetatable(instance, BattleSystem)
end

function BattleSystem:startTurn(unit)
    self.currentUnit = unit
    self.moved = false
    self.acted = false
end

function BattleSystem:hasMoved()
    return self.moved
end

function BattleSystem:hasActed()
    return self.acted
end

function BattleSystem:_reachableTiles(unit)
    local grid = self.battlefield.grid
    local maxDistance = unit.move or 0
    local queue = { { col = unit.col, row = unit.row, distance = 0 } }
    local head = 1
    local visited = { [tileKey(unit.col, unit.row)] = true }
    local tiles = {}

    while queue[head] do
        local node = queue[head]
        head = head + 1
        table.insert(tiles, copyTile(node))

        if node.distance < maxDistance then
            for _, neighbor in ipairs(neighbors(node.col, node.row)) do
                if grid:isWithinBounds(neighbor.col, neighbor.row) then
                    local key = tileKey(neighbor.col, neighbor.row)
                    if not visited[key] then
                        local occupant = self.battlefield:getUnitAt(neighbor.col, neighbor.row)
                        if not occupant or occupant.id == unit.id then
                            visited[key] = true
                            neighbor.distance = node.distance + 1
                            queue[#queue + 1] = neighbor
                        end
                    end
                end
            end
        end
    end

    return tiles
end

function BattleSystem:getReachableTiles(unit)
    assert(unit, "unit required")
    return self:_reachableTiles(unit)
end

local function containsTile(tiles, col, row)
    for _, tile in ipairs(tiles) do
        if tile.col == col and tile.row == row then
            return true
        end
    end
    return false
end

function BattleSystem:canMove(unit, col, row)
    if self.moved then
        return false
    end
    local tiles = self:getReachableTiles(unit)
    if not containsTile(tiles, col, row) then
        return false
    end
    local occupant = self.battlefield:getUnitAt(col, row)
    return not occupant or occupant.id == unit.id
end

function BattleSystem:move(unit, col, row)
    assert(unit, "unit required")
    assert(self.currentUnit and unit.id == self.currentUnit.id, "unit must be current turn")
    assert(self:canMove(unit, col, row), "move not allowed")

    if col ~= unit.col or row ~= unit.row then
        self.battlefield:moveUnit(unit, col, row)
    end
    self.moved = true
end

local function manhattan(a, b)
    return math.abs(a.col - b.col) + math.abs(a.row - b.row)
end

function BattleSystem:getAttackableTargets(attacker)
    assert(attacker, "attacker required")
    local targets = {}
    for _, unit in ipairs(self.battlefield.units) do
        if attacker:isEnemyOf(unit) and unit:isAlive() and manhattan(attacker, unit) <= attacker.attackRange then
            table.insert(targets, unit)
        end
    end
    return targets
end

function BattleSystem:canAttack(attacker, target)
    if self.acted then
        return false
    end
    if not target or not attacker:isEnemyOf(target) or not target:isAlive() then
        return false
    end
    return manhattan(attacker, target) <= attacker.attackRange
end

function BattleSystem:_finalizeTarget(target)
    if not target:isAlive() then
        self.battlefield:removeUnit(target)
        self.turnManager:removeUnit(target)
    end
    self:checkBattleOutcome()
end

function BattleSystem:attack(attacker, target)
    assert(attacker, "attacker required")
    assert(target, "target required")
    assert(self.currentUnit and attacker.id == self.currentUnit.id, "attacker must be current unit")
    assert(self:canAttack(attacker, target), "attack not allowed")

    target:takeDamage(attacker.attackPower)
    local defeated = not target:isAlive()
    self.acted = true
    self:_finalizeTarget(target)
    return {
        target = target,
        damage = attacker.attackPower,
        defeated = defeated
    }
end

function BattleSystem:checkBattleOutcome()
    if self.outcome then
        return self.outcome
    end

    local factions = self.battlefield:unitsByFaction()
    local contenders = {}
    for faction, units in pairs(factions) do
        for _, unit in ipairs(units) do
            if unit:isAlive() then
                table.insert(contenders, faction)
                break
            end
        end
    end

    if #contenders == 0 then
        self.outcome = { winner = nil, draw = true }
    elseif #contenders == 1 then
        self.outcome = { winner = contenders[1], draw = false }
    end

    return self.outcome
end

function BattleSystem:endTurn()
    self.currentUnit = nil
    self.moved = false
    self.acted = false
    if self:checkBattleOutcome() then
        return nil
    end
    local nextUnit = self.turnManager:advance()
    if nextUnit then
        self:startTurn(nextUnit)
    end
    return nextUnit
end

return BattleSystem
