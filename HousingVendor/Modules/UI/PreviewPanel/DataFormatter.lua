-- PreviewPanel Sub-module: Data formatting/parsing helpers
-- Part of PreviewPanelData

local _G = _G
local _, HousingVendor = ...
if not HousingVendor then return end

local PreviewPanelData = HousingVendor.PreviewPanelData or _G["HousingPreviewPanelData"]
if not PreviewPanelData then
    PreviewPanelData = {}
    HousingVendor.PreviewPanelData = PreviewPanelData
    _G["HousingPreviewPanelData"] = PreviewPanelData
end

PreviewPanelData.Util = PreviewPanelData.Util or {}

function PreviewPanelData.Util.CleanText(text)
    local DataManager = _G["HousingDataManager"]
    if DataManager and DataManager.Util and DataManager.Util.CleanText then
        return DataManager.Util.CleanText(text, false)
    end
    if not text or text == "" then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|[Hh]", ""):gsub("|T[^|]*|t", ""):gsub("|n", " "):match("^%s*(.-)%s*$") or text
end

function PreviewPanelData.Util.FormatMoneyFromCopper(copperAmount)
    local amount = tonumber(copperAmount) or 0
    if amount <= 0 then
        if GetCoinTextureString then
            return GetCoinTextureString(0)
        end
        return "0 Copper"
    end

    if GetCoinTextureString then
        return GetCoinTextureString(amount)
    end

    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100

    local parts = {}
    if gold > 0 then table.insert(parts, gold .. " Gold") end
    if silver > 0 then table.insert(parts, silver .. " Silver") end
    if copper > 0 then table.insert(parts, copper .. " Copper") end

    return table.concat(parts, " ")
end

function PreviewPanelData.Util.FormatMoneyTooltipFromCopper(copperAmount)
    local icons = PreviewPanelData.Util.FormatMoneyFromCopper(copperAmount)
    if GetCoinTextureString then
        return icons .. " (Gold)"
    end
    return icons
end

function PreviewPanelData.Util.GetCurrencyName(currencyID, fallbackName)
    local id = tonumber(currencyID)
    if not id or id <= 0 then
        return fallbackName or "Currency"
    end

    local currencyInfo = nil
    if HousingAPI and HousingAPI.GetCurrencyInfo then
        currencyInfo = HousingAPI:GetCurrencyInfo(id)
    elseif C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok then currencyInfo = info end
    end

    if currencyInfo and currencyInfo.name and currencyInfo.name ~= "" then
        return currencyInfo.name
    end

    if HousingCurrencyTypes and HousingCurrencyTypes[id] then
        return HousingCurrencyTypes[id]
    end

    return fallbackName or ("Currency (ID: " .. tostring(id) .. ")")
end

function PreviewPanelData.Util.GetCurrencyIconMarkup(currencyID)
    local id = tonumber(currencyID)
    if not id or id <= 0 then return nil end

    local currencyInfo = nil
    if HousingAPI and HousingAPI.GetCurrencyInfo then
        currencyInfo = HousingAPI:GetCurrencyInfo(id)
    elseif C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok then currencyInfo = info end
    end

    local iconFileID = currencyInfo and (currencyInfo.iconFileID or currencyInfo.icon)
    if not iconFileID then return nil end

    return "|T" .. tostring(iconFileID) .. ":14|t"
end

function PreviewPanelData.Util.NormalizeCostString(costStr)
    if not costStr or type(costStr) ~= "string" then return nil end

    local money = costStr:match("|Hmoney:(%d+)|h")
    if money then
        return PreviewPanelData.Util.FormatMoneyTooltipFromCopper(money)
    end

    local currencyID = costStr:match("|Hcurrency:(%d+)")
    if currencyID then
        local amount = tonumber(costStr:match("(%d+)")) or 0
        local name = PreviewPanelData.Util.GetCurrencyName(currencyID)
        local icon = costStr:match("(|T[^|]*|t)") or PreviewPanelData.Util.GetCurrencyIconMarkup(currencyID) or ""
        if icon ~= "" then icon = " " .. icon end
        return amount .. icon .. " (" .. name .. ")"
    end

    local amount = costStr:match("(%d+)")
    if amount and (costStr:find("INV_Misc_Coin_01") or costStr:lower():find("gold")) then
        return amount .. " Gold"
    end

    return costStr ~= "" and costStr or nil
end

function PreviewPanelData:DisplayNameAndIcon(previewFrame, item, catalogData)
    local name = catalogData.name or item.name or "Unknown Item"
    if catalogData.quality ~= nil then
        local qualityColors = {
            [0] = "|cff9d9d9d",
            [1] = "|cffffffff",
            [2] = "|cff1eff00",
            [3] = "|cff0070dd",
            [4] = "|cffa335ee",
            [5] = "|cffff8000",
        }
        local colorCode = qualityColors[catalogData.quality] or "|cffffffff"
        previewFrame.name:SetText(colorCode .. name .. "|r")
    else
        previewFrame.name:SetText(name)
    end
    
    previewFrame.idText:SetText("Item ID: " .. (item.itemID or "Unknown"))
    
    -- Try to get icon from multiple sources
    local icon = nil
    
    -- 1. Try icon cache module first
    if _G["HousingIcons"] and item.itemID then
        icon = _G["HousingIcons"]:GetIcon(item.itemID, item.thumbnailFileID or item._thumbnailFileID or nil)
    elseif _G["HousingIconCache"] and item.itemID then
        -- Backwards-compatible alias
        icon = _G["HousingIconCache"]:GetItemIcon(item.itemID, item.thumbnailFileID or item._thumbnailFileID or nil)
    end
    
    -- 2. Fall back to catalogData.icon
    if not icon then
        icon = catalogData.icon
    end
    
    -- 3. Fall back to item.icon
    if not icon then
        icon = item.icon
    end
    
    -- 4. Fall back to GetItemIcon API
    if not icon and item.itemID then
        local itemID = tonumber(item.itemID)
        if itemID then
            icon = GetItemIcon(itemID)
        end
    end
    
    -- 5. Final fallback to question mark
    if not icon or icon == "" then
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    
    previewFrame.icon:SetTexture(icon)
    
    if catalogData.quality ~= nil then
        local qualityColors = {
            [0] = {0.62, 0.62, 0.62},
            [1] = {1.00, 1.00, 1.00},
            [2] = {0.12, 1.00, 0.00},
            [3] = {0.00, 0.44, 0.87},
            [4] = {0.64, 0.21, 0.93},
            [5] = {1.00, 0.50, 0.00},
        }
        local color = qualityColors[catalogData.quality] or {1, 1, 1}
        if previewFrame.iconBorder and previewFrame.iconBorder.SetBackdropBorderColor then
            previewFrame.iconBorder:SetBackdropBorderColor(color[1], color[2], color[3], 0.9)
        elseif previewFrame.iconBorder and previewFrame.iconBorder.SetVertexColor then
            previewFrame.iconBorder:SetVertexColor(color[1], color[2], color[3], 0.8)
        end
    end
