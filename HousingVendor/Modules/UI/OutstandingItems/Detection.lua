-- OutstandingItems Sub-module: Detection logic
-- Part of HousingOutstandingItemsUI

local _G = _G
local OutstandingItemsUI = _G["HousingOutstandingItemsUI"]
if not OutstandingItemsUI then return end

function OutstandingItemsUI:GetCurrentZone()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if mapID and C_Map and C_Map.GetMapInfo then
        local mapInfo = C_Map.GetMapInfo(mapID)
        if mapInfo and mapInfo.name and mapInfo.name ~= "" then
            return mapID, mapInfo.name
        end
    end

    local fallbackName = _G.GetRealZoneText and _G.GetRealZoneText() or nil
    if fallbackName and fallbackName ~= "" then
        return nil, fallbackName
    end

    return nil, nil
end

function OutstandingItemsUI:GetOutstandingItemsForZone(mapID, zoneName)
    if (not mapID and not zoneName) or not HousingDataManager then
        return nil
    end

    local ids = nil
    if HousingDataManager.GetAllItemIDs then
        ids = HousingDataManager:GetAllItemIDs()
    end
    if not ids or #ids == 0 then
        if HousingDataManager.GetAllItems then
            local allItems = HousingDataManager:GetAllItems()
            ids = {}
            for _, item in ipairs(allItems or {}) do
                local idNum = item and tonumber(item.itemID)
                if idNum then
                    ids[#ids + 1] = idNum
                end
            end
        end
    end
    if not ids or #ids == 0 then
        return nil
    end

    local outstanding = {
        total = 0,
        vendors = {},
        quests = {},
        achievements = {},
        drops = {},
        professions = {},
    }

    local function IsCollected(itemID)
        if HousingDataManager.IsItemCollected then
            return HousingDataManager:IsItemCollected(itemID)
        end
        if HousingCompletionTracker and HousingCompletionTracker.IsCollected then
            return HousingCompletionTracker:IsCollected(itemID)
        end
        return false
    end

    for _, idNum in ipairs(ids) do
        local record = HousingDataManager.GetItemRecord and HousingDataManager:GetItemRecord(idNum) or nil
        if record then
            local recordZone = nil
            if _G.HousingVendorHelper and _G.HousingVendorHelper.GetZoneName then
                recordZone = _G.HousingVendorHelper:GetZoneName(record, nil)
            else
                recordZone = record._apiZone or record.zoneName
            end

            local matchesZone = false
            if mapID and record.mapID and record.mapID ~= 0 and record.mapID == mapID then
                matchesZone = true
            elseif zoneName and recordZone and recordZone == zoneName then
                matchesZone = true
            elseif zoneName and (record._apiZone == zoneName or record.zoneName == zoneName) then
                matchesZone = true
            end

            if matchesZone then
                local itemID = tonumber(record.itemID) or idNum
                if not IsCollected(itemID) then
                    outstanding.total = outstanding.total + 1

                    local src = record._sourceType or record.sourceType or "Vendor"

                    -- Categorize by source type (use _sourceType as authoritative)
                    if src == "Quest" then
                        table.insert(outstanding.quests, record)
                    elseif src == "Achievement" then
                        table.insert(outstanding.achievements, record)
                    elseif src == "Drop" then
                        table.insert(outstanding.drops, record)
                    elseif src == "Profession" then
                        table.insert(outstanding.professions, record)
                    else
                        -- Default to Vendor (includes items with _sourceType = "Vendor" or no _sourceType)
                        local vendorName = nil
                        local vendorCoords = nil
                        if _G.HousingVendorHelper then
                            vendorName = _G.HousingVendorHelper:GetVendorName(record, nil)
                            vendorCoords = _G.HousingVendorHelper:GetVendorCoords(record, nil)
                        else
                            vendorName = record.vendorName or record._apiVendor
                            vendorCoords = record.vendorCoords
                        end

                        if vendorName and vendorName ~= "" then
                            local entry = outstanding.vendors[vendorName]
                            if not entry then
                                entry = { name = vendorName, coords = vendorCoords, items = {} }
                                outstanding.vendors[vendorName] = entry
                            end
                            table.insert(entry.items, record)
                        end
                    end
                end
            end
        end
    end

    return outstanding
end

return OutstandingItemsUI

