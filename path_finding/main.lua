-- this demonstrates how to do path finding in a grid based game
--
local push = require('vendor/push')
local globals = require('globals')

local NodeMap= require('NodeMap')
-- local MainMenu = require("MainMenu")
-- local ContextMenu = require("ContextMenu")

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setTitle("Path Finding")
  gNodeMap = NodeMap()
  hoveredNode = nil

  push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
      fullscreen = false,
      resizable = true,
      vsync = true
    })
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 and hoveredNode ~= nil then
    hoveredNode:toggleSelect()
  end
  
  if button == 2 and hoveredNode ~= nil then

  end
end

function love.update(dt)
  local mouseX, mouseY = love.mouse.getPosition()
  local _hoveredNode = gNodeMap:findNodeAtPoint(mouseX, mouseY)

  -- refactor, this is confusing
  if _hoveredNode ~= nil then
    if hoveredNode ~= _hoveredNode then
      if hoveredNode ~= nil then
        hoveredNode:toggleHighlight()
      end

      hoveredNode = _hoveredNode
      hoveredNode:toggleHighlight()
    end
  else
    if hoveredNode ~= nil then
      hoveredNode:toggleHighlight()
      hoveredNode = nil
    end
  end
end

function love.draw()
  gNodeMap:render()
  local mouseX, mouseY = love.mouse.getPosition()
  love.graphics.circle("line", mouseX, mouseY, 5)
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.quit()
  end
end
