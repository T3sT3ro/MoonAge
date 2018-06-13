local ui = require "game/GameUI"
local manager = require "game/GameManager"
local MainMenuState = {name = "MainMenuState"}
local UI = require("UI/UI")
local UIButton = require("UI/UIButton")
local UIFrame = require("UI/UIFrame")
local UIWidget = require("UI/UIWidget")
ResourceManager.load("font.monospace24", "Inconsolata-Regular", "ttf", "resources/fonts", "font", 24)
local font = ResourceManager.get("font.monospace24")
local GUI = UI(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
local MainFrame = UIWidget()
local MapFrame = UIWidget({allign = {x = "center"},size = {x = 20*32, y = 20*32}})
MapFrame.renderer = manager.draw
MapFrame.mousePressed = manager.mousePressed
MainFrame:addWidget(MapFrame)
GUI:setWidget(MainFrame)
local GameState = {}
GameState.name = "GameState"
local oldResize 
function GameState.init()
    oldResize = love.resize
    oldHandlers = {
        mp = love.mousepressed,
        mr = love.mousereleased,
        wm = love.wheelmoved,
        kp = love.keypressed,
        kr = love.keyreleased,
        ti = love.textinput,
        fd = love.filedropped,
        dd = love.directorydropped
    }
    local handlers = GUI:getEventHandlers()

    love.resize = function(w,h)
        GUI:resize(0,0,w,h)
    end
    love.mousepressed = handlers.mousepressed
    love.mousereleased = handlers.mousereleased
    love.wheelmoved = handlers.wheelmoved
    love.keypressed = handlers.keypressed
    love.keyreleased = handlers.keyreleased
    love.textinput = handlers.textinput
    love.filedropped = handlers.filedropped
    love.directorydropped = handlers.directorydropped
    manager.init()
    ui.init()
end

function GameState.clear()
    love.resize = oldResize
    love.mousepressed = oldHandlers.mp
    love.mousereleased = oldHandlers.mr
    love.wheelmoved = oldHandlers.wm
    love.keypressed = oldHandlers.kp
    love.keyreleased = oldHandlers.kr
    love.textinput = oldHandlers.ti
    love.filedropped = oldHandlers.fd
    love.directorydropped = oldHandlers.dd
    manager.clear()
    ui.clear()
end

function GameState.update(dt)
    GUI:update(dt)
    manager.update(dt)
end

function GameState.draw()
    local t = MapFrame:getAABB()[1]
    GUI:draw(t.x,t.y)
    love.graphics.print(tostring(t.x).." "..tostring(t.y))
    --manager.draw(0)
end

return GameState