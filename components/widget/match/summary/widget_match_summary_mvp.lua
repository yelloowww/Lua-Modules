---
-- @Liquipedia
-- wiki=commons
-- page=Module:Widget/Match/Summary/Mvp
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Array = require('Module:Array')
local Class = require('Module:Class')
local Lua = require('Module:Lua')

local Widget = Lua.import('Module:Widget')
local WidgetUtil = Lua.import('Module:Widget/Util')
local HtmlWidgets = Lua.import('Module:Widget/Html/All')
local Div, Span, Fragment = HtmlWidgets.Div, HtmlWidgets.Span, HtmlWidgets.Fragment
local Link = Lua.import('Module:Widget/Basic/Link')

---@class MatchSummaryMVP: Widget
---@operator call(table): MatchSummaryMVP
local MatchSummaryMVP = Class.new(Widget)

---@return Widget[]?
function MatchSummaryMVP:render()
	if self.props.players == nil or #self.props.players == 0 then
		return nil
	end
	local players = Array.map(self.props.players, function(player)
		if type(player) == 'table' then
			local link = Link{
				link = player.name,
				children = {player.displayname},
			}
			if player.comment then
				return Fragment{children = {link, ' (' .. player.comment .. ')'}}
			end
			return link
		end
		return Link{
			link = player,
			children = {player},
		}
	end)
	return Div{
		classes = {'brkts-popup-footer', 'brkts-popup-mvp'},
		children = {Span{
			children = WidgetUtil.collect(
				#players > 1 and 'MVPs: ' or 'MVP: ',
				Array.interleave(players, ', '),
				self.props.points and ' (' .. self.props.points .. ' pts)' or nil
			),
		}},
	}
end

return MatchSummaryMVP
