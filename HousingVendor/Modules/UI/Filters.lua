-- Filters Module for HousingVendor addon
-- Clean filter controls and logic

local Filters = {}
Filters.__index = Filters

-- Cache global references for performance
local _G = _G
local CreateFrame = CreateFrame
local UIDropDownMenu_SetWidth = UIDropDownMenu_SetWidth
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UIDropDownMenu_SetSelectedValue = UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_GetSelectedValue = UIDropDownMenu_GetSelectedValue
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local string_format = string.format

local filterFrame = nil

-- Cache for dropdown column layouts
local dropdownLayoutCache = {}

-- Hook dropdown menu to set custom widths and enable multi-column display
local originalToggleDropDownMenu = ToggleDropDownMenu
function ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay)
    local result = originalToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay)
    
    -- Set custom width for specific dropdowns
    if dropDownFrame and dropDownFrame.customLabel then
        local label = dropDownFrame.customLabel
        
        if (label == "Vendor" or label == "Zone") and DropDownList1 and DropDownList1:IsShown() then
            -- Collect visible buttons
            local visibleButtons = {}
            for i = 1, UIDROPDOWNMENU_MAXBUTTONS do
                local btn = _G["DropDownList1Button" .. i]
                if btn and btn:IsShown() then
                    table.insert(visibleButtons, btn)
                end
            end
            
            -- Generate cache key based on label and button count
            local cacheKey = string.format("%s_%d", label, #visibleButtons)
            local layout = dropdownLayoutCache[cacheKey]
            
            -- Calculate layout if not cached
            if not layout then
                -- Both Vendor and Zone use 4 columns for uniformity
                local numColumns = 4
                local columnWidth = 185
                local spacing = 8
                local leftPadding = 20
                local menuWidth = leftPadding + (columnWidth * numColumns) + (spacing * (numColumns - 1)) + 20
                
                -- Split buttons into columns
                local columns = {}
                for i = 1, numColumns do
                    columns[i] = {}
                end
                
                local itemsPerColumn = math.ceil(#visibleButtons / numColumns)
                for i = 1, #visibleButtons do
                    local columnIndex = math.min(math.ceil(i / itemsPerColumn), numColumns)
                    table.insert(columns[columnIndex], i)  -- Store indices, not buttons
                end
                
                -- Calculate menu height
                local maxColumnHeight = 0
                for _, column in ipairs(columns) do
                    maxColumnHeight = math.max(maxColumnHeight, #column)
                end
                local menuHeight = maxColumnHeight * 16 + 30
                
                -- Cache the layout
                layout = {
                    numColumns = numColumns,
                    columnWidth = columnWidth,
                    spacing = spacing,
                    leftPadding = leftPadding,
                    menuWidth = menuWidth,
                    menuHeight = menuHeight,
                    columns = columns
                }
                dropdownLayoutCache[cacheKey] = layout
            end
            
            local menuWidth = layout.menuWidth
            local menuHeight = layout.menuHeight
            
            -- Set width and height BEFORE positioning buttons
            DropDownList1:SetWidth(menuWidth)
            DropDownList1:SetHeight(menuHeight)
            
            -- Create or update custom wide backdrop
            if not DropDownList1.customWideBackdrop then
                DropDownList1.customWideBackdrop = CreateFrame("Frame", nil, DropDownList1, "BackdropTemplate")
                -- Ensure frame level is valid (0 to 65535)
                local parentLevel = DropDownList1:GetFrameLevel()
                local backdropLevel = math.max(0, parentLevel - 1)
                DropDownList1.customWideBackdrop:SetFrameLevel(backdropLevel)
                DropDownList1.customWideBackdrop:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true,
                    tileSize = 16,
                    edgeSize = 16,
                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                })
                DropDownList1.customWideBackdrop:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            end
            
            -- Update backdrop size and position
            DropDownList1.customWideBackdrop:ClearAllPoints()
            DropDownList1.customWideBackdrop:SetPoint("TOPLEFT", DropDownList1, "TOPLEFT", 0, 0)
            DropDownList1.customWideBackdrop:SetWidth(menuWidth)
            DropDownList1.customWideBackdrop:SetHeight(menuHeight)
            DropDownList1.customWideBackdrop:Show()
            
            -- Hide original narrow border textures and left edge bar
            for i = 1, DropDownList1:GetNumRegions() do
                local region = select(i, DropDownList1:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    local texturePath = region:GetTexture() or ""
                    -- Hide tooltip borders and menu backdrop
                    if texturePath:find("UI%-Tooltip") or texturePath:find("MenuBackdrop") then
                        region:Hide()
                    end
                end
            end
            
            -- Hide the left border/bar specifically
            if _G["DropDownList1Border"] then
                _G["DropDownList1Border"]:Hide()
            end
            if DropDownList1.Border then
                DropDownList1.Border:Hide()
            end
            
            -- Position all columns using cached layout
            for colIndex, columnIndices in ipairs(layout.columns) do
                local xOffset = layout.leftPadding + ((colIndex - 1) * (layout.columnWidth + layout.spacing))
                
                local prevBtn = nil
                for rowIndex, btnIndex in ipairs(columnIndices) do
                    local btn = visibleButtons[btnIndex]
                    if btn then
                        btn:ClearAllPoints()
                        btn:SetWidth(layout.columnWidth)
                        if rowIndex == 1 then
                            btn:SetPoint("TOPLEFT", DropDownList1, "TOPLEFT", xOffset, -15)
                        else
                            btn:SetPoint("TOPLEFT", prevBtn, "BOTTOMLEFT", 0, 0)
                        end
                        prevBtn = btn
                        
                        -- Remove highlight/check borders from buttons
                        if btn.Highlight then
                            btn.Highlight:Hide()
                        end
                        if btn.Check then
                            btn.Check:Hide()
                        end
                        if btn.UnCheck then
                            btn.UnCheck:Hide()
                        end
                    end
                end
            end
        else
            -- For other dropdowns, hide the custom backdrop if it exists
            if DropDownList1 and DropDownList1.customWideBackdrop then
                DropDownList1.customWideBackdrop:Hide()
                -- Restore original border textures
                for i = 1, DropDownList1:GetNumRegions() do
                    local region = select(i, DropDownList1:GetRegions())
                    if region and region:GetObjectType() == "Texture" then
                        local texturePath = region:GetTexture() or ""
                        if texturePath:find("UI%-Tooltip") then
                            region:Show()
                        end
                    end
                end
            end
        end
    end
    
    return result
end

-- Get default faction based on player's faction
local function GetDefaultFaction()
    local playerFaction = UnitFactionGroup("player")
    -- Return player's faction, which will show that faction + neutral items
    if playerFaction == "Alliance" or playerFaction == "Horde" then
        return playerFaction
    end
    return "All Factions" -- Fallback
end

local currentFilters = {
    searchText = "",
    expansion = "All Expansions",
    vendor = "All Vendors",
    zone = "All Zones",
    type = "All Types",
    category = "All Categories",
    faction = GetDefaultFaction(),
    source = "All Sources",
    collection = "Uncollected",
    selectedExpansions = {},
    selectedSources = {},
    selectedFactions = {}
}

-- Helper to get filter key from label
local function GetFilterKey(label)
    return string.lower(label)
end

-- Initialize filters
function Filters:Initialize(parentFrame)
    self:CreateFilterSection(parentFrame)
end

-- Create filter section
function Filters:CreateFilterSection(parentFrame)
    filterFrame = CreateFrame("Frame", "HousingFilterFrame", parentFrame, "BackdropTemplate")
    -- Adjust position if warning message exists (35px height)
    local topOffset = -70
    if parentFrame.warningMessage then
        topOffset = -105 -- Move down by 35px to account for warning message
    end
    filterFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, topOffset)
    filterFrame:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, topOffset)
    filterFrame:SetHeight(110)
    
    -- Modern dark background
    filterFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    filterFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Perfect grid alignment - all dropdowns same width and spacing
    local dropdownWidth = 200  -- Wider dropdowns
    local spacing = 20  -- More breathing room
    local leftMargin = 15
    local col1X = leftMargin
    local col2X = col1X + dropdownWidth + spacing
    local col3X = col2X + dropdownWidth + spacing
    local col4X = col3X + dropdownWidth + spacing
    
    -- ROW 1: Search, Expansion, Vendor, Zone
    -- Search box (column 1)
    local searchBox = CreateFrame("EditBox", "HousingSearchBox", filterFrame, "InputBoxTemplate")
    searchBox:SetSize(dropdownWidth, 22)
    searchBox:SetPoint("TOPLEFT", col1X + 25, -25)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        currentFilters.searchText = self:GetText()
        Filters:ApplyFilters()
    end)
    
    local searchLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", -5, 3)  -- Top left of search box
    searchLabel:SetText("Search:")
    searchLabel:SetTextColor(1, 0.82, 0, 1)
    
    -- Expansion dropdown (column 2)
    local expansionDD = self:CreateDropdown(filterFrame, "Expansion", "TOPLEFT", filterFrame, "TOPLEFT", col2X, function(value)
        currentFilters.expansion = value
        self:ApplyFilters()
    end)
    expansionDD:SetPoint("TOPLEFT", col2X, -25)
    
    -- Vendor dropdown (column 3)
    local vendorDD = self:CreateDropdown(filterFrame, "Vendor", "TOPLEFT", filterFrame, "TOPLEFT", col3X, function(value)
        currentFilters.vendor = value
        self:ApplyFilters()
    end)
    vendorDD:SetPoint("TOPLEFT", col3X, -25)
    
    -- Zone dropdown (column 4)
    local zoneDD = self:CreateDropdown(filterFrame, "Zone", "TOPLEFT", filterFrame, "TOPLEFT", col4X, function(value)
        currentFilters.zone = value
        self:ApplyFilters()
    end)
    zoneDD:SetPoint("TOPLEFT", col4X, -25)
    
    -- ROW 2: Type, Category, Source, Faction (perfectly aligned with row 1)
    local row2Y = -72  -- Slightly more spacing between rows
    
    -- Type dropdown (column 1 - aligns with Search)
    local typeDropdown = self:CreateDropdown(filterFrame, "Type", "TOPLEFT", filterFrame, "TOPLEFT", col1X, function(value)
        currentFilters.type = value
        self:ApplyFilters()
    end)
    typeDropdown:SetPoint("TOPLEFT", col1X, row2Y)
    
    -- Category dropdown (column 2 - aligns with Expansion)
    local categoryDropdown = self:CreateDropdown(filterFrame, "Category", "TOPLEFT", filterFrame, "TOPLEFT", col2X, function(value)
        currentFilters.category = value
        self:ApplyFilters()
    end)
    categoryDropdown:SetPoint("TOPLEFT", col2X, row2Y)
    
    -- Source dropdown (column 3 - aligns with Vendor)
    local sourceDropdown = self:CreateDropdown(filterFrame, "Source", "TOPLEFT", filterFrame, "TOPLEFT", col3X, function(value)
        currentFilters.source = value
        self:ApplyFilters()
    end)
    sourceDropdown:SetPoint("TOPLEFT", col3X, row2Y)
    
    -- Faction dropdown (column 4 - aligns with Zone)
    local factionDropdown = self:CreateDropdown(filterFrame, "Faction", "TOPLEFT", filterFrame, "TOPLEFT", col4X, function(value)
        currentFilters.faction = value
        self:ApplyFilters()
    end)
    factionDropdown:SetPoint("TOPLEFT", col4X, row2Y)

    -- Collection dropdown (column 5 - next to Faction)
    local col5X = col4X + dropdownWidth + spacing
    local collectionDropdown = self:CreateCollectionDropdown(filterFrame, "Collection", function(value)
        currentFilters.collection = value
        self:ApplyFilters()
    end)
    collectionDropdown:SetPoint("TOPLEFT", col5X, row2Y)

    -- Back button (hidden by default, shown when drilling down into a view)
    local backBtn = CreateFrame("Button", "HousingBackButton", filterFrame, "UIPanelButtonTemplate")
    backBtn:SetSize(80, 26)
    backBtn:SetPoint("TOPRIGHT", -130, -25)
    backBtn:SetText("← Back")
    backBtn:SetNormalFontObject("GameFontNormalLarge")
    backBtn:Hide()  -- Hidden by default
    backBtn:SetScript("OnClick", function()
        -- Return to the appropriate view based on current display mode
        if HousingUINew and HousingDB and HousingDB.settings and HousingDB.settings.displayMode then
            HousingUINew:RefreshDisplay(HousingDB.settings.displayMode)
            backBtn:Hide()
        end
    end)
    _G["HousingBackButton"] = backBtn

    -- Modern Clear Filters button (top right, aligned with row 1)
    local clearBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(110, 26)
    clearBtn:SetPoint("TOPRIGHT", -10, -25)
    clearBtn:SetText("Clear Filters")
    clearBtn:SetNormalFontObject("GameFontNormalLarge")
    clearBtn:SetScript("OnClick", function()
        self:ClearAllFilters()
    end)

    _G["HousingFilterFrame"] = filterFrame
