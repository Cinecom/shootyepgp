BenchTracker = {}
local mainFrame = nil
local playerFrames = {}
local logEntries = {}
local currentCheckData = {}
local isListening = false
local listenTimer = nil
local listenElapsed = 0
local checkCounter = 0
local activeTab = "afk"

-- Class colors (same as raidstrike)
local CLASS_COLORS = {
    ["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43},
    ["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73},
    ["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45},
    ["ROGUE"] = {r = 1.0, g = 0.96, b = 0.41},
    ["PRIEST"] = {r = 1.0, g = 1.0, b = 1.0},
    ["SHAMAN"] = {r = 0.0, g = 0.44, b = 0.87},
    ["MAGE"] = {r = 0.41, g = 0.8, b = 0.94},
    ["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79},
    ["DRUID"] = {r = 1.0, g = 0.49, b = 0.04}
}

local LOCALIZED_CLASS_LOOKUP = {
    ["Warrior"] = "WARRIOR", ["Paladin"] = "PALADIN", ["Hunter"] = "HUNTER",
    ["Rogue"] = "ROGUE", ["Priest"] = "PRIEST", ["Shaman"] = "SHAMAN",
    ["Mage"] = "MAGE", ["Warlock"] = "WARLOCK", ["Druid"] = "DRUID",
    ["Krieger"] = "WARRIOR", ["Jager"] = "HUNTER",
    ["Schurke"] = "ROGUE", ["Priester"] = "PRIEST", ["Schamane"] = "SHAMAN",
    ["Magier"] = "MAGE", ["Hexenmeister"] = "WARLOCK", ["Druide"] = "DRUID",
    ["Guerrier"] = "WARRIOR", ["Chasseur"] = "HUNTER",
    ["Voleur"] = "ROGUE", ["Chaman"] = "SHAMAN",
}

function BenchTracker:GetEnglishClass(localizedClass)
    if not localizedClass then return nil end
    local upperClass = string.upper(localizedClass)
    if CLASS_COLORS[upperClass] then
        return upperClass
    end
    local englishClass = LOCALIZED_CLASS_LOOKUP[localizedClass]
    if englishClass then
        return englishClass
    end
    return upperClass
end

function BenchTracker:IsOfficer()
    local numMembers = GetNumGuildMembers()
    local playerName = UnitName("player")
    for i = 1, numMembers do
        local name, rank, rankIndex = GetGuildRosterInfo(i)
        if name == playerName then
            if rank == "Officer" or rank == "Supreme Leader" then
                return true
            end
            return false
        end
    end
    return false
end

function BenchTracker:GetTimestamp()
    local dateInfo = date("*t")
    local day = dateInfo.day
    local month = dateInfo.month
    local year = dateInfo.year
    local hour = dateInfo.hour
    local min = dateInfo.min
    local dayStr = day
    local monthStr = month
    if day < 10 then dayStr = "0" .. day end
    if month < 10 then monthStr = "0" .. month end
    local hourStr = hour
    local minStr = min
    if hour < 10 then hourStr = "0" .. hour end
    if min < 10 then minStr = "0" .. min end
    return "[" .. dayStr .. "/" .. monthStr .. "/" .. year .. " - " .. hourStr .. ":" .. minStr .. "]"
end

-- Get list of raid members (bench group)
function BenchTracker:GetRaidMembers()
    local members = {}
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then return members end
    for i = 1, raidSize do
        local name, rank, subgroup, level, class = GetRaidRosterInfo(i)
        if name then
            table.insert(members, {name = name, class = class, subgroup = subgroup})
        end
    end
    -- Sort alphabetically
    table.sort(members, function(a, b)
        return a.name < b.name
    end)
    return members
end

----------------------------------------------------------------
-- MAIN FRAME
----------------------------------------------------------------
function BenchTracker:CreateMainFrame()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "BenchTrackerFrame", UIParent)
    mainFrame:SetWidth(280)
    mainFrame:SetHeight(380)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    mainFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:Hide()

    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -8)
    title:SetText("Bench Tracker")
    title:SetTextColor(0.9, 0.9, 0.9, 1)

    -- Close button
    local closeButton = CreateFrame("Button", nil, mainFrame)
    closeButton:SetWidth(12)
    closeButton:SetHeight(12)
    closeButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)
    closeButton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    closeButton:SetBackdropColor(0.8, 0.2, 0.2, 0.8)
    closeButton:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    local closeText = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeText:SetText("x")
    closeText:SetTextColor(1, 1, 1, 1)
    closeButton:SetScript("OnEnter", function()
        this:SetBackdropColor(1, 0.3, 0.3, 1)
    end)
    closeButton:SetScript("OnLeave", function()
        this:SetBackdropColor(0.8, 0.2, 0.2, 0.8)
    end)
    closeButton:SetScript("OnClick", function() mainFrame:Hide() end)

    -- Tab buttons
    BenchTracker:CreateTabButtons()

    -- AFK Check content area
    local afkContent = CreateFrame("Frame", "BenchAfkContent", mainFrame)
    afkContent:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 6, -42)
    afkContent:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 6)
    afkContent:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil, tile = true, tileSize = 16,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    afkContent:SetBackdropColor(0.08, 0.08, 0.08, 0.5)
    mainFrame.afkContent = afkContent

    -- Column labels above the list (centered over the radio buttons)
    local readyLabel = afkContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    readyLabel:SetPoint("TOP", afkContent, "TOPRIGHT", -50, -2)
    readyLabel:SetText("|cFF00CC00R|r")
    readyLabel:SetTextColor(0.0, 0.8, 0.0, 1)
    mainFrame.colReadyLabel = readyLabel

    local afkLabel = afkContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    afkLabel:SetPoint("TOP", afkContent, "TOPRIGHT", -32, -2)
    afkLabel:SetText("|cFFCC0000A|r")
    afkLabel:SetTextColor(0.8, 0.0, 0.0, 1)
    mainFrame.colAfkLabel = afkLabel

    -- Scroll frame for AFK list
    local scrollFrame = CreateFrame("ScrollFrame", "BenchAfkScrollFrame", afkContent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", afkContent, "TOPLEFT", 2, -14)
    scrollFrame:SetPoint("BOTTOMRIGHT", afkContent, "BOTTOMRIGHT", -2, 26)

    local scrollChild = CreateFrame("Frame", "BenchAfkScrollChild", scrollFrame)
    scrollChild:SetWidth(245)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    mainFrame.afkScrollFrame = scrollFrame
    mainFrame.afkScrollChild = scrollChild

    -- Style scrollbar
    BenchTracker:StyleScrollbar(scrollFrame)

    -- AFK Check button (bottom-left of afk content)
    local afkBtn = CreateFrame("Button", nil, afkContent)
    afkBtn:SetWidth(85)
    afkBtn:SetHeight(18)
    afkBtn:SetPoint("BOTTOMLEFT", afkContent, "BOTTOMLEFT", 4, 4)
    afkBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    afkBtn:SetBackdropColor(0.6, 0.3, 0.0, 0.9)
    afkBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local afkBtnText = afkBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    afkBtnText:SetPoint("CENTER", afkBtn, "CENTER", 0, 0)
    afkBtnText:SetText("AFK Check")
    afkBtnText:SetTextColor(1, 1, 1, 1)
    afkBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.8, 0.4, 0.0, 1)
    end)
    afkBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.6, 0.3, 0.0, 0.9)
    end)
    afkBtn:SetScript("OnClick", function()
        BenchTracker:StartAFKCheck()
    end)
    mainFrame.afkButton = afkBtn

    -- Add to Log button (bottom-right of afk content)
    local logBtn = CreateFrame("Button", nil, afkContent)
    logBtn:SetWidth(85)
    logBtn:SetHeight(18)
    logBtn:SetPoint("BOTTOMRIGHT", afkContent, "BOTTOMRIGHT", -4, 4)
    logBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    logBtn:SetBackdropColor(0.2, 0.4, 0.6, 0.9)
    logBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local logBtnText = logBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    logBtnText:SetPoint("CENTER", logBtn, "CENTER", 0, 0)
    logBtnText:SetText("Add to Log")
    logBtnText:SetTextColor(1, 1, 1, 1)
    logBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.3, 0.5, 0.7, 1)
    end)
    logBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.2, 0.4, 0.6, 0.9)
    end)
    logBtn:SetScript("OnClick", function()
        BenchTracker:ManualLogAFKCheck()
    end)
    mainFrame.logButton = logBtn

    -- Log content area
    local logContent = CreateFrame("Frame", "BenchLogContent", mainFrame)
    logContent:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 6, -42)
    logContent:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 6)
    logContent:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil, tile = true, tileSize = 16,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    logContent:SetBackdropColor(0.08, 0.08, 0.08, 0.5)
    logContent:Hide()
    mainFrame.logContent = logContent

    -- Clear Log button (bottom of log content)
    local clearLogBtn = CreateFrame("Button", nil, logContent)
    clearLogBtn:SetWidth(70)
    clearLogBtn:SetHeight(18)
    clearLogBtn:SetPoint("BOTTOM", logContent, "BOTTOM", 0, 4)
    clearLogBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    clearLogBtn:SetBackdropColor(0.5, 0.15, 0.15, 0.9)
    clearLogBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local clearLogText = clearLogBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearLogText:SetPoint("CENTER", clearLogBtn, "CENTER", 0, 0)
    clearLogText:SetText("Clear Log")
    clearLogText:SetTextColor(1, 1, 1, 1)
    clearLogBtn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.7, 0.2, 0.2, 1)
    end)
    clearLogBtn:SetScript("OnLeave", function()
        this:SetBackdropColor(0.5, 0.15, 0.15, 0.9)
    end)
    clearLogBtn:SetScript("OnClick", function()
        BenchTracker:ClearLog()
    end)
    mainFrame.clearLogButton = clearLogBtn

    -- Scroll frame for Log
    local logScrollFrame = CreateFrame("ScrollFrame", "BenchLogScrollFrame", logContent, "UIPanelScrollFrameTemplate")
    logScrollFrame:SetPoint("TOPLEFT", logContent, "TOPLEFT", 2, -2)
    logScrollFrame:SetPoint("BOTTOMRIGHT", logContent, "BOTTOMRIGHT", -2, 26)

    local logScrollChild = CreateFrame("Frame", "BenchLogScrollChild", logScrollFrame)
    logScrollChild:SetWidth(245)
    logScrollChild:SetHeight(1)
    logScrollFrame:SetScrollChild(logScrollChild)
    mainFrame.logScrollFrame = logScrollFrame
    mainFrame.logScrollChild = logScrollChild

    BenchTracker:StyleScrollbar(logScrollFrame)
