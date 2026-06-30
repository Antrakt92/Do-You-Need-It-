local addonName = ...
local Core = _G.DoYouNeedItCore

local Addon = {
    name = addonName or "DoYouNeedIt",
    rows = {},
    rowFrames = {},
    pendingInspect = {},
    selectedHistoryIndex = nil,
    selectedView = "current",
    itemRetryCount = {},
}

local SetAutoWhisper
local SetDelay
local CreateUI

local issecretvalue = _G.issecretvalue or function()
    return false
end

local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 340
local ROW_WIDTH = 470
local ROW_HEIGHT = 30
local ROW_START_Y = -72
local ROW_STRIDE = 34
local MAX_VISIBLE_ROWS = 6
local MAX_ITEM_RETRIES = 5
local ITEM_RETRY_DELAY = 0.7
local UNKNOWN_EQUIPPED = "Equipped: unknown"
local WHISPER_TEMPLATE = "Hey, do you need %s?"

local EQUIP_LOC_SLOTS = {
    INVTYPE_HEAD = { "HeadSlot" },
    INVTYPE_NECK = { "NeckSlot" },
    INVTYPE_SHOULDER = { "ShoulderSlot" },
    INVTYPE_CHEST = { "ChestSlot" },
    INVTYPE_ROBE = { "ChestSlot" },
    INVTYPE_WAIST = { "WaistSlot" },
    INVTYPE_LEGS = { "LegsSlot" },
    INVTYPE_FEET = { "FeetSlot" },
    INVTYPE_WRIST = { "WristSlot" },
    INVTYPE_HAND = { "HandsSlot" },
    INVTYPE_FINGER = { "Finger0Slot", "Finger1Slot" },
    INVTYPE_TRINKET = { "Trinket0Slot", "Trinket1Slot" },
    INVTYPE_CLOAK = { "BackSlot" },
    INVTYPE_WEAPON = { "MainHandSlot", "SecondaryHandSlot" },
    INVTYPE_SHIELD = { "SecondaryHandSlot" },
    INVTYPE_2HWEAPON = { "MainHandSlot" },
    INVTYPE_WEAPONMAINHAND = { "MainHandSlot" },
    INVTYPE_WEAPONOFFHAND = { "SecondaryHandSlot" },
    INVTYPE_HOLDABLE = { "SecondaryHandSlot" },
    INVTYPE_RANGED = { "RangedSlot" },
    INVTYPE_RANGEDRIGHT = { "RangedSlot" },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7ccfffDo You Need It?|r " .. tostring(message))
end

local function IsSecret(value)
    local ok, secret = pcall(issecretvalue, value)
    return not ok or secret == true
end

local function CleanString(value)
    if IsSecret(value) then
        return nil
    end
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function CleanBoolean(value)
    if IsSecret(value) then
        return nil
    end
    local okTrue, isTrue = pcall(function()
        return value == true
    end)
    if okTrue and isTrue then
        return true
    end
    local okFalse, isFalse = pcall(function()
        return value == false
    end)
    if okFalse and isFalse then
        return false
    end
    return nil
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f, g, h, i, j, k, l, m, n
end

local function Now()
    if type(GetServerTime) == "function" then
        return GetServerTime()
    end
    return time()
end

local function UnitExistsClean(unit)
    return CleanBoolean(SafeCall(UnitExists, unit)) == true
end

local function SafeUnitName(unit)
    local name, realm = SafeCall(UnitName, unit)
    name = CleanString(name)
    realm = CleanString(realm)
    if name == nil then
        return nil
    end
    if realm and realm ~= "" then
        return name .. "-" .. realm, name
    end
    return name, name
end

local function SafeUnitGUID(unit)
    local guid = SafeCall(UnitGUID, unit)
    return CleanString(guid)
end

local function SafePlayerName()
    local fullName, shortName = SafeUnitName("player")
    return fullName or shortName or UnitName("player")
end

local function SafeInstanceName()
    local name = SafeCall(GetInstanceInfo)
    return CleanString(name) or "Unknown Instance"
end

local function ExtractItemLink(message)
    message = CleanString(message)
    if message == nil then
        return nil
    end
    return message:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
        or message:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
end

local function BuildRoster()
    Addon.roster = {}

    local function addUnit(unit)
        if not UnitExistsClean(unit) then
            return
        end
        local fullName, shortName = SafeUnitName(unit)
        if fullName then
            Addon.roster[fullName] = unit
        end
        if shortName then
            Addon.roster[shortName] = unit
        end
    end

    addUnit("player")
    for index = 1, 4 do
        addUnit("party" .. index)
    end
    for index = 1, 40 do
        addUnit("raid" .. index)
    end
end

local function ResolveUnitForName(name)
    if not Addon.roster then
        BuildRoster()
    end
    return name and Addon.roster[name] or nil
end

local function FindLooterFromMessage(message)
    message = CleanString(message)
    if message == nil then
        return nil
    end
    if not Addon.roster then
        BuildRoster()
    end
    for name in pairs(Addon.roster) do
        if name ~= SafePlayerName() and message:find(name, 1, true) then
            return name
        end
    end
    return nil
end

local function GetItemInfoCompat(itemLink)
    if C_Item and type(C_Item.GetItemInfo) == "function" then
        return SafeCall(C_Item.GetItemInfo, itemLink)
    end
    return SafeCall(GetItemInfo, itemLink)
end

local function GetItemInfoInstantCompat(itemLink)
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        return SafeCall(C_Item.GetItemInfoInstant, itemLink)
    end
    if type(GetItemInfoInstant) == "function" then
        return SafeCall(GetItemInfoInstant, itemLink)
    end
    return nil
end

local function ReadItemMetadata(itemLink)
    local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = GetItemInfoInstantCompat(itemLink)
    local itemName, resolvedLink, quality, itemLevel, requiredLevel, itemTypeText, itemSubTypeText, stackCount, equipLoc
    local itemIcon, sellPrice, detailedClassID, detailedSubclassID, bindType, expansionID, setID, isCraftingReagent =
        GetItemInfoCompat(itemLink)

    itemName = CleanString(itemName)
    resolvedLink = CleanString(resolvedLink) or itemLink
    itemEquipLoc = CleanString(itemEquipLoc)
    equipLoc = CleanString(equipLoc) or itemEquipLoc

    if itemID == nil or quality == nil or equipLoc == nil then
        return nil
    end

    return {
        itemID = itemID,
        name = itemName,
        link = resolvedLink,
        quality = quality,
        itemLevel = itemLevel,
        classID = detailedClassID or classID,
        subclassID = detailedSubclassID or subclassID,
        equipLoc = equipLoc,
        bindType = bindType,
        isCraftingReagent = isCraftingReagent == true,
    }
end

local function FormatEquippedText(unit, equipLoc)
    local slotNames = EQUIP_LOC_SLOTS[equipLoc]
    if not slotNames then
        return UNKNOWN_EQUIPPED
    end

    local links = {}
    for index = 1, #slotNames do
        local slotID = GetInventorySlotInfo(slotNames[index])
        if slotID then
            local link = SafeCall(GetInventoryItemLink, unit, slotID)
            link = CleanString(link)
            if link then
                links[#links + 1] = link
            end
        end
    end

    if #links == 0 then
        return UNKNOWN_EQUIPPED
    end
    return "Equipped: " .. table.concat(links, " / ")
end

local function CanInspectClean(unit)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    local result = SafeCall(CanInspect, unit, false)
    return CleanBoolean(result) == true
end

local function RefreshRows()
    if not Addon.frame then
        return
    end

    local rows = Addon.state.currentRows
    if Addon.selectedView == "session" then
        rows = Addon.state.sessionRows
    elseif Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        rows = group and group.rows or {}
    end

    local title = "Current"
    if Addon.selectedView == "session" then
        title = "This Session"
    elseif Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        title = group and group.title or "History"
    end
    Addon.historyButton:SetText(title)

    local autoText = Addon.state.settings.autoWhisper and ("Auto: " .. Addon.state.settings.autoDelay .. "s") or "Auto: off"
    Addon.autoStatus:SetText(autoText)
    if Addon.autoCheck then
        Addon.autoCheck:SetChecked(Addon.state.settings.autoWhisper == true)
    end
    if Addon.delaySlider then
        Addon.updatingControls = true
        Addon.delaySlider:SetValue(Addon.state.settings.autoDelay)
        Addon.updatingControls = false
    end
    if Addon.delayValue then
        Addon.delayValue:SetText(Addon.state.settings.autoDelay .. "s")
    end

    for index = 1, MAX_VISIBLE_ROWS do
        local rowFrame = Addon.rowFrames[index]
        local row = rows[index]
        if row then
            rowFrame.row = row
            rowFrame.looter:SetText(row.looter or "?")
            rowFrame.drop:SetText(row.itemLink or "")
            rowFrame.equipped:SetText(row.equippedText or UNKNOWN_EQUIPPED)
            rowFrame.status:SetText(row.statusText or row.reason or "candidate")
            if Addon.selectedView == "history" then
                rowFrame.whisper:Disable()
                rowFrame.whisper:SetText("History")
            else
                rowFrame.whisper:Enable()
                rowFrame.whisper:SetText(row.manualWhispered and "Sent" or "Ask")
            end
            rowFrame:Show()
        else
            rowFrame.row = nil
            rowFrame:Hide()
        end
    end

    if #rows == 0 then
        Addon.emptyText:SetText("No tradeable gear drops in this view.")
        Addon.emptyText:Show()
    else
        Addon.emptyText:Hide()
    end
end

local function SaveDB()
    DoYouNeedItDB = DoYouNeedItDB or {}
    DoYouNeedItDB.settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    DoYouNeedItDB.history = Addon.state and Addon.state.history or {}
end

local function SendWhisper(row, isAuto)
    if not row or not row.looter or not row.itemLink then
        return
    end

    row.pendingAutoWhisper = false
    row.autoToken = nil
    local message = string.format(WHISPER_TEMPLATE, row.itemLink)
    local target = row.looter

    C_Timer.After(0, function()
        if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
            C_ChatInfo.SendChatMessage(message, "WHISPER", nil, target)
        else
            SendChatMessage(message, "WHISPER", nil, target)
        end
    end)

    if isAuto then
        row.autoWhispered = true
        row.statusText = "auto sent"
    else
        row.manualWhispered = true
        row.statusText = "sent"
    end
    RefreshRows()
end

local function CancelPendingAuto(row)
    if row then
        row.pendingAutoWhisper = false
        row.autoToken = nil
        if row.statusText and row.statusText:find("auto in", 1, true) then
            row.statusText = "candidate"
        end
    end
end

local function ScheduleAutoWhisper(row)
    local decision = Core.GetAutoWhisperDecision(Addon.state.settings, row)
    if not decision.shouldSchedule then
        return
    end

    local token = {}
    row.pendingAutoWhisper = true
    row.autoToken = token
    row.statusText = "auto in " .. tostring(decision.delay) .. "s"
    RefreshRows()

    C_Timer.After(decision.delay, function()
        if row.autoToken ~= token or not row.pendingAutoWhisper then
            return
        end
        if Addon.state.settings.autoWhisper ~= true or row.unsafe == true then
            CancelPendingAuto(row)
            RefreshRows()
            return
        end
        SendWhisper(row, true)
    end)
end

local function RequestInspectForRow(row)
    local unit = ResolveUnitForName(row.looter)
    if not unit or not CanInspectClean(unit) then
        row.equippedText = UNKNOWN_EQUIPPED
        return
    end

    row.equippedText = FormatEquippedText(unit, row.equipLoc)
    if row.equippedText ~= UNKNOWN_EQUIPPED then
        return
    end

    local guid = SafeUnitGUID(unit)
    if not guid then
        return
    end
    Addon.pendingInspect[guid] = Addon.pendingInspect[guid] or {}
    table.insert(Addon.pendingInspect[guid], row)
    SafeCall(NotifyInspect, unit)
end

local function AddTradeCandidate(looter, itemLink, metadata)
    local playerName = SafePlayerName()
    local classification = DoYouNeedItCore.ClassifyTradeCandidate(metadata, looter, playerName, Addon.state.settings)
    if not classification.visible then
        return false
    end

    local row = Core.AddVisibleRow(Addon.state, {
        looter = looter,
        itemLink = metadata.link or itemLink,
        equipLoc = metadata.equipLoc,
        itemID = metadata.itemID,
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = Addon.currentEncounterName,
        timestamp = Now(),
        reason = "trade candidate",
        statusText = "candidate",
        equippedText = UNKNOWN_EQUIPPED,
        unsafe = false,
    })
    if not row then
        return false
    end

    RequestInspectForRow(row)
    ScheduleAutoWhisper(row)
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    RefreshRows()
    if DoYouNeedItCore.ShouldAutoShowWindow(row) then
        CreateUI()
        Addon.frame:Show()
    end
    return true
end

local function RetryItemLater(looter, itemLink)
    local count = (Addon.itemRetryCount[itemLink] or 0) + 1
    Addon.itemRetryCount[itemLink] = count
    if count > MAX_ITEM_RETRIES then
        return
    end
    C_Timer.After(ITEM_RETRY_DELAY, function()
        local metadata = ReadItemMetadata(itemLink)
        if metadata then
            Addon.itemRetryCount[itemLink] = nil
            AddTradeCandidate(looter, itemLink, metadata)
        end
    end)
end

local function HandleLootMessage(message)
    local itemLink = ExtractItemLink(message)
    if not itemLink then
        return
    end

    local looter = FindLooterFromMessage(message)
    if not looter then
        return
    end

    local metadata = ReadItemMetadata(itemLink)
    if not metadata then
        RetryItemLater(looter, itemLink)
        return
    end

    AddTradeCandidate(looter, itemLink, metadata)
end

local function CompleteCurrentGroup(encounterName)
    if not Addon.state or #Addon.state.currentRows == 0 then
        return
    end
    Core.CompleteCurrentGroup(Addon.state, {
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = encounterName or Addon.currentEncounterName,
        startedAt = Addon.currentEncounterStartedAt,
        endedAt = Now(),
    })
    Addon.selectedView = "history"
    Addon.selectedHistoryIndex = 1
    SaveDB()
    RefreshRows()
end

local function SelectView(view, historyIndex)
    Addon.selectedView = view
    Addon.selectedHistoryIndex = historyIndex
    RefreshRows()
end

local function CycleHistoryView()
    if Addon.selectedView == "current" then
        SelectView("session")
    elseif Addon.selectedView == "session" and #Addon.state.history > 0 then
        SelectView("history", 1)
    else
        SelectView("current")
    end
end

local function OpenHistoryMenu(owner)
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
            rootDescription:CreateButton("Current", function()
                SelectView("current")
            end)
            rootDescription:CreateButton("This Session", function()
                SelectView("session")
            end)
            for index = 1, #Addon.state.history do
                local group = Addon.state.history[index]
                rootDescription:CreateButton(group.title or ("History " .. index), function()
                    SelectView("history", index)
                end)
            end
        end)
    else
        CycleHistoryView()
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, ROW_START_Y - ((index - 1) * ROW_STRIDE))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.08, 0.08, 0.09, index % 2 == 0 and 0.75 or 0.55)

    row.looter = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.looter:SetPoint("LEFT", row, "LEFT", 8, 8)
    row.looter:SetWidth(82)
    row.looter:SetJustifyH("LEFT")

    row.drop = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.drop:SetPoint("LEFT", row.looter, "RIGHT", 6, 0)
    row.drop:SetWidth(155)
    row.drop:SetJustifyH("LEFT")

    row.equipped = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.equipped:SetPoint("LEFT", row.drop, "RIGHT", 8, 0)
    row.equipped:SetWidth(135)
    row.equipped:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetPoint("TOPLEFT", row.looter, "BOTTOMLEFT", 0, -2)
    row.status:SetWidth(380)
    row.status:SetJustifyH("LEFT")

    row.whisper = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.whisper:SetSize(48, 20)
    row.whisper:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.whisper:SetText("Ask")
    row.whisper:SetScript("OnClick", function(button)
        local data = button:GetParent().row
        if data then
            CancelPendingAuto(data)
            SendWhisper(data, false)
        end
    end)

    row:Hide()
    return row
