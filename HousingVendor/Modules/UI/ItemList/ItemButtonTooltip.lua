local _G = _G
local C_Timer = C_Timer
local GameTooltip = GameTooltip

local Theme = nil
local function GetTheme()
    if not Theme then
        Theme = HousingTheme or {}
    end
    return Theme
end

local Tooltip = {}
function Tooltip.AttachButton(button)
    local theme = GetTheme()
    local colors = theme.Colors or {}

    -- Hover effects (Midnight theme)
    local bgHover = colors.bgHover or {0.22, 0.16, 0.32, 0.95}
    local accentPrimary = colors.accentPrimary or {0.55, 0.65, 0.90, 1.0}
    
    -- Modifier key handler for dynamic tooltip updates
    local function UpdateTooltipOnModifier(btn)
        if btn:IsMouseOver() and btn.itemData then
            btn:GetScript("OnEnter")(btn)
        end
    end

    button:SetScript("OnEnter", function(self)
        local item = self.itemData
        if item then
            -- Register for modifier key changes to update tooltip dynamically
            self:RegisterEvent("MODIFIER_STATE_CHANGED")
            self:SetScript("OnEvent", function(frame, event)
                if event == "MODIFIER_STATE_CHANGED" then
                    C_Timer.After(0.05, function() UpdateTooltipOnModifier(frame) end)
                end
            end)
            -- Hover state: lighter background, accent border
            self:SetBackdropColor(bgHover[1], bgHover[2], bgHover[3], bgHover[4])
            self:SetBackdropBorderColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
            
            -- No map icon hover effect needed anymore
            
            -- Brighten the backdrop color on hover (preserve faction/source colors)
            if self.originalBackdropColor then
                local r, g, b, a = unpack(self.originalBackdropColor)
                -- Brighten significantly for better visibility
                self:SetBackdropColor(math.min(r + 0.2, 1), math.min(g + 0.2, 1), math.min(b + 0.2, 1), 1)
            else
                -- Fallback if color wasn't stored
                self:SetBackdropColor(0.3, 0.3, 0.3, 1)
            end
            
            -- Gather all available information from all APIs
            local allInfo = {}
            if HousingPreviewPanel and HousingPreviewPanel.GatherAllItemInfo then
                allInfo = HousingPreviewPanel:GatherAllItemInfo(item)
                -- Safety check: ensure catalogInfo and decorInfo are tables or nil (never numbers)
                if allInfo.catalogInfo and type(allInfo.catalogInfo) ~= "table" then
                    allInfo.catalogInfo = nil
                end
                if allInfo.decorInfo and type(allInfo.decorInfo) ~= "table" then
                    allInfo.decorInfo = nil
                end
            end
            
            -- Show comprehensive tooltip with larger font
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()

            -- Increase font size for better readability
            local tooltipFont = GameTooltipText:GetFont()
            GameTooltipText:SetFont(tooltipFont or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
            
            -- Try to show official WoW item tooltip first (if itemID is available)
            local showOfficialTooltip = false
            if item.itemID and item.itemID ~= "" then
                local numericItemID = tonumber(item.itemID)
                if numericItemID then
                    -- Request item data to be loaded
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        C_Item.RequestLoadItemDataByID(numericItemID)
                    end
                    
                    -- Try to get item info
                    local itemInfo = allInfo.itemInfo
                    if not itemInfo and C_Item and C_Item.GetItemInfo then
                        if C_Item.RequestLoadItemDataByID then
                            C_Item.RequestLoadItemDataByID(numericItemID)
                        end
                        local ok, info = pcall(C_Item.GetItemInfo, numericItemID)
                        if ok then
                            itemInfo = info
                        end
                    end
                    
                    -- If we have item info, show official tooltip
                    if itemInfo then
                        GameTooltip:SetItemByID(numericItemID)
                        showOfficialTooltip = true
                    end
                end
            end
            
            -- If official tooltip didn't work, use custom tooltip
            if not showOfficialTooltip then
                -- Item name (colored by faction or quality)
                local nameColor = {1, 1, 1, 1}
                if item.faction == "Horde" then
                    nameColor = {1, 0.3, 0.3, 1} -- Red
                elseif item.faction == "Alliance" then
                    nameColor = {0.3, 0.6, 1, 1} -- Blue
                elseif allInfo.itemInfo and type(allInfo.itemInfo) == "table" and allInfo.itemInfo.itemQuality then
                    -- Use quality color if available
                    local qualityColors = {
                        [0] = {0.62, 0.62, 0.62, 1}, -- Poor
                        [1] = {1, 1, 1, 1}, -- Common
                        [2] = {0.12, 1, 0, 1}, -- Uncommon
                        [3] = {0, 0.44, 0.87, 1}, -- Rare
                        [4] = {0.64, 0.21, 0.93, 1}, -- Epic
                        [5] = {1, 0.5, 0, 1}, -- Legendary
                        [6] = {0.9, 0.8, 0.5, 1}, -- Artifact
                        [7] = {0.9, 0.8, 0.5, 1} -- Heirloom
                    }
                    local qualityColor = qualityColors[allInfo.itemInfo.itemQuality] or {1, 1, 1, 1}
                    nameColor = qualityColor
                end
                
                local displayName = item.name or "Unknown Item"
                if allInfo.itemInfo and type(allInfo.itemInfo) == "table" and allInfo.itemInfo.itemName then
                    displayName = allInfo.itemInfo.itemName
                elseif allInfo.catalogInfo and type(allInfo.catalogInfo) == "table" and allInfo.catalogInfo.name then
                    displayName = allInfo.catalogInfo.name
                elseif allInfo.decorInfo and type(allInfo.decorInfo) == "table" and allInfo.decorInfo.name then
                    displayName = allInfo.decorInfo.name
                end
                
                GameTooltip:SetText(displayName, nameColor[1], nameColor[2], nameColor[3], 1, true)
                
                -- Add API info if available
                if allInfo.itemInfo and type(allInfo.itemInfo) == "table" then
                    if allInfo.itemInfo.itemLevel then
                        GameTooltip:AddLine("Item Level: " .. allInfo.itemInfo.itemLevel, 0.8, 0.8, 0.8, 1)
                    end
                    if allInfo.itemInfo.itemType then
                        local typeText = allInfo.itemInfo.itemType
                        if allInfo.itemInfo.itemSubType then
                            typeText = string.format("%s - %s", typeText, allInfo.itemInfo.itemSubType)
                        end
                        GameTooltip:AddLine("Type: " .. typeText, 0.8, 0.8, 0.8, 1)
                    end
                end
            else
                -- Add separator after official tooltip (no header text)
                GameTooltip:AddLine(" ")
            end
            
            -- Add API information section (no header text)
            if allInfo.itemInfo or (allInfo.catalogInfo and type(allInfo.catalogInfo) == "table") or (allInfo.decorInfo and type(allInfo.decorInfo) == "table") then
                if (allInfo.catalogInfo and type(allInfo.catalogInfo) == "table") or (allInfo.decorInfo and type(allInfo.decorInfo) == "table") then
                    local desc = nil
                    if allInfo.catalogInfo and type(allInfo.catalogInfo) == "table" and allInfo.catalogInfo.description then
                        desc = allInfo.catalogInfo.description
                    elseif allInfo.decorInfo and type(allInfo.decorInfo) == "table" and allInfo.decorInfo.description then
                        desc = allInfo.decorInfo.description
                    end
                    if desc and desc ~= "" then
                        GameTooltip:AddLine("Description: " .. desc, 0.9, 0.9, 0.8, true)
                    end
                end
            end
            
            -- Type and Category
            if item.type and item.type ~= "" then
                GameTooltip:AddLine("Type: " .. item.type, 0.8, 0.8, 0.8, 1)
            end
            if item.category and item.category ~= "" then
                GameTooltip:AddLine("Category: " .. item.category, 0.8, 0.8, 0.8, 1)
            end
            
            GameTooltip:AddLine(" ") -- Spacer
            
            -- Generic NonVendor names to skip (redundant with source type)
            local genericVendors = {
                ["Achievement Items"] = true,
                ["Quest Items"] = true,
                ["Drop Items"] = true,
                ["Crafted Items"] = true,
                ["Replica Items"] = true,
                ["Miscellaneous Items"] = true,
                ["Event Rewards"] = true,
                ["Collection Items"] = true
            }
            local genericZones = {
                ["Achievement Rewards"] = true,
                ["Quest Rewards"] = true,
                ["Drop Rewards"] = true,
                ["Crafted"] = true,
                ["Replicas"] = true,
                ["Miscellaneous"] = true,
                ["Events"] = true,
                ["Collections"] = true
            }
            
            -- Vendor information: prefer hard data via VendorHelper, supplement with API only if missing
            local vendorDisplay = nil
            local zoneDisplay = nil

            local Filters = _G.HousingFilters
            local filterVendor = Filters and Filters.currentFilters and Filters.currentFilters.vendor or nil
            local filterZone = Filters and Filters.currentFilters and Filters.currentFilters.zone or nil

            if _G.HousingVendorHelper then
                vendorDisplay = _G.HousingVendorHelper:GetVendorName(item, filterVendor)
                zoneDisplay = _G.HousingVendorHelper:GetZoneName(item, filterZone)
            else
                vendorDisplay = item.vendorName or item._apiVendor
                zoneDisplay = item.zoneName or item._apiZone
            end

            local expansionDisplay = item._apiExpansion or item.expansionName

            -- On-demand API vendor lookup ONLY if we still have no vendor/zone (never override hard data)
            if (not vendorDisplay or vendorDisplay == "") and HousingAPI and item.itemID then
                local itemIDNum = tonumber(item.itemID)
                local baseInfo = itemIDNum and HousingAPI:GetDecorItemInfoFromItemID(itemIDNum)
                if baseInfo and baseInfo.decorID then
                    local vendorInfo = HousingAPI:GetDecorVendorInfo(baseInfo.decorID)
                    if vendorInfo then
                        if vendorInfo.name and vendorInfo.name ~= "" then
                            vendorDisplay = vendorInfo.name
                            item._apiVendor = vendorInfo.name
                            -- DO NOT overwrite item.vendorName - it contains authoritative data
                        end
                        if vendorInfo.zone and vendorInfo.zone ~= "" then
                            zoneDisplay = vendorInfo.zone
                            item._apiZone = vendorInfo.zone
                            -- DO NOT overwrite item.zoneName - it contains authoritative data
                        end
                    end
                end
            end

            if vendorDisplay and vendorDisplay ~= "" and not genericVendors[vendorDisplay] then
                GameTooltip:AddLine("Vendor: " .. vendorDisplay, 1, 0.82, 0, 1)

                -- Show vendor items if Shift is held
                if IsShiftKeyDown() and HousingDataManager then
                    local vendorItems = {}
                    -- Search through all items to find ones from this vendor
                    for _, checkItem in ipairs(allItems) do
                        local checkVendor = checkItem.vendorName or checkItem._apiVendor  -- Prioritize hardcoded data
                        if checkVendor == vendorDisplay and checkItem.itemID ~= item.itemID then
                            table.insert(vendorItems, checkItem)
                        end
                    end

                    if #vendorItems > 0 then
                        GameTooltip:AddLine(" ", 1, 1, 1, 1) -- Spacer
                        GameTooltip:AddLine("Other items from " .. vendorDisplay .. ":", 0.4, 0.8, 1, 1)

                        -- Limit to first 15 items to avoid tooltip overflow
                        local maxItems = math.min(15, #vendorItems)
                        for i = 1, maxItems do
                            local vendorItem = vendorItems[i]
                            local itemNameShort = vendorItem.name
                            if #itemNameShort > 35 then
                                itemNameShort = itemNameShort:sub(1, 32) .. "..."
                            end

                            -- Check if collected
                            local isCollected = false
                            if vendorItem.itemID then
                                local itemIDNum = tonumber(vendorItem.itemID)
                                if itemIDNum and HousingCollectionAPI then
                                    isCollected = HousingCollectionAPI:IsItemCollected(itemIDNum)
                                end
                            end

                            local checkmark = isCollected and "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:16|t " or "  "
                            GameTooltip:AddLine(checkmark .. itemNameShort, 0.9, 0.9, 0.9, 1)
                        end

                        if #vendorItems > maxItems then
                            GameTooltip:AddLine(string.format("|cFF808080...and %d more items|r", #vendorItems - maxItems), 0.6, 0.6, 0.6, 1)
                        end
                    end
                end
            end
            if zoneDisplay and zoneDisplay ~= "" and not genericZones[zoneDisplay] then
                GameTooltip:AddLine("Zone: " .. zoneDisplay, 1, 0.82, 0, 1)
            end
            if expansionDisplay and expansionDisplay ~= "" and not genericVendors[expansionDisplay] then
                local expansionText = expansionDisplay
                -- Add indicator for Midnight expansion (not yet released)
                if expansionText == "Midnight" then
                    expansionText = expansionText .. " (Not Yet Released)"
                end
                GameTooltip:AddLine("Expansion: " .. expansionText, 1, 0.82, 0, 1)
            end
            
            -- Coordinates
            if item.vendorCoords and item.vendorCoords.x and item.vendorCoords.y then
                GameTooltip:AddLine("Coordinates: " .. string.format("%.1f, %.1f", item.vendorCoords.x, item.vendorCoords.y), 0.7, 0.7, 0.7, 1)
            end

            -- Cost information (parse on-demand if not already available)
            local costDisplay = nil

            -- First check if cost already parsed
            if item._costBreakdown and #item._costBreakdown > 0 then
                costDisplay = item._costBreakdown[1]
            else
                -- Parse cost data on-demand from catalog
                local catalogData = nil
                if HousingAPI and HousingAPI.GetCatalogData and item.itemID then
                    catalogData = HousingAPI:GetCatalogData(item.itemID)
                end

                if catalogData and (catalogData.costRaw or catalogData.cost) then
                    local costStr = catalogData.costRaw or catalogData.cost
                    if type(costStr) == "string" then
                        -- If it's formatted (money/currency links), take the first entry as-is
                        if costStr:find("|Hmoney:", 1, true) or costStr:find("|Hcurrency:", 1, true) then
                            costDisplay = costStr:match("([^,]+)")
                        else
                            -- Check if it's a gold amount (numeric string)
                            local goldAmount = tonumber(costStr)
                            if goldAmount then
                            local gold = math.floor(goldAmount / 10000)
                            local silver = math.floor((goldAmount % 10000) / 100)
                            local copper = goldAmount % 100

                            if gold > 0 then
                                costDisplay = gold .. " Gold"
                                if silver > 0 then costDisplay = costDisplay .. " " .. silver .. " Silver" end
                                if copper > 0 then costDisplay = costDisplay .. " " .. copper .. " Copper" end
                            elseif silver > 0 then
                                costDisplay = silver .. " Silver"
                                if copper > 0 then costDisplay = costDisplay .. " " .. copper .. " Copper" end
                            else
                                costDisplay = copper .. " Copper"
                            end
                        else
                            -- It's a currency string - take first entry if comma-separated
                            costDisplay = costStr:match("([^,]+)")
                        end
                        end
                    end
                end
            end

                -- Convert currency icons to readable names
                if costDisplay and type(costDisplay) == "string" then
                    if not costDisplay:find("%(") then
                        local currencyID = costDisplay:match("|Hcurrency:(%d+)|h")
                        if currencyID then
                            currencyID = tonumber(currencyID)
                            local amount = tonumber(costDisplay:match("(%d+)")) or 0
                            local icon = costDisplay:match("(|T[^|]*|t)")
                            local currencyName = nil

                            if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                                local ok, currencyInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
                                if ok and currencyInfo and currencyInfo.name then
                                    currencyName = currencyInfo.name
                                    if not icon and (currencyInfo.iconFileID or currencyInfo.icon) then
                                        icon = "|T" .. tostring(currencyInfo.iconFileID or currencyInfo.icon) .. ":14|t"
                                    end
                                end
                            end

                            if not currencyName and HousingCurrencyTypes and HousingCurrencyTypes[currencyID] then
                                currencyName = HousingCurrencyTypes[currencyID]
                            end

                            if currencyName then
                                if icon then
                                    costDisplay = amount .. " " .. icon .. " (" .. currencyName .. ")"
                                else
                                    costDisplay = amount .. " (" .. currencyName .. ")"
                                end
                            end
                        end
                    end
                end

            if costDisplay then
                GameTooltip:AddLine("Cost: " .. costDisplay, 1, 0.82, 0, 1)
            end

            -- Achievement requirement (prioritize API data)
            local achievementText = nil
            local achievementID = nil
            
            -- Priority 1: Try from item's AchievementRewards data (has achievementId)
            if item._achievementId then
                achievementID = item._achievementId
                achievementText = item._achievementName or ("Achievement #" .. achievementID)
            -- Priority 2: Try API data
            elseif item._apiAchievement then
                -- Parse achievement name from formatted text if needed
                achievementText = item._apiAchievement
                if string.find(achievementText, "|n|cFFFFD200") then
                    achievementText = string.match(achievementText, "^([^|]+)") or achievementText
                end
                -- Try to extract achievement ID from API data
                if item.itemID then
                    local numericItemID = tonumber(item.itemID)
                    if numericItemID and HousingAPI then
                        local catalogData = HousingAPI:GetCatalogData(numericItemID)
                        if catalogData and catalogData.achievementID then
                            achievementID = catalogData.achievementID
                        end
                    end
                end
            elseif item.achievementRequired and item.achievementRequired ~= "" then
                achievementText = item.achievementRequired
            end
            
            -- Try to get from catalog data if API data not loaded yet
            if not achievementText and item.itemID then
                local numericItemID = tonumber(item.itemID)
                if numericItemID and HousingAPI then
                    local catalogData = HousingAPI:GetCatalogData(numericItemID)
                    if catalogData then
                        if catalogData.achievement then
                            achievementText = catalogData.achievement
                        end
                        if catalogData.achievementID then
                            achievementID = catalogData.achievementID
                        end
                    end
                end
            end
            
            if achievementText and achievementText ~= "" then
                -- Check if achievement is completed and get points
                local achievementStatus = ""
                local achievementPoints = nil
                if achievementID then
                    local completion = HousingAPI and HousingAPI.GetAchievementCompletion and HousingAPI:GetAchievementCompletion(achievementID) or nil
                    if completion then
                        if completion.completed then
                            achievementStatus = " |cFF00FF00(Completed)|r"
                        else
                            achievementStatus = " |cFFFF0000(Not Completed)|r"
                        end
                        achievementPoints = completion.points
                    elseif C_AchievementInfo and C_AchievementInfo.GetAchievementInfo then
                        local ok, achInfo = pcall(C_AchievementInfo.GetAchievementInfo, achievementID)
                        if ok and achInfo then
                            if achInfo.completed then
                                achievementStatus = " |cFF00FF00(Completed)|r"
                            else
                                achievementStatus = " |cFFFF0000(Not Completed)|r"
                            end
                            achievementPoints = achInfo.points
                        end
                    end
                end
                
                -- Build achievement text with status and points
                local displayText = achievementText .. achievementStatus
                if achievementPoints and achievementPoints > 0 then
                    displayText = displayText .. " - " .. achievementPoints .. "pts"
                end
                
                GameTooltip:AddLine("Achievement: " .. displayText, 1, 0.5, 0, 1)
                
                -- Add hint for full tooltip details if we have achievement ID
                if achievementID then
                    GameTooltip:AddLine(" ", 1, 1, 1, 1)  -- Spacer
                    GameTooltip:AddLine("|cFF808080(Hover over achievement name in preview panel for full details)|r", 0.5, 0.5, 0.5, true)
                    
                    -- Store the achievement ID for tooltip enhancement
                    if not self._tooltipAchievementID then
                        -- Hook to show achievement tooltip when hovering over the achievement line
                        self._tooltipAchievementID = achievementID
                    end
                end
            end
            
            -- Quest requirement (ALWAYS use Housing Catalog API - it's the authoritative source)
            local questText = nil
            local questID = nil
            
            -- Priority 1: Try from item's QuestRewards data (has questId)
            if item._questId then
                questID = item._questId
                questText = item._questName or ("Quest #" .. questID)
            -- Priority 2: Get from Housing Catalog API (most accurate for housing decor)
            elseif item.itemID then
                local numericItemID = tonumber(item.itemID)
                if numericItemID and HousingAPI then
                    local catalogData = HousingAPI:GetCatalogData(numericItemID)
                    if catalogData and catalogData.quest then
                        questText = catalogData.quest
                        questID = catalogData.questID
                    end
                end
            end
            
            -- Priority 2: Use cached API data if catalog fetch didn't work
            if not questText and item._apiQuest then
                questText = item._apiQuest
            end
            
            -- Priority 3: Fallback to static data (least accurate)
            if not questText and item.questRequired and item.questRequired ~= "" then
                questText = item.questRequired
            end
            
            -- Only show quest if we have Housing Catalog API data (don't show static data quest)
            -- This ensures we only show the correct quest that unlocks the item
            if questText and questText ~= "" and (item._apiDataLoaded or HousingAPI) then
                -- Strip WoW color codes and formatting from quest text
                local cleanQuestText = questText
                -- Remove color codes (|cFFRRGGBB and |r)
                cleanQuestText = cleanQuestText:gsub("|c%x%x%x%x%x%x%x%x", "")
                cleanQuestText = cleanQuestText:gsub("|r", "")
                -- Remove hyperlinks (|H....|h and |h)
                cleanQuestText = cleanQuestText:gsub("|H[^|]*|h", "")
                cleanQuestText = cleanQuestText:gsub("|h", "")
                -- Remove textures/icons (|T....|t)
                cleanQuestText = cleanQuestText:gsub("|T[^|]*|t", "")
                -- Remove newlines
                cleanQuestText = cleanQuestText:gsub("|n", " ")
                -- Trim whitespace
                cleanQuestText = cleanQuestText:match("^%s*(.-)%s*$")
                
                if cleanQuestText and cleanQuestText ~= "" then
                    -- Add quest text line
                    GameTooltip:AddLine("Quest: " .. cleanQuestText, 0.5, 0.8, 1, 1)
                    
                    -- If we have questID, show full quest tooltip on hover
                    if questID then
                        -- Add instruction hint
                        GameTooltip:AddLine(" ", 1, 1, 1, 1)  -- Spacer
                        GameTooltip:AddLine("|cFF808080(Hover over quest name in preview panel for full details)|r", 0.5, 0.5, 0.5, true)
                    end
                end
            end
            
            -- Reputation/Renown requirement (prioritize API data)
            local reputationText = nil
            local repProgress = nil
            local bestRepCharKey = nil
            local catalogData = nil
            local repLookup = nil
            local repCfg = nil
            local requiredStanding = nil

            if item.itemID then
                local numericItemID = tonumber(item.itemID)
                if numericItemID and HousingAPI then
                    catalogData = HousingAPI:GetCatalogData(numericItemID)
                    if catalogData then
                        if catalogData.reputation and catalogData.reputation ~= "" then
                            reputationText = catalogData.reputation
                        elseif catalogData.renown and catalogData.renown ~= "" then
                            reputationText = catalogData.renown
                        end
                    end
                end
            end

            -- Resolve faction + required standing from lookup data if available (more reliable than per-item text fields)
            if item.itemID then
                local numericItemID = tonumber(item.itemID)
                if numericItemID and HousingVendorItemToFaction and HousingReputations then
                    repLookup = HousingVendorItemToFaction[numericItemID]
                    if repLookup then
                        repCfg = HousingReputations[repLookup.factionID]
                        requiredStanding = repLookup.requiredStanding
                    end
                end
            end

            -- Fallback to item fields if API data not available
            if not reputationText and repCfg and repCfg.label and requiredStanding and requiredStanding ~= "" then
                reputationText = repCfg.label .. " - " .. requiredStanding
            end
            if not reputationText and item.reputationRequired and item.reputationRequired ~= "" then
                local factionName = item.factionName or ""
                if factionName ~= "" then
                    reputationText = factionName .. " - " .. item.reputationRequired
                else
                    reputationText = item.reputationRequired
                end
            end

            -- Calculate reputation progress (same logic as PreviewPanelData)
            if reputationText and item.itemID then
                local numericItemID = tonumber(item.itemID)
                if numericItemID and HousingReputation and HousingVendorItemToFaction and HousingReputations then
                    if HousingReputation.SnapshotReputation then
                        pcall(HousingReputation.SnapshotReputation)
                    end

                    local repLookup = HousingVendorItemToFaction[numericItemID]
                    if repLookup then
                        local cfg = HousingReputations[repLookup.factionID]
                        if cfg then
                            local bestRec, bestCharKey = HousingReputation.GetBestRepRecord(repLookup.factionID)
                            if bestRec then
                                bestRepCharKey = bestCharKey
                                local isUnlocked = HousingReputation.IsItemUnlocked(numericItemID)
                                local requiredStanding = repLookup.requiredStanding

                                if isUnlocked then
                                    repProgress = { current = 1, max = 1, text = "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:16|t Requirement Met", met = true }
                                elseif cfg.rep == "renown" then
                                    local requiredRenown = tonumber(requiredStanding:match("Renown%s+(%d+)")) or 0
                                    repProgress = {
                                        current = bestRec.renownLevel or 0,
                                        max = requiredRenown,
                                        text = string.format("|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:16|t %d / %d Renown", bestRec.renownLevel or 0, requiredRenown),
                                        met = false
                                    }
                                elseif cfg.rep == "standard" then
                                    local reactionNames = {"Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"}
                                    local requiredReaction = 0
                                    for i, name in ipairs(reactionNames) do
                                        if name == requiredStanding then
                                            requiredReaction = i
                                            break
                                        end
                                    end

                                    if requiredReaction > 0 and bestRec.reaction then
                                        repProgress = {
                                            current = bestRec.reaction or 0,
                                            max = requiredReaction,
                                            text = string.format("|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:16|t %s / %s", reactionNames[bestRec.reaction] or "Unknown", requiredStanding),
                                            met = false
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Display reputation with progress bar
            if reputationText and reputationText ~= "" then
                -- Clean reputation text (remove WoW formatting codes)
                local cleanRepText = reputationText
                cleanRepText = cleanRepText:gsub("|c%x%x%x%x%x%x%x%x", "")
                cleanRepText = cleanRepText:gsub("|r", "")
                cleanRepText = cleanRepText:gsub("|H[^|]*|h", "")
                cleanRepText = cleanRepText:gsub("|h", "")
                cleanRepText = cleanRepText:gsub("|T[^|]*|t", "")
                cleanRepText = cleanRepText:gsub("|n", " ")
                cleanRepText = cleanRepText:match("^%s*(.-)%s*$")

                if cleanRepText and cleanRepText ~= "" then
                    -- Color code the reputation requirement based on whether it's met
                    local repR, repG, repB = 0.9, 0.7, 0.3  -- Default orange
                    if repProgress then
                        if repProgress.met or (repProgress.current >= repProgress.max) then
                            repR, repG, repB = 0, 1, 0  -- Green if met
                        else
                            repR, repG, repB = 1, 0.25, 0.25  -- Red if not met
                        end
                    end
                    GameTooltip:AddLine("Reputation: " .. cleanRepText, repR, repG, repB, 1)

                    -- Add progress info if we have progress data
                    if repProgress and repProgress.max > 0 then
                        local progress = math.min(repProgress.current / repProgress.max, 1)

                        -- Create progress text with color
                        local r, g, b
                        if repProgress.met or progress >= 1 then
                            r, g, b = 0, 1, 0 -- Green if met
                        elseif progress >= 0.5 then
                            r, g, b = 0, 0.75, 1 -- Blue if halfway
                        else
                            r, g, b = 1, 0.25, 0.25 -- Red if far away
                        end

                        -- Show progress as text with percentage
                        local progressLine = string.format("%s - %.0f%%", repProgress.text, progress * 100)
                        GameTooltip:AddLine(progressLine, r, g, b, 1)

                        if bestRepCharKey then
                            GameTooltip:AddLine("Best progress on: " .. bestRepCharKey, 0.7, 0.7, 0.7, 1)
                        end
                    end
                end
            end

            -- Drop source (prioritize API data)
            local dropText = nil
            if item._apiSourceText and (item._apiSourceText:find("Drop") or item._apiSourceText:find("Loot")) then
                -- Extract drop source from sourceText
                dropText = item._apiSourceText:match("Drop: ([^\r\n|:]+)") or item._apiSourceText:match("Loot: ([^\r\n|:]+)")
                if dropText then
                    dropText = dropText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h", ""):gsub("|h", ""):gsub("|T[^|]*|t", ""):gsub("|n", "")
                    dropText = dropText:match("^%s*(.-)%s*$")
                end
            elseif item.dropSource and item.dropSource ~= "" then
                dropText = item.dropSource
            end
            
            if dropText and dropText ~= "" then
                GameTooltip:AddLine("Drops from: " .. dropText, 0.8, 0.5, 1, 1)
            end
            
            -- Faction
            if item.faction and item.faction ~= "Neutral" then
                local factionColor = {1, 1, 1, 1}
                if item.faction == "Horde" then
                    factionColor = {1, 0.3, 0.3, 1}
                elseif item.faction == "Alliance" then
                    factionColor = {0.3, 0.6, 1, 1}
                end
                GameTooltip:AddLine("Faction: " .. item.faction, factionColor[1], factionColor[2], factionColor[3], 1)
            end
            
            -- Item ID (if available)
            if item.itemID and item.itemID ~= "" then
                GameTooltip:AddLine("Item ID: " .. item.itemID, 0.5, 0.5, 0.5, 1)
            end
            
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        local theme = GetTheme()
        local colors = theme.Colors or {}
        local bgTertiary = colors.bgTertiary or {0.16, 0.12, 0.24, 0.90}
        local borderPrimary = colors.borderPrimary or {0.35, 0.30, 0.50, 0.8}

        -- Unregister modifier key event
        self:UnregisterEvent("MODIFIER_STATE_CHANGED")
        self:SetScript("OnEvent", nil)

        -- Restore tooltip font size
        local tooltipFont = GameTooltipText:GetFont()
        GameTooltipText:SetFont(tooltipFont or "Fonts\\FRIZQT__.TTF", 12, "")

        -- Restore original colors
        if self.originalBackdropColor then
            self:SetBackdropColor(unpack(self.originalBackdropColor))
        else
            self:SetBackdropColor(bgTertiary[1], bgTertiary[2], bgTertiary[3], bgTertiary[4])
        end
        self:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], borderPrimary[4])

        GameTooltip:Hide()
    end)
end

_G["HousingVendorItemListTooltip"] = Tooltip

