local Grid = require("tactics_battle.world.Grid")
local Unit = require("tactics_battle.world.Unit")
local Battlefield = require("tactics_battle.world.Battlefield")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")
local EnemyAI = require("tactics_battle.systems.EnemyAI")
local Cursor = require("tactics_battle.ui.Cursor")

local state = {
    grid = nil,
    battlefield = nil,
    turnManager = nil,
    cursor = nil,
    selectedUnit = nil,
    font = nil,
    moveTiles = nil,
    attackTargets = nil,
    battleOutcome = nil,
    battleSystem = nil,
    enemyAI = nil,
    turnOrder = nil
}

local function updateTurnOrder()
    if not state.turnManager then
        state.turnOrder = nil
        return
    end
    state.turnOrder = state.turnManager:getTurnOrder()
end

local function refreshHighlights()
    if not state.selectedUnit or not state.battleSystem then
        state.moveTiles = nil
        state.attackTargets = nil
        return
    end
    if state.battleSystem:hasMoved() then
        state.moveTiles = { { col = state.selectedUnit.col, row = state.selectedUnit.row } }
    else
        state.moveTiles = state.battleSystem:getReachableTiles(state.selectedUnit)
    end
    if state.battleSystem:hasActed() then
        state.attackTargets = {}
    else
        state.attackTargets = state.battleSystem:getAttackableTargets(state.selectedUnit)
    end
end

local function createUnits()
    return {
        Unit.new({ id = "ally_knight", name = "Knight", faction = "allies", speed = 8, hp = 120, move = 3, attackPower = 35, col = 2, row = 5 }),
        Unit.new({ id = "ally_archer", name = "Archer", faction = "allies", speed = 12, hp = 80, move = 4, attackRange = 3, attackPower = 28, col = 3, row = 6 }),
        Unit.new({ id = "enemy_soldier", name = "Soldier", faction = "enemies", speed = 7, hp = 100, move = 3, attackPower = 32, col = 8, row = 3 }),
        Unit.new({ id = "enemy_mage", name = "Mage", faction = "enemies", speed = 10, hp = 70, move = 4, attackRange = 3, attackPower = 40, col = 7, row = 2 })
    }
end

local function populateBattlefield(battlefield, units)
    for _, unit in ipairs(units) do
        battlefield:addUnit(unit, unit.col, unit.row)
    end
end

local function centerOffsets(grid)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local totalWidth = grid.width * grid.tileSize
    local totalHeight = grid.height * grid.tileSize
    local offsetX = (width - totalWidth) / 2
    local offsetY = (height - totalHeight) / 2
    return offsetX, offsetY
end

local function drawGrid(grid)
    local offsetX, offsetY = centerOffsets(grid)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.2, 0.25, 0.3)
    for tile in grid:tiles() do
        local x = offsetX + (tile.col - 1) * grid.tileSize
        local y = offsetY + (tile.row - 1) * grid.tileSize
        love.graphics.rectangle("line", x, y, grid.tileSize, grid.tileSize)
    end
end

local function drawHighlightTiles(grid, tiles, color)
    if not tiles then
        return
    end
    local offsetX, offsetY = centerOffsets(grid)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.4)
    for _, tile in ipairs(tiles) do
        local x = offsetX + (tile.col - 1) * grid.tileSize
        local y = offsetY + (tile.row - 1) * grid.tileSize
        love.graphics.rectangle("fill", x + 2, y + 2, grid.tileSize - 4, grid.tileSize - 4, 6, 6)
    end
end

local function drawCursor(grid, cursor)
    if not cursor then
        return
    end
    local offsetX, offsetY = centerOffsets(grid)
    local x = offsetX + (cursor.col - 1) * grid.tileSize
    local y = offsetY + (cursor.row - 1) * grid.tileSize
    love.graphics.setColor(1, 0.85, 0.3, 0.7)
    love.graphics.rectangle("line", x + 2, y + 2, grid.tileSize - 4, grid.tileSize - 4)
end

local function unitColor(unit)
    if unit.faction == "allies" then
        return 0.3, 0.7, 0.9
    else
        return 0.9, 0.4, 0.4
    end
end

local function drawUnits(grid, battlefield, selectedUnit)
    local offsetX, offsetY = centerOffsets(grid)
    for _, unit in ipairs(battlefield.units) do
        local x = offsetX + (unit.col - 1) * grid.tileSize
        local y = offsetY + (unit.row - 1) * grid.tileSize
        local r, g, b = unitColor(unit)
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", x + 6, y + 6, grid.tileSize - 12, grid.tileSize - 12, 6, 6)
        if selectedUnit and selectedUnit.id == unit.id then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x + 4, y + 4, grid.tileSize - 8, grid.tileSize - 8, 6, 6)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(unit.name, x + 8, y + grid.tileSize - 20)
    end
end

