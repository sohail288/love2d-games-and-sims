local Grid = require("tactics_battle.world.Grid")
local Unit = require("tactics_battle.world.Unit")
local Battlefield = require("tactics_battle.world.Battlefield")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")
local EnemyAI = require("tactics_battle.systems.EnemyAI")
local Cursor = require("tactics_battle.ui.Cursor")
local Scenarios = require("tactics_battle.scenarios")

local state = {
    grid = nil,
    battlefield = nil,
    turnManager = nil,
    cursor = nil,
    selectedUnit = nil,
    font = nil,
    moveTiles = nil,
    attackTiles = nil,
    battleOutcome = nil,
    battleSystem = nil,
    enemyAI = nil,
    turnOrder = nil,
    attackPreview = false,
    scenario = nil,
    scenarioState = nil,
    objectives = nil,
    objectiveLookup = nil
}

local function updateTurnOrder()
    if not state.turnManager then
        state.turnOrder = nil
        return
    end
    state.turnOrder = state.turnManager:getTurnOrder()
end

local function clearAttackPreview()
    state.attackPreview = false
    state.attackTiles = nil
end

local function refreshAttackTiles()
    if not state.selectedUnit or not state.battleSystem then
        clearAttackPreview()
        return
    end

    if state.battleSystem:hasActed() then
        clearAttackPreview()
        return
    end

    if state.attackPreview then
        state.attackTiles = state.battleSystem:getAttackableTiles(state.selectedUnit)
    else
        state.attackTiles = nil
    end
end

local function refreshHighlights()
    if not state.selectedUnit or not state.battleSystem then
        state.moveTiles = nil
        clearAttackPreview()
        return
    end
    if state.battleSystem:hasMoved() then
        state.moveTiles = { { col = state.selectedUnit.col, row = state.selectedUnit.row } }
    else
        state.moveTiles = state.battleSystem:getReachableTiles(state.selectedUnit)
    end
    refreshAttackTiles()
end

