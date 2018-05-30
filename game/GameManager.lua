local logic = require "game/GameLogic"
local map = require "game/GameMap"
local Unit = require "game/actors/Unit"
local GameManager = {}

local u1
local u2
function GameManager.init()
    logic.init()
    map.init()

    u1 = Unit:new({x = 100})
    u1:init("dagger")
    u2 = Unit:new({y = 300})
    u2:init("dagger2")

    u1:debugInfo()
    u2:debugInfo()
end

function GameManager.clear()
    logic.clear()
    map.clear()
end

function GameManager.update(dt)
    map.update(dt)
end

function GameManager.draw()
    map.draw()
    u1:draw()
    u2:draw()
end

return GameManager