end

function BenchTracker:StyleScrollbar(scrollFrame)
    local scrollBar = getglobal(scrollFrame:GetName() .. "ScrollBar")
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, 16)
        scrollBar:SetWidth(5)
        scrollBar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 2,
            insets = {left = 1, right = 1, top = 1, bottom = 1}
        })
        scrollBar:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        scrollBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        local thumb = getglobal(scrollBar:GetName() .. "ThumbTexture")
        if thumb then
            thumb:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            thumb:SetVertexColor(0.9, 0.9, 0.9, 0.9)
            thumb:SetWidth(8)
        end
        local upButton = getglobal(scrollBar:GetName() .. "ScrollUpButton")
        local downButton = getglobal(scrollBar:GetName() .. "ScrollDownButton")
        if upButton then upButton:SetWidth(0) end
        if downButton then downButton:SetWidth(0) end
    end
end

----------------------------------------------------------------
-- TAB BUTTONS
----------------------------------------------------------------
function BenchTracker:CreateTabButtons()
    -- AFK Check tab
    local tabAfk = CreateFrame("Button", "BenchTabAfk", mainFrame)
    tabAfk:SetWidth(80)
    tabAfk:SetHeight(16)
    tabAfk:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 8, -22)
    tabAfk:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    local tabAfkText = tabAfk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabAfkText:SetPoint("CENTER", tabAfk, "CENTER", 0, 0)
    tabAfkText:SetText("AFK Check")
    tabAfk:SetScript("OnClick", function()
        BenchTracker:SwitchTab("afk")
    end)
    mainFrame.tabAfk = tabAfk
    mainFrame.tabAfkText = tabAfkText

    -- Log tab
    local tabLog = CreateFrame("Button", "BenchTabLog", mainFrame)
    tabLog:SetWidth(80)
    tabLog:SetHeight(16)
    tabLog:SetPoint("LEFT", tabAfk, "RIGHT", 4, 0)
    tabLog:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    local tabLogText = tabLog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tabLogText:SetPoint("CENTER", tabLog, "CENTER", 0, 0)
    tabLogText:SetText("Log")
    tabLog:SetScript("OnClick", function()
        BenchTracker:SwitchTab("log")
    end)
    mainFrame.tabLog = tabLog
    mainFrame.tabLogText = tabLogText
