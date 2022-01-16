-- this demonstrates how to do path finding in a grid based game
--
local push = require('vendor/push')
local Timer = require 'vendor/knife/timer'

local globals = require('globals')

local NodeMap= require('NodeMap')
local MainMenu = require("menu/MainMenu")
local ContextMenu = require("menu/ContextMenu")
local Entity = require("Entity")

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setTitle("Path Finding")
  gNodeMap = NodeMap()
  hoveredNode = nil

  gContextMenu = ContextMenu()
  gMainMenu = MainMenu()
  gEntity = Entity()

  push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
      fullscreen = false,
      resizable = true,
      vsync = true
    })

  Timer.every(3, function() 
    local node
    if gNodeMap.sourceNode ~= nil then
      node = gNodeMap.sourceNode
    else
      if gEntity.node ~= nil then
        gEntity.node:toggleSelect()
      end
      local row = math.floor(math.random() * (gNodeMap.rows - 1)) + 1
      local col = math.floor(math.random() * (gNodeMap.columns - 1)) + 1
      node =  gNodeMap.nodes[row][col]
      node:toggleSelect()
    end
    gEntity:orientTowardsNode(node)
  end)
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
      -- context menu is over all
    if not gContextMenu.isOpen or not gContextMenu:pointWithinBounds(x, y) then
      gMainMenu:handleMouseClick()

      if gNodeMap:nodeIsHighlighted() then
        gNodeMap:handleSelectNode()
      end
    end
  end

  gContextMenu:handleMouseClick(button, gNodeMap:getHighlightedNode())
  
end

function love.update(dt)
  local mouseX, mouseY = love.mouse.getPosition()
  gNodeMap:handleNodeHighlight(mouseX, mouseY)
  gMainMenu:handleMouseOver(mouseX, mouseY)
  gContextMenu:handleMouseOver(mouseX, mouseY)
  Timer.update(dt)
  gEntity:update(dt)
end

function love.draw()
  gNodeMap:render()
  gMainMenu:render()
  gContextMenu:render()
  local mouseX, mouseY = love.mouse.getPosition()
  love.graphics.circle("line", mouseX, mouseY, 5)
  gEntity:render()
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.quit()
  end
end
