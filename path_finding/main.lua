-- this demonstrates how to do path finding in a grid based game
--
local push = require('vendor/push')
local Timer = require 'vendor/knife/timer'

local globals = require('globals')

local NodeMap = require('NodeMap')
local MainMenu = require("menu/MainMenu")
local ContextMenu = require("menu/ContextMenu")
local Entity = require("Entity")
local Simulator = require("Simulator")

function love.load()
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.window.setTitle("Path Finding")
  gNodeMap = NodeMap()
  gSimulator = Simulator(gNodeMap, { numEntities = 20 })
  hoveredNode = nil

  gContextMenu = ContextMenu { simulator = gSimulator }
  gMainMenu = MainMenu()

  push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
    fullscreen = false,
    resizable = true,
    vsync = true
  })

end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then
    -- context menu is over all
    if not gContextMenu.isOpen or not gContextMenu:pointWithinBounds(x, y) then
      gMainMenu:handleMouseClick()

      if gNodeMap:nodeIsHighlighted() then
        gNodeMap:handleSelectNode()
        if gSimulator.state == "started" then
          gSimulator:recalculateTraversal()
        end
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
  gSimulator:update(dt)
end

function love.draw()
  gNodeMap:render()
  gMainMenu:render()
  gContextMenu:render()
  local mouseX, mouseY = love.mouse.getPosition()
  love.graphics.circle("line", mouseX, mouseY, 5)
  gSimulator:render()
end

function love.keypressed(key)
  if key == 'escape' then
    love.event.quit()
  end
end
