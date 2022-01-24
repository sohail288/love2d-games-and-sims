local Class = require('vendor/class')
local Entity = require("Entity")

local Simulator = Class{}

function Simulator:init(nodeMap, opts)
  opts = opts or {}
  self.nodeMap = nodeMap
  self.entities = {}
  self.entitiesToGenerate = opts.numEntities or 100

  self:_spawnEntities()
end

function Simulator:_spawnEntities()
  local i = self.entitiesToGenerate
  local attempts = 1
  while i > 0  and attempts <= 5 do
    local row = math.floor(math.random() * (self.nodeMap.rows - 1)) + 1
    local col = math.floor(math.random() * (self.nodeMap.columns - 1)) + 1
    if not self.nodeMap.nodes[row][col].selected then
      local node = self.nodeMap.nodes[row][col]
      local l, r, t, b = node:getBounds()
      local entity = Entity{x=r + math.random() * (r - l), y=t + math.random() * (b - t)}
      table.insert(self.entities, entity)
      i = i - 1
      attempts = 1
    else
      attempts = attempts + 1
    end
  end
end


function Simulator:start()
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
  end
end

function Simulator:render()
  for _, entity in ipairs(self.entities) do
    entity:render()
  end
end

return Simulator
