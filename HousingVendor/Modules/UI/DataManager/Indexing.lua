-- Indexing.lua
-- Low-overhead ID indexing + filtering + on-demand item record creation.

local _G = _G
local DataManager = _G["HousingDataManager"]
if not DataManager then return end

local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local table_insert = table.insert
local table_sort = table.sort
local string_lower = string.lower

local Util = DataManager.Util or {}
local INTERNED_STRINGS = Util.INTERNED_STRINGS or {}
local function InternString(str) return Util.InternString and Util.InternString(str) or str end
local function NormalizeVendorName(vendorName) return Util.NormalizeVendorName and Util.NormalizeVendorName(vendorName) or vendorName end
local function CoalesceNonEmptyString(a, b) return Util.CoalesceNonEmptyString and Util.CoalesceNonEmptyString(a, b) or (a ~= nil and a ~= "" and a or b) end

local function GetApiDataCache()
    return Util.GetApiDataCache and Util.GetApiDataCache() or {}
end

local function TouchApiDataCacheItem(itemID)
    if Util.TouchApiDataCacheItem then
        Util.TouchApiDataCacheItem(itemID)
    end
end

-- Lightweight caches (avoid building full item-record tables for all items).
local MAX_ITEM_RECORD_CACHE = 250

local function InferExpansionFromProfessionSkill(skill)
    if type(skill) ~= "string" or skill == "" then return nil end
    local s = skill:lower()
    if s:find("classic") then return "Classic" end
    if s:find("burning crusade") or s:find("tbc") then return "The Burning Crusade" end
    if s:find("wrath") then return "Wrath of the Lich King" end
    if s:find("cataclysm") then return "Cataclysm" end
    if s:find("mists") then return "Mists of Pandaria" end
    if s:find("warlords") or s:find("draenor") then return "Warlords of Draenor" end
    if s:find("legion") then return "Legion" end
    if s:find("battle for azeroth") or s:find("azeroth") then return "Battle for Azeroth" end
    if s:find("shadowlands") then return "Shadowlands" end
    if s:find("dragonflight") then return "Dragonflight" end
    if s:find("war within") then return "The War Within" end
    if s:find("midnight") then return "Midnight" end
    return nil
end

local function EnsureDataLoaded()
    if _G.HousingDataLoader and _G.HousingDataLoader.IsDataLoaded and not _G.HousingDataLoader:IsDataLoaded() then
        if _G.HousingDataLoader.LoadData then
            _G.HousingDataLoader:LoadData()
        end
    end
end