local function drawHud()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(state.font)
    local current = state.turnManager:currentUnit()
    if current then
        love.graphics.print(string.format("Current Turn: %s (%s)", current.name, current.faction), 16, 16)
    end
    if state.selectedUnit then
        love.graphics.print(string.format("Selected: %s | HP %d/%d", state.selectedUnit.name, state.selectedUnit.hp, state.selectedUnit.maxHp), 16, 40)
    else
        love.graphics.print("Selected: none", 16, 40)
    end
    if state.battleOutcome then
        local message
        if state.battleOutcome.draw then
            message = "Battle complete: Draw"
        else
            message = string.format("Battle complete: %s win", state.battleOutcome.winner)
        end
        love.graphics.print(message, 16, 64)
    end
    if state.turnOrder and #state.turnOrder > 0 and state.turnManager then
        local labels = {}
        local currentIndex = state.turnManager:getCurrentIndex()
        for index, unit in ipairs(state.turnOrder) do
            local marker = index == currentIndex and "*" or " "
            labels[#labels + 1] = string.format("%s%s", marker, unit.name)
        end
        love.graphics.print("Turn Order: " .. table.concat(labels, " -> "), 16, 88)
    end
    love.graphics.print("Controls: Arrows move cursor, Space select, Enter move, A attack, Tab end turn", 16, love.graphics.getHeight() - 32)
end

local function beginTurn(unit)
    if not unit or not state.battleSystem or state.battleOutcome then
        return
    end

    if state.battleSystem.currentUnit ~= unit then
        state.battleSystem:startTurn(unit)
    end

    state.selectedUnit = nil
    state.moveTiles = nil
    state.attackTargets = nil

    if state.cursor then
        state.cursor:setPosition(unit.col, unit.row)
    end

    updateTurnOrder()

    if unit.faction == "enemies" and state.enemyAI then
        local actions = state.enemyAI:takeTurn(unit)
        if actions.attacked or actions.moved then
            refreshHighlights()
        end
        state.battleOutcome = state.battleSystem:checkBattleOutcome()
        updateTurnOrder()
        if not state.battleOutcome then
            local nextUnit = state.battleSystem:endTurn()
            state.battleOutcome = state.battleSystem:checkBattleOutcome()
            updateTurnOrder()
            if nextUnit then
                beginTurn(nextUnit)
            end
        end
    end
end

local function selectUnitAtCursor()
    local unit = state.battlefield:getUnitAt(state.cursor.col, state.cursor.row)
    local current = state.turnManager:currentUnit()
    if unit and current and unit.id == current.id then
        state.selectedUnit = unit
        refreshHighlights()
    end
end

local function moveSelectedUnit()
    if not state.selectedUnit or not state.battleSystem then
        return
    end
    if not state.battleSystem:canMove(state.selectedUnit, state.cursor.col, state.cursor.row) then
        return
    end
    state.battleSystem:move(state.selectedUnit, state.cursor.col, state.cursor.row)
    refreshHighlights()
end

local function attackTargetAtCursor()
    if not state.selectedUnit or not state.battleSystem then
        return
    end
    local target = state.battlefield:getUnitAt(state.cursor.col, state.cursor.row)
    if not target then
        return
    end
    if not state.battleSystem:canAttack(state.selectedUnit, target) then
        return
    end
    state.battleSystem:attack(state.selectedUnit, target)
    refreshHighlights()
    state.battleOutcome = state.battleSystem:checkBattleOutcome()
    updateTurnOrder()
end

local function endTurn()
    state.selectedUnit = nil
    state.moveTiles = nil
    state.attackTargets = nil
    if not state.battleSystem then
        return
    end
    local nextUnit = state.battleSystem:endTurn()
    state.battleOutcome = state.battleSystem:checkBattleOutcome()
    updateTurnOrder()
    if nextUnit then
        beginTurn(nextUnit)
    end
end

function love.load()
    state.grid = Grid.new(10, 8, 64)
    state.battlefield = Battlefield.new(state.grid)
    local units = createUnits()
    populateBattlefield(state.battlefield, units)
    state.turnManager = TurnManager.new(units)
    state.battleSystem = BattleSystem.new({ battlefield = state.battlefield, turnManager = state.turnManager })
    state.enemyAI = EnemyAI.new({ battleSystem = state.battleSystem })
    local current = state.turnManager:currentUnit()
    state.cursor = Cursor.new(state.grid, current and current.col or 1, current and current.row or 1)
    updateTurnOrder()
    if current then
        beginTurn(current)
    end
    state.font = love.graphics.newFont(16)
    love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
end

function love.keypressed(key)
    if key == "up" then
        state.cursor:move(0, -1)
    elseif key == "down" then
        state.cursor:move(0, 1)
    elseif key == "left" then
        state.cursor:move(-1, 0)
    elseif key == "right" then
        state.cursor:move(1, 0)
    elseif key == "space" then
        selectUnitAtCursor()
    elseif key == "return" or key == "kpenter" then
        moveSelectedUnit()
    elseif key == "a" then
        attackTargetAtCursor()
    elseif key == "tab" then
        endTurn()
    end
end

function love.draw()
    drawGrid(state.grid)
    drawHighlightTiles(state.grid, state.moveTiles, { 0.2, 0.5, 0.8, 0.25 })
    drawHighlightTiles(state.grid, state.attackTargets, { 0.9, 0.3, 0.3, 0.25 })
    drawUnits(state.grid, state.battlefield, state.selectedUnit)
    drawCursor(state.grid, state.cursor)
    drawHud()
end

