local BoWLoot2 = LibStub('AceAddon-3.0'):NewAddon('BoWLoot2', 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0')
local AceGUI = LibStub('AceGUI-3.0')
local BoWLoot2_version = '2.0.3'

local options = {
	name = 'SciCalc',
	handler = SciCalc,
	type = 'group',
	args = {
		add = {
			type = 'execute',
			name = 'Add Item',
			desc = 'Adds an item to the loot system.',
			func = function(input)
				local _, _, item = string.find(input['input'], '(|c%x+|Hitem:%d+:.-|r)')
				BoWLoot2:AddItem(item)
				BoWLoot2:Print('Added item', item)
			end,
		},
		show = {
			type = 'execute',
			name = 'Show Loot Window',
			desc = 'Shows the loot window.',
			func = function(input)
				BoWLoot2.lootFrame:Show()
			end,
		},
		rarity = {
			type = 'execute',
			name = 'Set Rarity',
			desc = 'Sets minimum rarity.  Expects integer 0-7 (4 is epic).',
			func = function(input)
				local _, _, rarity = string.find(input['input'], '(%d+)')
				BoWLoot2.minrarity = tonumber(rarity)
				BoWLoot2:Print('Rarity set to', rarity)
			end,
		},
		version = {
			type = 'execute',
			name = 'Get Version',
			desc = 'Shows the addon\'s version',
			func = function()
				BoWLoot2:Print('Installed version:', BoWLoot2_version)
			end,
		} 
	}
}

function BoWLoot2:OnInitialize()
	LibStub('AceConfig-3.0'):RegisterOptionsTable('BoWLoot2', options, { 'bowloot2', 'bl' })
	
	self.minrarity = 4
	
	self:RegisterEvent('LOOT_OPENED')
	self.lootFrame = AceGUI:Create('Window')
	self.lootFrame:SetTitle('BoWLoot2 Loot Frame')
	self.lootFrame:SetWidth(250)
	self.lootFrame:SetHeight(245)
	self.lootFrame:SetLayout('Flow')
	self.lootFrame:EnableResize(false)
	self.lootFrame:Hide()
	
	self.lootFrame.announce = AceGUI:Create('InteractiveLabel')
	self.lootFrame.announce:SetText('Announce')
	self.lootFrame.announce:SetColor(1, 0, 0)
	self.lootFrame.announce:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE, MONOCHROME')
	self.lootFrame.announce:SetCallback('OnClick', 
		function(widget)
			self:StartAnnouncing()
		end
	)
	
	self.lootFrame.clear = AceGUI:Create('InteractiveLabel')
	self.lootFrame.clear:SetText('Clear and Cancel')
	self.lootFrame.clear:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE, MONOCHROME')
	self.lootFrame.clear:SetColor(1, 0, 0)
	self.lootFrame.clear:SetCallback('OnClick', 
		function(widget)
			self:EndLoot()
		end
	)
	
	self.lootFrame.show = AceGUI:Create('InteractiveLabel')
	self.lootFrame.show:SetText('Show Current Loot')
	self.lootFrame.show:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE, MONOCHROME')
	self.lootFrame.show:SetColor(1, 0, 0)
	self.lootFrame.show:SetCallback('OnClick', 
		function(widget)
			self:ShowLootLocal()
		end
	)
	
	self.lootFrame.officers = AceGUI:Create('InteractiveLabel')
	self.lootFrame.officers:SetText('Show Officers')
	self.lootFrame.officers:SetFont('Fonts\\FRIZQT__.TTF', 12, 'OUTLINE, MONOCHROME')
	self.lootFrame.officers:SetColor(1, 0, 0)
	self.lootFrame.officers:SetCallback('OnClick', 
		function(widget)
			self:ShowOfficers()
		end
	)
	
	self.lootFrame.links = AceGUI:Create('SimpleGroup')
	
	self.lootFrame:AddChild(self.lootFrame.announce)
	self.lootFrame:AddChild(self.lootFrame.clear)
	self.lootFrame:AddChild(self.lootFrame.show)
	self.lootFrame:AddChild(self.lootFrame.officers)
	self.lootFrame:AddChild(self.lootFrame.links)
	
	self.doingloot = false
	self.currentloot = {}
	
	self:RegisterEvent('CHAT_MSG_WHISPER')
end

function BoWLoot2:TellRaid(msg)
	SendChatMessage(msg, 'RAID')
	--self:Print('To Raid:', msg)
end

function BoWLoot2:TellUser(user, msg)
	SendChatMessage('[BoWLoot2] ' .. msg, 'WHISPER', 'Common', user)
	--self:Print('To', user, ':', msg)
end

function BoWLoot2:TellOfficers(msg)
	SendChatMessage(msg, 'OFFICER')
	--SendChatMessage(msg, 'CHANNEL', 'Common', GetChannelName('bowloot'));
	--self:Print('To Officers:', msg)
end

function BoWLoot2:StartAnnouncing()
	if #self.currentloot > 0 then
		self.lootFrame.announce:SetColor(.2, .2, .2)
		self.lootFrame.announce:SetCallback('OnClick', 
			function(widget)
				self:Print('Already announcing')
			end
		)
		local total = 60
		local times = { 0, 30, 50 }
		for _, t in pairs(times) do
			self:ScheduleTimer('AnnounceLoot', t, total - t)
		end
		self:ScheduleTimer(
			function(arg) 
				self:TellRaid('-- Loot Closed --')
				self:ShowOfficers()
				self:EndLoot()
			end
		,
		total
		)
	else
		self:Print('No loot in system')
	end
end

function BoWLoot2:ShowOfficers()
	for i, info in pairs(self.currentloot) do
		self:TellOfficers(info['link'] .. 'x' .. info['num'])
		for from, message in pairs(info['bids']) do
			if message['msg'] == nil then message['msg'] = '' end
			local _, _, _, ilevel = GetItemInfo(info['link'])
			self:TellOfficers('    ' .. from .. ', ' .. message['current'] .. ', dILVL=' .. (ilevel - message['ilevel']) .. ', ' .. message['msg'])
		end
	end
end

function BoWLoot2:ShowLootLocal()
	if #self.currentloot > 0 then
		for k, v in pairs(self.currentloot) do
			self:Print(k .. ') ' .. v['link'] .. ' x' .. v['num'])
		end
	else
		self:Print('No loot in system')
	end
end

function BoWLoot2:AnnounceLoot(timeleft)
	self:TellRaid('--- BoW Loot System: You have ' .. timeleft .. ' sec. to join for loot ---')
	local i = 1
	for i, v in ipairs(self.currentloot) do
		self:TellRaid(i .. ') ' .. v['link'] .. ' x' .. v['num'])
	end
	self:TellRaid('Whisper me \'loot help\' for instructions')
end

function BoWLoot2:LOOT_OPENED()
	doShow = false
	for i=1,GetNumLootItems() do
		l = GetLootSlotLink(i)
		if l ~= nil and self:AddItem(l) then
			doShow = true
		end
	end
	if doShow then
		self.lootFrame:Show()
	end
end

function BoWLoot2:ItemExists(l)
	for _, v in pairs(self.currentloot) do
		if v['link'] == l then
			return true
		end
	end
	return false
end

function BoWLoot2:AddItem(l)
	if not self.doingloot then
		self:StartLoot()
	end
	
	local _, _, rarity = GetItemInfo(l)
	
	if l and rarity >= self.minrarity then
		if not BoWLoot2:ItemExists(l) then				
			link = AceGUI:Create('InteractiveLabel')
			link:SetText(l)
			self.lootFrame.links:AddChild(link)
			table.insert(self.currentloot, { num=1, link=l, bids={} })
		else
			for i, v in pairs(self.currentloot) do
				if v['link'] == l then
					self.currentloot[i]['num'] = self.currentloot[i]['num'] + 1
					break
				end
			end
		end
		return true
	end
	return false
end

function BoWLoot2:StartLoot()
	self.doingloot = true
	self.currentloot = {}
end

function BoWLoot2:EndLoot()
	self.doingloot = false
	self.currentloot = {}
	self.lootFrame.links:ReleaseChildren()
	
	self:CancelAllTimers()
	self.lootFrame.announce:SetColor(1, 0, 0)
	self.lootFrame.announce:SetCallback('OnClick', 
		function(widget)
			self:StartAnnouncing()
		end
	)
end

function BoWLoot2:CHAT_MSG_WHISPER(_, msg, from)
	if msg == 'loot help' then
		self:TellUser(from, 'To bid on an item, send the number of the item you\'d like followed by a link to the item you currently have.  After this you can include a message for the loot council.')
		self:TellUser(from, '    Example: 3 [Item Link Here] this is my message')
		self:TellUser(from, '    The order of the item number and item link does not matter, only that the message comes last.')
	elseif msg == 'invite' then
		InviteUnit(from)
	end
	if self.doingloot then
		local _, _, before, currentItem, after = string.find(msg, '(.*)(|c%x+|Hitem:%d+:.-|r)(.*)')
		if currentItem ~= nil then
			local message = after
			local _, _, bidItem = string.find(before, '(%d+)')
			if bidItem == nil then
				_, _, bidItem, after = string.find(after, '(%d+)(.*)')
				message = after
			end
			
			if bidItem ~= nil then
				bidItem = tonumber(strtrim(bidItem))
				if message ~= nil then
					message = strtrim(message)
				end
				
				if self.currentloot[bidItem] == nil then
					self:TellUser(from, '*** Invalid Item Number.  Bid in format [item number] [current item link] [optional comment] ***')
				else
					local _, _, _, currentilevel = GetItemInfo(currentItem)
					if currentilevel == nil then
						currentilevel = 0
					end
					self.currentloot[bidItem]['bids'][from] = { msg=message, current=currentItem, ilevel=currentilevel}
					if from ~= UnitName('player') then
						self:TellUser(from, 'Your bid for ' .. self.currentloot[bidItem]['link'] .. ' has been received')
					else
						self:TellUser(from, 'Bid from lootmaster has been received')
					end
				end
			else
				self:TellUser(from, '*** Invalid Bid ***')
				self:TellUser(from, '   Send the number of the item you want plus a link to your current item, followed by an optional short message')
			end
		end
	end
end