end

function BenchTracker:SwitchTab(tab)
    activeTab = tab
    if tab == "afk" then
        mainFrame.afkContent:Show()
        mainFrame.logContent:Hide()
        mainFrame.tabAfk:SetBackdropColor(0.3, 0.3, 0.5, 1)
        mainFrame.tabAfk:SetBackdropBorderColor(0.6, 0.6, 0.8, 1)
        mainFrame.tabAfkText:SetTextColor(1, 1, 1, 1)
        mainFrame.tabLog:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        mainFrame.tabLog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        mainFrame.tabLogText:SetTextColor(0.6, 0.6, 0.6, 1)
        BenchTracker:UpdateAFKDisplay()
    else
        mainFrame.afkContent:Hide()
        mainFrame.logContent:Show()
        mainFrame.tabLog:SetBackdropColor(0.3, 0.3, 0.5, 1)
        mainFrame.tabLog:SetBackdropBorderColor(0.6, 0.6, 0.8, 1)
        mainFrame.tabLogText:SetTextColor(1, 1, 1, 1)
        mainFrame.tabAfk:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        mainFrame.tabAfk:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        mainFrame.tabAfkText:SetTextColor(0.6, 0.6, 0.6, 1)
        BenchTracker:UpdateLogDisplay()
    end
end