end

-- Create a dropdown
function Filters:CreateDropdown(parent, label, point, relativeTo, relativePoint, xOffset, onChange)
    local dropdown = CreateFrame("Frame", "Housing" .. label .. "Dropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, relativeTo, relativePoint, xOffset, 0)
    
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 3)
    labelText:SetText(label .. ":")
    labelText:SetTextColor(1, 0.82, 0, 1)  -- Gold color
    
    -- All dropdowns use uniform width for perfect alignment
    local dropdownWidth = 200
    UIDropDownMenu_SetWidth(dropdown, dropdownWidth)
    local defaultText = string.format("All %ss", label)
    if label == "Expansion" then
        defaultText = "All Expansions"
    elseif label == "Faction" then
        -- Use current faction filter value (player's faction or "All Factions")
        local filterKey = GetFilterKey(label)
        defaultText = currentFilters[filterKey] or "All Factions"
    elseif label == "Source" then
        defaultText = "All Sources"
    end
    UIDropDownMenu_SetText(dropdown, defaultText)
    
    -- Store onChange callback
    dropdown.onChange = onChange
    dropdown.label = label
    
    -- Set up dropdown menu
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local options = {}
        
        -- Get options from DataManager
        if HousingDataManager then
            local filterOptions = HousingDataManager:GetFilterOptions()
            if label == "Expansion" then
                options = filterOptions.expansions or {}
            elseif label == "Vendor" then
                options = filterOptions.vendors or {}
            elseif label == "Zone" then
                options = filterOptions.zones or {}
            elseif label == "Type" then
                options = filterOptions.types or {}
            elseif label == "Category" then
                options = filterOptions.categories or {}
            elseif label == "Faction" then
                options = filterOptions.factions or {}
            elseif label == "Source" then
                options = filterOptions.sources or {"Achievement", "Quest", "Drop", "Vendor"}
            end
        end
        
        -- Add "All" option (handle pluralization correctly)
        local allText = string.format("All %ss", label)
        if label == "Expansion" then
            allText = "All Expansions"
        elseif label == "Faction" then
            allText = "All Factions"
        elseif label == "Source" then
            allText = "All Sources"
        end
        
        local info = UIDropDownMenu_CreateInfo()
        info.text = allText
        info.notCheckable = false
        local filterKey = GetFilterKey(label)
        info.checked = (currentFilters[filterKey] == allText)
        info.func = function()
            UIDropDownMenu_SetSelectedValue(dropdown, allText)
            UIDropDownMenu_SetText(dropdown, allText)
            currentFilters[filterKey] = allText
            if dropdown.onChange then
                dropdown.onChange(allText)
            end
        end
        UIDropDownMenu_AddButton(info)
        
        -- Add options
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option
            info.notCheckable = false
            local filterKey = GetFilterKey(label)
            info.checked = (currentFilters[filterKey] == option)
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropdown, option)
                UIDropDownMenu_SetText(dropdown, option)
                currentFilters[filterKey] = option
                if dropdown.onChange then
                    dropdown.onChange(option)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Store label for later use
    dropdown.customLabel = label
    
    return dropdown
