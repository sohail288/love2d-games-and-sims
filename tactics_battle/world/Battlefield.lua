local Battlefield = {}
Battlefield.__index = Battlefield

local function tileKey(col, row)
    return string.format("%d_%d", col, row)
end

function Battlefield.new(grid)
    assert(grid, "grid required")
    local instance = {
        grid = grid,
        units = {},
        unitsById = {},
        occupied = {}
    }
    return setmetatable(instance, Battlefield)
end

function Battlefield:addUnit(unit, col, row)
    assert(unit, "unit required")
    col = col or unit.col
    row = row or unit.row
    assert(self.grid:isWithinBounds(col, row), "position out of bounds")
    assert(not self:getUnitAt(col, row), "tile already occupied")

    unit:setPosition(col, row)
    table.insert(self.units, unit)
    self.unitsById[unit.id] = unit
    self.occupied[tileKey(col, row)] = unit
end

function Battlefield:getUnitAt(col, row)
    return self.occupied[tileKey(col, row)]
end

function Battlefield:moveUnit(unit, col, row)
    assert(unit and self.unitsById[unit.id], "unit must belong to battlefield")
    assert(self.grid:isWithinBounds(col, row), "target out of bounds")
    local key = tileKey(col, row)
    assert(not self.occupied[key], "target tile occupied")

    self.occupied[tileKey(unit.col, unit.row)] = nil
    unit:setPosition(col, row)
    self.occupied[key] = unit
end

function Battlefield:removeUnit(unit)
    if not unit or not self.unitsById[unit.id] then
        return
    end
    self.occupied[tileKey(unit.col, unit.row)] = nil
    self.unitsById[unit.id] = nil
    for index, other in ipairs(self.units) do
        if other.id == unit.id then
            table.remove(self.units, index)
            break
        end
    end
end

function Battlefield:unitsByFaction()
    local groups = {}
    for _, unit in ipairs(self.units) do
        groups[unit.faction] = groups[unit.faction] or {}
        table.insert(groups[unit.faction], unit)
    end
    return groups
end

return Battlefield