----------------------------------------------------------------
-- PLAYER ROW (AFK TAB)
----------------------------------------------------------------
function BenchTracker:CreatePlayerRow(parent, index)
    local frame = CreateFrame("Frame", "BenchPlayerRow" .. index, parent)
    frame:SetWidth(245)
    frame:SetHeight(16)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil, tile = true, tileSize = 16,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    })
    frame:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function()
        this:SetBackdropColor(0.25, 0.35, 0.45, 0.8)
    end)
    frame:SetScript("OnLeave", function()
        this:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
    end)

    -- Player name
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", frame, "LEFT", 4, 0)
    nameText:SetWidth(140)
    nameText:SetJustifyH("LEFT")
    frame.nameText = nameText

    -- Ready button (green)
    local readyBtn = CreateFrame("Button", nil, frame)
    readyBtn:SetWidth(14)
    readyBtn:SetHeight(14)
    readyBtn:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    readyBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    readyBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("Ready", 0.2, 0.8, 0.2)
        GameTooltip:Show()
    end)
    readyBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.readyBtn = readyBtn

    -- AFK button (red)
    local afkBtn = CreateFrame("Button", nil, frame)
    afkBtn:SetWidth(14)
    afkBtn:SetHeight(14)
    afkBtn:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    afkBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 4,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    afkBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText("AFK", 0.8, 0.2, 0.2)
        GameTooltip:Show()
    end)
    afkBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.afkBtn = afkBtn

    frame:Hide()
    return frame
