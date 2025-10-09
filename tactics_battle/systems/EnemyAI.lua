local EnemyAI = {}
EnemyAI.__index = EnemyAI

local function manhattan(a, b)
    return math.abs(a.col - b.col) + math.abs(a.row - b.row)
end

local function copyTargets(targets)
    local copy = {}
    for index, target in ipairs(targets) do
        copy[index] = target
    end
    return copy
end

local function chooseAttackTarget(attacker, targets)
    local ranked = copyTargets(targets)
    table.sort(ranked, function(a, b)
        if a.hp == b.hp then
            local distanceA = manhattan(attacker, a)
            local distanceB = manhattan(attacker, b)
            if distanceA == distanceB then
                return a.id < b.id
            end
            return distanceA < distanceB
        end
        return a.hp < b.hp
    end)
    return ranked[1]
end

local function aliveEnemies(battlefield, unit)
    local enemies = {}
    for _, other in ipairs(battlefield.units) do
        if unit:isEnemyOf(other) and other:isAlive() then
            table.insert(enemies, other)
        end
    end
    return enemies
end

local function minimumDistanceToEnemies(tile, enemies)
    local best = math.huge
    for _, enemy in ipairs(enemies) do
        local distance = math.abs(tile.col - enemy.col) + math.abs(tile.row - enemy.row)
        if distance < best then
            best = distance
        end
    end
    return best
end

function EnemyAI.new(battleSystem)
    assert(battleSystem, "battle system required")
    local instance = { battleSystem = battleSystem }
    return setmetatable(instance, EnemyAI)
end

function EnemyAI:_chooseMove(unit, enemies)
    if #enemies == 0 then
        return nil
    end

    local reachable = self.battleSystem:getReachableTiles(unit)
    local currentBest = minimumDistanceToEnemies(unit, enemies)
    local bestTile = nil
    local bestDistance = currentBest

    for _, tile in ipairs(reachable) do
        if tile.distance and tile.distance > 0 then
            local score = minimumDistanceToEnemies(tile, enemies)
            if score < bestDistance then
                if self.battleSystem:canMove(unit, tile.col, tile.row) then
                    bestTile = tile
                    bestDistance = score
                end
            elseif score == bestDistance and bestTile then
                if tile.distance < bestTile.distance then
                    if self.battleSystem:canMove(unit, tile.col, tile.row) then
                        bestTile = tile
                    end
                elseif tile.distance == bestTile.distance then
                    if tile.col < bestTile.col or (tile.col == bestTile.col and tile.row < bestTile.row) then
                        if self.battleSystem:canMove(unit, tile.col, tile.row) then
                            bestTile = tile
                        end
                    end
                end
            end
        end
    end

    return bestTile
end

function EnemyAI:takeTurn(unit)
    if not unit or not unit:isAlive() then
        return
    end

    local battleSystem = self.battleSystem
    local battlefield = battleSystem.battlefield
    local enemies = aliveEnemies(battlefield, unit)

    local targets = battleSystem:getAttackableTargets(unit)
    if #targets > 0 then
        local target = chooseAttackTarget(unit, targets)
        battleSystem:attack(unit, target)
        return
    end

    local destination = self:_chooseMove(unit, enemies)
    if destination then
        battleSystem:move(unit, destination.col, destination.row)
    end

    targets = battleSystem:getAttackableTargets(unit)
    if #targets > 0 and not battleSystem:hasActed() then
        local target = chooseAttackTarget(unit, targets)
        battleSystem:attack(unit, target)
    end
end

return EnemyAI
