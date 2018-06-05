local UIWidget = {UUIDseed = -1}
package.loaded[...] = UIWidget

local UI = require "UI/UI"
local Typeassert = require "utils/Typeassert"
local Color = require "UI/Color"
local AABB = require "UI/AABB"
local floor = math.floor

UIWidget.__index = UIWidget

--- absolute values are pixels
--- % values are relative to available space + widgets's layout policy

function UIWidget.isUIWidget(o)
    return getmetatable(o) == UIWidget
end

function UIWidget.isID(ID)
    return type(ID) == "number"
end

function UIWidget:nextID(...)
    UIWidget.UUIDseed = UIWidget.UUIDseed + 1
    return UIWidget.UUIDseed
end

-- style:
---- z-index
---- allign = {x=[center|left|right], y=[center|up|down]}
---- origin = {x, y}
---- size = {x, y}
---- margin = [ {all} | {x, y} | {left, right, up, down} ]
---- theme = {bg, fg, fg_focus, hilit, hilit_focus}
-- flags:
---- keepFocus
---- clickThru
---- allowOverflow
---- hidden
---- invisible
---- draggable
function UIWidget.new(style, flags)
    local valPred = function(x)
        return type(x) == "number" or type(x) == "string" and string.match(x, "^%-?[0-9]+%%$") == x
    end
    Typeassert(
        style,
        {
            "ANY",
            "nil",
            {
                z = "number|nil",
                allign = {
                    "ANY",
                    "nil",
                    {x = {"ANY", "R:center", "R:left", "R:right"}, y = {"ANY", "R:center", "R:up", "R:down"}}
                },
                origin = {"ANY", "nil", {x = valPred, y = valPred}},
                size = {"ANY", "nil", {x = valPred, y = valPred}},
                margin = {
                    "ANY",
                    "nil",
                    {left = valPred, right = valPred, up = valPred, down = valPred},
                    {x = valPred, y = valPred},
                    {all = valPred}
                },
                theme = {
                    "ANY",
                    "nil",
                    {
                        bg = {"ANY", "nil", Color.isColor},
                        fg = {"ANY", "nil", Color.isColor},
                        fg_focus = {"ANY", "nil", Color.isColor},
                        hilit = {"ANY", "nil", Color.isColor},
                        hilit_focus = {"ANY", "nil", Color.isColor}
                    }
                }
            }
        }
    )
    Typeassert(
        flags,
        {
            "ANY",
            "nil",
            {
                keepFocus = "nil|boolean",
                clickThru = "nil|boolean",
                allowOverflow = "nil|boolean",
                hidden = "nil|boolean",
                invisible = "nil|boolean",
                draggable = "nil|boolean",
            }
        }
    )

    --- DEFAULT STYLE
    style = style or {}
    style.z = style.z or 0
    style.allign = style.allign or {x = "center", y = "center"} -- TODO: apply in AABB calculation
    style.origin = style.origin or {x = 0, y = 0}
    style.size = style.size or {x = "100%", y = "100%"}
    style.margin = style.margin or {left = 0, right = 0, up = 0, down = 0}
    style.theme = style.theme or {bg, fg, fg_focus, hilit, hilit_focus}
    
    --- DEFAULT FLAGS
    flags = flags or {}
    flags.keepFocus = flags.keepFocus or false -- TODO: will keep focus until dropFocus() is not
    flags.clickThru = flags.clickThru or false -- TODO: true for element to not register click
    flags.allowOverflow = flags.allowOverflow or false -- TODO: allowOverflow by IDs
    flags.hidden = flags.hidden or false -- FIXME: test
    flags.invisible = flags.invisible or false -- doesn't render self but renders children
    flags.draggable = flags.draggable or false -- TODO: dragged by margin and all pass-thru inner elements

    --- OBJECT CONSTRUCTION BEGIN
    local self = setmetatable({style = {}, flags = {}}, UIWidget) -- FIXME: refactor, move to #120
    -----------------
    self.style.origin =
        setmetatable(
        {},
        {
            -- no direct access to
            _x, -- exact
            _y,
            _xP, -- percentages -
            _yP,
            __index = function(t, k)
                local t = getmetatable(t)
                return (k == "x" and t._x) or (k == "y" and t._y) or (k == "value" and t._value) -- returns value in pixels
            end,
            __newindex = function(t, k, val)
                local t = getmetatable(t)
                local valP = UI.getPercent(val)

                if k == "x" then
                    self._layoutModified = (valP ~= t._xP) or (val ~= t._x)
                    t._xP, t._x = (valP and val), ((valP and floor(self._availAABB:width() * (valP / 100))) or val)
                elseif k == "y" then
                    self._layoutModified = (valP ~= t._yP) or (val ~= t._y)
                    t._yP, t._y = (valP and val), ((valP and floor(self._availAABB:height() * (valP / 100))) or val)
                end
            end,
            _value = function(self, k) -- returns stored value
                self = getmetatable(self)
                return (k == "x" and (self._xP or self._x)) or (k == "y" and (self._yP or self._y))
            end
        }
    )
    ---------------
    self.style.size =
        setmetatable(
        {},
        {
            _x, -- exact
            _y,
            _xP, -- percentages
            _yP,
            __index = getmetatable(self.style.origin).__index, -- same
            __newindex = getmetatable(self.style.origin).__newindex, -- same
            _value = getmetatable(self.style.origin)._value
        }
    )
    -----------------
    self.style.margin =
        setmetatable(
        {},
        {
            _l, -- exact
            _r,
            _u,
            _dr,
            _lP, -- percentages
            _rP,
            _uR,
            _dP,
            __index = function(T, k)
                local t = getmetatable(T)
                return (k == "left" and t._l) or (k == "right" and t._r) or (k == "up" and t._u) or
                    (k == "down" and t._d) or
                    (k == "x" and (t._l == t._r) and t._l) or
                    (k == "y" and (t._u == t._d) and t._u) or
                    (k == "all" and (t._u == t._d and t._l == t._r and t._l == t._u) and t._u) or
                    (k == "value" and t._value)
            end,
            __newindex = function(T, k, val)
                local t = getmetatable(T)
                local valP = UI.getPercent(val)
                if k == "left" then
                    self._layoutModified = (valP ~= t._lP) or (val ~= t._l)
                    t._lP, t._l = (valP and val), ((valP and floor(self._availAABB:width() * (valP / 100))) or val)
                elseif k == "right" then
                    self._layoutModified = (valP ~= t._rP) or (val ~= t._r)
                    t._rP, t._r = (valP and val), ((valP and floor(self._availAABB:width() * (valP / 100))) or val)
                elseif k == "up" then
                    self._layoutModified = (valP ~= t._uP) or (val ~= t._u)
                    t._uP, t._u = (valP and val), ((valP and floor(self._availAABB:height() * (valP / 100))) or val)
                elseif k == "down" then
                    self._layoutModified = (valP ~= t._dP) or (val ~= t._d)
                    t._dP, t._d = (valP and val), ((valP and floor(self._availAABB:height() * (valP / 100))) or val)
                elseif k == "x" then -- use previous
                    T.left = val
                    T.right = val
                elseif k == "y" then -- use previous
                    T.up = val
                    T.down = val
                elseif k == "all" then -- use previous
                    T.x = val
                    T.y = val
                end
            end,
            __call = function(T, val) -- one number initialization with call as margin(15)
                T.left, T.right, T.up, T.down = val, val, val, val
            end,
            _value = function(self, k)
                self = getmetatable(self)
                return (k == "left" and (self._lP or self._l)) or (k == "right" and (self._rP or self._r)) or
                    (k == "up" and (self._uP or self._u)) or
                    (k == "down" and (self._dP or self._d))
            end
        }
    )
    ----------------
    self.style.theme =
        setmetatable(
        {},
        {
            __index = function(t, k) -- returns value from _
                local code = ({base = 1, fg = 2, fg_focus = 3, hilit = 4, hilit_focus = 5})[k]
                return (code and Color(self._UI.theme[code])) or Color(0, 0, 0) -- default is black
            end
        }
    )

    self.__index = UI
    self._UI = null
    self._ID = UIWidget.nextID() -- might be obsolete, because objects self identifies itself by unique table
    self._focused = false
    self._hovered = false
    self._childrenByZ = {}
    self._parent = self -- stand-alone widgets shouldn't exist
    self._availAABB = AABB(0, 0, 0, 0)
    self._AABB = AABB(0, 0, 0, 0)
    self._layoutModified = true
    self.renderer = function(self, ...)
    end -- renderer of this widget
    self.updater = function(self, ...)
    end -- updater of this widget

    self.style.z = style.z
    self.style.allign = {x = style.allign.x, y = style.allign.y}
    self.style.origin.x = style.origin.x
    self.style.origin.y = style.origin.y
    self.style.size.x = style.size.x
    self.style.size.y = style.size.y
    self.style.margin.left = style.margin.all or style.margin.x or style.margin.left
    self.style.margin.right = style.margin.all or style.margin.x or style.margin.right
    self.style.margin.up = style.margin.all or style.margin.y or style.margin.up
    self.style.margin.down = style.margin.all or style.margin.y or style.margin.down
    self.style.theme.bg = style.theme.bg
    self.style.theme.fg = style.theme.fg
    self.style.theme.fg_focus = style.theme.fg_focus
    self.style.theme.hilit_focus = style.theme.hilit_focus
    self.style.theme.hilit = style.theme.hilit

    return self
