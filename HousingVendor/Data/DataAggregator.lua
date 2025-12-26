local DATA_ADDON_NAME = ...
local _G = _G

-- Initialize global indexed tables
_G.HousingExpansionData = _G.HousingExpansionData or {}
_G.HousingProfessionData = _G.HousingProfessionData or {}
_G.HousingReputationData = _G.HousingReputationData or {}
-- Legacy name used by other modules (Reputation.lua / PreviewPanelData.lua)
_G.HousingReputations = _G.HousingReputations or _G.HousingReputationData

-- Vendor indexing (memory-focused):
-- - Avoid storing a full second copy of vendor item records in `_G.HousingAllVendorItems`.
-- - Instead, store:
--   - A shared vendor pool (`_G.HousingVendorPool`) and per-item vendor index arrays (`_G.HousingItemVendorIndex`)
--   - Compact per-expansion vendor/zone sets for filter dropdown population (`_G.HousingVendorFilterIndex`)
_G.HousingVendorPool = _G.HousingVendorPool or {}
_G.HousingVendorPoolIndex = _G.HousingVendorPoolIndex or {}
_G.HousingItemVendorIndex = _G.HousingItemVendorIndex or {}
_G.HousingVendorFilterIndex = _G.HousingVendorFilterIndex or { vendorsByExpansion = {}, zonesByExpansion = {} }

-- Counters for statistics
local stats = {
    vendorCount = 0,
    questCount = 0,
    achievementCount = 0,
    dropCount = 0,
    reputationCount = 0,
    professionCount = 0
}

local function SafeString(v)
    if v == nil then return "" end
    if type(v) == "string" then return v end
    return tostring(v)
end

local function NormalizeNameKey(value)
    if value == nil then return nil end
    local s = tostring(value)
    s = s:lower()
    s = s:gsub("%s+", " ")
    s = s:match("^%s*(.-)%s*$")
    return (s and s ~= "") and s or nil
end

local function ResolveReputationFactionID(factionIDOrName)
    if factionIDOrName == nil or factionIDOrName == "" or factionIDOrName == "None" then
        return nil
    end

    local num = tonumber(factionIDOrName)
    if num then
        return tostring(num)
    end

    local key = NormalizeNameKey(factionIDOrName)
    if key then
        if _G.HousingVendorFactionIDsNormalized and _G.HousingVendorFactionIDsNormalized[key] then
            return tostring(_G.HousingVendorFactionIDsNormalized[key])
        end
        if _G.HousingVendorFactionIDs and _G.HousingVendorFactionIDs[factionIDOrName] then
            return tostring(_G.HousingVendorFactionIDs[factionIDOrName])
        end
    end

    return tostring(factionIDOrName)
end

local function AddFilterEntry(expansion, vendorName, zoneName)
    if not expansion or expansion == "" then
        return
    end

    local vfi = _G.HousingVendorFilterIndex
    if not vfi then
        return
    end

    if vendorName and vendorName ~= "" then
        local vendors = vfi.vendorsByExpansion[expansion]
        if not vendors then
            vendors = {}
            vfi.vendorsByExpansion[expansion] = vendors
        end
        vendors[vendorName] = true
    end

    if zoneName and zoneName ~= "" then
        local zones = vfi.zonesByExpansion[expansion]
        if not zones then
            zones = {}
            vfi.zonesByExpansion[expansion] = zones
        end
        zones[zoneName] = true
    end
end

local function GetOrCreateVendorIndex(vd)
    if not vd then return nil end

    local name = vd.vendorName
    local location = vd.location
    local faction = vd.faction
    local expansion = vd.expansion

    if not name or name == "" or name == "None" then
        return nil
    end

    -- Convert numeric faction to string for consistent comparisons
    if type(faction) == "number" then
        if faction == 0 then
            faction = "Neutral"
        elseif faction == 1 then
            faction = "Alliance"
        elseif faction == 2 then
            faction = "Horde"
        end
    end

    local key = SafeString(name) .. "|" .. SafeString(location) .. "|" .. SafeString(faction) .. "|" .. SafeString(expansion)
    local existing = _G.HousingVendorPoolIndex[key]
    if existing then
        return existing
    end

    local idx = #_G.HousingVendorPool + 1
    _G.HousingVendorPool[idx] = {
        name = name,
        location = location,
        coords = vd.coords,
        faction = faction,  -- Now stored as string
        expansion = expansion,
    }
    _G.HousingVendorPoolIndex[key] = idx
    return idx
