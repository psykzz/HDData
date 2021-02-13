HD = {}
HDConfig = {
	debug = false,
	Calendar = {
		shortFormat = false,
		daysToParse = 21,
	},
	Inspect = {
	},
}
HDData = HDData or  {
	Version = 1,
	Calendar = {},
	Inspect = {},
}

if not HDData.Version then
	HDData.Version = 1
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOADING_SCREEN_DISABLED")
f:RegisterEvent("PLAYER_STARTED_MOVING")

f:SetScript("OnEvent", function(self, event, ...) HD:OnEvent(self, event, ...) end)