end

function UIWidget:update(...) -- TODO: status passed during tree traversal (anyHovered flag)
    if not self.flags.hidden then -- don't waste resources for hidden objects
        self:updater(...)
        self:reloadLayout(self._layoutModified) -- handles size, origin, margin changes (later also drag and scroll?)
        for _, v in ipairs(self._childrenByZ) do
            v:update(...)
        end
    end
end

-- guarantee: elements are setup properly
----- scissor is set to available space
function UIWidget:draw(...)
    if not self.flags.hidden then
        if not self.invisible then
            self:renderer(...)
        end
        for _, v in ipairs(self._childrenByZ) do
            -- TODO: allow overflow flag implementation as set scissors to parent 
            self:setScissor()
            v:draw(...)
        end
    end
end

-- to override
function UIWidget:reloadLayoutSelf()
end

-- guarantee - availAABB is set properly
function UIWidget:reloadLayout(doReload) -- doReload when any of ancestors was updated
    if not self.flags.hidden and doReload or self._layoutModified then -- resources save on hidden objects
        -- FIXME: test

        -- assigning has sideeffect of recalculating exact sizes
        self.style.origin.x = self.style.origin:value("x")
        self.style.origin.y = self.style.origin:value("y")
        self.style.size.x = self.style.size:value("x")
        self.style.size.y = self.style.size:value("y")
        self.style.margin.left = self.style.margin:value("left")
        self.style.margin.right = self.style.margin:value("right")
        self.style.margin.up = self.style.margin:value("up")
        self.style.margin.down = self.style.margin:value("down")

        -- self AABB
        local x1 = self._availAABB[1].x + self.style.origin.x
        local y1 = self._availAABB[1].y + self.style.origin.y
        self._AABB:set(x1, y1, x1 + self.style.size.x, y1 + self.style.size.y)

        self:reloadLayoutSelf()
        -- availAABB and reloadLayout for children
        for _, v in ipairs(self._childrenByZ) do
            if (self.flags.allowOverflow) then
                v._availAABB:set(self._availAABB)
            else
                v._availAABB:set(self._AABB)
                v._availAABB:contract(
                    self.style.margin.left,
                    self.style.margin.right,
                    self.style.margin.down,
                    self.style.margin.up
                )
                v._availAABB = v._availAABB:cut(self._availAABB)
            end
            v:reloadLayout(doReload or self._layoutModified)
        end

        self._layoutModified = false
    end
