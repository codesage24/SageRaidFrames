-- =============================
-- SageRaidFrames
-- =============================

-- Saved Variables
SageRaidFramesDB = SageRaidFramesDB or {}

-- Helper function to ensure we always have valid values
local function GetConfigValue(key)
    local value = SageRaidFramesDB[key]
    
    -- Handle string values (like orientation)
    if DEFAULTS[key] and type(DEFAULTS[key]) == "string" then
        if type(value) == "string" then
            return value
        end
        -- Fallback to default if nil or invalid type
        SageRaidFramesDB[key] = DEFAULTS[key]
        return DEFAULTS[key]
    end
    
    -- Handle numeric values
    if type(value) == "number" then
        return value
    end

    -- Fallback to default if nil or invalid type
    SageRaidFramesDB[key] = DEFAULTS[key]
    return DEFAULTS[key]
end

for k,v in pairs(DEFAULTS) do
    if SageRaidFramesDB[k] == nil then
        SageRaidFramesDB[k] = v
    end
end

-- Frame table
local addon = CreateFrame("Frame")
local frames = {}

-- Ascension-safe unit detection
local function GetUnit(i)
    -- In raid: use raid units directly (player is included in raid roster)
    if GetNumRaidMembers() > 0 then
        if UnitExists("raid"..i) then
            return "raid"..i
        end
        return nil
    end
    
    -- In party (not raid): slot 1 for player, then party members
    if i == 1 then
        return "player"
    end

    -- Adjust index because we used slot 1 for the player
    local idx = i - 1

    -- Raid takes priority
    if UnitExists("raid"..idx) then
        return "raid"..idx
    end

    -- Otherwise use party units (party1–party4)
    if UnitExists("party"..idx) then
        return "party"..idx
    end

    return nil
end

-- Create single cell
local function CreateCell(i)
    local f = CreateFrame("Button", "SRF_Cell"..i, UIParent, "SecureUnitButtonTemplate")
    f:SetSize(GetConfigValue("cellWidth"), GetConfigValue("cellHeight"))

    local row, col
    if GetConfigValue("orientation") == "HORIZONTAL" then
        row = math.floor((i-1)/GetConfigValue("gridCols"))
        col = (i-1)%GetConfigValue("gridCols")
    else
        col = math.floor((i-1)/GetConfigValue("gridCols"))
        row = (i-1)%GetConfigValue("gridCols")
    end

    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        GetConfigValue("posX") + (col*(GetConfigValue("cellWidth")+GetConfigValue("spacing"))),
        (-GetConfigValue("posY")) - (row*(GetConfigValue("cellHeight")+GetConfigValue("spacing")))
    )

 -- Assign unit and click behavior
    local unit = GetUnit(i)
    f:SetAttribute("unit", unit)
    f:RegisterForClicks("AnyUp")       -- left/right clicks
    f:SetAttribute("type1", "target")  -- left-click targets unit
    f:SetAttribute("type2", "menu")    -- right-click opens unit menu

    -- Black background for the entire cell
    f:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        insets = { left=0, right=0, top=0, bottom=0 },
    })
    f:SetBackdropColor(0, 0, 0, 1) -- Solid black background

    -- Target overlay (initially hidden)
    local targetOverlay = CreateFrame("Frame", nil, f)
    targetOverlay:SetAllPoints(f)
    targetOverlay:SetFrameLevel(f:GetFrameLevel() + 5)
    targetOverlay:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = false, tileSize = 0, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    targetOverlay:SetBackdropColor(1, 1, 1, 0) -- Yellow overlay with transparency
    targetOverlay:SetBackdropBorderColor(1, 1, 0, 1) -- Bright yellow border
    targetOverlay:Hide()
    f.targetOverlay = targetOverlay

    -- Health bar (takes up most of the frame)
    local healthBar = CreateFrame("StatusBar", nil, f)
    healthBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    healthBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 6) -- Leave space for power bar
    healthBar:SetMinMaxValues(0,1)
    healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    f.healthBar = healthBar

    -- Power bar (small bar at bottom)
    local powerBar = CreateFrame("StatusBar", nil, f)
    powerBar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 6)
    powerBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    powerBar:SetMinMaxValues(0,1)
    powerBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    f.powerBar = powerBar

    -- Create text frame for player name and health
    local textFrame = CreateFrame("Frame", nil, f)
    textFrame:SetAllPoints(f)
    textFrame:SetFrameLevel(f:GetFrameLevel() + 10)

    -- Player name text (top-left corner)
    f.text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("TOPLEFT", textFrame, "TOPLEFT", 2, -2)
    f.text:SetTextColor(1, 1, 1, 1) -- White text for better readability

    -- Health percentage text (center of cell)
    f.healthText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetFont("Fonts\\2002.TTF", 10)
    f.healthText:SetPoint("CENTER", textFrame, "CENTER", 0, -3)
    f.healthText:SetTextColor(1, 1, 1, 0.6) -- White text with black outline

    -- Show/hide when unit exists
    RegisterUnitWatch(f)

    -- Store frame
    frames[i] = f