local function BuildFilterOptionsFromIndexes(state)
    local filterOptions = {
        expansions = {},
        vendors = {},
        zones = {},
        types = {},
        categories = {},
        factions = {},
        sources = {},
        qualities = {},
        requirements = {},
    }

    -- Sources (static list, plus whatever is seen)
    filterOptions.sources[INTERNED_STRINGS["Vendor"] or "Vendor"] = true
    filterOptions.sources[INTERNED_STRINGS["Quest"] or "Quest"] = true
    filterOptions.sources[INTERNED_STRINGS["Achievement"] or "Achievement"] = true
    filterOptions.sources[INTERNED_STRINGS["Drop"] or "Drop"] = true
    filterOptions.sources[INTERNED_STRINGS["Profession"] or "Profession"] = true
    filterOptions.sources[INTERNED_STRINGS["Reputation"] or "Reputation"] = true
    filterOptions.sources[INTERNED_STRINGS["Renown"] or "Renown"] = true

    -- Factions (static)
    filterOptions.factions[INTERNED_STRINGS["Neutral"] or "Neutral"] = true
    filterOptions.factions[INTERNED_STRINGS["Alliance"] or "Alliance"] = true
    filterOptions.factions[INTERNED_STRINGS["Horde"] or "Horde"] = true

    -- Expansions: use what we actually indexed (plus stable ordering)
    if state._seenExpansions then
        for exp in pairs(state._seenExpansions) do
            if exp and exp ~= "" then
                filterOptions.expansions[exp] = true
            end
        end
    end

    -- Vendors/Zones: compact vendor filter index built by DataAggregator in the datapack
    local vfi = _G.HousingVendorFilterIndex
    if vfi and vfi.vendorsByExpansion then
        for _, vendors in pairs(vfi.vendorsByExpansion) do
            for name in pairs(vendors) do
                if name and name ~= "" and name ~= "None" then
                    filterOptions.vendors[name] = true
                end
            end
        end
    end
    if vfi and vfi.zonesByExpansion then
        for _, zones in pairs(vfi.zonesByExpansion) do
            for zoneName in pairs(zones) do
                if zoneName and zoneName ~= "" then
                    filterOptions.zones[zoneName] = true
                end
            end
        end
    end

    -- Types/Categories: prefer API-provided tag groups when available, otherwise fall back to whatever
    -- has already been seen in the session API cache.
    local function AddTagGroupOptions(tagGroups)
        if type(tagGroups) ~= "table" then return end

        for _, group in ipairs(tagGroups) do
            local groupName = group and group.name and string_lower(tostring(group.name)) or ""
            local isCategoryGroup = groupName == "category" or groupName == "categories"
            local isTypeGroup = groupName == "type" or groupName == "types" or groupName == "subcategory" or groupName == "subcategories"
            if isCategoryGroup or isTypeGroup then
                if type(group.tags) == "table" then
                    for _, tagData in pairs(group.tags) do
                        local tagName = tagData and tagData.name or nil
                        if tagName and tagName ~= "" then
                            if isTypeGroup then
                                filterOptions.types[tagName] = true
                            else
                                filterOptions.categories[tagName] = true
                            end
                        end
                    end
                elseif type(group.tagNames) == "table" then
                    for _, tagName in pairs(group.tagNames) do
                        if tagName and tagName ~= "" then
                            if isTypeGroup then
                                filterOptions.types[tagName] = true
                            else
                                filterOptions.categories[tagName] = true
                            end
                        end
                    end
                end
            end
        end
    end

    if _G.HousingAPICache and _G.HousingAPICache.GetFilterTagGroups then
        local ok, tagGroups = pcall(_G.HousingAPICache.GetFilterTagGroups, _G.HousingAPICache)
        if ok and tagGroups then
            AddTagGroupOptions(tagGroups)
        end
    end

    -- Seen API cache values (helps when tag groups aren’t available yet)
    do
        local apiDataCache = GetApiDataCache()
        if type(apiDataCache) == "table" then
            for _, apiData in pairs(apiDataCache) do
                if type(apiData) == "table" then
                    if apiData.category and apiData.category ~= "" then
                        filterOptions.categories[apiData.category] = true
                    end
                    if apiData.subcategory and apiData.subcategory ~= "" then
                        filterOptions.types[apiData.subcategory] = true
                    end
                end
            end
        end
    end

    local function SortKeys(hashTable)
        local keys = {}
        for k in pairs(hashTable or {}) do
            table_insert(keys, k)
        end
        table_sort(keys)
        return keys
    end

    state.filterOptionsCache = {
        expansions = SortKeys(filterOptions.expansions),
        vendors = SortKeys(filterOptions.vendors),
        zones = SortKeys(filterOptions.zones),
        types = SortKeys(filterOptions.types),
        categories = SortKeys(filterOptions.categories),
        factions = SortKeys(filterOptions.factions),
        sources = SortKeys(filterOptions.sources),
        qualities = SortKeys(filterOptions.qualities),
        requirements = SortKeys(filterOptions.requirements),
    }
end

function DataManager:InvalidateIndexes()
    local s = self._state
    s.allItemIDs = nil
    s._itemMeta = nil
    s._seenExpansions = nil
    s.filterOptionsCache = nil
    s.filteredIDCache = nil
    s.lastFilterHash = nil
    s._itemRecordCache = nil
    s._itemRecordCacheCount = 0
end

function DataManager:HasIndexCache()
    local s = self._state
    return type(s.allItemIDs) == "table" and #s.allItemIDs > 0
end

