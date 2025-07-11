---
-- @Liquipedia
-- page=Module:Widget/Builder
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Lua = require('Module:Lua')

local Class = Lua.import('Module:Class')

local Widget = Lua.import('Module:Widget')

---@class BuilderWidget: Widget
---@operator call({builder: function}): BuilderWidget
local Builder = Class.new(Widget)

---@return Widget[]?
function Builder:render()
	return self.props.builder()
end

return Builder
