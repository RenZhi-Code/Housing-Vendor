local _G = _G
local C_Timer = C_Timer

local ItemList = _G["HousingItemList"]
if not ItemList then return end

local Theme = nil
local function GetTheme()
    if not Theme then
        Theme = HousingTheme or {}
    end
    return Theme
end

-- Update a special view item button (expansion, location, vendor)
function ItemList:UpdateSpecialViewItemButton(button, item)
    -- Determine the type and set appropriate visuals
    local viewType = "Item"
    local viewColor = {0.196, 0.804, 0.196, 1}  -- Green for vendor (#32CD32)
    
    if item._isExpansion then
        viewType = "Expansion"
        viewColor = {0.64, 0.21, 0.93, 1}  -- Purple for expansion (#A035EE)
    elseif item._isZone then
        viewType = "Location"
        viewColor = {0, 0.44, 0.87, 1}  -- Blue for location (#0070DD)
    elseif item._isVendor then
        viewType = "Vendor"
        viewColor = {1, 0.5, 0, 1}  -- Orange for vendor (#FF8000)
    end
    
    -- Update faction/source color bar
    if button.factionBar then
        button.factionBar:SetVertexColor(viewColor[1], viewColor[2], viewColor[3], 1)
        button.factionBar:Show()
    end
    
    -- Update backdrop color
    local backdropColor = {0.1, 0.1, 0.1, 0.7}
    if item._isExpansion then
        backdropColor = {0.15, 0.05, 0.2, 0.9}  -- Dark purple for expansion
    elseif item._isZone then
        backdropColor = {0.05, 0.1, 0.2, 0.9}  -- Dark blue for location
    elseif item._isVendor then
        backdropColor = {0.2, 0.1, 0.05, 0.9}  -- Dark orange for vendor
    end
    
    button.originalBackdropColor = backdropColor
    button:SetBackdropColor(unpack(backdropColor))
    
    -- Update item name
    button.nameText:SetText(item.name)
    
    -- Removed: Type text and tooltip info text (fields removed)
    
    -- Price text removed - no longer displaying price in main UI
    
    -- Hide map icon for special view items
    button.mapIcon:Hide()
    
    -- Set a generic icon for special views
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Map02")
    
    -- Removed: housing icon and weight (fields removed)
    
    -- Override click behavior for special view items - drill down to show items
    button:SetScript("OnClick", function(self, mouseButton)
        if item._isExpansion and item._expansionData then
            -- Show all items in this expansion
            local expansionItems = item._expansionData.items
            if HousingFilters then
                local filters = HousingFilters:GetFilters()
                ItemList:UpdateItems(expansionItems, filters)
                -- Show back button
                if _G["HousingBackButton"] then
                    _G["HousingBackButton"]:Show()
                end
            end
        elseif item._isZone and item._zoneData then
            -- Show all items in this zone
            local zoneItems = item._zoneData.items
            if HousingFilters then
                local filters = HousingFilters:GetFilters()
                ItemList:UpdateItems(zoneItems, filters)
                -- Show back button
                if _G["HousingBackButton"] then
                    _G["HousingBackButton"]:Show()
                end
            end
        elseif item._isVendor and item._vendorData then
            -- Show all items from this vendor
            local vendorItems = item._vendorData.items
            if HousingFilters then
                local filters = HousingFilters:GetFilters()
                ItemList:UpdateItems(vendorItems, filters)
                -- Show back button
                if _G["HousingBackButton"] then
                    _G["HousingBackButton"]:Show()
                end
            end
        end
    end)
end

function ItemList:UpdateRegularItemButton(button, item, buttonIndex)
    buttonIndex = buttonIndex or 1

    -- Accept itemIDs (number) and resolve to a lightweight record on demand
    if type(item) == "number" and _G.HousingDataManager and _G.HousingDataManager.GetItemRecord then
        item = _G.HousingDataManager:GetItemRecord(item)
        if not item then
            return
        end
        button.itemData = item
    end
    
    -- Determine source type - prioritize API data over static data
    local isAchievement = false
    local isQuest = false
    local isDrop = false
    
    -- Check API data first (most accurate)
    if item._apiDataLoaded then
        if item._apiRequirementType == "Achievement" or item._apiAchievement then
            isAchievement = true
        elseif item._apiRequirementType == "Quest" then
            isQuest = true
        elseif item._apiRequirementType == "Drop" then
            isDrop = true
        end
    end
    
    -- Also check _sourceType field (set during data loading)
    if not isAchievement and not isQuest and not isDrop then
        if item._sourceType == "Achievement" then
            isAchievement = true
        elseif item._sourceType == "Quest" then
            isQuest = true
        elseif item._sourceType == "Drop" then
            isDrop = true
        end
    end
    
    -- Fallback to static data if API data not available
    if not isAchievement and not isQuest and not isDrop then
        isAchievement = item.achievementRequired and item.achievementRequired ~= ""
        isQuest = item.questRequired and item.questRequired ~= ""
        isDrop = item.dropSource and item.dropSource ~= ""
    end
    
    -- Get theme colors
    local theme = GetTheme()
    local colors = theme.Colors or {}

    -- LEFT EDGE: Split bar - TOP half = faction, BOTTOM half = source type
    local factionHorde = colors.factionHorde or {0.85, 0.20, 0.25, 1.0}
    local factionAlliance = colors.factionAlliance or {0.25, 0.50, 0.90, 1.0}
    local factionNeutral = colors.factionNeutral or {0.60, 0.58, 0.65, 1.0}
    local sourceAchievement = colors.sourceAchievement or {0.95, 0.80, 0.25, 1.0}
    local sourceQuest = colors.sourceQuest or {0.80, 0.45, 0.95, 1.0}
    local sourceDrop = colors.sourceDrop or {0.95, 0.60, 0.25, 1.0}
    local sourceVendor = colors.sourceVendor or {0.35, 0.80, 0.45, 1.0}

    -- TOP HALF (factionBar): Faction color, or source color if no faction
    if button.factionBar then
        if item.faction == "Horde" then
            button.factionBar:SetVertexColor(factionHorde[1], factionHorde[2], factionHorde[3], 1)
        elseif item.faction == "Alliance" then
            button.factionBar:SetVertexColor(factionAlliance[1], factionAlliance[2], factionAlliance[3], 1)
        elseif isAchievement then
            -- No faction, show source type in top half
            button.factionBar:SetVertexColor(sourceAchievement[1], sourceAchievement[2], sourceAchievement[3], 1)
        elseif isQuest then
            button.factionBar:SetVertexColor(sourceQuest[1], sourceQuest[2], sourceQuest[3], 1)
        elseif isDrop then
            button.factionBar:SetVertexColor(sourceDrop[1], sourceDrop[2], sourceDrop[3], 1)
        else
            button.factionBar:SetVertexColor(sourceVendor[1], sourceVendor[2], sourceVendor[3], 1)
        end
        button.factionBar:Show()
    end

    -- BOTTOM HALF (sourceBar): Source type color (always show if faction exists, otherwise matches top)
    if button.sourceBar then
        if item.faction == "Horde" or item.faction == "Alliance" then
            -- Faction exists, show source type in bottom half
            if isAchievement then
                button.sourceBar:SetVertexColor(sourceAchievement[1], sourceAchievement[2], sourceAchievement[3], 1)
            elseif isQuest then
                button.sourceBar:SetVertexColor(sourceQuest[1], sourceQuest[2], sourceQuest[3], 1)
            elseif isDrop then
                button.sourceBar:SetVertexColor(sourceDrop[1], sourceDrop[2], sourceDrop[3], 1)
            else
                button.sourceBar:SetVertexColor(sourceVendor[1], sourceVendor[2], sourceVendor[3], 1)
            end
        else
            -- No faction, match the top half to create unified bar
            if isAchievement then
                button.sourceBar:SetVertexColor(sourceAchievement[1], sourceAchievement[2], sourceAchievement[3], 1)
            elseif isQuest then
                button.sourceBar:SetVertexColor(sourceQuest[1], sourceQuest[2], sourceQuest[3], 1)
            elseif isDrop then
                button.sourceBar:SetVertexColor(sourceDrop[1], sourceDrop[2], sourceDrop[3], 1)
            else
                button.sourceBar:SetVertexColor(sourceVendor[1], sourceVendor[2], sourceVendor[3], 1)
            end
        end
        button.sourceBar:Show()
    end
    
    -- Update backdrop color (Midnight theme with faction tint)
    local bgTertiary = colors.bgTertiary or {0.16, 0.12, 0.24, 0.90}
    local backdropColor
    if item.faction == "Horde" then
        backdropColor = {0.22, 0.10, 0.14, 0.90} -- Subtle red-purple tint
    elseif item.faction == "Alliance" then
        backdropColor = {0.10, 0.14, 0.24, 0.90} -- Subtle blue-purple tint
    else
        backdropColor = {bgTertiary[1], bgTertiary[2], bgTertiary[3], bgTertiary[4]}
    end
    
    -- Store and apply
    button.originalBackdropColor = backdropColor
    button:SetBackdropColor(unpack(backdropColor))
    
    -- Update item name with quality color (Midnight theme enhanced)
    local displayName = item.name or "Unknown"

    -- Quality color codes (slightly brighter for dark theme)
    local qualityColors = {
        [0] = "|cff9d9d9d", -- Poor (gray)
        [1] = "|cffEBE8F0", -- Common (soft white-purple)
        [2] = "|cff1EFF00", -- Uncommon (green)
        [3] = "|cff4080E6", -- Rare (moonlit blue)
        [4] = "|cffA855F7", -- Epic (vibrant purple)
        [5] = "|cffFF8000", -- Legendary (orange)
    }

    -- Use cached API quality if available
    if item._apiQuality then
        local colorCode = qualityColors[item._apiQuality] or "|cffEBE8F0"
        button.nameText:SetText(colorCode .. displayName .. "|r")
    else
        button.nameText:SetText(displayName)
    end
    
    -- Update zone text (new field)
    if button.zoneText then
        local zoneName = item._apiZone or item.zoneName or ""
        button.zoneText:SetText(zoneName)
    end

    -- Display owned quantity if available (from cached API data)
    if button.quantityText then
        local numStored = item._apiNumStored or 0
        local numPlaced = item._apiNumPlaced or 0
        local totalOwned = numStored + numPlaced

        if totalOwned > 0 then
            button.quantityText:SetText(totalOwned)
            button.quantityText:Show()
        else
            button.quantityText:Hide()
        end
    end
    
    -- Removed: Source type display (typeText field removed)
    
    --------------------------------------------------------
    -- GET QUALITY & COST FROM CATALOG API (async - may take time)
    --------------------------------------------------------
    -- Quality color codes (WoW format: |cAARRGGBB)
    local qualityColors = {
        [0] = "|cff9d9d9d", -- Poor (gray)
        [1] = "|cffffffff", -- Common (white)
        [2] = "|cff1eff00", -- Uncommon (green)
        [3] = "|cff0070dd", -- Rare (blue)
        [4] = "|cffa335ee", -- Epic (purple)
        [5] = "|cffff8000", -- Legendary (orange)
    }
    
    if button.costText then
        button.costText:SetText("...") -- Show loading indicator
        button.costText:Show()
    end
    
    -- Initialize vendor text (show empty initially)
    if button.vendorText then
        button.vendorText:SetText("")
        button.vendorText:Show()
    end
    
    local itemID = tonumber(item.itemID)
    button._hvItemID = itemID
    if itemID and HousingAPI then
        local maxAttempts = 4

        local function FormatCostFromVendorInfo(vendorInfo)
            if not vendorInfo or not vendorInfo.cost or #vendorInfo.cost == 0 then
                return nil
            end

            local parts = {}
            for _, costEntry in ipairs(vendorInfo.cost) do
                if costEntry then
                    if costEntry.currencyID == 0 then
                        local copperAmount = tonumber(costEntry.amount) or 0
                        if GetCoinTextureString then
                            table_insert(parts, GetCoinTextureString(copperAmount))
                        else
                            local gold = math.floor(copperAmount / 10000)
                            local silver = math.floor((copperAmount % 10000) / 100)
                            local copper = copperAmount % 100

                            if gold > 0 and silver > 0 then
                                table_insert(parts, string.format("%dg %ds", gold, silver))
                            elseif gold > 0 then
                                table_insert(parts, string.format("%dg", gold))
                            elseif silver > 0 then
                                table_insert(parts, string.format("%ds", silver))
                            elseif copper > 0 then
                                table_insert(parts, string.format("%dc", copper))
                            end
                        end
                    elseif costEntry.currencyID then
                        local amount = tonumber(costEntry.amount) or 0
                        local icon = GetCurrencyIconMarkup and GetCurrencyIconMarkup(costEntry.currencyID) or nil
                        if icon and icon ~= "" then
                            table_insert(parts, tostring(amount) .. " " .. icon)
                        else
                            local currencyName = "Currency #" .. tostring(costEntry.currencyID)
                            local currencyInfo = HousingAPI.GetCurrencyInfo and HousingAPI:GetCurrencyInfo(costEntry.currencyID)
                            if currencyInfo and currencyInfo.name then
                                currencyName = currencyInfo.name
                            elseif HousingCurrencyTypes and HousingCurrencyTypes[costEntry.currencyID] then
                                currencyName = HousingCurrencyTypes[costEntry.currencyID]
                            end
                            table_insert(parts, tostring(amount) .. " " .. currencyName)
                        end
                    end
                end
            end

            if #parts == 0 then return nil end
            return table.concat(parts, " + ")
        end

        local function TryPopulateVendorAndCost(attempt)
            if not button:IsVisible() then return end
            if button._hvItemID ~= itemID then return end

            local catalogData = nil
            if HousingAPICache and HousingAPICache.GetCatalogData then
                catalogData = HousingAPICache:GetCatalogData(itemID)
            else
                catalogData = HousingAPI:GetCatalogData(itemID)
            end

            -- Name + quality (prefer API name if our lightweight record still says "Unknown Item")
            if catalogData and button.nameText then
                if catalogData.name and (not item.name or item.name == "" or item.name == "Unknown Item") then
                    item.name = catalogData.name
                end
                if catalogData.quality ~= nil then
                    local colorCode = qualityColors[catalogData.quality] or "|cffffffff"
                    local displayName = item.name or catalogData.name or "Unknown"
                    button.nameText:SetText(colorCode .. displayName .. "|r")
                else
                    local displayName = item.name or catalogData.name or "Unknown"
                    button.nameText:SetText(displayName)
                end
            end

            -- Vendor + cost from catalogData (best, includes icons)
            if button.vendorText then
                local Filters = _G.HousingFilters
                local filterVendor = Filters and Filters.currentFilters and Filters.currentFilters.vendor or nil
                if _G.HousingVendorHelper then
                    local staticVendor = _G.HousingVendorHelper:GetVendorName(item, filterVendor)
                    if staticVendor and staticVendor ~= "" then
                        button.vendorText:SetText(staticVendor)
                        button.vendorText:Show()
                    end
                end

                -- Only fall back to API/catalog vendor text if we still have nothing.
                local currentVendor = button.vendorText:GetText()
                if (not currentVendor or currentVendor == "") and catalogData and catalogData.vendor and catalogData.vendor ~= "" then
                    button.vendorText:SetText(catalogData.vendor)
                    button.vendorText:Show()
                end
            end
            if catalogData and button.costText and catalogData.cost and catalogData.cost ~= "" then
                button.costText:SetText(catalogData.cost)
                button.costText:Show()
            end

            -- Enriched vendor info (if available)
            local enrichedVendors = nil
            if HousingDataEnrichment and itemID then
                enrichedVendors = HousingDataEnrichment:GetVendorInfo(itemID)
            end
            if enrichedVendors and #enrichedVendors > 0 then
                local vendor = enrichedVendors[1]
                if button.vendorText and vendor.name and vendor.name ~= "" then
                    button.vendorText:SetText(vendor.name)
                    button.vendorText:Show()
                end
                if button.costText and vendor.price and vendor.currency and vendor.price > 0 then
                    local costText = (vendor.currency == "Gold")
                        and string_format("%dg", vendor.price)
                        or string_format("%d %s", vendor.price, vendor.currency)
                    button.costText:SetText(costText)
                    button.costText:Show()
                end
            else
                -- Vendor info from API/cache as a fallback (often available even when sourceText cost is missing)
                local vendorInfo = nil
                local baseInfo = HousingAPI:GetDecorItemInfoFromItemID(itemID)
                if baseInfo and baseInfo.decorID then
                    if HousingAPICache and HousingAPICache.GetVendorInfo then
                        vendorInfo = HousingAPICache:GetVendorInfo(baseInfo.decorID)
                    else
                        vendorInfo = HousingAPI:GetDecorVendorInfo(baseInfo.decorID)
                    end
                end

                if vendorInfo then
                    if button.vendorText then
                        local currentVendor = button.vendorText:GetText()
                        if (not currentVendor or currentVendor == "") and vendorInfo.name and vendorInfo.name ~= "" then
                            button.vendorText:SetText(vendorInfo.name)
                            button.vendorText:Show()
                        end
                    end

                    if button.costText then
                        local currentCost = button.costText:GetText()
                        if not currentCost or currentCost == "" or currentCost == "..." then
                            local formatted = FormatCostFromVendorInfo(vendorInfo)
                            if formatted and formatted ~= "" then
                                button.costText:SetText(formatted)
                                button.costText:Show()
                            end
                        end
                    end
                end
            end

            -- Final fallback: static gold price
            if button.costText then
                local currentCost = button.costText:GetText()
                if (not currentCost or currentCost == "" or currentCost == "...") then
                    if item.price and item.price > 0 then
                        button.costText:SetText(string.format("%dg", item.price))
                        button.costText:Show()
                    elseif currentCost == "..." then
                        button.costText:Hide()
                    end
                end
            end

            -- Fallback vendor text from static/vendor helper data (keeps list populated even when APIs are unavailable)
            if button.vendorText then
                local currentVendor = button.vendorText:GetText()
                if not currentVendor or currentVendor == "" then
                    local vendorName = nil
                    if _G.HousingVendorHelper then
                        local Filters = _G.HousingFilters
                        local filterVendor = Filters and Filters.currentFilters and Filters.currentFilters.vendor
                        vendorName = _G.HousingVendorHelper:GetVendorName(item, filterVendor)
                    else
                        vendorName = item.vendorName or item._apiVendor  -- Prioritize hardcoded data over API
                    end

                    if vendorName and vendorName ~= "" then
                        button.vendorText:SetText(vendorName)
                        button.vendorText:Show()
                    end
                end
            end

            -- Retry a few times (post-login APIs can lag, making cost/vendor intermittent on first paint)
            local needsRetry = false
            if button.vendorText then
                local v = button.vendorText:GetText()
                if not v or v == "" then needsRetry = true end
            end
            if button.costText then
                local c = button.costText:GetText()
                if not c or c == "" or c == "..." then needsRetry = true end
            end

            if needsRetry and attempt < maxAttempts then
                C_Timer.After(0.6, function()
                    TryPopulateVendorAndCost(attempt + 1)
                end)
            end
        end

        C_Timer.After(0.1, function()
            TryPopulateVendorAndCost(1)
        end)
    else
        -- No catalog API, try item.price directly
        -- Note: Static data stores price in GOLD, not copper
        if button.costText then
            if item.price and item.price > 0 then
                button.costText:SetText(string.format("%dg", item.price))
            else
                button.costText:Hide()
            end
        end
    end
    
    -- Removed: Vendor/zone info display (tooltipInfoText field removed)
    -- Wishlist button removed - now in preview panel
    -- Map icon removed - now in preview panel

    -- Update icon - try to get from cache or load asynchronously
    if item.itemID and item.itemID ~= "" then
        local itemID = tonumber(item.itemID)
        if itemID then
            -- Set question mark as placeholder
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            -- If we have a decor thumbnail FileDataID, try it first (only if it resolves to a texture path).
            local thumb = item.thumbnailFileID or item._thumbnailFileID
            local thumbID = thumb and tonumber(thumb) or nil
            if thumbID and thumbID > 0 and C_Texture and C_Texture.GetFileTextureInfo then
                local ok, texturePath = pcall(C_Texture.GetFileTextureInfo, thumbID)
                if ok and texturePath and texturePath ~= "" then
                    button.icon:SetTexture(texturePath)
                end
            end

            -- Request item data to be loaded
            if C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end

            -- Try to get icon with retries (item data may take time to load)
            local attempts = 0
            local maxAttempts = 5
            local retryDelay = 0.1

            local function TryLoadIcon()
                if not button:IsVisible() then return end

                local iconTexture = nil

                -- Method 1: Try C_Item.GetItemIconByID
                if C_Item and C_Item.GetItemIconByID then
                    iconTexture = C_Item.GetItemIconByID(itemID)
                end

                -- Method 2: Fallback to GetItemIcon
                if not iconTexture and GetItemIcon then
                    iconTexture = GetItemIcon(itemID)
                end

                -- If we got a valid texture, use it
                if iconTexture and iconTexture ~= "" then
                    button.icon:SetTexture(iconTexture)
                else
                    -- Retry if we haven't exceeded max attempts
                    attempts = attempts + 1
                    if attempts < maxAttempts then
                        C_Timer.After(retryDelay, TryLoadIcon)
                    end
                    -- If max attempts reached, keep the question mark
                end
            end

            -- Start loading with a small delay to stagger requests
            C_Timer.After(0.01 * buttonIndex, TryLoadIcon)
            
            -- Removed: tooltip scanning for weight and house icon (fields removed)
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    else
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    
    -- Removed: housing icon and weight (fields removed)
    
    -- Check if item is collected and show green tick
    -- If quantity > 0, item is collected (owned = collected)
    if button.collectedIcon then
        local isCollected = false
        
        -- First check: Do we have quantity data showing ownership?
        local numStored = item._apiNumStored or 0
        local numPlaced = item._apiNumPlaced or 0
        local totalOwned = numStored + numPlaced
        
        if totalOwned > 0 then
            isCollected = true
        else
            -- Fallback: Check via HousingCollectionAPI (for items without quantity data yet)
            if item.itemID and item.itemID ~= "" then
                local itemID = tonumber(item.itemID)
                if itemID and HousingCollectionAPI then
                    isCollected = HousingCollectionAPI:IsItemCollected(itemID)
                end
            end
        end
        
        if isCollected then
            button.collectedIcon:Show()
        else
            button.collectedIcon:Hide()
        end
    end
    
    -- Restore default click behavior for regular items (preview panel only)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        local item = self.itemData
        if not item then return end
        
        -- Click: Show preview panel
        if HousingPreviewPanel then
            HousingPreviewPanel:ShowItem(item)
        else
            -- Silently handle missing PreviewPanel
            -- print("HousingVendor: HousingPreviewPanel not found")
        end
    end)
end

