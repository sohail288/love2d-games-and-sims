local EnemyAI = {}
EnemyAI.__index = EnemyAI

local function copyPosition(tile)
    return { col = tile.col, row = tile.row }
end

local function manhattan(a, b)
    return math.abs(a.col - b.col) + math.abs(a.row - b.row)
end

local function directionTo(from, to)
    local dx = (to.col or 0) - (from.col or 0)
    local dy = (to.row or 0) - (from.row or 0)
    if math.abs(dx) >= math.abs(dy) then
        if dx >= 0 then
            return "east"
        else
            return "west"
        end
    end
    if dy >= 0 then
        return "south"
    else
        return "north"
    end
end

local function aliveOpponents(battlefield, faction)
    local opponents = {}
    local groups = battlefield:unitsByFaction()
    for otherFaction, units in pairs(groups) do
        if otherFaction ~= faction then
            for _, unit in ipairs(units) do
                if unit:isAlive() then
                    table.insert(opponents, unit)
                end
            end
        end
    end
    return opponents
end

local function closestOpponent(unit, opponents)
    local nearest = nil
    local bestDistance = math.huge
    for _, opponent in ipairs(opponents) do
        local distance = manhattan(unit, opponent)
        if distance < bestDistance then
            bestDistance = distance
            nearest = opponent
        end
    end
    return nearest
end

local function selectLowestHpTarget(targets)
    table.sort(targets, function(a, b)
        if a.hp == b.hp then
            return a.id < b.id
        end
        return a.hp < b.hp
    end)
    return targets[1]
end

local function chooseDestination(reachable, opponents)
    if #reachable == 0 or #opponents == 0 then
        return nil
    end

    local best = nil
    local bestDistance = math.huge
    local bestSteps = math.huge

    for _, tile in ipairs(reachable) do
        local closest = math.huge
        for _, opponent in ipairs(opponents) do
            local distance = manhattan(tile, opponent)
            if distance < closest then
                closest = distance
            end
        end

        local steps = tile.distance or 0
        if closest < bestDistance or (closest == bestDistance and steps < bestSteps) then
            best = tile
            bestDistance = closest
            bestSteps = steps
        end
    end

    return best
end

function EnemyAI.new(args)
    assert(args and args.battleSystem, "battleSystem required")

    local instance = {
        battleSystem = args.battleSystem
    }

    return setmetatable(instance, EnemyAI)
end

function EnemyAI:takeTurn(unit)
    assert(unit, "unit required")
    if unit.faction ~= "enemies" then
        return { attacked = false, moved = false }
    end

    local battleSystem = self.battleSystem
    local battlefield = battleSystem.battlefield
    local result = { attacked = false, moved = false }

    local attackable = battleSystem:getAttackableTargets(unit)
    if #attackable > 0 then
        local target = selectLowestHpTarget(attackable)
        battleSystem:attack(unit, target)
        local facing = directionTo(unit, target)
        if facing then
            unit:setOrientation(facing)
        end
        result.attacked = true
        result.target = target
        return result
    end

    local opponents = aliveOpponents(battlefield, unit.faction)
    if #opponents == 0 then
        return result
    end

    local reachable = battleSystem:getReachableTiles(unit)
    local destination = chooseDestination(reachable, opponents)
    if destination and (destination.col ~= unit.col or destination.row ~= unit.row) then
        local startCol, startRow = unit.col, unit.row
        local path = battleSystem:findPath(unit, destination.col, destination.row)
        battleSystem:move(unit, destination.col, destination.row)
        result.moved = true
        result.movedTo = copyPosition(destination)
        result.path = path
        local moveFacing = directionTo({ col = startCol, row = startRow }, destination)
        if moveFacing then
            unit:setOrientation(moveFacing)
        end
    end

    attackable = battleSystem:getAttackableTargets(unit)
    if #attackable > 0 then
        local target = selectLowestHpTarget(attackable)
        battleSystem:attack(unit, target)
        local facing = directionTo(unit, target)
        if facing then
            unit:setOrientation(facing)
        end
        result.attacked = true
        result.target = target
    elseif result.moved and #opponents > 0 then
        local closest = closestOpponent(unit, opponents)
        if closest then
            local facing = directionTo(unit, closest)
            if facing then
                unit:setOrientation(facing)
            end
        end
    end

    return result
end

return EnemyAI