end

function PreviewPanelData:DisplayCollectionStatus(previewFrame, item, catalogData)
    local itemID = tonumber(item.itemID)
    local isCollected = false
    if itemID and HousingCollectionAPI then
        isCollected = HousingCollectionAPI:IsItemCollected(itemID)
    end
    
    if isCollected then
        previewFrame.collectedCheck:Show()
        previewFrame.collectedValue:SetText("|cFF00FF00Yes|r")
    else
        previewFrame.collectedCheck:Hide()
        previewFrame.collectedValue:SetText("|cFFFF0000No|r")
    end
    
    local collectionText = nil
    local numPlaced = item._apiNumPlaced or catalogData.numPlaced or 0
    local numStored = item._apiNumStored or catalogData.numStored or 0
    local totalOwned = numPlaced + numStored

    if numPlaced > 0 then
        collectionText = string.format("Placed: %d", numPlaced)
        if numStored > 0 then
            collectionText = collectionText .. string.format(" | Stored: %d", numStored)
        end
    elseif numStored > 0 then
        collectionText = string.format("Stored: %d", numStored)
    elseif catalogData.quantity and catalogData.quantity > 0 then
        collectionText = string.format("Owned: %d", catalogData.quantity)
    end
    
    if collectionText and collectionText ~= "" then
        previewFrame.SetFieldValue(previewFrame.collectionValue, collectionText, previewFrame.collectionValue.label)
        if previewFrame.collectedValue and previewFrame.collectedValue.label then
            previewFrame.collectedValue.label:ClearAllPoints()
            previewFrame.collectedValue.label:SetPoint("LEFT", previewFrame.collectionValue, "RIGHT", 15, 0)
        end
    else
        if previewFrame.collectionValue then
            previewFrame.collectionValue:Hide()
            if previewFrame.collectionValue.label then
                previewFrame.collectionValue.label:Hide()
            end
        end
        if previewFrame.collectedValue and previewFrame.collectedValue.label then
            previewFrame.collectedValue.label:ClearAllPoints()
            previewFrame.collectedValue.label:SetPoint("TOPLEFT", previewFrame.idText, "BOTTOMLEFT", 0, -4)
        end
    end
end

function PreviewPanelData:DisplayExpansionAndFaction(previewFrame, item, catalogData)
    local expansionText = nil
    if HousingAPI and item.itemID then
        local apiExpansion = HousingAPI:GetExpansionFromFilterTags(item.itemID)
        if apiExpansion and apiExpansion ~= "" then
            expansionText = apiExpansion
            if expansionText == "Midnight" then
                expansionText = expansionText .. " (Not Yet Released)"
            end
        end
    end
    if not expansionText and item.expansionName and item.expansionName ~= "" then
        expansionText = item.expansionName
        if expansionText == "Midnight" then
            expansionText = expansionText .. " (Not Yet Released)"
        end
    end
    
    local displayExpansion = expansionText
    if displayExpansion then
        displayExpansion = displayExpansion:gsub("|c%x%x%x%x%x%x%x%x", "")
        displayExpansion = displayExpansion:gsub("|r", "")
        displayExpansion = displayExpansion:gsub("|H[^|]*|h", "")
        displayExpansion = displayExpansion:gsub("|h", "")
        displayExpansion = displayExpansion:gsub("|T[^|]*|t", "")
        displayExpansion = displayExpansion:gsub("|n", " ")
        displayExpansion = displayExpansion:match("^%s*(.-)%s*$") or displayExpansion
    end
    
    previewFrame.SetFieldValue(previewFrame.expansionValue, displayExpansion, previewFrame.expansionValue.label)

    local factionText = item.faction or "Neutral"
    if factionText == "Alliance" then
        factionText = "|cFF0070DD" .. factionText .. "|r"
    elseif factionText == "Horde" then
        factionText = "|cFFC41E3A" .. factionText .. "|r"
    elseif factionText == "Neutral" then
        factionText = "|cFFFFD100" .. factionText .. "|r"
    end
    previewFrame.SetFieldValue(previewFrame.factionValue, factionText, previewFrame.factionValue.label)
end