end

function BenchTracker:SetRadioState(frame, state)
    -- state: "ready", "afk", or "none"
    if state == "ready" then
        frame.readyBtn:SetBackdropColor(0.1, 0.7, 0.1, 0.9)
        frame.readyBtn:SetBackdropBorderColor(0.1, 0.5, 0.1, 1)
        frame.afkBtn:SetBackdropColor(0.25, 0.25, 0.25, 0.6)
        frame.afkBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    elseif state == "afk" then
        frame.readyBtn:SetBackdropColor(0.25, 0.25, 0.25, 0.6)
        frame.readyBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        frame.afkBtn:SetBackdropColor(0.8, 0.1, 0.1, 0.9)
        frame.afkBtn:SetBackdropBorderColor(0.6, 0.1, 0.1, 1)
    else
        frame.readyBtn:SetBackdropColor(0.25, 0.25, 0.25, 0.6)
        frame.readyBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        frame.afkBtn:SetBackdropColor(0.25, 0.25, 0.25, 0.6)
        frame.afkBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end
end

----------------------------------------------------------------
-- AFK DISPLAY
----------------------------------------------------------------
function BenchTracker:UpdateAFKDisplay()
    if not mainFrame or not mainFrame:IsVisible() then return end
    if activeTab ~= "afk" then return end

    local isOfficer = BenchTracker:IsOfficer()
    local members = BenchTracker:GetRaidMembers()
    local scrollChild = mainFrame.afkScrollChild

    -- Show/hide buttons based on officer status
    if mainFrame.afkButton then
        if isOfficer then
            mainFrame.afkButton:Show()
        else
            mainFrame.afkButton:Hide()
        end
    end
    if mainFrame.logButton then
        if isOfficer then
            mainFrame.logButton:Show()
        else
            mainFrame.logButton:Hide()
        end
    end

    -- Hide all existing rows
    for i = 1, table.getn(playerFrames) do
        playerFrames[i]:Hide()
    end

    local yOffset = 0
    for i = 1, table.getn(members) do
        local member = members[i]

        if not playerFrames[i] then
            playerFrames[i] = BenchTracker:CreatePlayerRow(scrollChild, i)
        end

        local row = playerFrames[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row:Show()

        row.nameText:SetText(member.name)
        local englishClass = BenchTracker:GetEnglishClass(member.class)
        local color = CLASS_COLORS[englishClass] or {r = 0.5, g = 0.5, b = 0.5}
        row.nameText:SetTextColor(color.r, color.g, color.b, 1)

        row.playerName = member.name

        -- Determine current status
        local status = "none"
        if currentCheckData[member.name] then
            status = currentCheckData[member.name]
        end
        BenchTracker:SetRadioState(row, status)

        -- Button click handlers
        if isOfficer then
            row.readyBtn:SetScript("OnClick", function()
                local pName = this:GetParent().playerName
                currentCheckData[pName] = "ready"
                BenchTracker:UpdateAFKDisplay()
            end)
            row.afkBtn:SetScript("OnClick", function()
                local pName = this:GetParent().playerName
                currentCheckData[pName] = "afk"
                BenchTracker:UpdateAFKDisplay()
            end)
            row.readyBtn:EnableMouse(true)
            row.afkBtn:EnableMouse(true)
        else
            row.readyBtn:EnableMouse(false)
            row.afkBtn:EnableMouse(false)
        end

        yOffset = yOffset - 17
    end

    local contentHeight = table.getn(members) * 17 + 10
    scrollChild:SetHeight(contentHeight)
    if mainFrame.afkScrollFrame then
        mainFrame.afkScrollFrame:UpdateScrollChildRect()
    end
end

----------------------------------------------------------------
-- AFK CHECK LOGIC
----------------------------------------------------------------
function BenchTracker:StartAFKCheck()
    if not BenchTracker:IsOfficer() then return end
    if isListening then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000BenchTracker: An AFK check is already in progress!|r")
        return
    end

    -- Reset status for current raid members
    currentCheckData = {}
    local members = BenchTracker:GetRaidMembers()
    for i = 1, table.getn(members) do
        currentCheckData[members[i].name] = "afk"
    end

    checkCounter = checkCounter + 1
    isListening = true
    listenElapsed = 0

    -- Send announcements
    SendChatMessage("BENCH GROUP: Type in [Guild Chat] or in [#General on Discord] within 30sec if you're here.", "GUILD")
    SendChatMessage("BENCH GROUP: Type in [Guild Chat] or in [#General on Discord] within 30sec if you're here.", "RAID_WARNING")

    -- Trigger /pull 30 (BigWigs Pulltimer)
    if SlashCmdList["BWPT_SHORTHAND"] then
        SlashCmdList["BWPT_SHORTHAND"]("30")
    end

    -- Start 30 second timer
    BenchTracker:StartListenTimer()

    BenchTracker:UpdateAFKDisplay()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00BenchTracker: AFK check started! Listening for 30 seconds...|r")
end

function BenchTracker:StartListenTimer()
    if not listenTimer then
        listenTimer = CreateFrame("Frame", "BenchListenTimer", UIParent)
    end
    listenElapsed = 0
    listenTimer:SetScript("OnUpdate", function()
        listenElapsed = listenElapsed + arg1
        if listenElapsed >= 30 then
            BenchTracker:StopListening()
        end
    end)
    listenTimer:Show()
end

function BenchTracker:StopListening()
    isListening = false
    if listenTimer then
        listenTimer:SetScript("OnUpdate", nil)
        listenTimer:Hide()
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00BenchTracker: AFK check listening ended. Review results and click 'Add to Log' when ready.|r")
    BenchTracker:UpdateAFKDisplay()
end

function BenchTracker:OnChatMessage(playerName)
    if not isListening then return end

    -- Check if this player is in our bench raid
    if currentCheckData[playerName] then
        currentCheckData[playerName] = "ready"
        BenchTracker:UpdateAFKDisplay()
    end
end

----------------------------------------------------------------
-- LOGGING
----------------------------------------------------------------
function BenchTracker:LogAFKCheck()
    local timestamp = BenchTracker:GetTimestamp()
    local readyList = {}
    local afkList = {}

    for name, status in pairs(currentCheckData) do
        if status == "ready" then
            table.insert(readyList, name)
        else
            table.insert(afkList, name)
        end
    end

    table.sort(readyList)
    table.sort(afkList)

    local entry = {
        entryType = "afk",
        timestamp = timestamp,
        checkNum = checkCounter,
        ready = readyList,
        afk = afkList
    }
    table.insert(logEntries, entry)
    BenchTrackerDB.log = logEntries
    BenchTrackerDB.checkCounter = checkCounter

    if activeTab == "log" then
        BenchTracker:UpdateLogDisplay()
    end
end

function BenchTracker:ManualLogAFKCheck()
    if not BenchTracker:IsOfficer() then return end

    -- Check if there is any data to log
    local hasData = false
    for name, status in pairs(currentCheckData) do
        hasData = true
        break
    end
    if not hasData then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000BenchTracker: Nothing to log. Run an AFK check first.|r")
        return
    end

    BenchTracker:LogAFKCheck()

    -- Reset radio buttons
    currentCheckData = {}

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00BenchTracker: AFK check results added to log.|r")
    BenchTracker:UpdateAFKDisplay()
    if activeTab == "log" then
        BenchTracker:UpdateLogDisplay()
    end
end

function BenchTracker:LogEPAward(epAmount)
    local timestamp = BenchTracker:GetTimestamp()
    local members = BenchTracker:GetRaidMembers()
    local nameList = {}
    for i = 1, table.getn(members) do
        table.insert(nameList, members[i].name)
    end
    table.sort(nameList)

    local entry = {
        entryType = "ep",
        timestamp = timestamp,
        ep = epAmount,
        players = nameList
    }
    table.insert(logEntries, entry)
    BenchTrackerDB.log = logEntries

    if activeTab == "log" then
        BenchTracker:UpdateLogDisplay()
    end
end

----------------------------------------------------------------
-- LOG DISPLAY
----------------------------------------------------------------
local logFontStrings = {}

function BenchTracker:ClearLog()
    if not BenchTracker:IsOfficer() then return end
    logEntries = {}
    checkCounter = 0
    BenchTrackerDB.log = logEntries
    BenchTrackerDB.checkCounter = 0
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00BenchTracker: Log cleared.|r")
    BenchTracker:UpdateLogDisplay()
end

function BenchTracker:UpdateLogDisplay()
    if not mainFrame or not mainFrame:IsVisible() then return end
    if activeTab ~= "log" then return end

    -- Show/hide Clear Log button based on officer status
    if mainFrame.clearLogButton then
        if BenchTracker:IsOfficer() then
            mainFrame.clearLogButton:Show()
        else
            mainFrame.clearLogButton:Hide()
        end
    end

    local scrollChild = mainFrame.logScrollChild

    -- Hide all existing log text
    for i = 1, table.getn(logFontStrings) do
        logFontStrings[i]:Hide()
    end

    local yOffset = 0
    local fsIndex = 0

    local function getFS()
        fsIndex = fsIndex + 1
        if not logFontStrings[fsIndex] then
            logFontStrings[fsIndex] = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        local fs = logFontStrings[fsIndex]
        fs:ClearAllPoints()
        fs:Show()
        return fs
    end

    -- Render entries in reverse order (newest first)
    local numEntries = table.getn(logEntries)
    for idx = numEntries, 1, -1 do
        local entry = logEntries[idx]

        if entry.entryType == "afk" then
            -- Header
            local header = getFS()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yOffset)
            header:SetWidth(240)
            header:SetJustifyH("LEFT")
            header:SetText("|cFFFFCC00" .. entry.timestamp .. " AFK Check #" .. entry.checkNum .. "|r")
            header:SetTextColor(1, 0.8, 0, 1)
            yOffset = yOffset - 12

            -- Ready list
            if table.getn(entry.ready) > 0 then
                local readyLabel = getFS()
                readyLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, yOffset)
                readyLabel:SetWidth(236)
                readyLabel:SetJustifyH("LEFT")
                local readyStr = "|cFF00CC00Ready:|r "
                for i = 1, table.getn(entry.ready) do
                    if i > 1 then readyStr = readyStr .. ", " end
                    readyStr = readyStr .. entry.ready[i]
                end
                readyLabel:SetText(readyStr)
                readyLabel:SetTextColor(0.8, 0.8, 0.8, 1)
                yOffset = yOffset - 12
            end

            -- AFK list
            if table.getn(entry.afk) > 0 then
                local afkLabel = getFS()
                afkLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, yOffset)
                afkLabel:SetWidth(236)
                afkLabel:SetJustifyH("LEFT")
                local afkStr = "|cFFCC0000AFK:|r "
                for i = 1, table.getn(entry.afk) do
                    if i > 1 then afkStr = afkStr .. ", " end
                    afkStr = afkStr .. entry.afk[i]
                end
                afkLabel:SetText(afkStr)
                afkLabel:SetTextColor(0.8, 0.8, 0.8, 1)
                yOffset = yOffset - 12
            end

            yOffset = yOffset - 4

        elseif entry.entryType == "ep" then
            -- EP award header
            local header = getFS()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yOffset)
            header:SetWidth(240)
            header:SetJustifyH("LEFT")
            header:SetText("|cFF33BBFF" .. entry.timestamp .. " EP Award: +" .. entry.ep .. " EP|r")
            header:SetTextColor(0.2, 0.7, 1, 1)
            yOffset = yOffset - 12

            -- Player list
            local playerLabel = getFS()
            playerLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 6, yOffset)
            playerLabel:SetWidth(236)
            playerLabel:SetJustifyH("LEFT")
            local pStr = ""
            for i = 1, table.getn(entry.players) do
                if i > 1 then pStr = pStr .. ", " end
                pStr = pStr .. entry.players[i]
            end
            playerLabel:SetText(pStr)
            playerLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            yOffset = yOffset - 12

            yOffset = yOffset - 4
        end
    end

    if numEntries == 0 then
        local emptyMsg = getFS()
        emptyMsg:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, yOffset)
        emptyMsg:SetWidth(240)
        emptyMsg:SetJustifyH("LEFT")
        emptyMsg:SetText("|cFF666666No log entries yet.|r")
        emptyMsg:SetTextColor(0.4, 0.4, 0.4, 1)
        yOffset = yOffset - 14
    end

    local contentHeight = math.abs(yOffset) + 10
    scrollChild:SetHeight(contentHeight)
    if mainFrame.logScrollFrame then
        mainFrame.logScrollFrame:UpdateScrollChildRect()
    end