function DataManager:GetAllItemIDs()
    EnsureDataLoaded()

    local s = self._state
    if type(s.allItemIDs) == "table" and #s.allItemIDs > 0 then
        return s.allItemIDs
    end

    local ids = {}
    local meta = {}
    local seenExpansions = {}

    if not _G.HousingAllItems or type(_G.HousingAllItems) ~= "table" then
        s.allItemIDs = {}
        s._itemMeta = {}
        s._seenExpansions = {}
        BuildFilterOptionsFromIndexes(s)
        return s.allItemIDs
    end

    -- Ensure HousingVendorItemToFaction is built before we build metadata
    if _G.HousingReputationLoader and _G.HousingReputationLoader.Rebuild then
        pcall(_G.HousingReputationLoader.Rebuild, _G.HousingReputationLoader)
    end

    local expansionData = _G.HousingExpansionData
    local professionData = _G.HousingProfessionData
    local repLookup = _G.HousingVendorItemToFaction

    for itemID in pairs(_G.HousingAllItems) do
        local idNum = tonumber(itemID)
        if idNum then
            ids[#ids + 1] = idNum

            local srcType = INTERNED_STRINGS["Vendor"] or "Vendor"
            local expName = nil
            local qid, aid = nil, nil
            local isProfession = false
            local requirement = nil

            local sources = expansionData and expansionData[idNum] or nil
            if sources and type(sources) == "table" then
                if sources.quest then
                    srcType = INTERNED_STRINGS["Quest"] or "Quest"
                    expName = sources.quest.expansion or expName
                    qid = sources.quest.questId or qid
                    requirement = INTERNED_STRINGS["Quest"] or "Quest"
                elseif sources.achievement then
                    srcType = INTERNED_STRINGS["Achievement"] or "Achievement"
                    expName = sources.achievement.expansion or expName
                    aid = sources.achievement.achievementId or aid
                    requirement = INTERNED_STRINGS["Achievement"] or "Achievement"
                elseif sources.drop then
                    srcType = INTERNED_STRINGS["Drop"] or "Drop"
                    expName = sources.drop.expansion or expName
                elseif sources.vendor and sources.vendor.vendorDetails then
                    expName = sources.vendor.vendorDetails.expansion or expName
                end
            end

            if professionData and professionData[idNum] then
                isProfession = true
                srcType = INTERNED_STRINGS["Profession"] or "Profession"
                expName = InferExpansionFromProfessionSkill(professionData[idNum].skill) or expName
                requirement = INTERNED_STRINGS["Profession"] or "Profession"
            end

            if repLookup and repLookup[idNum] then
                local repInfo = repLookup[idNum]
                local repType = repInfo and repInfo.rep or nil
                if repType then
                    local repLower = string_lower(tostring(repType))
                    if repLower == "renown" then
                        requirement = INTERNED_STRINGS["Renown"] or "Renown"
                    else
                        requirement = INTERNED_STRINGS["Reputation"] or "Reputation"
                    end
                else
                    -- Treat any faction-gated vendor item as reputation-gated, even if rep type is missing.
                    requirement = INTERNED_STRINGS["Reputation"] or "Reputation"
                end
            end

            if expName and expName ~= "" then
                seenExpansions[expName] = true
            end

            meta[idNum] = {
                sourceType = srcType,
                expansion = expName,
                questId = qid,
                achievementId = aid,
                isProfession = isProfession,
                requirement = requirement,
            }
        end
    end

    table_sort(ids)

    s.allItemIDs = ids
    s._itemMeta = meta
    s._seenExpansions = seenExpansions

    BuildFilterOptionsFromIndexes(s)

    return s.allItemIDs
end

-- Use shared GetFilterHash from Util (moved to Shared.lua to eliminate duplication)
local function GetFilterHash(filters)
    return Util.GetFilterHash and Util.GetFilterHash(filters) or ""
end

function DataManager:FilterItemIDs(itemIDs, filters)
    if not itemIDs or #itemIDs == 0 then
        return {}
    end

    local s = self._state
    local filterHash = GetFilterHash(filters or {})
    if s.filteredIDCache and s.lastFilterHash == filterHash then
        return s.filteredIDCache
    end

    local meta = s._itemMeta or {}
    local out = {}

    local searchText = (filters and filters.searchText and string_lower(filters.searchText)) or ""
    local wantSearch = searchText ~= ""

    local selectedExpansions = filters and filters.selectedExpansions or nil
    local selectedSources = filters and filters.selectedSources or nil
    local selectedCategories = filters and filters.selectedCategories or nil

    local wantVendor = filters and filters.vendor and filters.vendor ~= "All Vendors"
    local wantZone = filters and filters.zone and filters.zone ~= "All Zones"
    local wantCollection = filters and filters.collection and filters.collection ~= "" and filters.collection ~= "All"
    local wantFaction = filters and filters.faction and filters.faction ~= "All Factions"
    local wantRequirement = filters and filters.requirement and filters.requirement ~= "All Requirements"
    local wantQuality = filters and filters.quality and filters.quality ~= "All Qualities"
    local wantType = filters and filters.type and filters.type ~= "All Types"
    local wantCategory = (filters and filters.category and filters.category ~= "All Categorys" and filters.category ~= "All Categories") or (selectedCategories and next(selectedCategories) ~= nil)

    local wantSource = (filters and filters.source and filters.source ~= "All Sources") or (selectedSources and next(selectedSources) ~= nil)
    local wantExpansion = (filters and filters.expansion and filters.expansion ~= "" and filters.expansion ~= "All Expansions") or (selectedExpansions and next(selectedExpansions) ~= nil)

    local vendorPool = _G.HousingVendorPool
    local vendorIndex = _G.HousingItemVendorIndex
    local repLookup = _G.HousingVendorItemToFaction

    local apiDataCache = GetApiDataCache()
    local wantApiFacets = wantQuality or wantType or wantCategory

    local apiMissing = 0
    if wantApiFacets and type(apiDataCache) == "table" then
        for _, idNum in ipairs(itemIDs) do
            if not apiDataCache[idNum] then
                apiMissing = apiMissing + 1
            end
        end
    end

    local nameCache = s._nameCache
    if not nameCache then
        nameCache = {}
        s._nameCache = nameCache
    end

    for _, idNum in ipairs(itemIDs) do
        local m = meta[idNum] or {}
        local ok = true

        if ok and wantExpansion then
            local exp = m.expansion or "Other"
            local hasSelections = false
            if selectedExpansions then
                for _, _ in pairs(selectedExpansions) do
                    hasSelections = true
                    break
                end
            end
            if hasSelections then
                if not selectedExpansions[exp] then
                    ok = false
                end
            elseif filters and filters.expansion and filters.expansion ~= "All Expansions" and filters.expansion ~= "" then
                if exp ~= filters.expansion then
                    ok = false
                end
            end
        end

        if ok and wantSource then
            local st = tostring(m.sourceType or (INTERNED_STRINGS["Vendor"] or "Vendor"))
            if selectedSources and next(selectedSources) ~= nil then
                if not (selectedSources[st] or selectedSources[tostring(st)]) then
                    ok = false
                end
            elseif filters and filters.source and filters.source ~= "All Sources" then
                if st ~= tostring(filters.source) then
                    ok = false
                end
            end
        end

        if ok and wantRequirement then
            local req = m.requirement or "None"
            if req == "None" and repLookup and repLookup[idNum] then
                local repInfo = repLookup[idNum]
                local repType = repInfo and repInfo.rep or nil
                if repType and string_lower(tostring(repType)) == "renown" then
                    req = "Renown"
                else
                    req = "Reputation"
                end
            end
            if filters.requirement == "None" then
                if req ~= "None" then ok = false end
            elseif req ~= filters.requirement then
                ok = false
            end
        end

        if ok and wantQuality then
            local apiData = apiDataCache and apiDataCache[idNum] or nil
            local q = apiData and apiData.quality or nil
            if q ~= nil then
                local qualityNames = {
                    [0] = "Poor",
                    [1] = "Common",
                    [2] = "Uncommon",
                    [3] = "Rare",
                    [4] = "Epic",
                    [5] = "Legendary",
                }
                if qualityNames[q] ~= filters.quality then
                    ok = false
                end
            end
            -- Note: Items without quality data are not filtered out
        end

        if ok and (wantType or wantCategory) then
            local apiData = apiDataCache and apiDataCache[idNum] or nil
            if apiData then
                if wantType then
                    local matches = (apiData.subcategory and apiData.subcategory == filters.type) or (apiData.category and apiData.category == filters.type)
                    if not matches then ok = false end
                end
                if ok and wantCategory then
                    local matchesCategory = false
                    if selectedCategories and next(selectedCategories) ~= nil then
                        for selectedCategory, isSelected in pairs(selectedCategories) do
                            if isSelected then
                                if apiData.category == selectedCategory or apiData.subcategory == selectedCategory then
                                    matchesCategory = true
                                    break
                                end
                            end
                        end
                    elseif filters and filters.category and filters.category ~= "" and filters.category ~= "All Categories" and filters.category ~= "All Categorys" then
                        matchesCategory = (apiData.category == filters.category) or (apiData.subcategory == filters.category)
                    else
                        matchesCategory = true
                    end
                    if not matchesCategory then ok = false end
                end
            end
            -- Note: Items without API data are not filtered out
        end

        if ok and wantFaction then
            local itemFaction = "Neutral"
            local indices = vendorIndex and vendorIndex[idNum] or nil
            if indices and vendorPool then
                local hasAlliance = false
                local hasHorde = false
                for _, idx in ipairs(indices) do
                    local v = idx and vendorPool[idx] or nil
                    local f = v and v.faction or nil
                    if f == "Alliance" or f == 1 then
                        hasAlliance = true
                    elseif f == "Horde" or f == 2 then
                        hasHorde = true
                    end
                end
                -- If item has both Alliance and Horde vendors, it's Neutral (available to both)
                if hasAlliance and hasHorde then
                    itemFaction = "Neutral"
                elseif hasAlliance then
                    itemFaction = "Alliance"
                elseif hasHorde then
                    itemFaction = "Horde"
                end
            end
            if itemFaction ~= filters.faction and itemFaction ~= "Neutral" then
                ok = false
            end
        end

        if ok and wantVendor then
            local matchesVendor = false
            local indices = vendorIndex and vendorIndex[idNum] or nil
            if indices and vendorPool then
                local normalizedFilterVendor = NormalizeVendorName(filters.vendor)
                for _, idx in ipairs(indices) do
                    local v = idx and vendorPool[idx] or nil
                    local vendorName = v and v.name or nil
                    if vendorName and vendorName ~= "" and vendorName ~= "None" then
                        if vendorName == filters.vendor then
                            matchesVendor = true
                            break
                        end
                        if normalizedFilterVendor and NormalizeVendorName(vendorName) == normalizedFilterVendor then
                            matchesVendor = true
                            break
                        end
                    end
                end
            end
            if not matchesVendor then
                ok = false
            end
        end

        if ok and wantZone then
            local matchesZone = false
            local indices = vendorIndex and vendorIndex[idNum] or nil
            if indices and vendorPool then
                for _, idx in ipairs(indices) do
                    local v = idx and vendorPool[idx] or nil
                    local zoneName = v and v.location or nil
                    if zoneName and zoneName ~= "" and zoneName == filters.zone then
                        matchesZone = true
                        break
                    end
                end
            end
            if not matchesZone then
                ok = false
            end
        end

        if ok and wantCollection then
            local isCollected = false
            if _G.HousingCollectionAPI and _G.HousingCollectionAPI.IsItemCollected then
                isCollected = _G.HousingCollectionAPI:IsItemCollected(idNum)
            end
            if filters.collection == "Collected" and not isCollected then
                ok = false
            elseif filters.collection == "Uncollected" and isCollected then
                ok = false
            end
        end

        if ok and wantSearch then
            local cached = nameCache[idNum]
            if cached == nil then
                local name = nil
                if _G.C_Item and _G.C_Item.GetItemNameByID then
                    name = _G.C_Item.GetItemNameByID(idNum)
                end
                cached = name and string_lower(name) or ""
                nameCache[idNum] = cached
            end
            if cached == "" then
                if not tostring(idNum):find(searchText, 1, true) then
                    ok = false
                end
            else
                if not cached:find(searchText, 1, true) and not tostring(idNum):find(searchText, 1, true) then
                    ok = false
                end
            end
        end

        -- Show Only Available Items filter (API-verified items only)
        if ok and filters and filters.showOnlyAvailable then
            local isAvailable = false
            if _G.C_Item and _G.C_Item.GetItemNameByID then
                local itemName = _G.C_Item.GetItemNameByID(idNum)
                -- Item is available if API returns a valid name (not nil and not "Unknown Item")
                if itemName and itemName ~= "" and itemName ~= "Unknown Item" then
                    isAvailable = true
                end
            end

            if not isAvailable then
                ok = false
            end
        end

        if ok then
            out[#out + 1] = idNum
        end
    end

    -- If an API-dependent filter produced 0 results while API data is missing, kick off a batch load and
    -- return the unfiltered list for now (avoids “everything disappears” until cache warms).
    if wantApiFacets and #out == 0 and apiMissing > 0 and not s.batchLoadInProgress and self.BatchLoadAPIDataForItemIDs then
        local idsToLoad = itemIDs
        pcall(self.BatchLoadAPIDataForItemIDs, self, idsToLoad, function()
            -- refresh filter options too (types/categories can appear after tags load)
            s.filterOptionsCache = nil
            s.filteredIDCache = nil
            s.lastFilterHash = nil
            if _G.HousingFilters and _G.HousingFilters.ApplyFilters then
                pcall(_G.HousingFilters.ApplyFilters, _G.HousingFilters)
            end
        end)
        out = itemIDs
    end

    -- If we are missing API data and a facet filter is active, keep warming in the background so the
    -- list converges to correct results shortly after.
    if wantApiFacets and apiMissing > 0 and not s.batchLoadInProgress and self.BatchLoadAPIDataForItemIDs then
        pcall(self.BatchLoadAPIDataForItemIDs, self, itemIDs, function()
            s.filterOptionsCache = nil
            s.filteredIDCache = nil
            s.lastFilterHash = nil
            if _G.HousingFilters and _G.HousingFilters.ApplyFilters then
                pcall(_G.HousingFilters.ApplyFilters, _G.HousingFilters)
            end
        end)
    end

    s.filteredIDCache = out
    s.lastFilterHash = filterHash
    return out
end

function DataManager:GetItemMeta(itemID)
    local s = self._state
    return (s._itemMeta and s._itemMeta[itemID]) or nil
end

function DataManager:GetItemRecord(itemID)
    local idNum = tonumber(itemID)
    if not idNum then return nil end

    EnsureDataLoaded()

    local s = self._state
    local cache = s._itemRecordCache
    if not cache then
        cache = {}
        s._itemRecordCache = cache
        s._itemRecordCacheCount = 0
    end

    if cache[idNum] then
        return cache[idNum]
    end

    local decorData = _G.HousingAllItems and _G.HousingAllItems[idNum] or nil
    if not decorData then
        return nil
    end

    local m = (s._itemMeta and s._itemMeta[idNum]) or {}

    local itemName = nil
    if _G.C_Item and _G.C_Item.GetItemNameByID then
        itemName = _G.C_Item.GetItemNameByID(idNum)
    end

    local sources = _G.HousingExpansionData and _G.HousingExpansionData[idNum] or nil
    if (not itemName or itemName == "" or itemName == "Unknown Item") and sources then
        if sources.vendor and sources.vendor.itemName then
            itemName = sources.vendor.itemName
        elseif sources.quest and sources.quest.title then
            itemName = sources.quest.title
        elseif sources.achievement and sources.achievement.title then
            itemName = sources.achievement.title
        elseif sources.drop and sources.drop.title then
            itemName = sources.drop.title
        end
    end
    if not itemName or itemName == "" then
        itemName = "Unknown Item"
    end

    local record = {
        name = itemName,
        itemID = tostring(idNum),
        decorID = decorData[1],
        modelFileID = decorData[2] or "",
        model3D = decorData[2] or nil,
        thumbnailFileID = decorData[3] or "",

        expansionName = m.expansion,
        _sourceType = m.sourceType or (INTERNED_STRINGS["Vendor"] or "Vendor"),
        _isProfessionItem = m.isProfession or false,
        _questId = m.questId,
        _achievementId = m.achievementId,

        coords = { x = 0, y = 0 },
        mapID = 0,
        faction = INTERNED_STRINGS["Neutral"] or "Neutral",
        npcID = nil,

        _vendorIndices = _G.HousingItemVendorIndex and _G.HousingItemVendorIndex[idNum] or nil,

        _apiExpansion = nil,
        _apiCategory = nil,
        _apiSubcategory = nil,
        _apiVendor = nil,
        _apiZone = nil,
        _apiQuality = nil,
        _apiNumStored = 0,
        _apiNumPlaced = 0,
        _apiAchievement = nil,
        _apiSourceText = nil,
        _apiDataLoaded = false,
    }

    -- Apply cached API data if present
    local apiDataCache = GetApiDataCache()
    if apiDataCache and apiDataCache[idNum] then
        local apiData = apiDataCache[idNum]
        TouchApiDataCacheItem(idNum)
        record._apiExpansion = apiData.expansion
        record._apiCategory = apiData.category
        record._apiSubcategory = apiData.subcategory
        record._apiVendor = apiData.vendor
        record._apiZone = apiData.zone
        record._apiQuality = apiData.quality
        record._apiNumStored = apiData.numStored or 0
        record._apiNumPlaced = apiData.numPlaced or 0
        record._apiAchievement = apiData.achievement
        record._apiSourceText = apiData.sourceText
        record._sourceType = apiData.sourceType or record._sourceType
        record._apiDataLoaded = true

        -- Basic coords
        if apiData.coords and type(apiData.coords) == "table" then
            local cx, cy = apiData.coords.x, apiData.coords.y
            if type(cx) == "number" and type(cy) == "number" and cx > 0 and cy > 0 then
                record.coords = apiData.coords
                record.mapID = apiData.coords.mapID or record.mapID
            end
        end
    end

    -- If vendor details exist for this item, use them for map/coords/faction/expansionName
    if sources and sources.vendor and sources.vendor.vendorDetails then
        local vd = sources.vendor.vendorDetails
        record.expansionName = record.expansionName or vd.expansion
        if vd.coords and type(vd.coords) == "table" then
            record.coords = vd.coords
            record.mapID = vd.coords.mapID or record.mapID
        end
        if vd.npcID and vd.npcID ~= "None" and vd.npcID ~= "" then
            record.npcID = vd.npcID
        end

        -- Check if item has multiple vendors with different factions
        local hasAlliance = false
        local hasHorde = false

        if record._vendorIndices and _G.HousingVendorPool then
            for _, vendorIdx in ipairs(record._vendorIndices) do
                local vendor = _G.HousingVendorPool[vendorIdx]
                if vendor and vendor.faction then
                    if vendor.faction == 1 then
                        hasAlliance = true
                    elseif vendor.faction == 2 then
                        hasHorde = true
                    end
                end
            end
        end

        -- Set faction based on all vendors (not just the first one)
        if hasAlliance and hasHorde then
            -- Item sold by both factions - mark as Neutral so both can see it
            record.faction = INTERNED_STRINGS["Neutral"] or "Neutral"
        elseif vd.faction == 1 then
            record.faction = INTERNED_STRINGS["Alliance"] or "Alliance"
        elseif vd.faction == 2 then
            record.faction = INTERNED_STRINGS["Horde"] or "Horde"
        else
            record.faction = INTERNED_STRINGS["Neutral"] or "Neutral"
        end

        record.vendorName = vd.vendorName
        record.zoneName = vd.location
    end

    -- Profession details (optional)
    if _G.HousingProfessionData and _G.HousingProfessionData[idNum] then
        local p = _G.HousingProfessionData[idNum]
        record.profession = p.profession
        record.skill = p.skill
    end

    -- Cache with a simple cap
    cache[idNum] = record
    s._itemRecordCacheCount = (s._itemRecordCacheCount or 0) + 1
    if (s._itemRecordCacheCount or 0) > MAX_ITEM_RECORD_CACHE then
        s._itemRecordCache = {}
        s._itemRecordCacheCount = 0
    end

    return record
end
