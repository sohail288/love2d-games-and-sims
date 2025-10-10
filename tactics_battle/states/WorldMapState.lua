local WorldMap = require("tactics_battle.world.WorldMap")
local defaultMapConfig = require("tactics_battle.world.default_map")
local Scenarios = require("tactics_battle.scenarios.init")

local WorldMapState = {}
WorldMapState.__index = WorldMapState

function WorldMapState.new()
    local self = setmetatable({}, WorldMapState)
    self.world = nil
    self.message = nil
    self.travelDuration = 0.6
    self.travelSegment = nil
    self.travelPath = nil
    self.travelPlan = nil
    self.traveling = false
    self.awaitingTownMenu = false
    self.random = (love and love.math and love.math.random) or math.random
    return self
end

local function ensureWorld(params, context)
    if params and params.world then
        return params.world
    end
    context.world = context.world or {}
    if not context.world.map then
        context.world.map = WorldMap.new(defaultMapConfig)
    end
    return context.world.map
end

local function mergeParams(base, extra)
    if not extra then
        return base
    end
    for key, value in pairs(extra) do
        base[key] = value
    end
    return base
end

local function returnToWorld(game, world, message, extra)
    game:changeState("world_map", mergeParams({ world = world, message = message }, extra))
end

local function travelToTown(state, game, location)
    state.world:markVisited(location.id)
    local script = location.script or { { text = string.format("%s is quiet for now.", location.name) } }
    game:changeState("cutscene", {
        title = location.name,
        script = script,
        onComplete = function(innerGame)
            returnToWorld(innerGame, state.world, string.format("Departed %s.", location.name), { awaitingTownMenu = false })
        end
    })
end

local function travelToBattlefield(state, game, location, resumePlan)
    local scenario = Scenarios.getScenario(location.scenario) or Scenarios.getDefaultScenario()
    game:changeState("battle", {
        scenario = scenario,
        onComplete = function(innerGame, outcome)
            state.world:markVisited(location.id)
            local message
            if outcome and outcome.draw then
                message = string.format("The fight at %s remains unresolved.", location.name)
            elseif outcome and outcome.winner == "players" then
                message = string.format("Victory at %s!", location.name)
                local script = location.victoryScript
                if script then
                    innerGame:changeState("cutscene", {
                        title = location.name .. " Aftermath",
                        script = script,
                        onComplete = function(gameAfter)
                            returnToWorld(gameAfter, state.world, message, { resumePlan = resumePlan })
                        end
                    })
                    return
                end
            elseif outcome and outcome.winner then
                message = string.format("Defeat at %s.", location.name)
            else
                message = string.format("The skirmish at %s has ended.", location.name)
            end
            returnToWorld(innerGame, state.world, message, { resumePlan = resumePlan })
        end
    })
end

function WorldMapState:clearTravelPlan()
    self.traveling = false
    self.travelSegment = nil
    self.travelPath = nil
    self.travelPlan = nil
end

function WorldMapState:serializeTravelPlan(traveling)
    if not self.travelPlan then
        return nil
    end
    local data = {
        ids = {},
        index = self.travelPlan.index,
        traveling = traveling ~= nil and traveling or self.traveling
    }
    for _, id in ipairs(self.travelPlan.ids) do
        table.insert(data.ids, id)
    end
    return data
end