end

function Filters:CreateCollectionDropdown(parent, label, onChange)
    local dropdown = CreateFrame("Frame", string.format("Housing%sDropdown", label), parent, "UIDropDownMenuTemplate")

    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("BOTTOMLEFT", dropdown, "TOPLEFT", 20, 3)
    labelText:SetText(label .. ":")
    labelText:SetTextColor(1, 0.82, 0, 1)

    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_SetText(dropdown, "Uncollected")

    dropdown.onChange = onChange
    dropdown.label = label

    UIDropDownMenu_Initialize(dropdown, function()
        local options = {"All", "Uncollected", "Collected"}

        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option
            info.value = option
            info.func = function()
                UIDropDownMenu_SetText(dropdown, option)
                if dropdown.onChange then
                    dropdown.onChange(option)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    dropdown.customLabel = label

    return dropdown
end

-- Apply filters and update item list
function Filters:ApplyFilters()
    if HousingItemList and HousingDataManager then
        local allItems = HousingDataManager:GetAllItems()
        HousingItemList:UpdateItems(allItems, currentFilters)
    end
end

-- Get current filters
function Filters:GetFilters()
    return currentFilters
end

-- Clear all filters
function Filters:ClearAllFilters()
    currentFilters.searchText = ""
    currentFilters.expansion = "All Expansions"
    currentFilters.vendor = "All Vendors"
    currentFilters.zone = "All Zones"
    currentFilters.type = "All Types"
    currentFilters.category = "All Categories"
    currentFilters.faction = GetDefaultFaction()
    currentFilters.source = "All Sources"
    currentFilters.collection = "Uncollected"
    currentFilters.selectedExpansions = {}
    currentFilters.selectedSources = {}
    currentFilters.selectedFactions = {}

    local searchBox = _G["HousingSearchBox"]
    if searchBox then
        searchBox:SetText("")
    end

    local expansionDropdown = _G["HousingExpansionDropdown"]
    if expansionDropdown then
        UIDropDownMenu_SetText(expansionDropdown, "All Expansions")
    end

    local vendorDropdown = _G["HousingVendorDropdown"]
    if vendorDropdown then
        UIDropDownMenu_SetText(vendorDropdown, "All Vendors")
    end

    local zoneDropdown = _G["HousingZoneDropdown"]
    if zoneDropdown then
        UIDropDownMenu_SetText(zoneDropdown, "All Zones")
    end

    local typeDropdown = _G["HousingTypeDropdown"]
    if typeDropdown then
        UIDropDownMenu_SetText(typeDropdown, "All Types")
    end

    local categoryDropdown = _G["HousingCategoryDropdown"]
    if categoryDropdown then
        UIDropDownMenu_SetText(categoryDropdown, "All Categories")
    end

    local sourceDropdown = _G["HousingSourceDropdown"]
    if sourceDropdown then
        UIDropDownMenu_SetText(sourceDropdown, "All Sources")
    end

    local factionDropdown = _G["HousingFactionDropdown"]
    if factionDropdown then
        UIDropDownMenu_SetText(factionDropdown, GetDefaultFaction())
    end

    local collectionDropdown = _G["HousingCollectionDropdown"]
    if collectionDropdown then
        UIDropDownMenu_SetText(collectionDropdown, "Uncollected")
    end

    self:ApplyFilters()

    print("|cFFFFD100HousingVendor:|r Filters cleared")
end

-- Make globally accessible
_G["HousingFilters"] = Filters

return Filters

