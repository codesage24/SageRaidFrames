-- =============================
-- SageRaidFrames minimal working
-- =============================

-- Defaults
local defaults = {
    cellWidth = 40,
    cellHeight = 40,
    spacing = 4,
    gridCols = 5,
    posX = 200,
    posY = 200,
    orientation = "HORIZONTAL", -- or "VERTICAL"
}

-- Saved Variables
SageRaidFramesDB = SageRaidFramesDB or {}

for k,v in pairs(defaults) do
    if SageRaidFramesDB[k] == nil then
        SageRaidFramesDB[k] = v
    end
end

-- Frame table
local addon = CreateFrame("Frame")
local frames = {}
local MAX_UNITS = 25

-- Ascension-safe unit detection
local function GetUnit(i)
    -- Slot 1 always reserved for the player
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
    f:SetSize(SageRaidFramesDB.cellWidth, SageRaidFramesDB.cellHeight)

    local row, col
    if SageRaidFramesDB.orientation == "HORIZONTAL" then
        row = math.floor((i-1)/SageRaidFramesDB.gridCols)
        col = (i-1)%SageRaidFramesDB.gridCols
    else
        col = math.floor((i-1)/SageRaidFramesDB.gridCols)
        row = (i-1)%SageRaidFramesDB.gridCols
    end

    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        SageRaidFramesDB.posX + (col*(SageRaidFramesDB.cellWidth+SageRaidFramesDB.spacing)),
        (-SageRaidFramesDB.posY) - (row*(SageRaidFramesDB.cellHeight+SageRaidFramesDB.spacing))
    )

 -- Assign unit and click behavior
    local unit = GetUnit(i)
    f:SetAttribute("unit", unit)
    f:RegisterForClicks("AnyUp")       -- left/right clicks
    f:SetAttribute("type1", "target")  -- left-click targets unit
    f:SetAttribute("type2", "menu")    -- right-click opens unit menu

    -- Backdrop
    f:SetBackdrop({
        bgFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left=2, right=2, top=2, bottom=2 },
    })
    f:SetBackdropColor(0,0,0,0.8)
    f:SetBackdropBorderColor(0,0,0,1) 

    -- Health bar
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    bar:SetMinMaxValues(0,1)
    bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    f.healthBar = bar

    -- Name text
    f.text = bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.text:SetPoint("CENTER")

    f:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1,1,1,1)
    end)
    f:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0,0,0,1)
    end)

    -- Show/hide when unit exists
    RegisterUnitWatch(f)

    -- Store frame
    frames[i] = f
end

-- Update unit
local function UpdateUnit(f, unit)
    if not unit or not UnitExists(unit) then
        f:Hide()
        return
    end
    f:Show()
    local hp, maxhp = UnitHealth(unit), UnitHealthMax(unit)
    f.healthBar:SetValue((maxhp>0) and (hp/maxhp) or 0)

    local _, class = UnitClass(unit)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        f.healthBar:SetStatusBarColor(c.r, c.g, c.b)
    else
        f.healthBar:SetStatusBarColor(0.3,0.3,0.3)
    end

    f.text:SetText(UnitName(unit) and string.sub(UnitName(unit),1,4) or "??")
    if not UnitIsConnected(unit) then
        f.healthBar:SetStatusBarColor(0.2,0.2,0.2)
        f.text:SetText("OFF")
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
end

-- Update layout
local function UpdateLayout()
    for i,f in pairs(frames) do
        f:SetSize(SageRaidFramesDB.cellWidth, SageRaidFramesDB.cellHeight)

        local row, col
        if SageRaidFramesDB.orientation == "HORIZONTAL" then
            -- normal: left→right, then next row
            row = math.floor((i-1)/SageRaidFramesDB.gridCols)
            col = (i-1)%SageRaidFramesDB.gridCols
        else
            -- vertical: top→bottom, then next column
            col = math.floor((i-1)/SageRaidFramesDB.gridCols)
            row = (i-1)%SageRaidFramesDB.gridCols
        end

        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
            SageRaidFramesDB.posX + (col*(SageRaidFramesDB.cellWidth+SageRaidFramesDB.spacing)),
            (-SageRaidFramesDB.posY) - (row*(SageRaidFramesDB.cellHeight+SageRaidFramesDB.spacing))
        )
    end
end

-- Event handling
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("RAID_ROSTER_UPDATE")
addon:RegisterEvent("PARTY_MEMBERS_CHANGED")
addon:RegisterEvent("UNIT_HEALTH")
addon:RegisterEvent("UNIT_AURA")

addon:SetScript("OnEvent", function(_, event, arg)
    if event=="PLAYER_LOGIN" then RefreshGrid()
    elseif event=="UNIT_HEALTH" and arg then
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
local widthConfig = Utils_CreateSliderWithBox("Cell Width", panel, title, 20, 100, 
    function() return SageRaidFramesDB.width or 0 end,
    function(value) SageRaidFramesDB.width = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Height Configuration
local heightConfig = Utils_CreateSliderWithBox("Cell Height", panel, widthConfig, 20, 100, 
    function() return SageRaidFramesDB.height or 0 end,
    function(value) SageRaidFramesDB.height = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Spacing Configuration
local spacingConfig = Utils_CreateSliderWithBox("Cell Spacing", panel, heightConfig, 0, 20, 
    function() return SageRaidFramesDB.spacing or 0 end,
    function(value) SageRaidFramesDB.spacing = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Position X Configuration
local posXConfig = Utils_CreateSliderWithBox("Frame Position X", panel, spacingConfig, 0, 2000, 
    function() return SageRaidFramesDB.posX or 0 end,
    function(value) SageRaidFramesDB.posX = math.floor(value); UpdateLayout(); panel.refresh() end)

-- Position Y Configuration
local posYConfig = Utils_CreateSliderWithBox("Frame Position Y", panel, posXConfig, 0, 2000, 
    function() return SageRaidFramesDB.posY or 0 end,
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
    UIDropDownMenu_SetSelectedValue(orientDrop, SageRaidFramesDB.orientation)
end)

panel.refresh = function()
    widthConfig:SetValue(SageRaidFramesDB.cellWidth)
    heightConfig:SetValue(SageRaidFramesDB.cellHeight)
    spacingConfig:SetValue(SageRaidFramesDB.spacing)
    posXConfig:SetValue(SageRaidFramesDB.posX)
    posYConfig:SetValue(SageRaidFramesDB.posY)
    UIDropDownMenu_SetSelectedValue(orientDrop, SageRaidFramesDB.orientation)
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