local function createScenarioContext(extras)
    local context = {}
    if extras then
        for key, value in pairs(extras) do
            context[key] = value
        end
    end
    context.battleSystem = state.battleSystem
    context.battlefield = state.battlefield
    context.turnManager = state.turnManager
    context.scenario = state.scenario
    context.scenarioState = state.scenarioState
    context.objectives = state.objectives

    function context:countFactionUnits(faction)
        local count = 0
        if not state.battlefield then
            return count
        end
        for _, unit in ipairs(state.battlefield.units or {}) do
            if unit.faction == faction then
                count = count + 1
            end
        end
        return count
    end

    function context:listObjectives(filterType)
        local results = {}
        for _, objective in ipairs(state.objectives or {}) do
            if not filterType or objective.type == filterType then
                results[#results + 1] = objective
            end
        end
        return results
    end

    return context
end

local function triggerScenarioHook(hookName, extras)
    if not state.scenario or not state.scenario.hooks then
        return
    end
    local hook = state.scenario.hooks[hookName]
    if hook then
        hook(createScenarioContext(extras))
    end
end

local function initializeObjectives(scenario)
    state.objectives = {}
    state.objectiveLookup = {}
    if not scenario or not scenario.objectives then
        return
    end
    for _, definition in ipairs(scenario.objectives) do
        local entry = {
            id = definition.id,
            type = definition.type or "primary",
            description = definition.description or "",
            status = definition.initialStatus,
            details = definition.initialDetails,
            evaluate = definition.evaluate
        }
        state.objectives[#state.objectives + 1] = entry
        if entry.id then
            state.objectiveLookup[entry.id] = entry
        end
    end
end

local function updateObjectives(outcome)
    if not state.objectives then
        return
    end

    local changed = false
    local context = createScenarioContext({ outcome = outcome })

    for _, objective in ipairs(state.objectives) do
        if objective.evaluate then
            local status, details = objective.evaluate(context)
            if status and status ~= objective.status then
                objective.status = status
                changed = true
            end
            if details ~= objective.details then
                objective.details = details
                changed = true
            end
        end
    end

    if changed then
        triggerScenarioHook("onObjectivesUpdated", { outcome = outcome })
    end
end

local function evaluateBattleState()
    if not state.battleSystem then
        return
    end
    local outcome = state.battleSystem:checkBattleOutcome()
    state.battleOutcome = outcome
    updateObjectives(outcome)
end

local function instantiateScenarioUnits(scenario)
    local units = {}
    if not scenario or not scenario.units then
        return units
    end
    for index, unitDefinition in ipairs(scenario.units) do
        units[index] = Unit.new(unitDefinition)
    end
    return units
end

local function formatObjectiveStatus(status)
    if not status or status == "" then
        return "In progress"
    end
    local label = status:gsub("_", " ")
    return label:sub(1, 1):upper() .. label:sub(2)
end

local function initializeScenario(scenario)
    state.scenario = scenario
    if scenario and scenario.createState then
        state.scenarioState = scenario.createState()
    else
        state.scenarioState = {}
    end

    state.selectedUnit = nil
    state.moveTiles = nil
    state.attackTiles = nil
    state.battleOutcome = nil
    state.turnOrder = nil
    state.attackPreview = false

    if not scenario or not scenario.grid then
        return
    end

    state.grid = Grid.new(scenario.grid.width, scenario.grid.height, scenario.grid.tileSize)
    state.battlefield = Battlefield.new(state.grid)

    local units = instantiateScenarioUnits(scenario)
    local alliedCount = 0
    for _, unit in ipairs(units) do
        if unit.faction == "allies" then
            alliedCount = alliedCount + 1
        end
        state.battlefield:addUnit(unit, unit.col, unit.row)
    end

    state.scenarioState.initialAllies = alliedCount

    state.turnManager = TurnManager.new(units)
    state.battleSystem = BattleSystem.new({
        battlefield = state.battlefield,
        turnManager = state.turnManager,
        scenario = scenario,
        scenarioState = state.scenarioState
    })
    state.enemyAI = EnemyAI.new({ battleSystem = state.battleSystem })

    initializeObjectives(scenario)
    updateObjectives(nil)

    local current = state.turnManager:currentUnit()
    state.cursor = Cursor.new(state.grid, current and current.col or 1, current and current.row or 1)
    updateTurnOrder()

    if current then
        beginTurn(current)
    end
end

local function ensureCurrentSelection()
    if state.selectedUnit then
        return state.selectedUnit
    end

    local current = state.turnManager and state.turnManager:currentUnit() or nil
    if current then
        state.selectedUnit = current
        refreshHighlights()
    end
    return state.selectedUnit
end

local function enterAttackPreview()
    local unit = ensureCurrentSelection()
    if not unit or not state.battleSystem then
        return nil
    end

    if state.battleSystem:hasActed() then
        return nil
    end

    state.attackPreview = true
    state.attackTiles = state.battleSystem:getAttackableTiles(unit)
    return unit
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
    local y = 16

    if state.scenario then
        love.graphics.print(string.format("Scenario: %s", state.scenario.name or state.scenario.id), 16, y)
        y = y + 24
        if state.scenario.description then
            love.graphics.print(state.scenario.description, 16, y)
            y = y + 24
        end
    end

    local current = state.turnManager and state.turnManager:currentUnit() or nil
    if current then
        love.graphics.print(string.format("Current Turn: %s (%s)", current.name, current.faction), 16, y)
    else
        love.graphics.print("Current Turn: none", 16, y)
    end
    y = y + 24

    if state.selectedUnit then
        love.graphics.print(string.format("Selected: %s | HP %d/%d", state.selectedUnit.name, state.selectedUnit.hp, state.selectedUnit.maxHp), 16, y)
    else
        love.graphics.print("Selected: none", 16, y)
    end
    y = y + 24

    if state.objectives and #state.objectives > 0 then
        love.graphics.print("Objectives:", 16, y)
        y = y + 20
        for _, objective in ipairs(state.objectives) do
            local statusLabel = formatObjectiveStatus(objective.status)
            love.graphics.print(string.format("- [%s] %s", statusLabel, objective.description), 24, y)
            y = y + 20
            if objective.details and objective.details ~= "" then
                love.graphics.print(string.format("  %s", objective.details), 32, y)
                y = y + 18
            end
        end
    end

    if state.battleOutcome then
        local message
        if state.battleOutcome.draw then
            message = "Battle complete: Draw"
        else
            message = string.format("Battle complete: %s win", state.battleOutcome.winner)
        end
        love.graphics.print(message, 16, y)
        y = y + 24
        if state.battleOutcome.reason and state.battleOutcome.reason ~= "" then
            love.graphics.print("Reason: " .. state.battleOutcome.reason, 16, y)
            y = y + 24
        end
    end

    if state.turnOrder and #state.turnOrder > 0 and state.turnManager then
        local labels = {}
        local currentIndex = state.turnManager:getCurrentIndex()
        for index, unit in ipairs(state.turnOrder) do
            local marker = index == currentIndex and "*" or " "
            labels[#labels + 1] = string.format("%s%s", marker, unit.name)
        end
        love.graphics.print("Turn Order: " .. table.concat(labels, " -> "), 16, y)
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
    clearAttackPreview()

    if state.cursor then
        state.cursor:setPosition(unit.col, unit.row)
    end

    updateTurnOrder()
    triggerScenarioHook("onTurnStart", { unit = unit })

    if unit.faction == "enemies" and state.enemyAI then
        local actions = state.enemyAI:takeTurn(unit)
        if actions.attacked or actions.moved then
            refreshHighlights()
        end
        evaluateBattleState()
        updateTurnOrder()
        if not state.battleOutcome then
            local nextUnit = state.battleSystem:endTurn()
            evaluateBattleState()
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
        clearAttackPreview()
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
    clearAttackPreview()
    state.battleSystem:move(state.selectedUnit, state.cursor.col, state.cursor.row)
    refreshHighlights()
end

local function attackTargetAtCursor()
    local unit = enterAttackPreview()
    if not unit then
        return
    end

    refreshAttackTiles()

    local target = state.battlefield:getUnitAt(state.cursor.col, state.cursor.row)
    if not target or not state.battleSystem:canAttack(unit, target) then
        return
    end

    state.battleSystem:attack(unit, target)
    clearAttackPreview()
    refreshHighlights()
    evaluateBattleState()
    updateTurnOrder()
end

local function endTurn()
    state.selectedUnit = nil
    state.moveTiles = nil
    clearAttackPreview()
    if not state.battleSystem then
        return
    end
    local nextUnit = state.battleSystem:endTurn()
    evaluateBattleState()
    updateTurnOrder()
    if nextUnit then
        beginTurn(nextUnit)
    end
end

function love.load()
    state.font = love.graphics.newFont(16)
    love.graphics.setBackgroundColor(0.08, 0.09, 0.12)
    initializeScenario(Scenarios.getDefaultScenario())
    evaluateBattleState()
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
    drawHighlightTiles(state.grid, state.attackTiles, { 0.9, 0.3, 0.3, 0.25 })
    drawUnits(state.grid, state.battlefield, state.selectedUnit)
    drawCursor(state.grid, state.cursor)
    drawHud()
end

