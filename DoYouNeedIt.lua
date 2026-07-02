local addonName = ...
local Core = _G.DoYouNeedItCore

local Addon = {
    name = addonName or "DoYouNeedIt",
    rows = {},
    rowFrames = {},
    inspectQueue = {},
    inspectActive = nil,
    inspectByGuid = {},
    inspectGeneration = 0,
    equipmentCache = {},
    equipmentScanQueue = {},
    equipmentScanScheduled = false,
    selectedHistoryIndex = nil,
    selectedView = "current",
    selectedTab = "askable",
    contentMode = "loot",
    pendingItems = {},
    lootGeneration = 0,
    recentLootKeys = {},
    recentLootDedupeSeconds = 8,
    challengeCompletedAt = nil,
    challengeFinalizeToken = nil,
    challengeLootFinalizeDelay = 3,
    recentEncounterFinalizeToken = nil,
    encounterLootFinalizeDelay = 3,
    fontStrings = {},
}

local SetAutoWhisper
local SetDelay
local SetWhisperTemplate
local CreateUI
local CreateSettingsUI
local OpenSettings
local RequestInspectForRow
local StartEquipmentScan
local StartNextInspectRequest
local QueueInspectRequest
local CancelActiveInspectRequest
local CompleteActiveInspectRequest
local RefreshSettingsControls
local RefreshLocalization
local ApplyCurrentFont
local MaybeAutoSwitchFont

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local issecretvalue = _G.issecretvalue or function()
    return false
end

local WINDOW_WIDTH = 540
local WINDOW_HEIGHT = 300
local ROW_WIDTH = 510
local ROW_HEIGHT = 30
local ROW_START_Y = -82
local ROW_STRIDE = 34
local HEADER_TAB_ASKABLE_WIDTH = 104
local HEADER_TAB_ALL_WIDTH = 82
local HEADER_HISTORY_WIDTH = 262
local ROW_LOOTER_WIDTH = 90
local ROW_DROP_WIDTH = 180
local ROW_DROP_HOVER_WIDTH = 188
local ROW_EQUIPPED_WIDTH = 150
local ROW_EQUIPPED_HOVER_WIDTH = 158
local ROW_STATUS_WIDTH = 420
local SETTINGS_LABEL_WIDTH = 92
local SETTINGS_CONTROL_X = 126
local SETTINGS_DROPDOWN_WIDTH = 210
local SETTINGS_EDITBOX_WIDTH = 250
local SETTINGS_SLIDER_WIDTH = 210
local MAX_VISIBLE_ROWS = 6
local MAX_ITEM_RETRIES = 5
local ITEM_RETRY_DELAY = 0.7
local MAX_INSPECT_RETRIES = 8
local INSPECT_RETRY_DELAY = 0.8
local MAX_EQUIPMENT_SCAN_ATTEMPTS = 2
local EQUIPMENT_SCAN_DELAY = 1.1
local EQUIPMENT_SCAN_TIMEOUT = 2.5
local EQUIPMENT_CACHE_MAX_AGE = 1800
local MAX_DIAGNOSTICS = 20
local ENCOUNTER_LOOT_GRACE = 120
local UNKNOWN_EQUIPPED = "Equipped: unknown"
local EQUIPPED_PENDING = "Equipped: checking..."
local EQUIPPED_UNAVAILABLE = "Equipped: unavailable"
local CACHED_EQUIPPED_PREFIX = "Cached: "

local DEFAULT_LOOTER_COLOR = { r = 1, g = 0.82, b = 0 }
local FALLBACK_CLASS_COLORS = {
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    MONK = { r = 0.00, g = 1.00, b = 0.60 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}

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
    INVTYPE_RANGED = { "MainHandSlot" },
    INVTYPE_RANGEDRIGHT = { "MainHandSlot" },
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
        or text:match("(|Hitem:.-|h%[.-%]|h)")
end

local function ShowItemTooltip(owner, itemLink)
    if not owner or type(itemLink) ~= "string" or itemLink == "" or not GameTooltip then
        return
    end
    pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, itemLink)
    pcall(GameTooltip.Show, GameTooltip)
end

local function HideItemTooltip()
    if GameTooltip then
        pcall(GameTooltip.Hide, GameTooltip)
    end
end