function PreviewPanelData:DisplayVendorInfo(previewFrame, item, catalogData)
    local itemID = item and tonumber(item.itemID) or nil
    local vendor = nil
    local zone = nil
    local cost = catalogData.cost
    local costBreakdown = {}
    local costBreakdownIcons = {}
    local coordsText = nil
    local apiCoords = nil
    local apiMapID = nil

    -- Store actual coordinate values for waypoint button (not just formatted text)
    local waypointX = nil
    local waypointY = nil
    local waypointMapID = nil
    
    local enrichedVendors = nil
    if USE_STATIC_VENDOR_ENRICHMENT and HousingDataEnrichment and item.itemID then
        enrichedVendors = HousingDataEnrichment:GetVendorInfo(item.itemID)
    end
    
    if enrichedVendors and #enrichedVendors > 0 then
        local vendorData = enrichedVendors[1]
        if vendorData.name and vendorData.name ~= "" then
            vendor = vendorData.name
        end
        
        if vendorData.location and vendorData.location ~= "" then
            zone = vendorData.location
        end
        
        if vendorData.coordX and vendorData.coordY then
            apiCoords = string.format("%.1f, %.1f", vendorData.coordX, vendorData.coordY)
            coordsText = apiCoords
            if not waypointX then
                waypointX = vendorData.coordX
                waypointY = vendorData.coordY
            end
            if vendorData.mapID and not waypointMapID then
                waypointMapID = vendorData.mapID
            end
        end
        
        if vendorData.price and vendorData.currency then
            if vendorData.price > 0 then
                if vendorData.currency == "Gold" then
                    cost = string.format("%dg", vendorData.price)
                    table.insert(costBreakdown, string.format("%d Gold", vendorData.price))
                    table.insert(costBreakdownIcons, PreviewPanelData.Util.FormatMoneyFromCopper((vendorData.price or 0) * 10000))
                else
                    cost = string.format("%d %s", vendorData.price, vendorData.currency)
                    local currencyName = vendorData.currency
                    local icon = PreviewPanelData.Util.GetCurrencyIconMarkup(vendorData.currencyId or 0)
                    if icon then
                        table.insert(costBreakdown, string.format("%d %s (%s)", vendorData.price, icon, currencyName))
                    else
                        table.insert(costBreakdown, string.format("%d (%s)", vendorData.price, currencyName))
                    end
                    local icon = PreviewPanelData.Util.GetCurrencyIconMarkup(vendorData.currencyId or 0)
                    if icon then
                        table.insert(costBreakdownIcons, string.format("%d %s", vendorData.price, icon))
                    end
                end
            end
        end
    elseif HousingAPI and item.itemID then
        local itemID = tonumber(item.itemID)
        if itemID then
            local baseInfo = HousingAPI:GetDecorItemInfoFromItemID(itemID)
            if baseInfo and baseInfo.decorID then
                local decorID = baseInfo.decorID
                local vendorInfo = HousingAPI:GetDecorVendorInfo(decorID)
                if vendorInfo then
                    if vendorInfo.name and vendorInfo.name ~= "" then
                        vendor = vendorInfo.name
                    end
                    
                    if vendorInfo.zone and vendorInfo.zone ~= "" then
                        zone = vendorInfo.zone
                    end
                    
                    if vendorInfo.coords and vendorInfo.coords.x and vendorInfo.coords.y then
                        apiCoords = string.format("%.1f, %.1f", vendorInfo.coords.x, vendorInfo.coords.y)
                        coordsText = apiCoords
                        if not waypointX then
                            waypointX = vendorInfo.coords.x
                            waypointY = vendorInfo.coords.y
                        end
                    end
                    if vendorInfo.mapID then
                        apiMapID = vendorInfo.mapID
                        if not waypointMapID then
                            waypointMapID = vendorInfo.mapID
                        end
                    end
                    
                    if vendorInfo.cost and #vendorInfo.cost > 0 then
                        for _, costEntry in ipairs(vendorInfo.cost) do
                            if costEntry.currencyID == 0 then
                                table.insert(costBreakdown, PreviewPanelData.Util.FormatMoneyTooltipFromCopper(costEntry.amount))
                                table.insert(costBreakdownIcons, PreviewPanelData.Util.FormatMoneyFromCopper(costEntry.amount))
                            elseif costEntry.currencyID then
                                local amount = tonumber(costEntry.amount) or 0
                                local name = PreviewPanelData.Util.GetCurrencyName(costEntry.currencyID)
                                local icon = PreviewPanelData.Util.GetCurrencyIconMarkup(costEntry.currencyID)
                                if icon then
                                    table.insert(costBreakdown, amount .. " " .. icon .. " (" .. name .. ")")
                                    table.insert(costBreakdownIcons, amount .. " " .. icon)
                                else
                                    table.insert(costBreakdown, amount .. " (" .. name .. ")")
                                end
                            elseif costEntry.itemID then
                                local itemName = "Item #" .. costEntry.itemID
                                if C_Item and C_Item.GetItemInfo then
                                    local ok3, itemInfo = pcall(C_Item.GetItemInfo, costEntry.itemID)
                                    if ok3 and itemInfo and itemInfo.itemName then
                                        itemName = itemInfo.itemName
                                    end
                                end
                                table.insert(costBreakdown, (costEntry.amount or 0) .. "x " .. itemName)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Prefer hard data vendor selection over API-provided vendor text (API can be wrong/overwritten).
    if item then
        local Filters = _G.HousingFilters
        local filterVendor = Filters and Filters.currentFilters and Filters.currentFilters.vendor or nil
        local filterZone = Filters and Filters.currentFilters and Filters.currentFilters.zone or nil

        if _G.HousingVendorHelper then
            vendor = vendor or _G.HousingVendorHelper:GetVendorName(item, filterVendor)
            zone = zone or _G.HousingVendorHelper:GetZoneName(item, filterZone)

            local coords = _G.HousingVendorHelper:GetVendorCoords(item, filterVendor)
            if coords and coords.x and coords.y and coords.x > 0 and coords.y > 0 then
                -- Store actual numeric coordinates for waypoint
                waypointX = coords.x
                waypointY = coords.y
                if coords.mapID and coords.mapID > 0 then
                    waypointMapID = coords.mapID
                    apiMapID = coords.mapID
                end

                if not coordsText then
                    coordsText = string.format("%.1f, %.1f", coords.x, coords.y)
                    apiCoords = coordsText
                end
            end
        end
    end

    if not vendor and catalogData.vendor then
        vendor = PreviewPanelData.Util.CleanText(catalogData.vendor)
    end

    if not zone and catalogData.zone then
        zone = PreviewPanelData.Util.CleanText(catalogData.zone)
        if zone:find("Zone:") then
            zone = zone:gsub("%s*Zone:%s*", "\n")
            zone = zone:gsub("^\n", "")
        end
    end

    -- Fallback to item zone if API data not available (zone may already be set by vendor helper above)
    if not zone and item then
        -- NEW: If user has filtered by zone, show that zone (not the overwritten one)
        local Filters = _G.HousingFilters
        if Filters and Filters.currentFilters and Filters.currentFilters.zone and Filters.currentFilters.zone ~= "All Zones" then
            -- User filtered by a specific zone, show that zone
            zone = Filters.currentFilters.zone
        else
            -- Fallback: static zone first, then API zone
            zone = item.zoneName or item._apiZone
        end
    end

    -- NOTE: Coordinate extraction is now handled by VendorHelper:GetVendorCoords() above (lines 726-740)
    -- which already has the fallback logic for item.coords and item.vendorCoords.
    -- No need to duplicate that logic here.
    
    local parsedReputation = nil
    local repProgress = nil
    local isRenownRequirement = false

    -- Reputation display: prefer catalog/API reputation text, then item record fields,
    -- and finally fall back to older "Faction:" suffix parsing in the zone string.
    local repInfoText = (catalogData and catalogData.reputation) or nil
    if (not repInfoText or repInfoText == "" or repInfoText == "N/A") and item then
        local required = item.reputationRequired
        if required and required ~= "" and required ~= "N/A" then
            local factionName = item.factionName
            if (not factionName or factionName == "") and item.factionID and HousingReputations then
                local cfg = HousingReputations[item.factionID]
                factionName = cfg and cfg.label or factionName
            end
            if factionName and factionName ~= "" then
                repInfoText = string.format("%s - %s", factionName, required)
            else
                repInfoText = required
            end
        end
    end
    if (not repInfoText or repInfoText == "" or repInfoText == "N/A") and itemID and HousingVendorItemToFaction and HousingReputations then
        local repLookup = HousingVendorItemToFaction[itemID]
        if repLookup then
            local cfg = HousingReputations[repLookup.factionID]
            if cfg and cfg.label and repLookup.requiredStanding then
                repInfoText = string.format("%s - %s", cfg.label, repLookup.requiredStanding)
            elseif repLookup.requiredStanding then
                repInfoText = repLookup.requiredStanding
            end
        end
    end

    local factionName, requiredStanding = nil, nil
    if repInfoText and repInfoText ~= "" and repInfoText ~= "N/A" then
        factionName, requiredStanding = repInfoText:match("^(.-)%s*%-%s*(.+)$")
        if factionName and requiredStanding then
            parsedReputation = repInfoText
        else
            -- Unknown formatting; still show the text as-is
            parsedReputation = repInfoText
            -- If the text is just a standing (e.g. "Revered"), still allow progress calc.
            if item and item.reputationRequired and repInfoText == item.reputationRequired then
                requiredStanding = item.reputationRequired
                factionName = item.factionName
                if (not factionName or factionName == "") and item.factionID and HousingReputations then
                    local cfg = HousingReputations[item.factionID]
                    factionName = cfg and cfg.label or factionName
                end
            end
        end
    elseif zone and zone:find("Faction:") then
        local actualZone, repInfo = zone:match("^(.-)%.?Faction:%s*(.+)$")
        if actualZone and repInfo then
            factionName, requiredStanding = repInfo:match("^(.-)%s*%-%s*(.+)$")
            parsedReputation = repInfo
            zone = actualZone
        end
    end

    -- Progress/validation uses the reputation lookup tables (by numeric itemID).
    if parsedReputation and HousingReputation and itemID and HousingVendorItemToFaction and HousingReputations then
        if HousingReputation.SnapshotReputation then
            pcall(HousingReputation.SnapshotReputation)
        end

        local repLookup = HousingVendorItemToFaction[itemID]
        if repLookup then
            local cfg = HousingReputations[repLookup.factionID]
            if cfg then
                if cfg.rep == "renown" then
                    isRenownRequirement = true
                end
                local bestRec = HousingReputation.GetBestRepRecord(repLookup.factionID)

                local current = nil
                if bestRec then
                    if cfg.rep == "renown" then
                        current = string.format("Renown %d", bestRec.renownLevel or 0)
                    elseif cfg.rep == "friendship" then
                        current = bestRec.reactionText or "Unknown"
                    elseif cfg.rep == "standard" then
                        local reactionNames = {"Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"}
                        current = reactionNames[bestRec.reaction] or "Unknown"
                    end
                end

                local required = requiredStanding
                local isUnlocked = HousingReputation.IsItemUnlocked(itemID)
                local labelName = factionName or (cfg and cfg.label) or "Reputation"
                local baseReputationText = (required and labelName) and string.format("%s - %s", labelName, required) or parsedReputation

                if required then
                    if isUnlocked then
                        parsedReputation = "|cFF00FF00" .. baseReputationText .. "|r"  -- Green for met
                        repProgress = { current = 1, max = 1, text = "Requirement Met" }
                    else
                        parsedReputation = "|cFFFF4040" .. baseReputationText .. "|r"  -- Red for not met

                        if cfg.rep == "renown" then
                            local requiredRenown = tonumber(required:match("Renown%s+(%d+)")) or 0
                            local currentRenown = (bestRec and bestRec.renownLevel) or 0
                            repProgress = {
                                current = currentRenown,
                                max = requiredRenown,
                                text = string.format("%d / %d", currentRenown, requiredRenown)
                            }
                        elseif cfg.rep == "standard" then
                            local reactionNames = {"Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"}
                            local requiredReaction = 0
                            for i, name in ipairs(reactionNames) do
                                if name == required then
                                    requiredReaction = i
                                    break
                                end
                            end

                            if requiredReaction > 0 then
                                local currentReaction = (bestRec and bestRec.reaction) or 0
                                repProgress = {
                                    current = currentReaction,
                                    max = requiredReaction,
                                    text = string.format("%s / %s", reactionNames[currentReaction] or "Unknown", required)
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    previewFrame.SetFieldValue(previewFrame.vendorValue, vendor, previewFrame.vendorValue.label)
    
    local displayZone = zone
    if displayZone then
        -- Strip out color codes and formatting
        displayZone = displayZone:gsub("|c%x%x%x%x%x%x%x%x", "")
        displayZone = displayZone:gsub("|r", "")
        displayZone = displayZone:gsub("|H[^|]*|h", "")
        displayZone = displayZone:gsub("|h", "")
        displayZone = displayZone:gsub("|T[^|]*|t", "")
        displayZone = displayZone:gsub("|n", " ")

        -- Remove "Faction: ..." suffix if present (displayed separately in reputation field)
        displayZone = displayZone:gsub("%s*Faction:.-$", "")

        displayZone = displayZone:match("^%s*(.-)%s*$") or displayZone
    end
    
    previewFrame.SetFieldValue(previewFrame.zoneValue, displayZone, previewFrame.zoneValue.label)
    
    local costDisplay = cost
    if #costBreakdown > 0 then
        costDisplay = (costBreakdownIcons[1] or costBreakdown[1])
        item._costBreakdown = costBreakdown -- tooltip-friendly strings
        item._costBreakdownIcons = costBreakdownIcons
    elseif catalogData and (catalogData.costRaw or catalogData.cost) then
        local costText = catalogData.costRaw or catalogData.cost
        if type(costText) == "string" then
            local numeric = tonumber(costText)
            if numeric then
                table.insert(costBreakdown, PreviewPanelData.Util.FormatMoneyTooltipFromCopper(numeric))
                table.insert(costBreakdownIcons, PreviewPanelData.Util.FormatMoneyFromCopper(numeric))
            else
                for part in string.gmatch(costText, "[^,]+") do
                    local normalized = PreviewPanelData.Util.NormalizeCostString(part) or part
                    if normalized and normalized ~= "" then
                        table.insert(costBreakdown, normalized)
                        local iconOnly = part:match("|Hmoney:(%d+)|h")
                        if iconOnly then
                            table.insert(costBreakdownIcons, PreviewPanelData.Util.FormatMoneyFromCopper(iconOnly))
                        else
                            local currencyID = part:match("|Hcurrency:(%d+)")
                            if currencyID then
                                local amount = tonumber(part:match("(%d+)")) or 0
                                local icon = part:match("(|T[^|]*|t)") or PreviewPanelData.Util.GetCurrencyIconMarkup(currencyID)
                                if icon then
                                    table.insert(costBreakdownIcons, amount .. " " .. icon)
                                end
                            end
                        end
                    end
                end
            end
        end

        if #costBreakdown > 0 then
            costDisplay = (costBreakdownIcons[1] or costBreakdown[1])
            item._costBreakdown = costBreakdown -- tooltip-friendly strings
            item._costBreakdownIcons = costBreakdownIcons
        end
    end

    if costDisplay and costDisplay ~= "" and costDisplay ~= "N/A" then
        previewFrame.costValue:SetText(costDisplay)
        previewFrame.costValue:Show()
        if previewFrame.costValue.label then
            previewFrame.costValue.label:Show()
        end
        
        previewFrame.costValue:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Cost Details", 1, 1, 1)
            
            if #costBreakdown > 0 then
                for _, costStr in ipairs(costBreakdown) do
                    local readable = costStr
                    if type(costStr) == "string" and costStr:find("|", 1, true) then
                        readable = PreviewPanelData.Util.NormalizeCostString(costStr) or PreviewPanelData.Util.CleanText(costStr) or costStr
                    end
                    GameTooltip:AddLine(readable, 1, 0.82, 0)
                end
            else
                GameTooltip:AddLine("No detailed cost information", 0.7, 0.7, 0.7)
            end
            
            GameTooltip:Show()
        end)
        
        previewFrame.costValue:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    else
        previewFrame.SetFieldValue(previewFrame.costValue, nil, previewFrame.costValue.label)
    end
    
    previewFrame.SetFieldValue(previewFrame.reputationValue, parsedReputation, previewFrame.reputationValue.label)

    -- Update reputation progress bar
    if previewFrame.reputationBar then
        if repProgress and repProgress.max > 0 then
            local progress = math.min(repProgress.current / repProgress.max, 1)
            previewFrame.reputationBar:SetValue(progress)
            previewFrame.reputationBar.text:SetText(repProgress.text)

            -- Color: green if met, blue if in progress, red if far away
            if progress >= 1 then
                previewFrame.reputationBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
            elseif progress >= 0.5 then
                previewFrame.reputationBar:SetStatusBarColor(0.2, 0.6, 1, 1)
            else
                previewFrame.reputationBar:SetStatusBarColor(0.8, 0.3, 0.3, 1)
            end

            previewFrame.reputationBar:Show()

            -- Add tooltip with detailed reputation info
            if not previewFrame.reputationBar.hasTooltip then
                previewFrame.reputationBar:EnableMouse(true)
                previewFrame.reputationBar:SetScript("OnEnter", function(self)
                    local currentItemID = previewFrame and previewFrame._currentItem and tonumber(previewFrame._currentItem.itemID) or nil
                    if currentItemID and HousingReputation then
                        local repInfo = HousingVendorItemToFaction and HousingVendorItemToFaction[currentItemID]
                        if repInfo and HousingReputations then
                            local cfg = HousingReputations[repInfo.factionID]
                            if cfg then
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetText(cfg.label or "Reputation", 1, 1, 1)

                                local bestRec, bestCharKey = HousingReputation.GetBestRepRecord(repInfo.factionID)
                                if bestRec then
                                    if cfg.rep == "renown" then
                                        GameTooltip:AddLine(string.format("Current: Renown %d", bestRec.renownLevel or 0), 0.5, 0.8, 1)
                                        local requiredRenown = tonumber(repInfo.requiredStanding:match("Renown%s+(%d+)")) or 0
                                        GameTooltip:AddLine(string.format("Required: Renown %d", requiredRenown), 1, 1, 0.5)
                                    elseif cfg.rep == "standard" then
                                        local reactionNames = {"Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"}
                                        GameTooltip:AddLine(string.format("Current: %s", reactionNames[bestRec.reaction] or "Unknown"), 0.5, 0.8, 1)
                                        GameTooltip:AddLine(string.format("Required: %s", repInfo.requiredStanding), 1, 1, 0.5)
                                    elseif cfg.rep == "friendship" then
                                        GameTooltip:AddLine(string.format("Current: %s", bestRec.reactionText or "Unknown"), 0.5, 0.8, 1)
                                        GameTooltip:AddLine(string.format("Required: %s", repInfo.requiredStanding), 1, 1, 0.5)
                                    end

                                    -- Show which character has the best reputation (account-wide tracking)
                                    if bestCharKey then
                                        GameTooltip:AddLine(" ", 1, 1, 1)
                                        GameTooltip:AddLine("Best progress on: " .. bestCharKey, 0.7, 0.7, 0.7)
                                    end
                                end

                                GameTooltip:Show()
                            end
                        end
                    end
                end)
                previewFrame.reputationBar:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                previewFrame.reputationBar.hasTooltip = true
            end
        else
            previewFrame.reputationBar:Hide()
        end
    end

    local renownText = catalogData.renown
    if isRenownRequirement and repProgress then
        renownText = nil
    end
    previewFrame.SetFieldValue(previewFrame.renownValue, renownText, previewFrame.renownValue.label)
    
    if coordsText and coordsText ~= "" then
        -- Use the pre-extracted waypoint coordinates we gathered earlier
        if waypointX and waypointY and waypointMapID then
            previewFrame.mapBtn:Show()
            previewFrame._vendorInfo = {
                name = vendor,
                vendorName = vendor,
                zoneName = zone,
                expansionName = item.expansionName,
                coords = {
                    x = waypointX,
                    y = waypointY,
                    mapID = waypointMapID
                },
                mapID = waypointMapID,
                itemID = item.itemID
            }
        else
            previewFrame.mapBtn:Hide()
        end
    else
        previewFrame.mapBtn:Hide()
    end
    
    previewFrame.UpdateHeaderVisibility(previewFrame.vendorHeader, {
        previewFrame.vendorValue,
        previewFrame.costValue,
        previewFrame.factionValue,
        previewFrame.reputationValue,
        previewFrame.renownValue,
        previewFrame.expansionValue,
        previewFrame.zoneValue
    })
