-- Data Manager for HousingVendor addon
-- Simple, efficient data aggregation - one pass, cached results

local DataManager = {}
DataManager.__index = DataManager

-- Cache global references for performance
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local string_format = string.format
local string_find = string.find
local string_lower = string.lower
local table_insert = table.insert
local table_sort = table.sort

-- Cache for aggregated items
local itemCache = nil
local filterOptionsCache = nil
local isInitialized = false

-- Filter result cache
local filteredResultsCache = nil
local lastFilterHash = nil

-- Faction lookup tables (pre-built for performance)
local hordeFactionKeywords = {
    "orgrimmar", "thunder bluff", "undercity", "silvermoon",
    "durotar", "mulgore", "tirisfal", "eversong"
}
local allianceFactionKeywords = {
    "stormwind", "ironforge", "darnassus", "exodar",
    "elwynn", "dun morogh", "teldrassil", "azuremyst"
}

-- Build quick lookup function
local function InferFactionFromText(text)
    local lowerText = string.lower(text)
    
    for _, keyword in ipairs(hordeFactionKeywords) do
        if string.find(lowerText, keyword) then
            return "Horde"
        end
    end
    
    for _, keyword in ipairs(allianceFactionKeywords) do
        if string.find(lowerText, keyword) then
            return "Alliance"
        end
    end
    
    return "Neutral"
end

-- Initialize data manager
function DataManager:Initialize()
    if isInitialized then return end
    itemCache = nil
    filterOptionsCache = nil
    isInitialized = true
end

-- Check if initialized
function DataManager:IsInitialized()
    return isInitialized
end

-- Aggregate all items from vendorData in a single pass
function DataManager:GetAllItems()
    -- Return cached data if available
    if itemCache then
        return itemCache
    end
    
    local allItems = {}
    local filterOptions = {
        expansions = {},
        vendors = {},
        zones = {},
        types = {},
        categories = {},
        factions = {},
        sources = {}  -- Achievement, Quest, Drop, Vendor
    }
    
    -- List of non-expansion category names to exclude from expansion filter
    local nonExpansionCategories = {
        ["Achievement Items"] = true,
        ["Drop Items"] = true,
        ["Quest Items"] = true,
        ["Replica Items"] = true,
        ["Miscellaneous Items"] = true,
        ["Event Rewards"] = true,
        ["Collection Items"] = true,
        ["Crafted Items"] = true
    }
    
    -- Single pass through all data
    for expansionName, expansionData in pairs(HousingData.vendorData) do
        -- Track expansion (exclude non-expansion categories)
        if not nonExpansionCategories[expansionName] then
            filterOptions.expansions[expansionName] = true
        end
        
        for zoneName, vendors in pairs(expansionData) do
            -- Track zone
            filterOptions.zones[zoneName] = true
            
            for _, vendor in ipairs(vendors) do
                -- Track vendor
                local vendorName = vendor.name or "Unknown Vendor"
                filterOptions.vendors[vendorName] = true
                
                if vendor.items then
                    for _, item in ipairs(vendor.items) do
                        local itemName = item.name or "Unknown Item"
                        
                        -- Skip [DNT] items
                        if not string.find(itemName, "%[DNT%]") then
                            -- Determine faction (check item first, then infer from location)
                            local itemFaction = item.faction or "Neutral"
                            
                            -- If not set in item data, infer from zone/vendor using pre-built lookup
                            if itemFaction == "Neutral" then
                                local zoneFaction = InferFactionFromText(zoneName)
                                if zoneFaction ~= "Neutral" then
                                    itemFaction = zoneFaction
                                else
                                    itemFaction = InferFactionFromText(vendorName)
                                end
                            end
                            
                            -- Create item record (preserve all fields)
                            local itemRecord = {
                                -- Basic info
                                name = itemName,
                                itemID = item.itemID or "",
                                type = item.type or "Uncategorized",
                                category = item.category or "Miscellaneous",
                                price = item.price or 0,
                                faction = itemFaction,
                                
                                -- Model data
                                modelFileID = item.modelFileID or "",
                                thumbnailFileID = item.thumbnailFileID or "",
                                
                                -- Vendor info
                                vendorName = vendorName,
                                vendorType = vendor.type or "Zone Specific",
                                vendorCoords = vendor.coordinates or {x = 0, y = 0},
                                
                                -- Location
                                zoneName = zoneName,
                                expansionName = expansionName,
                                mapID = item.mapID or 0,
                                
                                -- Achievement/Quest/Drop requirements (preserve all)
                                achievementRequired = item.achievementRequired or nil,
                                questRequired = item.questRequired or nil,
                                dropSource = item.dropSource or nil,
                                
                                -- Cost information (preserve currency field)
                                currency = item.currency or nil,
                                
                                -- Additional vendor field (from item data, not vendor structure)
                                vendor = item.vendor or nil,
                                
                                -- Pre-computed lowercase for filtering
                                _lowerName = string.lower(itemName),
                                _lowerType = string.lower(item.type or ""),
                                _lowerCategory = string.lower(item.category or ""),
                                _lowerVendor = string.lower(vendorName),
                                _lowerZone = string.lower(zoneName),
                                
                                -- Original data reference
                                _itemData = item,
                                _vendorData = vendor
                            }
                            
                            table.insert(allItems, itemRecord)
                            
                            -- Track filter options
                            filterOptions.types[itemRecord.type] = true
                            filterOptions.categories[itemRecord.category] = true
                            filterOptions.factions[itemFaction] = true
                            
                            -- Track source type (Achievement, Quest, Drop, or Vendor)
                            if item.achievementRequired and item.achievementRequired ~= "" then
                                filterOptions.sources["Achievement"] = true
                            elseif item.questRequired and item.questRequired ~= "" then
                                filterOptions.sources["Quest"] = true
                            elseif item.dropSource and item.dropSource ~= "" then
                                filterOptions.sources["Drop"] = true
                            else
                                filterOptions.sources["Vendor"] = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Convert filter options to sorted arrays
    filterOptionsCache = {
        expansions = self:_SortKeys(filterOptions.expansions),
        vendors = self:_SortKeys(filterOptions.vendors),
        zones = self:_SortKeys(filterOptions.zones),
        types = self:_SortKeys(filterOptions.types),
        categories = self:_SortKeys(filterOptions.categories),
        factions = self:_SortKeys(filterOptions.factions),
        sources = self:_SortKeys(filterOptions.sources)
    }
    
    -- Cache results
    itemCache = allItems
    
    return allItems
