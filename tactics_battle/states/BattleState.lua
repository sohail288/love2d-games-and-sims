local Grid = require("tactics_battle.world.Grid")
local Unit = require("tactics_battle.world.Unit")
local Battlefield = require("tactics_battle.world.Battlefield")
local TurnManager = require("tactics_battle.systems.TurnManager")
local BattleSystem = require("tactics_battle.systems.BattleSystem")
local BattleFlowStateMachine = require("tactics_battle.systems.BattleFlowStateMachine")
local EnemyAI = require("tactics_battle.systems.EnemyAI")
local Cursor = require("tactics_battle.ui.Cursor")
local Scenarios = require("tactics_battle.scenarios.init")

local BattleState = {}
BattleState.__index = BattleState

local orientationVectors = {
    north = { dx = 0, dy = -1 },
    south = { dx = 0, dy = 1 },
    east = { dx = 1, dy = 0 },
    west = { dx = -1, dy = 0 }
}

local orientationLabels = {
    north = "North",
    south = "South",
    east = "East",
    west = "West"
}

local keyOrientationMap = {
    up = "north",
    down = "south",
    left = "west",
    right = "east"
}

local actionLabels = {
    attack = "Attack",
    move = "Move",
    skip = "Skip Turn"
}

local clearAttackPreview
local refreshAttackTiles
local refreshHighlights

local function clearActionMenu(scene)
    scene.actionMenu = nil
end

