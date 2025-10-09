local Grid = require("tactics_battle.world.Grid")

describe("Grid", function()
    it("converts tile coordinates to world coordinates", function()
        local grid = Grid.new(5, 5, 32)
        local x, y = grid:tileToWorld(1, 1)
        assertEquals(x, 16)
        assertEquals(y, 16)
    end)

    it("converts world coordinates to tile indices", function()
        local grid = Grid.new(5, 5, 32)
        local col, row = grid:worldToTile(65, 65)
        assertEquals(col, 3)
        assertEquals(row, 3)
    end)

    it("returns nil for world coordinates outside the grid", function()
        local grid = Grid.new(2, 2, 32)
        local col, row = grid:worldToTile(200, 200)
        assertTrue(col == nil and row == nil)
    end)

    it("iterates over every tile", function()
        local grid = Grid.new(3, 2, 32)
        local count = 0
        for tile in grid:tiles() do
            count = count + 1
            assertTrue(grid:isWithinBounds(tile.col, tile.row))
        end
        assertEquals(count, 6)
    end)
end)
