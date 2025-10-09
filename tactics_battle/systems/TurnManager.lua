local TurnManager = {}
TurnManager.__index = TurnManager

local function aliveUnits(units)
    local result = {}
    for _, unit in ipairs(units) do
        if unit:isAlive() then
            table.insert(result, unit)
        end
    end
    return result
end

local function sortByInitiative(units)
    table.sort(units, function(a, b)
        if a.speed == b.speed then
            return a.id < b.id
        end
        return a.speed > b.speed
    end)
end

function TurnManager.new(units)
    local instance = {
        order = {},
        index = 1
    }
    setmetatable(instance, TurnManager)
    instance:setUnits(units or {})
    return instance
end

function TurnManager:setUnits(units)
    self.order = aliveUnits(units)
    sortByInitiative(self.order)
    if self.index > #self.order then
        self.index = 1
    end
end

function TurnManager:currentUnit()
    return self.order[self.index]
end

function TurnManager:advance()
    if #self.order == 0 then
        return nil
    end
    self.index = self.index + 1
    if self.index > #self.order then
        self.index = 1
    end
    local current = self:currentUnit()
    if current and not current:isAlive() then
        self:removeUnit(current)
        return self:advance()
    end
    return current
end

function TurnManager:removeUnit(unit)
    for i, candidate in ipairs(self.order) do
        if candidate.id == unit.id then
            table.remove(self.order, i)
            if i <= self.index then
                self.index = math.max(1, self.index - 1)
            end
            break
        end
    end
    if #self.order == 0 then
        self.index = 1
    else
        self.index = ((self.index - 1) % #self.order) + 1
    end
end

function TurnManager:refresh()
    self:setUnits(self.order)
end

function TurnManager:unitCount()
    return #self.order
end

function TurnManager:getTurnOrder()
    local snapshot = {}
    for i, unit in ipairs(self.order) do
        snapshot[i] = unit
    end
    return snapshot
end

function TurnManager:getCurrentIndex()
    return self.index
end

return TurnManager
