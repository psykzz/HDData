--[[
    The purpose of this addon is to generate data structures that can be used in Weakauras.
    Questions? Speak to PsyKzz#4695 (discord)
]]

local HD = HD
local config = HDConfig
local processedEvents = {}

local initialized = false
local initializationTimeout = false

local waitTable = {}
local waitFrame = nil

function HD:debug(cat, msg)
    if (config.debug) then
		print(string.format("HD: [%s] %s", cat, msg))
	end
end

function HD:OnEvent(self, event, ...)
	HD:debug('InitEvent', event..' '..time())

	HD:SetupInspection()
	
	if (event == 'LOADING_SCREEN_DISABLED') then
		HD:TryInitCalendar()
		self:UnregisterEvent("LOADING_SCREEN_DISABLED")
	end
	
	if (not initialized and initializationTimeout) then
		if (event == 'PLAYER_STARTED_MOVING') then
            HD:TryInitCalendar()
            self:UnregisterEvent("PLAYER_STARTED_MOVING")
		end
	end
	
	if (initialized) then
		if (event == 'PLAYER_STARTED_MOVING') then
			self:UnregisterEvent("PLAYER_STARTED_MOVING")
		end
	end
end
function HD:OnCalendarChange(self, event, ...)
	HD:debug('CalendarEvent', event..' '..time())
end