end

function PreviewPanelData:DisplayProfessionInfo(previewFrame, item, catalogData)
    local professionName = item.profession
    local professionText = nil
    local professionSkillText = nil
    local professionRecipeText = nil
    
    if item.profession then
        if item.professionSkillNeeded and item.professionSkillNeeded > 0 then
            local professionID = (C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine) and C_TradeSkillUI.GetTradeSkillLine() or nil
            local currentSkill, maxSkill = 0, 0
            
            if professionID and C_TradeSkillUI.GetProfessionSkillLine then
                local skillLineInfo = C_TradeSkillUI.GetProfessionSkillLine(professionID)
                if skillLineInfo then
                    currentSkill = skillLineInfo.skillLineCurrentLevel or 0
                    maxSkill = skillLineInfo.skillLineMaxLevel or 0
                end
            end
            
            if currentSkill >= item.professionSkillNeeded then
                if item.professionSkill then
                    professionSkillText = item.professionSkill .. " - Level " .. item.professionSkillNeeded .. " |cFF00FF00(Have " .. currentSkill .. "/" .. maxSkill .. ")|r"
                else
                    professionSkillText = "Level " .. item.professionSkillNeeded .. " |cFF00FF00(Have " .. currentSkill .. "/" .. maxSkill .. ")|r"
                end
            elseif currentSkill > 0 then
                if item.professionSkill then
                    professionSkillText = item.professionSkill .. " - Level " .. item.professionSkillNeeded .. " |cFFFF0000(Need " .. item.professionSkillNeeded .. ", currently " .. currentSkill .. "/" .. maxSkill .. ")|r"
                else
                    professionSkillText = "Level " .. item.professionSkillNeeded .. " |cFFFF0000(Need " .. item.professionSkillNeeded .. ", currently " .. currentSkill .. "/" .. maxSkill .. ")|r"
                end
            elseif item.professionSkill then
                professionSkillText = item.professionSkill .. " - Level " .. item.professionSkillNeeded
            else
                professionSkillText = "Level " .. item.professionSkillNeeded
            end
        elseif item.professionSkill then
            professionSkillText = item.professionSkill
        end

        if item.professionSpellID then
            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(item.professionSpellID)
            if spellInfo and spellInfo.name then
                professionRecipeText = spellInfo.name
            end
        elseif item.professionRecipeID then
            if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
                local recipeInfo = C_TradeSkillUI.GetRecipeInfo(item.professionRecipeID)
                if recipeInfo and recipeInfo.name then
                    professionRecipeText = recipeInfo.name
                end
            end
        end

        professionText = professionName
        if professionSkillText then
            professionText = professionText .. " (" .. professionSkillText .. ")"
        end
        if professionRecipeText then
            professionText = professionText .. "\n" .. professionRecipeText
        end
    elseif catalogData.profession then
        professionName = catalogData.profession
        professionText = catalogData.profession
    end
    
    previewFrame.SetFieldValue(previewFrame.professionValue, professionName, previewFrame.professionValue.label)
    previewFrame.SetFieldValue(previewFrame.professionSkillValue, professionSkillText, previewFrame.professionSkillValue.label)
    previewFrame.SetFieldValue(previewFrame.professionRecipeValue, professionRecipeText, previewFrame.professionRecipeValue.label)

    self:DisplayReagents(previewFrame, item)
    
    previewFrame.UpdateHeaderVisibility(previewFrame.professionHeader, {
        previewFrame.professionValue,
        previewFrame.professionSkillValue,
        previewFrame.professionRecipeValue,
        previewFrame.reagentsContainer
    })
