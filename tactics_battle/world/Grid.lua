local Grid = {}
Grid.__index = Grid

local function validateDimension(value, name)
    assert(type(value) == "number" and value > 0, name .. " must be a positive number")
end

function Grid.new(width, height, tileSize)
    validateDimension(width, "width")
    validateDimension(height, "height")
    tileSize = tileSize or 48
    validateDimension(tileSize, "tileSize")

    local instance = {
        width = math.floor(width),
        height = math.floor(height),
        tileSize = tileSize
    }

    return setmetatable(instance, Grid)
end

function Grid:isWithinBounds(col, row)
    return col >= 1 and col <= self.width and row >= 1 and row <= self.height
end

function Grid:tileToWorld(col, row)
    assert(self:isWithinBounds(col, row), "tile out of bounds")
    local offset = self.tileSize / 2
    local x = (col - 1) * self.tileSize + offset
    local y = (row - 1) * self.tileSize + offset
    return x, y
end

function Grid:worldToTile(x, y)
    local col = math.floor(x / self.tileSize) + 1
    local row = math.floor(y / self.tileSize) + 1
    if self:isWithinBounds(col, row) then
        return col, row
    end
    return nil, nil
end

function Grid:tiles()
    local col, row = 1, 1
    return function()
        if row > self.height then
            return nil
        end
        local current = { col = col, row = row }
        col = col + 1
        if col > self.width then
            col = 1
            row = row + 1
        end
        return current
    end
end

return Grid