end

CreateUI = function()
    if Addon.frame then
        return
    end

    local frame = CreateFrame("Frame", "DoYouNeedItFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    frame.title:SetText("Do You Need It?")

    frame.historyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.historyButton:SetSize(160, 22)
    frame.historyButton:SetPoint("LEFT", frame.title, "RIGHT", 12, 0)
    frame.historyButton:SetText("Current")
    frame.historyButton:SetScript("OnClick", function(button)
        OpenHistoryMenu(button)
    end)
    Addon.historyButton = frame.historyButton

    frame.autoStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.autoStatus:SetPoint("LEFT", frame.historyButton, "RIGHT", 10, 0)
    frame.autoStatus:SetWidth(62)
    frame.autoStatus:SetJustifyH("LEFT")
    Addon.autoStatus = frame.autoStatus

    frame.autoCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.autoCheck:SetSize(24, 24)
    frame.autoCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -42)
    frame.autoCheck:SetScript("OnClick", function(check)
        SetAutoWhisper(check:GetChecked() == true)
    end)
    Addon.autoCheck = frame.autoCheck

    frame.autoCheckLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.autoCheckLabel:SetPoint("LEFT", frame.autoCheck, "RIGHT", 2, 0)
    frame.autoCheckLabel:SetText("Auto")

    frame.delayLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.delayLabel:SetPoint("LEFT", frame.autoCheckLabel, "RIGHT", 14, 0)
    frame.delayLabel:SetText("Delay")

    frame.delaySlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    frame.delaySlider:SetPoint("LEFT", frame.delayLabel, "RIGHT", 10, 0)
    frame.delaySlider:SetSize(135, 18)
    frame.delaySlider:SetMinMaxValues(3, 30)
    frame.delaySlider:SetValueStep(1)
    if frame.delaySlider.SetObeyStepOnDrag then
        frame.delaySlider:SetObeyStepOnDrag(true)
    end
    frame.delaySlider:SetScript("OnValueChanged", function(_, value)
        if Addon.updatingControls then
            return
        end
        SetDelay(math.floor((tonumber(value) or 10) + 0.5), true)
    end)
    Addon.delaySlider = frame.delaySlider

    frame.delayValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.delayValue:SetPoint("LEFT", frame.delaySlider, "RIGHT", 10, 0)
    frame.delayValue:SetWidth(36)
    frame.delayValue:SetJustifyH("LEFT")
    Addon.delayValue = frame.delayValue

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.emptyText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.emptyText:SetText("No tradeable gear drops in this view.")
    Addon.emptyText = frame.emptyText

    for index = 1, MAX_VISIBLE_ROWS do
        Addon.rowFrames[index] = CreateRow(frame, index)
    end

    Addon.frame = frame
    frame:Hide()
    RefreshRows()