-- Calendar data
function HD:TryInitCalendar(i)
    HD:debug('Calendar','Init module')
    if (not i) then
		i = 1
		processedEvents = {}
		initializationTimeout = false
		initialized = false
	end
	
	if (i <= 20) then
		HD:debug('Calendar', 'Initialization : Iteration n°' .. i)
		HD:SetupCalendar()
		local events = HD:FindEvents()
		if (#events > 0) then
			processedEvents = events
			initialized = true
			HD:SetupCalendarEvents()
			return
		end
		i = i + 1
		HD:setTimeout(0.5, HD.TryInitCalendar, HD, i)
	else
		initializationTimeout = true
	end
    HD:debug('Calendar','Init finished')
end
function HD:SetupCalendar()
    HD:debug('Calendar','Setup Calendar')
    CalendarFrame_CloseEvent()
    local currentTime = C_DateAndTime.GetCurrentCalendarTime()
    C_Calendar.SetAbsMonth(currentTime.month, currentTime.year)
    C_Calendar.OpenCalendar()
    HD:debug('Calendar','Setup Calendar finished')
end

function HD:SetupCalendarEvents()
    local calFrame = CreateFrame("Frame")
	calFrame:RegisterEvent("CALENDAR_OPEN_EVENT")
	calFrame:RegisterEvent("CALENDAR_UPDATE_EVENT")
	calFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
	calFrame:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
	calFrame:RegisterEvent("CALENDAR_ACTION_PENDING")
	calFrame:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
	calFrame:RegisterEvent("CALENDAR_CLOSE_EVENT")
    calFrame:SetScript("OnEvent", function(self, event, ...) HD:OnCalendarChange(self, event, ...) end)

    -- Start processing events
    HD:EnqueueEvent()
end

function HD:FindEvents()
	local eventsFound = {}
	local currTime = C_DateAndTime.GetCurrentCalendarTime()
	if (currTime.monthDay == 0) then
		return eventsFound
	end
	
	for i = 0, config.Calendar.daysToParse do
		i = i * -1 -- only look back, not forward.
		local newDate = C_DateAndTime.AdjustTimeByDays(currTime, i)
		local monthOffset = newDate.month - currTime.month		
		local numEvents = C_Calendar.GetNumDayEvents(monthOffset, newDate.monthDay)
		
		for j = 1, numEvents do
			local event = C_Calendar.GetDayEvent(monthOffset, newDate.monthDay, j)
			if (event.eventType == 0 and (event.calendarType == 'PLAYER' or event.calendarType == 'GUILD_EVENT')) then
				table.insert(eventsFound, event)
			end
		end
		
	end
	HD:debug('Calendar', 'Found events: ' .. #eventsFound)
	if (#eventsFound > 0) then
        return HD:ProcessEvents(eventsFound)
    else
        return {}
	end
	return eventsFound
end


function HD:OpenProcessedEvent(i)
	HD:debug('Calendar', 'Opening event ' .. processedEvents[i]['id'])
	local indexInfo = C_Calendar.GetEventIndexInfo(processedEvents[i]['id'])
	C_Calendar.OpenEvent(indexInfo.offsetMonths, indexInfo.monthDay, indexInfo.eventIndex)
end

function HD:TryGetAttendance(eventID, i)
	if (not i) then
		i = 1
	end
	if (i <= 30) then
		HD:debug('cal', 'Attendance: Iteration n°' .. i)
		local currentEventIndex = C_Calendar.GetEventIndex()
		if (currentEventIndex) then
			local eventIndex = C_Calendar.GetEventIndexInfo(eventID)
			if (HD:isEqualEventIndex(currentEventIndex, eventIndex)) then
				HD:debug('calendar', 'eventID ' .. eventID .. ' found')
				local attendance = HD:GetCurrentAttendance()
				if (attendance) then
					HD:debug('calendar', 'Attendance for ' .. eventID .. ' found')
					HD:InsertAttendance(attendance, eventID)
					HD:SaveCalendar()
					HD:EnqueueEvent(eventID)
					return
				end
			end
		end
		i = i + 1
		HD:setTimeout(0.05, HD.TryGetAttendance, HD, eventID, i)
	end
end
function HD:EnqueueEvent(previousEventID)
	local index = 1
	
	if (not previousEventID) then
		local eventID = processedEvents[index]['id']
		HD:OpenProcessedEvent(index)
		HD:TryGetAttendance(eventID)
	else
		for i = 1, #processedEvents do
			if (processedEvents[i]['id'] == previousEventID) then
				index = i + 1
				if (index <= #processedEvents) then
					HD:OpenProcessedEvent(index)
					HD:TryGetAttendance(processedEvents[index]['id'])
				else
					CalendarFrame_CloseEvent()
				end
				return
			end
		end
	end
	
	HD:debug('Calendar', 'Queuing event n°' .. index)
end

function HD:GetCurrentAttendance()
	local attendance = {}
	local numInvites = C_Calendar.GetNumInvites()
	for i = 1, numInvites do
		local invite = C_Calendar.EventGetInvite(i)
		if invite.name then
            attendance[i] = {
                ['name'] = invite.name,
                ['class'] = invite.classID,
                ['status'] = invite.inviteStatus
            }
		end
	end
	return attendance
end

function HD:InsertAttendance(attendance, eventID)
	for i = 1, #processedEvents do
		if (processedEvents[i]['id'] == eventID) then
			processedEvents[i]['attendance'] = attendance
			break
		end
	end
end

function HD:SaveCalendar()
	HD:debug('Calendar', 'Saving')
	HDData.Calendar = {
		['updated'] = time(),
		['numEvents'] = #processedEvents,
		['events'] = processedEvents
	}
end


function HD:ProcessEvent(event)
	local dateTableStart = {
		['day'] = event.startTime.monthDay,
		['month'] = event.startTime.month,
		['year'] = event.startTime.year,
		['hour'] = event.startTime.hour,
		['min'] = event.startTime.minute,
	}
	local dateTableEnd = {
		['day'] = event.endTime.monthDay,
		['month'] = event.endTime.month,
		['year'] = event.endTime.year,
		['hour'] = event.endTime.hour,
		['min'] = event.endTime.minute,
	}
	
	local fullFormatedEvent = {
		['id'] = event.eventID,
		['title'] = event.title,
		['isCustomTitle'] = event.isCustomTitle,
		['timestamp'] = time(dateTableStart),
		['startTime'] = event.startTime,
		['endTime'] = event.endTime,
		['calendarType'] = event.calendarType,
		['sequenceType'] = event.sequenceType,
		['eventType'] = event.eventType,
		['iconTexture'] = event.iconTexture,
		['modStatus'] = event.modStatus,
		['inviteStatus'] = event.inviteStatus,
		['invitedBy'] = event.invitedBy,
		['difficulty'] = event.difficulty,
		['inviteType'] = event.inviteType,
		['sequenceIndex'] = event.sequenceIndex,
		['numSequenceDays'] = event.numSequenceDays,
		['difficultyName'] = event.difficultyName,
		['dontDisplayBanner'] = event.dontDisplayBanner,
		['dontDisplayEnd'] = event.dontDisplayEnd,
		['clubID'] = event.clubID,
		['isLocked'] = event.isLocked,
		['attendance'] = {}
	}
	local shortFormatedEvent = {
		['id'] = event.eventID,
		['title'] = event.title,
		['timestamp'] = time(dateTableStart),
		['attendance'] = {}
	}
	
	if (config.Calendar.shortFormat) then
		return shortFormatedEvent
	else
		return fullFormatedEvent
	end
end

function HD:ProcessEvents(events)
	local processedEvents = {}
	for i = 1, #events do
		local processedEvent = HD:ProcessEvent(events[i])
		if (processedEvent) then
			table.insert(processedEvents, processedEvent)
		end
	end
	return processedEvents
end



-- Raid inspect
local InspectCache = {}
local InspectFrame = nil
local EventFrame = nil
local InspectQueue = {}
local GuidToUnit = {}
function HD:SetupInspection()
	HD:debug('inspect', 'Setup init')
	if not InspectFrame then
		InspectFrame = CreateFrame('GameTooltip', 'InspectTooltip', nil, 'GameTooltipTemplate');
		InspectFrame:SetOwner(UIParent, 'ANCHOR_NONE');
	end
	if not EventFrame then
		local EventFrame = CreateFrame("Frame")
		EventFrame:RegisterEvent("CHAT_MSG_LOOT")
		EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
		EventFrame:RegisterEvent("INSPECT_READY")
		EventFrame:SetScript("OnEvent", function(self, event, ...) HD:OnInspectEvent(event, ...) end)
	end
	HD:RefreshGUIDCache()
	HD:InspectUnit("player")
	HD:debug('inspect', 'Setup completed')
end

function HD:InspectUnit(unit)
	local inspectInfo = HD:_InspectUnit(unit)
	if inspectInfo then
		HD:debug('inspect', 'saving inspectInfo')
		local name = UnitName(unit)
		local guid = UnitGUID(unit)
		HDData.Inspect[guid] = {
			name = name,
			guid = guid,
			armorClass = inspectInfo[1] and inspectInfo[1].itemSubClass or 'UNKNOWN',
			updated = time(),
			inspectInfo = inspectInfo
		}
	end
	return inspectInfo
end

function HD:OnInspectEvent(event, ...)
	HD:debug('inspect', 'Event: '..event)
	if event == "CHAT_MSG_LOOT" then -- REset event
		return HD:ResetCache()
	elseif event == "GROUP_ROSTER_UPDATE" then
		HD:RefreshGUIDCache()
	elseif event == "INSPECT_READY" then
		local guid = ...
		local unit = GuidToUnit[guid]
		if unit then
			HD:InspectUnit(GuidToUnit[guid])
		end
	end
end

function HD:RefreshGUIDCache()
	GuidToUnit = {}
	GuidToUnit["player"] = UnitGUID("player")
	local ubase = IsInRaid() and "raid" or "party"
	for i = 1, GetNumGroupMembers() do
		local unit = ubase..i
		local guid = UnitGUID(unit)
		if guid and unit then -- offline units etc may fail this
			GuidToUnit[guid] = unit
		end
	end
end

function HD:ResetCache()
	InspectCache = {}
end

function HD:TryInspectUnit(unit, i)

	
end

function HD:_InspectUnit(unit)
	HD:debug('inspect', 'inspecting '..unit)
	local gear = {}
	if UnitExists(unit) then
		for slotId = 1, 18 do
			local hasItem, _ = InspectFrame:SetInventoryItem(unit, slotId)
			if hasItem then
				local _, item = InspectFrame:GetItem()

				-- Handle trinkets
				if item and (slotId == 16 or slotId == 17) and item:find("item::") then
					item = GetInventoryItemLink(unit, slotId)
				end

				if(item) then
					_, _, _, itemLevel, _, itemClass, itemSubClass, _, equipType = GetItemInfo(item)
					gear[slotId] = {
						itemLevel = itemLevel,
						itemClass = itemClass,
						itemSubClass = itemSubClass,
						equipType = equipType,
					}
				end
			end
		end
	end
	return gear
end