end

----------------------------------------------------------------
-- SLASH COMMAND
----------------------------------------------------------------
SLASH_BENCH1 = "/bench"
SlashCmdList["BENCH"] = function(msg)
    if not mainFrame then
        BenchTracker:CreateMainFrame()
    end

    if mainFrame:IsVisible() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        BenchTracker:SwitchTab(activeTab)
    end
end

----------------------------------------------------------------
-- EVENT HANDLING
----------------------------------------------------------------
local benchEventFrame = CreateFrame("Frame", "BenchEventFrame", UIParent)
benchEventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
benchEventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
benchEventFrame:RegisterEvent("CHAT_MSG_GUILD")
benchEventFrame:RegisterEvent("CHAT_MSG_RAID")
benchEventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
benchEventFrame:RegisterEvent("ADDON_LOADED")

benchEventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "shootyepgp" then
        -- Load saved log data
        if not BenchTrackerDB then
            BenchTrackerDB = {}
        end
        if BenchTrackerDB.log then
            logEntries = BenchTrackerDB.log
        else
            BenchTrackerDB.log = {}
        end
        if BenchTrackerDB.checkCounter then
            checkCounter = BenchTrackerDB.checkCounter
        else
            BenchTrackerDB.checkCounter = 0
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00BenchTracker loaded! Type /bench to open.|r")

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if mainFrame and mainFrame:IsVisible() and activeTab == "afk" then
            BenchTracker:UpdateAFKDisplay()
        end

    elseif event == "CHAT_MSG_GUILD" then
        if isListening and arg1 and arg2 then
            BenchTracker:OnChatMessage(arg2)
        end

    elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        if isListening and arg1 and arg2 then
            BenchTracker:OnChatMessage(arg2)
        end
    end
end)

----------------------------------------------------------------
-- HOOK: EP AWARDS
----------------------------------------------------------------
local original_award_raid_ep = nil
local original_award_reserve_ep = nil

local epHookFrame = CreateFrame("Frame", "BenchEPHookFrame", UIParent)
epHookFrame:RegisterEvent("ADDON_LOADED")
epHookFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "shootyepgp" then
        -- Hook after sepgp is available
        if sepgp and sepgp.award_reserve_ep then
            original_award_reserve_ep = sepgp.award_reserve_ep
            sepgp.award_reserve_ep = function(self, ep)
                original_award_reserve_ep(self, ep)
                BenchTracker:LogEPAward(ep)
            end
        end
        if sepgp and sepgp.award_raid_ep then
            original_award_raid_ep = sepgp.award_raid_ep
            sepgp.award_raid_ep = function(self, ep)
                original_award_raid_ep(self, ep)
                BenchTracker:LogEPAward(ep)
            end
        end
    end
end)
