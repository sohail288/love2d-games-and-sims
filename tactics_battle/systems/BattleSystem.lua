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

local function decodeKey(key)
    local col, row = key:match("^(%-?%d+)_(%-?%d+)$")
    if not col then
        error("invalid tile key: " .. tostring(key))
    end
    return tonumber(col), tonumber(row)
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
        outcome = nil,
        scenario = args.scenario,
        scenarioState = args.scenarioState,
        turnTimeCost = 1
    }

    return setmetatable(instance, BattleSystem)
end

function BattleSystem:startTurn(unit)
    self.currentUnit = unit
    self.moved = false
    self.acted = false
    self.turnTimeCost = 1
end

function BattleSystem:hasMoved()
    return self.moved
end

function BattleSystem:hasActed()
    return self.acted
end

function BattleSystem:getActionTimeCost(actionType, unit)
    if unit and unit.timeCosts and unit.timeCosts[actionType] then
        return unit.timeCosts[actionType]
    end
    if self.scenario and self.scenario.actionTimeCosts then
        local cost = self.scenario.actionTimeCosts[actionType]
        if type(cost) == "table" and unit then
            if cost[unit.id] ~= nil then
                return cost[unit.id]
            end
        elseif cost ~= nil then
            return cost
        end
    end
    return 1
end

function BattleSystem:getTurnTimeCost()
    return self.turnTimeCost or 1
end

function BattleSystem:_searchReachable(unit)
    local grid = self.battlefield.grid
    local maxDistance = unit.move or 0
    local queue = { { col = unit.col, row = unit.row, distance = 0 } }
    local head = 1
    local visited = { [tileKey(unit.col, unit.row)] = { distance = 0 } }
    local parents = {}
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
                            visited[key] = { distance = node.distance + 1 }
                            parents[key] = tileKey(node.col, node.row)
                            neighbor.distance = node.distance + 1
                            queue[#queue + 1] = neighbor
                        end
                    end
                end
            end
        end
    end

    return tiles, visited, parents
end

function BattleSystem:getReachableTiles(unit)
    assert(unit, "unit required")
    local tiles = self:_searchReachable(unit)
    return tiles
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
    local cost = self:getActionTimeCost("move", unit)
    if cost > (self.turnTimeCost or 1) then
        self.turnTimeCost = cost
    end
end

local function manhattan(a, b)
    return math.abs(a.col - b.col) + math.abs(a.row - b.row)
end

function BattleSystem:getAttackableTargets(attacker)
    assert(attacker, "attacker required")
    local targets = {}
    for _, unit in ipairs(self.battlefield.units) do
        if attacker:isEnemyOf(unit) and manhattan(attacker, unit) <= attacker.attackRange then
            table.insert(targets, unit)
        end
    end
    return targets
end

function BattleSystem:getAttackableTiles(attacker)
    assert(attacker, "attacker required")
    local range = attacker.attackRange or 1
    local tiles = {}
    local seen = {}
    for dx = -range, range do
        for dy = -range, range do
            local col = attacker.col + dx
            local row = attacker.row + dy
            if self.battlefield.grid:isWithinBounds(col, row) then
                local distance = math.abs(dx) + math.abs(dy)
                if distance > 0 and distance <= range then
                    local key = tileKey(col, row)
                    if not seen[key] then
                        seen[key] = true
                        tiles[#tiles + 1] = { col = col, row = row }
                    end
                end
            end
        end
    end
    return tiles
end

function BattleSystem:canAttack(attacker, target)
    if self.acted then
        return false
    end
    if not target or not attacker:isEnemyOf(target) then
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
    local cost = self:getActionTimeCost("attack", attacker)
    if cost > (self.turnTimeCost or 1) then
        self.turnTimeCost = cost
    end
    self:_finalizeTarget(target)
    return {
        target = target,
        damage = attacker.attackPower,
        defeated = defeated
    }
end

local function mergeExtras(context, extras)
    if not extras then
        return context
    end
    for key, value in pairs(extras) do
        context[key] = value
    end
    return context
end

function BattleSystem:_buildScenarioContext(extras)
    if not self.scenario then
        return nil
    end

    local battlefield = self.battlefield
    local context = mergeExtras({
        battleSystem = self,
        battlefield = battlefield,
        turnManager = self.turnManager,
        scenario = self.scenario,
        scenarioState = self.scenarioState or {}
    }, extras)

    function context:countFactionUnits(faction)
        local count = 0
        for _, unit in ipairs(battlefield.units) do
            if unit.faction == faction then
                count = count + 1
            end
        end
        return count
    end

    function context:listFactionUnits(faction)
        local result = {}
        for _, unit in ipairs(battlefield.units) do
            if faction == nil or unit.faction == faction then
                result[#result + 1] = unit
            end
        end
        return result
    end

    return context
end

local function evaluateConditions(self, conditions)
    if not conditions or not self.scenario then
        return nil
    end

    local context = self:_buildScenarioContext()
    for _, evaluator in ipairs(conditions) do
        local result = evaluator(context)
        if result then
            if result.draw == nil then
                result.draw = false
            end
            return result
        end
    end

    return nil
end

function BattleSystem:checkBattleOutcome()
    if self.outcome then
        return self.outcome
    end

    local scenarioVictory = evaluateConditions(self, self.scenario and self.scenario.victoryConditions)
    if scenarioVictory then
        self.outcome = scenarioVictory
        return self.outcome
    end

    local scenarioDefeat = evaluateConditions(self, self.scenario and self.scenario.defeatConditions)
    if scenarioDefeat then
        self.outcome = scenarioDefeat
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
        self.outcome = { winner = nil, draw = true, reason = "All combatants were defeated." }
    elseif #contenders == 1 then
        self.outcome = {
            winner = contenders[1],
            draw = false,
            reason = string.format("Only the %s remain standing.", contenders[1])
        }
    end

    return self.outcome
end

function BattleSystem:findPath(unit, destinationCol, destinationRow)
    assert(unit, "unit required")
    local _, visited, parents = self:_searchReachable(unit)
    local goalKey = tileKey(destinationCol, destinationRow)
    if not visited[goalKey] then
        return nil
    end

    local path = {}
    local currentKey = goalKey
    while currentKey do
        local col, row = decodeKey(currentKey)
        table.insert(path, 1, { col = col, row = row })
        currentKey = parents[currentKey]
    end

    return path
end

function BattleSystem:endTurn()
    self.currentUnit = nil
    self.moved = false
    self.acted = false
    local timeCost = self.turnTimeCost or 1
    self.turnTimeCost = 1
    if self:checkBattleOutcome() then
        return nil, timeCost
    end
    local nextUnit = self.turnManager:advance()
    if nextUnit then
        self:startTurn(nextUnit)
    end
    return nextUnit, timeCost
end

return BattleSystem
