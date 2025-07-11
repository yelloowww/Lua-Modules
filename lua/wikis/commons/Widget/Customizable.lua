---
-- @Liquipedia
-- page=Module:Widget/Customizable
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Lua = require('Module:Lua')

local Class = Lua.import('Module:Class')

local Widget = Lua.import('Module:Widget')
local CustomizableContext = Lua.import('Module:Widget/Contexts/Customizable')

---@class CustomizableWidget: Widget
---@operator call({id: string, children: Widget[]}): CustomizableWidget
---@field id string
local Customizable = Class.new(
	Widget,
	function(self, input)
		self.id = self:assertExistsAndCopy(input.id)
	end
)

---@return Widget[]?
function Customizable:render()
	local injector = self:useContext(CustomizableContext.LegacyCustomizable)
	if injector == nil then
		return self.props.children
	end
	return injector:parse(self.id, self.props.children)
end

return Customizable