local function OpenItemLink(owner, itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return
    end
    local modifiedOk, modifiedHandled = pcall(HandleModifiedItemClick, itemLink)
    if modifiedOk and modifiedHandled == true then
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

local function SafeUnitClassToken(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    if type(UnitClassBase) == "function" then
        local classToken = CleanString(SafeCall(UnitClassBase, unit))
        if classToken then
            return classToken
        end
    end

    local _, classToken = SafeCall(UnitClass, unit)
    return CleanString(classToken)
end

local function SafePlayerName()
    local fullName, shortName = SafeUnitName("player")
    return fullName or shortName
end

local function SafeRealmName()
    if type(GetNormalizedRealmName) == "function" then
        local normalized = CleanString(SafeCall(GetNormalizedRealmName))
        if normalized then
            return normalized
        end
    end
    if type(GetRealmName) == "function" then
        return CleanString(SafeCall(GetRealmName))
    end
    return nil
end

local function SafePlayerStorageKey()
    local fullName, shortName = SafeUnitName("player")
    local name = shortName or fullName
    if fullName and fullName:find("-", 1, true) then
        return fullName
    end
    local realm = SafeRealmName()
    if name and realm then
        return name .. "-" .. realm
    end
    return name or "__unknown"
end

local function SafeInstanceName()
    local name = SafeCall(GetInstanceInfo)
    return CleanString(name) or "Unknown Instance"
end

local function ClientLocale()
    return CleanString(SafeCall(GetLocale)) or "enUS"
end

local function ActiveLocale()
    if Addon.previewLocale then
        return Addon.previewLocale
    end
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    return Core.ResolveActiveLocale(settings.forceLocale, ClientLocale())
end

local function L(key)
    return Core.GetLocaleLabel(key, ActiveLocale())
end

local function RegisterFontString(fontString, size, flags, stable, dynamic)
    if not fontString then
        return
    end
    Addon.fontStrings[#Addon.fontStrings + 1] = {
        fontString = fontString,
        size = size,
        flags = flags,
        stable = stable == true,
        dynamic = dynamic == true,
    }
    if ApplyCurrentFont then
        ApplyCurrentFont()
    end
end

local function KeepOneLine(fontString)
    if not fontString then
        return
    end
    SafeCall(fontString.SetMaxLines, fontString, 1)
    SafeCall(fontString.SetWordWrap, fontString, false)
    SafeCall(fontString.SetNonSpaceWrap, fontString, false)
end

local function RegisterButtonFont(button, size, flags, stable)
    if button and type(button.GetFontString) == "function" then
        local fontString = button:GetFontString()
        RegisterFontString(fontString, size, flags, stable)
        KeepOneLine(fontString)
    end
end

local function BuildFontsList(locale)
    local fonts = {}
    local seen = {}

    local function addFont(name, path)
        if type(name) ~= "string" or name == "" or type(path) ~= "string" or path == "" then
            return
        end
        local key = Core.FontPathKey(path)
        if key and not seen[key] then
            seen[key] = true
            fonts[#fonts + 1] = {
                name = name,
                path = path,
            }
        end
    end

    local clientLocale = ClientLocale()
    local blizzardFonts = Core.GetBlizzardFonts(clientLocale)
    for index = 1, #blizzardFonts do
        addFont(blizzardFonts[index].name, blizzardFonts[index].path)
    end
    locale = Core.ResolveActiveLocale(locale or ActiveLocale(), clientLocale)
    if locale ~= clientLocale then
        blizzardFonts = Core.GetBlizzardFonts(locale)
        for index = 1, #blizzardFonts do
            addFont(blizzardFonts[index].name, blizzardFonts[index].path)
        end
    end

    if LSM and type(LSM.List) == "function" and type(LSM.Fetch) == "function" then
        local names = LSM:List("font")
        if type(names) == "table" then
            for index = 1, #names do
                local name = names[index]
                local path = SafeCall(function()
                    return LSM:Fetch("font", name, true)
                end)
                addFont(name, path)
            end
        end
    end
    return fonts
end

local function StableSettingsFont()
    local active = ActiveLocale()
    local requiredGlyph = Core.GetLocaleGlyphRequirement(active)
    return Core.FindCompatibleFont(Core.GetDefaultFont(), requiredGlyph, BuildFontsList(active), ClientLocale()) or Core.GetDefaultFont()
end

local function FindAvailableFontPath(path, fonts)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    fonts = type(fonts) == "table" and fonts or BuildFontsList(ActiveLocale())
    for index = 1, #fonts do
        if Core.SameFontPath(fonts[index].path, path) then
            return fonts[index].path
        end
    end
    return nil
end

local function FindCompatibleAvailableFont(path, glyph, fonts, clientLocale)
    fonts = type(fonts) == "table" and fonts or BuildFontsList(ActiveLocale())
    local availablePath = FindAvailableFontPath(path, fonts)
    if availablePath and Core.FontSupports(availablePath, glyph, clientLocale) then
        return availablePath
    end
    for index = 1, #fonts do
        if Core.FontSupports(fonts[index].path, glyph, clientLocale) then
            return fonts[index].path
        end
    end
    return Core.GetDefaultFont()
end

local function FindFontName(path)
    local fonts = BuildFontsList(ActiveLocale())
    for index = 1, #fonts do
        if Core.SameFontPath(fonts[index].path, path) then
            return fonts[index].name
        end
    end
    return "Friz Quadrata TT"
end

ApplyCurrentFont = function()
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    local previewFont = Addon.previewFont or settings.font or Core.GetDefaultFont()
    local stableFont
    local dynamicFonts
    local dynamicFallbacks = {}
    local selectedSize = tonumber(settings.fontSize) or 12
    for index = 1, #Addon.fontStrings do
        local entry = Addon.fontStrings[index]
        if entry and entry.fontString and type(entry.fontString.SetFont) == "function" then
            local font = previewFont
            if entry.stable then
                stableFont = stableFont or StableSettingsFont()
                font = stableFont
            end
            if entry.dynamic then
                local text = type(entry.fontString.GetText) == "function" and SafeCall(entry.fontString.GetText, entry.fontString) or nil
                local glyph = Core.GetTextGlyphRequirement(text)
                if glyph then
                    dynamicFonts = dynamicFonts or BuildFontsList(ActiveLocale())
                    local cacheKey = tostring(font) .. "\001" .. glyph
                    if dynamicFallbacks[cacheKey] == nil then
                        dynamicFallbacks[cacheKey] = Core.FindCompatibleFont(font, glyph, dynamicFonts, ClientLocale()) or font
                    end
                    font = dynamicFallbacks[cacheKey]
                end
            end
            SafeCall(entry.fontString.SetFont, entry.fontString, font, Core.ResolveFontSize(entry.size, selectedSize), entry.flags)
        end
    end
end

MaybeAutoSwitchFont = function()
    if not Addon.state or not Addon.state.settings then
        return false
    end

    local settings = Addon.state.settings
    local active = Core.ResolveActiveLocale(settings.forceLocale, ClientLocale())
    local requiredGlyph = Core.GetLocaleGlyphRequirement(active)
    local clientLocale = ClientLocale()
    local fonts = BuildFontsList(active)
    local changed = false
    local previousFont = FindAvailableFontPath(settings.fontBeforeAutoSwitch, fonts)
    if previousFont and Core.FontSupports(previousFont, requiredGlyph, clientLocale) then
        settings.font = previousFont
        settings.fontBeforeAutoSwitch = nil
        return true
    elseif settings.fontBeforeAutoSwitch and not previousFont then
        settings.fontBeforeAutoSwitch = nil
        changed = true
    end

    local currentFont = FindAvailableFontPath(settings.font, fonts)
    if currentFont and Core.FontSupports(currentFont, requiredGlyph, clientLocale) then
        if not Core.SameFontPath(currentFont, settings.font) then
            settings.font = currentFont
            return true
        end
        return changed
    end

    local fallback = FindCompatibleAvailableFont(settings.font, requiredGlyph, fonts, clientLocale)
    if fallback and not Core.SameFontPath(fallback, settings.font) then
        if currentFont and not settings.fontBeforeAutoSwitch then
            settings.fontBeforeAutoSwitch = settings.font
        end
        settings.font = fallback
        return true
    end
    return changed
end

local function ExtractItemLink(message)
    message = CleanString(message)
    if message == nil then
        return nil
    end
    return message:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
        or message:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
end

local function ShouldPersistDiagnostics()
    return Addon.state and Addon.state.settings and Addon.state.settings.debug == true
end

local function PersistDiagnostics()
    DoYouNeedItDB = DoYouNeedItDB or {}
    if ShouldPersistDiagnostics() then
        DoYouNeedItDB.diagnostics = Addon.diagnostics or {}
    else
        DoYouNeedItDB.diagnostics = nil
    end
end

local function SavedDropListHasEntries(value)
    return type(value) == "table" and #value > 0
end

local function PreserveLegacyAccountDrops(settings)
    DoYouNeedItDB = DoYouNeedItDB or {}
    if type(DoYouNeedItDB.legacyAccountDrops) == "table" then
        return
    end
    if not SavedDropListHasEntries(DoYouNeedItDB.history)
        and not SavedDropListHasEntries(DoYouNeedItDB.sessionRows)
        and not SavedDropListHasEntries(DoYouNeedItDB.sessionAllRows) then
        return
    end

    settings = Core.NormalizeSettings(settings or {})
    DoYouNeedItDB.legacyAccountDrops = {
        history = Core.SnapshotHistoryForSave(DoYouNeedItDB.history, settings.maxHistoryGroups, settings.maxSessionRows),
        sessionRows = Core.SnapshotRowsForSave(DoYouNeedItDB.sessionRows, settings.maxSessionRows),
        sessionAllRows = Core.SnapshotRowsForSave(DoYouNeedItDB.sessionAllRows, settings.maxSessionRows),
    }
end

local function GetCharacterDropsDB(create)
    DoYouNeedItDB = DoYouNeedItDB or {}
    local key = Addon.characterKey or SafePlayerStorageKey()
    Addon.characterKey = key
    if type(DoYouNeedItDB.characters) ~= "table" then
        if not create then
            return {}, key
        end
        DoYouNeedItDB.characters = {}
    end

    if type(DoYouNeedItDB.characters[key]) ~= "table" then
        if not create then
            return {}, key
        end
        DoYouNeedItDB.characters[key] = {}
    end
    return DoYouNeedItDB.characters[key], key
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
    PersistDiagnostics()

    local detail = saved and (saved.reason or saved.looter or saved.itemLink) or nil
    Debug(stage .. (detail and (": " .. tostring(detail)) or ""))
    return saved
end

local function BuildRoster()
    local entries = {}

    local function addUnit(unit)
        local fullName, shortName = SafeUnitName(unit)
        if fullName and not Core.IsPlaceholderName(fullName) then
            entries[#entries + 1] = {
                unit = unit,
                fullName = fullName,
                shortName = shortName,
            }
        end
    end

    addUnit("player")
    for index = 1, 4 do
        addUnit("party" .. index)
    end
    for index = 1, 40 do
        addUnit("raid" .. index)
    end
    Addon.roster = Core.CreateRosterIndex(entries)
end

local function ResolveUnitForName(name)
    if not Addon.roster then
        BuildRoster()
    end
    return Core.GetRosterUnit(Addon.roster, name)
end

local function ResolveClassTokenForName(name)
    local unit = ResolveUnitForName(name)
    return SafeUnitClassToken(unit)
end

local function GetClassColor(classToken)
    classToken = CleanString(classToken)
    if not classToken then
        return nil
    end

    local colors = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS or nil
    local color = colors and colors[classToken] or FALLBACK_CLASS_COLORS[classToken]
    if type(color) ~= "table" then
        return nil
    end

    local r = tonumber(color.r)
    local g = tonumber(color.g)
    local b = tonumber(color.b)
    if r == nil or g == nil or b == nil then
        return nil
    end
    return r, g, b
end

local function ApplyLooterClassColor(fontString, classToken)
    if not fontString or type(fontString.SetTextColor) ~= "function" then
        return
    end

    local r, g, b = GetClassColor(classToken)
    if r == nil then
        r, g, b = DEFAULT_LOOTER_COLOR.r, DEFAULT_LOOTER_COLOR.g, DEFAULT_LOOTER_COLOR.b
    end
    SafeCall(fontString.SetTextColor, fontString, r, g, b)
end

local function EnsureRowClassToken(row)
    if type(row) ~= "table" then
        return nil
    end
    if type(row.classToken) == "string" and row.classToken ~= "" then
        return row.classToken
    end

    local classToken = ResolveClassTokenForName(row.looter)
    if classToken then
        row.classToken = classToken
    end
    return row.classToken
end

local function UnitMatchesGuid(unit, guid)
    return type(unit) == "string"
        and type(guid) == "string"
        and guid ~= ""
        and SafeUnitGUID(unit) == guid
end

local function IsRowInList(list, row)
    if type(list) ~= "table" or type(row) ~= "table" then
        return false
    end
    for index = 1, #list do
        if list[index] == row then
            return true
        end
    end
    return false
end

local function IsRowStillTracked(row)
    if type(row) ~= "table" or type(Addon.state) ~= "table" then
        return false
    end
    if IsRowInList(Addon.state.currentRows, row)
        or IsRowInList(Addon.state.allRows, row)
        or IsRowInList(Addon.state.sessionRows, row)
        or IsRowInList(Addon.state.sessionAllRows, row)
    then
        return true
    end

    local history = Addon.state.history
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" and (IsRowInList(group.rows, row) or IsRowInList(group.allRows, row)) then
                return true
            end
        end
    end
    return false
end

local function ResolveUnitMatchingRequest(request, preferredUnit)
    if type(request) ~= "table" then
        return nil
    end
    if UnitMatchesGuid(preferredUnit, request.guid) then
        request.unit = preferredUnit
        return preferredUnit
    end
    if UnitMatchesGuid(request.unit, request.guid) then
        return request.unit
    end
    return nil
end

local function ResolveRowUnitForRequest(request, row)
    local unit = type(row) == "table" and ResolveUnitForName(row.looter) or nil
    return ResolveUnitMatchingRequest(request, unit)
end

local function ResolveScanUnitForRequest(request)
    local scan = type(request) == "table" and request.scan or nil
    local unit = type(scan) == "table" and ResolveUnitForName(scan.name) or nil
    return ResolveUnitMatchingRequest(request, unit)
end

local function ResolveInspectRequestUnit(request)
    if type(request) ~= "table" then
        return nil
    end
    local rows = type(request.rows) == "table" and request.rows or {}
    for index = 1, #rows do
        local row = rows[index]
        if IsRowStillTracked(row) then
            local unit = ResolveRowUnitForRequest(request, row)
            if unit then
                return unit
            end
        end
    end
    local scanUnit = ResolveScanUnitForRequest(request)
    if scanUnit then
        return scanUnit
    end
    return ResolveUnitMatchingRequest(request, nil)
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
            return resolved.name, false, nil, resolved.lootSource
        end
        local canonical = Core.FindRosterNameInMessage(resolved.name, Addon.roster, playerName)
            or Core.ResolveRosterName(resolved.name, Addon.roster)
        if canonical then
            return canonical, false, nil, resolved.lootSource
        end
        local cleanName = CleanString(resolved.name)
        if cleanName and not Core.IsPlaceholderName(cleanName) then
            return cleanName, true, "looter_unresolved", resolved.lootSource
        end
        return nil
    end

    local looter = Core.FindRosterNameInMessage(cleanMessage, Addon.roster, playerName)
    if looter then
        return looter, false
    end

    for index = 1, select("#", ...) do
        local value = CleanString(select(index, ...))
        if value then
            looter = Core.FindRosterNameInMessage(value, Addon.roster, playerName)
            if looter then
                return looter, false
            end
        end
    end
    return nil
end

local function BuildDropContext(unsafe, unsafeReason)
    local now = Now()
    return {
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = Core.ResolveDropEncounterName(
            Addon.currentEncounterName,
            Addon.recentEncounterName,
            Addon.recentEncounterEndedAt,
            now,
            ENCOUNTER_LOOT_GRACE
        ),
        timestamp = now,
        generation = Addon.lootGeneration or 0,
        unsafe = unsafe == true,
        unsafeReason = unsafeReason,
    }
end

function Addon.CleanupRecentLootKeys(now)
    Addon.recentLootKeys = type(Addon.recentLootKeys) == "table" and Addon.recentLootKeys or {}
    now = type(now) == "number" and now or Now()
    for key, seenAt in pairs(Addon.recentLootKeys) do
        if type(seenAt) ~= "number" or now - seenAt > Addon.recentLootDedupeSeconds then
            Addon.recentLootKeys[key] = nil
        end
    end
end

function Addon.ShouldSkipDuplicateLoot(looter, itemLink)
    if type(looter) ~= "string" or looter == "" or type(itemLink) ~= "string" or itemLink == "" then
        return false
    end

    local now = Now()
    Addon.CleanupRecentLootKeys(now)
    local itemID = Core.ExtractItemID(itemLink)
    local linkKey = "link\031" .. looter .. "\031" .. itemLink
    local itemKey = itemID and ("item\031" .. looter .. "\031" .. tostring(itemID)) or nil
    if Addon.recentLootKeys[linkKey] or (itemKey and Addon.recentLootKeys[itemKey]) then
        return true, itemID
    end

    Addon.recentLootKeys[linkKey] = now
    if itemKey then
        Addon.recentLootKeys[itemKey] = now
    end
    return false, itemID
end

function Addon.ResolveEncounterLootLooter(playerName)
    if not Addon.roster then
        BuildRoster()
    end

    local cleanName = CleanString(playerName)
    if not cleanName or Core.IsPlaceholderName(cleanName) then
        return nil
    end

    local player = SafePlayerName()
    return Core.ResolveRosterName(cleanName, Addon.roster)
        or Core.FindRosterNameInMessage(cleanName, Addon.roster, player)
        or cleanName
end

function Addon.HasCurrentLootRows()
    return Addon.state and (#(Addon.state.currentRows or {}) > 0 or #(Addon.state.allRows or {}) > 0)
end

function Addon.IsRecentChallengeCompletion()
    local completedAt = Addon.challengeCompletedAt
    local now = Now()
    return type(completedAt) == "number" and now >= completedAt and now - completedAt <= ENCOUNTER_LOOT_GRACE
end

function Addon.ScheduleChallengeHistoryFinalize(reason)
    if not Addon.state then
        return
    end

    local token = {}
    Addon.challengeFinalizeToken = token
    C_Timer.After(Addon.challengeLootFinalizeDelay, function()
        if Addon.challengeFinalizeToken ~= token then
            return
        end
        Addon.challengeFinalizeToken = nil
        if Addon.HasCurrentLootRows() then
            RecordDiagnostic("challenge_history_complete", {
                reason = reason or "challenge_completed",
            })
            Addon.CompleteCurrentGroup(Addon.currentEncounterName)
        end
    end)
end

function Addon.ScheduleChallengeHistoryFinalizeIfRecent(reason)
    if Addon.IsRecentChallengeCompletion() then
        Addon.ScheduleChallengeHistoryFinalize(reason)
        return true
    end
    return false
end

function Addon.IsRecentEncounterEnd()
    local endedAt = Addon.recentEncounterEndedAt
    local now = Now()
    return type(Addon.currentEncounterName) ~= "string"
        and type(Addon.recentEncounterName) == "string"
        and Addon.recentEncounterName ~= ""
        and type(endedAt) == "number"
        and now >= endedAt
        and now - endedAt <= ENCOUNTER_LOOT_GRACE
end

function Addon.ScheduleRecentEncounterHistoryFinalize(reason)
    if not Addon.state then
        return
    end

    local token = {}
    Addon.recentEncounterFinalizeToken = token
    C_Timer.After(Addon.encounterLootFinalizeDelay or Addon.challengeLootFinalizeDelay, function()
        if Addon.recentEncounterFinalizeToken ~= token then
            return
        end
        Addon.recentEncounterFinalizeToken = nil
        if Addon.HasCurrentLootRows() then
            RecordDiagnostic("encounter_history_complete", {
                reason = reason or "post_encounter_loot",
                encounterName = Addon.recentEncounterName,
            })
            Addon.CompleteCurrentGroup(Addon.recentEncounterName)
        end
    end)
end

function Addon.ScheduleRecentEncounterHistoryFinalizeIfRecent(reason)
    if Addon.IsRecentEncounterEnd() then
        Addon.ScheduleRecentEncounterHistoryFinalize(reason)
        return true
    end
    return false
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
        local slotID = SafeCall(GetInventorySlotInfo, slotNames[index])
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

local function DisplayEquippedText(text)
    text = type(text) == "string" and text or UNKNOWN_EQUIPPED
    if text == UNKNOWN_EQUIPPED or text == EQUIPPED_PENDING or text == EQUIPPED_UNAVAILABLE then
        return L(text)
    end
    if IsCachedEquippedText(text) then
        return L(CACHED_EQUIPPED_PREFIX) .. text:sub(#CACHED_EQUIPPED_PREFIX + 1)
    end
    local equippedPrefix = "Equipped: "
    if text:find(equippedPrefix, 1, true) == 1 then
        return L(equippedPrefix) .. text:sub(#equippedPrefix + 1)
    end
    return text
end

local function CanInspectClean(unit)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    local result = SafeCall(CanInspect, unit, false)
    return CleanBoolean(result) == true
end

local function CountEquipmentCacheEntries()
    local count = 0
    for _ in pairs(Addon.equipmentCache or {}) do
        count = count + 1
    end
    return count
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
    if not Addon.roster then
        BuildRoster()
    end

    local equippedByLoc = {}
    for equipLoc in pairs(EQUIP_LOC_SLOTS) do
        local text = FormatCachedEquippedTextFromLinks(ReadEquippedLinks(unit, equipLoc))
        if text ~= UNKNOWN_EQUIPPED then
            equippedByLoc[equipLoc] = text
        end
    end

    local names = {}
    local canonical = Core.ResolveRosterName(fullName, Addon.roster) or Core.ResolveRosterName(shortName, Addon.roster)
    if canonical then
        names[#names + 1] = canonical
        if shortName and shortName ~= canonical and Core.ResolveRosterName(shortName, Addon.roster) == canonical then
            names[#names + 1] = shortName
        end
    elseif fullName and not Core.IsPlaceholderName(fullName) then
        names[#names + 1] = fullName
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

local function RemoveQueuedScanInspectRequests()
    if type(Addon.inspectQueue) ~= "table" then
        return
    end
    for index = #Addon.inspectQueue, 1, -1 do
        local request = Addon.inspectQueue[index]
        local rows = type(request) == "table" and request.rows or nil
        if type(request) == "table" and request.scan and (type(rows) ~= "table" or #rows == 0) then
            Addon.inspectByGuid[request.guid] = nil
            table.remove(Addon.inspectQueue, index)
        end
    end
end

local function AddScanUnit(queue, seen, unit, source)
    local fullName, shortName = SafeUnitName(unit)
    local key = Core.ResolveRosterName(fullName, Addon.roster)
        or Core.ResolveRosterName(shortName, Addon.roster)
        or fullName
        or shortName
    if not key or Core.IsPlaceholderName(key) or seen[key] then
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
    RemoveQueuedScanInspectRequests()
    RecordDiagnostic("scan_queued", {
        reason = source or "manual",
        count = #queue,
    })
    ScheduleEquipmentScan(0)
    return #queue
end

StartEquipmentScan = function()
    if Addon.inspectActive then
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
    QueueInspectRequest(guid, scan.unit, { scan = scan }, false)
    StartNextInspectRequest()
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

function Addon.SetLootChromeShown(shown)
    local function setShown(frame)
        if not frame then
            return
        end
        if shown then
            frame:Show()
        else
            frame:Hide()
        end
    end

    setShown(Addon.tabAskable)
    setShown(Addon.tabAllGear)
    setShown(Addon.historyButton)
    setShown(Addon.settingsButton)
end

function Addon.HideLootRows()
    for index = 1, MAX_VISIBLE_ROWS do
        if Addon.rowFrames[index] then
            Addon.rowFrames[index]:Hide()
        end
    end
    if Addon.emptyText then
        Addon.emptyText:Hide()
    end
end

local function RefreshRows()
    if not Addon.frame then
        return
    end

    if Addon.contentMode == "settings" then
        Addon.SetLootChromeShown(false)
        Addon.HideLootRows()
        if Addon.settingsFrame then
            Addon.settingsFrame:Show()
        end
        return
    end

    Addon.SetLootChromeShown(true)
    if Addon.settingsFrame and Addon.settingsFrame:IsShown() then
        Addon.settingsFrame:Hide()
    end

    local rows = RowsForSelectedView()
    local displayRows = Core.GetNewestRowsFirst(rows, MAX_VISIBLE_ROWS)

    local title = L("Current")
    if Addon.selectedView == "session" then
        title = L("This Session")
    elseif Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        title = group and group.title or L("History")
    end
    Addon.historyButton:SetText(title)
    if Addon.tabAskable then
        Addon.tabAskable:SetText(L("Askable"))
        Addon.tabAskable:SetEnabled(Addon.selectedTab ~= "askable")
    end
    if Addon.tabAllGear then
        Addon.tabAllGear:SetText(L("All Gear"))
        Addon.tabAllGear:SetEnabled(Addon.selectedTab ~= "all")
    end

    for index = 1, MAX_VISIBLE_ROWS do
        local rowFrame = Addon.rowFrames[index]
        local row = displayRows[index]
        if row then
            rowFrame.row = row
            rowFrame.looter:SetText(row.looter or "?")
            ApplyLooterClassColor(rowFrame.looter, EnsureRowClassToken(row))
            rowFrame.drop:ClearAllPoints()
            if row.lootSource == "bonus_roll" then
                rowFrame.rollIcon:Show()
                rowFrame.drop:SetPoint("LEFT", rowFrame.rollIcon, "RIGHT", 4, 0)
                rowFrame.drop:SetWidth(ROW_DROP_WIDTH - 18)
            else
                rowFrame.rollIcon:Hide()
                rowFrame.drop:SetPoint("LEFT", rowFrame.looter, "RIGHT", 8, 0)
                rowFrame.drop:SetWidth(ROW_DROP_WIDTH)
            end
            rowFrame.drop:SetText(row.itemLink or "")
            rowFrame.equipped:SetText(DisplayEquippedText(row.equippedText))
            rowFrame.dropLink.itemLink = FirstItemLink(row.itemLink)
            rowFrame.equippedLink.itemLink = FirstItemLink(row.equippedText)
            rowFrame.dropLink:SetShown(rowFrame.dropLink.itemLink ~= nil)
            rowFrame.equippedLink:SetShown(rowFrame.equippedLink.itemLink ~= nil)
            rowFrame.status:SetText(Core.GetRowStatusText(row, ActiveLocale()))
            local whisperState = Core.GetWhisperButtonState(Addon.selectedTab, Addon.selectedView, row)
            if whisperState.visible then
                rowFrame.whisper:SetText(L(whisperState.text))
                if whisperState.enabled then
                    rowFrame.whisper:Enable()
                else
                    rowFrame.whisper:Disable()
                end
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
            rowFrame.rollIcon:Hide()
            rowFrame.dropLink:Hide()
            rowFrame.equippedLink:Hide()
            rowFrame:Hide()
        end
    end

    ApplyCurrentFont()

    if #rows == 0 then
        Addon.emptyText:SetText(Addon.selectedTab == "all" and L("No gear drops in this view.") or L("No askable gear drops in this view."))
        Addon.emptyText:Show()
    else
        Addon.emptyText:Hide()
    end
    if RefreshSettingsControls then
        RefreshSettingsControls()
    end
end

local function SaveDB()
    DoYouNeedItDB = DoYouNeedItDB or {}
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    local characterDB = GetCharacterDropsDB(true)
    local history = Addon.state and Core.SnapshotHistoryForSave(Addon.state.history, settings.maxHistoryGroups, settings.maxSessionRows) or {}
    local sessionRows = Addon.state and Core.SnapshotRowsForSave(Addon.state.sessionRows, settings.maxSessionRows) or {}
    local sessionAllRows = Addon.state and Core.SnapshotRowsForSave(Addon.state.sessionAllRows, settings.maxSessionRows) or {}
    DoYouNeedItDB.settings = settings
    characterDB.history = history
    characterDB.sessionRows = sessionRows
    characterDB.sessionAllRows = sessionAllRows
    DoYouNeedItDB.currentCharacter = Addon.characterKey
    DoYouNeedItDB.history = history
    DoYouNeedItDB.sessionRows = sessionRows
    DoYouNeedItDB.sessionAllRows = sessionAllRows
    PersistDiagnostics()
end

local function IsIncompleteCharacterKey(key, newKey)
    if type(key) ~= "string" or key == "" or key == "__unknown" then
        return true
    end
    if type(newKey) == "string" and newKey:find("-", 1, true) and not key:find("-", 1, true) then
        return newKey:find(key .. "-", 1, true) == 1
    end
    return false
end

local function StateHasDropRows()
    if type(Addon.state) ~= "table" then
        return false
    end
    return #(Addon.state.currentRows or {}) > 0
        or #(Addon.state.allRows or {}) > 0
        or #(Addon.state.sessionRows or {}) > 0
        or #(Addon.state.sessionAllRows or {}) > 0
        or #(Addon.state.history or {}) > 0
end

function Addon.RowMergeKey(row)
    if type(row) ~= "table" then
        return nil
    end
    return tostring(row.id or "")
        .. "\031" .. tostring(row.looter or "")
        .. "\031" .. tostring(row.itemLink or "")
        .. "\031" .. tostring(row.timestamp or "")
end

function Addon.AppendUniqueRows(target, seen, rows)
    if type(rows) ~= "table" then
        return
    end
    for index = 1, #rows do
        local row = rows[index]
        local key = Addon.RowMergeKey(row)
        if key and not seen[key] then
            seen[key] = true
            target[#target + 1] = row
        end
    end
end

function Addon.MergeSavedRowsBeforeLive(savedRows, liveRows, limit)
    local merged = {}
    local seen = {}
    Addon.AppendUniqueRows(merged, seen, savedRows)
    Addon.AppendUniqueRows(merged, seen, liveRows)
    limit = math.max(1, math.floor(tonumber(limit) or 50))
    while #merged > limit do
        table.remove(merged, 1)
    end
    return merged
end

function Addon.HistoryGroupMergeKey(group)
    if type(group) ~= "table" then
        return nil
    end
    local firstRows = type(group.allRows) == "table" and group.allRows or group.rows
    local firstRow = type(firstRows) == "table" and firstRows[1] or nil
    return tostring(group.title or "")
        .. "\031" .. tostring(group.startedAt or "")
        .. "\031" .. tostring(group.endedAt or "")
        .. "\031" .. tostring(Addon.RowMergeKey(firstRow) or "")
end

function Addon.AppendUniqueHistoryGroups(target, seen, history)
    if type(history) ~= "table" then
        return
    end
    for index = 1, #history do
        local group = history[index]
        local key = Addon.HistoryGroupMergeKey(group)
        if key and not seen[key] then
            seen[key] = true
            target[#target + 1] = group
        end
    end
end

function Addon.MergeSavedHistoryAfterLive(liveHistory, savedHistory, limit)
    local merged = {}
    local seen = {}
    Addon.AppendUniqueHistoryGroups(merged, seen, liveHistory)
    Addon.AppendUniqueHistoryGroups(merged, seen, savedHistory)
    limit = math.max(1, math.floor(tonumber(limit) or 10))
    while #merged > limit do
        table.remove(merged)
    end
    return merged
end

local function RefreshCharacterStorageFromPlayerIdentity()
    local oldKey = Addon.characterKey
    local newKey = SafePlayerStorageKey()
    if type(newKey) ~= "string" or newKey == "" or newKey == "__unknown" or oldKey == newKey then
        return false
    end
    if not IsIncompleteCharacterKey(oldKey, newKey) then
        return false
    end

    Addon.characterKey = newKey
    local characterDB = GetCharacterDropsDB(true)
    if Addon.state then
        local settings = Addon.state.settings or Core.NormalizeSettings({})
        local savedHistory = Core.SnapshotHistoryForSave(characterDB.history, settings.maxHistoryGroups, settings.maxSessionRows)
        local savedSessionRows = Core.NormalizeSavedRows(characterDB.sessionRows, settings.maxSessionRows)
        local savedSessionAllRows = Core.NormalizeSavedAllRows(
            characterDB.sessionAllRows,
            characterDB.sessionRows,
            settings.maxSessionRows
        )
        if StateHasDropRows() then
            Addon.state.history = Addon.MergeSavedHistoryAfterLive(Addon.state.history, savedHistory, settings.maxHistoryGroups)
            Addon.state.sessionRows = Addon.MergeSavedRowsBeforeLive(savedSessionRows, Addon.state.sessionRows, settings.maxSessionRows)
            Addon.state.sessionAllRows = Addon.MergeSavedRowsBeforeLive(savedSessionAllRows, Addon.state.sessionAllRows, settings.maxSessionRows)
        else
            Addon.state.history = savedHistory
            Addon.state.sessionRows = savedSessionRows
            Addon.state.sessionAllRows = savedSessionAllRows
        end
    end
    SaveDB()
    RefreshRows()
    return true
end

local function SendWhisper(row, isAuto)
    if not row or not row.looter or not row.itemLink then
        return
    end
    if row.manualWhispered == true or row.autoWhispered == true or row.whisperInFlight == true then
        return
    end

    row.pendingAutoWhisper = false
    row.autoToken = nil
    local message = Core.FormatWhisperMessage(Addon.state.settings.whisperTemplate, row.itemLink)
    local target = row.looter
    local token = {}
    row.whisperInFlight = true
    row.whisperToken = token
    row.statusKey = isAuto and "auto_sending" or "sending"
    row.statusSeconds = nil
    row.statusText = nil
    RefreshRows()

    C_Timer.After(0, function()
        if row.whisperToken ~= token or row.whisperInFlight ~= true then
            return
        end
        if not IsRowStillTracked(row) then
            row.whisperInFlight = false
            row.whisperToken = nil
            return
        end

        local sendFn = SendChatMessage
        if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
            sendFn = C_ChatInfo.SendChatMessage
        end

        local ok = false
        if type(sendFn) == "function" then
            ok = pcall(sendFn, message, "WHISPER", nil, target)
        end

        row.whisperInFlight = false
        row.whisperToken = nil
        if ok then
            if isAuto then
                row.autoWhispered = true
                row.statusKey = "auto_sent"
            else
                row.manualWhispered = true
                row.statusKey = "sent"
            end
        else
            row.statusKey = "whisper_failed"
            RecordDiagnostic("whisper_failed", {
                looter = target,
                itemLink = row.itemLink,
            })
        end
        SaveDB()
        RefreshRows()
    end)
    SaveDB()
end

local function CancelPendingAuto(row)
    if row then
        row.pendingAutoWhisper = false
        row.autoToken = nil
        if row.statusKey == "auto_pending" or (row.statusText and row.statusText:find("auto in", 1, true)) then
            row.statusKey = "candidate"
            row.statusSeconds = nil
            row.statusText = nil
        end
    end
end

function Addon.RemoveRowFromList(list, row)
    if type(list) ~= "table" or type(row) ~= "table" then
        return false
    end
    local removed = false
    for index = #list, 1, -1 do
        if list[index] == row then
            table.remove(list, index)
            removed = true
        end
    end
    return removed
end

function Addon.FindTrackedLootRowMatching(looter, matches)
    if type(Addon.state) ~= "table" or type(looter) ~= "string" or type(matches) ~= "function" then
        return nil
    end
    local state = Addon.state
    local lists = {
        state.allRows,
        state.currentRows,
        state.sessionAllRows,
        state.sessionRows,
    }
    for listIndex = 1, #lists do
        local list = lists[listIndex]
        if type(list) == "table" then
            for rowIndex = #list, 1, -1 do
                local row = list[rowIndex]
                if type(row) == "table" and row.looter == looter and matches(row) then
                    return row
                end
            end
        end
    end

    local history = state.history
    if type(history) == "table" then
        for groupIndex = 1, #history do
            local group = history[groupIndex]
            if type(group) == "table" then
                local historyLists = { group.allRows, group.rows }
                for listIndex = 1, #historyLists do
                    local list = historyLists[listIndex]
                    if type(list) == "table" then
                        for rowIndex = #list, 1, -1 do
                            local row = list[rowIndex]
                            if type(row) == "table" and row.looter == looter and matches(row) then
                                return row
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Addon.FindTrackedLootRow(looter, itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    return Addon.FindTrackedLootRowMatching(looter, function(row)
        return row.itemLink == itemLink
    end)
end

function Addon.FindTrackedLootRowByItemID(looter, itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end
    return Addon.FindTrackedLootRowMatching(looter, function(row)
        return tonumber(row.itemID) == itemID
    end)
end

function Addon.UpdateTrackedLootLink(row, itemLink, source)
    if type(row) ~= "table" or type(itemLink) ~= "string" or itemLink == "" or row.itemLink == itemLink then
        return false
    end
    if source ~= "chat" and type(row.itemLink) == "string" and row.itemLink ~= "" then
        return false
    end

    row.itemLink = itemLink
    local itemID = Core.ExtractItemID(itemLink)
    if itemID then
        row.itemID = itemID
    end
    return true
end

function Addon.UpgradeTrackedLootToBonus(looter, itemLink, context, source)
    context = type(context) == "table" and context or {}
    if context.lootSource ~= "bonus_roll" then
        return false
    end

    local itemID = Core.ExtractItemID(itemLink)
    local row = Addon.FindTrackedLootRow(looter, itemLink) or Addon.FindTrackedLootRowByItemID(looter, itemID)
    if not row then
        return false
    end

    Addon.UpdateTrackedLootLink(row, itemLink, source)
    CancelPendingAuto(row)
    row.whisperInFlight = false
    row.whisperToken = nil
    row.lootSource = "bonus_roll"
    row.askable = false
    row.reason = "bonus_roll"
    row.statusKey = "bonus_roll"
    row.statusSeconds = nil
    row.statusText = nil
    Addon.RemoveRowFromList(Addon.state.currentRows, row)
    Addon.RemoveRowFromList(Addon.state.sessionRows, row)
    local history = Addon.state.history
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" then
                Addon.RemoveRowFromList(group.rows, row)
            end
        end
    end

    RecordDiagnostic("bonus_loot_upgrade", {
        looter = looter,
        itemLink = itemLink,
        source = source or "unknown",
    })
    Addon.selectedTab = DoYouNeedItCore.GetAutoShowTabForRow(Addon.state, row)
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    Addon.EnterLootMode()
    SaveDB()
    RefreshRows()
    if not Addon.ScheduleChallengeHistoryFinalizeIfRecent(context.source or source or "bonus_loot_upgrade") then
        Addon.ScheduleRecentEncounterHistoryFinalizeIfRecent(context.source or source or "bonus_loot_upgrade")
    end
    if DoYouNeedItCore.ShouldAutoShowWindow(row) then
        CreateUI()
        Addon.frame:Show()
    end
    return true
end

function Addon.UpgradePendingLootToBonus(looter, itemLink, context, source)
    context = type(context) == "table" and context or {}
    if context.lootSource ~= "bonus_roll" or type(Addon.pendingItems) ~= "table" then
        return false
    end

    local bucket = Addon.pendingItems[itemLink]
    local waiters = type(bucket) == "table" and bucket.waiters or nil
    if type(waiters) ~= "table" then
        return false
    end

    local updated = false
    for index = 1, #waiters do
        local waiter = waiters[index]
        if type(waiter) == "table" and waiter.looter == looter and type(waiter.context) == "table" then
            waiter.context.lootSource = "bonus_roll"
            waiter.context.source = waiter.context.source or context.source or source
            updated = true
        end
    end

    if updated then
        RecordDiagnostic("bonus_loot_pending_upgrade", {
            looter = looter,
            itemLink = itemLink,
            source = source or "unknown",
        })
    end
    return updated
end

local function ScheduleAutoWhisper(row)
    local decision = Core.GetAutoWhisperDecision(Addon.state.settings, row)
    if not decision.shouldSchedule then
        return
    end

    local token = {}
    row.pendingAutoWhisper = true
    row.autoToken = token
    row.statusKey = "auto_pending"
    row.statusSeconds = decision.delay
    row.statusText = nil
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

    if not IsRowStillTracked(row) then
        row.inspectPending = false
        row.inspectToken = nil
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

    local generation = Addon.inspectGeneration or 0
    C_Timer.After(INSPECT_RETRY_DELAY, function()
        if row.inspectToken ~= token or generation ~= (Addon.inspectGeneration or 0) or not IsRowStillTracked(row) then
            return
        end
        row.inspectToken = nil
        RequestInspectForRow(row)
        SaveDB()
        RefreshRows()
    end)
    return true
end

local function ClearOwnedInspectState()
    if ClearInspectPlayer then
        SafeCall(ClearInspectPlayer)
    end
end

local function AppendInspectRow(request, row)
    if type(request) ~= "table" or type(row) ~= "table" then
        return
    end
    request.rows = type(request.rows) == "table" and request.rows or {}
    for index = 1, #request.rows do
        if request.rows[index] == row then
            return
        end
    end
    request.rows[#request.rows + 1] = row
end

local function MoveQueuedInspectRequestToFront(request)
    if type(request) ~= "table" or request == Addon.inspectActive then
        return
    end
    for index = 1, #Addon.inspectQueue do
        if Addon.inspectQueue[index] == request then
            table.remove(Addon.inspectQueue, index)
            table.insert(Addon.inspectQueue, 1, request)
            return
        end
    end
end

QueueInspectRequest = function(guid, unit, payload, preferFront)
    if type(guid) ~= "string" or guid == "" or type(unit) ~= "string" or unit == "" then
        return nil
    end
    payload = type(payload) == "table" and payload or {}

    local request = Addon.inspectByGuid[guid]
    if not request then
        request = {
            guid = guid,
            unit = unit,
            rows = {},
        }
        Addon.inspectByGuid[guid] = request
        if preferFront then
            table.insert(Addon.inspectQueue, 1, request)
        else
            Addon.inspectQueue[#Addon.inspectQueue + 1] = request
        end
    elseif preferFront then
        MoveQueuedInspectRequestToFront(request)
    end

    if payload.scan then
        request.scan = request.scan or payload.scan
    end
    if payload.row then
        AppendInspectRow(request, payload.row)
    end
    if type(payload.rows) == "table" then
        for index = 1, #payload.rows do
            AppendInspectRow(request, payload.rows[index])
        end
    end
    return request
end

local function FinishInspectRequestRows(request, reason)
    local rows = type(request.rows) == "table" and request.rows or {}
    for index = 1, #rows do
        local row = rows[index]
        if type(row) == "table" and row.inspectPending == true then
            row.inspectPending = false
            row.inspectToken = nil
            if IsRowStillTracked(row) then
                ScheduleInspectRetry(row, reason)
            end
        end
    end
end

local function FinishInspectRequest(request, reason, clearOwned)
    if type(request) ~= "table" then
        return
    end
    if Addon.inspectActive == request then
        Addon.inspectActive = nil
    end
    Addon.inspectByGuid[request.guid] = nil
    if clearOwned then
        ClearOwnedInspectState()
    end
    FinishInspectRequestRows(request, reason)
    if request.scan then
        RequeueEquipmentScan(request.scan, reason)
    end
    SaveDB()
    RefreshRows()
    StartNextInspectRequest()
end

CancelActiveInspectRequest = function(reason, requeueScan)
    local request = Addon.inspectActive
    if not request then
        return false
    end
    Addon.inspectActive = nil
    Addon.inspectByGuid[request.guid] = nil
    if request.scan then
        RecordDiagnostic("scan_cancelled", {
            reason = reason or "unknown",
            looter = request.scan.name,
            attempt = request.scan.attempt or 0,
        })
        if requeueScan then
            table.insert(Addon.equipmentScanQueue, 1, request.scan)
            ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
        end
    end
    ClearOwnedInspectState()
    StartNextInspectRequest()
    return true
end

local function ClearInspectWorkRows()
    local seen = {}
    local function clearList(list)
        if type(list) ~= "table" then
            return
        end
        for index = 1, #list do
            local row = list[index]
            if type(row) == "table" and not seen[row] then
                seen[row] = true
                row.inspectPending = false
                row.inspectToken = nil
                row.inspectRetryCount = nil
                if row.equippedText == EQUIPPED_PENDING then
                    row.equippedText = UNKNOWN_EQUIPPED
                end
            end
        end
    end

    if type(Addon.state) ~= "table" then
        return
    end
    clearList(Addon.state.currentRows)
    clearList(Addon.state.allRows)
    clearList(Addon.state.sessionRows)
    clearList(Addon.state.sessionAllRows)
    local history = Addon.state.history
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" then
                clearList(group.rows)
                clearList(group.allRows)
            end
        end
    end
end

local function CancelAllInspectWork()
    Addon.inspectGeneration = (Addon.inspectGeneration or 0) + 1
    local hadActive = Addon.inspectActive ~= nil
    Addon.inspectActive = nil
    Addon.inspectQueue = {}
    Addon.inspectByGuid = {}
    Addon.equipmentScanQueue = {}
    Addon.equipmentScanScheduled = false
    ClearInspectWorkRows()
    if hadActive then
        ClearOwnedInspectState()
    end
end

StartNextInspectRequest = function()
    if Addon.inspectActive then
        return
    end

    local request = table.remove(Addon.inspectQueue, 1)
    if not request then
        return
    end
    local unit = ResolveInspectRequestUnit(request)
    if not unit then
        FinishInspectRequest(request, "guid_mismatch", false)
        return
    end
    if not CanInspectClean(unit) then
        FinishInspectRequest(request, "inspect_blocked", false)
        return
    end

    local rows = type(request.rows) == "table" and request.rows or {}
    request.token = {}
    request.notified = true
    request.unit = unit
    Addon.inspectActive = request
    Addon.inspectByGuid[request.guid] = request

    if request.scan then
        RecordDiagnostic("scan_requested", {
            reason = request.scan.source or "scan",
            looter = request.scan.name,
            attempt = request.scan.attempt or 0,
        })
    end
    if #rows > 0 then
        RecordDiagnostic("inspect_requested", {
            looter = rows[1].looter,
            equipLoc = rows[1].equipLoc,
            count = #rows,
            attempt = rows[1].inspectRetryCount or 0,
        })
    end
    SafeCall(NotifyInspect, unit)

    local token = request.token
    local timeout = #rows > 0 and INSPECT_RETRY_DELAY or EQUIPMENT_SCAN_TIMEOUT
    local generation = Addon.inspectGeneration or 0
    C_Timer.After(timeout, function()
        if Addon.inspectActive ~= request or request.token ~= token or generation ~= (Addon.inspectGeneration or 0) then
            return
        end
        FinishInspectRequest(request, "inspect_timeout", true)
    end)
end

CompleteActiveInspectRequest = function(guid)
    local request = Addon.inspectActive
    if not request or request.guid ~= guid then
        return false
    end

    Addon.inspectActive = nil
    Addon.inspectByGuid[request.guid] = nil
    local requestUnit = ResolveInspectRequestUnit(request)

    if request.scan then
        if requestUnit and CaptureEquipmentForUnit(requestUnit, request.scan.source or "scan") then
            ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
        else
            RequeueEquipmentScan(request.scan, requestUnit and "links_missing" or "guid_mismatch")
        end
    end

    local rows = type(request.rows) == "table" and request.rows or {}
    for index = 1, #rows do
        local row = rows[index]
        if type(row) == "table" and row.inspectPending == true then
            row.inspectPending = false
            row.inspectToken = nil
            if IsRowStillTracked(row) then
                local unit = ResolveRowUnitForRequest(request, row) or requestUnit
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
    end

    ClearOwnedInspectState()
    SaveDB()
    RefreshRows()
    StartNextInspectRequest()
    return true
end

RequestInspectForRow = function(row)
    if not IsRowStillTracked(row) then
        if type(row) == "table" then
            row.inspectPending = false
            row.inspectToken = nil
        end
        return
    end

    local unit = ResolveUnitForName(row.looter)
    if not unit then
        ScheduleInspectRetry(row, "unit_missing")
        return
    end
    if not CanInspectClean(unit) then
        ScheduleInspectRetry(row, InCombatLockdown and InCombatLockdown() and "combat_lockdown" or "inspect_blocked")
        return
    end

    local guid = SafeUnitGUID(unit)
    if not guid then
        ScheduleInspectRetry(row, "guid_missing")
        return
    end

    local active = Addon.inspectActive
    local activeRows = active and type(active.rows) == "table" and active.rows or nil
    if active and active.guid ~= guid and active.scan and (type(activeRows) ~= "table" or #activeRows == 0) then
        CancelActiveInspectRequest("loot_inspect", true)
        active = Addon.inspectActive
    end

    if not active then
        local equippedText = FormatEquippedText(unit, row.equipLoc)
        if equippedText ~= UNKNOWN_EQUIPPED then
            CaptureEquipmentForUnit(unit, "loot_live")
            CompleteInspectRow(row, equippedText)
            return
        end
    end

    if not IsCachedEquippedText(row.equippedText) then
        row.equippedText = EQUIPPED_PENDING
    end
    row.inspectPending = true
    row.inspectToken = nil
    QueueInspectRequest(guid, unit, { row = row }, true)
    StartNextInspectRequest()
end

local function AddTradeCandidate(looter, itemLink, metadata, context)
    context = type(context) == "table" and context or BuildDropContext(false)
    local playerName = SafePlayerName()
    metadata.lootSource = context.lootSource
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
            lootSource = context.lootSource,
        })
        return false, gearClassification.reason
    end

    local classification = context.unsafe == true
        and { visible = false, reason = context.unsafeReason or "looter_unresolved" }
        or DoYouNeedItCore.ClassifyTradeCandidate(metadata, looter, playerName, Addon.state.settings)
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
            lootSource = context.lootSource,
        })
    end

    local cachedEquippedText = Core.GetCachedEquippedText(Addon.equipmentCache, looter, metadata.equipLoc, Now(), EQUIPMENT_CACHE_MAX_AGE)
    local row = Core.AddVisibleRow(Addon.state, {
        looter = looter,
        classToken = context.classToken or ResolveClassTokenForName(looter),
        itemLink = metadata.link or itemLink,
        equipLoc = metadata.equipLoc,
        itemID = metadata.itemID,
        instanceName = context.instanceName or Addon.currentInstanceName or SafeInstanceName(),
        encounterName = context.encounterName,
        timestamp = context.timestamp or Now(),
        lootSource = context.lootSource,
        reason = askable and "trade candidate" or classification.reason,
        statusKey = askable and "candidate" or (classification.reason or "not_askable"),
        equippedText = cachedEquippedText or UNKNOWN_EQUIPPED,
        unsafe = context.unsafe == true,
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
        lootSource = context.lootSource,
    })
    if not row.unsafe then
        RequestInspectForRow(row)
    end
    if askable then
        ScheduleAutoWhisper(row)
    end
    Addon.selectedTab = DoYouNeedItCore.GetAutoShowTabForRow(Addon.state, row)
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    Addon.EnterLootMode()
    SaveDB()
    RefreshRows()
    if not Addon.ScheduleChallengeHistoryFinalizeIfRecent(context.source or "post_challenge_loot") then
        Addon.ScheduleRecentEncounterHistoryFinalizeIfRecent(context.source or "post_encounter_loot")
    end
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
        statusKey = "test_row",
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
        statusKey = "bind_on_pickup",
        equippedText = UNKNOWN_EQUIPPED,
        unsafe = false,
    }, false)
    Addon.selectedTab = "askable"
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    Addon.EnterLootMode()
    RefreshRows()
    if DoYouNeedItCore.ShouldAutoShowWindow(row) then
        CreateUI()
        Addon.frame:Show()
    end
end

local RetryPendingItem

local function FailPendingItem(itemLink, bucket, reason)
    if Addon.pendingItems[itemLink] == bucket then
        Addon.pendingItems[itemLink] = nil
    end
    local waiters = type(bucket) == "table" and type(bucket.waiters) == "table" and bucket.waiters or {}
    for index = 1, #waiters do
        RecordDiagnostic("metadata_failed", {
            reason = reason or "unresolved_item",
            looter = waiters[index].looter,
            itemLink = itemLink,
            attempt = bucket and bucket.attempts or 0,
        })
    end
end

local function ProcessPendingItem(itemLink, bucket)
    bucket = bucket or Addon.pendingItems[itemLink]
    if type(bucket) ~= "table" or Addon.pendingItems[itemLink] ~= bucket then
        return true
    end
    if bucket.generation ~= (Addon.lootGeneration or 0) then
        return true
    end

    local metadata = ReadItemMetadata(itemLink)
    if not metadata then
        return false
    end

    local waiters = Core.DrainPendingItemWaiters(Addon.pendingItems, itemLink, bucket.generation)
    for index = 1, #waiters do
        local waiter = waiters[index]
        if waiter.generation == (Addon.lootGeneration or 0) then
            AddTradeCandidate(waiter.looter, itemLink, metadata, waiter.context)
        end
    end
    return true
end

local function SchedulePendingItemRetry(itemLink, bucket, delay)
    local token = {}
    bucket.retryToken = token
    local generation = bucket.generation
    C_Timer.After(delay or ITEM_RETRY_DELAY, function()
        if Addon.pendingItems[itemLink] ~= bucket or bucket.retryToken ~= token or bucket.generation ~= generation then
            return
        end
        bucket.retryToken = nil
        RetryPendingItem(itemLink)
    end)
end

RetryPendingItem = function(itemLink)
    local bucket = Addon.pendingItems[itemLink]
    if type(bucket) ~= "table" then
        return
    end
    if bucket.generation ~= (Addon.lootGeneration or 0) then
        return
    end
    if ProcessPendingItem(itemLink, bucket) then
        return
    end

    bucket.attempts = (bucket.attempts or 0) + 1
    if bucket.attempts > MAX_ITEM_RETRIES then
        FailPendingItem(itemLink, bucket, "retry_limit")
        return
    end

    if bucket.loadRequested ~= true and RequestItemLoad(itemLink, function()
        local current = Addon.pendingItems[itemLink]
        if type(current) == "table" and current == bucket and not ProcessPendingItem(itemLink, current) then
            SchedulePendingItemRetry(itemLink, current, ITEM_RETRY_DELAY)
        end
    end) then
        bucket.loadRequested = true
        RecordDiagnostic("metadata_requested", {
            itemLink = itemLink,
            itemID = Core.ExtractItemID(itemLink),
            count = #(bucket.waiters or {}),
        })
        SchedulePendingItemRetry(itemLink, bucket, ITEM_RETRY_DELAY * 3)
        return
    end

    SchedulePendingItemRetry(itemLink, bucket, ITEM_RETRY_DELAY)
end

local function RetryItemLater(looter, itemLink, context)
    context = type(context) == "table" and context or BuildDropContext(false)
    local bucket, created = Core.AddPendingItemWaiter(Addon.pendingItems, itemLink, {
        looter = looter,
        context = context,
        generation = context.generation,
    })
    if not bucket then
        return
    end
    if created then
        RetryPendingItem(itemLink)
    end
end

local function InvalidatePendingLoot()
    Addon.lootGeneration = (Addon.lootGeneration or 0) + 1
    Addon.pendingItems = {}
    Addon.recentLootKeys = {}
end

function Addon.HandleResolvedLoot(looter, itemLink, context, source)
    itemLink = ExtractItemLink(itemLink) or CleanString(itemLink)
    if not itemLink then
        RecordDiagnostic("no_item_link", {
            source = source or "unknown",
        })
        return
    end

    if not looter then
        RecordDiagnostic("no_looter", {
            itemLink = itemLink,
            source = source or "unknown",
        })
        return
    end

    context = type(context) == "table" and context or BuildDropContext(false)
    context.source = source or context.source
    if context.lootSource == "bonus_roll"
        and (Addon.UpgradeTrackedLootToBonus(looter, itemLink, context, source)
            or Addon.UpgradePendingLootToBonus(looter, itemLink, context, source))
    then
        return
    end

    local duplicate, duplicateItemID = Addon.ShouldSkipDuplicateLoot(looter, itemLink)
    if duplicate then
        if Addon.UpgradeTrackedLootToBonus(looter, itemLink, context, source)
            or Addon.UpgradePendingLootToBonus(looter, itemLink, context, source)
        then
            return
        end
        local row = Addon.FindTrackedLootRow(looter, itemLink) or Addon.FindTrackedLootRowByItemID(looter, duplicateItemID)
        if Addon.UpdateTrackedLootLink(row, itemLink, source) then
            RecordDiagnostic("duplicate_loot_link_updated", {
                looter = looter,
                itemLink = itemLink,
                itemID = duplicateItemID,
                source = source or "unknown",
            })
            SaveDB()
            RefreshRows()
        end
        RecordDiagnostic("duplicate_loot", {
            looter = looter,
            itemLink = itemLink,
            source = source or "unknown",
        })
        return
    end

    local metadata = ReadItemMetadata(itemLink)
    if not metadata then
        RecordDiagnostic("metadata_pending", {
            looter = looter,
            itemLink = itemLink,
            source = source or "unknown",
        })
        RetryItemLater(looter, itemLink, context)
        return
    end

    AddTradeCandidate(looter, itemLink, metadata, context)
end

local function HandleLootMessage(message, ...)
    RecordDiagnostic("loot_event", {
        message = CleanString(message),
        source = "chat",
    })

    local itemLink = ExtractItemLink(message)
    local looter, unsafe, unsafeReason, lootSource = FindLooterFromMessage(message, ...)
    local context = BuildDropContext(unsafe, unsafeReason)
    context.lootSource = lootSource
    Addon.HandleResolvedLoot(looter, itemLink, context, "chat")
end

function Addon.HandleEncounterLootReceived(encounterID, itemID, itemLink, quantity, playerName, classFileName)
    RecordDiagnostic("loot_event", {
        source = "encounter",
        itemID = tonumber(itemID),
        looter = CleanString(playerName),
        classToken = CleanString(classFileName),
    })

    local looter = Addon.ResolveEncounterLootLooter(playerName)
    local context = BuildDropContext(false)
    context.classToken = CleanString(classFileName)
    Addon.HandleResolvedLoot(looter, itemLink, context, "encounter")
end

function Addon.CompleteCurrentGroup(encounterName)
    if not Addon.state or (#Addon.state.currentRows == 0 and #(Addon.state.allRows or {}) == 0) then
        return
    end
    Core.CompleteCurrentGroup(Addon.state, {
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = encounterName or Addon.currentEncounterName or Core.FirstRowEncounterName(Addon.state.currentRows) or Core.FirstRowEncounterName(Addon.state.allRows),
        locale = ActiveLocale(),
        startedAt = Addon.currentEncounterStartedAt,
        endedAt = Now(),
    })
    Addon.selectedView = "history"
    Addon.selectedHistoryIndex = 1
    Addon.challengeFinalizeToken = nil
    Addon.recentEncounterFinalizeToken = nil
    Addon.EnterLootMode()
    SaveDB()
    RefreshRows()
end

local function SelectView(view, historyIndex)
    Addon.selectedView = view
    Addon.selectedHistoryIndex = historyIndex
    Addon.EnterLootMode()
    RefreshRows()
end

local function SelectTab(tab)
    Addon.selectedTab = tab == "all" and "all" or "askable"
    Addon.EnterLootMode()
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
            rootDescription:CreateButton(L("Current"), function()
                SelectView("current")
            end)
            rootDescription:CreateButton(L("This Session"), function()
                SelectView("session")
            end)
            for index = 1, #Addon.state.history do
                local group = Addon.state.history[index]
                rootDescription:CreateButton(group.title or (L("History") .. " " .. index), function()
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
    row.looter:SetWidth(ROW_LOOTER_WIDTH)
    row.looter:SetJustifyH("LEFT")
    KeepOneLine(row.looter)
    RegisterFontString(row.looter, 11, nil, false, true)

    row.drop = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.drop:SetPoint("LEFT", row.looter, "RIGHT", 8, 0)
    row.drop:SetWidth(ROW_DROP_WIDTH)
    row.drop:SetJustifyH("LEFT")
    KeepOneLine(row.drop)
    RegisterFontString(row.drop, 11, nil, false, true)

    row.rollIcon = row:CreateTexture(nil, "OVERLAY")
    row.rollIcon:SetSize(14, 14)
    row.rollIcon:SetPoint("LEFT", row.looter, "RIGHT", 6, 0)
    row.rollIcon:SetAtlas("lootroll-toast-icon-need-up")
    row.rollIcon:Hide()

    row.dropLink = CreateFrame("Button", nil, row)
    row.dropLink:SetPoint("LEFT", row.looter, "RIGHT", 6, 0)
    row.dropLink:SetSize(ROW_DROP_HOVER_WIDTH, ROW_HEIGHT)
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
    row.equipped:SetPoint("LEFT", row.drop, "RIGHT", 10, 0)
    row.equipped:SetWidth(ROW_EQUIPPED_WIDTH)
    row.equipped:SetJustifyH("LEFT")
    KeepOneLine(row.equipped)
    RegisterFontString(row.equipped, 11, nil, false, true)

    row.equippedLink = CreateFrame("Button", nil, row)
    row.equippedLink:SetPoint("LEFT", row.drop, "RIGHT", 8, 0)
    row.equippedLink:SetSize(ROW_EQUIPPED_HOVER_WIDTH, ROW_HEIGHT)
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
    row.status:SetWidth(ROW_STATUS_WIDTH)
    row.status:SetJustifyH("LEFT")
    KeepOneLine(row.status)
    RegisterFontString(row.status, 10, nil, false, true)

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
    RegisterButtonFont(row.whisper, 11)

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
    frame:SetScript("OnHide", function()
        if type(Addon.EnterLootMode) == "function" then
            Addon.EnterLootMode()
        else
            Addon.contentMode = "loot"
        end
    end)
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
    frame.title:SetWidth(210)
    frame.title:SetJustifyH("LEFT")
    KeepOneLine(frame.title)
    frame.title:SetText(L("Do You Need It?"))
    RegisterFontString(frame.title, 16, "OUTLINE")

    frame.tabAskable = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.tabAskable:SetSize(HEADER_TAB_ASKABLE_WIDTH, 22)
    frame.tabAskable:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42)
    frame.tabAskable:SetText(L("Askable"))
    frame.tabAskable:SetScript("OnClick", function()
        SelectTab("askable")
    end)
    RegisterButtonFont(frame.tabAskable, 11)
    Addon.tabAskable = frame.tabAskable

    frame.tabAllGear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.tabAllGear:SetSize(HEADER_TAB_ALL_WIDTH, 22)
    frame.tabAllGear:SetPoint("LEFT", frame.tabAskable, "RIGHT", 4, 0)
    frame.tabAllGear:SetText(L("All Gear"))
    frame.tabAllGear:SetScript("OnClick", function()
        SelectTab("all")
    end)
    RegisterButtonFont(frame.tabAllGear, 11)
    Addon.tabAllGear = frame.tabAllGear

    frame.historyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.historyButton:SetSize(HEADER_HISTORY_WIDTH, 22)
    frame.historyButton:SetPoint("LEFT", frame.tabAllGear, "RIGHT", 6, 0)
    frame.historyButton:SetText(L("Current"))
    frame.historyButton:SetScript("OnClick", function(button)
        OpenHistoryMenu(button)
    end)
    RegisterButtonFont(frame.historyButton, 11)
    Addon.historyButton = frame.historyButton

    frame.settingsButton = CreateFrame("Button", nil, frame)
    frame.settingsButton:SetSize(22, 22)
    frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -8)
    frame.settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.settingsButton:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.settingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.settingsButton:SetScript("OnEnter", function(button)
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(L("Settings"))
            GameTooltip:Show()
        end
    end)
    frame.settingsButton:SetScript("OnLeave", HideItemTooltip)
    frame.settingsButton:SetScript("OnClick", OpenSettings)
    Addon.settingsButton = frame.settingsButton

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.emptyText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.emptyText:SetText(L("No askable gear drops in this view."))
    RegisterFontString(frame.emptyText, 12)
    Addon.emptyText = frame.emptyText

    for index = 1, MAX_VISIBLE_ROWS do
        Addon.rowFrames[index] = CreateRow(frame, index)
    end

    Addon.frame = frame
    frame:Hide()
    RefreshRows()
end

local function StripParenSuffix(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^(.-)%s*%(") or text
end

local function LanguageDisplayLabel(option)
    if option.value ~= "auto" then
        return option.label
    end
    local current = ClientLocale()
    local currentOption = Core.GetLanguageOption(current)
    return string.format(L("Auto (current: %s)"), StripParenSuffix((currentOption and currentOption.label) or current))
end

local function LanguageCompactLabel(option)
    if option.value == "auto" then
        local current = ClientLocale()
        local currentOption = Core.GetLanguageOption(current)
        return (currentOption and (currentOption.compactLabel or StripParenSuffix(currentOption.label))) or current
    end
    return option.compactLabel or StripParenSuffix(option.label)
end

local function CurrentLanguageLabel()
    local option = Core.GetLanguageOption(Addon.state.settings.forceLocale) or Core.GetLanguageOption("auto")
    return LanguageCompactLabel(option)
end

local function GetDropdownChild(dropdown, suffix)
    if not dropdown then
        return nil
    end
    if type(suffix) == "string" and dropdown[suffix] then
        return dropdown[suffix]
    end
    local name = type(dropdown.GetName) == "function" and dropdown:GetName()
    if not name then
        return nil
    end
    return _G[name .. suffix]
end

local function DropdownCaptionFont()
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    return StableSettingsFont(), Core.ResolveFontSize(12, settings.fontSize)
end

local function ShowDropdownPart(dropdown, suffix)
    local part = GetDropdownChild(dropdown, suffix)
    if part then
        SafeCall(part.Show, part)
        SafeCall(part.SetAlpha, part, 1)
    end
    return part
end

local function SetDropdownTextSafe(dropdown, text)
    if not dropdown then
        return
    end
    SafeCall(UIDropDownMenu_SetText, dropdown, text or "")
    local font, size = DropdownCaptionFont()
    local textRegion = ShowDropdownPart(dropdown, "Text")
    if textRegion then
        SafeCall(textRegion.SetFont, textRegion, font, size, "")
        SafeCall(textRegion.SetText, textRegion, text or "")
    end
    local button = ShowDropdownPart(dropdown, "Button")
    if button then
        SafeCall(button.Enable, button)
    end
    ShowDropdownPart(dropdown, "Left")
    ShowDropdownPart(dropdown, "Middle")
    ShowDropdownPart(dropdown, "Right")
end

local function ConfigureSliderTemplateLabels(slider, lowText, highText)
    if not slider then
        return
    end
    local font, size = DropdownCaptionFont()
    local valueText = GetDropdownChild(slider, "Text")
    if valueText then
        SafeCall(valueText.SetText, valueText, "")
        SafeCall(valueText.SetFont, valueText, font, size, "")
        SafeCall(valueText.Hide, valueText)
    end
    local low = GetDropdownChild(slider, "Low")
    if low then
        SafeCall(low.SetText, low, lowText or "")
        SafeCall(low.SetFont, low, font, size, "")
        SafeCall(low.Show, low)
    end
    local high = GetDropdownChild(slider, "High")
    if high then
        SafeCall(high.SetText, high, highText or "")
        SafeCall(high.SetFont, high, font, size, "")
        SafeCall(high.Show, high)
    end
end

local function RefreshFontWarning()
    if not Addon.fontWarning or not Addon.state then
        return
    end
    local active = ActiveLocale()
    local requiredGlyph = Core.GetLocaleGlyphRequirement(active)
    local font = Addon.previewFont or Addon.state.settings.font
    if Core.FontSupports(font, requiredGlyph, ClientLocale()) then
        Addon.fontWarning:SetText("")
    else
        Addon.fontWarning:SetText(string.format(L("Font may not render %s glyphs."), requiredGlyph))
    end
end

RefreshSettingsControls = function()
    if not Addon.settingsFrame or not Addon.state then
        return
    end
    local settings = Addon.state.settings
    if Addon.settingsTitle then
        Addon.settingsTitle:SetText(L("Settings"))
    end
    if Addon.settingsBackButton then
        Addon.settingsBackButton:SetText(L("Back"))
    end
    if Addon.autoCheck then
        Addon.autoCheck:SetChecked(settings.autoWhisper == true)
    end
    if Addon.autoCheckLabel then
        Addon.autoCheckLabel:SetText(L("Auto whisper"))
    end
    if Addon.delayLabel then
        Addon.delayLabel:SetText(L("Delay"))
    end
    if Addon.delaySlider then
        Addon.updatingControls = true
        Addon.delaySlider:SetValue(settings.autoDelay)
        Addon.updatingControls = false
        ConfigureSliderTemplateLabels(Addon.delaySlider, L("Low"), L("High"))
    end
    if Addon.delayValue then
        Addon.delayValue:SetText(settings.autoDelay .. "s")
    end
    if Addon.whisperLabel then
        Addon.whisperLabel:SetText(L("Whisper text:"))
    end
    if Addon.whisperEditBox and not Addon.whisperTemplateFocused and Addon.whisperEditBox:GetText() ~= settings.whisperTemplate then
        Addon.whisperEditBox:SetText(settings.whisperTemplate)
    end
    if Addon.whisperResetButton then
        Addon.whisperResetButton:SetText(L("Reset"))
    end
    if Addon.languageLabel then
        Addon.languageLabel:SetText(L("Language:"))
    end
    if Addon.fontLabel then
        Addon.fontLabel:SetText(L("Font:"))
    end
    if Addon.fontSizeLabel then
        Addon.fontSizeLabel:SetText(L("Font Size:"))
    end
    if Addon.fontSizeSlider then
        Addon.updatingControls = true
        Addon.fontSizeSlider:SetValue(settings.fontSize)
        Addon.updatingControls = false
        ConfigureSliderTemplateLabels(Addon.fontSizeSlider, L("Low"), L("High"))
    end
    if Addon.fontSizeValue then
        Addon.fontSizeValue:SetText(settings.fontSize)
    end
    if Addon.languageDropdown then
        SetDropdownTextSafe(Addon.languageDropdown, CurrentLanguageLabel())
    end
    if Addon.fontDropdown then
        SetDropdownTextSafe(Addon.fontDropdown, FindFontName(settings.font))
    end
    RefreshFontWarning()
end

RefreshLocalization = function()
    if Addon.frame and Addon.frame.title then
        Addon.frame.title:SetText(L("Do You Need It?"))
    end
    RefreshRows()
    RefreshSettingsControls()
end

local function ScheduleSettingsControlsRefresh()
    local function refreshIfVisible()
        if Addon.settingsFrame and (type(Addon.settingsFrame.IsShown) ~= "function" or Addon.settingsFrame:IsShown()) then
            RefreshSettingsControls()
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, refreshIfVisible)
    else
        refreshIfVisible()
    end
end

local function SetFontSize(value)
    Addon.state.settings.fontSize = tonumber(value) or Addon.state.settings.fontSize
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    ApplyCurrentFont()
    RefreshSettingsControls()
end

local function SetFontPath(path)
    if type(path) ~= "string" or path == "" then
        return
    end
    Addon.previewFont = nil
    Addon.state.settings.font = path
    Addon.state.settings.fontBeforeAutoSwitch = nil
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    ApplyCurrentFont()
    RefreshSettingsControls()
end

local function SetForceLocale(value)
    Addon.previewLocale = nil
    Addon.previewFont = nil
    Addon.state.settings.forceLocale = Core.NormalizeForceLocale(value)
    MaybeAutoSwitchFont()
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    ApplyCurrentFont()
    RefreshLocalization()
end

local function PreviewLanguage(value)
    local locale = Core.ResolveActiveLocale(value, ClientLocale())
    if Addon.previewLocale == locale then
        return
    end
    Addon.previewLocale = locale
    local requiredGlyph = Core.GetLocaleGlyphRequirement(locale)
    local fallback = Core.FindCompatibleFont(Addon.state.settings.font, requiredGlyph, BuildFontsList(locale), ClientLocale())
    if fallback and not Core.SameFontPath(fallback, Addon.state.settings.font) then
        Addon.previewFont = fallback
    else
        Addon.previewFont = nil
    end
    ApplyCurrentFont()
    RefreshLocalization()
end

local function CancelLanguagePreview()
    if not Addon.previewLocale then
        return
    end
    Addon.previewLocale = nil
    Addon.previewFont = nil
    ApplyCurrentFont()
    RefreshLocalization()
end

local function PreviewFont(path)
    if type(path) ~= "string" or path == "" then
        return
    end
    if Core.SameFontPath(path, Addon.previewFont) then
        return
    end
    Addon.previewFont = path
    ApplyCurrentFont()
    RefreshSettingsControls()
end

local function CancelFontPreview()
    Addon.previewFont = nil
    ApplyCurrentFont()
    RefreshSettingsControls()
end

local function CancelSettingsPreview()
    Addon.previewLocale = nil
    Addon.previewFont = nil
    ApplyCurrentFont()
    RefreshLocalization()
end

local function HideFontPicker()
    if Addon.fontPickerFrame and Addon.fontPickerFrame:IsShown() then
        Addon.fontPickerFrame:Hide()
    end
    if Addon.fontPickerCatcher and Addon.fontPickerCatcher:IsShown() then
        Addon.fontPickerCatcher:Hide()
    end
end

local function BuildFontPickerFrame()
    local cols = 3
    local buttonWidth = 160
    local buttonHeight = 22
    local pad = 8
    local scrollbarWidth = 22
    local visibleRows = 14
    local frameWidth = cols * buttonWidth + pad * 2 + scrollbarWidth
    local frameHeight = visibleRows * buttonHeight + pad * 2

    local picker = CreateFrame("Frame", "DoYouNeedItFontPicker", UIParent, "BackdropTemplate")
    picker:SetSize(frameWidth, frameHeight)
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel((Addon.settingsFrame and Addon.settingsFrame:GetFrameLevel() or 100) + 50)
    picker:SetClampedToScreen(true)
    picker:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    picker:SetBackdropColor(0, 0, 0, 0.92)
    picker:Hide()

    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:SetFrameLevel(picker:GetFrameLevel() - 1)
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", HideFontPicker)

    local scroll = CreateFrame("ScrollFrame", "DoYouNeedItFontPickerScroll", picker, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pad, -pad)
    scroll:SetPoint("BOTTOMRIGHT", -(pad + scrollbarWidth), pad)

    local content = CreateFrame("Frame", "DoYouNeedItFontPickerContent", scroll)
    content:SetSize(cols * buttonWidth, 1)
    scroll:SetScrollChild(content)

    picker:SetScript("OnHide", function()
        if Addon.fontPickerCatcher then
            Addon.fontPickerCatcher:Hide()
        end
        CancelFontPreview()
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "DoYouNeedItFontPicker")
    end

    Addon.fontPickerFrame = picker
    Addon.fontPickerCatcher = catcher
    Addon.fontPickerScroll = scroll
    Addon.fontPickerContent = content
    Addon.fontPickerButtons = {}
end

local function PopulateFontPicker()
    if not Addon.fontPickerContent then
        return
    end

    local cols = 3
    local buttonWidth = 160
    local buttonHeight = 22
    local visibleRows = 14
    local fonts = BuildFontsList(ActiveLocale())
    local currentPath = Addon.state and Addon.state.settings and Addon.state.settings.font
    local rows = math.ceil(#fonts / cols)
    local currentRow

    Addon.fontPickerContent:SetHeight(math.max(rows * buttonHeight, 1))

    for index, font in ipairs(fonts) do
        local button = Addon.fontPickerButtons[index]
        if not button then
            button = CreateFrame("Button", nil, Addon.fontPickerContent)
            button:SetSize(buttonWidth, buttonHeight)

            button.bg = button:CreateTexture(nil, "BACKGROUND")
            button.bg:SetAllPoints()
            button.bg:SetColorTexture(0, 0, 0, 0)

            button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
            local highlight = SafeCall(button.GetHighlightTexture, button)
            if highlight then
                SafeCall(highlight.SetBlendMode, highlight, "ADD")
                SafeCall(highlight.SetVertexColor, highlight, 1, 1, 1, 0.4)
            end

            button.text = button:CreateFontString(nil, "OVERLAY")
            RegisterFontString(button.text, 12, nil, true)
            button.text:SetPoint("LEFT", 6, 0)
            button.text:SetPoint("RIGHT", -4, 0)
            button.text:SetJustifyH("LEFT")
            if button.text.SetWordWrap then
                button.text:SetWordWrap(false)
            end
            if button.text.SetMaxLines then
                button.text:SetMaxLines(1)
            end

            button:SetScript("OnEnter", function(btn)
                Addon.fontPickerHoverGen = (Addon.fontPickerHoverGen or 0) + 1
                PreviewFont(btn.fontPath)
            end)
            button:SetScript("OnLeave", function()
                local generation = Addon.fontPickerHoverGen or 0
                local function restoreIfStillAway()
                    if generation == (Addon.fontPickerHoverGen or 0) then
                        CancelFontPreview()
                    end
                end
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0, restoreIfStillAway)
                else
                    restoreIfStillAway()
                end
            end)
            button:SetScript("OnClick", function(btn)
                SetFontPath(btn.fontPath)
                HideFontPicker()
            end)

            Addon.fontPickerButtons[index] = button
        end

        local row = math.floor((index - 1) / cols)
        local col = (index - 1) % cols
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", col * buttonWidth, -row * buttonHeight)
        button.fontName = font.name
        button.fontPath = font.path
        button.text:SetText(font.name)
        if Core.SameFontPath(font.path, currentPath) then
            button.bg:SetColorTexture(0, 1, 0.5, 0.18)
            currentRow = row
        else
            button.bg:SetColorTexture(0, 0, 0, 0)
        end
        button:Show()
    end

    for index = #fonts + 1, #(Addon.fontPickerButtons or {}) do
        Addon.fontPickerButtons[index]:Hide()
    end

    if Addon.fontPickerScroll then
        if currentRow then
            local centerOffset = math.floor(visibleRows / 2)
            local targetScroll = math.max(0, (currentRow - centerOffset) * buttonHeight)
            local maxScroll = math.max(0, rows * buttonHeight - visibleRows * buttonHeight)
            Addon.fontPickerScroll:SetVerticalScroll(math.min(targetScroll, maxScroll))
        else
            Addon.fontPickerScroll:SetVerticalScroll(0)
        end
    end
end

local function ShowFontPicker()
    if not Addon.fontPickerFrame then
        BuildFontPickerFrame()
    end
    Addon.previewFont = nil
    Addon.fontPickerHoverGen = (Addon.fontPickerHoverGen or 0) + 1
    PopulateFontPicker()

    local frameLevel = (Addon.settingsFrame and Addon.settingsFrame:GetFrameLevel() or 100) + 50
    Addon.fontPickerFrame:SetFrameLevel(frameLevel)
    if Addon.fontPickerCatcher then
        Addon.fontPickerCatcher:SetFrameLevel(frameLevel - 1)
    end

    local button = _G["DoYouNeedItFontDropdownButton"] or (Addon.fontDropdown and Addon.fontDropdown.Button)
    Addon.fontPickerFrame:ClearAllPoints()
    if button then
        Addon.fontPickerFrame:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    elseif Addon.fontDropdown then
        Addon.fontPickerFrame:SetPoint("TOPLEFT", Addon.fontDropdown, "BOTTOMLEFT", 16, -2)
    else
        Addon.fontPickerFrame:SetPoint("CENTER")
    end
    if Addon.fontPickerCatcher then
        Addon.fontPickerCatcher:Show()
    end
    Addon.fontPickerFrame:Show()
end

local function ToggleFontPicker()
    if Addon.fontPickerFrame and Addon.fontPickerFrame:IsShown() then
        HideFontPicker()
        return
    end
    SafeCall(CloseDropDownMenus)
    ShowFontPicker()
end

local function HookSettingsDropdownButtons()
    if not DropDownList1 then
        return
    end
    for index = 1, 64 do
        local button = _G["DropDownList1Button" .. index]
        if not button then
            break
        end
        if not button._dyniPreviewHooked then
            button:HookScript("OnEnter", function(btn)
                Addon.dropdownPreviewGen = (Addon.dropdownPreviewGen or 0) + 1
                if UIDROPDOWNMENU_OPEN_MENU == Addon.languageDropdown and btn.value ~= nil then
                    PreviewLanguage(btn.value)
                end
            end)
            button:HookScript("OnLeave", function()
                local generation = Addon.dropdownPreviewGen or 0
                local function restoreIfStillAway()
                    if generation ~= (Addon.dropdownPreviewGen or 0) then
                        return
                    end
                    if UIDROPDOWNMENU_OPEN_MENU == Addon.languageDropdown then
                        CancelLanguagePreview()
                    end
                end
                if C_Timer and type(C_Timer.After) == "function" then
                    C_Timer.After(0, restoreIfStillAway)
                else
                    restoreIfStillAway()
                end
            end)
            button._dyniPreviewHooked = true
        end
    end
end

local function EnsureDropdownPreviewHooks()
    if DropDownList1 and not DropDownList1._dyniPreviewHooks then
        DropDownList1:HookScript("OnShow", HookSettingsDropdownButtons)
        DropDownList1:HookScript("OnHide", function()
            CancelLanguagePreview()
            CancelFontPreview()
            ScheduleSettingsControlsRefresh()
        end)
        DropDownList1._dyniPreviewHooks = true
    end
end

local function ArmDropdownPreviewHooks()
    EnsureDropdownPreviewHooks()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            EnsureDropdownPreviewHooks()
            HookSettingsDropdownButtons()
        end)
    end
end

function Addon.CommitFocusedWhisperTemplate()
    if Addon.whisperEditBox and Addon.whisperTemplateFocused and not Addon.committingWhisperTemplate then
        Addon.committingWhisperTemplate = true
        Addon.whisperTemplateFocused = false
        SetWhisperTemplate(Addon.whisperEditBox:GetText())
        Addon.committingWhisperTemplate = false
    end
end

function Addon.EnterLootMode()
    local leavingSettings = Addon.contentMode == "settings" or (Addon.settingsFrame and Addon.settingsFrame:IsShown())
    if leavingSettings then
        Addon.CommitFocusedWhisperTemplate()
        HideFontPicker()
        SafeCall(CloseDropDownMenus)
        CancelSettingsPreview()
    end
    Addon.contentMode = "loot"
    if Addon.settingsFrame and Addon.settingsFrame:IsShown() then
        Addon.settingsFrame:Hide()
    end
end

function Addon.CloseSettings()
    Addon.EnterLootMode()
    RefreshRows()
end

CreateSettingsUI = function()
    if Addon.settingsFrame then
        return
    end

    if not Addon.frame then
        CreateUI()
    end

    local frame = CreateFrame("Frame", "DoYouNeedItSettingsFrame", Addon.frame)
    frame:SetSize(508, 232)
    frame:SetPoint("TOPLEFT", Addon.frame, "TOPLEFT", 16, -50)
    frame:SetFrameLevel((Addon.frame and Addon.frame:GetFrameLevel() or 0) + 5)
    frame:EnableMouse(true)
    frame:SetScript("OnHide", function()
        Addon.CommitFocusedWhisperTemplate()
        HideFontPicker()
        CancelSettingsPreview()
    end)

    frame.back = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.back:SetSize(70, 22)
    frame.back:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 2)
    frame.back:SetScript("OnClick", function()
        Addon.CloseSettings()
    end)
    RegisterButtonFont(frame.back, 11, nil, true)
    Addon.settingsBackButton = frame.back

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("LEFT", frame.back, "RIGHT", 12, 0)
    frame.title:SetWidth(240)
    KeepOneLine(frame.title)
    frame.title:SetText(L("Settings"))
    RegisterFontString(frame.title, 16, "OUTLINE", true)
    Addon.settingsTitle = frame.title

    frame.headerRule = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerRule:SetColorTexture(1, 0.82, 0, 0.20)
    frame.headerRule:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -28)
    frame.headerRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -28)
    frame.headerRule:SetHeight(1)

    local y = -44
    frame.autoCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.autoCheck:SetSize(24, 24)
    frame.autoCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, y)
    frame.autoCheck:SetScript("OnClick", function(check)
        SetAutoWhisper(check:GetChecked() == true)
    end)
    Addon.autoCheck = frame.autoCheck

    frame.autoCheckLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.autoCheckLabel:SetPoint("LEFT", frame.autoCheck, "RIGHT", 4, 0)
    frame.autoCheckLabel:SetWidth(360)
    KeepOneLine(frame.autoCheckLabel)
    RegisterFontString(frame.autoCheckLabel, 12, nil, true)
    Addon.autoCheckLabel = frame.autoCheckLabel

    y = y - 34
    frame.delayLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.delayLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    frame.delayLabel:SetWidth(SETTINGS_LABEL_WIDTH)
    KeepOneLine(frame.delayLabel)
    RegisterFontString(frame.delayLabel, 12, nil, true)
    Addon.delayLabel = frame.delayLabel

    frame.delaySlider = CreateFrame("Slider", "DoYouNeedItDelaySlider", frame, "OptionsSliderTemplate")
    frame.delaySlider:SetPoint("TOPLEFT", frame, "TOPLEFT", SETTINGS_CONTROL_X, y - 4)
    frame.delaySlider:SetSize(SETTINGS_SLIDER_WIDTH, 18)
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
    frame.delayValue:SetPoint("LEFT", frame.delaySlider, "RIGHT", 12, 0)
    frame.delayValue:SetWidth(40)
    frame.delayValue:SetJustifyH("LEFT")
    RegisterFontString(frame.delayValue, 12, nil, true)
    Addon.delayValue = frame.delayValue

    y = y - 39
    frame.whisperLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.whisperLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    frame.whisperLabel:SetWidth(SETTINGS_LABEL_WIDTH)
    KeepOneLine(frame.whisperLabel)
    RegisterFontString(frame.whisperLabel, 12, nil, true)
    Addon.whisperLabel = frame.whisperLabel

    frame.whisperEditBox = CreateFrame("EditBox", "DoYouNeedItWhisperEditBox", frame, "InputBoxTemplate")
    frame.whisperEditBox:SetPoint("TOPLEFT", frame, "TOPLEFT", SETTINGS_CONTROL_X, y - 3)
    frame.whisperEditBox:SetSize(SETTINGS_EDITBOX_WIDTH, 22)
    if frame.whisperEditBox.SetAutoFocus then
        frame.whisperEditBox:SetAutoFocus(false)
    end
    if frame.whisperEditBox.SetMaxLetters then
        frame.whisperEditBox:SetMaxLetters(Core.MAX_WHISPER_TEMPLATE_LENGTH)
    end
    frame.whisperEditBox:SetScript("OnEditFocusGained", function()
        Addon.whisperTemplateFocused = true
    end)
    frame.whisperEditBox:SetScript("OnEnterPressed", function(editBox)
        if Addon.committingWhisperTemplate then
            return
        end
        Addon.committingWhisperTemplate = true
        Addon.whisperTemplateFocused = false
        SetWhisperTemplate(editBox:GetText())
        SafeCall(editBox.ClearFocus, editBox)
        Addon.committingWhisperTemplate = false
    end)
    frame.whisperEditBox:SetScript("OnEditFocusLost", function(editBox)
        if Addon.committingWhisperTemplate then
            return
        end
        Addon.committingWhisperTemplate = true
        Addon.whisperTemplateFocused = false
        SetWhisperTemplate(editBox:GetText())
        Addon.committingWhisperTemplate = false
    end)
    frame.whisperEditBox:SetScript("OnEscapePressed", function(editBox)
        Addon.whisperTemplateFocused = false
        editBox:SetText(Addon.state.settings.whisperTemplate)
        SafeCall(editBox.ClearFocus, editBox)
    end)
    RegisterFontString(frame.whisperEditBox, 12, nil, true)
    Addon.whisperEditBox = frame.whisperEditBox

    frame.whisperResetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.whisperResetButton:SetPoint("LEFT", frame.whisperEditBox, "RIGHT", 8, 0)
    frame.whisperResetButton:SetSize(58, 22)
    frame.whisperResetButton:SetScript("OnClick", function()
        Addon.whisperTemplateFocused = false
        SetWhisperTemplate(nil)
        SafeCall(frame.whisperEditBox.ClearFocus, frame.whisperEditBox)
    end)
    RegisterButtonFont(frame.whisperResetButton, 11, nil, true)
    Addon.whisperResetButton = frame.whisperResetButton

    y = y - 39
    frame.languageLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.languageLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    frame.languageLabel:SetWidth(SETTINGS_LABEL_WIDTH)
    KeepOneLine(frame.languageLabel)
    RegisterFontString(frame.languageLabel, 12, nil, true)
    Addon.languageLabel = frame.languageLabel

    frame.languageDropdown = CreateFrame("Frame", "DoYouNeedItLanguageDropdown", frame, "UIDropDownMenuTemplate")
    frame.languageDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", SETTINGS_CONTROL_X - 16, y - 8)
    UIDropDownMenu_SetWidth(frame.languageDropdown, SETTINGS_DROPDOWN_WIDTH)
    UIDropDownMenu_JustifyText(frame.languageDropdown, "CENTER")
    UIDropDownMenu_Initialize(frame.languageDropdown, function()
        local current = Addon.state.settings.forceLocale
        local options = Core.GetLanguageOptions()
        for index = 1, #options do
            local option = options[index]
            local info = UIDropDownMenu_CreateInfo()
            info.text = LanguageDisplayLabel(option)
            info.value = option.value
            info.checked = current == option.value
            info.func = function()
                SetForceLocale(option.value)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Addon.languageDropdown = frame.languageDropdown
    local languageButton = _G["DoYouNeedItLanguageDropdownButton"] or frame.languageDropdown.Button
    if languageButton then
        languageButton:HookScript("OnClick", function()
            HideFontPicker()
            ArmDropdownPreviewHooks()
        end)
    end

    y = y - 39
    frame.fontLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.fontLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    frame.fontLabel:SetWidth(SETTINGS_LABEL_WIDTH)
    KeepOneLine(frame.fontLabel)
    RegisterFontString(frame.fontLabel, 12, nil, true)
    Addon.fontLabel = frame.fontLabel

    frame.fontDropdown = CreateFrame("Frame", "DoYouNeedItFontDropdown", frame, "UIDropDownMenuTemplate")
    frame.fontDropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", SETTINGS_CONTROL_X - 16, y - 8)
    UIDropDownMenu_SetWidth(frame.fontDropdown, SETTINGS_DROPDOWN_WIDTH)
    UIDropDownMenu_JustifyText(frame.fontDropdown, "CENTER")
    Addon.fontDropdown = frame.fontDropdown
    local fontButton = _G["DoYouNeedItFontDropdownButton"] or frame.fontDropdown.Button
    if fontButton then
        fontButton:SetScript("OnClick", ToggleFontPicker)
    end

    y = y - 39
    frame.fontSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.fontSizeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    frame.fontSizeLabel:SetWidth(SETTINGS_LABEL_WIDTH)
    KeepOneLine(frame.fontSizeLabel)
    RegisterFontString(frame.fontSizeLabel, 12, nil, true)
    Addon.fontSizeLabel = frame.fontSizeLabel

    frame.fontSizeSlider = CreateFrame("Slider", "DoYouNeedItFontSizeSlider", frame, "OptionsSliderTemplate")
    frame.fontSizeSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", SETTINGS_CONTROL_X, y - 4)
    frame.fontSizeSlider:SetSize(SETTINGS_SLIDER_WIDTH, 18)
    frame.fontSizeSlider:SetMinMaxValues(8, 24)
    frame.fontSizeSlider:SetValueStep(1)
    if frame.fontSizeSlider.SetObeyStepOnDrag then
        frame.fontSizeSlider:SetObeyStepOnDrag(true)
    end
    frame.fontSizeSlider:SetScript("OnValueChanged", function(_, value)
        if Addon.updatingControls then
            return
        end
        SetFontSize(math.floor((tonumber(value) or 12) + 0.5))
    end)
    Addon.fontSizeSlider = frame.fontSizeSlider

    frame.fontSizeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.fontSizeValue:SetPoint("LEFT", frame.fontSizeSlider, "RIGHT", 12, 0)
    frame.fontSizeValue:SetWidth(40)
    frame.fontSizeValue:SetJustifyH("LEFT")
    RegisterFontString(frame.fontSizeValue, 12, nil, true)
    Addon.fontSizeValue = frame.fontSizeValue

    frame.fontWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.fontWarning:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -248)
    frame.fontWarning:SetWidth(460)
    frame.fontWarning:SetJustifyH("LEFT")
    KeepOneLine(frame.fontWarning)
    frame.fontWarning:SetTextColor(1, 0.6, 0.2)
    RegisterFontString(frame.fontWarning, 11, nil, true)
    Addon.fontWarning = frame.fontWarning

    Addon.settingsFrame = frame
    frame:Hide()
    EnsureDropdownPreviewHooks()
    RefreshSettingsControls()
    ApplyCurrentFont()
end

OpenSettings = function()
    CreateUI()
    CreateSettingsUI()
    Addon.contentMode = "settings"
    Addon.frame:Show()
    Addon.settingsFrame:Show()
    RefreshRows()
    RefreshSettingsControls()
end

local function CancelAllPendingAuto()
    if type(Addon.state) ~= "table" then
        return
    end

    local seen = {}
    local function cancelList(list)
        if type(list) ~= "table" then
            return
        end
        for index = 1, #list do
            local row = list[index]
            if type(row) == "table" and not seen[row] then
                seen[row] = true
                CancelPendingAuto(row)
            end
        end
    end

    cancelList(Addon.state.currentRows)
    cancelList(Addon.state.allRows)
    cancelList(Addon.state.sessionRows)
    cancelList(Addon.state.sessionAllRows)
    local history = Addon.state.history
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" then
                cancelList(group.rows)
                cancelList(group.allRows)
            end
        end
    end
end

SetAutoWhisper = function(enabled)
    Addon.state.settings.autoWhisper = enabled == true
    if not Addon.state.settings.autoWhisper then
        CancelAllPendingAuto()
    end
    SaveDB()
    RefreshRows()
    RefreshSettingsControls()
end

SetDelay = function(value, quiet)
    local old = Addon.state.settings.autoDelay
    Addon.state.settings.autoDelay = tonumber(value) or old
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    RefreshRows()
    RefreshSettingsControls()
    if not quiet and Addon.state.settings.autoDelay ~= tonumber(value) then
        Print("delay must be between " .. Addon.state.settings.minDelay .. " and " .. Addon.state.settings.maxDelay .. " seconds")
    end
end

SetWhisperTemplate = function(value)
    Addon.state.settings.whisperTemplate = Core.NormalizeWhisperTemplate(value)
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    RefreshSettingsControls()
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
        InvalidatePendingLoot()
        CancelAllInspectWork()
        Addon.equipmentCache = {}
        Addon.state.currentRows = {}
        Addon.state.allRows = {}
        Addon.state.sessionRows = {}
        Addon.state.sessionAllRows = {}
        Addon.selectedTab = "askable"
        Addon.selectedView = "current"
        Addon.selectedHistoryIndex = nil
        Addon.EnterLootMode()
        SaveDB()
        RefreshRows()
    elseif command == "history" then
        CycleHistoryView()
        CreateUI()
        Addon.frame:Show()
    elseif command == "settings" then
        OpenSettings()
    elseif command == "test" then
        CreateUI()
        AddTestRow()
    elseif command == "scan" then
        QueueEquipmentScan("manual", false)
    elseif command == "debug" then
        rest = string.lower(rest or "")
        if rest == "on" then
            Addon.state.settings.debug = true
            Addon.diagnostics = {}
            SaveDB()
        elseif rest == "off" then
            Addon.state.settings.debug = false
            Addon.diagnostics = {}
            SaveDB()
        else
            Print("debug=" .. tostring(Addon.state.settings.debug)
                .. ", diagnostics=" .. tostring(#(Addon.diagnostics or {}))
                .. "; usage: /dyni debug on|off")
        end
    elseif command == "diag" then
        if not ShouldPersistDiagnostics() then
            Print("debug diagnostics are off; use /dyni debug on to record diagnostics")
            return
        end
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
            .. ", locale=" .. tostring(Core.ResolveActiveLocale(Addon.state.settings.forceLocale, ClientLocale()))
            .. ", font=" .. tostring(FindFontName(Addon.state.settings.font))
            .. ", layout=540x300")
    else
        Print("commands: /dyni, /dyni settings, /dyni test, /dyni scan, /dyni auto on|off, /dyni delay <seconds>, /dyni clear, /dyni history, /dyni debug on|off, /dyni diag, /dyni status")
    end
end

local function Initialize()
    DoYouNeedItDB = DoYouNeedItDB or {}
    local settings = Core.NormalizeSettings(DoYouNeedItDB.settings or {})
    Addon.characterKey = SafePlayerStorageKey()
    PreserveLegacyAccountDrops(settings)
    local characterDB = GetCharacterDropsDB(true)
    if type(DoYouNeedItDB.settings) ~= "table" or type(DoYouNeedItDB.settings.font) ~= "string" or DoYouNeedItDB.settings.font == "" then
        settings.font = Core.LocaleAwareDefaultFont(STANDARD_TEXT_FONT)
    end
    Addon.state = Core.CreateState(settings)
    local fontChanged = MaybeAutoSwitchFont()
    Addon.state.history = Core.SnapshotHistoryForSave(characterDB.history, Addon.state.settings.maxHistoryGroups, Addon.state.settings.maxSessionRows)
    Addon.state.sessionRows = Core.NormalizeSavedRows(characterDB.sessionRows, Addon.state.settings.maxSessionRows)
    Addon.state.sessionAllRows = Core.NormalizeSavedAllRows(
        characterDB.sessionAllRows,
        characterDB.sessionRows,
        Addon.state.settings.maxSessionRows
    )
    Addon.diagnostics = Addon.state.settings.debug == true and type(DoYouNeedItDB.diagnostics) == "table" and DoYouNeedItDB.diagnostics or {}
    PersistDiagnostics()
    Addon.equipmentCache = {}
    Addon.inspectQueue = {}
    Addon.inspectActive = nil
    Addon.inspectByGuid = {}
    Addon.inspectGeneration = 0
    Addon.pendingItems = {}
    Addon.lootGeneration = 0
    Addon.recentLootKeys = {}
    Addon.challengeCompletedAt = nil
    Addon.challengeFinalizeToken = nil
    Addon.recentEncounterFinalizeToken = nil
    Addon.equipmentScanQueue = {}
    Addon.equipmentScanScheduled = false
    Addon.lootPatterns = Core.CreateLootMessagePatterns({
        lootSelf = LOOT_ITEM_SELF,
        lootSelfMultiple = LOOT_ITEM_SELF_MULTIPLE,
        lootOther = LOOT_ITEM,
        lootOtherMultiple = LOOT_ITEM_MULTIPLE,
        bonusSelf = LOOT_ITEM_BONUS_ROLL_SELF,
        bonusOther = LOOT_ITEM_BONUS_ROLL,
    })
    while #Addon.state.history > Addon.state.settings.maxHistoryGroups do
        table.remove(Addon.state.history)
    end
    if fontChanged then
        SaveDB()
    end
    Addon.currentInstanceName = SafeInstanceName()
    BuildRoster()
    CreateUI()
    ApplyCurrentFont()

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
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
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
            Addon.CompleteCurrentGroup(Addon.currentEncounterName)
        end
        SaveDB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshCharacterStorageFromPlayerIdentity()
        local instanceName = SafeInstanceName()
        local instanceChanged = Addon.currentInstanceName and Addon.currentInstanceName ~= instanceName
        if instanceChanged then
            CancelAllInspectWork()
            if Addon.state and (#Addon.state.currentRows > 0 or #(Addon.state.allRows or {}) > 0) then
                Addon.CompleteCurrentGroup(Addon.currentEncounterName)
            end
            Addon.recentEncounterName = nil
            Addon.recentEncounterEndedAt = nil
            Addon.currentEncounterID = nil
            Addon.currentEncounterName = nil
            Addon.currentEncounterStartedAt = nil
            Addon.challengeCompletedAt = nil
            Addon.challengeFinalizeToken = nil
            Addon.recentEncounterFinalizeToken = nil
            InvalidatePendingLoot()
        end
        Addon.currentInstanceName = instanceName
        BuildRoster()
        QueueEquipmentScan("entering_world", true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        StartEquipmentScan()
    elseif event == "CHALLENGE_MODE_START" then
        Addon.challengeCompletedAt = nil
        Addon.challengeFinalizeToken = nil
        Addon.recentEncounterFinalizeToken = nil
        QueueEquipmentScan("challenge_start", true)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        Addon.challengeCompletedAt = Now()
        Addon.ScheduleChallengeHistoryFinalize("challenge_completed")
    elseif event == "CHALLENGE_MODE_RESET" then
        Addon.challengeCompletedAt = nil
        Addon.challengeFinalizeToken = nil
        Addon.recentEncounterFinalizeToken = nil
    elseif event == "GROUP_ROSTER_UPDATE" then
        BuildRoster()
        Addon.equipmentCache = {}
        QueueEquipmentScan("group_roster_update", true)
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if Addon.state and (#Addon.state.currentRows > 0 or #(Addon.state.allRows or {}) > 0) then
            Addon.CompleteCurrentGroup(Addon.currentEncounterName)
        end
        Addon.recentEncounterName = nil
        Addon.recentEncounterEndedAt = nil
        Addon.recentEncounterFinalizeToken = nil
        Addon.currentEncounterID = encounterID
        Addon.currentEncounterName = CleanString(encounterName)
        Addon.currentEncounterStartedAt = Now()
        QueueEquipmentScan("encounter_start", true)
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        Addon.currentEncounterID = encounterID or Addon.currentEncounterID
        Addon.currentEncounterName = CleanString(encounterName) or Addon.currentEncounterName
        Addon.CompleteCurrentGroup(Addon.currentEncounterName)
        Addon.recentEncounterName = Addon.currentEncounterName
        Addon.recentEncounterEndedAt = Now()
        Addon.currentEncounterID = nil
        Addon.currentEncounterName = nil
        Addon.currentEncounterStartedAt = nil
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        Addon.HandleEncounterLootReceived(...)
    elseif event == "CHAT_MSG_LOOT" then
        HandleLootMessage(...)
    elseif event == "INSPECT_READY" then
        local guid = ...
        guid = CleanString(guid)
        if guid then
            CompleteActiveInspectRequest(guid)
        end
    end
end)