end

-- Update target overlays for all frames
local function UpdateTargetOverlays()
    local currentTarget = UnitName("target")
    
    for i = 1, MAX_UNITS do
        if frames[i] and frames[i].targetOverlay then
            local unit = GetUnit(i)
            if unit and UnitExists(unit) and currentTarget and UnitName(unit) == currentTarget then
                frames[i].targetOverlay:Show()
            else
                frames[i].targetOverlay:Hide()
            end
        end
    end
end

-- Update unit
local function UpdateUnit(f, unit)
    if not unit or not UnitExists(unit) then
        f:Hide()
        return
    end
    f:Show()
    
    -- Update health
    local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
    local healthPercent = (maxhp > 0) and (hp/maxhp) or 0
    f.healthBar:SetValue(healthPercent)

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        f.healthBar:SetStatusBarColor(c.r, c.g, c.b)
    else
        f.healthBar:SetStatusBarColor(0.3,0.3,0.3)
    end

    -- Update health percentage text
    if maxhp > 0 then
        local healthPercentDisplay = math.floor(healthPercent * 100)
        f.healthText:SetText(healthPercentDisplay .. "%")
    else
        f.healthText:SetText("--")
    end

    -- Update power
    local power, maxPower = UnitMana(unit), UnitManaMax(unit)
    local powerType = UnitPowerType(unit)
    
    if maxPower > 0 then
        f.powerBar:SetValue(power/maxPower)
        f.powerBar:Show()
        
        -- Set power bar color based on power type
        local powerColor = POWER_COLORS[powerType]
        if powerColor then
            f.powerBar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
        else
            f.powerBar:SetStatusBarColor(0.5, 0.5, 0.5) -- Default gray
        end
    else
        f.powerBar:Hide()
    end

    -- Update player name
    local unitName = UnitName(unit)
    if unitName then
        f.text:SetText(string.sub(unitName, 1, math.floor(GetConfigValue("cellWidth") / 8)))
    else
        f.text:SetText("??")
    end
    
    if not UnitIsConnected(unit) then
        f.healthBar:SetStatusBarColor(0.2,0.2,0.2)
        f.powerBar:SetStatusBarColor(0.1,0.1,0.1)
        f.text:SetText("")
        f.healthText:SetText("OFFLINE")
    end
end

-- Refresh grid
local function RefreshGrid()
    for i=1,MAX_UNITS do
        local unit = GetUnit(i)
        if not frames[i] then CreateCell(i) end
        frames[i]:SetAttribute("unit", unit)
        UpdateUnit(frames[i], unit)
    end
    -- Update target overlays after refreshing grid
    UpdateTargetOverlays()
end

-- Update layout
local function UpdateLayout()
    for i,f in pairs(frames) do
        f:SetSize(GetConfigValue("cellWidth"), GetConfigValue("cellHeight"))
        f:ClearAllPoints()

        local row, col
        if GetConfigValue("orientation") == "HORIZONTAL" then
            -- normal: left→right, then next row
            row = math.floor((i-1)/GetConfigValue("gridCols"))
            col = (i-1)%GetConfigValue("gridCols")
        else
            -- vertical: top→bottom, then next column
            col = math.floor((i-1)/GetConfigValue("gridCols"))
            row = (i-1)%GetConfigValue("gridCols")
        end

        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
            GetConfigValue("posX") + (col*(GetConfigValue("cellWidth")+GetConfigValue("spacing"))),
            (-GetConfigValue("posY")) - (row*(GetConfigValue("cellHeight")+GetConfigValue("spacing")))
        )
    end
end

-- Event handling
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("RAID_ROSTER_UPDATE")
addon:RegisterEvent("PARTY_MEMBERS_CHANGED")
addon:RegisterEvent("UNIT_HEALTH")
addon:RegisterEvent("UNIT_MANA")
addon:RegisterEvent("UNIT_RAGE")
addon:RegisterEvent("UNIT_ENERGY")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("PLAYER_TARGET_CHANGED")