end

function PreviewPanelData:DisplayReagents(previewFrame, item)
    local itemID = tonumber(item.itemID)
    local reagentData = itemID and HousingVendor.ProfessionReagents and HousingVendor.ProfessionReagents:GetReagents(itemID)
    
    local textPrimary = HousingTheme.Colors.textPrimary
    local accentPrimary = HousingTheme.Colors.accentPrimary
    
    if previewFrame.reagentsContainer then
        previewFrame.reagentsContainer:Hide()
        if previewFrame.reagentsContainer.header then
            previewFrame.reagentsContainer.header:Hide()
        end
        for _, line in pairs(previewFrame.reagentsContainer.lines or {}) do
            line:Hide()
        end
    end
    
    if reagentData and reagentData.reagents and #reagentData.reagents > 0 then
        if not previewFrame.reagentsContainer then
            local container = CreateFrame("Frame", nil, previewFrame.details)
            container:SetWidth(210)
            container:SetHeight(1)
            container.lines = {}
            previewFrame.reagentsContainer = container
        end
        
        local container = previewFrame.reagentsContainer
        container:ClearAllPoints()
        container:SetPoint("TOPRIGHT", previewFrame.details, "TOPRIGHT", -10, (previewFrame.professionHeader:GetTop() - previewFrame.details:GetTop()))
        container:Show()
        
        if not container.header then
            local header = previewFrame.details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
            header:SetWidth(200)
            header:SetJustifyH("LEFT")
            header:SetText("Reagents:")
            header:SetTextColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
            container.header = header
        end
        container.header:Show()
        
        local yOffset = -18
        for i, reagent in ipairs(reagentData.reagents) do
            if not container.lines[i] then
                local line = previewFrame.details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                line:SetJustifyH("LEFT")
                line:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
                container.lines[i] = line
            end
            
            local line = container.lines[i]
            line:ClearAllPoints()
            line:SetPoint("TOPRIGHT", container.header, "BOTTOMRIGHT", 0, yOffset)
            line:SetWidth(200)
            
            local reagentName = nil
            if C_Item and C_Item.GetItemNameByID then
                reagentName = C_Item.GetItemNameByID(reagent.id)
            end
            
            if not reagentName and C_Item and C_Item.GetItemInfo then
                reagentName = C_Item.GetItemInfo(reagent.id)
            end
            
            if not reagentName then
                reagentName = "Loading..."
                C_Item.RequestLoadItemDataByID(reagent.id)
                C_Timer.After(0.5, function()
                    local name = C_Item.GetItemNameByID(reagent.id)
                    if name and line then
                        line:SetText(reagent.amount .. "x " .. name)
                    end
                end)
            end
            
            line:SetText(reagent.amount .. "x " .. reagentName)
            line:Show()
            yOffset = yOffset - 14
        end
        
        for i = #reagentData.reagents + 1, #container.lines do
            container.lines[i]:Hide()
        end
        
        container:SetHeight(math.abs(yOffset) + 14)
    end
