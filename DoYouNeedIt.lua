local addonName = ...
local Core = _G.DoYouNeedItCore

local Addon = {
    name = addonName or "DoYouNeedIt",
    rows = {},
    rowFrames = {},
    pendingInspect = {},
    pendingEquipmentScan = {},
    equipmentCache = {},
    equipmentScanQueue = {},
    equipmentScanActive = nil,
    equipmentScanScheduled = false,
    selectedHistoryIndex = nil,
    selectedView = "current",
    selectedTab = "askable",
    itemRetryCount = {},
}

local SetAutoWhisper
local SetDelay
local CreateUI
local RequestInspectForRow

local issecretvalue = _G.issecretvalue or function()
    return false
end

local WINDOW_WIDTH = 460
local WINDOW_HEIGHT = 310
local ROW_WIDTH = 430
local ROW_HEIGHT = 30
local ROW_START_Y = -72
local ROW_STRIDE = 34
local MAX_VISIBLE_ROWS = 5
local MAX_ITEM_RETRIES = 5
local ITEM_RETRY_DELAY = 0.7
local MAX_INSPECT_RETRIES = 8
local INSPECT_RETRY_DELAY = 0.8
local MAX_EQUIPMENT_SCAN_ATTEMPTS = 2
local EQUIPMENT_SCAN_DELAY = 1.1
local EQUIPMENT_SCAN_TIMEOUT = 2.5
local MAX_DIAGNOSTICS = 20
local ENCOUNTER_LOOT_GRACE = 120
local UNKNOWN_EQUIPPED = "Equipped: unknown"
local EQUIPPED_PENDING = "Equipped: checking..."
local EQUIPPED_UNAVAILABLE = "Equipped: unavailable"
local CACHED_EQUIPPED_PREFIX = "Cached: "
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

local PREFERRED_ARMOR_SUBCLASS_BY_CLASS = {
    DEATHKNIGHT = 4,
    DEMONHUNTER = 2,
    DRUID = 2,
    EVOKER = 3,
    HUNTER = 3,
    MAGE = 1,
    MONK = 2,
    PALADIN = 4,
    PRIEST = 1,
    ROGUE = 2,
    SHAMAN = 3,
    WARLOCK = 1,
    WARRIOR = 4,
}

local ARMOR_SPECIALIZATION_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7ccfffDo You Need It?|r " .. tostring(message))
end

local function Debug(message)
    if Addon.state and Addon.state.settings and Addon.state.settings.debug == true then
        Print("debug: " .. tostring(message))
    end
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

