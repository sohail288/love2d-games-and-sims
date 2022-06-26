local Class = require('vendor/class')

local Node = require('Node')

local NodeMap = Class{}

local DEFAULT_ROWS = 8
local DEFAULT_COLUMNS = 8
local VIEWPORT_START_X = 0.1 * VIRTUAL_WIDTH
local VIEWPORT_START_Y = 0.1 * VIRTUAL_HEIGHT

function NodeMap:init(rows, columns, opts)
  opts = opts or {}
  self.rows = rows or DEFAULT_ROWS
  self.columns = columns or DEFAULT_COLUMNS
  self.hoveredNode = nil
  self.sourceNode = nil
  self.destinationNode = nil
  self.observers = opts.observers or {}

  -- generate the nodes
  self.nodes = {}
  local x = VIEWPORT_START_X
  local y = VIEWPORT_START_Y
  for i = 1, self.rows do
    self.nodes[i] = {}
    for j = 1, self.columns do
      local node = Node(x + (j - 1) * TILE_SIZE, y + (i - 1) * TILE_SIZE)
      self.nodes[i][j] = node
      node:setNodeMap(self)
    end
  end
end

function NodeMap:addObserver(observer)
  self.observers[observer] = true
end

function NodeMap:removeObserver(targetObserver)
  for _, observer in ipairs(self.observers) do
    if observer ==  targetObserver then
      -- TODO: instead delete observer and shift elements to left
      self.observers[targetObserver] = false
    end
  end
end

function NodeMap:setSource(node)
  if self.sourceNode ~= nil and self.sourceNode ~= node then
    self.sourceNode.isSourceNode = false
  end

  if node == self.destinationNode then
    self.destinationNode.isDestinationNode = false
    self.destinationNode = nil
  end

  node.isSourceNode = true
  node.selected = false
  self.sourceNode = node
end

function NodeMap:getSource()
  return self.sourceNode
end

function NodeMap:setDestination(node)
  -- do not allow setting source as destination? or replace that?
  if self.destinationNode ~= nil and self.destinationNode ~= node then
    self.destinationNode.isDestinationNode = false
  end

  if node == self.sourceNode then
    self.sourceNode.isSourceNode = false
    self.sourceNode = nil
  end
  node.isDestinationNode = true
  node.selected = false
  self.destinationNode = node
end

function NodeMap:getDestination()
  return self.destinationNode
end

function NodeMap:iterator()
  local rowIdx = 1
  local columnIdx = 0
  return function()
    columnIdx = columnIdx + 1
    if columnIdx > self.columns then
      rowIdx = rowIdx + 1
      columnIdx = 1 
    end

    if rowIdx > self.rows then
      return nil
    else
      return self.nodes[rowIdx][columnIdx]
    end
  end
end

function NodeMap:update(dt)
end

function NodeMap:render()
  love.graphics.rectangle("line", 0.1 * VIRTUAL_WIDTH, 0.1 * VIRTUAL_HEIGHT, VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
  for _, nodeRow in ipairs(self.nodes) do
    for _, node in ipairs(nodeRow) do
      node:render()
    end
  end

end

function NodeMap:getNodePosition(node)
  local row = math.floor((node.y - VIEWPORT_START_Y) / TILE_SIZE) + 1
  local col = math.floor((node.x - VIEWPORT_START_X) / TILE_SIZE) + 1
  return row, col
end

function NodeMap:getNode(row, col)
  local row = self.nodes[row]
  if row ~= nil then
      return row[col]
  end
  return nil
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

function NodeMap:getHighlightedNode()
  return self.hoveredNode
end

function NodeMap:handleSelectNode()
  if self.hoveredNode ~= nil then
    if self.hoveredNode == self.sourceNode then
      self.sourceNode.isSourceNode = false
      self.sourceNode = nil
    end
    if self.hoveredNode == self.destinationNode then
      self.destinationNode.isDestinationNode = false
      self.destinationNode = nil
    end
    self.hoveredNode:toggleSelect()
    for observer, observerIsActive in pairs(self.observers) do
      if observerIsActive then
        observer(self, self.hoveredNode)
      end
    end
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