end

-- Get filter options (expansions, vendors, zones, etc.)
function DataManager:GetFilterOptions()
    if not filterOptionsCache then
        self:GetAllItems() -- This will populate filterOptionsCache
    end

    return filterOptionsCache
end

local function IsItemCollected(itemID)
    if not itemID or itemID == "" then
        return false
    end

    local numericItemID = tonumber(itemID)
    if not numericItemID then
        return false
    end

    if C_PlayerInfo and C_PlayerInfo.IsItemCollected then
        local success, isCollected = pcall(function()
            return C_PlayerInfo.IsItemCollected(numericItemID)
        end)
        if success then
            return isCollected
        end
    end

    return false
end

-- Generate hash key from filter values
local function GetFilterHash(filters)
    return string.format("%s|%s|%s|%s|%s|%s|%s|%s",
        filters.searchText or "",
        filters.expansion or "",
        filters.vendor or "",
        filters.zone or "",
        filters.type or "",
        filters.category or "",
        filters.faction or "",
        filters.source or "",
        filters.collection or "")
end

function DataManager:FilterItems(items, filters)
    if not items or #items == 0 then
        return {}
    end
    
    -- Check cache first
    local filterHash = GetFilterHash(filters)
    if filteredResultsCache and lastFilterHash == filterHash then
        return filteredResultsCache
    end
    
    local filtered = {}
    local searchText = string.lower(filters.searchText or "")
    
    for _, item in ipairs(items) do
        local show = true
        
        -- Search filter
        if searchText ~= "" then
            if not string.find(item._lowerName, searchText) and
               not string.find(item._lowerType, searchText) and
               not string.find(item._lowerCategory, searchText) and
               not string.find(item._lowerVendor, searchText) and
               not string.find(item._lowerZone, searchText) then
                show = false
            end
        end
        
        -- Expansion filter
        if show and filters.expansion and filters.expansion ~= "All Expansions" then
            if item.expansionName ~= filters.expansion then
                show = false
            end
        end
        
        -- Vendor filter
        if show and filters.vendor and filters.vendor ~= "All Vendors" then
            if item.vendorName ~= filters.vendor then
                show = false
            end
        end
        
        -- Zone filter
        if show and filters.zone and filters.zone ~= "All Zones" then
            if item.zoneName ~= filters.zone then
                show = false
            end
        end
        
        -- Type filter
        if show and filters.type and filters.type ~= "All Types" then
            if item.type ~= filters.type then
                show = false
            end
        end
        
        -- Category filter
        if show and filters.category and filters.category ~= "All Categories" then
            if item.category ~= filters.category then
                show = false
            end
        end
        
        -- Faction filter
        -- When a specific faction is selected (Alliance or Horde), also show Neutral items
        if show and filters.faction and filters.faction ~= "All Factions" then
            local itemFaction = item.faction or "Neutral"
            if itemFaction ~= filters.faction and itemFaction ~= "Neutral" then
                show = false
            end
        end
        
        -- Source filter (Achievement, Quest, Drop, Vendor)
        if show and filters.source and filters.source ~= "All Sources" then
            local itemSource = "Vendor"
            if item.achievementRequired and item.achievementRequired ~= "" then
                itemSource = "Achievement"
            elseif item.questRequired and item.questRequired ~= "" then
                itemSource = "Quest"
            elseif item.dropSource and item.dropSource ~= "" then
                itemSource = "Drop"
            end

            if itemSource ~= filters.source then
                show = false
            end
        end

        -- Collection filter
        if show and filters.collection and filters.collection ~= "All" then
            local isCollected = IsItemCollected(item.itemID)
            if filters.collection == "Uncollected" and isCollected then
                show = false
            elseif filters.collection == "Collected" and not isCollected then
                show = false
            end
        end

        if show then
            table.insert(filtered, item)
        end
    end

    -- Cache results
    filteredResultsCache = filtered
    lastFilterHash = filterHash

    return filtered
end

-- Helper: Convert hash table keys to sorted array
function DataManager:_SortKeys(hashTable)
    local keys = {}
    for key in pairs(hashTable) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

-- Clear cache (call when data changes)
function DataManager:ClearCache()
    itemCache = nil
    filterOptionsCache = nil
    filteredResultsCache = nil
    lastFilterHash = nil
end

-- Make globally accessible
_G["HousingDataManager"] = DataManager

return DataManager

