-- OutstandingItems Sub-module: Event handling
-- Part of HousingOutstandingItemsUI

local _G = _G
local OutstandingItemsUI = _G["HousingOutstandingItemsUI"]
if not OutstandingItemsUI then return end

local function IsInNonWorldInstance()
    if not IsInInstance then return false end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType and instanceType ~= "none"
end

local function HidePopupIfShown()
    local popupFrame = OutstandingItemsUI._popupFrame
    if popupFrame and popupFrame.IsShown and popupFrame:IsShown() then
        popupFrame:Hide()
    end
end

local function EnsureEventFrame()
    local eventFrame = OutstandingItemsUI._eventFrame
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        OutstandingItemsUI._eventFrame = eventFrame

        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DIFFICULTY_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
                if IsInNonWorldInstance() then
                    HidePopupIfShown()
                    return
                end
            end

            local function TryZoneCheck(attempt)
                if attempt > 10 then
                    return
                end

                local zoneMapID, zone = OutstandingItemsUI:GetCurrentZone()

                local hasData = false
                if HousingDataManager and HousingDataManager.HasIndexCache then
                    hasData = HousingDataManager:HasIndexCache()
                end

                if not hasData and HousingDB and HousingDB.settings and HousingDB.settings.showOutstandingPopup then
                    if HousingDataManager and HousingDataManager.GetAllItemIDs then
                        pcall(function() HousingDataManager:GetAllItemIDs() end)
                        hasData = HousingDataManager:HasIndexCache()
                    end
                end

                if (not zoneMapID and not zone) or not hasData then
                    C_Timer.After(1, function()
                        TryZoneCheck(attempt + 1)
                    end)
                    return
                end

                OutstandingItemsUI:OnZoneChanged()
            end

            C_Timer.After(2, function()
                TryZoneCheck(1)
            end)
        end)
    end
    return eventFrame
end

function OutstandingItemsUI:OnZoneChanged()
    if IsInNonWorldInstance() then
        HidePopupIfShown()
        return
    end

    local mapID, zoneName = self:GetCurrentZone()
    local zoneKey = mapID or zoneName

    if not zoneKey then
        return
    end

    if zoneKey == self._currentZoneKey then
        return
    end

    self._currentZoneKey = zoneKey

    if HousingDB and HousingDB.settings and HousingDB.settings.autoFilterByZone then
        if zoneName and HousingFilters and HousingFilters.SetZoneFilter then
            HousingFilters:SetZoneFilter(zoneName)
        end
    end

    if HousingDB and HousingDB.settings and HousingDB.settings.showOutstandingPopup then
        if zoneKey ~= self._lastPopupZoneKey then
            local outstanding = self:GetOutstandingItemsForZone(mapID, zoneName)
            if outstanding and outstanding.total and outstanding.total > 0 then
                self._lastPopupZoneKey = zoneKey
                print("|cFF8A7FD4HousingVendor:|r Found " .. outstanding.total .. " uncollected items in " .. (zoneName or "this zone"))
                self:ShowPopup(zoneName or "Current Zone", outstanding)
            end
        end
    end
end

function OutstandingItemsUI:StartEventHandlers()
    local frame = EnsureEventFrame()
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
end

function OutstandingItemsUI:StopEventHandlers()
    local frame = self._eventFrame
    if frame then
        frame:UnregisterAllEvents()
    end
end

return OutstandingItemsUI