end

local function CancelAllPendingAuto()
    for index = 1, #Addon.state.currentRows do
        CancelPendingAuto(Addon.state.currentRows[index])
    end
    for index = 1, #Addon.state.sessionRows do
        CancelPendingAuto(Addon.state.sessionRows[index])
    end
end

SetAutoWhisper = function(enabled)
    Addon.state.settings.autoWhisper = enabled == true
    if not Addon.state.settings.autoWhisper then
        CancelAllPendingAuto()
    end
    SaveDB()
    RefreshRows()
    Print("auto whisper " .. (Addon.state.settings.autoWhisper and "enabled" or "disabled"))
end

SetDelay = function(value, quiet)
    local old = Addon.state.settings.autoDelay
    Addon.state.settings.autoDelay = tonumber(value) or old
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    RefreshRows()
    if quiet then
        return
    end
    if Addon.state.settings.autoDelay ~= tonumber(value) then
        Print("delay must be between " .. Addon.state.settings.minDelay .. " and " .. Addon.state.settings.maxDelay .. " seconds")
    else
        Print("auto whisper delay set to " .. Addon.state.settings.autoDelay .. " seconds")
    end
end

local function HandleSlash(message)
    message = CleanString(message) or ""
    local command, rest = message:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" then
        CreateUI()
        if Addon.frame:IsShown() then
            Addon.frame:Hide()
        else
            Addon.frame:Show()
            RefreshRows()
        end
    elseif command == "auto" then
        rest = string.lower(rest or "")
        if rest == "on" then
            SetAutoWhisper(true)
        elseif rest == "off" then
            SetAutoWhisper(false)
        else
            Print("usage: /dyni auto on|off")
        end
    elseif command == "delay" then
        SetDelay(rest)
    elseif command == "clear" then
        CancelAllPendingAuto()
        Addon.state.currentRows = {}
        Addon.state.sessionRows = {}
        Addon.selectedView = "current"
        Addon.selectedHistoryIndex = nil
        SaveDB()
        RefreshRows()
        Print("current session rows cleared; saved history kept")
    elseif command == "history" then
        CycleHistoryView()
        CreateUI()
        Addon.frame:Show()
    elseif command == "status" then
        Print("auto=" .. tostring(Addon.state.settings.autoWhisper)
            .. ", delay=" .. tostring(Addon.state.settings.autoDelay)
            .. "s, saved groups=" .. tostring(#Addon.state.history))
    else
        Print("commands: /dyni, /dyni auto on|off, /dyni delay <seconds>, /dyni clear, /dyni history, /dyni status")
    end
end

local function Initialize()
    DoYouNeedItDB = DoYouNeedItDB or {}
    local settings = Core.NormalizeSettings(DoYouNeedItDB.settings or {})
    Addon.state = Core.CreateState(settings)
    Addon.state.history = type(DoYouNeedItDB.history) == "table" and DoYouNeedItDB.history or {}
    while #Addon.state.history > Addon.state.settings.maxHistoryGroups do
        table.remove(Addon.state.history)
    end
    Addon.currentInstanceName = SafeInstanceName()
    BuildRoster()
    CreateUI()

    SLASH_DOYOUNEEDIT1 = "/dyni"
    SlashCmdList.DOYOUNEEDIT = HandleSlash
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("INSPECT_READY")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == Addon.name then
            Initialize()
        end
    elseif event == "PLAYER_LOGOUT" then
        if Addon.state and #Addon.state.currentRows > 0 then
            CompleteCurrentGroup(Addon.currentEncounterName)
        end
        SaveDB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local instanceName = SafeInstanceName()
        if Addon.currentInstanceName and Addon.currentInstanceName ~= instanceName and Addon.state and #Addon.state.currentRows > 0 then
            CompleteCurrentGroup(Addon.currentEncounterName)
        end
        Addon.currentInstanceName = instanceName
        BuildRoster()
    elseif event == "GROUP_ROSTER_UPDATE" then
        BuildRoster()
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if Addon.state and #Addon.state.currentRows > 0 then
            CompleteCurrentGroup(Addon.currentEncounterName)
        end
        Addon.currentEncounterID = encounterID
        Addon.currentEncounterName = CleanString(encounterName)
        Addon.currentEncounterStartedAt = Now()
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        Addon.currentEncounterID = encounterID or Addon.currentEncounterID
        Addon.currentEncounterName = CleanString(encounterName) or Addon.currentEncounterName
        CompleteCurrentGroup(Addon.currentEncounterName)
        Addon.currentEncounterID = nil
        Addon.currentEncounterName = nil
        Addon.currentEncounterStartedAt = nil
    elseif event == "CHAT_MSG_LOOT" then
        local message = ...
        HandleLootMessage(message)
    elseif event == "INSPECT_READY" then
        local guid = ...
        guid = CleanString(guid)
        if guid and Addon.pendingInspect[guid] then
            local rows = Addon.pendingInspect[guid]
            Addon.pendingInspect[guid] = nil
            for index = 1, #rows do
                local row = rows[index]
                local unit = ResolveUnitForName(row.looter)
                if unit then
                    row.equippedText = FormatEquippedText(unit, row.equipLoc)
                end
            end
            if ClearInspectPlayer then
                SafeCall(ClearInspectPlayer)
            end
            RefreshRows()
        end
    end
end)