end

-- to override
function UIWidget:reloadSelf(...)
end
-- drops focus, reset scroll, clear buffers etc.
--- quarantee - availAABB is always set properly
function UIWidget:reload(...)
    self._hovered = false
    self:dropFocus()

    -- z-index children sort
    table.sort(
        self._childrenByZ,
        function(w1, w2)
            return w1.z < w2.z
        end
    )
    self:reloadSelf()

    self:reloadLayout(true)

    for _, v in ipairs(self._childrenByZ) do
        v:reload(...)
    end
end

function UIWidget:addWidget(widget)
    Typeassert(widget, UIWidget.isUIWidget)
    table.insert(self._childrenByZ, widget)
    widget._parent:removeWidget(widget)
    widget._parent = self
    widget._UI = self._UI
    self:reloadLayout(true)
end

-- remove widget from tree
function UIWidget:removeWidget(widget)
    for k, v in ipairs(self._childrenByZ) do
        if v == widget then
            widget = k
            break
        end
    end
    table.remove(self._childrenByZ, k)
    self:reloadLayout(true)
end

-- copy of requested AABB
function UIWidget:getAABB()
    return AABB(self._AABB)
end

-- realAABB as displayed on screen
function UIWidget:getRealAABB()
    return self._availAABB:cut(self._AABB)
