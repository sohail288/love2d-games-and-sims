local Class = require('vendor/class')
local Entity = require("Entity")

local Simulator = Class{}

function Simulator:init(nodeMap, opts)
  opts = opts or {}
  self.nodeMap = nodeMap
  self.entities = {}
  self.entitiesToGenerate = opts.numEntities or 100
  self.traversalStrategy = function(nodeMap)
    -- random algorithm
    if not nodeMap.destinationNode then
      return
    end
    local frontier = {nodeMap.destinationNode}

    while #frontier > 0 do
      local currentNode = table.remove(frontier)
      local nodeRow, nodeCol = nodeMap:getNodePosition(currentNode)
      for _, connection in ipairs({{0, 1}, {1, 0}, {-1, 0}, {0, -1}}) do
        local neighbor = nodeMap:getNode(connection[1] + nodeRow, connection[2] + nodeCol) 
        if neighbor ~= nil then
          if not neighbor.visited and not neighbor.seen  and not neighbor.selected then
            neighbor.seen = true
            neighbor.nextNode = currentNode
            table.insert(frontier, neighbor)
          end
        end
      end
    end
    return
  end
end

function Simulator:_spawnEntities()
  local startNode = self.nodeMap.sourceNode
  local i = self.entitiesToGenerate
  local attempts = 1
  while i > 0  and attempts <= 5 do
    if startNode ~= nil then
      local node = startNode
      local nodeRow, nodeCol = self.nodeMap:getNodePosition(node)
      local l, r, t, b = node:getBounds()
      local entity = Entity{x=math.random() * 10 +  (r + l) / 2, y=math.random() * 10 + (b + t) / 2}
      entity:orientTowardsNode(node)
      table.insert(self.entities, entity)
      i = i - 1

    else
      local row = math.floor(math.random() * (self.nodeMap.rows - 1)) + 1
      local col = math.floor(math.random() * (self.nodeMap.columns - 1)) + 1
      if not self.nodeMap.nodes[row][col].selected then
        local node = self.nodeMap.nodes[row][col]
        local l, r, t, b = node:getBounds()
        local entity = Entity{x=r + math.random() * (r - l), y=t + math.random() * (b - t)}
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
  self.traversalStrategy(self.nodeMap)
  self:_spawnEntities()
end

function Simulator:pause()
end

function Simulator:stop()
end

function Simulator:step()
end

function Simulator:update(dt)
  for _, entity in ipairs(self.entities) do
    entity:update(dt)
    local entityNodePos = self.nodeMap:findNodeAtPoint(entity:getX(), entity:getY())
    if entity.node and entityNodePos == entity.node then
      if entity.node.nextNode ~= nil then
        entity:orientTowardsNode(entity.node.nextNode)
      end
    elseif entity.node then
      entity:orientTowardsNode(entity.node)
    end
  end
end

function Simulator:render()
  for _, entity in ipairs(self.entities) do
    entity:render()
  end
end

return Simulator
