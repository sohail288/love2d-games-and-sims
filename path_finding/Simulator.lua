local Class = require('vendor/class')
local Entity = require("Entity")

local Simulator = Class {}

function Simulator:init(nodeMap, opts)
  opts = opts or {}
  self.state = "stopped"
  self.nodeMap = nodeMap
  self.entities = {}
  self.entitiesToGenerate = opts.numEntities or 100
  self.traversalStrategy = function(nodeMap)
    -- random algorithm
    if not nodeMap.destinationNode then
      return
    end

    for node in nodeMap:iterator() do
      node:clearTraversalData()
    end

    nodeMap.destinationNode.distanceToDest = 0
    local frontier = { nodeMap.destinationNode }

    while #frontier > 0 do
      local currentNode = table.remove(frontier)
      local nodeRow, nodeCol = nodeMap:getNodePosition(currentNode)
      for _, connection in ipairs({ { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 } }) do
        local neighbor = nodeMap:getNode(connection[1] + nodeRow, connection[2] + nodeCol)
        if neighbor ~= nil then
          if not neighbor.selected then
            neighbor.seen = true
            if neighbor.distanceToDest > currentNode.distanceToDest + 1 then
              neighbor.nextNode = currentNode
              neighbor.distanceToDest = currentNode.distanceToDest + 1
              table.insert(frontier, neighbor)
            end
          end
        end
      end
    end
  end
  self.nodeMap:addObserver(self.traversalStrategy)
end

function Simulator:_spawnEntities()
  local startNode = self.nodeMap.sourceNode
  local i = self.entitiesToGenerate
  local attempts = 1
  while i > 0 and attempts <= 5 do
    if startNode ~= nil then
      local node = startNode
      local nodeRow, nodeCol = self.nodeMap:getNodePosition(node)
      local l, r, t, b = node:getBounds()
      local entity = Entity { x = math.random() * 30 + (r + l) / 2, y = math.random() * 30 + (b + t) / 2 }
      entity:orientTowardsNode(node)
      table.insert(self.entities, entity)
      i = i - 1

    else
      local row = math.floor(math.random() * (self.nodeMap.rows - 1)) + 1
      local col = math.floor(math.random() * (self.nodeMap.columns - 1)) + 1
      if not self.nodeMap.nodes[row][col].selected then
        local node = self.nodeMap.nodes[row][col]
        local l, r, t, b = node:getBounds()
        local entity = Entity { x = r + math.random() * (r - l), y = t + math.random() * (b - t) }
        entity:orientTowardsNode(node)
        table.insert(self.entities, entity)
        i = i - 1
        attempts = 1
      else
        attempts = attempts + 1
      end
    end
  end
end

function Simulator:start()
  if self.state == "stopped" then
    self.state = "started"
    self.traversalStrategy(self.nodeMap)
    self:_spawnEntities()
  elseif self.state == "paused" then
    self.state = "started"
  end
end

function Simulator:recalculateTraversal()
  self.traversalStrategy(self.nodeMap)
end

function Simulator:pause()
  self.state = "paused"
end

function Simulator:stop()
  self.entities = {}
  self.state = "stopped"
  for node in self.nodeMap:iterator() do
    if node.nextNode ~= nil then
      node.nextNode = nil
    end

    if node._obstacle ~= nil then
      node._obstacle.targetedEntity = nil
    end
  end
end

function Simulator:step()
end

function Simulator:entityIterator()
  local index = 1
  return function()

    while index <= #self.entities and (not self.entities[index].active or self.entities[index].health <= 0) do
      index = index + 1
    end

    if index > #self.entities then
      return nil
    end

    local entityToReturn = self.entities[index]
    index = index + 1
    return entityToReturn
  end
end

function Simulator:update(dt)
  if self.state == "paused" then
    return
  end

  local nodeProjectiles = {}
  for node in self.nodeMap:iterator() do
    nodeProjectiles[node] = {}
  end

  for node in self.nodeMap:iterator() do
    if node._obstacle then
      node._obstacle:setTargetEntity(self.nodeMap)
      node._obstacle:update(dt)

      for _, projectile in ipairs(node._obstacle._projectiles) do
        local projectileNode = self.nodeMap:findNodeAtPoint(projectile.position:get(1), projectile.position:get(2))

        if projectileNode then
          table.insert(nodeProjectiles[projectileNode], projectile)
        end
      end
    end
  end

  for entity in self:entityIterator() do
    entity:update(dt)
    local entityNodePos = self.nodeMap:findNodeAtPoint(entity:getX(), entity:getY())
    if entity.node and entityNodePos == entity.node then
      if entity.node == self.nodeMap.destinationNode then
        entity.active = false
      end

      if entity.node.nextNode ~= nil then
        entity:orientTowardsNode(entity.node.nextNode)
      end
    elseif entity.node then
      entity:orientTowardsNode(entity.node)
    end

    -- check collisions
    if entityNodePos then
      for _, projectile in ipairs(nodeProjectiles[entityNodePos]) do
        local distanceFromProjectile = (projectile.position - entity.position):magnitude()
        if distanceFromProjectile - entity.size - projectile.size < 0 and projectile.active then
          -- collision
          print(entity, projectile, "collision")
          entity.active = false
          projectile.active = false
          break
        end
      end
    end
  end

end

function Simulator:render()
  for entity in self:entityIterator() do
    entity:render()
  end

end

return Simulator