local function FirstItemLink(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    return text:match("(|c%x%x%x%x%x%x%x%x|Hitem:.-|h%[.-%]|h|r)")
end

local function ShowItemTooltip(owner, itemLink)
    if not owner or type(itemLink) ~= "string" or itemLink == "" or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(itemLink)
    GameTooltip:Show()
end

local function HideItemTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function OpenItemLink(owner, itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return
    end
    if HandleModifiedItemClick and HandleModifiedItemClick(itemLink) then
        return
    end
    ShowItemTooltip(owner, itemLink)
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

local function CleanNumber(value)
    if IsSecret(value) then
        return nil
    end
    local ok, number = pcall(tonumber, value)
    if ok then
        return number
    end
    return nil
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t
end

local function Now()
    if type(GetServerTime) == "function" then
        return GetServerTime()
    end
    return time()
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

local function RecordDiagnostic(stage, fields)
    Addon.diagnostics = type(Addon.diagnostics) == "table" and Addon.diagnostics or {}
    fields = type(fields) == "table" and fields or {}

    local entry = {
        stage = stage,
        at = Now(),
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = Addon.currentEncounterName,
    }
    for key, value in pairs(fields) do
        if not IsSecret(value) then
            local valueType = type(value)
            if valueType == "string" or valueType == "number" or valueType == "boolean" then
                entry[key] = value
            end
        end
    end

    local saved = Core.RecordDiagnostic(Addon.diagnostics, entry, MAX_DIAGNOSTICS)
    DoYouNeedItDB = DoYouNeedItDB or {}
    DoYouNeedItDB.diagnostics = Addon.diagnostics

    local detail = saved and (saved.reason or saved.looter or saved.itemLink) or nil
    Debug(stage .. (detail and (": " .. tostring(detail)) or ""))
    return saved
end

local function BuildRoster()
    Addon.roster = {}

    local function addUnit(unit)
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

local function FindLooterFromMessage(message, ...)
    if not Addon.roster then
        BuildRoster()
    end

    local playerName = SafePlayerName()
    local cleanMessage = CleanString(message)
    local resolved = Core.ResolveLootMessageLooter(cleanMessage, Addon.lootPatterns, playerName)
    if resolved and resolved.name then
        if resolved.isSelf then
            return resolved.name
        end
        local canonical = Core.FindRosterNameInMessage(resolved.name, Addon.roster, playerName)
        return canonical or resolved.name
    end

    local looter = Core.FindRosterNameInMessage(cleanMessage, Addon.roster, playerName)
    if looter then
        return looter
    end

    for index = 1, select("#", ...) do
        local value = CleanString(select(index, ...))
        if value then
            looter = Core.FindRosterNameInMessage(value, Addon.roster, playerName)
            if looter then
                return looter
            end
        end
    end
    return nil
end

local function RequestItemLoad(itemLink, callback)
    local itemID = Core.ExtractItemID(itemLink)
    if not itemID or not C_Item or type(C_Item.CreateFromItemID) ~= "function" then
        return false
    end

    local item = SafeCall(C_Item.CreateFromItemID, itemID)
    if type(item) ~= "table" or type(item.ContinueOnItemLoad) ~= "function" then
        return false
    end

    local ok = pcall(function()
        item:ContinueOnItemLoad(callback)
    end)
    return ok == true
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

local function GetPlayerClassToken()
    if type(UnitClassBase) == "function" then
        local classToken = CleanString(SafeCall(UnitClassBase, "player"))
        if classToken then
            return classToken
        end
    end

    local _, classToken = SafeCall(UnitClass, "player")
    return CleanString(classToken)
end

local function PlayerArmorSubclassAllows(equipLoc, classID, subclassID)
    if ARMOR_SPECIALIZATION_EQUIP_LOCS[equipLoc or ""] ~= true then
        return nil
    end
    if CleanNumber(classID) ~= 4 then
        return nil
    end

    local subclass = CleanNumber(subclassID)
    local preferred = PREFERRED_ARMOR_SUBCLASS_BY_CLASS[GetPlayerClassToken() or ""]
    if not subclass or not preferred then
        return nil
    end
    return subclass == preferred
end

local function CanPlayerEquipItem(itemLink, classID, subclassID, equipLoc)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    local isEquippable
    if C_Item and type(C_Item.IsEquippableItem) == "function" then
        isEquippable = CleanBoolean(SafeCall(C_Item.IsEquippableItem, itemLink))
    elseif type(IsEquippableItem) == "function" then
        isEquippable = CleanBoolean(SafeCall(IsEquippableItem, itemLink))
    end
    if isEquippable == false then
        return false
    end

    local isUsable
    if C_Item and type(C_Item.IsUsableItem) == "function" then
        isUsable = CleanBoolean(SafeCall(C_Item.IsUsableItem, itemLink))
    elseif type(IsUsableItem) == "function" then
        isUsable = CleanBoolean(SafeCall(IsUsableItem, itemLink))
    end
    if isUsable == false then
        return false
    end

    local armorAllowed = PlayerArmorSubclassAllows(equipLoc, classID, subclassID)
    if armorAllowed == false then
        return false
    end

    if isEquippable == true or isUsable == true or armorAllowed == true then
        return true
    end
    return nil
end

local function TooltipHasTradeTimer(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" or not C_TooltipInfo or type(C_TooltipInfo.GetHyperlink) ~= "function" then
        return false
    end

    local data = SafeCall(C_TooltipInfo.GetHyperlink, itemLink)
    if type(data) ~= "table" then
        return false
    end
    if TooltipUtil and type(TooltipUtil.SurfaceArgs) == "function" then
        SafeCall(TooltipUtil.SurfaceArgs, data)
    end

    local tradePrefix
    local tradeFormat = CleanString(_G.BIND_TRADE_TIME_REMAINING)
    if tradeFormat then
        tradePrefix = tradeFormat:match("^(.-)%%s") or tradeFormat
    end

    local lines = type(data.lines) == "table" and data.lines or {}
    for index = 1, #lines do
        local line = lines[index]
        local text = CleanString(type(line) == "table" and line.leftText or nil)
        if text then
            if tradePrefix and tradePrefix ~= "" and text:find(tradePrefix, 1, true) then
                return true
            end
            if text:find("You may trade this item", 1, true) then
                return true
            end
        end
    end
    return false
end

local function ReadItemMetadata(itemLink)
    local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = GetItemInfoInstantCompat(itemLink)
    local itemName, resolvedLink, quality, itemLevel, requiredLevel, itemTypeText, itemSubTypeText, stackCount,
        equipLoc, itemIcon, sellPrice, detailedClassID, detailedSubclassID, bindType, expansionID, setID, isCraftingReagent =
        GetItemInfoCompat(itemLink)
    local metadataClassID = detailedClassID or classID
    local metadataSubclassID = detailedSubclassID or subclassID
    local metadataEquipLoc = CleanString(equipLoc) or CleanString(itemEquipLoc)

    return Core.BuildItemMetadata(itemLink, {
        itemID = itemID,
        equipLoc = CleanString(itemEquipLoc),
        classID = classID,
        subclassID = subclassID,
    }, {
        name = CleanString(itemName),
        link = CleanString(resolvedLink),
        quality = quality,
        itemLevel = itemLevel,
        classID = metadataClassID,
        subclassID = metadataSubclassID,
        equipLoc = metadataEquipLoc,
        bindType = bindType,
        tradeTimeRemaining = TooltipHasTradeTimer(itemLink),
        playerCanEquip = CanPlayerEquipItem(itemLink, metadataClassID, metadataSubclassID, metadataEquipLoc),
        isCraftingReagent = isCraftingReagent == true,
    })
end

local function ReadEquippedLinks(unit, equipLoc)
    local slotNames = EQUIP_LOC_SLOTS[equipLoc]
    if not slotNames then
        return {}
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
    return links
end

local function FormatEquippedLinks(prefix, links)
    links = type(links) == "table" and links or {}
    if #links == 0 then
        return UNKNOWN_EQUIPPED
    end
    return prefix .. table.concat(links, " / ")
end

local function FormatEquippedText(unit, equipLoc)
    return FormatEquippedLinks("Equipped: ", ReadEquippedLinks(unit, equipLoc))
end

local function FormatCachedEquippedTextFromLinks(links)
    return FormatEquippedLinks(CACHED_EQUIPPED_PREFIX, links)
end

local function IsCachedEquippedText(text)
    return type(text) == "string" and text:find(CACHED_EQUIPPED_PREFIX, 1, true) == 1
end

local function CanInspectClean(unit)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    local result = SafeCall(CanInspect, unit, false)
    return CleanBoolean(result) == true
end

local StartEquipmentScan

local function CountEquipmentCacheEntries()
    local count = 0
    for _ in pairs(Addon.equipmentCache or {}) do
        count = count + 1
    end
    return count
end

local function HasPendingLootInspect()
    for _, rows in pairs(Addon.pendingInspect or {}) do
        if type(rows) == "table" and #rows > 0 then
            return true
        end
    end
    return false
end

local function ScheduleEquipmentScan(delay)
    if Addon.equipmentScanScheduled then
        return
    end
    Addon.equipmentScanScheduled = true
    C_Timer.After(delay or EQUIPMENT_SCAN_DELAY, function()
        Addon.equipmentScanScheduled = false
        if StartEquipmentScan then
            StartEquipmentScan()
        end
    end)
end

local function CaptureEquipmentForUnit(unit, source)
    local fullName, shortName = SafeUnitName(unit)
    if not fullName and not shortName then
        return false
    end

    local equippedByLoc = {}
    for equipLoc in pairs(EQUIP_LOC_SLOTS) do
        local text = FormatCachedEquippedTextFromLinks(ReadEquippedLinks(unit, equipLoc))
        if text ~= UNKNOWN_EQUIPPED then
            equippedByLoc[equipLoc] = text
        end
    end

    local names = {}
    if fullName then
        names[#names + 1] = fullName
    end
    if shortName and shortName ~= fullName then
        names[#names + 1] = shortName
    end

    local captured = Core.StoreEquipmentCache(Addon.equipmentCache, names, equippedByLoc, Now())
    RecordDiagnostic(captured and "scan_cached" or "scan_empty", {
        reason = source or "scan",
        looter = fullName or shortName,
        slots = captured and "cached" or "none",
    })
    return captured
end

local function RequeueEquipmentScan(scan, reason)
    if type(scan) ~= "table" then
        return
    end
    local attempt = (scan.attempt or 0) + 1
    if attempt > MAX_EQUIPMENT_SCAN_ATTEMPTS then
        RecordDiagnostic("scan_failed", {
            reason = reason or "unknown",
            looter = scan.name,
            attempt = attempt - 1,
        })
        return
    end
    scan.attempt = attempt
    table.insert(Addon.equipmentScanQueue, scan)
    RecordDiagnostic("scan_retry", {
        reason = reason or "unknown",
        looter = scan.name,
        attempt = attempt,
    })
    ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
end

local function CancelActiveEquipmentScan(reason, requeue)
    local active = Addon.equipmentScanActive
    if not active then
        return
    end
    if active.guid then
        Addon.pendingEquipmentScan[active.guid] = nil
    end
    Addon.equipmentScanActive = nil
    RecordDiagnostic("scan_cancelled", {
        reason = reason or "unknown",
        looter = active.name,
        attempt = active.attempt or 0,
    })
    if requeue then
        table.insert(Addon.equipmentScanQueue, 1, active)
        ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
    end
end

local function AddScanUnit(queue, seen, unit, source)
    local fullName, shortName = SafeUnitName(unit)
    local key = fullName or shortName
    if not key or seen[key] then
        return
    end
    seen[key] = true
    queue[#queue + 1] = {
        unit = unit,
        name = key,
        source = source,
        attempt = 0,
    }
end

local function QueueEquipmentScan(source, quiet)
    if not Addon.state then
        return 0
    end

    BuildRoster()
    local queue = {}
    local seen = {}
    AddScanUnit(queue, seen, "player", source)
    for index = 1, 4 do
        AddScanUnit(queue, seen, "party" .. index, source)
    end
    for index = 1, 40 do
        AddScanUnit(queue, seen, "raid" .. index, source)
    end

    Addon.equipmentScanQueue = queue
    RecordDiagnostic("scan_queued", {
        reason = source or "manual",
        count = #queue,
    })
    if not quiet then
        Print("equipment scan queued: " .. tostring(#queue) .. " units")
    end
    ScheduleEquipmentScan(0)
    return #queue
end

StartEquipmentScan = function()
    if Addon.equipmentScanActive then
        return
    end
    if HasPendingLootInspect() then
        ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        RecordDiagnostic("scan_deferred", { reason = "combat_lockdown" })
        ScheduleEquipmentScan(3)
        return
    end

    local scan = table.remove(Addon.equipmentScanQueue, 1)
    if not scan then
        return
    end

    if scan.unit == "player" then
        CaptureEquipmentForUnit(scan.unit, scan.source or "scan")
        ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
        return
    end
    if not CanInspectClean(scan.unit) then
        RequeueEquipmentScan(scan, "inspect_blocked")
        return
    end

    local guid = SafeUnitGUID(scan.unit)
    if not guid then
        RequeueEquipmentScan(scan, "guid_missing")
        return
    end

    scan.guid = guid
    scan.token = {}
    Addon.equipmentScanActive = scan
    Addon.pendingEquipmentScan[guid] = scan
    RecordDiagnostic("scan_requested", {
        reason = scan.source or "scan",
        looter = scan.name,
        attempt = scan.attempt or 0,
    })
    SafeCall(NotifyInspect, scan.unit)

    local token = scan.token
    C_Timer.After(EQUIPMENT_SCAN_TIMEOUT, function()
        if Addon.equipmentScanActive ~= scan or scan.token ~= token then
            return
        end
        Addon.pendingEquipmentScan[guid] = nil
        Addon.equipmentScanActive = nil
        RequeueEquipmentScan(scan, "inspect_timeout")
    end)
end

local function RowsForSelectedView()
    local useAllGear = Addon.selectedTab == "all"
    if Addon.selectedView == "session" then
        return useAllGear and (Addon.state.sessionAllRows or {}) or Addon.state.sessionRows
    end
    if Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        if not group then
            return {}
        end
        return useAllGear and (group.allRows or group.rows or {}) or (group.rows or {})
    end
    return useAllGear and (Addon.state.allRows or {}) or Addon.state.currentRows
end

local function RefreshRows()
    if not Addon.frame then
        return
    end

    local rows = RowsForSelectedView()
    local displayRows = Core.GetNewestRowsFirst(rows, MAX_VISIBLE_ROWS)

    local title = "Current"
    if Addon.selectedView == "session" then
        title = "This Session"
    elseif Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        title = group and group.title or "History"
    end
    Addon.historyButton:SetText(title)
    if Addon.tabAskable then
        Addon.tabAskable:SetEnabled(Addon.selectedTab ~= "askable")
    end
    if Addon.tabAllGear then
        Addon.tabAllGear:SetEnabled(Addon.selectedTab ~= "all")
    end

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
        local row = displayRows[index]
        if row then
            rowFrame.row = row
            rowFrame.looter:SetText(row.looter or "?")
            rowFrame.drop:SetText(row.itemLink or "")
            rowFrame.equipped:SetText(row.equippedText or UNKNOWN_EQUIPPED)
            rowFrame.dropLink.itemLink = row.itemLink
            rowFrame.equippedLink.itemLink = FirstItemLink(row.equippedText)
            rowFrame.dropLink:SetShown(rowFrame.dropLink.itemLink ~= nil)
            rowFrame.equippedLink:SetShown(rowFrame.equippedLink.itemLink ~= nil)
            rowFrame.status:SetText(row.statusText or row.reason or "candidate")
            if Addon.selectedTab == "askable" and Addon.selectedView ~= "history" and row.askable ~= false then
                rowFrame.whisper:Enable()
                rowFrame.whisper:SetText(row.manualWhispered and "Sent" or "Ask")
                rowFrame.whisper:Show()
            else
                rowFrame.whisper:Disable()
                rowFrame.whisper:Hide()
            end
            rowFrame:Show()
        else
            rowFrame.row = nil
            rowFrame.dropLink.itemLink = nil
            rowFrame.equippedLink.itemLink = nil
            rowFrame.dropLink:Hide()
            rowFrame.equippedLink:Hide()
            rowFrame:Hide()
        end
    end

    if #rows == 0 then
        Addon.emptyText:SetText(Addon.selectedTab == "all" and "No gear drops in this view." or "No askable gear drops in this view.")
        Addon.emptyText:Show()
    else
        Addon.emptyText:Hide()
    end
end

local function SaveDB()
    DoYouNeedItDB = DoYouNeedItDB or {}
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    DoYouNeedItDB.settings = settings
    DoYouNeedItDB.history = Addon.state and Core.SnapshotHistoryForSave(Addon.state.history, settings.maxHistoryGroups) or {}
    DoYouNeedItDB.sessionRows = Addon.state and Core.SnapshotRowsForSave(Addon.state.sessionRows, settings.maxSessionRows) or {}
    DoYouNeedItDB.sessionAllRows = Addon.state and Core.SnapshotRowsForSave(Addon.state.sessionAllRows, settings.maxSessionRows) or {}
    DoYouNeedItDB.diagnostics = Addon.diagnostics or {}
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
    SaveDB()
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

local function CompleteInspectRow(row, equippedText)
    if not row then
        return
    end
    row.equippedText = equippedText
    row.inspectPending = false
    row.inspectToken = nil
    row.inspectRetryCount = nil
    RecordDiagnostic("inspect_ready", {
        looter = row.looter,
        equipLoc = row.equipLoc,
    })
end

local function FailInspectRow(row, reason)
    if not row then
        return
    end
    row.inspectPending = false
    row.inspectToken = nil
    if IsCachedEquippedText(row.equippedText) then
        -- Keep the pre-scan fallback visible when live inspect fails.
    elseif row.equippedText == EQUIPPED_PENDING or row.equippedText == UNKNOWN_EQUIPPED then
        row.equippedText = EQUIPPED_UNAVAILABLE
    end
    RecordDiagnostic("inspect_failed", {
        reason = reason or "unknown",
        looter = row.looter,
        equipLoc = row.equipLoc,
        attempt = row.inspectRetryCount or 0,
    })
end

local function ScheduleInspectRetry(row, reason)
    if not row then
        return false
    end

    row.inspectPending = false
    local attempt = (row.inspectRetryCount or 0) + 1
    row.inspectRetryCount = attempt
    if attempt > MAX_INSPECT_RETRIES then
        FailInspectRow(row, reason or "retry_limit")
        SaveDB()
        RefreshRows()
        return false
    end

    if not IsCachedEquippedText(row.equippedText) then
        row.equippedText = EQUIPPED_PENDING
    end
    local token = {}
    row.inspectToken = token
    RecordDiagnostic("inspect_retry", {
        reason = reason or "unknown",
        looter = row.looter,
        equipLoc = row.equipLoc,
        attempt = attempt,
    })
    SaveDB()
    RefreshRows()

    C_Timer.After(INSPECT_RETRY_DELAY, function()
        if row.inspectToken ~= token then
            return
        end
        row.inspectToken = nil
        RequestInspectForRow(row)
        SaveDB()
        RefreshRows()
    end)
    return true
end

RequestInspectForRow = function(row)
    local unit = ResolveUnitForName(row.looter)
    if not unit then
        ScheduleInspectRetry(row, "unit_missing")
        return
    end
    if not CanInspectClean(unit) then
        ScheduleInspectRetry(row, InCombatLockdown and InCombatLockdown() and "combat_lockdown" or "inspect_blocked")
        return
    end

    local equippedText = FormatEquippedText(unit, row.equipLoc)
    if equippedText ~= UNKNOWN_EQUIPPED then
        CaptureEquipmentForUnit(unit, "loot_live")
        CompleteInspectRow(row, equippedText)
        return
    end

    local guid = SafeUnitGUID(unit)
    if not guid then
        ScheduleInspectRetry(row, "guid_missing")
        return
    end

    CancelActiveEquipmentScan("loot_inspect", true)
    if not IsCachedEquippedText(row.equippedText) then
        row.equippedText = EQUIPPED_PENDING
    end
    row.inspectPending = true
    Addon.pendingInspect[guid] = Addon.pendingInspect[guid] or {}
    table.insert(Addon.pendingInspect[guid], row)
    RecordDiagnostic("inspect_requested", {
        looter = row.looter,
        equipLoc = row.equipLoc,
        attempt = row.inspectRetryCount or 0,
    })
    SafeCall(NotifyInspect, unit)

    local token = {}
    row.inspectToken = token
    C_Timer.After(INSPECT_RETRY_DELAY, function()
        if row.inspectToken ~= token or row.inspectPending ~= true then
            return
        end
        row.inspectPending = false
        row.inspectToken = nil
        ScheduleInspectRetry(row, "inspect_timeout")
    end)
end

local function AddTradeCandidate(looter, itemLink, metadata)
    local playerName = SafePlayerName()
    local gearClassification = DoYouNeedItCore.ClassifyGearLoot(metadata, looter, Addon.state.settings)
    if not gearClassification.visible then
        RecordDiagnostic("filtered", {
            reason = gearClassification.reason,
            looter = looter,
            itemLink = itemLink,
            equipLoc = metadata and metadata.equipLoc,
            classID = metadata and metadata.classID,
            quality = metadata and metadata.quality,
            bindType = metadata and metadata.bindType,
            playerCanEquip = metadata and metadata.playerCanEquip,
        })
        return false, gearClassification.reason
    end

    local classification = DoYouNeedItCore.ClassifyTradeCandidate(metadata, looter, playerName, Addon.state.settings)
    local askable = classification.visible == true
    if not askable then
        RecordDiagnostic("all_gear_only", {
            reason = classification.reason,
            looter = looter,
            itemLink = itemLink,
            equipLoc = metadata and metadata.equipLoc,
            classID = metadata and metadata.classID,
            quality = metadata and metadata.quality,
            bindType = metadata and metadata.bindType,
            playerCanEquip = metadata and metadata.playerCanEquip,
        })
    end

    local cachedEquippedText = Core.GetCachedEquippedText(Addon.equipmentCache, looter, metadata.equipLoc)
    local row = Core.AddVisibleRow(Addon.state, {
        looter = looter,
        itemLink = metadata.link or itemLink,
        equipLoc = metadata.equipLoc,
        itemID = metadata.itemID,
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = Core.ResolveDropEncounterName(
            Addon.currentEncounterName,
            Addon.recentEncounterName,
            Addon.recentEncounterEndedAt,
            Now(),
            ENCOUNTER_LOOT_GRACE
        ),
        timestamp = Now(),
        reason = askable and "trade candidate" or classification.reason,
        statusText = askable and "candidate" or (classification.reason or "not askable"),
        equippedText = cachedEquippedText or UNKNOWN_EQUIPPED,
        unsafe = false,
    }, askable)
    if not row then
        RecordDiagnostic("row_failed", {
            reason = "state_rejected",
            looter = looter,
            itemLink = itemLink,
        })
        return false
    end

    RecordDiagnostic("row_added", {
        looter = looter,
        itemLink = itemLink,
        equipLoc = metadata.equipLoc,
        itemID = metadata.itemID,
        askable = askable,
        playerCanEquip = metadata.playerCanEquip,
    })
    RequestInspectForRow(row)
    if askable then
        ScheduleAutoWhisper(row)
    end
    Addon.selectedTab = DoYouNeedItCore.GetAutoShowTabForRow(Addon.state, row)
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    SaveDB()
    RefreshRows()
    if DoYouNeedItCore.ShouldAutoShowWindow(row) then
        CreateUI()
        Addon.frame:Show()
    end
    return true, askable and "askable" or "all_gear_only"
end

local function AddTestRow()
    local row = Core.AddVisibleRow(Addon.state, {
        looter = "Example",
        itemLink = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
        equipLoc = "INVTYPE_WEAPON",
        itemID = 19019,
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = Addon.currentEncounterName,
        timestamp = Now(),
        reason = "test row",
        statusText = "test row",
        equippedText = "Equipped: |cff1eff00|Hitem:25:::::::::::::|h[Worn Shortsword]|h|r",
        unsafe = false,
    }, true)
    Core.AddVisibleRow(Addon.state, {
        looter = "Example",
        itemLink = "|cffa335ee|Hitem:19020:::::::::::::|h[Bound Test Chest]|h|r",
        equipLoc = "INVTYPE_CHEST",
        itemID = 19020,
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = Addon.currentEncounterName,
        timestamp = Now(),
        reason = "bind_on_pickup",
        statusText = "bind_on_pickup",
        equippedText = UNKNOWN_EQUIPPED,
        unsafe = false,
    }, false)
    Addon.selectedTab = "askable"
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    RefreshRows()
    if DoYouNeedItCore.ShouldAutoShowWindow(row) then
        CreateUI()
        Addon.frame:Show()
    end
    Print("test rows added; Askable shows one row, All Gear shows both")
end

local function TryProcessItemMetadata(looter, itemLink)
    if Addon.itemRetryCount[itemLink] == nil then
        return true
    end

    local metadata = ReadItemMetadata(itemLink)
    if metadata then
        Addon.itemRetryCount[itemLink] = nil
        AddTradeCandidate(looter, itemLink, metadata)
        return true
    end
    return false
end

local function RetryItemLater(looter, itemLink)
    local count = (Addon.itemRetryCount[itemLink] or 0) + 1
    Addon.itemRetryCount[itemLink] = count
    if count > MAX_ITEM_RETRIES then
        RecordDiagnostic("metadata_failed", {
            reason = "retry_limit",
            looter = looter,
            itemLink = itemLink,
        })
        return
    end

    if count == 1 and RequestItemLoad(itemLink, function()
        if not TryProcessItemMetadata(looter, itemLink) then
            RetryItemLater(looter, itemLink)
        end
    end) then
        RecordDiagnostic("metadata_requested", {
            looter = looter,
            itemLink = itemLink,
            itemID = Core.ExtractItemID(itemLink),
        })
        C_Timer.After(ITEM_RETRY_DELAY * 3, function()
            if not TryProcessItemMetadata(looter, itemLink) then
                RetryItemLater(looter, itemLink)
            end
        end)
        return
    end

    C_Timer.After(ITEM_RETRY_DELAY, function()
        if not TryProcessItemMetadata(looter, itemLink) then
            if count < MAX_ITEM_RETRIES then
                RetryItemLater(looter, itemLink)
                return
            end
            RecordDiagnostic("metadata_failed", {
                reason = "unresolved_item",
                looter = looter,
                itemLink = itemLink,
            })
        end
    end)
end

local function HandleLootMessage(message, ...)
    RecordDiagnostic("loot_event", {
        message = CleanString(message),
    })

    local itemLink = ExtractItemLink(message)
    if not itemLink then
        RecordDiagnostic("no_item_link", {
            message = CleanString(message),
        })
        return
    end

    local looter = FindLooterFromMessage(message, ...)
    if not looter then
        RecordDiagnostic("no_looter", {
            itemLink = itemLink,
            message = CleanString(message),
        })
        return
    end

    local metadata = ReadItemMetadata(itemLink)
    if not metadata then
        RecordDiagnostic("metadata_pending", {
            looter = looter,
            itemLink = itemLink,
        })
        RetryItemLater(looter, itemLink)
        return
    end

    AddTradeCandidate(looter, itemLink, metadata)
end

local function CompleteCurrentGroup(encounterName)
    if not Addon.state or (#Addon.state.currentRows == 0 and #(Addon.state.allRows or {}) == 0) then
        return
    end
    Core.CompleteCurrentGroup(Addon.state, {
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = encounterName or Addon.currentEncounterName or Core.FirstRowEncounterName(Addon.state.currentRows) or Core.FirstRowEncounterName(Addon.state.allRows),
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

local function SelectTab(tab)
    Addon.selectedTab = tab == "all" and "all" or "askable"
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
    row.looter:SetWidth(72)
    row.looter:SetJustifyH("LEFT")

    row.drop = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.drop:SetPoint("LEFT", row.looter, "RIGHT", 6, 0)
    row.drop:SetWidth(140)
    row.drop:SetJustifyH("LEFT")

    row.dropLink = CreateFrame("Button", nil, row)
    row.dropLink:SetPoint("LEFT", row.looter, "RIGHT", 4, 0)
    row.dropLink:SetSize(146, ROW_HEIGHT)
    row.dropLink:RegisterForClicks("AnyUp")
    row.dropLink:SetScript("OnEnter", function(button)
        ShowItemTooltip(button, button.itemLink)
    end)
    row.dropLink:SetScript("OnLeave", HideItemTooltip)
    row.dropLink:SetScript("OnClick", function(button)
        OpenItemLink(button, button.itemLink)
    end)
    row.dropLink:Hide()

    row.equipped = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.equipped:SetPoint("LEFT", row.drop, "RIGHT", 8, 0)
    row.equipped:SetWidth(125)
    row.equipped:SetJustifyH("LEFT")

    row.equippedLink = CreateFrame("Button", nil, row)
    row.equippedLink:SetPoint("LEFT", row.drop, "RIGHT", 6, 0)
    row.equippedLink:SetSize(131, ROW_HEIGHT)
    row.equippedLink:RegisterForClicks("AnyUp")
    row.equippedLink:SetScript("OnEnter", function(button)
        ShowItemTooltip(button, button.itemLink)
    end)
    row.equippedLink:SetScript("OnLeave", HideItemTooltip)
    row.equippedLink:SetScript("OnClick", function(button)
        OpenItemLink(button, button.itemLink)
    end)
    row.equippedLink:Hide()

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetPoint("TOPLEFT", row.looter, "BOTTOMLEFT", 0, -2)
    row.status:SetWidth(350)
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
    frame.title:SetWidth(128)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetText("Do You Need It?")

    frame.tabAskable = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.tabAskable:SetSize(70, 22)
    frame.tabAskable:SetPoint("TOPLEFT", frame, "TOPLEFT", 150, -12)
    frame.tabAskable:SetText("Askable")
    frame.tabAskable:SetScript("OnClick", function()
        SelectTab("askable")
    end)
    Addon.tabAskable = frame.tabAskable

    frame.tabAllGear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.tabAllGear:SetSize(72, 22)
    frame.tabAllGear:SetPoint("LEFT", frame.tabAskable, "RIGHT", 4, 0)
    frame.tabAllGear:SetText("All Gear")
    frame.tabAllGear:SetScript("OnClick", function()
        SelectTab("all")
    end)
    Addon.tabAllGear = frame.tabAllGear

    frame.historyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.historyButton:SetSize(102, 22)
    frame.historyButton:SetPoint("LEFT", frame.tabAllGear, "RIGHT", 6, 0)
    frame.historyButton:SetText("Current")
    frame.historyButton:SetScript("OnClick", function(button)
        OpenHistoryMenu(button)
    end)
    Addon.historyButton = frame.historyButton

    frame.autoStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.autoStatus:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, -48)
    frame.autoStatus:SetWidth(70)
    frame.autoStatus:SetJustifyH("RIGHT")
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
        Addon.state.allRows = {}
        Addon.state.sessionRows = {}
        Addon.state.sessionAllRows = {}
        Addon.selectedTab = "askable"
        Addon.selectedView = "current"
        Addon.selectedHistoryIndex = nil
        SaveDB()
        RefreshRows()
        Print("current session rows cleared; saved history kept")
    elseif command == "history" then
        CycleHistoryView()
        CreateUI()
        Addon.frame:Show()
    elseif command == "test" then
        CreateUI()
        AddTestRow()
    elseif command == "scan" then
        QueueEquipmentScan("manual", false)
    elseif command == "debug" then
        rest = string.lower(rest or "")
        if rest == "on" then
            Addon.state.settings.debug = true
            SaveDB()
            Print("debug enabled")
        elseif rest == "off" then
            Addon.state.settings.debug = false
            SaveDB()
            Print("debug disabled")
        else
            Print("debug=" .. tostring(Addon.state.settings.debug)
                .. ", diagnostics=" .. tostring(#(Addon.diagnostics or {}))
                .. "; usage: /dyni debug on|off")
        end
    elseif command == "diag" then
        local diagnostics = Addon.diagnostics or {}
        if #diagnostics == 0 then
            Print("no diagnostics recorded yet")
        end
        for index = 1, math.min(5, #diagnostics) do
            local entry = diagnostics[index]
            Print("diag " .. tostring(index) .. ": "
                .. tostring(entry.stage or "?")
                .. (entry.reason and (" reason=" .. tostring(entry.reason)) or "")
                .. (entry.looter and (" looter=" .. tostring(entry.looter)) or "")
                .. (entry.equipLoc and (" slot=" .. tostring(entry.equipLoc)) or "")
                .. (entry.attempt and (" attempt=" .. tostring(entry.attempt)) or "")
                .. (entry.itemLink and (" item=" .. tostring(entry.itemLink)) or ""))
        end
    elseif command == "status" then
        Print("auto=" .. tostring(Addon.state.settings.autoWhisper)
            .. ", delay=" .. tostring(Addon.state.settings.autoDelay)
            .. "s, saved groups=" .. tostring(#Addon.state.history)
            .. ", session drops=" .. tostring(#Addon.state.sessionRows)
            .. ", all gear=" .. tostring(#(Addon.state.sessionAllRows or {}))
            .. ", cache=" .. tostring(CountEquipmentCacheEntries())
            .. ", scan queue=" .. tostring(#(Addon.equipmentScanQueue or {}))
            .. ", debug=" .. tostring(Addon.state.settings.debug)
            .. ", diagnostics=" .. tostring(#(Addon.diagnostics or {}))
            .. ", build=" .. tostring(Core.VERSION)
            .. ", layout=460x310")
    else
        Print("commands: /dyni, /dyni test, /dyni scan, /dyni auto on|off, /dyni delay <seconds>, /dyni clear, /dyni history, /dyni debug on|off, /dyni diag, /dyni status")
    end
end

local function Initialize()
    DoYouNeedItDB = DoYouNeedItDB or {}
    local settings = Core.NormalizeSettings(DoYouNeedItDB.settings or {})
    Addon.state = Core.CreateState(settings)
    Addon.state.history = Core.SnapshotHistoryForSave(DoYouNeedItDB.history, Addon.state.settings.maxHistoryGroups)
    Addon.state.sessionRows = Core.NormalizeSavedRows(DoYouNeedItDB.sessionRows, Addon.state.settings.maxSessionRows)
    Addon.state.sessionAllRows = Core.NormalizeSavedRows(DoYouNeedItDB.sessionAllRows, Addon.state.settings.maxSessionRows)
    Addon.diagnostics = type(DoYouNeedItDB.diagnostics) == "table" and DoYouNeedItDB.diagnostics or {}
    Addon.equipmentCache = {}
    Addon.pendingEquipmentScan = {}
    Addon.equipmentScanQueue = {}
    Addon.equipmentScanActive = nil
    Addon.equipmentScanScheduled = false
    Addon.lootPatterns = Core.CreateLootMessagePatterns({
        lootSelf = LOOT_ITEM_SELF,
        lootSelfMultiple = LOOT_ITEM_SELF_MULTIPLE,
        lootOther = LOOT_ITEM,
        lootOtherMultiple = LOOT_ITEM_MULTIPLE,
    })
    while #Addon.state.history > Addon.state.settings.maxHistoryGroups do
        table.remove(Addon.state.history)
    end
    Addon.currentInstanceName = SafeInstanceName()
    BuildRoster()
    CreateUI()

    SLASH_DOYOUNEEDIT1 = "/dyni"
    SlashCmdList.DOYOUNEEDIT = HandleSlash
    QueueEquipmentScan("addon_loaded", true)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
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
        if Addon.state and (#Addon.state.currentRows > 0 or #(Addon.state.allRows or {}) > 0) then
            CompleteCurrentGroup(Addon.currentEncounterName)
        end
        SaveDB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local instanceName = SafeInstanceName()
        if Addon.currentInstanceName and Addon.currentInstanceName ~= instanceName and Addon.state and (#Addon.state.currentRows > 0 or #(Addon.state.allRows or {}) > 0) then
            CompleteCurrentGroup(Addon.currentEncounterName)
            Addon.recentEncounterName = nil
            Addon.recentEncounterEndedAt = nil
        end
        Addon.currentInstanceName = instanceName
        BuildRoster()
        QueueEquipmentScan("entering_world", true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        StartEquipmentScan()
    elseif event == "CHALLENGE_MODE_START" then
        QueueEquipmentScan("challenge_start", true)
    elseif event == "GROUP_ROSTER_UPDATE" then
        BuildRoster()
        QueueEquipmentScan("group_roster_update", true)
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if Addon.state and (#Addon.state.currentRows > 0 or #(Addon.state.allRows or {}) > 0) then
            CompleteCurrentGroup(Addon.currentEncounterName)
        end
        Addon.recentEncounterName = nil
        Addon.recentEncounterEndedAt = nil
        Addon.currentEncounterID = encounterID
        Addon.currentEncounterName = CleanString(encounterName)
        Addon.currentEncounterStartedAt = Now()
        QueueEquipmentScan("encounter_start", true)
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        Addon.currentEncounterID = encounterID or Addon.currentEncounterID
        Addon.currentEncounterName = CleanString(encounterName) or Addon.currentEncounterName
        CompleteCurrentGroup(Addon.currentEncounterName)
        Addon.recentEncounterName = Addon.currentEncounterName
        Addon.recentEncounterEndedAt = Now()
        Addon.currentEncounterID = nil
        Addon.currentEncounterName = nil
        Addon.currentEncounterStartedAt = nil
    elseif event == "CHAT_MSG_LOOT" then
        HandleLootMessage(...)
    elseif event == "INSPECT_READY" then
        local guid = ...
        guid = CleanString(guid)
        local handledInspect = false
        if guid and Addon.pendingEquipmentScan[guid] then
            local scan = Addon.pendingEquipmentScan[guid]
            Addon.pendingEquipmentScan[guid] = nil
            if Addon.equipmentScanActive == scan then
                Addon.equipmentScanActive = nil
            end
            if CaptureEquipmentForUnit(scan.unit, scan.source or "scan") then
                handledInspect = true
                ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
            else
                RequeueEquipmentScan(scan, "links_missing")
            end
        end
        if guid and Addon.pendingInspect[guid] then
            local rows = Addon.pendingInspect[guid]
            Addon.pendingInspect[guid] = nil
            for index = 1, #rows do
                local row = rows[index]
                if row.inspectPending == true then
                    row.inspectPending = false
                    row.inspectToken = nil
                    local unit = ResolveUnitForName(row.looter)
                    if unit then
                        CaptureEquipmentForUnit(unit, "loot_ready")
                        local equippedText = FormatEquippedText(unit, row.equipLoc)
                        if equippedText ~= UNKNOWN_EQUIPPED then
                            CompleteInspectRow(row, equippedText)
                        else
                            ScheduleInspectRetry(row, "links_missing")
                        end
                    else
                        ScheduleInspectRetry(row, "unit_missing")
                    end
                end
            end
            handledInspect = true
            SaveDB()
            RefreshRows()
        end
        if handledInspect and ClearInspectPlayer then
            SafeCall(ClearInspectPlayer)
        end
    end
end)