local function openActionMenu(scene, unit, actions)
    scene.activeAction = nil
    scene.availableActions = actions

    if not actions or #actions == 0 then
        clearActionMenu(scene)
        return
    end

    local menu = {
        unit = unit,
        items = {},
        selectedIndex = 1,
        step = scene.turnStep or 1,
        actions = actions
    }

    local seen = {}
    for _, actionId in ipairs(actions) do
        if actionLabels[actionId] and not seen[actionId] then
            menu.items[#menu.items + 1] = { id = actionId, label = actionLabels[actionId] }
            seen[actionId] = true
        end
    end

    menu.items[#menu.items + 1] = { id = "skip", label = actionLabels.skip }

    if #menu.items == 0 then
        clearActionMenu(scene)
        return
    end

    scene.actionMenu = menu
    clearAttackPreview(scene)
    scene.moveTiles = nil

    if scene.cursor and unit then
        scene.cursor:setPosition(unit.col, unit.row)
    end
end

local function adjustActionMenuSelection(scene, delta)
    local menu = scene.actionMenu
    if not menu or not menu.items or #menu.items == 0 then
        return
    end

    local count = #menu.items
    local index = ((menu.selectedIndex - 1 + delta) % count) + 1
    menu.selectedIndex = index
end

local function confirmActionMenuSelection(scene)
    local menu = scene.actionMenu
    if not menu or not menu.items then
        return
    end

    local choice = menu.items[menu.selectedIndex]
    if not choice then
        return
    end

    if choice.id == "skip" then
        clearActionMenu(scene)
        scene.availableActions = nil
        scene.activeAction = nil
        if scene.flowMachine then
            scene.flowMachine:skipTurn()
        end
        return
    end

    local unit = scene.selectedUnit
    if not unit then
        clearActionMenu(scene)
        return
    end

    clearActionMenu(scene)
    scene.activeAction = { type = choice.id, step = menu.step }

    if choice.id == "move" then
        scene.attackPreview = false
        refreshHighlights(scene)
    elseif choice.id == "attack" then
        scene.attackPreview = true
        refreshAttackTiles(scene)
        scene.moveTiles = { { col = unit.col, row = unit.row } }
    end
end

local function newScene()
    return {
        grid = nil,
        battlefield = nil,
        turnManager = nil,
        cursor = nil,
        selectedUnit = nil,
        font = nil,
        moveTiles = nil,
        attackTiles = nil,
        battleOutcome = nil,
        battleOutcomeHandled = false,
        battleSystem = nil,
        enemyAI = nil,
        turnOrder = nil,
        attackPreview = false,
        scenario = nil,
        scenarioState = nil,
        objectives = nil,
        objectiveLookup = nil,
        timeUnits = 0,
        movementAnimation = nil,
        movementDuration = 0.18,
        flowMachine = nil,
        onComplete = nil,
        orientationSelection = nil,
        actionMenu = nil,
        activeAction = nil,
        turnStep = 1,
        availableActions = nil
    }
end

local function updateTurnOrder(scene)
    if not scene.turnManager then
        scene.turnOrder = nil
        return
    end
    scene.turnOrder = scene.turnManager:getTurnOrder()
end

clearAttackPreview = function(scene)
    scene.attackPreview = false
    scene.attackTiles = nil
end

refreshAttackTiles = function(scene)
    if not scene.selectedUnit or not scene.battleSystem then
        clearAttackPreview(scene)
        return
    end

    if scene.battleSystem:hasActed() then
        clearAttackPreview(scene)
        return
    end

    if scene.attackPreview then
        scene.attackTiles = scene.battleSystem:getAttackableTiles(scene.selectedUnit)
    else
        scene.attackTiles = nil
    end
end

refreshHighlights = function(scene)
    if not scene.selectedUnit or not scene.battleSystem then
        scene.moveTiles = nil
        clearAttackPreview(scene)
        return
    end
    local activeType = scene.activeAction and scene.activeAction.type or nil
    if activeType == "attack" then
        scene.moveTiles = { { col = scene.selectedUnit.col, row = scene.selectedUnit.row } }
        scene.attackPreview = true
    else
        if scene.battleSystem:hasMoved() then
            scene.moveTiles = { { col = scene.selectedUnit.col, row = scene.selectedUnit.row } }
        else
            scene.moveTiles = scene.battleSystem:getReachableTiles(scene.selectedUnit)
        end
        if activeType ~= "attack" then
            scene.attackPreview = false
        end
    end
    refreshAttackTiles(scene)
end

local function beginOrientationSelection(scene, unit, reason)
    if not unit then
        return
    end

    scene.orientationSelection = {
        unit = unit,
        direction = unit.getOrientation and unit:getOrientation() or unit.orientation or "south",
        reason = reason
    }
    scene.moveTiles = nil
    clearAttackPreview(scene)
    clearActionMenu(scene)
    scene.activeAction = nil
    scene.availableActions = nil
    if scene.cursor then
        scene.cursor:setPosition(unit.col, unit.row)
    end
end

local function setOrientationDirection(scene, direction)
    if not scene.orientationSelection then
        return
    end
    if direction then
        scene.orientationSelection.direction = direction
    end
end

local function confirmOrientationSelection(scene)
    local selection = scene.orientationSelection
    if not selection or not selection.unit then
        return
    end
    if not scene.flowMachine then
        selection.unit:setOrientation(selection.direction)
        scene.orientationSelection = nil
        return
    end

    local direction = selection.direction or selection.unit:getOrientation()
    selection.unit:setOrientation(direction)
    scene.orientationSelection = nil
    scene.flowMachine:onOrientationChosen(direction)
end

local function advanceTime(scene, cost)
    cost = cost or 1
    scene.timeUnits = (scene.timeUnits or 0) + cost
end

local function isAnimating(scene)
    return scene.movementAnimation ~= nil
end

local function startMovementAnimation(scene, unit, path)
    if not path or #path < 2 then
        return
    end

    unit:setRenderPosition(path[1].col, path[1].row)
    scene.movementAnimation = {
        unit = unit,
        path = path,
        segment = 1,
        progress = 0,
        duration = scene.movementDuration or 0.18
    }
end

local function updateMovementAnimation(scene, dt)
    local animation = scene.movementAnimation
    if not animation then
        return false
    end

    local path = animation.path
    local duration = animation.duration
    if duration <= 0 then
        duration = 0.01
    end

    animation.progress = animation.progress + dt
    while animation.progress >= duration and animation.segment < #path do
        animation.progress = animation.progress - duration
        animation.segment = animation.segment + 1
        if animation.segment >= #path then
            animation.unit:setRenderPosition(animation.unit.col, animation.unit.row)
            scene.movementAnimation = nil
            return true
        end
    end

    if animation.segment >= #path then
        animation.unit:setRenderPosition(animation.unit.col, animation.unit.row)
        scene.movementAnimation = nil
        return true
    end

    local from = path[animation.segment]
    local to = path[animation.segment + 1]
    local t = math.min(animation.progress / duration, 1)
    local col = from.col + (to.col - from.col) * t
    local row = from.row + (to.row - from.row) * t
    animation.unit:setRenderPosition(col, row)
    return false
end

local function createScenarioContext(scene, extras)
    local context = {}
    if extras then
        for key, value in pairs(extras) do
            context[key] = value
        end
    end
    context.battleSystem = scene.battleSystem
    context.battlefield = scene.battlefield
    context.turnManager = scene.turnManager
    context.scenario = scene.scenario
    context.scenarioState = scene.scenarioState
    context.objectives = scene.objectives

    function context:countFactionUnits(faction)
        local count = 0
        if not scene.battlefield then
            return count
        end
        for _, unit in ipairs(scene.battlefield.units or {}) do
            if unit.faction == faction then
                count = count + 1
            end
        end
        return count
    end

    function context:listObjectives(filterType)
        local results = {}
        for _, objective in ipairs(scene.objectives or {}) do
            if not filterType or objective.type == filterType then
                results[#results + 1] = objective
            end
        end
        return results
    end

    return context
end

local function triggerScenarioHook(scene, hookName, extras)
    if not scene.scenario or not scene.scenario.hooks then
        return
    end
    local hook = scene.scenario.hooks[hookName]
    if hook then
        hook(createScenarioContext(scene, extras))
    end
end

local function initializeObjectives(scene, scenario)
    scene.objectives = {}
    scene.objectiveLookup = {}
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
        scene.objectives[#scene.objectives + 1] = entry
        if entry.id then
            scene.objectiveLookup[entry.id] = entry
        end
    end
end

local function updateObjectives(scene, outcome)
    if not scene.objectives then
        return
    end

    local changed = false
    local context = createScenarioContext(scene, { outcome = outcome })

    for _, objective in ipairs(scene.objectives) do
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
        triggerScenarioHook(scene, "onObjectivesUpdated", { outcome = outcome })
    end
end

local function evaluateBattleState(scene)
    if not scene.battleSystem then
        return
    end
    local outcome = scene.battleSystem:checkBattleOutcome()
    scene.battleOutcome = outcome
    updateObjectives(scene, outcome)
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

local function beginTurn(scene, unit)
    if not unit or not scene.battleSystem or scene.battleOutcome then
        return
    end

    if scene.battleSystem.currentUnit ~= unit then
        scene.battleSystem:startTurn(unit)
    end

    scene.selectedUnit = unit
    scene.moveTiles = nil
    clearAttackPreview(scene)
    scene.orientationSelection = nil
    clearActionMenu(scene)
    scene.activeAction = nil
    scene.availableActions = nil
    scene.turnStep = 1

    if scene.cursor then
        scene.cursor:setPosition(unit.col, unit.row)
    end

    if scene.flowMachine then
        scene.flowMachine:beginTurn(unit)
    end

    updateTurnOrder(scene)
    triggerScenarioHook(scene, "onTurnStart", { unit = unit })

    if unit.faction == "enemies" and scene.enemyAI then
        local actions = scene.enemyAI:takeTurn(unit)
        if actions.path and #actions.path >= 2 then
            startMovementAnimation(scene, unit, actions.path)
        end
        if actions.attacked or actions.moved then
            refreshHighlights(scene)
        end
        evaluateBattleState(scene)
        updateTurnOrder(scene)
        if not scene.battleOutcome then
            local nextUnit, timeCost = scene.battleSystem:endTurn()
            advanceTime(scene, timeCost)
            evaluateBattleState(scene)
            updateTurnOrder(scene)
            if nextUnit then
                beginTurn(scene, nextUnit)
            end
        end
    end
end

local function endTurn(scene)
    scene.selectedUnit = nil
    scene.moveTiles = nil
    clearAttackPreview(scene)
    scene.orientationSelection = nil
    if not scene.battleSystem then
        return
    end
    local nextUnit, timeCost = scene.battleSystem:endTurn()
    advanceTime(scene, timeCost)
    evaluateBattleState(scene)
    updateTurnOrder(scene)
    if nextUnit then
        beginTurn(scene, nextUnit)
    end
end

local function initializeScenario(scene, scenario)
    scene.scenario = scenario
    if scenario and scenario.createState then
        scene.scenarioState = scenario.createState()
    else
        scene.scenarioState = {}
    end

    scene.selectedUnit = nil
    scene.moveTiles = nil
    scene.attackTiles = nil
    scene.battleOutcome = nil
    scene.turnOrder = nil
    scene.attackPreview = false
    scene.timeUnits = 0
    scene.movementAnimation = nil
    scene.actionMenu = nil
    scene.activeAction = nil
    scene.availableActions = nil
    scene.turnStep = 1

    if not scenario or not scenario.grid then
        return
    end

    scene.grid = Grid.new(scenario.grid.width, scenario.grid.height, scenario.grid.tileSize)
    scene.battlefield = Battlefield.new(scene.grid)

    local units = instantiateScenarioUnits(scenario)
    local alliedCount = 0
    for _, unit in ipairs(units) do
        if unit.faction == "allies" then
            alliedCount = alliedCount + 1
        end
        scene.battlefield:addUnit(unit, unit.col, unit.row)
        unit:setRenderPosition(unit.col, unit.row)
    end

    scene.scenarioState.initialAllies = alliedCount

    scene.turnManager = TurnManager.new(units)
    scene.battleSystem = BattleSystem.new({
        battlefield = scene.battlefield,
        turnManager = scene.turnManager,
        scenario = scenario,
        scenarioState = scene.scenarioState
    })
    scene.flowMachine = BattleFlowStateMachine.new({
        battleSystem = scene.battleSystem,
        battlefield = scene.battlefield,
        onAwaitingInput = function()
            refreshHighlights(scene)
        end,
        onActionMenuRequested = function(unit, actions)
            openActionMenu(scene, unit, actions)
        end,
        onActionComplete = function()
            evaluateBattleState(scene)
            updateTurnOrder(scene)
        end,
        onNoActionsRemaining = function()
            refreshHighlights(scene)
        end,
        onOrientationPrompt = function(unit, reason)
            beginOrientationSelection(scene, unit, reason)
        end,
        onOrientationComplete = function()
            scene.orientationSelection = nil
        end,
        onTurnComplete = function()
            endTurn(scene)
        end
    })
    scene.enemyAI = EnemyAI.new({ battleSystem = scene.battleSystem })

    initializeObjectives(scene, scenario)
    updateObjectives(scene, nil)

    local current = scene.turnManager:currentUnit()
    scene.cursor = Cursor.new(scene.grid, current and current.col or 1, current and current.row or 1)
    updateTurnOrder(scene)

    if current then
        beginTurn(scene, current)
    end
end

local function ensureCurrentSelection(scene)
    if scene.selectedUnit then
        return scene.selectedUnit
    end

    local current = scene.turnManager and scene.turnManager:currentUnit() or nil
    if current then
        scene.selectedUnit = current
        refreshHighlights(scene)
    end
    return scene.selectedUnit
end

local function enterAttackPreview(scene)
    local unit = ensureCurrentSelection(scene)
    if not unit or not scene.battleSystem then
        return nil
    end

    if scene.activeAction and scene.activeAction.type ~= "attack" then
        return nil
    end

    if scene.battleSystem:hasActed() then
        return nil
    end

    scene.attackPreview = true
    scene.attackTiles = scene.battleSystem:getAttackableTiles(unit)
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

local function drawUnits(grid, battlefield, selectedUnit, orientationSelection)
    local offsetX, offsetY = centerOffsets(grid)
    for _, unit in ipairs(battlefield.units) do
        local col, row = unit:getRenderPosition()
        local x = offsetX + (col - 1) * grid.tileSize
        local y = offsetY + (row - 1) * grid.tileSize
        local r, g, b = unitColor(unit)
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", x + 6, y + 6, grid.tileSize - 12, grid.tileSize - 12, 6, 6)
        if selectedUnit and selectedUnit.id == unit.id then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x + 4, y + 4, grid.tileSize - 8, grid.tileSize - 8, 6, 6)
        end
        local orientation = unit.getOrientation and unit:getOrientation() or unit.orientation
        if orientationSelection and orientationSelection.unit and orientationSelection.unit.id == unit.id then
            orientation = orientationSelection.direction or orientation
        end
        local vector = orientationVectors[orientation or "south"]
        if vector then
            local arrowLength = grid.tileSize / 2 - 8
            local centerX = x + grid.tileSize / 2
            local centerY = y + grid.tileSize / 2
            if orientationSelection and orientationSelection.unit and orientationSelection.unit.id == unit.id then
                love.graphics.setColor(1, 0.9, 0.4)
            else
                love.graphics.setColor(1, 0.85, 0.2)
            end
            love.graphics.setLineWidth(2)
            love.graphics.line(centerX, centerY, centerX + vector.dx * arrowLength, centerY + vector.dy * arrowLength)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(unit.name, x + 8, y + grid.tileSize - 20)
    end
end

local function drawHud(scene)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(scene.font)
    local y = 16

    if scene.scenario then
        love.graphics.print(string.format("Scenario: %s", scene.scenario.name or scene.scenario.id), 16, y)
        y = y + 24
        if scene.scenario.description then
            love.graphics.print(scene.scenario.description, 16, y)
            y = y + 24
        end
    end

    local current = scene.turnManager and scene.turnManager:currentUnit() or nil
    if current then
        love.graphics.print(string.format("Current Turn: %s (%s)", current.name, current.faction), 16, y)
    else
        love.graphics.print("Current Turn: none", 16, y)
    end
    y = y + 24

    love.graphics.print(string.format("Time Units Elapsed: %d", scene.timeUnits or 0), 16, y)
    y = y + 24

    if scene.selectedUnit then
        love.graphics.print(string.format("Selected: %s | HP %d/%d", scene.selectedUnit.name, scene.selectedUnit.hp, scene.selectedUnit.maxHp), 16, y)
    else
        love.graphics.print("Selected: none", 16, y)
    end
    y = y + 24

    if scene.objectives and #scene.objectives > 0 then
        love.graphics.print("Objectives:", 16, y)
        y = y + 20
        for _, objective in ipairs(scene.objectives) do
            local statusLabel = formatObjectiveStatus(objective.status)
            love.graphics.print(string.format("- [%s] %s", statusLabel, objective.description), 24, y)
            y = y + 20
            if objective.details and objective.details ~= "" then
                love.graphics.print(string.format("  %s", objective.details), 32, y)
                y = y + 18
            end
        end
    end

    if scene.battleOutcome then
        local message
        if scene.battleOutcome.draw then
            message = "Battle complete: Draw"
        else
            message = string.format("Battle complete: %s win", scene.battleOutcome.winner)
        end
        love.graphics.print(message, 16, y)
        y = y + 24
        if scene.battleOutcome.reason and scene.battleOutcome.reason ~= "" then
            love.graphics.print("Reason: " .. scene.battleOutcome.reason, 16, y)
            y = y + 24
        end
    end

    if scene.turnOrder and #scene.turnOrder > 0 and scene.turnManager then
        local labels = {}
        local currentIndex = scene.turnManager:getCurrentIndex()
        for index, unit in ipairs(scene.turnOrder) do
            local marker = index == currentIndex and "*" or " "
            labels[#labels + 1] = string.format("%s%s", marker, unit.name)
        end
        love.graphics.print("Turn Order: " .. table.concat(labels, " -> "), 16, y)
    end

    local bottomY = love.graphics.getHeight() - 32
    if scene.orientationSelection then
        local selection = scene.orientationSelection
        local label = orientationLabels[selection.direction] or selection.direction or "South"
        love.graphics.print(string.format("Choose facing: %s", label), 16, bottomY - 24)
        love.graphics.print("Use arrows to change, Enter to confirm. Facing affects critical hits.", 16, bottomY)
    else
        love.graphics.print("Controls: Arrows move cursor, Space open menu, Enter confirm, Tab skip turn, P pause", 16, bottomY)
    end
end

local function drawActionMenu(scene)
    local menu = scene.actionMenu
    if not menu or not menu.items or #menu.items == 0 then
        return
    end

    local width = 240
    local lineHeight = 24
    local height = 48 + #menu.items * lineHeight
    local x = love.graphics.getWidth() - width - 32
    local y = 72

    love.graphics.setColor(0.08, 0.1, 0.14, 0.85)
    love.graphics.rectangle("fill", x, y, width, height, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 10, 10)

    local stepLabel = string.format("Step %d: Choose action", menu.step or 1)
    love.graphics.print(stepLabel, x + 16, y + 14)

    local entryY = y + 40
    for index, item in ipairs(menu.items) do
        if index == menu.selectedIndex then
            love.graphics.setColor(0.95, 0.85, 0.4)
        else
            love.graphics.setColor(0.85, 0.9, 1)
        end
        love.graphics.print(item.label, x + 20, entryY)
        entryY = entryY + lineHeight
    end
    love.graphics.setColor(1, 1, 1)
end

local function moveSelectedUnit(scene)
    if not scene.selectedUnit or not scene.battleSystem or isAnimating(scene) then
        return
    end
    if not scene.activeAction or scene.activeAction.type ~= "move" then
        return
    end
    local destinationCol, destinationRow = scene.cursor.col, scene.cursor.row
    if not scene.battleSystem:canMove(scene.selectedUnit, destinationCol, destinationRow) then
        return
    end
    local path = scene.battleSystem:findPath(scene.selectedUnit, destinationCol, destinationRow)
    if not path or #path < 2 then
        return
    end
    clearAttackPreview(scene)
    scene.moveTiles = nil
    scene.battleSystem:move(scene.selectedUnit, destinationCol, destinationRow)
    local hasAnimation = path and #path >= 2
    startMovementAnimation(scene, scene.selectedUnit, path)
    if scene.cursor then
        scene.cursor:setPosition(destinationCol, destinationRow)
    end
    if scene.flowMachine then
        scene.flowMachine:onMoveCommitted(hasAnimation)
        if not hasAnimation then
            scene.flowMachine:onAnimationsComplete("move")
        end
    end
    scene.activeAction = nil
    scene.availableActions = nil
    scene.turnStep = (scene.turnStep or 1) + 1
end

local function attackTargetAtCursor(scene)
    if isAnimating(scene) then
        return
    end
    if not scene.activeAction or scene.activeAction.type ~= "attack" then
        return
    end
    local unit = enterAttackPreview(scene)
    if not unit then
        return
    end

    refreshAttackTiles(scene)

    local target = scene.battlefield:getUnitAt(scene.cursor.col, scene.cursor.row)
    if not target or not scene.battleSystem:canAttack(unit, target) then
        return
    end

    scene.battleSystem:attack(unit, target)
    clearAttackPreview(scene)
    if scene.flowMachine then
        scene.flowMachine:onAttackCommitted(false)
        scene.flowMachine:onAnimationsComplete("attack")
    end
    scene.activeAction = nil
    scene.availableActions = nil
    scene.turnStep = (scene.turnStep or 1) + 1
end

function BattleState.new()
    local self = setmetatable({}, BattleState)
    self.scene = newScene()
    return self
end

function BattleState:getScene()
    return self.scene
end

function BattleState:enter(game, params)
    local scenario = params and params.scenario or Scenarios.getDefaultScenario()
    local context = game:getContext()
    self.scene.font = context.font
    self.scene.onComplete = params and params.onComplete or nil
    self.scene.battleOutcomeHandled = false

    if not self.scene.font and love and love.graphics and love.graphics.newFont then
        self.scene.font = love.graphics.newFont(16)
        context.font = self.scene.font
    end

    initializeScenario(self.scene, scenario)
    evaluateBattleState(self.scene)
end

function BattleState:exit(_game)
    self.scene = newScene()
end

function BattleState:update(game, dt)
    local completed = false
    if dt then
        completed = updateMovementAnimation(self.scene, dt) or false
    end
    if completed and self.scene.flowMachine then
        self.scene.flowMachine:onAnimationsComplete("move")
    end
    if self.scene.flowMachine then
        self.scene.flowMachine:update(dt or 0)
    end
    if self.scene.battleOutcome and not self.scene.battleOutcomeHandled then
        self.scene.battleOutcomeHandled = true
        local callback = self.scene.onComplete
        if callback then
            self.scene.onComplete = nil
            callback(game, self.scene.battleOutcome)
        end
    end
end

function BattleState:render(_game)
    if not self.scene.grid then
        return
    end
    drawGrid(self.scene.grid)
    drawHighlightTiles(self.scene.grid, self.scene.moveTiles, { 0.2, 0.5, 0.8, 0.25 })
    drawHighlightTiles(self.scene.grid, self.scene.attackTiles, { 0.9, 0.3, 0.3, 0.25 })
    drawUnits(self.scene.grid, self.scene.battlefield, self.scene.selectedUnit, self.scene.orientationSelection)
    drawCursor(self.scene.grid, self.scene.cursor)
    drawHud(self.scene)
    drawActionMenu(self.scene)
end

function BattleState:keypressed(game, key)
    if key == "escape" then
        love.event.quit()
        return
    end

    if self.scene.orientationSelection then
        local direction = keyOrientationMap[key]
        if direction then
            setOrientationDirection(self.scene, direction)
        elseif key == "return" or key == "kpenter" or key == "space" or key == "tab" then
            confirmOrientationSelection(self.scene)
        end
        return
    end

    if self.scene.actionMenu and self.scene.actionMenu.items then
        if key == "up" then
            adjustActionMenuSelection(self.scene, -1)
        elseif key == "down" then
            adjustActionMenuSelection(self.scene, 1)
        elseif key == "return" or key == "kpenter" or key == "space" then
            confirmActionMenuSelection(self.scene)
        elseif key == "tab" then
            clearActionMenu(self.scene)
            if self.scene.flowMachine then
                self.scene.flowMachine:skipTurn()
            end
        end
        return
    end

    if isAnimating(self.scene) then
        return
    end

    if not self.scene.cursor then
        return
    end

    if key == "up" then
        self.scene.cursor:move(0, -1)
    elseif key == "down" then
        self.scene.cursor:move(0, 1)
    elseif key == "left" then
        self.scene.cursor:move(-1, 0)
    elseif key == "right" then
        self.scene.cursor:move(1, 0)
    elseif key == "return" or key == "kpenter" then
        if self.scene.activeAction and self.scene.activeAction.type == "move" then
            moveSelectedUnit(self.scene)
        elseif self.scene.activeAction and self.scene.activeAction.type == "attack" then
            attackTargetAtCursor(self.scene)
        else
            if self.scene.availableActions and #self.scene.availableActions > 0 then
                openActionMenu(self.scene, self.scene.selectedUnit, self.scene.availableActions)
            end
        end
    elseif key == "space" then
        if self.scene.activeAction then
            openActionMenu(self.scene, self.scene.selectedUnit, self.scene.availableActions or {})
        elseif self.scene.availableActions and #self.scene.availableActions > 0 then
            openActionMenu(self.scene, self.scene.selectedUnit, self.scene.availableActions)
        end
    elseif key == "tab" then
        clearActionMenu(self.scene)
        self.scene.activeAction = nil
        self.scene.availableActions = nil
        if self.scene.flowMachine then
            self.scene.flowMachine:skipTurn()
        else
            endTurn(self.scene)
        end
    elseif key == "p" then
        local pauseState = game:getState("pause")
        if pauseState then
            game:changeState("pause", { previous = "battle" })
        end
    end
end

return BattleState
