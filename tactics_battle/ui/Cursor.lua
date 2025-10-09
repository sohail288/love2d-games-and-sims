local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(grid, col, row)
    assert(grid, "grid required")
    local instance = {
        grid = grid,
        col = col or 1,
        row = row or 1
    }
    return setmetatable(instance, Cursor)
end

function Cursor:setPosition(col, row)
    if self.grid:isWithinBounds(col, row) then
        self.col = col
        self.row = row
    end
end

function Cursor:move(dx, dy)
    local targetCol = self.col + dx
    local targetRow = self.row + dy
    if self.grid:isWithinBounds(targetCol, targetRow) then
        self.col = targetCol
        self.row = targetRow
    end
end

return Cursor