addon:SetScript("OnEvent", function(_, event, arg)
    if event=="PLAYER_LOGIN" then 
        RefreshGrid()
    elseif event=="PLAYER_TARGET_CHANGED" then
        UpdateTargetOverlays()
    elseif event=="UNIT_HEALTH" and arg then
        for i=1,MAX_UNITS do
            if GetUnit(i)==arg and frames[i] then UpdateUnit(frames[i], arg) end
        end
    elseif (event=="UNIT_MANA" or event=="UNIT_RAGE" or event=="UNIT_ENERGY") and arg then
        for i=1,MAX_UNITS do
            if GetUnit(i)==arg and frames[i] then UpdateUnit(frames[i], arg) end
        end
    else
        RefreshGrid()
    end
end)

-- ==========================
-- Config Panel
-- ==========================
local panel = CreateFrame("Frame", "SRF_ConfigPanel", UIParent)
panel.name = "SageRaidFrames"
panel:Hide()

local title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
title:SetPoint("TOPLEFT",16,-16)
title:SetText("SageRaidFrames Configuration")

-- Width Configuration
local widthConfig = Utils_CreateSliderWithBox("Cell Width", panel, title, 50, 200, 
    function() return GetConfigValue("cellWidth") end,
    function(value) SageRaidFramesDB.cellWidth = math.floor(value); UpdateLayout(); panel.refresh(); RefreshGrid() end)

-- Height Configuration
local heightConfig = Utils_CreateSliderWithBox("Cell Height", panel, widthConfig, 40, 100, 
    function() return GetConfigValue("cellHeight") end,
    function(value) SageRaidFramesDB.cellHeight = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Spacing Configuration
local spacingConfig = Utils_CreateSliderWithBox("Cell Spacing", panel, heightConfig, 0, 20, 
    function() return GetConfigValue("spacing") end,
    function(value) SageRaidFramesDB.spacing = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Position X Configuration
local posXConfig = Utils_CreateSliderWithBox("Frame Position X", panel, spacingConfig, 0, 2000, 
    function() return GetConfigValue("posX") end,
    function(value) SageRaidFramesDB.posX = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Position Y Configuration
local posYConfig = Utils_CreateSliderWithBox("Frame Position Y", panel, posXConfig, 0, 2000, 
    function() return GetConfigValue("posY") end,
    function(value) SageRaidFramesDB.posY = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Orientation Configuration
local orientLabel = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
orientLabel:SetPoint("TOPLEFT", posYConfig, "BOTTOMLEFT", 0, -30)
orientLabel:SetText("Orientation")

local orientDrop = CreateFrame("Frame", "SRF_OrientDropdown", panel, "UIDropDownMenuTemplate")
orientDrop:SetPoint("TOPLEFT", orientLabel, "BOTTOMLEFT", -20, -10)

-- Dropdown menu builder
local function OrientDrop_Init(self, level)
    local horizontal = UIDropDownMenu_CreateInfo()
    horizontal.text = "Horizontal"
    horizontal.value = "HORIZONTAL"
    horizontal.func = function()
        SageRaidFramesDB.orientation = "HORIZONTAL"
        UIDropDownMenu_SetSelectedValue(orientDrop, "HORIZONTAL")
        UpdateLayout()
    end
    UIDropDownMenu_AddButton(horizontal)

    local vertical = UIDropDownMenu_CreateInfo()
    vertical.text = "Vertical"
    vertical.value = "VERTICAL"
    vertical.func = function()
        SageRaidFramesDB.orientation = "VERTICAL"
        UIDropDownMenu_SetSelectedValue(orientDrop, "VERTICAL")
        UpdateLayout()
    end
    UIDropDownMenu_AddButton(vertical)
end

-- MUST reinitialize when panel is shown
panel:SetScript("OnShow", function()
    UIDropDownMenu_Initialize(orientDrop, OrientDrop_Init)
    UIDropDownMenu_SetSelectedValue(orientDrop, GetConfigValue("orientation"))
end)

panel.refresh = function()
    widthConfig:SetValue(GetConfigValue("cellWidth"))
    heightConfig:SetValue(GetConfigValue("cellHeight"))
    spacingConfig:SetValue(GetConfigValue("spacing"))
    posXConfig:SetValue(GetConfigValue("posX"))
    posYConfig:SetValue(GetConfigValue("posY"))
    UIDropDownMenu_SetSelectedValue(orientDrop, GetConfigValue("orientation"))
end

InterfaceOptions_AddCategory(panel)

-- Slash Command
SLASH_SAGERFCONFIG1 = "/srf"
SlashCmdList["SAGERFCONFIG"] = function()
    if panel then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