end

-- Helper to register data by itemID
local function RegisterByItemID(targetTable, items, dataType, statKey)
    if not items then return end
    for _, item in ipairs(items) do
        local itemID = tonumber(item.itemID)
        if itemID then
            if not targetTable[itemID] then
                targetTable[itemID] = {}
            end

            -- For quest/achievement/drop, store arrays to support multiple sources per item
            -- For vendor, keep single entry (vendors are handled separately via HousingItemVendorIndex)
            if dataType == "quest" or dataType == "achievement" or dataType == "drop" then
                if not targetTable[itemID][dataType] then
                    targetTable[itemID][dataType] = {}
                end
                -- Add to array instead of overwriting
                table.insert(targetTable[itemID][dataType], item)
            else
                -- Vendor and other types use single entry (vendor has separate index system)
                targetTable[itemID][dataType] = item
            end

            if statKey then
                stats[statKey] = stats[statKey] + 1
            end
        end
    end
end

-- Public registration API (preferred by data files)
_G.HousingDataAggregator = _G.HousingDataAggregator or {}

function _G.HousingDataAggregator:RegisterExpansionItems(dataType, items)
    if dataType == "vendor" then
        RegisterByItemID(_G.HousingExpansionData, items, "vendor", "vendorCount")

        -- Build compact vendor filter data + per-item vendor indices (no full record duplication).
        if items then
            for _, item in ipairs(items) do
                local itemID = tonumber(item and item.itemID)
                local vd = item and item.vendorDetails or nil

                if vd then
                    -- Normalize reputation faction IDs when present (can be numeric string or faction name).
                    if vd.factionID and vd.factionID ~= "" and vd.factionID ~= "None" then
                        vd.factionID = ResolveReputationFactionID(vd.factionID) or vd.factionID
                    end

                    local expansion = vd.expansion
                    local vendorName = vd.vendorName
                    local zoneName = vd.location

                    if vendorName and vendorName ~= "" and vendorName ~= "None" then
                        AddFilterEntry(expansion, vendorName, zoneName)

                        local vendorIndex = GetOrCreateVendorIndex(vd)
                        if itemID and vendorIndex then
                            local list = _G.HousingItemVendorIndex[itemID]
                            if not list then
                                list = {}
                                _G.HousingItemVendorIndex[itemID] = list
                            end
                            list[#list + 1] = vendorIndex
                        end
                    end
                end
            end
        end
    elseif dataType == "quest" then
        RegisterByItemID(_G.HousingExpansionData, items, "quest", "questCount")
    elseif dataType == "achievement" then
        RegisterByItemID(_G.HousingExpansionData, items, "achievement", "achievementCount")
    elseif dataType == "drop" then
        RegisterByItemID(_G.HousingExpansionData, items, "drop", "dropCount")
    end
end

function _G.HousingDataAggregator:RegisterReputation(items)
    if not items then return end
    for _, item in ipairs(items) do
        -- Check if this is a faction definition (has factionID at top level)
        if item.factionID and not item.itemID then
            local factionIDStr = tostring(item.factionID)
            local factionIDNum = tonumber(item.factionID)

            _G.HousingReputationData[factionIDStr] = item
            _G.HousingReputations[factionIDStr] = item

            -- Also index by numeric key for WoW APIs that require numeric faction IDs.
            if factionIDNum then
                _G.HousingReputationData[factionIDNum] = item
                _G.HousingReputations[factionIDNum] = item
            end
            stats.reputationCount = stats.reputationCount + 1
        end

        -- Check if this is a reputation-gated item (has itemID + vendorDetails)
        if item.itemID and item.vendorDetails then
            local itemID = tonumber(item.itemID)
            if itemID then
                -- Add to HousingExpansionData so ReputationLoader can find it
                if not _G.HousingExpansionData[itemID] then
                    _G.HousingExpansionData[itemID] = {}
                end
                -- Store as vendor type (it's vendor-sold with reputation requirement)
                _G.HousingExpansionData[itemID].vendor = item

                -- Build vendor filter data + per-item vendor indices
                local vd = item.vendorDetails
                if vd then
                    if vd.factionID and vd.factionID ~= "" and vd.factionID ~= "None" then
                        vd.factionID = ResolveReputationFactionID(vd.factionID) or vd.factionID
                    end

                    local expansion = vd.expansion
                    local vendorName = vd.vendorName
                    local zoneName = vd.location

                    if vendorName and vendorName ~= "" and vendorName ~= "None" then
                        AddFilterEntry(expansion, vendorName, zoneName)

                        local vendorIndex = GetOrCreateVendorIndex(vd)
                        if vendorIndex then
                            local list = _G.HousingItemVendorIndex[itemID]
                            if not list then
                                list = {}
                                _G.HousingItemVendorIndex[itemID] = list
                            end
                            list[#list + 1] = vendorIndex
                        end
                    end
                end
            end
        end
    end
end

function _G.HousingDataAggregator:RegisterProfession(items)
    if not items then return end
    for _, item in ipairs(items) do
        local itemID = tonumber(item.itemID)
        if itemID and not _G.HousingProfessionData[itemID] then
            _G.HousingProfessionData[itemID] = item
            stats.professionCount = stats.professionCount + 1
        end
    end
end

-- Convenience function globals for generated files
function _G.HousingDataAggregator_RegisterExpansionItems(dataType, items)
    return _G.HousingDataAggregator:RegisterExpansionItems(dataType, items)
end

function _G.HousingDataAggregator_RegisterReputation(items)
    return _G.HousingDataAggregator:RegisterReputation(items)
end

function _G.HousingDataAggregator_RegisterProfession(items)
    return _G.HousingDataAggregator:RegisterProfession(items)
end

-- Legacy compatibility (best-effort):
-- Some old generated files assign globals like `vendor = { ... }` instead of calling the
-- registration helpers. Historically we captured that via a _G metatable hook, but modern WoW
-- clients protect _G's metatable and will error ("cannot change a protected metatable").
--
-- We now attempt to install the hook safely; if it's blocked, data files must use the explicit
-- `HousingDataAggregator_Register*` functions (all current generated files do).
local function TryInstallLegacyGlobalAssignmentHook()
    local existingMeta = getmetatable(_G)
    if type(existingMeta) ~= "table" then
        existingMeta = nil
    end

    local originalNewIndex = (existingMeta and existingMeta.__newindex) or rawset
    local newMeta = existingMeta or {}

    newMeta.__newindex = function(t, key, value)
        local success, err = pcall(function()
            if key == "vendor" and type(value) == "table" then
                _G.HousingDataAggregator:RegisterExpansionItems("vendor", value)
            elseif key == "quest" and type(value) == "table" then
                _G.HousingDataAggregator:RegisterExpansionItems("quest", value)
            elseif key == "achievement" and type(value) == "table" then
                _G.HousingDataAggregator:RegisterExpansionItems("achievement", value)
            elseif key == "drop" and type(value) == "table" then
                _G.HousingDataAggregator:RegisterExpansionItems("drop", value)
            elseif key == "reputation" and type(value) == "table" then
                _G.HousingDataAggregator:RegisterReputation(value)
            elseif key == "profession" and type(value) == "table" then
                _G.HousingDataAggregator:RegisterProfession(value)
            end
        end)

        if not success then
            print("|cFFFF0000HousingVendor DataAggregator Error:|r " .. tostring(err))
        end

        if originalNewIndex == rawset then
            rawset(t, key, value)
        else
            originalNewIndex(t, key, value)
        end
    end

    pcall(setmetatable, _G, newMeta)
end

TryInstallLegacyGlobalAssignmentHook()

-- Register a callback to print stats when all files are loaded
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == DATA_ADDON_NAME then
        -- Calculate total indexed items
        local totalExpansionItems = 0
        for _ in pairs(_G.HousingExpansionData) do
            totalExpansionItems = totalExpansionItems + 1
        end

        local totalProfessionItems = 0
        for _ in pairs(_G.HousingProfessionData) do
            totalProfessionItems = totalProfessionItems + 1
        end

        -- Stats available in stats table if needed for debugging:
        -- stats.vendorCount, stats.questCount, stats.achievementCount, etc.

        self:UnregisterEvent("ADDON_LOADED")
    end
end)
