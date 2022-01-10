local Class = require('vendor/class')

local Node = require('Node')

local NodeMap = Class{}

local DEFAULT_ROWS = 8
local DEFAULT_COLUMNS = 8
local VIEWPORT_START_X = 0.1 * VIRTUAL_WIDTH
local VIEWPORT_START_Y = 0.1 * VIRTUAL_HEIGHT

function NodeMap:init(rows, columns, opts)
  self.rows = rows or DEFAULT_ROWS
  self.columns = columns or DEFAULT_COLUMNS
  self.hoveredNode = nil

  -- generate the nodes
  self.nodes = {}
  local x = VIEWPORT_START_X
  local y = VIEWPORT_START_Y
  for i = 1, self.rows do
    self.nodes[i] = {}
    for j = 1, self.columns do
      local node = Node(x + (j - 1) * TILE_SIZE, y + (i - 1) * TILE_SIZE)
      self.nodes[i][j] = node
    end
  end
end

function NodeMap:update(dt)
end

function NodeMap:clear()
  -- clear all node states
end

function NodeMap:render()
  love.graphics.rectangle("line", 0.1 * VIRTUAL_WIDTH, 0.1 * VIRTUAL_HEIGHT, VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
  for _, nodeRow in ipairs(self.nodes) do
    for _, node in ipairs(nodeRow) do
      node:render()
    end
  end

end

function NodeMap:findNodeAtPoint(x, y)
  -- need a linear function that maps x, y to a node
  local row = math.floor((y - VIEWPORT_START_Y) / TILE_SIZE)
  local col = math.floor((x - VIEWPORT_START_X) / TILE_SIZE)
  if row < 0 or row > #self.nodes - 1 then
    return nil
  end
  if col < 0 or col > self.columns - 1 then
    return nil
  end
  return self.nodes[row + 1][col + 1]
end

function NodeMap:handleNodeHighlight(pointerX, pointerY)
  local _hoveredNode = self:findNodeAtPoint(pointerX, pointerY)

  -- refactor, this is confusing
  if _hoveredNode ~= nil then
    if self.hoveredNode ~= _hoveredNode then
      if self.hoveredNode ~= nil then
        self.hoveredNode:toggleHighlight()
      end

      self.hoveredNode = _hoveredNode
      self.hoveredNode:toggleHighlight()
    end
  else
    if self.hoveredNode ~= nil then
      self.hoveredNode:toggleHighlight()
      self.hoveredNode = nil
    end
  end
end

function NodeMap:nodeIsHighlighted()
  return self.hoveredNode ~= nil
end

function NodeMap:handleSelectNode()
  if self.hoveredNode ~= nil then
    self.hoveredNode:toggleSelect()
  end
end

function NodeMap:clear()
  for _, nodeRow in ipairs(self.nodes) do
    for _, node in ipairs(nodeRow) do
      node:reset()
    end
  end
end

return NodeMap
