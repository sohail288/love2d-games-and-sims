local BattleFlowStateMachine = {}
BattleFlowStateMachine.__index = BattleFlowStateMachine

local function isPlayerUnit(unit)
    return unit and unit.faction == "allies"
end

local function tilesContainOtherPosition(tiles, unit)
    if not tiles then
        return false
    end
    for _, tile in ipairs(tiles) do
        if tile.col ~= unit.col or tile.row ~= unit.row then
            return true
        end
    end
    return false
end

function BattleFlowStateMachine.new(args)
    assert(args and args.battleSystem, "battleSystem required")

    local instance = {
        battleSystem = args.battleSystem,
        battlefield = args.battlefield or args.battleSystem.battlefield,
        state = "idle",
        currentUnit = nil,
        pendingAction = nil,
        waitingForAnimation = false,
        pendingSummary = false,
        pendingTurnEnd = false,
        summaryReason = nil,
        turnEndReason = nil,
        onAwaitingInput = args.onAwaitingInput,
        onActionComplete = args.onActionComplete,
        onTurnSummary = args.onTurnSummary,
        onTurnComplete = args.onTurnComplete,
        onNoActionsRemaining = args.onNoActionsRemaining,
        onOrientationPrompt = args.onOrientationPrompt,
        onOrientationComplete = args.onOrientationComplete,
        pendingOrientation = false,
        orientationReason = nil
    }

    return setmetatable(instance, BattleFlowStateMachine)
end

function BattleFlowStateMachine:_resetTurnState()
    self.pendingAction = nil
    self.waitingForAnimation = false
    self.pendingSummary = false
    self.pendingTurnEnd = false
    self.summaryReason = nil
    self.turnEndReason = nil
    self.pendingOrientation = false
    self.orientationReason = nil
end

function BattleFlowStateMachine:beginTurn(unit)
    self.currentUnit = unit
    self.state = "idle"
    self:_resetTurnState()

    if not isPlayerUnit(unit) then
        return
    end

    self:enterAwaitingInput()
end

function BattleFlowStateMachine:enterAwaitingInput()
    if not isPlayerUnit(self.currentUnit) then
        self.state = "idle"
        return
    end

    self.state = "awaiting_input"
    if self.onAwaitingInput then
        self.onAwaitingInput(self.currentUnit)
    end

    if not self:hasRemainingActions() then
        self:queueSummary("no_actions")
    end
end

function BattleFlowStateMachine:hasRemainingActions()
    if not isPlayerUnit(self.currentUnit) then
        return false
    end

    if not self.battleSystem or not self.battlefield then
        return false
    end

    local unit = self.battleSystem.currentUnit
    if not unit or unit.id ~= self.currentUnit.id then
        unit = self.currentUnit
    end

    if not unit or not unit:isAlive() then
        return false
    end

    if not self.battleSystem:hasMoved() then
        local tiles = self.battleSystem:getReachableTiles(unit)
        if tilesContainOtherPosition(tiles, unit) then
            return true
        end
    end

    if not self.battleSystem:hasActed() then
        local targets = self.battleSystem:getAttackableTargets(unit)
        if targets and #targets > 0 then
            return true
        end
    end

    return false
end

function BattleFlowStateMachine:queueSummary(reason)
    if not isPlayerUnit(self.currentUnit) then
        return
    end

    self.state = "turn_summary"
    self.pendingSummary = true
    self.summaryReason = reason

    if reason == "no_actions" or reason == "skipped" then
        self.turnEndReason = reason
    end
end

function BattleFlowStateMachine:_requireOrientation(reason)
    if not isPlayerUnit(self.currentUnit) then
        return
    end
    if self.pendingOrientation then
        return
    end

    self.state = "choosing_orientation"
    self.pendingOrientation = true
    self.orientationReason = reason or self.turnEndReason or "completed"

    if self.onOrientationPrompt then
        self.onOrientationPrompt(self.currentUnit, self.orientationReason)
    end
end

function BattleFlowStateMachine:_transitionToEndingTurn(reason)
    if not isPlayerUnit(self.currentUnit) then
        return
    end

    self.state = "ending_turn"
    self.turnEndReason = reason or self.turnEndReason or "completed"
    self.pendingTurnEnd = true
end

function BattleFlowStateMachine:onMoveCommitted(hasAnimation)
    if self.state ~= "awaiting_input" or not isPlayerUnit(self.currentUnit) then
        return
    end

    self.state = "resolving_action"
    self.pendingAction = "move"
    self.waitingForAnimation = hasAnimation and true or false

    if not self.waitingForAnimation then
        self:queueSummary("move")
    end
end

function BattleFlowStateMachine:onAttackCommitted(hasAnimation)
    if self.state ~= "awaiting_input" or not isPlayerUnit(self.currentUnit) then
        return
    end

    self.state = "resolving_action"
    self.pendingAction = "attack"
    self.waitingForAnimation = hasAnimation and true or false

    if not self.waitingForAnimation then
        self:queueSummary("attack")
    end
end

function BattleFlowStateMachine:onAnimationsComplete(actionType)
    if not isPlayerUnit(self.currentUnit) then
        return
    end

    if self.pendingAction ~= actionType then
        return
    end

    if not self.waitingForAnimation then
        return
    end

    self.waitingForAnimation = false
    self:queueSummary(actionType)
end

function BattleFlowStateMachine:skipTurn()
    if self.state ~= "awaiting_input" or not isPlayerUnit(self.currentUnit) then
        return
    end

    self:queueSummary("skipped")
end

function BattleFlowStateMachine:_processSummary()
    self.pendingSummary = false

    local actionType = self.pendingAction
    local reason = self.summaryReason
    self.pendingAction = nil
    self.summaryReason = nil

    if self.onTurnSummary then
        self.onTurnSummary(self.currentUnit, actionType, reason)
    end

    if actionType and self.onActionComplete then
        self.onActionComplete(actionType, self.currentUnit)
    end

    if reason == "no_actions" and self.onNoActionsRemaining then
        self.onNoActionsRemaining(self.currentUnit)
    end

    if self.turnEndReason then
        self:_requireOrientation(self.turnEndReason)
        return
    end

    if self:hasRemainingActions() then
        self:enterAwaitingInput()
        return
    end

    if self.onNoActionsRemaining and reason ~= "no_actions" then
        self.onNoActionsRemaining(self.currentUnit)
    end

    if not self.turnEndReason then
        self.turnEndReason = "no_actions"
    end

    self:_requireOrientation(self.turnEndReason)
end

function BattleFlowStateMachine:update(_dt)
    while self.pendingSummary do
        self:_processSummary()
    end

    if self.pendingOrientation then
        return
    end

    if self.pendingTurnEnd then
        self.pendingTurnEnd = false
        local finishedUnit = self.currentUnit
        local reason = self.turnEndReason or "completed"
        self.state = "idle"
        self.currentUnit = nil
        self:_resetTurnState()
        if self.onTurnComplete then
            self.onTurnComplete(finishedUnit, reason)
        end
    end
end

function BattleFlowStateMachine:onOrientationChosen(orientation)
    if not isPlayerUnit(self.currentUnit) then
        return
    end
    if not self.pendingOrientation then
        return
    end

    self.pendingOrientation = false
    local reason = self.orientationReason or self.turnEndReason or "completed"
    self.orientationReason = nil

    if self.onOrientationComplete then
        self.onOrientationComplete(self.currentUnit, orientation, reason)
    end

    self:_transitionToEndingTurn(reason)
end

return BattleFlowStateMachine
