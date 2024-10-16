---
-- @Liquipedia
-- wiki=heroes
-- page=Module:MatchSummary
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local CustomMatchSummary = {}

local Abbreviation = require('Module:Abbreviation')
local Array = require('Module:Array')
local CharacterIcon = require('Module:CharacterIcon')
local Class = require('Module:Class')
local DateExt = require('Module:Date/Ext')
local DisplayHelper = require('Module:MatchGroup/Display/Helper')
local ExternalLinks = require('Module:ExternalLinks')
local Icon = require('Module:Icon')
local Logic = require('Module:Logic')
local Lua = require('Module:Lua')
local Page = require('Module:Page')
local String = require('Module:StringUtils')
local Table = require('Module:Table')

local MatchSummary = Lua.import('Module:MatchSummary/Base')
local MatchSummaryWidgets = Lua.import('Module:Widget/Match/Summary/All')

local MAX_NUM_BANS = 3
local NUM_CHAMPIONS_PICK = 5

local GREEN_CHECK = Icon.makeIcon{iconName = 'winner', color = 'forest-green-text', size = '110%'}
local NO_CHECK = '[[File:NoCheck.png|link=]]'
local NO_CHARACTER = 'default'
local FP = Abbreviation.make('First Pick', 'First Pick for Heroes on this map')
local TBD = Abbreviation.make('TBD', 'To Be Determined')

-- Champion Ban Class
---@class HeroesOfTheStormHeroBan: MatchSummaryRowInterface
---@operator call: HeroesOfTheStormHeroBan
---@field root Html
---@field table Html
local ChampionBan = Class.new(
	function(self)
		self.root = mw.html.create('div'):addClass('brkts-popup-mapveto')
		self.table = self.root:tag('table')
			:addClass('wikitable-striped'):addClass('collapsible'):addClass('collapsed')
		self:createHeader()
	end
)

---@return HeroesOfTheStormHeroBan
function ChampionBan:createHeader()
	self.table:tag('tr')
		:tag('th'):css('width','40%'):wikitext(''):done()
		:tag('th'):css('width','20%'):wikitext('Bans'):done()
		:tag('th'):css('width','40%'):wikitext(''):done()
	return self
end

---@param banData {numberOfBans: integer, [1]: table, [2]: table}
---@param gameNumber integer
---@param date string
---@return HeroesOfTheStormHeroBan
function ChampionBan:banRow(banData, gameNumber, date)
	if Logic.isEmpty(banData) then
		return self
	end
	self.table:tag('tr')
		:tag('td')
			:node(CustomMatchSummary._opponentChampionsDisplay(banData[1], banData.numberOfBans, date, false, true))
		:tag('td')
			:node(mw.html.create('div')
				:wikitext(Abbreviation.make(
							'Game ' .. gameNumber,
							'Bans in game ' .. gameNumber
						)
					)
				)
		:tag('td')
			:node(CustomMatchSummary._opponentChampionsDisplay(banData[2], banData.numberOfBans, date, true, true))
	return self
end

---@return Html
function ChampionBan:create()
	return self.root
end

---@class HeroesOfTheStormMapVeto: VetoDisplay
local MapVeto = Class.new(MatchSummary.MapVeto)

---@param map1 string?
---@param map2 string?
---@return string
---@return string
function MapVeto:displayMaps(map1, map2)
	if Logic.isEmpty(map1) and Logic.isEmpty(map2) then
		return TBD, TBD
	end

	return self:displayMap(map1), self:displayMap(map2)
end

---@param map string?
---@return string
function MapVeto:displayMap(map)
	return Logic.isEmpty(map) and FP or Page.makeInternalLink(map) --[[@as string]]
end

---@param args table
---@return Html
function CustomMatchSummary.getByMatchId(args)
	return MatchSummary.defaultGetByMatchId(CustomMatchSummary, args, {width = '480px'})
end

---@param match MatchGroupUtilMatch
---@param footer MatchSummaryFooter
---@return MatchSummaryFooter
function CustomMatchSummary.addToFooter(match, footer)
	footer = MatchSummary.addVodsToFooter(match, footer)

	if Table.isNotEmpty(match.links) then
		footer:addElement(ExternalLinks.print(match.links))
	end

	return footer
end

---@param match MatchGroupUtilMatch
---@return MatchSummaryBody
function CustomMatchSummary.createBody(match)
	local body = MatchSummary.Body()

	if match.dateIsExact or match.timestamp ~= DateExt.defaultTimestamp then
		-- dateIsExact means we have both date and time. Show countdown
		-- if match is not default date, we have a date, so display the date
		body:addRow(MatchSummary.Row():addElement(
			DisplayHelper.MatchCountdownBlock(match)
		))
	end

	-- Iterate each map
	for gameIndex, game in ipairs(match.games) do
		local rowDisplay = CustomMatchSummary._createGame(game, gameIndex, match.date)
		if rowDisplay then
			body:addRow(rowDisplay)
		end
	end

	-- Add Match MVP(s)
	if Table.isNotEmpty(match.extradata.mvp) then
		body.root:node(MatchSummaryWidgets.Mvp{
			players = match.extradata.mvp.players,
			points = match.extradata.mvp.points,
		})
	end

	-- casters
	body:addRow(MatchSummary.makeCastersRow(match.extradata.casters))

	-- Pre-Process Champion Ban Data
	local championBanData = {}
	for gameIndex, game in ipairs(match.games) do
		local extradata = game.extradata or {}
		local banData = {{}, {}}
		local numberOfBans = 0
		for index = 1, MAX_NUM_BANS do
			if String.isNotEmpty(extradata['team1ban' .. index]) then
				numberOfBans = index
				banData[1][index] = extradata['team1ban' .. index]
			end
			if String.isNotEmpty(extradata['team2ban' .. index]) then
				numberOfBans = index
				banData[2][index] = extradata['team2ban' .. index]
			end
		end

		if numberOfBans > 0 then
			banData[1].color = extradata.team1side
			banData[2].color = extradata.team2side
			banData.numberOfBans = numberOfBans
			championBanData[gameIndex] = banData
		end
	end

	-- Add the Champion Bans
	if not Table.isEmpty(championBanData) then
		local championBan = ChampionBan()

		Array.forEach(match.games,function (_, gameIndex)
			championBan:banRow(championBanData[gameIndex], gameIndex, match.date)
		end)

		body:addRow(championBan)
	end

	-- Add the Map Vetoes
	body:addRow(MatchSummary.defaultMapVetoDisplay(match, MapVeto()))

	return body