end

function PreviewPanelData:DisplayRequirements(previewFrame, item, catalogData)
    local questText = item._apiQuest or catalogData.quest
    local questID = item._questId or (catalogData and catalogData.questID)
    local achievementText = item._apiAchievement or catalogData.achievement
    local achievementID = item._achievementId or (catalogData and catalogData.achievementID)
    local eventText = catalogData.event
    local classText = catalogData.class
    local raceText = catalogData.race
    
    if questText and questText ~= "" and questText ~= "N/A" then
        local isCompleted = false
        if questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            local ok, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
            if ok then
                isCompleted = completed
            end
        end
        
        local displayText = questText
        if isCompleted then
            displayText = displayText .. " |cFF00FF00(Completed)|r"
        else
            displayText = displayText .. " |cFFFF0000(Not Completed)|r"
        end
        
        previewFrame.questValue:SetText(displayText)
        previewFrame.questValue:Show()
        if previewFrame.questValue.label then previewFrame.questValue.label:Show() end
    else
        previewFrame.SetFieldValue(previewFrame.questValue, nil, previewFrame.questValue.label)
    end

    -- Achievement display with progress tracking
    if achievementText and achievementText ~= "" and achievementText ~= "N/A" then
        local isCompleted = false
        local achievementPoints = nil
        local criteriaProgress = nil
        local criteriaDetails = nil

        if achievementID then
            local completion = HousingAPI and HousingAPI.GetAchievementCompletion and HousingAPI:GetAchievementCompletion(achievementID) or nil
            if completion then
                isCompleted = completion.completed
                achievementPoints = completion.points
            elseif C_AchievementInfo and C_AchievementInfo.GetAchievementInfo then
                local ok, achInfo = pcall(C_AchievementInfo.GetAchievementInfo, achievementID)
                if ok and achInfo then
                    isCompleted = achInfo.completed
                    achievementPoints = achInfo.points
                end
            end

            -- Get criteria progress
            if C_AchievementInfo and C_AchievementInfo.GetAchievementNumCriteria then
                local numCriteria = C_AchievementInfo.GetAchievementNumCriteria(achievementID)
                if numCriteria and numCriteria > 0 then
                    local completedCount = 0
                    criteriaDetails = {}

                    for i = 1, numCriteria do
                        if C_AchievementInfo.GetAchievementCriteriaInfo then
                            local criteriaString, criteriaType, completed, quantity, reqQuantity =
                                C_AchievementInfo.GetAchievementCriteriaInfo(achievementID, i)

                            if completed then
                                completedCount = completedCount + 1
                            end

                            -- Store criteria details for tooltip
                            table.insert(criteriaDetails, {
                                description = criteriaString or "Criterion " .. i,
                                completed = completed,
                                quantity = quantity or 0,
                                reqQuantity = reqQuantity or 0
                            })
                        end
                    end

                    criteriaProgress = {
                        completed = completedCount,
                        total = numCriteria,
                        percentage = (completedCount / numCriteria) * 100
                    }
                end
            end
        end

        local displayText = achievementText
        if isCompleted then
            displayText = displayText .. " |cFF00FF00(Completed)|r"
        elseif criteriaProgress then
            displayText = displayText .. string.format(" |cFFFFAA00(%d/%d)|r", criteriaProgress.completed, criteriaProgress.total)
        else
            displayText = displayText .. " |cFFFF0000(Not Completed)|r"
        end

        if achievementPoints and achievementPoints > 0 then
            displayText = displayText .. " - " .. achievementPoints .. "pts"
        end

        previewFrame.achievementValue:SetText(displayText)
        previewFrame.achievementValue:Show()
        if previewFrame.achievementValue.label then previewFrame.achievementValue.label:Show() end

        -- Add tooltip with detailed criteria
        if criteriaDetails and #criteriaDetails > 0 then
            if not previewFrame.achievementValue.hasTooltip then
                previewFrame.achievementValue:SetScript("OnEnter", function(self)
                    if not previewFrame._achievementCriteriaDetails then return end

                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Achievement Progress", 1, 1, 1)
                    GameTooltip:AddLine(" ")

                    for i, criteria in ipairs(previewFrame._achievementCriteriaDetails) do
                        local color = criteria.completed and "|cFF00FF00" or "|cFFFF0000"
                        local statusText = criteria.completed and "✓" or "✗"

                        if criteria.reqQuantity > 0 then
                            GameTooltip:AddLine(
                                string.format("%s %s (%d/%d)", statusText, criteria.description, criteria.quantity, criteria.reqQuantity),
                                0.7, 0.7, 0.7
                            )
                        else
                            GameTooltip:AddLine(
                                string.format("%s %s", statusText, criteria.description),
                                0.7, 0.7, 0.7
                            )
                        end
                    end

                    GameTooltip:Show()
                end)
                previewFrame.achievementValue:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                previewFrame.achievementValue.hasTooltip = true
            end
            previewFrame._achievementCriteriaDetails = criteriaDetails
        end

        -- Show progress bar if we have criteria progress
        if previewFrame.achievementBar and criteriaProgress and not isCompleted then
            previewFrame.achievementBar:Show()
            previewFrame.achievementBar:SetMinMaxValues(0, criteriaProgress.total)
            previewFrame.achievementBar:SetValue(criteriaProgress.completed)

            -- Set bar text
            if previewFrame.achievementBar.text then
                previewFrame.achievementBar.text:SetText(
                    string.format("%d/%d (%.0f%%)", criteriaProgress.completed, criteriaProgress.total, criteriaProgress.percentage)
                )
            end

            -- Color the bar based on progress
            local r, g, b
            if criteriaProgress.percentage >= 75 then
                r, g, b = 0.0, 1.0, 0.0  -- Green when close
            elseif criteriaProgress.percentage >= 50 then
                r, g, b = 1.0, 0.84, 0.0  -- Gold when halfway
            else
                r, g, b = 1.0, 0.5, 0.0  -- Orange when starting
            end
            previewFrame.achievementBar:SetStatusBarColor(r, g, b)
        elseif previewFrame.achievementBar then
            previewFrame.achievementBar:Hide()
        end
    else
        previewFrame.SetFieldValue(previewFrame.achievementValue, nil, previewFrame.achievementValue.label)
        if previewFrame.achievementBar then
            previewFrame.achievementBar:Hide()
        end
    end
    
    if previewFrame.achievementTrackBtn then
        local shouldShow = achievementID ~= nil and achievementID ~= false
        previewFrame.achievementTrackBtn:SetShown(shouldShow)
        if achievementID then
            previewFrame._achievementId = achievementID
        end
    end
    
    previewFrame.SetFieldValue(previewFrame.eventValue, eventText, previewFrame.eventValue.label)
    previewFrame.SetFieldValue(previewFrame.classValue, classText, previewFrame.classValue.label)
    previewFrame.SetFieldValue(previewFrame.raceValue, raceText, previewFrame.raceValue.label)

    previewFrame.UpdateHeaderVisibility(previewFrame.requirementsHeader, {
        previewFrame.questValue,
        previewFrame.achievementValue,
        previewFrame.eventValue,
        previewFrame.classValue,
        previewFrame.raceValue
    })
end

function PreviewPanelData:Display3DModel(previewFrame, item, catalogData)
    local modelFileID = catalogData and (catalogData.asset or catalogData.modelFileID)
    previewFrame._currentModelID = modelFileID

    if previewFrame.modelFrame and modelFileID and previewFrame.modelVisible then
        previewFrame.modelContainer:Show()

        if modelFileID > 0 then
            previewFrame.modelFrame:SetModel(modelFileID)
        else
            previewFrame.modelContainer:Hide()
        end
    elseif previewFrame.modelContainer then
        previewFrame.modelContainer:Hide()
    end
end

return PreviewPanelData



