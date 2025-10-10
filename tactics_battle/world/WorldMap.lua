local WorldMap = {}
WorldMap.__index = WorldMap

local function cloneLocation(source)
    local copy = {
        id = source.id,
        name = source.name or source.id,
        type = source.type or "town",
        description = source.description,
        scenario = source.scenario,
        script = source.script,
        victoryScript = source.victoryScript,
        mandatory = source.mandatory or false,
        position = source.position,
        battleChance = source.battleChance
    }
    return copy
end

function WorldMap.new(config)
    assert(type(config) == "table", "world map configuration required")
    assert(type(config.locations) == "table" and #config.locations >= 1, "world map requires at least one location")

    local self = setmetatable({}, WorldMap)
    self._locations = {}
    local ids = {}
    for _, location in ipairs(config.locations) do
        assert(type(location.id) == "string" and location.id ~= "", "location id must be a non-empty string")
        table.insert(self._locations, cloneLocation(location))
        ids[location.id] = true
    end
    self._selected = config.selectedIndex or 1
    if self._selected < 1 or self._selected > #self._locations then
        self._selected = 1
    end
    self._graph = {}
    local function addConnection(a, b)
        if not (ids[a] and ids[b]) then
            return
        end
        self._graph[a] = self._graph[a] or {}
        table.insert(self._graph[a], b)
    end
    if type(config.paths) == "table" then
        for _, path in ipairs(config.paths) do
            if type(path) == "table" and path.from and path.to then
                addConnection(path.from, path.to)
                addConnection(path.to, path.from)
            end
        end
    else
        for index = 1, #self._locations - 1 do
            local from = self._locations[index].id
            local to = self._locations[index + 1].id
            addConnection(from, to)
            addConnection(to, from)
        end
    end
    self._visited = {}
    local currentIndex = config.currentIndex or self._selected
    if currentIndex < 1 or currentIndex > #self._locations then
        currentIndex = 1
    end
    self._currentId = self._locations[currentIndex].id
    self._visited[self._currentId] = true
    return self
end

function WorldMap:getLocations()
    return self._locations
end

function WorldMap:getLocation(index)
    return self._locations[index]
end

function WorldMap:getSelectedIndex()
    return self._selected
end

function WorldMap:getSelected()
    return self._locations[self._selected]
end

function WorldMap:getCurrent()
    return self:getLocationById(self._currentId)
end

function WorldMap:moveSelection(delta)
    if #self._locations == 0 then
        return self:getSelected()
    end
    local nextIndex = self._selected + (delta or 0)
    while nextIndex < 1 do
        nextIndex = nextIndex + #self._locations
    end
    while nextIndex > #self._locations do
        nextIndex = nextIndex - #self._locations
    end
    self._selected = nextIndex
    return self:getSelected()
end

function WorldMap:setSelectedIndex(index)
    if index >= 1 and index <= #self._locations then
        self._selected = index
    end
    return self:getSelected()
end

function WorldMap:getIndexById(id)
    for index, location in ipairs(self._locations) do
        if location.id == id then
            return index
        end
    end
    return nil
end

function WorldMap:getLocationById(id)
    for _, location in ipairs(self._locations) do
        if location.id == id then
            return location
        end
    end
    return nil
end

function WorldMap:markVisited(id)
    if id then
        self._visited[id] = true
    end
end

function WorldMap:isVisited(id)
    return self._visited[id] or false
end

function WorldMap:setCurrentLocation(id)
    if not id then
        return
    end
    local index = self:getIndexById(id)
    if not index then
        return
    end
    self._currentId = id
    self._selected = index
    self:markVisited(id)
end

function WorldMap:getCurrentLocationId()
    return self._currentId
end

function WorldMap:getNeighbors(id)
    return self._graph[id] or {}
end

function WorldMap:findShortestPath(toId)
    if not toId then
        return nil
    end
    local startId = self._currentId or (self._locations[1] and self._locations[1].id)
    if not startId then
        return nil
    end
    if startId == toId then
        return { self:getLocationById(startId) }
    end
    local queue = { startId }
    local head = 1
    local visited = { [startId] = true }
    local previous = {}
    while queue[head] do
        local node = queue[head]
        head = head + 1
        for _, neighbor in ipairs(self:getNeighbors(node)) do
            if not visited[neighbor] then
                visited[neighbor] = true
                previous[neighbor] = node
                if neighbor == toId then
                    queue[#queue + 1] = neighbor
                    head = #queue + 1
                    break
                else
                    queue[#queue + 1] = neighbor
                end
            end
        end
    end
    if not visited[toId] then
        return nil
    end
    local reversed = {}
    local current = toId
    while current do
        table.insert(reversed, 1, current)
        current = previous[current]
    end
    local path = {}
    for _, id in ipairs(reversed) do
        local location = self:getLocationById(id)
        if not location then
            return nil
        end
        table.insert(path, location)
    end
    return path
end

return WorldMap