end

---@param game MatchGroupUtilGame
---@param gameIndex integer
---@param date string
---@return MatchSummaryRow?
function CustomMatchSummary._createGame(game, gameIndex, date)
	local row = MatchSummary.Row()
	local extradata = game.extradata or {}

	local championsData = {{}, {}}
	local championsDataIsEmpty = true
	for champIndex = 1, NUM_CHAMPIONS_PICK do
		if String.isNotEmpty(extradata['team1champion' .. champIndex]) then
			championsData[1][champIndex] = extradata['team1champion' .. champIndex]
			championsDataIsEmpty = false
		end
		if String.isNotEmpty(extradata['team2champion' .. champIndex]) then
			championsData[2][champIndex] = extradata['team2champion' .. champIndex]
			championsDataIsEmpty = false
		end
		championsData[1].color = extradata.team1side
		championsData[2].color = extradata.team2side
	end

	if
		Logic.isEmpty(game.length) and
		Logic.isEmpty(game.winner) and
		championsDataIsEmpty
	then
		return nil
	end

	row:addClass('brkts-popup-body-game')
		:css('font-size', '90%')
		:css('padding', '4px')
		:css('min-height', '32px')

	row:addElement(CustomMatchSummary._opponentChampionsDisplay(championsData[1], NUM_CHAMPIONS_PICK, date, false))
	row:addElement(CustomMatchSummary._createCheckMark(game.winner == 1))
	row:addElement(mw.html.create('div')
		:addClass('brkts-popup-body-element-vertical-centered')
		:css('min-width', '120px')
		:css('margin-left', '1%')
		:css('margin-right', '1%')
		:node(mw.html.create('div')
			:css('margin', 'auto')
			:wikitext('[[' .. game.map .. ']]')
		)
	)
	row:addElement(CustomMatchSummary._createCheckMark(game.winner == 2))
	row:addElement(CustomMatchSummary._opponentChampionsDisplay(championsData[2], NUM_CHAMPIONS_PICK, date, true))

	if Logic.isNotEmpty(game.comment) or Logic.isNotEmpty(game.length) then
		game.length = Logic.nilIfEmpty(game.length)
		local commentContents = Array.append({},
			Logic.nilIfEmpty(game.comment),
			game.length and tostring(mw.html.create('span'):wikitext('Match Duration: ' .. game.length)) or nil
		)
		row
			:addElement(MatchSummary.Break():create())
			:addElement(mw.html.create('div')
				:css('margin', 'auto')
				:wikitext(table.concat(commentContents, '<br>'))
			)
	end

	return row
end

---@param isWinner boolean?
---@return Html
function CustomMatchSummary._createCheckMark(isWinner)
	local container = mw.html.create('div')
		:addClass('brkts-popup-spaced')
		:css('line-height', '27px')
		:css('margin-left', '1%')
		:css('margin-right', '1%')

	if isWinner then
		container:node(GREEN_CHECK )
	else
		container:node(NO_CHECK)
	end

	return container
end

---@param opponentChampionsData table
---@param numberOfChampions integer
---@param date string
---@param flip boolean?
---@param isBan boolean?
---@return Html
function CustomMatchSummary._opponentChampionsDisplay(opponentChampionsData, numberOfChampions, date, flip, isBan)
	local opponentChampionsDisplay = {}
	local color = opponentChampionsData.color or ''
	opponentChampionsData.color = nil

	for index = 1, numberOfChampions do
		local champDisplay = mw.html.create('div')
		:addClass('brkts-popup-side-color-' .. color)
		:css('float', flip and 'right' or 'left')
		:node(CharacterIcon.Icon{
			character = opponentChampionsData[index] or NO_CHARACTER,
			class = 'brkts-champion-icon',
			date = date,
		})
		if index == 1 then
			champDisplay:css('padding-left', '2px')
		elseif index == numberOfChampions then
			champDisplay:css('padding-right', '2px')
		end
		table.insert(opponentChampionsDisplay, champDisplay)
	end

	if flip then
		opponentChampionsDisplay = Array.reverse(opponentChampionsDisplay)
	end

	local display = mw.html.create('div')
	if isBan then
		display:addClass('brkts-popup-side-shade-out')
		display:css('padding-' .. (flip and 'right' or 'left'), '4px')
	end

	for _, item in ipairs(opponentChampionsDisplay) do
		display:node(item)
	end

	return display
end

return CustomMatchSummary
