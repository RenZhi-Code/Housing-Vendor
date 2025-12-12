-- Config UI Module
-- Settings for scale, font size, etc.

local ConfigUI = {}
ConfigUI.__index = ConfigUI

local configFrame = nil
local currentSettings = {
    uiScale = 1.0,
    fontSize = 12,
}

-- Initialize config with saved settings
function ConfigUI:Initialize()
    if not HousingDB then
        HousingDB = {}
    end
    
    -- Load saved settings or use defaults
    currentSettings.uiScale = HousingDB.uiScale or 1.0
    currentSettings.fontSize = HousingDB.fontSize or 12
end

-- Create config frame
function ConfigUI:CreateConfigFrame()
    if configFrame then
        return configFrame
    end
    
    -- Get Midnight theme colors
    local GetTheme = _G["GetHousingTheme"] or function() return {Colors = {}} end
    local theme = GetTheme()
    local colors = theme.Colors or {}
    
    local bgPrimary = HousingTheme.Colors.bgPrimary
    local bgSecondary = HousingTheme.Colors.bgSecondary
    local borderPrimary = HousingTheme.Colors.borderPrimary
    local accentPrimary = HousingTheme.Colors.accentPrimary
    local textPrimary = HousingTheme.Colors.textPrimary
    local textSecondary = HousingTheme.Colors.textSecondary
    
    local frame = CreateFrame("Frame", "HousingVendorConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    -- Make movable
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    
    -- Modern Midnight backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(bgPrimary[1], bgPrimary[2], bgPrimary[3], bgPrimary[4])
    frame:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], borderPrimary[4])
    
    -- Drag handlers
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    -- Header with gradient
    local headerBg = frame:CreateTexture(nil, "BACKGROUND")
    headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    headerBg:SetPoint("TOPLEFT", 0, 0)
    headerBg:SetPoint("TOPRIGHT", 0, 0)
    headerBg:SetHeight(60)
    headerBg:SetGradient("VERTICAL", 
        CreateColor(0.15, 0.10, 0.22, 0.8), 
        CreateColor(0.10, 0.07, 0.15, 0.6))
    
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", headerBg, "LEFT", 20, 0)
    title:SetText("Settings")
    title:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
    
    -- Close button (modern style)
    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    closeBtn:SetBackdropColor(bgSecondary[1], bgSecondary[2], bgSecondary[3], 0.8)
    closeBtn:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], 0.6)
    
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeX:SetPoint("CENTER")
    closeX:SetText("X")
    closeX:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
    
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.1, 0.1, 1)
        self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(bgSecondary[1], bgSecondary[2], bgSecondary[3], 0.8)
        self:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], 0.6)
    end)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Content area
    local contentY = -90
    
    -- UI Scale slider
    local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 30, contentY)
    scaleLabel:SetText("UI Scale")
    scaleLabel:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
    
    local scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 10, 0)
    scaleValue:SetTextColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
    scaleValue:SetText(string.format("%.2f", currentSettings.uiScale))
    
    local scaleSlider = CreateFrame("Slider", "HousingVendorScaleSlider", frame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -15)
    scaleSlider:SetWidth(420)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValue(currentSettings.uiScale)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    
    -- Slider labels with theme colors
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "Low"]:SetTextColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
    _G[scaleSlider:GetName() .. "High"]:SetText("1.5")
    _G[scaleSlider:GetName() .. "High"]:SetTextColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
    _G[scaleSlider:GetName() .. "Text"]:SetText("")
    
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        currentSettings.uiScale = value
        scaleValue:SetText(string.format("%.2f", value))
        
        -- Apply immediately to main frame
        if HousingUINew and HousingUINew.ApplyScale then
            HousingUINew:ApplyScale(value)
        end
    end)
    
    contentY = contentY - 90
    
    -- Theme Selector
    local themeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLabel:SetPoint("TOPLEFT", 30, contentY)
    themeLabel:SetText("UI Theme")
    themeLabel:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
    
    local currentThemeName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentThemeName:SetPoint("LEFT", themeLabel, "RIGHT", 10, 0)
    currentThemeName:SetTextColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
    currentThemeName:SetText(HousingTheme.ActiveThemeName or "Midnight")
    
    -- Theme buttons container
    local themeBtnY = -25
    local themeButtons = {}
    local themeNames = {"Midnight", "Alliance", "Horde", "Sleek Black"}
    
    local function CreateThemeButton(themeName, index)
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(100, 32)
        btn:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", (index - 1) * 105, themeBtnY)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        
        local isActive = HousingTheme.ActiveThemeName == themeName
        if isActive then
            btn:SetBackdropColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 0.3)
            btn:SetBackdropBorderColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
        else
            btn:SetBackdropColor(bgSecondary[1], bgSecondary[2], bgSecondary[3], 0.6)
            btn:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], 0.8)
        end
        
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("CENTER")
        btnText:SetText(themeName)
        btnText:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
        
        btn:SetScript("OnEnter", function(self)
            if HousingTheme.ActiveThemeName ~= themeName then
                self:SetBackdropColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 0.2)
                self:SetBackdropBorderColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 0.6)
            end
            
            -- Show theme description tooltip
            local theme = HousingTheme.Themes[themeName]
            if theme then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(themeName, 1, 1, 1)
                GameTooltip:AddLine(theme.description, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            local isActive = HousingTheme.ActiveThemeName == themeName
            if isActive then
                self:SetBackdropColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 0.3)
                self:SetBackdropBorderColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
            else
                self:SetBackdropColor(bgSecondary[1], bgSecondary[2], bgSecondary[3], 0.6)
                self:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], 0.8)
            end
        end)
        
        btn:SetScript("OnClick", function(self)
            -- Set new theme
            local success = HousingTheme:SetTheme(themeName)
            if success then
                currentThemeName:SetText(themeName)
                
                -- Update all theme buttons to show active state
                for _, themeBtn in pairs(themeButtons) do
                    local btnThemeName = themeBtn.themeName
                    local isActive = HousingTheme.ActiveThemeName == btnThemeName
                    -- Get fresh color references from new theme
                    local currentColors = HousingTheme.Colors
                    if isActive then
                        themeBtn:SetBackdropColor(currentColors.accentPrimary[1], currentColors.accentPrimary[2], currentColors.accentPrimary[3], 0.3)
                        themeBtn:SetBackdropBorderColor(currentColors.accentPrimary[1], currentColors.accentPrimary[2], currentColors.accentPrimary[3], 1)
                    else
                        themeBtn:SetBackdropColor(currentColors.bgSecondary[1], currentColors.bgSecondary[2], currentColors.bgSecondary[3], 0.6)
                        themeBtn:SetBackdropBorderColor(currentColors.borderPrimary[1], currentColors.borderPrimary[2], currentColors.borderPrimary[3], 0.8)
                    end
                end
                
                -- Apply theme to main UI immediately
                if HousingUINew and HousingUINew.ApplyTheme then
                    HousingUINew:ApplyTheme()
                end
                
                -- Apply theme to config frame
                ConfigUI:ApplyThemeToConfigFrame()
            end
        end)
        
        btn.themeName = themeName
        themeButtons[themeName] = btn
        return btn
    end
    
    -- Create theme buttons
    for i, themeName in ipairs(themeNames) do
        CreateThemeButton(themeName, i)
    end
    
    contentY = contentY - 70
    
    -- Font Size slider
    local fontLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 30, contentY)
    fontLabel:SetText("Font Size")
    fontLabel:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
    
    local fontValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontValue:SetPoint("LEFT", fontLabel, "RIGHT", 10, 0)
    fontValue:SetTextColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
    fontValue:SetText(tostring(currentSettings.fontSize) .. "px")
    
    local fontSlider = CreateFrame("Slider", "HousingVendorFontSlider", frame, "OptionsSliderTemplate")
    fontSlider:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -15)
    fontSlider:SetWidth(420)
    fontSlider:SetMinMaxValues(10, 18)
    fontSlider:SetValue(currentSettings.fontSize)
    fontSlider:SetValueStep(1)
    fontSlider:SetObeyStepOnDrag(true)
    
    -- Slider labels with theme colors
    _G[fontSlider:GetName() .. "Low"]:SetText("10")
    _G[fontSlider:GetName() .. "Low"]:SetTextColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
    _G[fontSlider:GetName() .. "High"]:SetText("18")
    _G[fontSlider:GetName() .. "High"]:SetTextColor(textSecondary[1], textSecondary[2], textSecondary[3], 1)
    _G[fontSlider:GetName() .. "Text"]:SetText("")
    
    fontSlider:SetScript("OnValueChanged", function(self, value)
        currentSettings.fontSize = value
        fontValue:SetText(tostring(value) .. "px")
        
        -- Apply immediately to item list only
        if HousingItemList and HousingItemList.ApplyFontSize then
            HousingItemList:ApplyFontSize(value)
        end
    end)

    -- Modern styled buttons
    local function CreateModernButton(text, width)
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(width, 36)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn:SetBackdropColor(bgSecondary[1], bgSecondary[2], bgSecondary[3], 0.9)
        btn:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], 0.8)
        
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("CENTER")
        btnText:SetText(text)
        btnText:SetTextColor(textPrimary[1], textPrimary[2], textPrimary[3], 1)
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(accentPrimary[1] * 0.3, accentPrimary[2] * 0.3, accentPrimary[3] * 0.3, 1)
            self:SetBackdropBorderColor(accentPrimary[1], accentPrimary[2], accentPrimary[3], 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(bgSecondary[1], bgSecondary[2], bgSecondary[3], 0.9)
            self:SetBackdropBorderColor(borderPrimary[1], borderPrimary[2], borderPrimary[3], 0.8)
        end)
        
        return btn
    end
    
    -- Save button
    local saveBtn = CreateModernButton("Save", 120)
    saveBtn:SetPoint("BOTTOM", -65, 25)
    saveBtn:SetScript("OnClick", function()
        -- Save to DB
        HousingDB.uiScale = currentSettings.uiScale
        HousingDB.fontSize = currentSettings.fontSize

        print("|cFF8A7FD4HousingVendor:|r Settings saved!")
        frame:Hide()
    end)
    
    -- Reset button
    local resetBtn = CreateModernButton("Reset", 120)
    resetBtn:SetPoint("BOTTOM", 65, 25)
    resetBtn:SetScript("OnClick", function()
        -- Reset to defaults
        currentSettings.uiScale = 1.0
        currentSettings.fontSize = 12

        scaleSlider:SetValue(1.0)
        fontSlider:SetValue(12)

        -- Apply defaults
        if HousingUINew and HousingUINew.ApplyScale then
            HousingUINew:ApplyScale(1.0)
        end
        if HousingItemList and HousingItemList.ApplyFontSize then
            HousingItemList:ApplyFontSize(12)
        end

        print("|cFF8A7FD4HousingVendor:|r Settings reset to defaults")
    end)
    
    configFrame = frame
    return frame
end

-- Show config UI
function ConfigUI:Show()
    if not configFrame then
        self:CreateConfigFrame()
    end
    configFrame:Show()
end

-- Hide config UI
function ConfigUI:Hide()
    if configFrame then
        configFrame:Hide()
    end
end

-- Toggle config UI
function ConfigUI:Toggle()
    if configFrame and configFrame:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

-- Get current settings
function ConfigUI:GetSettings()
    return currentSettings
end

-- Apply current theme to config frame
function ConfigUI:ApplyThemeToConfigFrame()
    if not configFrame then return end
    
    local colors = HousingTheme.Colors
    
    -- Update frame colors
    configFrame:SetBackdropColor(colors.bgPrimary[1], colors.bgPrimary[2], colors.bgPrimary[3], colors.bgPrimary[4])
    configFrame:SetBackdropBorderColor(colors.borderPrimary[1], colors.borderPrimary[2], colors.borderPrimary[3], colors.borderPrimary[4])
end

-- Make globally accessible
_G["HousingConfigUI"] = ConfigUI

return ConfigUI