function WorldMapState:restoreTravelPlan(plan)
    if not plan or not plan.ids then
        return
    end
    local path = {}
    for _, id in ipairs(plan.ids) do
        local location = self.world:getLocationById(id)
        if not location then
            return
        end
        table.insert(path, location)
    end
    if #path == 0 then
        return
    end
    self.travelPath = path
    self.travelPlan = {
        ids = {}
    }
    for _, id in ipairs(plan.ids) do
        table.insert(self.travelPlan.ids, id)
    end
    self.travelPlan.index = math.min(plan.index or 1, #self.travelPath)
    self.traveling = plan.traveling and (self.travelPlan.index < #self.travelPath)
    if self.traveling then
        self:advanceTravel()
        self.message = string.format("Resuming travel to %s.", self.travelPath[#self.travelPath].name)
    end
end

function WorldMapState:enter(game, params)
    local context = game:getContext()
    self.world = ensureWorld(params, context)
    self.message = params and params.message or nil
    self.awaitingTownMenu = params and params.awaitingTownMenu or false
    self.travelSegment = nil
    self.travelPath = nil
    self.travelPlan = nil
    self.traveling = false
    if params and params.resumePlan then
        self:restoreTravelPlan(params.resumePlan)
    end
    if not self.message and self.world then
        local current = self.world:getCurrent()
        if current then
            if current.type == "town" and current.mandatory then
                self.awaitingTownMenu = true
                self.message = string.format("Arrived at %s. Press Space to open the town menu.", current.name)
            else
                self.message = string.format("Currently at %s.", current.name)
            end
        end
    end
end

function WorldMapState:advanceTravel()
    if not self.travelPlan or not self.traveling then
        return
    end
    if self.travelPlan.index >= #self.travelPath then
        self:clearTravelPlan()
        return
    end
    local fromLocation = self.travelPath[self.travelPlan.index]
    local toLocation = self.travelPath[self.travelPlan.index + 1]
    self.travelSegment = {
        from = fromLocation,
        to = toLocation,
        progress = 0
    }
end

function WorldMapState:shouldTriggerBattle(location)
    local chance = location.battleChance
    if chance == nil then
        chance = 0.5
    end
    local randomValue = self.random and self.random() or math.random()
    return randomValue <= chance
end

function WorldMapState:handleArrival(game, location, isFinal)
    self.world:setCurrentLocation(location.id)
    local resumePlan
    if location.type == "battlefield" then
        if self:shouldTriggerBattle(location) then
            resumePlan = self:serializeTravelPlan(true)
            self:clearTravelPlan()
            self.message = string.format("Engaging at %s...", location.name)
            travelToBattlefield(self, game, location, resumePlan)
            return
        end
    end
    if isFinal then
        self:clearTravelPlan()
        if location.type == "town" then
            self.awaitingTownMenu = true
            self.message = string.format("Arrived at %s. Press Space to open the town menu.", location.name)
        else
            self.message = string.format("Arrived at %s.", location.name)
        end
        return
    end
    if location.mandatory then
        self:clearTravelPlan()
        if location.type == "town" then
            self.awaitingTownMenu = true
            self.message = string.format("Stopping at %s. Press Space to open the town menu.", location.name)
        else
            self.message = string.format("Stopping at %s.", location.name)
        end
        return
    end
    self.message = string.format("Passing through %s.", location.name)
end

function WorldMapState:update(game, dt)
    if not self.travelSegment or not self.travelPlan then
        return
    end
    local segment = self.travelSegment
    segment.progress = math.min(1, segment.progress + (dt or 0) / self.travelDuration)
    if segment.progress >= 1 then
        local nextIndex = self.travelPlan.index + 1
        self.travelPlan.index = nextIndex
        local isFinal = nextIndex == #self.travelPath
        self.travelSegment = nil
        self:handleArrival(game, self.travelPath[nextIndex], isFinal)
        if self.traveling and self.travelPlan and self.travelPlan.index < #self.travelPath then
            self:advanceTravel()
        end
    end
end

local function drawWorld(world, message)
    if not (love and love.graphics) then
        return
    end
    local lg = love.graphics
    lg.clear(0.07, 0.08, 0.1)
    lg.setColor(1, 1, 1)
    lg.print("World Map", 72, 60)
    local current = world:getCurrent()
    if current then
        lg.print(string.format("Current location: %s", current.name), 72, 84)
    end
    if message then
        lg.print(message, 72, 108)
    end
    local y = 156
    for index, location in ipairs(world:getLocations()) do
        local selected = index == world:getSelectedIndex()
        if selected then
            lg.setColor(0.4, 0.9, 0.6)
        else
            lg.setColor(1, 1, 1)
        end
        local label = location.name
        if world:isVisited(location.id) then
            label = label .. " (Visited)"
        end
        if location.mandatory then
            label = label .. " [Mandatory]"
        end
        lg.print(string.format("%d) %s", index, label), 72, y)
        if location.description then
            lg.setColor(0.8, 0.8, 0.9)
            lg.print(location.description, 92, y + 24)
        end
        y = y + 72
    end
    lg.setColor(1, 1, 1)
    lg.print("Use Left/Right to choose a destination. Enter to travel. Space to visit towns.", 72, love.graphics.getHeight() - 48)
end

function WorldMapState:render(_game)
    if not self.world then
        return
    end
    drawWorld(self.world, self.message)
end

function WorldMapState:startTravel(path)
    self.travelPath = path
    self.travelPlan = { ids = {}, index = 1 }
    for _, location in ipairs(path) do
        table.insert(self.travelPlan.ids, location.id)
    end
    self.traveling = true
    self.awaitingTownMenu = false
    local destination = path[#path]
    self.message = string.format("Traveling to %s...", destination.name)
    local destIndex = self.world:getIndexById(destination.id)
    if destIndex then
        self.world:setSelectedIndex(destIndex)
    end
    self:advanceTravel()
end

function WorldMapState:activateSelection(game)
    if not self.world or self.travelSegment or self.traveling then
        return
    end
    self.awaitingTownMenu = false
    local destination = self.world:getSelected()
    if not destination then
        return
    end
    local path = self.world:findShortestPath(destination.id)
    if not path or #path <= 1 then
        if destination.type == "town" then
            self.awaitingTownMenu = true
            self.message = string.format("Already at %s. Press Space to open the town menu.", destination.name)
        else
            self.message = string.format("Already at %s.", destination.name)
        end
        return
    end
    self:startTravel(path)
end

function WorldMapState:keypressed(game, key)
    if not self.world then
        return
    end
    if key == "space" then
        if self.awaitingTownMenu then
            local current = self.world:getCurrent()
            if current then
                self.awaitingTownMenu = false
                travelToTown(self, game, current)
            end
        end
        return
    end
    if self.travelSegment or self.traveling then
        return
    end
    if key == "left" or key == "up" then
        self.world:moveSelection(-1)
    elseif key == "right" or key == "down" then
        self.world:moveSelection(1)
    elseif key == "return" or key == "kpenter" then
        self:activateSelection(game)
    end
end

return WorldMapState