end

-- copy of availAABB
function UIWidget:getAvailAABB()
    return AABB(self._availAABB)
end

-- copy of origin
function UIWidget:getOrigin()
    return {x = self.style.origin.x, y = self.style.origin.y}
end

-- cursor relative to self
function UIWidget:getCursor()
    local c = self._UI.cursor
    return {x = c.x - self._AABB[1].x, y = c.y - self._AABB[1].y}
end

-- proxy to parent
function UIWidget:getRawCursor()
    return self._UI:getRawCursor()
end

-- proxy to parent
function UIWidget:setRawCursor(x, y)
    self._UI:setRawCursor(x, y)
end

-- sets cursor relative to this elements realAABB corner
function UIWidget:setCursor(x, y)
    if type(x) == "table" then
        x, y = x.x, x.y
    end
    self._UI.cursor.x, self._UI.cursor.y = self._AABB[1].x + x, self._AABB[1].y + y
end

--  overridable to implement subelement scissor policy
function UIWidget:setScissor(...)
    love.graphics.setScissor(self:getRealAABB():normalized())
end

function UIWidget:isFocused()
    return self._focused
end

function UIWidget:dropFocus()
    self.flags._focused = false
end

-- true if mouse is over real AABB of self, excluding right and down border
function UIWidget:mouseIn()
    local mouse = self:getMouse()
    local rAABB = self:getRealAABB()
    return mouse.x >= rAABB.x and mouse.y >= rAABB.y and mouse.x < rAABB.x and mouse.y < rAABB.y
end

-- true if this item is hovered (and none of direct subitems with passThru=false is hovered) 
function UIWidget:isHovered()
    return self._hovered and not self.flag.passThru -- TODO: pull up passThru ???
end

-- returns widget containing x, y in it's realAABB
function UIWidget:getWidgetAt(x, y)
    if self:getRealAABB():contains(x, y) then
        local ans = self
        for i = #self._childrenByZ, 1, -1 do
            ans = self._childrenByZ[i]:getWidgetAt(x, y) or ans
        end
    end
    return nil
end

-- returns widget by ID or nil if it doesn't exist in UI tree
function UIWidget:getWidgetByID(id)
    if self._ID == id then
        return self
    end
    for _, widget in ipairs(self._childrenByZ) do
        local ans = widget:getWidgetAt(id)
        if ans then
            return ans
        end
    end
    return nil
end

return setmetatable(
    UIWidget,
    {
        __index = UI,
        __call = function(_, ...)
            local ok, ret = pcall(UIWidget.new, ...)
            if ok then
                return ret
            else
                error("UIWidget: " .. ret)
            end
        end
    }
)
