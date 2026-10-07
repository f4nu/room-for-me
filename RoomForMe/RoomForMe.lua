-- Hides groups in the Looking For Group browser (Blizzard_GroupFinder_VanillaStyle)
-- that have open slots, but none for any role you have ticked.
--
-- Blizzard already sorts such groups lower (HasRemainingSlotsForLocalPlayerRole in
-- Blizzard_LFGVanilla_Browse.lua); this removes them. Solo players, your own listing
-- and groups that report no open slots at all (activities without roles) are kept.

local ADDON = ...
local BLIZZARD_LFG = "Blizzard_GroupFinder_VanillaStyle"

local function IsEnabled()
	return RoomForMeDB == nil or RoomForMeDB.enabled ~= false
end

-- The roles ticked in the group finder, or nil if none are, in which case nothing is hidden.
local function MyRoles()
	for _, get in ipairs({ C_LFGListRoles.GetRoles, C_LFGListRoles.GetSavedRoles }) do
		local roles = get()
		if roles and (roles.tank or roles.healer or roles.dps) then
			return roles
		end
	end
end

local function HasRoomFor(resultID, roles)
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if not info or info.hasSelf or info.numMembers <= 1 then
		return true
	end
	local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
	if not counts then
		return true
	end
	local tank = counts.TANK_REMAINING or 0
	local healer = counts.HEALER_REMAINING or 0
	local dps = counts.DAMAGER_REMAINING or 0
	if tank + healer + dps == 0 then
		return true
	end
	return (roles.tank and tank > 0) or (roles.healer and healer > 0) or (roles.dps and dps > 0) or false
end

-- Runs after Blizzard sorts the result list, before it is drawn; filters it in place.
local function FilterResults(results)
	if not IsEnabled() then
		return
	end
	local roles = MyRoles()
	if not roles then
		return
	end
	local kept = 0
	for i = 1, #results do
		local resultID = results[i]
		if HasRoomFor(resultID, roles) then
			kept = kept + 1
			results[kept] = resultID
		end
	end
	for i = #results, kept + 1, -1 do
		results[i] = nil
	end
end

local function Refresh()
	if LFGBrowseFrame and LFGBrowseFrame:IsShown() then
		LFGBrowseFrame:UpdateResultList()
	end
end

local function SetEnabled(enabled)
	RoomForMeDB.enabled = enabled
	Refresh()
end

local function HookBlizzardLFG()
	hooksecurefunc("LFGBrowseUtil_SortSearchResults", FilterResults)

	-- With everything filtered away Blizzard draws an empty list; say why.
	hooksecurefunc(LFGBrowseFrame, "UpdateResults", function(self)
		if not self.searching and not self.searchFailed and self.totalResults > 0 and #self.results == 0 then
			self.NoResultsFound:SetText("No groups have room for your role.")
			self.NoResultsFound:Show()
		end
	end)
end

EventUtil.ContinueOnAddOnLoaded(ADDON, function()
	RoomForMeDB = RoomForMeDB or {}
	if RoomForMeDB.enabled == nil then
		RoomForMeDB.enabled = true
	end
end)

EventUtil.ContinueOnAddOnLoaded(BLIZZARD_LFG, HookBlizzardLFG)

-- A checkbox in the gear menu of the Looking For Group window.
Menu.ModifyMenu("MENU_LFG_LISTING_SETTINGS", function(owner, rootDescription)
	rootDescription:CreateCheckbox("Hide groups with no room for my role", IsEnabled, function()
		SetEnabled(not IsEnabled())
	end)
end)

local events = CreateFrame("Frame")
events:RegisterEvent("LFG_LIST_ROLE_UPDATE")
events:SetScript("OnEvent", Refresh)

SLASH_ROOMFORME1 = "/rfm"
SlashCmdList.ROOMFORME = function()
	SetEnabled(not IsEnabled())
	print("Room For Me: " .. (IsEnabled() and "on" or "off"))
end
