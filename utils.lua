local HD = HD

local waitTable = {}
local waitFrame = nil

function HD:setTimeout(delay, func, ...)
	if(type(delay) ~= "number" or type(func) ~= "function") then
		return false
	end
	if(waitFrame == nil) then
		waitFrame = CreateFrame("Frame", "WaitFrame", UIParent)
		waitFrame:SetScript("onUpdate", function(self, elapse)
			local count = #waitTable
			local i = 1
			while(i <= count) do
				local waitRecord = tremove(waitTable, i)
				local d = tremove(waitRecord,1)
				local f = tremove(waitRecord,1)
				local p = tremove(waitRecord,1)
				if(d > elapse) then
					tinsert(waitTable, i, {d-elapse, f, p})
					i = i + 1
				else
					count = count - 1
					f(unpack(p))
				end
			end
			end
		)
	end
	tinsert(waitTable, {delay, func, {...}})
	return true
end

function HD:isEqualEventIndex(tableA, tableB)
	-- We expect both to be tables not nil.
	if (tableA == nil or tableB == nil) then
		return false
	end
	if (tableA.offsetMonths ~= tableB.offsetMonths) then
		return false
	elseif (tableA.monthDay ~= tableB.monthDay) then
		return false
	elseif (tableA.eventIndex ~= tableB.eventIndex) then
		return false
	end
	return true
end

function HD:isEqualFormatedEvents(eventsA, eventsB)
	if (#eventsA ~= #eventsB) then
		return false
	end
	for i = 1, #eventsA do
		if (not HD:isEqualFormatedEvent(eventsA[i], eventsB[i])) then
			return false
		end
	end
	return true
end

function HD:isEqualFormatedEvent(tableA, tableB)
	if (tableA.id ~= tableB.id) then
		return false
	elseif (tableA.title ~= tableB.title) then
		return false
	elseif (tableA.timestamp ~= tableB.timestamp) then
		return false
	end
	return true
end
