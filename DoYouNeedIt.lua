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
    combatInspectRows = {},
    equipmentCache = {},
    equipmentScanQueue = {},
    equipmentScanScheduled = false,
    selectedHistoryIndex = nil,
    selectedView = "current",
    contentMode = "loot",
    rowScrollOffset = 0,
    currentHistoryFallbackGroup = nil,
    pendingItems = {},
    lootGeneration = 0,
    recentLootKeys = {},
    recentLootDedupeSeconds = 8,
    challengeCompletedAt = nil,
    challengeFinalizeToken = nil,
    challengeLootFinalizeDelay = 10,
    recentEncounterFinalizeToken = nil,
    encounterLootFinalizeDelay = 10,
    warbandRecheckDelay = 1.5,
    fontStrings = {},
}

local SetAutoWhisper
local SetDelay
local SetWhisperTemplate
local CreateUI
local CreateSettingsUI
local OpenSettings
local RequestInspectForRow
local ScheduleInspectRetry
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
local SETTINGS_WINDOW_HEIGHT = 420
local ROW_WIDTH = 510
local ROW_HEIGHT = 30
local ROW_START_Y = -82
local ROW_STRIDE = 34
local HEADER_HISTORY_WIDTH = 456
local ROW_LOOTER_WIDTH = 90
local ROW_DROP_WIDTH = 180
local ROW_DROP_HOVER_WIDTH = 188
local ROW_EQUIPPED_WIDTH = 150
local ROW_EQUIPPED_HOVER_WIDTH = 158
local ROW_STATUS_WIDTH = 380
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

function Addon.ShowTextTooltip(owner, text)
    if not owner or type(text) ~= "string" or text == "" or not GameTooltip then
        return
    end
    pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetText, GameTooltip, text)
    pcall(GameTooltip.Show, GameTooltip)
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
    if ok and type(number) == "number" and number == number and number ~= math.huge and number ~= -math.huge then
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
    -- WHY: both clocks can hand back secret-tagged values in combat; a raw
    -- secret must never flow into arithmetic, comparisons, or SavedVariables.
    -- Each clock is read through pcall plus the secret adapter and must yield
    -- a clean number, otherwise the next clock is tried; nil means "no
    -- trustworthy time" and callers with a fail-closed path (auto-whisper
    -- pump) re-arm instead of dispatching.
    if type(GetServerTime) == "function" then
        local ok, value = pcall(GetServerTime)
        if ok and type(value) == "number" and value == value and not IsSecret(value) then
            return value
        end
    end
    if type(time) == "function" then
        local ok, value = pcall(time)
        if ok and type(value) == "number" and value == value and not IsSecret(value) then
            return value
        end
    end
    return nil
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

function Addon.IsGroupInstanceContext()
    local _, instanceType = SafeCall(GetInstanceInfo)
    instanceType = CleanString(instanceType)
    if instanceType ~= "party" and instanceType ~= "raid" then
        return false
    end

    if CleanBoolean(SafeCall(IsInRaid)) == true then
        return true
    end
    return CleanBoolean(SafeCall(IsInGroup)) == true
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

local function SafeSelfLootLooterName()
    local playerName = SafePlayerName()
    if playerName then
        return playerName
    end
    local storageKey = SafePlayerStorageKey()
    if storageKey and storageKey ~= "__unknown" then
        return storageKey
    end
    return L("You")
end

local function RegisterFontString(fontString, size, flags, stable, dynamic, maxSize)
    if not fontString then
        return
    end
    Addon.fontStrings[#Addon.fontStrings + 1] = {
        fontString = fontString,
        size = size,
        flags = flags,
        stable = stable == true,
        dynamic = dynamic == true,
        maxSize = maxSize,
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

local function RegisterButtonFont(button, size, flags, stable, maxSize)
    if button and type(button.GetFontString) == "function" then
        local fontString = button:GetFontString()
        RegisterFontString(fontString, size, flags, stable, nil, maxSize)
        KeepOneLine(fontString)
    end
end

local function BuildFontsList(locale)
    locale = Core.ResolveActiveLocale(locale or ActiveLocale(), ClientLocale())
    -- Paint-pass cache (Addon fields, not new locals): every repaint asks
    -- for the list several times, so reuse it within one RefreshRows pass
    -- for the same locale. The shared-media name fingerprint below is the
    -- version key: a changed font set still rebuilds instead of going stale.
    local pass = Addon.fontListPass or 0
    local cache = Addon.fontListCache
    if cache and cache.pass == pass and cache.locale == locale and type(cache.fonts) == "table" then
        return cache.fonts
    end
    local names
    if LSM and type(LSM.List) == "function" and type(LSM.Fetch) == "function" then
        names = LSM:List("font")
    end
    local parts = {}
    if type(names) == "table" then
        for index = 1, #names do
            parts[#parts + 1] = tostring(names[index])
        end
    end
    local namesKey = table.concat(parts, "\001")
    if cache and cache.locale == locale and cache.namesKey == namesKey and type(cache.fonts) == "table" then
        cache.pass = pass
        return cache.fonts
    end
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
    Addon.fontListCache = { pass = pass, locale = locale, namesKey = namesKey, fonts = fonts }
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

-- Saved font paths can go stale mid-session (shared-media set replaced by
-- another addon, profile copied from another machine after load repair).
-- Resolve once per paint pass so a broken path never reaches SetFont.
function Addon.ValidatedDisplayFont()
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    local font = Addon.previewFont or settings.font or Core.GetDefaultFont()
    local active = ActiveLocale()
    local fonts = BuildFontsList(active)
    if not FindAvailableFontPath(font, fonts) then
        font = FindCompatibleAvailableFont(font, Core.GetLocaleGlyphRequirement(active), fonts, ClientLocale())
    end
    return font
end

ApplyCurrentFont = function()
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    local previewFont = Addon.ValidatedDisplayFont()
    local stableFont
    local dynamicFonts
    local dynamicFallbacks = {}
    -- Painters follow an uncommitted slider drag; stable readers
    -- (scheduler, status, saves) keep using settings directly.
    local previewSize = Addon.sliderPreview and Addon.sliderPreview.fontSize
    local selectedSize = tonumber(previewSize) or tonumber(settings.fontSize) or 12
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
            local size = Core.ResolveFontSize(entry.size, selectedSize)
            if entry.maxSize then size = math.min(size, entry.maxSize) end
            SafeCall(entry.fontString.SetFont, entry.fontString, font, size, entry.flags)
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
        -- Remember the pre-fallback path even when it is already gone
        -- (shared-media set replaced mid-session): otherwise the original
        -- can never be restored on re-registration.
        if not settings.fontBeforeAutoSwitch then
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
    -- WHY: item names may contain "]" (e.g. "Sword [of Doom]"), so the name
    -- is matched non-greedily up to the "]|h" terminator instead of the
    -- first "]".
    return message:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h%[(.-)%]|h|r)")
        or message:match("(|Hitem:[^|]+|h%[(.-)%]|h)")
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
        history = Core.SnapshotHistoryForSave(
            DoYouNeedItDB.history,
            settings.maxHistoryGroups,
            settings.maxSessionRows,
            ENCOUNTER_LOOT_GRACE,
            Core.ResolveActiveLocale(settings.forceLocale, ClientLocale())
        ),
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
    -- Debug-off records nothing anywhere: neither persisted nor in-memory,
    -- so /dyni diag keeps reporting "off" instead of serving stale rows.
    if not ShouldPersistDiagnostics() then
        return nil
    end
    Addon.diagnostics = type(Addon.diagnostics) == "table" and Addon.diagnostics or {}
    fields = type(fields) == "table" and fields or {}

    local entry = {
        stage = CleanString(stage) or "unknown",
        at = Now(),
        instanceName = CleanString(Addon.currentInstanceName) or CleanString(SafeInstanceName()),
        encounterName = CleanString(Addon.currentEncounterName),
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

    return saved
end

local function BuildRoster()
    local previous = {}
    for _, entry in ipairs(Addon.rosterEntries or {}) do
        if type(entry) == "table" and type(entry.fullName) == "string" then
            previous[entry.fullName] = true
        end
    end
    local entries = {}

    local function addUnit(unit)
        local fullName, shortName = SafeUnitName(unit)
        if fullName and not Core.IsPlaceholderName(fullName) then
            entries[#entries + 1] = {
                unit = unit,
                fullName = fullName,
                shortName = shortName,
                classToken = SafeUnitClassToken(unit),
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
    local current = {}
    for _, entry in ipairs(entries) do
        if type(entry.fullName) == "string" then
            current[entry.fullName] = true
        end
    end
    Addon.rosterEntries = entries
    Addon.roster = Core.CreateRosterIndex(entries)
    -- Report departed full names so roster events can invalidate only their
    -- equipment cache instead of wiping fresh entries of the living.
    local departed = {}
    for name in pairs(previous) do
        if not current[name] then
            departed[#departed + 1] = name
        end
    end
    return departed
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

function Addon.ApplyTradeStatusColor(fontString, statusKey)
    if not fontString or type(fontString.SetTextColor) ~= "function" then
        return
    end
    local color = Core.TRADE_STATUS_COLORS[statusKey] or Core.TRADE_STATUS_COLORS.trade_unknown
    SafeCall(fontString.SetTextColor, fontString, color[1], color[2], color[3], 1)
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
    local selfLootName = SafeSelfLootLooterName()
    local cleanMessage = CleanString(message)
    local resolved = Core.ResolveLootMessageLooter(cleanMessage, Addon.lootPatterns, playerName or selfLootName)
    if resolved and resolved.name then
        if resolved.isSelf then
            return resolved.name or selfLootName, false, nil, resolved.lootSource, true
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
        isGroupInstance = Addon.IsGroupInstanceContext(),
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

function Addon.RememberLootKeys(looter, itemLink, timestamp)
    local itemID = Core.ExtractItemID(itemLink)
    Addon.recentLootKeys["link\031" .. looter .. "\031" .. itemLink] = timestamp
    if itemID then Addon.recentLootKeys["item\031" .. looter .. "\031" .. tostring(itemID)] = timestamp end
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

    Addon.RememberLootKeys(looter, itemLink, now)
    return false, itemID
end

function Addon.ResolveEncounterLootLooter(playerName, classFileName)
    BuildRoster()

    local cleanName = CleanString(playerName)
    if not cleanName or Core.IsPlaceholderName(cleanName) then
        return nil
    end

    local player = SafePlayerName()
    local resolved = Core.ResolveRosterName(cleanName, Addon.roster)
        or Core.FindRosterNameInMessage(cleanName, Addon.roster, player)
    if resolved then
        return resolved
    end

    if Addon.roster and Addon.roster.ambiguous and Addon.roster.ambiguous[cleanName] == true then
        local classToken = CleanString(classFileName)
        local matches = 0
        local matchedName
        local entries = type(Addon.rosterEntries) == "table" and Addon.rosterEntries or {}
        if classToken then
            for index = 1, #entries do
                local entry = entries[index]
                if type(entry) == "table" and entry.shortName == cleanName then
                    local entryClass = CleanString(entry.classToken) or SafeUnitClassToken(entry.unit)
                    if entryClass == classToken then
                        matches = matches + 1
                        matchedName = entry.fullName
                    end
                end
            end
        end
        if matches == 1 and matchedName then
            return matchedName
        end
        return cleanName, "ambiguous_looter"
    end

    return cleanName
end

function Addon.HasCurrentLootRows()
    return Addon.state and (#(Addon.state.currentRows or {}) > 0 or #(Addon.state.allRows or {}) > 0)
end

function Addon.IsRecentChallengeCompletion()
    local completedAt = Addon.challengeCompletedAt
    local now = Now()
    return type(completedAt) == "number" and now >= completedAt and now - completedAt <= ENCOUNTER_LOOT_GRACE
end

function Addon.ScheduleChallengeHistoryFinalize(reason, rearms)
    if not Addon.state then
        return
    end

    rearms = tonumber(rearms) or 0
    local token = { rearms = rearms }
    Addon.challengeFinalizeToken = token
    Addon.challengeFinalizeRearms = rearms
    C_Timer.After(Addon.challengeLootFinalizeDelay, function()
        if Addon.challengeFinalizeToken ~= token then
            return
        end
        Addon.challengeFinalizeToken = nil
        -- Late M+ chest loot can still be resolving when the run closes: drain
        -- every bucket that can complete now so it joins its run inside grace,
        -- then close only a run that actually owns loot rows.
        Addon.DrainCompletablePendingLoot()
        if Addon.HasCurrentLootRows() then
            Addon.challengeFinalizeRearms = nil
            RecordDiagnostic("challenge_history_complete", {
                reason = reason or "challenge_completed",
            })
            Addon.CompleteCurrentGroup(Addon.currentEncounterName)
        elseif Addon.IsRecentChallengeCompletion() then
            if (token.rearms or 0) >= 3 then
                Addon.challengeFinalizeRearms = nil
                RecordDiagnostic("challenge_history_empty", {
                    reason = reason or "challenge_completed",
                    rearms = token.rearms or 0,
                })
                return
            end
            Addon.ScheduleChallengeHistoryFinalize(reason, (token.rearms or 0) + 1)
        else
            Addon.challengeFinalizeRearms = nil
            RecordDiagnostic("challenge_history_empty", {
                reason = reason or "challenge_completed",
            })
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
    if not itemID or type(Item) ~= "table" or type(Item.CreateFromItemID) ~= "function" then
        return false
    end

    local item = SafeCall(Item.CreateFromItemID, Item, itemID)
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

local function CanPlayerEquipItem(itemLink, classID, subclassID, equipLoc)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    local apiCanEquip
    local isEquippable
    if C_Item and type(C_Item.IsEquippableItem) == "function" then
        isEquippable = CleanBoolean(SafeCall(C_Item.IsEquippableItem, itemLink))
    elseif type(IsEquippableItem) == "function" then
        isEquippable = CleanBoolean(SafeCall(IsEquippableItem, itemLink))
    end
    if isEquippable == false then
        apiCanEquip = false
    elseif isEquippable == true then
        apiCanEquip = true
    end

    local isUsable
    if C_Item and type(C_Item.IsUsableItem) == "function" then
        isUsable = CleanBoolean(SafeCall(C_Item.IsUsableItem, itemLink))
    elseif type(IsUsableItem) == "function" then
        isUsable = CleanBoolean(SafeCall(IsUsableItem, itemLink))
    end
    if isUsable == false then
        apiCanEquip = false
    elseif isUsable == true and apiCanEquip ~= false then
        apiCanEquip = true
    end

    return Core.ResolvePlayerCanEquip({
        classID = CleanNumber(classID),
        subclassID = CleanNumber(subclassID),
        equipLoc = CleanString(equipLoc),
    }, GetPlayerClassToken(), apiCanEquip)
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

local function ReadAccountBinding(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" or not C_Item then
        return false, false
    end

    -- WHY: warband-until-equipped gear reports the same bind type as ordinary BoE;
    -- these hyperlink-safe APIs distinguish it even when the item is not in our bags.
    local isAccountBound = false
    if type(C_Item.IsItemBindToAccount) == "function" then
        isAccountBound = CleanBoolean(SafeCall(C_Item.IsItemBindToAccount, itemLink)) == true
    end

    local isAccountBoundUntilEquipped = false
    if type(C_Item.IsItemBindToAccountUntilEquip) == "function" then
        isAccountBoundUntilEquipped = CleanBoolean(SafeCall(C_Item.IsItemBindToAccountUntilEquip, itemLink)) == true
    end
    return isAccountBound, isAccountBoundUntilEquipped
end

local function ReadItemMetadata(itemLink)
    local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = GetItemInfoInstantCompat(itemLink)
    local itemName, resolvedLink, quality, itemLevel, requiredLevel, itemTypeText, itemSubTypeText, stackCount,
        equipLoc, itemIcon, sellPrice, detailedClassID, detailedSubclassID, bindType, expansionID, setID, isCraftingReagent =
        GetItemInfoCompat(itemLink)
    local metadataClassID = detailedClassID or classID
    local metadataSubclassID = detailedSubclassID or subclassID
    local metadataEquipLoc = CleanString(equipLoc) or CleanString(itemEquipLoc)
    local isAccountBound, isAccountBoundUntilEquipped = ReadAccountBinding(itemLink)

    return Core.BuildItemMetadata(itemLink, {
        itemID = itemID,
        equipLoc = CleanString(itemEquipLoc),
        classID = classID,
        subclassID = subclassID,
    }, {
        name = CleanString(itemName),
        link = CleanString(resolvedLink),
        quality = CleanNumber(quality),
        itemLevel = Addon.ReadItemLevel(itemLink),
        classID = metadataClassID,
        subclassID = metadataSubclassID,
        equipLoc = metadataEquipLoc,
        bindType = CleanNumber(bindType),
        tradeTimeRemaining = TooltipHasTradeTimer(itemLink),
        isAccountBound = isAccountBound,
        isAccountBoundUntilEquipped = isAccountBoundUntilEquipped,
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

function Addon.ReadItemLevel(itemLink)
    local itemLevel
    if C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
        itemLevel = CleanNumber(SafeCall(C_Item.GetDetailedItemLevelInfo, itemLink))
    end
    if not itemLevel then
        local _, _, _, fallbackItemLevel = GetItemInfoCompat(itemLink)
        itemLevel = CleanNumber(fallbackItemLevel)
    end
    if not (itemLevel and itemLevel > 0 and itemLevel < math.huge) then
        return nil
    end
    return itemLevel
end

function Addon.ReadEquippedItemLevels(links)
    local levels = {}
    for index = 1, #(links or {}) do
        local itemLevel = Addon.ReadItemLevel(links[index])
        if itemLevel then
            levels[#levels + 1] = itemLevel
        end
    end
    return levels
end

local function FormatEquippedLinks(prefix, links)
    links = type(links) == "table" and links or {}
    if #links == 0 then
        return UNKNOWN_EQUIPPED
    end
    return prefix .. table.concat(links, " / ")
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

-- Returns true when the unit is in inspect range, false when definitely out
-- of range, and nil when range cannot be determined (missing API or a
-- secret-tagged result). Unknown range must never block inspection.
local function CanInspectRangeClean(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    if type(UnitInRange) == "function" then
        local inRange = CleanBoolean(SafeCall(UnitInRange, unit))
        if inRange ~= nil then
            return inRange
        end
    end
    if type(CheckInteractDistance) == "function" then
        local close = CleanBoolean(SafeCall(CheckInteractDistance, unit, 1))
        if close ~= nil then
            return close
        end
    end
    return nil
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
    local generation = Addon.inspectGeneration or 0
    C_Timer.After(delay or EQUIPMENT_SCAN_DELAY, function()
        -- A cleared scan must not consume a newer queue or clear its timer flag.
        if generation ~= (Addon.inspectGeneration or 0) then return end
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

function Addon.InvalidateEquipmentCacheForNames(names)
    if type(names) ~= "table" or type(Addon.equipmentCache) ~= "table" then
        return 0
    end
    local removed = 0
    for index = 1, #names do
        local fullName = names[index]
        if type(fullName) == "string" and fullName ~= "" then
            if Addon.equipmentCache[fullName] ~= nil then
                Addon.equipmentCache[fullName] = nil
                removed = removed + 1
            end
            local shortName = fullName:match("^([^-]+)")
            if shortName and shortName ~= fullName and Addon.equipmentCache[shortName] ~= nil then
                local roster = Addon.roster
                local ambiguous = type(roster) == "table" and type(roster.ambiguous) == "table" and roster.ambiguous[shortName] == true
                local shortOwner = roster and Core.ResolveRosterName(shortName, roster) or nil
                if not ambiguous and (shortOwner == nil or shortOwner == fullName) then
                    Addon.equipmentCache[shortName] = nil
                    removed = removed + 1
                end
            end
        end
    end
    return removed
end

function Addon.RebuildEquipmentScanQueue(source)
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
    return #queue
end

local function QueueEquipmentScan(source, quiet)
    if not Addon.state then
        return 0
    end

    local count = Addon.RebuildEquipmentScanQueue(source)
    RecordDiagnostic("scan_queued", {
        reason = source or "manual",
        count = count,
    })
    ScheduleEquipmentScan(0)
    return count
end

StartEquipmentScan = function()
    if #Addon.equipmentScanQueue == 0 then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        RecordDiagnostic("scan_deferred", { reason = "combat_lockdown" })
        -- The shared combat-end wakeup resumes scans and loot without polling.
        return
    end
    if Addon.inspectActive then
        ScheduleEquipmentScan(EQUIPMENT_SCAN_DELAY)
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
    if Addon.selectedView == "current" and Addon.demoRows then
        return Addon.demoRows
    end
    local function unifiedRows(allRows, askableRows)
        local visible = {}
        local rows = type(allRows) == "table" and #allRows > 0 and allRows or askableRows or {}
        for _, row in ipairs(rows) do
            if not Core.IsHiddenLootRow(row) then visible[#visible + 1] = row end
        end
        return visible
    end

    if Addon.selectedView == "session" then
        return unifiedRows(Addon.state.sessionAllRows, Addon.state.sessionRows)
    end
    if Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        if not group then
            return {}
        end
        return unifiedRows(group.allRows, group.rows)
    end
    local hasLiveCurrentRows = #(Addon.state.currentRows or {}) > 0 or #(Addon.state.allRows or {}) > 0
    if Addon.selectedView == "current" and not hasLiveCurrentRows then
        local group = Addon.currentHistoryFallbackGroup
        if group then
            return unifiedRows(group.allRows, group.rows)
        end
    end
    return unifiedRows(Addon.state.allRows, Addon.state.currentRows)
end

function Addon.LootRowMetrics()
    local size = Addon.state and Addon.state.settings.fontSize or 12
    local body = Core.ResolveFontSize(11, size)
    local detail = Core.ResolveFontSize(10, size)
    local height = math.max(ROW_HEIGHT, body + detail + 6)
    local stride = height + 4
    local startY = ROW_START_Y - math.max(0, size - 12) * 2
    local count = math.min(MAX_VISIBLE_ROWS, math.floor((WINDOW_HEIGHT + startY - 8) / stride))
    return height, stride, math.max(1, count), body, startY
end

function Addon.GetVisibleRowCount()
    local _, _, count = Addon.LootRowMetrics()
    return count
end

-- Column widths grow with the body font (same idea as the history/scroll/new
-- loot chrome scaling below) but stay capped so the fixed 510px row keeps
-- every column on screen; headers and hover targets follow the same widths.
function Addon.LootColumnWidths()
    local size = Addon.state and Addon.state.settings.fontSize or 12
    local scale = Core.ResolveFontSize(11, size) / 11
    local function scaled(base, cap)
        return math.min(cap, math.max(base, math.floor(base * scale + 0.5)))
    end
    return {
        looter = scaled(ROW_LOOTER_WIDTH, 110),
        drop = scaled(ROW_DROP_WIDTH, 200),
        equipped = scaled(ROW_EQUIPPED_WIDTH, 160),
    }
end

function Addon.CaptureReadingPosition()
    local rows = RowsForSelectedView()
    local offset = Addon.rowScrollOffset or 0
    return {
        view = Addon.selectedView,
        group = Addon.selectedHistoryIndex and Addon.state.history[Addon.selectedHistoryIndex],
        offset = offset,
        anchor = offset > 0 and rows[#rows - offset] or nil,
    }
end

function Addon.RestoreReadingPosition(saved, newLoot)
    Addon.selectedView = saved.view
    if saved.view == "history" then
        Addon.selectedHistoryIndex = nil
        for index, group in ipairs(Addon.state.history) do
            if group == saved.group then Addon.selectedHistoryIndex = index; break end
        end
        if not Addon.selectedHistoryIndex then Addon.selectedView = "session" end
    end
    Addon.rowScrollOffset = saved.offset
    if saved.anchor then
        local rows = RowsForSelectedView()
        for index, row in ipairs(rows) do
            if row == saved.anchor then Addon.rowScrollOffset = #rows - index; break end
        end
    end
    if newLoot and (saved.view ~= "current" or saved.offset > 0) then
        Addon.newLootPending = true
    end
end

local function NewestRowsWindow(rows)
    local result = {}
    if type(rows) ~= "table" then
        Addon.rowScrollOffset = 0
        return result, 0, 0, 0
    end

    local rowCount = #rows
    local _, _, visibleCount = Addon.LootRowMetrics()
    local maxOffset = math.max(0, rowCount - visibleCount)
    local offset = math.floor(tonumber(Addon.rowScrollOffset) or 0)
    if offset < 0 then
        offset = 0
    elseif offset > maxOffset then
        offset = maxOffset
    end
    Addon.rowScrollOffset = offset

    local startIndex = rowCount - offset
    for index = startIndex, 1, -1 do
        local row = rows[index]
        if type(row) == "table" then
            result[#result + 1] = row
            if #result >= visibleCount then
                break
            end
        end
    end
    return result, offset, maxOffset, rowCount
end

function Addon.HideSettingsTooltip()
    if GameTooltip and Addon.settingsButton
        and CleanBoolean(SafeCall(GameTooltip.IsOwned, GameTooltip, Addon.settingsButton)) == true then
        HideItemTooltip()
    end
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

    setShown(Addon.historyButton)
    setShown(Addon.settingsButton)
    if Addon.newLootButton then
        if shown and Addon.newLootPending then Addon.newLootButton:Show()
        else Addon.newLootButton:Hide() end
    end
    for index = 1, #(Addon.columnHeaders or {}) do
        setShown(Addon.columnHeaders[index])
    end
    if not shown then
        Addon.HideSettingsTooltip()
        setShown(Addon.scrollBadge)
        setShown(Addon.scrollText)
    end
end

function Addon.HideRowTooltip(rowFrame)
    if not GameTooltip or not rowFrame then
        return
    end
    for _, owner in ipairs({ rowFrame.dropLink, rowFrame.equippedLink, rowFrame.equippedLink2, rowFrame.tradeInfo }) do
        if CleanBoolean(SafeCall(GameTooltip.IsOwned, GameTooltip, owner)) == true then
            HideItemTooltip()
            return
        end
    end
end

function Addon.HideLootRows()
    Addon.HideSettingsTooltip()
    for index = 1, MAX_VISIBLE_ROWS do
        if Addon.rowFrames[index] then
            Addon.HideRowTooltip(Addon.rowFrames[index])
            Addon.rowFrames[index]:Hide()
        end
    end
    if Addon.emptyText then
        Addon.emptyText:Hide()
    end
    if Addon.emptyHelp then
        Addon.emptyHelp:Hide()
    end
    if Addon.scrollBadge then
        Addon.scrollBadge:Hide()
    end
    if Addon.scrollText then
        Addon.scrollText:Hide()
    end
end

local function RefreshRows()
    if not Addon.frame then
        return
    end

    -- New paint pass: same-locale font-list lookups below reuse one build.
    Addon.fontListPass = (Addon.fontListPass or 0) + 1

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
    local displayRows, offset, _, rowCount = NewestRowsWindow(rows)
    if Addon.newLootPending then
        local current = Addon.state.allRows or {}
        if #current == 0 and Addon.currentHistoryFallbackGroup then
            current = Addon.currentHistoryFallbackGroup.allRows or Addon.currentHistoryFallbackGroup.rows or {}
        end
        local hasVisible = false
        for _, row in ipairs(current) do
            if not Core.IsHiddenLootRow(row) then hasVisible = true; break end
        end
        if not hasVisible or (Addon.selectedView == "current" and offset == 0) then
            Addon.newLootPending = false
            Addon.newLootButton:Hide()
        end
    end
    local rowHeight, rowStride, visibleCount, bodyHeight, rowStartY = Addon.LootRowMetrics()
    local extraSize = math.max(0, Addon.state.settings.fontSize - 12)
    Addon.historyButton:SetHeight(math.max(22, bodyHeight + 6))
    local badgeWidth = math.max(76, bodyHeight * 7)
    Addon.scrollBadge:SetSize(badgeWidth, math.max(16, bodyHeight + 3))
    Addon.historyButton:GetFontString():SetWidth(HEADER_HISTORY_WIDTH - badgeWidth - 24)
    Addon.newLootButton:SetHeight(math.max(22, bodyHeight + 3))
    Addon.newLootButton:SetWidth(math.max(100, bodyHeight * 6))
    local columnWidths = Addon.LootColumnWidths()
    local dropX = 18 + columnWidths.looter + 8
    local equippedX = dropX + columnWidths.drop + 10
    -- Trade starts exactly where the scaled equipped column ends (456 at
    -- font 12); the fixed header offset above would let a wider equipped
    -- column overlap the Trade header at larger fonts. The trade block
    -- itself scales with the body font like the other columns so longer
    -- transfer labels (ru "Передача: вероятно") keep a fitting box.
    local tradeX = equippedX + columnWidths.equipped
    local tradeScale = Core.ResolveFontSize(11, Addon.state.settings.fontSize) / 11
    local tradeWidth = math.min(220, math.max(110, math.floor(110 * tradeScale + 0.5)))
    local tradeHeaderWidth = math.min(90, math.max(58, math.floor(58 * tradeScale + 0.5)))
    local tradeInfoHeight = math.min(24, math.max(11, math.floor(11 * tradeScale + 0.5)))
    Addon.frame.columnPlayer:SetWidth(columnWidths.looter)
    Addon.frame.columnDrop:SetWidth(columnWidths.drop)
    Addon.frame.columnEquipped:SetWidth(columnWidths.equipped)
    Addon.frame.columnTrade:SetWidth(tradeHeaderWidth)
    Addon.frame.columnPlayer.columnX = 18
    Addon.frame.columnDrop.columnX = dropX
    Addon.frame.columnEquipped.columnX = equippedX
    Addon.frame.columnTrade.columnX = tradeX
    for _, header in ipairs(Addon.columnHeaders) do
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", Addon.frame, "TOPLEFT", header.columnX, -68 - extraSize)
    end

    local title = L("Current")
    if Addon.selectedView == "session" then
        title = L("This Session")
    elseif Addon.selectedView == "history" and Addon.selectedHistoryIndex then
        local group = Addon.state.history[Addon.selectedHistoryIndex]
        title = Core.GetHistoryGroupTitle(group, ActiveLocale()) or L("History")
    end
    Addon.historyButton:SetText(title)
    if Addon.scrollText then
        if rowCount > visibleCount then
            local newestPosition = rowCount - offset
            local oldestPosition = math.max(1, newestPosition - #displayRows + 1)
            Addon.scrollText:SetText(tostring(oldestPosition) .. "-" .. tostring(newestPosition) .. " / " .. tostring(rowCount))
            if Addon.scrollBadge then
                Addon.scrollBadge:Show()
            end
            Addon.scrollText:Show()
        else
            if Addon.scrollBadge then
                Addon.scrollBadge:Hide()
            end
            Addon.scrollText:Hide()
        end
    end
    for index = 1, MAX_VISIBLE_ROWS do
        local rowFrame = Addon.rowFrames[index]
        local row = displayRows[index]
        local firstEquipped, secondEquipped = Addon.EquippedItemLinks(row and row.equippedText)
        if rowFrame.row ~= row or not row
            or rowFrame.dropLink.itemLink ~= FirstItemLink(row.itemLink)
            or rowFrame.equippedLink.itemLink ~= firstEquipped
            or rowFrame.equippedLink2.itemLink ~= secondEquipped
            or rowFrame.tradeInfo.tooltipText ~= Core.GetTradeStatusTooltip(row, ActiveLocale())
        then
            Addon.HideRowTooltip(rowFrame)
        end
        if row then
            rowFrame.row = row
            rowFrame:ClearAllPoints()
            rowFrame:SetPoint("TOPLEFT", Addon.frame, "TOPLEFT", 10, rowStartY - ((index - 1) * rowStride))
            rowFrame:SetHeight(rowHeight)
            rowFrame.looter:SetHeight(bodyHeight)
            rowFrame.looter:SetWidth(columnWidths.looter)
            rowFrame.dropLink:SetHeight(bodyHeight + 3)
            rowFrame.equippedLink:SetHeight(bodyHeight + 3)
            rowFrame.equippedLink2:SetHeight(bodyHeight + 3)
            rowFrame.whisper:SetHeight(math.max(16, bodyHeight + 3))
            rowFrame.looter:SetText(row.looter or "?")
            ApplyLooterClassColor(rowFrame.looter, EnsureRowClassToken(row))
            rowFrame.drop:ClearAllPoints()
            if row.lootSource == "bonus_roll" then
                rowFrame.rollIcon:Show()
                rowFrame.drop:SetPoint("LEFT", rowFrame.rollIcon, "RIGHT", 4, 0)
                rowFrame.drop:SetWidth(columnWidths.drop - 18)
            else
                rowFrame.rollIcon:Hide()
                rowFrame.drop:SetPoint("LEFT", rowFrame.looter, "RIGHT", 8, 0)
                rowFrame.drop:SetWidth(columnWidths.drop)
            end
            rowFrame.drop:SetText(row.itemLink or "")
            -- Hover targets track the scaled columns (defaults reproduce the
            -- creation-time 104/294 anchors exactly at font size 12).
            rowFrame.dropLink:ClearAllPoints()
            rowFrame.dropLink:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 14 + columnWidths.looter, -1)
            rowFrame.dropLink:SetWidth(columnWidths.drop + 8)
            local equippedLinkX = 24 + columnWidths.looter + columnWidths.drop
            rowFrame.equippedLink:ClearAllPoints()
            rowFrame.equippedLink:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", equippedLinkX, -1)
            rowFrame.equippedLink:SetWidth(columnWidths.equipped + 8)
            if secondEquipped then
                local prefix = IsCachedEquippedText(row.equippedText) and DisplayEquippedText("Cached: ") or ""
                rowFrame.equipped:SetText(prefix .. firstEquipped)
                rowFrame.equipped:SetWidth((columnWidths.equipped - 8) / 2)
                rowFrame.equippedLink:SetWidth((columnWidths.equipped - 8) / 2 + 2)
                rowFrame.equipped2:SetWidth((columnWidths.equipped - 8) / 2)
                rowFrame.equippedLink2:ClearAllPoints()
                rowFrame.equippedLink2:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", equippedLinkX + (columnWidths.equipped - 8) / 2 + 8, -1)
                rowFrame.equippedLink2:SetWidth((columnWidths.equipped - 8) / 2 + 2)
                rowFrame.equipped2:SetText(secondEquipped)
                rowFrame.equipped2:Show()
                rowFrame.equippedDivider:Show()
            else
                rowFrame.equipped:SetText(DisplayEquippedText(row.equippedText))
                rowFrame.equipped:SetWidth(columnWidths.equipped)
                rowFrame.equippedLink:SetWidth(columnWidths.equipped + 8)
                rowFrame.equipped2:Hide()
                rowFrame.equippedDivider:Hide()
            end
            local tradeStatusKey = Core.GetTradeStatusKey(row)
            rowFrame.trade:SetText(Core.GetTradeStatusText(row, ActiveLocale()))
            Addon.ApplyTradeStatusColor(rowFrame.trade, tradeStatusKey)
            -- Trade shares the second row line with the status text: the
            -- block keeps the row right edge while its scaled width grows
            -- left, and the status yields so the two boxes never overlap.
            rowFrame.trade:ClearAllPoints()
            rowFrame.trade:SetPoint("BOTTOMRIGHT", rowFrame, "BOTTOMRIGHT", -6, 2)
            rowFrame.trade:SetWidth(tradeWidth)
            rowFrame.status:SetWidth((ROW_WIDTH - 6 - tradeWidth) - 8 - 6)
            rowFrame.tradeInfo:ClearAllPoints()
            rowFrame.tradeInfo:SetPoint("BOTTOMRIGHT", rowFrame, "BOTTOMRIGHT", -6, 1)
            rowFrame.tradeInfo:SetSize(tradeWidth, tradeInfoHeight)
            rowFrame.tradeInfo.tooltipText = Core.GetTradeStatusTooltip(row, ActiveLocale())
            rowFrame.tradeInfo:Show()
            rowFrame.dropLink.itemLink = FirstItemLink(row.itemLink)
            rowFrame.equippedLink.itemLink = firstEquipped
            rowFrame.equippedLink2.itemLink = secondEquipped
            rowFrame.dropLink:SetShown(rowFrame.dropLink.itemLink ~= nil)
            rowFrame.equippedLink:SetShown(rowFrame.equippedLink.itemLink ~= nil)
            rowFrame.equippedLink2:SetShown(secondEquipped ~= nil)
            rowFrame.status:SetText(Core.GetRowStatusText(row, ActiveLocale()))
            local whisperState = Core.GetWhisperButtonState(nil, Addon.selectedView, row)
            rowFrame.accent:SetColorTexture(whisperState.enabled and 0.22 or 0.22, whisperState.enabled and 0.68 or 0.28, whisperState.enabled and 0.88 or 0.34, whisperState.enabled and 0.85 or 0.35)
            rowFrame.status:SetTextColor(0.64, 0.70, 0.77, 1)
            if whisperState.visible then
                rowFrame.whisper:SetText(L(whisperState.text))
                if whisperState.enabled and not row.isTest then
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
            rowFrame.equippedLink2.itemLink = nil
            rowFrame.tradeInfo.tooltipText = nil
            rowFrame.rollIcon:Hide()
            rowFrame.dropLink:Hide()
            rowFrame.equippedLink:Hide()
            rowFrame.equippedLink2:Hide()
            rowFrame.equipped2:Hide()
            rowFrame.equippedDivider:Hide()
            rowFrame.tradeInfo:Hide()
            rowFrame:Hide()
        end
    end

    ApplyCurrentFont()

    if #rows == 0 then
        Addon.emptyText:SetText(L("No gear drops in this view."))
        Addon.emptyText:Show()
        Addon.emptyHelp:SetText(L("Gear from your dungeon or raid will appear here."))
        Addon.emptyHelp:Show()
        if Addon.scrollText then
            Addon.scrollText:Hide()
        end
    else
        Addon.emptyText:Hide()
        Addon.emptyHelp:Hide()
    end
    if RefreshSettingsControls then
        RefreshSettingsControls()
    end
end

local function SaveDB()
    DoYouNeedItDB = DoYouNeedItDB or {}
    local settings = Addon.state and Addon.state.settings or Core.NormalizeSettings({})
    local characterDB = GetCharacterDropsDB(true)
    local history = Addon.state and Core.SnapshotHistoryForSave(
        Addon.state.history,
        settings.maxHistoryGroups,
        settings.maxSessionRows,
        ENCOUNTER_LOOT_GRACE,
        ActiveLocale()
    ) or {}
    local sessionRows = Addon.state and Core.SnapshotRowsForSave(Addon.state.sessionRows, settings.maxSessionRows) or {}
    local sessionAllRows = Addon.state and Core.SnapshotRowsForSave(Addon.state.sessionAllRows, settings.maxSessionRows) or {}
    -- Main-side secret sweep: snapshots copy clean primitives by type, but a
    -- secret-tagged string/number/boolean survives type checks, so any saved
    -- row field the secret adapter still flags is dropped before persisting.
    local function sweepSecretsFromSavedRows(list)
        if type(list) ~= "table" then
            return
        end
        for index = 1, #list do
            local row = list[index]
            if type(row) == "table" then
                for key, value in pairs(row) do
                    local valueType = type(value)
                    if (valueType == "string" or valueType == "number" or valueType == "boolean")
                        and IsSecret(value) then
                        row[key] = nil
                    end
                end
            end
        end
    end
    local function sweepSecretsFromSavedHistory(groups)
        if type(groups) ~= "table" then
            return
        end
        for index = 1, #groups do
            local group = groups[index]
            if type(group) == "table" then
                for key, value in pairs(group) do
                    local valueType = type(value)
                    if (valueType == "string" or valueType == "number" or valueType == "boolean")
                        and IsSecret(value) then
                        group[key] = nil
                    end
                end
                sweepSecretsFromSavedRows(group.rows)
                sweepSecretsFromSavedRows(group.allRows)
            end
        end
    end
    sweepSecretsFromSavedRows(sessionRows)
    sweepSecretsFromSavedRows(sessionAllRows)
    sweepSecretsFromSavedHistory(history)
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
    -- Identity is id+looter+itemID+timestamp: reloads reuse row IDs, so the
    -- full link is compared only when upgrading an item variant, never to
    -- tell two rows apart.
    local itemID
    do
        local ok, number = pcall(tonumber, row.itemID)
        if ok then
            itemID = number
        end
    end
    itemID = itemID or Core.ExtractItemID(row.itemLink)
    return tostring(row.id or "")
        .. "\031" .. tostring(row.looter or "")
        .. "\031" .. tostring(itemID or "")
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
            seen[key] = #target + 1
            target[#target + 1] = row
        elseif key then
            local stored = target[seen[key]]
            if type(stored) == "table" then
                Core.UpgradeRowLinkToDetailed(stored, row)
            end
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
        local savedHistory = Core.SnapshotHistoryForSave(
            characterDB.history,
            settings.maxHistoryGroups,
            settings.maxSessionRows,
            ENCOUNTER_LOOT_GRACE,
            ActiveLocale()
        )
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
    if not row or row.isTest or not row.looter or not row.itemLink then
        return
    end
    if row.manualWhispered == true or row.autoWhispered == true or row.whisperInFlight == true then
        return
    end

    row.pendingAutoWhisper = false
    row.autoToken = nil
    local message, messageError = Core.FormatWhisperMessage(Addon.state.settings.whisperTemplate, row.itemLink)
    if not message then
        row.statusKey = messageError
        row.statusSeconds = nil
        row.statusText = nil
        Print(L(messageError .. "_help"))
        SaveDB()
        RefreshRows()
        return
    end
    local target = row.looter
    if isAuto ~= true then
        -- A manual Ask fired inside the pacing gap of a fresh automatic
        -- dispatch waits out the remainder instead of bursting: same-tick
        -- manual streaks still send immediately (chat-throttle backstop
        -- below keeps them retryable), so only post-auto manuals defer.
        local nowStamp = Now()
        local lastDispatch = Addon.lastDispatchAt
        if Addon.lastDispatchWasAuto == true and type(lastDispatch) == "number"
            and type(nowStamp) == "number" and nowStamp - lastDispatch < 1.5 then
            row.statusKey = "sending"
            row.statusSeconds = nil
            row.statusText = nil
            SaveDB()
            RefreshRows()
            C_Timer.After(lastDispatch + 1.5 - nowStamp, function()
                if not IsRowStillTracked(row) then
                    return
                end
                SendWhisper(row, false)
            end)
            return
        end
    end
    local token = {}
    row.whisperInFlight = true
    row.whisperToken = token
    row.whisperIsAuto = isAuto == true
    row.dispatchStartedAt = Now()
    Addon.lastDispatchAt = row.dispatchStartedAt
    Addon.lastDispatchWasAuto = isAuto == true
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
            row.whisperIsAuto = nil
            return
        end

        if isAuto then
            -- Party tokens can be reused before the roster event reaches us.
            BuildRoster()
            if not Addon.IsGroupInstanceContext() or not ResolveUnitForName(target) then
                row.whisperInFlight = false
                row.whisperToken = nil
                row.whisperIsAuto = nil
                row.statusKey = "candidate"
                SaveDB()
                RefreshRows()
                return
            end
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
        row.whisperIsAuto = nil
        if ok then
            -- LIMITATION: pcall proves client acceptance, not delivery.
            -- Sub-second repeat streaks are suspected throttling: keep a
            -- retryable Ask instead of Sent.
            local nowStamp = Now()
            local lastStamp = Addon.lastWhisperSentAt
            Addon.lastWhisperSentAt = nowStamp
            if type(lastStamp) == "number" and type(nowStamp) == "number" and nowStamp - lastStamp < Core.WHISPER_REPEAT_WINDOW then
                Addon.fastWhisperStreak = (Addon.fastWhisperStreak or 0) + 1
            else
                Addon.fastWhisperStreak = 0
            end
            if (Addon.fastWhisperStreak or 0) >= Core.WHISPER_REPEAT_STREAK_LIMIT then
                Addon.fastWhisperStreak = 0
                row.statusKey = "whisper_failed"
                row.whisperRetryable = true
                RecordDiagnostic("whisper_throttled", {
                    looter = target,
                    itemLink = row.itemLink,
                })
            elseif isAuto then
                row.autoWhispered = true
                row.statusKey = "auto_sent"
                row.whisperRetryable = nil
            else
                row.manualWhispered = true
                row.statusKey = "sent"
                row.whisperRetryable = nil
            end
        else
            row.statusKey = "whisper_failed"
            row.whisperRetryable = true
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

local function CancelPendingAuto(row, cancelManual)
    if row then
        row.pendingAutoWhisper = false
        row.autoToken = nil
        if row.whisperInFlight == true and (row.whisperIsAuto == true or cancelManual == true) then
            row.whisperInFlight = false
            row.whisperToken = nil
            row.whisperIsAuto = nil
            row.statusKey = "candidate"
            row.statusSeconds = nil
            row.statusText = nil
        end
        if row.statusKey == "auto_pending" or (row.statusText and row.statusText:find("auto in", 1, true)) then
            row.statusKey = "candidate"
            row.statusSeconds = nil
            row.statusText = nil
        end
    end
end

-- Proactive cleanup: drop the stale "auto in Ns" display for departed
-- looters (the send-boundary guard already blocks delivery lazily).
-- Departed full names match tracked rows by full name AND by short form
-- (before "-"): intake may store either variant depending on whether the
-- realm was known, so both directions are compared.
function Addon.CancelPendingAutoForDeparted(departed)
    if type(departed) ~= "table" or type(Addon.state) ~= "table" then
        return
    end
    local function shortName(name)
        if type(name) ~= "string" or name == "" then
            return nil
        end
        return name:match("^([^-]+)") or name
    end
    local departedFull, departedShort = {}, {}
    for index = 1, #departed do
        local name = departed[index]
        if type(name) == "string" and name ~= "" then
            departedFull[name] = true
            local short = shortName(name)
            if short then
                departedShort[short] = true
            end
        end
    end
    if not next(departedFull) then
        return
    end
    local cancelled, changed = {}, false
    local function cancelList(list)
        if type(list) ~= "table" then
            return
        end
        for index = 1, #list do
            local row = list[index]
            local rowShort = type(row) == "table" and shortName(row.looter) or nil
            local rowLooter = type(row) == "table" and row.looter or nil
            if type(row) == "table" and not cancelled[row]
                and (row.pendingAutoWhisper == true or row.statusKey == "auto_pending")
                and ((type(rowLooter) == "string" and departedFull[rowLooter] == true)
                    or (rowShort ~= nil and departedShort[rowShort] == true)) then
                CancelPendingAuto(row)
                cancelled[row] = true
                changed = true
            end
        end
    end
    local state = Addon.state
    cancelList(state.currentRows)
    cancelList(state.allRows)
    cancelList(state.sessionRows)
    cancelList(state.sessionAllRows)
    if type(state.history) == "table" then
        for index = 1, #state.history do
            local group = state.history[index]
            if type(group) == "table" then
                cancelList(group.rows)
                cancelList(group.allRows)
            end
        end
    end
    if changed then
        -- Evict cancelled rows from the auto queue like CancelAllPendingAuto
        -- does, but keep survivors dispatchable.
        if type(Addon.autoWhisperQueue) == "table" then
            local kept = {}
            for index = 1, #Addon.autoWhisperQueue do
                local row = Addon.autoWhisperQueue[index]
                if not cancelled[row] then
                    kept[#kept + 1] = row
                end
            end
            Addon.autoWhisperQueue = kept
        end
        SaveDB()
        RefreshRows()
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
    do
        local ok, number = pcall(tonumber, itemID)
        if ok then
            itemID = number
        else
            itemID = nil
        end
    end
    if not itemID then
        return nil
    end
    return Addon.FindTrackedLootRowMatching(looter, function(row)
        local rowID
        do
            local ok, number = pcall(tonumber, row.itemID)
            if ok then
                rowID = number
            end
        end
        return rowID == itemID
    end)
end

function Addon.UpdateTrackedLootLink(row, itemLink, source)
    if type(row) == "table" and row.lootSource == "bonus_roll" and source ~= "bonus" then
        return false
    end
    if type(row) ~= "table" or type(itemLink) ~= "string" or itemLink == "" or row.itemLink == itemLink then
        return false
    end
    if type(row.itemLink) == "string" and row.itemLink ~= "" then
        -- All sources share longest-wins: a link may only replace the tracked
        -- link when it describes the same item in more detail. Equal-length
        -- duplicates keep the existing link unless the incoming quality color
        -- proves an upgrade (encounter rare vs chat epic for the same drop).
        local oldID = Core.ExtractItemID(row.itemLink)
        local newID = Core.ExtractItemID(itemLink)
        if not newID or newID ~= oldID or #itemLink <= #row.itemLink then
            local function linkQuality(link)
                local color = type(link) == "string" and link:match("|c[fF][fF](%x%x%x%x%x%x)") or nil
                if not color then
                    return nil
                end
                color = color:lower()
                if color == "9d9d9d" then return 0
                elseif color == "ffffff" then return 1
                elseif color == "1eff00" then return 2
                elseif color == "0070dd" then return 3
                elseif color == "a335ee" then return 4
                elseif color == "ff8000" then return 5
                elseif color == "e6cc80" then return 6
                elseif color == "00ccff" then return 7
                else return nil end
            end
            local oldQuality = linkQuality(row.itemLink)
            local newQuality = linkQuality(itemLink)
            if newID and newID == oldID and newQuality and oldQuality and newQuality > oldQuality then
                -- Quality upgrade wins despite equal/shorter length; fall through.
            else
                if newID and newID == oldID and #itemLink == #row.itemLink then
                    RecordDiagnostic("duplicate_loot_link_kept", {
                        looter = row.looter,
                        itemLink = itemLink,
                        source = source or "unknown",
                    })
                end
                return false
            end
        end
    end

    row.itemLink = itemLink
    local itemID = Core.ExtractItemID(itemLink)
    if itemID then
        row.itemID = itemID
    end
    Addon.RevalidateTrackedLootMetadata(row)
    return true
end

function Addon.UpgradeTrackedLootToBonus(looter, itemLink, context, source)
    context = type(context) == "table" and context or {}
    if context.lootSource ~= "bonus_roll" then
        return false
    end

    local itemID = Core.ExtractItemID(itemLink)
    local now = context.timestamp or Now()
    -- Delayed source events may update fresh history, but must not rewrite an older run.
    local row = Addon.FindTrackedLootRowMatching(looter, function(candidate)
        return candidate.lootGeneration == (Addon.lootGeneration or 0)
            and type(candidate.timestamp) == "number"
            and now >= candidate.timestamp and now - candidate.timestamp <= ENCOUNTER_LOOT_GRACE
            and (candidate.lootSource ~= "bonus_roll"
                or now - (candidate.bonusConfirmedAt or candidate.timestamp) <= Addon.recentLootDedupeSeconds)
            and (not context.instanceName or candidate.instanceName == context.instanceName)
            and (not context.encounterName or not candidate.encounterName or candidate.encounterName == context.encounterName)
            and (candidate.itemLink == itemLink or (itemID and candidate.itemID == itemID))
    end)
    if not row then
        return false
    end

    local reading = Addon.CaptureReadingPosition()
    Addon.UpdateTrackedLootLink(row, itemLink, source)
    CancelPendingAuto(row)
    row.whisperInFlight = false
    row.whisperToken = nil
    row.whisperIsAuto = nil
    row.bonusConfirmedAt = row.bonusConfirmedAt or now
    -- All event sources share the first confirmation window; repeats must not extend it.
    Addon.RememberLootKeys(looter, itemLink, row.bonusConfirmedAt)
    row.lootSource = "bonus_roll"
    row.askable = false
    row.reason = "bonus_roll"
    row.statusKey = "bonus_roll"
    row.statusSeconds = nil
    row.statusText = nil
    Addon.SyncRowAskability(row, false)

    RecordDiagnostic("bonus_loot_upgrade", {
        looter = looter,
        itemLink = itemLink,
        source = source or "unknown",
    })
    Addon.RestoreReadingPosition(reading, false)
    if Addon.contentMode ~= "settings" then Addon.EnterLootMode() end
    SaveDB()
    RefreshRows()
    if not Addon.ScheduleChallengeHistoryFinalizeIfRecent(context.source or source or "bonus_loot_upgrade") then
        Addon.ScheduleRecentEncounterHistoryFinalizeIfRecent(context.source or source or "bonus_loot_upgrade")
    end
    if DoYouNeedItCore.ShouldAutoShowWindow(row, context) then
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

function Addon.AutoWhisperGap()
    local jitter = 0
    if math and type(math.random) == "function" then
        local ok, value = pcall(math.random)
        if ok and type(value) == "number" and value >= 0 and value < 1 then
            jitter = value * 0.5
        end
    end
    return 1.5 + jitter
end

function Addon.PumpAutoWhisperQueue()
    Addon.autoWhisperPumpScheduled = false
    if Addon.state == nil or Addon.state.settings == nil then
        return
    end
    local now = Now()
    if type(now) ~= "number" then
        -- Fail-closed without trustworthy time: keep the queue untouched and
        -- retry on the pacing gap instead of dispatching blindly.
        Addon.autoWhisperPumpScheduled = true
        C_Timer.After(Addon.AutoWhisperGap(), Addon.PumpAutoWhisperQueue)
        return
    end
    local stalled = false
    local function failStalledWhisper(row)
        -- Backstop for sends whose zero-delay chat callback never ran: free
        -- the row as a retryable failure instead of wedging the pacing cap,
        -- and defuse its pending auto so the pump cannot redispatch it.
        -- 10s is an order of magnitude past the normal same-tick resolve.
        if type(row) ~= "table" or row.whisperInFlight ~= true then
            return
        end
        local startedAt = row.dispatchStartedAt
        if type(startedAt) ~= "number" or now - startedAt <= 10 then
            return
        end
        row.whisperInFlight = false
        row.whisperToken = nil
        row.whisperIsAuto = nil
        row.dispatchStartedAt = nil
        row.pendingAutoWhisper = false
        row.autoToken = nil
        row.statusKey = "whisper_failed"
        row.statusSeconds = nil
        row.statusText = nil
        row.whisperRetryable = true
        RecordDiagnostic("whisper_stalled", {
            looter = row.looter,
            itemLink = row.itemLink,
        })
        stalled = true
    end
    local function sweepStalledWhispers(list)
        if type(list) ~= "table" then
            return
        end
        for index = 1, #list do
            failStalledWhisper(list[index])
        end
    end
    sweepStalledWhispers(Addon.autoWhisperQueue)
    sweepStalledWhispers(Addon.state.currentRows)
    sweepStalledWhispers(Addon.state.allRows)
    sweepStalledWhispers(Addon.state.sessionRows)
    sweepStalledWhispers(Addon.state.sessionAllRows)
    if stalled then
        SaveDB()
        RefreshRows()
    end
    -- Cap in-flight sends at one: a queued row waits while ANY active send
    -- (automatic or manual Ask) has not resolved yet.
    for index = 1, #Addon.autoWhisperQueue do
        local queued = Addon.autoWhisperQueue[index]
        if type(queued) == "table" and queued.whisperInFlight == true then
            Addon.autoWhisperPumpScheduled = true
            C_Timer.After(Addon.AutoWhisperGap(), Addon.PumpAutoWhisperQueue)
            return
        end
    end
    while #Addon.autoWhisperQueue > 0 do
        local row = table.remove(Addon.autoWhisperQueue, 1)
        if type(row) == "table" and row.pendingAutoWhisper == true and row.autoToken ~= nil
            and IsRowStillTracked(row) and Addon.state.settings.autoWhisper == true
            and row.unsafe ~= true and row.askable ~= false and not Core.IsHiddenLootRow(row) then
            local last = Addon.lastDispatchAt
            if type(last) == "number" and now - last < 1.5 then
                table.insert(Addon.autoWhisperQueue, 1, row)
                Addon.autoWhisperPumpScheduled = true
                C_Timer.After((last + 1.5 - now) + (Addon.AutoWhisperGap() - 1.5), Addon.PumpAutoWhisperQueue)
                return
            end
            SendWhisper(row, true)
            break
        end
    end
    if #Addon.autoWhisperQueue > 0 and not Addon.autoWhisperPumpScheduled then
        Addon.autoWhisperPumpScheduled = true
        C_Timer.After(Addon.AutoWhisperGap(), Addon.PumpAutoWhisperQueue)
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
    row.statusKey = "auto_pending"
    row.statusSeconds = decision.delay
    row.statusText = nil
    RefreshRows()

    -- FIFO pacing: the head keeps its configured delay, followers dispatch
    -- through the pump at least 1.5s (+ jitter) apart, one in flight.
    Addon.autoWhisperQueue[#Addon.autoWhisperQueue + 1] = row
    if not Addon.autoWhisperPumpScheduled then
        Addon.autoWhisperPumpScheduled = true
        C_Timer.After(decision.delay, Addon.PumpAutoWhisperQueue)
    end
end

function Addon.AddRowToListOnce(list, row)
    if type(list) ~= "table" or type(row) ~= "table" or IsRowInList(list, row) then
        return false
    end
    list[#list + 1] = row
    return true
end

function Addon.SyncRowAskability(row, askable)
    row.askable = askable == true
    local state = Addon.state
    local function sync(allRows, rows, limit)
        if row.askable and IsRowInList(allRows, row) then
            Addon.AddRowToListOnce(rows, row)
            while type(limit) == "number" and #rows > limit do table.remove(rows, 1) end
        elseif not row.askable then
            Addon.RemoveRowFromList(rows, row)
        end
    end
    sync(state.allRows, state.currentRows)
    sync(state.sessionAllRows, state.sessionRows, state.settings.maxSessionRows)
    for _, group in ipairs(state.history or {}) do
        if type(group) == "table" then sync(group.allRows, group.rows) end
    end
end

function Addon.RevalidateTrackedLootMetadata(row)
    CancelPendingAuto(row, true)
    Addon.SyncRowAskability(row, false)
    row.itemLevel = nil
    row.playerCanEquip = nil
    row.tradeStatusKey = "trade_unknown"
    row.reason = "not_askable"
    row.statusKey = "not_askable"
    row.statusSeconds = nil
    row.statusText = nil
    row.inspectPending = false
    row.inspectToken = nil
    row.inspectRetryCount = nil
    Addon.combatInspectRows[row] = nil
    local token, generation, itemLink = {}, Addon.lootGeneration, row.itemLink
    row.metadataToken = token
    local attempts = 0
    local function refresh()
        if row.metadataToken ~= token or Addon.lootGeneration ~= generation
            or row.itemLink ~= itemLink or not IsRowStillTracked(row) then return end
        local metadata = ReadItemMetadata(itemLink)
        if not metadata then
            attempts = attempts + 1
            if attempts <= MAX_ITEM_RETRIES then
                C_Timer.After(ITEM_RETRY_DELAY, refresh)
            else
                row.metadataToken = nil
            end
            return
        end
        row.metadataToken = nil
        metadata.lootSource = row.lootSource
        local classification = Core.ClassifyTradeCandidate(metadata, row.looter, SafePlayerName(), Addon.state.settings)
        if row.unsafe or row.isSelfLoot then
            classification = { visible = false, reason = row.isSelfLoot and "self_loot" or "looter_unresolved" }
        end
        row.itemLevel = Addon.ReadItemLevel(itemLink)
        row.equipLoc = metadata.equipLoc
        row.playerCanEquip = metadata.playerCanEquip
        row.isAccountBound = metadata.isAccountBound
        row.isAccountBoundUntilEquipped = metadata.isAccountBoundUntilEquipped
        row.tradeStatusKey = Core.ResolveTradeStatus(metadata)
        row.reason = classification.visible and "trade_candidate" or classification.reason
        row.statusKey = classification.visible and "candidate" or classification.reason
        if row.autoWhispered then row.statusKey = "auto_sent"
        elseif row.manualWhispered then row.statusKey = "sent" end
        Addon.SyncRowAskability(row, classification.visible)
        if not row.unsafe and not row.isSelfLoot then RequestInspectForRow(row) end
        if row.askable and row.autoWhisperEligible then ScheduleAutoWhisper(row) end
        SaveDB()
        RefreshRows()
    end
    -- A detailed chat link can change bonus levels even when the base item is cached.
    refresh()
end

function Addon.PromotePersonalLootRowFromEquipped(row, equippedLinks)
    if type(row) ~= "table"
        or row.askable == true
        or row.reason ~= "bind_on_pickup"
        or row.playerCanEquip ~= true
        or row.unsafe == true
    then
        return false
    end

    local slotNames = EQUIP_LOC_SLOTS[row.equipLoc]
    local requiredSlotCount = type(slotNames) == "table" and #slotNames or 1
    local equippedItemLevels = Addon.ReadEquippedItemLevels(equippedLinks)
    if Core.IsLikelyTradeableFromItemLevels(row.itemLevel, equippedItemLevels, requiredSlotCount) ~= true then
        return false
    end

    row.askable = true
    row.reason = "trade_candidate"
    row.statusKey = "candidate"
    row.statusText = nil
    row.tradeStatusKey = "trade_likely"

    Addon.SyncRowAskability(row, true)

    RecordDiagnostic("trade_likely_item_level", {
        looter = row.looter,
        equipLoc = row.equipLoc,
        itemLink = row.itemLink,
    })
    if row.autoWhisperEligible == true then
        ScheduleAutoWhisper(row)
    end
    return true
end

local function CompleteInspectRow(row, equippedText, equippedLinks)
    if not row then
        return
    end
    Addon.combatInspectRows[row] = nil
    row.equippedText = equippedText
    row.inspectPending = false
    row.inspectToken = nil
    if not row.itemLevel then row.itemLevel = Addon.ReadItemLevel(row.itemLink) end
    Addon.PromotePersonalLootRowFromEquipped(row, equippedLinks)
    if row.reason == "bind_on_pickup" and row.playerCanEquip == true and not row.unsafe then
        local slots = EQUIP_LOC_SLOTS[row.equipLoc]
        local requiredCount = type(slots) == "table" and #slots or 1
        local levels = Addon.ReadEquippedItemLevels(equippedLinks)
        if not row.itemLevel or #levels < requiredCount then
            -- Links can arrive before item levels or the second ring/trinket slot.
            -- Keep the same retry budget until the comparison is complete.
            ScheduleInspectRetry(row, "comparison_pending")
            return
        end
    end
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
    Addon.combatInspectRows[row] = nil
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

ScheduleInspectRetry = function(row, reason)
    if not row then
        return false
    end

    if not IsRowStillTracked(row) then
        Addon.combatInspectRows[row] = nil
        row.inspectPending = false
        row.inspectToken = nil
        return false
    end

    row.inspectPending = false
    if InCombatLockdown and InCombatLockdown() then
        -- Combat duration is not an inspection failure and must not spend retries.
        row.inspectToken = nil
        Addon.combatInspectRows[row] = true
        if row.equippedText == UNKNOWN_EQUIPPED or row.equippedText == EQUIPPED_UNAVAILABLE then
            row.equippedText = EQUIPPED_PENDING
        end
        return true
    end
    Addon.combatInspectRows[row] = nil
    local attempt = (row.inspectRetryCount or 0) + 1
    row.inspectRetryCount = attempt
    if attempt > MAX_INSPECT_RETRIES then
        FailInspectRow(row, reason or "retry_limit")
        SaveDB()
        RefreshRows()
        return false
    end

    if row.equippedText == UNKNOWN_EQUIPPED or row.equippedText == EQUIPPED_UNAVAILABLE then
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
                row.rangeParked = nil
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
    Addon.combatInspectRows = {}
    Addon.combatInspectResumeToken = nil
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
    if CanInspectRangeClean(unit) == false then
        -- Out of range spends no retries: rotate to the back, resume later,
        -- and fail over to the normal retry path after repeated passes.
        request.rangePasses = (request.rangePasses or 0) + 1
        if request.rangePasses > MAX_INSPECT_RETRIES then
            request.rangePasses = nil
            local parkedRows = type(request.rows) == "table" and request.rows or {}
            for index = 1, #parkedRows do
                local parkedRow = parkedRows[index]
                if type(parkedRow) == "table" and IsRowStillTracked(parkedRow) then
                    parkedRow.rangeParked = true
                    parkedRow.equippedText = EQUIPPED_PENDING
                end
            end
            if Addon.inspectActive == request then
                Addon.inspectActive = nil
            end
            if request.guid and Addon.inspectByGuid[request.guid] == request then
                Addon.inspectByGuid[request.guid] = nil
            end
            if request.scan then
                RequeueEquipmentScan(request.scan, "out_of_range")
            end
            SaveDB()
            RefreshRows()
            StartNextInspectRequest()
            return
        end
        Addon.inspectQueue[#Addon.inspectQueue + 1] = request
        Addon.inspectByGuid[request.guid] = request
        local deferredRows = type(request.rows) == "table" and request.rows or {}
        for index = 1, #deferredRows do
            local deferredRow = deferredRows[index]
            if type(deferredRow) == "table" and IsRowStillTracked(deferredRow)
                and (deferredRow.equippedText == UNKNOWN_EQUIPPED or deferredRow.equippedText == EQUIPPED_UNAVAILABLE) then
                deferredRow.equippedText = EQUIPPED_PENDING
            end
        end
        RecordDiagnostic("inspect_out_of_range", {
            looter = #deferredRows > 0 and deferredRows[1].looter or request.scan and request.scan.name,
            passes = request.rangePasses,
        })
        local rangeGeneration = Addon.inspectGeneration or 0
        C_Timer.After(INSPECT_RETRY_DELAY * 3, function()
            if rangeGeneration ~= (Addon.inspectGeneration or 0) then return end
            StartNextInspectRequest()
        end)
        SaveDB()
        RefreshRows()
        return
    end
    request.rangePasses = nil

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
    -- WHY this completion path intentionally runs even in combat while the
    -- request path parks: every read here is secret-safe (GUID/unit/links
    -- resolve through SafeCall plus Clean* adapters, never raw comparisons),
    -- and the only protected effect downstream (auto-whisper chat) always
    -- goes through a deferred C_Timer.After(0) clean-stack send per the API
    -- contract. Rows that still lack links re-park via ScheduleInspectRetry
    -- into combatInspectRows, so completing changes no combat behavior.
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
                    local equippedLinks = ReadEquippedLinks(unit, row.equipLoc)
                    local equippedText = FormatEquippedLinks("Equipped: ", equippedLinks)
                    if equippedText ~= UNKNOWN_EQUIPPED then
                        CompleteInspectRow(row, equippedText, equippedLinks)
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
    if type(row) == "table" then
        row.rangeParked = nil
        Addon.combatInspectRows[row] = nil
    end
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
        local equippedLinks = ReadEquippedLinks(unit, row.equipLoc)
        local equippedText = FormatEquippedLinks("Equipped: ", equippedLinks)
        if equippedText ~= UNKNOWN_EQUIPPED then
            CaptureEquipmentForUnit(unit, "loot_live")
            CompleteInspectRow(row, equippedText, equippedLinks)
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

Addon.ResumeInspectWorkAfterCombat = function(retries)
    if InCombatLockdown and InCombatLockdown() then
        if retries > 0 and not Addon.combatInspectResumeToken
            and (next(Addon.combatInspectRows) or #Addon.equipmentScanQueue > 0) then
            local token = {}
            local generation = Addon.inspectGeneration
            Addon.combatInspectResumeToken = token
            -- The regen event may precede the API flip. Both queues share one budget.
            C_Timer.After(0.25, function()
                if Addon.combatInspectResumeToken ~= token
                    or Addon.inspectGeneration ~= generation then return end
                Addon.combatInspectResumeToken = nil
                Addon.ResumeInspectWorkAfterCombat(retries - 1)
            end)
        end
        return
    end
    Addon.combatInspectResumeToken = nil
    local rows = Addon.combatInspectRows
    Addon.combatInspectRows = {}
    for row in pairs(rows) do RequestInspectForRow(row) end
    StartNextInspectRequest()
    StartEquipmentScan()
    if next(rows) then
        SaveDB()
        RefreshRows()
    end
end

function Addon.ScheduleWarbandRecheck(row, metadata)
    -- WHY: ReadAccountBinding runs only at intake, but warband-until-equipped
    -- flags can resolve a moment later while bindType 2/3 still reports BoE.
    -- A single bounded recheck hides a row that confirms as warband-bound
    -- without deleting its history; anything else leaves the row untouched.
    if type(row) ~= "table" or type(metadata) ~= "table" then
        return
    end
    if metadata.bindType ~= Core.BIND_ON_EQUIP and metadata.bindType ~= Core.BIND_ON_USE then
        return
    end
    if metadata.isAccountBound == true or metadata.isAccountBoundUntilEquipped == true then
        return
    end
    if row.tradeStatusKey ~= "trade_likely" then
        return
    end
    local token = {}
    row.warbandRecheckToken = token
    local generation = Addon.lootGeneration or 0
    local itemLink = row.itemLink
    -- One bounded recheck inside the 1-2s binding-resolution window.
    C_Timer.After(Addon.warbandRecheckDelay, function()
        if row.warbandRecheckToken ~= token then
            return
        end
        row.warbandRecheckToken = nil
        if generation ~= (Addon.lootGeneration or 0) then
            return
        end
        if row.itemLink ~= itemLink or not IsRowStillTracked(row) then
            return
        end
        -- WHY: IsRowStillTracked includes finalized history groups, but the
        -- recheck must never mutate history: only live current/session rows
        -- may be hidden; history rows keep their stored verdict.
        if type(Addon.state) ~= "table"
            or not (IsRowInList(Addon.state.currentRows, row)
                or IsRowInList(Addon.state.allRows, row)
                or IsRowInList(Addon.state.sessionRows, row)
                or IsRowInList(Addon.state.sessionAllRows, row)) then
            return
        end
        if row.manualWhispered == true or row.autoWhispered == true or row.whisperInFlight == true then
            return
        end
        local bound, untilEquip = ReadAccountBinding(itemLink)
        if bound ~= true and untilEquip ~= true then
            return
        end
        CancelPendingAuto(row, true)
        row.isAccountBound = bound == true
        row.isAccountBoundUntilEquipped = untilEquip == true
        row.tradeStatusKey = "trade_no"
        row.reason = "warband_bound"
        row.statusKey = "warband_bound"
        Addon.SyncRowAskability(row, false)
        RecordDiagnostic("warband_recheck_hidden", {
            looter = row.looter,
            itemLink = itemLink,
        })
        SaveDB()
        RefreshRows()
    end)
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

    local classification
    if context.unsafe == true then
        classification = { visible = false, reason = context.unsafeReason or "looter_unresolved" }
    elseif context.isSelfLoot == true then
        classification = { visible = false, reason = "self_loot" }
    else
        classification = DoYouNeedItCore.ClassifyTradeCandidate(metadata, looter, playerName, Addon.state.settings)
    end
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

    local reading = Addon.CaptureReadingPosition()
    local cachedEquippedText = Core.GetCachedEquippedText(Addon.equipmentCache, looter, metadata.equipLoc, Now(), EQUIPMENT_CACHE_MAX_AGE)
    local row = Core.AddVisibleRow(Addon.state, {
        looter = looter,
        classToken = context.classToken or ResolveClassTokenForName(looter),
        itemLink = metadata.link or itemLink,
        equipLoc = metadata.equipLoc,
        itemID = metadata.itemID,
        itemLevel = metadata.itemLevel,
        instanceName = context.instanceName or Addon.currentInstanceName or SafeInstanceName(),
        encounterName = context.encounterName,
        timestamp = context.timestamp or Now(),
        lootSource = context.lootSource,
        reason = askable and "trade candidate" or classification.reason,
        statusKey = askable and "candidate" or (classification.reason or "not_askable"),
        equippedText = cachedEquippedText or UNKNOWN_EQUIPPED,
        tradeStatusKey = Core.ResolveTradeStatus(metadata),
        playerCanEquip = metadata.playerCanEquip,
        isAccountBound = metadata.isAccountBound,
        isAccountBoundUntilEquipped = metadata.isAccountBoundUntilEquipped,
        autoWhisperEligible = context.isGroupInstance == true,
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
    row.lootGeneration = context.generation or Addon.lootGeneration or 0
    if row.lootSource == "bonus_roll" then row.bonusConfirmedAt = row.timestamp end
    row.isSelfLoot = context.isSelfLoot == true

    RecordDiagnostic("row_added", {
        looter = looter,
        itemLink = itemLink,
        equipLoc = metadata.equipLoc,
        itemID = metadata.itemID,
        askable = askable,
        playerCanEquip = metadata.playerCanEquip,
        lootSource = context.lootSource,
    })
    if not row.unsafe and context.isSelfLoot ~= true then
        RequestInspectForRow(row)
    end
    if askable and context.isGroupInstance == true then
        ScheduleAutoWhisper(row)
    end
    Addon.ScheduleWarbandRecheck(row, metadata)
    Addon.demoRows = nil
    Addon.currentHistoryFallbackGroup = nil
    Addon.RestoreReadingPosition(reading, true)
    if Addon.contentMode ~= "settings" then
        Addon.EnterLootMode()
    end
    SaveDB()
    RefreshRows()
    if not Addon.ScheduleChallengeHistoryFinalizeIfRecent(context.source or "post_challenge_loot") then
        Addon.ScheduleRecentEncounterHistoryFinalizeIfRecent(context.source or "post_encounter_loot")
    end
    if DoYouNeedItCore.ShouldAutoShowWindow(row, context) then
        CreateUI()
        Addon.frame:Show()
    end
    return true, askable and "askable" or "all_gear_only"
end

local function AddTestRow()
    -- Keep examples outside live state so they never enter history or chat.
    local demoState = Core.CreateState(Addon.state.settings)
    local row = Core.AddVisibleRow(demoState, {
        isTest = true,
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
        tradeStatusKey = "trade_likely",
        unsafe = false,
    }, true)
    Core.AddVisibleRow(demoState, {
        isTest = true,
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
        tradeStatusKey = "trade_unknown",
        unsafe = false,
    }, false)
    Addon.demoRows = demoState.allRows
    Addon.selectedView = "current"
    Addon.selectedHistoryIndex = nil
    Addon.rowScrollOffset = 0
    Addon.EnterLootMode()
    RefreshRows()
    if DoYouNeedItCore.ShouldAutoShowWindow(row, { forceAutoShow = true }) then
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

local function PendingBucketHasLooter(bucket, looter, generation)
    local waiters = type(bucket) == "table" and type(bucket.waiters) == "table" and bucket.waiters or {}
    for index = 1, #waiters do
        local waiter = waiters[index]
        if type(waiter) == "table" and waiter.looter == looter and (generation == nil or waiter.generation == generation) then
            return true
        end
    end
    return false
end

local function UpdatePendingWaiterContext(bucket, looter, context)
    if type(context) ~= "table" then
        return
    end
    local waiters = type(bucket) == "table" and type(bucket.waiters) == "table" and bucket.waiters or {}
    for index = 1, #waiters do
        local waiter = waiters[index]
        if type(waiter) == "table" and waiter.looter == looter then
            Core.MergePendingWaiterContext(waiter, context)
        end
    end
end

local function MergeDuplicatePendingLoot(looter, itemLink, context, source)
    if type(Addon.pendingItems) ~= "table" then
        return false
    end
    local itemID = Core.ExtractItemID(itemLink)
    if not itemID then
        return false
    end

    local generation = type(context) == "table" and context.generation or nil
    for pendingLink, bucket in pairs(Addon.pendingItems) do
        if pendingLink ~= itemLink
            and type(bucket) == "table"
            and (generation == nil or bucket.generation == generation)
            and Core.ExtractItemID(bucket.itemLink or pendingLink) == itemID
            and PendingBucketHasLooter(bucket, looter, generation)
        then
            if #itemLink <= #(bucket.itemLink or pendingLink) then
                -- Longest-wins for all sources: keep the detailed variant unless
                -- the incoming quality color proves an upgrade (rare encounter
                -- vs epic chat for the same drop).
                local function pendingLinkQuality(link)
                    local color = type(link) == "string" and link:match("|c[fF][fF](%x%x%x%x%x%x)") or nil
                    if not color then
                        return nil
                    end
                    color = color:lower()
                    if color == "9d9d9d" then return 0
                    elseif color == "ffffff" then return 1
                    elseif color == "1eff00" then return 2
                    elseif color == "0070dd" then return 3
                    elseif color == "a335ee" then return 4
                    elseif color == "ff8000" then return 5
                    elseif color == "e6cc80" then return 6
                    elseif color == "00ccff" then return 7
                    else return nil end
                end
                local existingQuality = pendingLinkQuality(bucket.itemLink or pendingLink)
                local incomingQuality = pendingLinkQuality(itemLink)
                if incomingQuality and existingQuality and incomingQuality > existingQuality then
                    -- Quality upgrade wins; fall through to the split path below.
                else
                    if #itemLink == #(bucket.itemLink or pendingLink) then
                        RecordDiagnostic("pending_duplicate_loot_kept", {
                            looter = looter,
                            itemLink = itemLink,
                            itemID = itemID,
                            source = source or "unknown",
                        })
                    end
                    UpdatePendingWaiterContext(bucket, looter, context)
                    if not ProcessPendingItem(pendingLink, bucket) then
                        SchedulePendingItemRetry(pendingLink, bucket, 0)
                    end
                    return true
                end
            end
            -- A shared generic link can have multiple looters with distinct bonus variants.
            local remaining, target = {}, nil
            for index = 1, #bucket.waiters do
                local waiter = bucket.waiters[index]
                if waiter.looter == looter and (generation == nil or waiter.generation == generation) then
                    target = Core.AddPendingItemWaiter(Addon.pendingItems, itemLink, waiter)
                else
                    remaining[#remaining + 1] = waiter
                end
            end
            bucket.waiters = remaining
            if #remaining == 0 then
                Addon.pendingItems[pendingLink] = nil
            end
            bucket = target
            bucket.retryToken = nil
            UpdatePendingWaiterContext(bucket, looter, context)
            RecordDiagnostic("pending_duplicate_loot", {
                looter = looter,
                itemLink = itemLink,
                itemID = itemID,
                source = source or "unknown",
            })
            if not ProcessPendingItem(itemLink, bucket) then
                SchedulePendingItemRetry(itemLink, bucket, 0)
            end
            return true
        end
    end
    return false
end

function Addon.DrainCompletablePendingLoot()
    -- Finalize paths call this before closing a run: every pending bucket
    -- whose item data resolves now becomes rows; unresolvable buckets keep
    -- their own bounded retries instead of being dropped or duplicated.
    if type(Addon.pendingItems) ~= "table" then
        return
    end
    local links = {}
    for itemLink in pairs(Addon.pendingItems) do
        links[#links + 1] = itemLink
    end
    for index = 1, #links do
        local bucket = Addon.pendingItems[links[index]]
        if type(bucket) == "table" then
            ProcessPendingItem(links[index], bucket)
        end
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

    if not Addon.roster then
        BuildRoster()
    end
    if type(looter) == "string" and Addon.roster then
        local canonicalLooter = Core.ResolveRosterName(looter, Addon.roster)
        if type(canonicalLooter) == "string" and canonicalLooter ~= "" then
            looter = canonicalLooter
        end
    end

    context = type(context) == "table" and context or BuildDropContext(false)
    context.source = source or context.source
    if context.lootSource == "bonus_roll"
        and (Addon.UpgradeTrackedLootToBonus(looter, itemLink, context, source)
            or Addon.UpgradePendingLootToBonus(looter, itemLink, context, source))
    then
        return
    end
    if context.isGroupInstance ~= true then
        RecordDiagnostic("ignored_loot_context", {
            itemLink = itemLink,
            looter = looter,
            source = source or "unknown",
        })
        return
    end

    if context.skipDuplicateLoot ~= true then
        local duplicate, duplicateItemID = Addon.ShouldSkipDuplicateLoot(looter, itemLink)
        if duplicate then
            if MergeDuplicatePendingLoot(looter, itemLink, context, source) then
                return
            end
            if context.lootSource == "bonus_roll"
                and (Addon.UpgradeTrackedLootToBonus(looter, itemLink, context, source)
                    or Addon.UpgradePendingLootToBonus(looter, itemLink, context, source))
            then
                return
            end
            local row = Addon.FindTrackedLootRow(looter, itemLink) or Addon.FindTrackedLootRowByItemID(looter, duplicateItemID)
            if not row then
                local function baseName(name)
                    return type(name) == "string" and name:match("^([^-]+)") or nil
                end
                local function lootersCanonicallyEqual(left, right)
                    if left == right then
                        return true
                    end
                    if Addon.roster then
                        local leftCanonical = Core.ResolveRosterName(left, Addon.roster)
                        local rightCanonical = Core.ResolveRosterName(right, Addon.roster)
                        if leftCanonical and leftCanonical == right then
                            return true
                        end
                        if rightCanonical and rightCanonical == left then
                            return true
                        end
                        if leftCanonical and rightCanonical and leftCanonical == rightCanonical then
                            return true
                        end
                    end
                    local leftBase = baseName(left)
                    local rightBase = baseName(right)
                    return leftBase ~= nil and leftBase == rightBase
                end
                local function findLegacyRow()
                    if type(Addon.state) ~= "table" then
                        return nil
                    end
                    local lists = { Addon.state.allRows, Addon.state.currentRows, Addon.state.sessionAllRows, Addon.state.sessionRows }
                    for listIndex = 1, #lists do
                        local list = lists[listIndex]
                        if type(list) == "table" then
                            for rowIndex = #list, 1, -1 do
                                local candidate = list[rowIndex]
                                if type(candidate) == "table" then
                                    local candidateItemID = candidate.itemID or Core.ExtractItemID(candidate.itemLink)
                                    if candidateItemID and candidateItemID == duplicateItemID and candidate.timestamp == context.timestamp
                                        and lootersCanonicallyEqual(candidate.looter, looter) then
                                        return candidate
                                    end
                                end
                            end
                        end
                    end
                    return nil
                end
                local legacyRow = findLegacyRow()
                if legacyRow then
                    legacyRow.looter = looter
                    row = legacyRow
                end
            end
            if Addon.UpdateTrackedLootLink(row, itemLink, source) then
                RecordDiagnostic("duplicate_loot_link_updated", {
                    looter = looter,
                    itemLink = itemLink,
                    itemID = duplicateItemID,
                    source = source or "unknown",
                })
                SaveDB()
                RefreshRows()
                local recheckMetadata = ReadItemMetadata(itemLink)
                if recheckMetadata then
                    Addon.ScheduleWarbandRecheck(row, recheckMetadata)
                end
            end
            RecordDiagnostic("duplicate_loot", {
                looter = looter,
                itemLink = itemLink,
                source = source or "unknown",
            })
            return
        end
    end

    if context.skipDuplicateLoot ~= true and MergeDuplicatePendingLoot(looter, itemLink, context, source) then
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
    local looter, unsafe, unsafeReason, lootSource, isSelfLoot = FindLooterFromMessage(message, ...)
    local context = BuildDropContext(unsafe, unsafeReason)
    context.lootSource = lootSource
    context.isSelfLoot = isSelfLoot == true
    Addon.HandleResolvedLoot(looter, itemLink, context, "chat")
end

function Addon.HandleEncounterLootReceived(encounterID, itemID, itemLink, quantity, playerName, classFileName)
    RecordDiagnostic("loot_event", {
        source = "encounter",
        itemID = CleanNumber(itemID),
        looter = CleanString(playerName),
        classToken = CleanString(classFileName),
    })

    local looter, unsafeReason = Addon.ResolveEncounterLootLooter(playerName, classFileName)
    local context = BuildDropContext(unsafeReason ~= nil, unsafeReason)
    context.classToken = CleanString(classFileName)
    -- Mirror the chat path: encounter loot can be our own (bonus/personal),
    -- and revalidation checks row.isSelfLoot before reopening Ask.
    local selfName = SafePlayerName()
    context.isSelfLoot = type(looter) == "string" and type(selfName) == "string" and looter == selfName
    if unsafeReason == "ambiguous_looter" then
        context.skipDuplicateLoot = true
    end
    Addon.HandleResolvedLoot(looter, itemLink, context, "encounter")
end

function Addon.CompleteCurrentGroup(encounterName)
    if not Addon.state or (#Addon.state.currentRows == 0 and #(Addon.state.allRows or {}) == 0) then
        return
    end
    local reading = Addon.CaptureReadingPosition()
    Addon.currentHistoryFallbackGroup = Core.CompleteCurrentGroup(Addon.state, {
        instanceName = Addon.currentInstanceName or SafeInstanceName(),
        encounterName = encounterName or Addon.currentEncounterName or Core.FirstRowEncounterName(Addon.state.currentRows) or Core.FirstRowEncounterName(Addon.state.allRows),
        locale = ActiveLocale(),
        startedAt = Addon.currentEncounterStartedAt,
        endedAt = Now(),
        mergeWindow = ENCOUNTER_LOOT_GRACE,
    })
    Addon.RestoreReadingPosition(reading, false)
    Addon.challengeFinalizeToken = nil
    Addon.recentEncounterFinalizeToken = nil
    if Addon.contentMode ~= "settings" then
        Addon.EnterLootMode()
    end
    SaveDB()
    RefreshRows()
end

local function SelectView(view, historyIndex)
    Addon.demoRows = nil
    Addon.selectedView = view
    Addon.selectedHistoryIndex = historyIndex
    Addon.rowScrollOffset = 0
    if view == "current" then Addon.newLootPending = false end
    Addon.EnterLootMode()
    RefreshRows()
end

function Addon.ShowNewLoot()
    SelectView("current")
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

function Addon.FormatHistoryTimestamp(timestamp)
    local value = CleanNumber(timestamp)
    if not value or value <= 0 then
        return nil
    end

    local formatter = type(date) == "function" and date or (os and type(os.date) == "function" and os.date)
    local text = CleanString(SafeCall(formatter, "%d.%m %H:%M", value))
    return text ~= "" and text or nil
end

function Addon.HistoryGroupMenuTitle(group, index)
    -- Render from stored instance/encounter names so a language switch
    -- re-localizes the menu instead of showing a frozen completion-time title.
    local title = Core.GetHistoryGroupTitle(group, ActiveLocale())
    if not title then
        title = L("History") .. " " .. tostring(index)
    end

    local timestamp = type(group) == "table" and Addon.FormatHistoryTimestamp(group.endedAt or group.startedAt) or nil
    if timestamp then
        return timestamp .. " - " .. title
    end
    return title
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
                rootDescription:CreateButton(Addon.HistoryGroupMenuTitle(group, index), function()
                    SelectView("history", index)
                end)
            end
        end)
    else
        CycleHistoryView()
    end
end

function Addon.EquippedItemLinks(text)
    text = CleanString(text)
    local first = FirstItemLink(text)
    if not first then
        return nil, nil
    end
    local _, finish = text:find(first, 1, true)
    return first, finish and FirstItemLink(text:sub(finish + 1)) or nil
end

function Addon.StyleButton(button, accent)
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(accent and 0.08 or 0.075, accent and 0.23 or 0.095, accent and 0.31 or 0.125, 1)
    SafeCall(button.SetBackdropBorderColor, button, 0.22, accent and 0.48 or 0.29, accent and 0.60 or 0.37, 0.8)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8", "ADD")
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(0.18, 0.36, 0.48, 0.22)
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, ROW_START_Y - ((index - 1) * ROW_STRIDE))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.085, 0.108, 0.14, index % 2 == 0 and 0.92 or 0.65)
    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.accent:SetWidth(2)
    row.rule = row:CreateTexture(nil, "BORDER")
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.rule:SetHeight(1)
    row.rule:SetColorTexture(0.25, 0.32, 0.40, 0.22)

    row.looter = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.looter:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -2)
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
    row.dropLink:SetPoint("TOPLEFT", row, "TOPLEFT", 104, -1)
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
    row.equippedLink:SetPoint("TOPLEFT", row, "TOPLEFT", 294, -1)
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

    row.equipped2 = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.equipped2:SetPoint("LEFT", row.equipped, "RIGHT", 8, 0)
    row.equipped2:SetWidth((ROW_EQUIPPED_WIDTH - 8) / 2)
    row.equipped2:SetJustifyH("LEFT")
    KeepOneLine(row.equipped2)
    RegisterFontString(row.equipped2, 11, nil, false, true)
    row.equipped2:Hide()
    row.equippedDivider = row:CreateTexture(nil, "ARTWORK")
    row.equippedDivider:SetPoint("LEFT", row.equipped, "RIGHT", 3, 0)
    row.equippedDivider:SetSize(1, 10)
    row.equippedDivider:SetColorTexture(0.45, 0.55, 0.66, 0.5)
    row.equippedDivider:Hide()
    row.equippedLink2 = CreateFrame("Button", nil, row)
    row.equippedLink2:SetPoint("TOPLEFT", row, "TOPLEFT", 294 + (ROW_EQUIPPED_WIDTH - 8) / 2 + 8, -1)
    row.equippedLink2:SetSize((ROW_EQUIPPED_WIDTH - 8) / 2 + 2, ROW_HEIGHT)
    row.equippedLink2:RegisterForClicks("AnyUp")
    row.equippedLink2:SetScript("OnEnter", function(button)
        ShowItemTooltip(button, button.itemLink)
    end)
    row.equippedLink2:SetScript("OnLeave", HideItemTooltip)
    row.equippedLink2:SetScript("OnClick", function(button)
        OpenItemLink(button, button.itemLink)
    end)
    row.equippedLink2:Hide()

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetPoint("TOPLEFT", row.looter, "BOTTOMLEFT", 0, -2)
    row.status:SetWidth(ROW_STATUS_WIDTH)
    row.status:SetJustifyH("LEFT")
    KeepOneLine(row.status)
    RegisterFontString(row.status, 10, nil, false, true)

    row.trade = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.trade:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 2)
    row.trade:SetWidth(110)
    row.trade:SetJustifyH("RIGHT")
    KeepOneLine(row.trade)
    RegisterFontString(row.trade, 9, nil, false, true)

    row.tradeInfo = CreateFrame("Button", nil, row)
    row.tradeInfo:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 1)
    row.tradeInfo:SetSize(110, 11)
    row.tradeInfo:SetScript("OnEnter", function(button)
        Addon.ShowTextTooltip(button, button.tooltipText)
    end)
    row.tradeInfo:SetScript("OnLeave", HideItemTooltip)
    row.tradeInfo:Hide()

    row.whisper = CreateFrame("Button", nil, row, "UIPanelButtonTemplate,BackdropTemplate")
    row.whisper:SetSize(48, 16)
    row.whisper:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -2)
    row.whisper:SetText("Ask")
    Addon.StyleButton(row.whisper, true)
    row.whisper:SetScript("OnClick", function(button)
        local data = button:GetParent().row
        if data then
            CancelPendingAuto(data)
            SendWhisper(data, false)
        end
    end)
    -- Keep transient Sending/Sent labels readable inside the compact action column.
    RegisterButtonFont(row.whisper, 11, nil, nil, 12)

    row:Hide()
    return row
end

function Addon.NormalizeWindowPosition(value)
    if type(value) ~= "table" then return nil end
    local anchors = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    local point, relativePoint = CleanString(value.point), CleanString(value.relativePoint)
    local x, y = CleanNumber(value.x), CleanNumber(value.y)
    if not point or not relativePoint or not anchors[point] or not anchors[relativePoint]
        or not x or not y or x ~= x or y ~= y
        or math.abs(x) > 10000 or math.abs(y) > 10000 then return nil end
    return { point = point, relativePoint = relativePoint, x = x, y = y }
end

function Addon.SaveWindowPosition()
    if not Addon.frame or type(DoYouNeedItDB) ~= "table" then return end
    local point, relative, relativePoint, x, y = SafeCall(Addon.frame.GetPoint, Addon.frame)
    if relative and relative ~= UIParent then return end
    local position = Addon.NormalizeWindowPosition({ point = point, relativePoint = relativePoint, x = x, y = y })
    if position then DoYouNeedItDB.windowPosition = position end
end

function Addon.RestoreWindowPosition()
    if not Addon.frame then return end
    local position = Addon.NormalizeWindowPosition(DoYouNeedItDB and DoYouNeedItDB.windowPosition)
        or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    Addon.frame:ClearAllPoints()
    Addon.frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    Addon.frame:SetUserPlaced(true)
end

function Addon.ResetWindowPosition()
    if type(DoYouNeedItDB) ~= "table" then
        DoYouNeedItDB = {}
    end
    DoYouNeedItDB.windowPosition = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    Addon.RestoreWindowPosition()
end

CreateUI = function()
    if Addon.frame then
        return
    end

    local frame = CreateFrame("Frame", "DoYouNeedItFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    -- DIALOG strata alone can slide under other addons' windows; toplevel
    -- keeps the loot window above foreign UI while it is shown.
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "DoYouNeedItFrame")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Addon.SaveWindowPosition()
    end)
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(true)
    end
    frame:SetScript("OnMouseWheel", function(_, delta)
        -- Settings mode shows no loot rows; scrolling there must not move a
        -- hidden reading position that would surprise the user on return.
        if Addon.contentMode == "settings" then
            return
        end
        local value = CleanNumber(delta) or 0
        if value == 0 then
            return
        end
        local rows = RowsForSelectedView()
        if #rows <= Addon.GetVisibleRowCount() then
            Addon.rowScrollOffset = 0
            RefreshRows()
            return
        end
        Addon.rowScrollOffset = (tonumber(Addon.rowScrollOffset) or 0) + (value < 0 and 1 or -1)
        RefreshRows()
    end)
    frame:SetScript("OnHide", function()
        if type(Addon.EnterLootMode) == "function" then
            Addon.HideLootRows()
            Addon.EnterLootMode()
        else
            Addon.contentMode = "loot"
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.035, 0.047, 0.065, 0.98)
    SafeCall(frame.SetBackdropBorderColor, frame, 0.23, 0.31, 0.40, 0.95)
    frame.headerBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.headerBackground:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.headerBackground:SetHeight(34)
    frame.headerBackground:SetColorTexture(0.075, 0.105, 0.145, 1)
    frame.headerAccent = frame:CreateTexture(nil, "ARTWORK")
    frame.headerAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -34)
    frame.headerAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -34)
    frame.headerAccent:SetHeight(1)
    frame.headerAccent:SetColorTexture(0.22, 0.62, 0.82, 0.55)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -10)
    frame.title:SetWidth(286)
    frame.title:SetJustifyH("LEFT")
    KeepOneLine(frame.title)
    frame.title:SetText(L("Do You Need It?"))
    frame.title:SetTextColor(0.86, 0.94, 1, 1)
    RegisterFontString(frame.title, 16)

    frame.historyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,BackdropTemplate")
    frame.historyButton:SetSize(HEADER_HISTORY_WIDTH, 22)
    frame.historyButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42)
    frame.historyButton:SetText(L("Current"))
    Addon.StyleButton(frame.historyButton, false)
    local historyText = frame.historyButton:GetFontString()
    historyText:ClearAllPoints()
    historyText:SetPoint("LEFT", frame.historyButton, "LEFT", 10, 0)
    historyText:SetWidth(HEADER_HISTORY_WIDTH - 100)
    historyText:SetJustifyH("LEFT")
    frame.historyButton:SetScript("OnClick", function(button)
        OpenHistoryMenu(button)
    end)
    RegisterButtonFont(frame.historyButton, 11)
    Addon.historyButton = frame.historyButton

    frame.newLootButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,BackdropTemplate")
    frame.newLootButton:SetSize(100, 22)
    frame.newLootButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -65, -7)
    frame.newLootButton:SetText(L("New loot"))
    Addon.StyleButton(frame.newLootButton, true)
    RegisterButtonFont(frame.newLootButton, 11)
    frame.newLootButton:SetScript("OnClick", function()
        if type(Addon.ShowNewLoot) == "function" then
            Addon.ShowNewLoot()
        end
    end)
    frame.newLootButton:Hide()
    Addon.newLootButton = frame.newLootButton

    local function createColumnHeader(key, x, width, justify)
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label.columnX = x
        label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -68)
        label:SetWidth(width)
        label:SetJustifyH(justify or "LEFT")
        label:SetText(L(key))
        label:SetTextColor(0.62, 0.67, 0.74, 1)
        KeepOneLine(label)
        RegisterFontString(label, 9, nil, false, true)
        return label
    end

    frame.columnPlayer = createColumnHeader("Player", 18, ROW_LOOTER_WIDTH)
    frame.columnDrop = createColumnHeader("Dropped", 116, ROW_DROP_WIDTH)
    frame.columnEquipped = createColumnHeader("Equipped now", 306, ROW_EQUIPPED_WIDTH)
    frame.columnTrade = createColumnHeader("Trade", 456, 58, "RIGHT")
    Addon.columnHeaders = {
        frame.columnPlayer,
        frame.columnDrop,
        frame.columnEquipped,
        frame.columnTrade,
    }

    frame.settingsButton = CreateFrame("Button", nil, frame)
    frame.settingsButton:SetSize(22, 22)
    frame.settingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -8)
    frame.settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.settingsButton:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.settingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    frame.settingsButton:SetScript("OnEnter", function(button)
        Addon.ShowTextTooltip(button, L("Settings"))
    end)
    frame.settingsButton:SetScript("OnLeave", HideItemTooltip)
    frame.settingsButton:SetScript("OnClick", OpenSettings)
    Addon.settingsButton = frame.settingsButton

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.emptyText:SetPoint("CENTER", frame, "CENTER", 0, 2)
    frame.emptyText:SetWidth(470)
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetText(L("No gear drops in this view."))
    RegisterFontString(frame.emptyText, 12)
    Addon.emptyText = frame.emptyText

    frame.emptyHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.emptyHelp:SetPoint("TOP", frame.emptyText, "BOTTOM", 0, -12)
    frame.emptyHelp:SetWidth(470)
    frame.emptyHelp:SetJustifyH("CENTER")
    frame.emptyHelp:SetTextColor(0.50, 0.59, 0.69, 1)
    frame.emptyHelp:SetText(L("Gear from your dungeon or raid will appear here."))
    RegisterFontString(frame.emptyHelp, 11, nil, false, true)
    Addon.emptyHelp = frame.emptyHelp

    frame.scrollBadge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.scrollBadge:SetSize(76, 16)
    frame.scrollBadge:SetPoint("TOPRIGHT", frame.historyButton, "TOPRIGHT", -2, -3)
    frame.scrollBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 8,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame.scrollBadge:SetBackdropColor(0.10, 0.16, 0.21, 1)
    frame.scrollBadge:Hide()
    Addon.scrollBadge = frame.scrollBadge

    frame.scrollText = frame.scrollBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.scrollText:SetAllPoints(frame.scrollBadge)
    frame.scrollText:SetJustifyH("CENTER")
    frame.scrollText:SetTextColor(0.95, 0.95, 0.95, 1)
    KeepOneLine(frame.scrollText)
    RegisterFontString(frame.scrollText, 11)
    Addon.scrollText = frame.scrollText

    for index = 1, MAX_VISIBLE_ROWS do
        Addon.rowFrames[index] = CreateRow(frame, index)
    end

    Addon.frame = frame
    Addon.RestoreWindowPosition()
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

function Addon.LayoutSettings()
    local frame = Addon.settingsFrame
    if not frame then
        return
    end
    local layoutPreview = Addon.sliderPreview and Addon.sliderPreview.fontSize
    local size = tonumber(layoutPreview) or Addon.state.settings.fontSize
    local extra = math.max(0, size - 12)
    local height = SETTINGS_WINDOW_HEIGHT + extra * 13
    frame:SetHeight(height - 66)
    if Addon.contentMode == "settings" then
        Addon.frame:SetHeight(height)
    end
    local function place(control, x, y)
        control:ClearAllPoints()
        control:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    end
    place(frame.whispersHeading, 10, 38)
    place(frame.autoCheck, 4, 56 + extra)
    place(frame.delayLabel, 10, 94 + extra * 2)
    place(frame.delaySlider, SETTINGS_CONTROL_X, 98 + extra * 2)
    place(frame.whisperLabel, 10, 133 + extra * 4)
    place(frame.whisperEditBox, SETTINGS_CONTROL_X, 130 + extra * 4)
    place(frame.whisperHelp, SETTINGS_CONTROL_X, 158 + extra * 5)
    place(frame.appearanceHeading, 10, 190 + extra * 6)
    place(frame.appearanceRule, 10, 181 + extra * 6)
    place(frame.languageLabel, 10, 215 + extra * 7)
    place(frame.languageDropdown, SETTINGS_CONTROL_X - 16, 211 + extra * 7)
    place(frame.fontLabel, 10, 256 + extra * 9)
    place(frame.fontDropdown, SETTINGS_CONTROL_X - 16, 252 + extra * 9)
    place(frame.fontSizeLabel, 10, 297 + extra * 11)
    place(frame.fontSizeSlider, SETTINGS_CONTROL_X, 301 + extra * 11)
    place(frame.fontWarning, 10, 336 + extra * 12)
    frame.whisperEditBox:SetHeight(math.max(22, size + 8))
    frame.whisperResetButton:SetHeight(math.max(22, size + 8))
    frame.back:SetHeight(math.max(22, size + 6))
    frame.resetPosition:SetHeight(math.max(22, size + 6))
end

RefreshSettingsControls = function()
    if not Addon.settingsFrame or not Addon.state then
        return
    end
    local settings = Addon.state.settings
    Addon.LayoutSettings()
    Addon.settingsFrame.whispersHeading:SetText(L("Whispers"))
    Addon.settingsFrame.appearanceHeading:SetText(L("Appearance"))
    Addon.settingsFrame.whisperHelp:SetText(L("Use {item} for the dropped item."))
    Addon.settingsFrame.resetPosition:SetText(L("Reset Position"))
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
        Addon.delaySlider:SetValue((Addon.sliderPreview and Addon.sliderPreview.delay) or settings.autoDelay)
        Addon.updatingControls = false
        ConfigureSliderTemplateLabels(Addon.delaySlider, L("Low"), L("High"))
    end
    if Addon.delayValue then
        Addon.delayValue:SetText(((Addon.sliderPreview and Addon.sliderPreview.delay) or settings.autoDelay) .. "s")
    end
    if Addon.whisperLabel then
        Addon.whisperLabel:SetText(L("Whisper text:"))
    end
    if Addon.whisperEditBox and not Addon.whisperTemplateFocused and Addon.whisperEditBox:GetText() ~= settings.whisperTemplate then
        Addon.whisperEditBox:SetText(settings.whisperTemplate)
    end
    if Addon.whisperResetButton then
        local armedAt = tonumber(Addon.whisperResetArmedAt)
        local now = Now()
        if armedAt and type(now) == "number" and now - armedAt > 5 then
            Addon.whisperResetArmedAt = nil
            armedAt = nil
        end
        if armedAt then
            Addon.whisperResetButton:SetText(L("Reset") .. "?")
        else
            Addon.whisperResetButton:SetText(L("Reset"))
        end
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
        Addon.fontSizeSlider:SetValue((Addon.sliderPreview and Addon.sliderPreview.fontSize) or settings.fontSize)
        Addon.updatingControls = false
        ConfigureSliderTemplateLabels(Addon.fontSizeSlider, L("Low"), L("High"))
    end
    if Addon.fontSizeValue then
        Addon.fontSizeValue:SetText((Addon.sliderPreview and Addon.sliderPreview.fontSize) or settings.fontSize)
    end
    if Addon.languageDropdown then
        SetDropdownTextSafe(Addon.languageDropdown, CurrentLanguageLabel())
    end
    if Addon.fontDropdown then
        SetDropdownTextSafe(Addon.fontDropdown, FindFontName(Addon.ValidatedDisplayFont()))
    end
    RefreshFontWarning()
end

RefreshLocalization = function()
    if Addon.frame and Addon.frame.title then
        Addon.frame.title:SetText(L("Do You Need It?"))
        Addon.frame.columnPlayer:SetText(L("Player"))
        Addon.frame.columnDrop:SetText(L("Dropped"))
        Addon.frame.columnEquipped:SetText(L("Equipped now"))
        Addon.frame.columnTrade:SetText(L("Trade"))
        Addon.frame.newLootButton:SetText(L("New loot"))
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

local function SetFontSize(value, previewOnly)
    local number = tonumber(value)
    if previewOnly then
        -- Drag ticks stage in Addon.sliderPreview: live settings (with
        -- their scheduler/status readers) stay on the saved size while
        -- painters follow the preview. Bounds mirror NormalizeSettings.
        Addon.sliderPreview = Addon.sliderPreview or {}
        Addon.sliderPreview.fontSize = math.floor(math.min(24, math.max(8, number or Addon.state.settings.fontSize)) + 0.5)
        ApplyCurrentFont()
        RefreshSettingsControls()
        return
    end
    Addon.state.settings.fontSize = number or Addon.state.settings.fontSize
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    ApplyCurrentFont()
    RefreshSettingsControls()
end

function Addon.CommitSliderChanges()
    local preview = Addon.sliderPreview
    if type(preview) ~= "table" or (preview.delay == nil and preview.fontSize == nil) then
        return
    end
    Addon.sliderPreview = nil
    if preview.delay ~= nil then
        Addon.state.settings.autoDelay = preview.delay
    end
    if preview.fontSize ~= nil then
        Addon.state.settings.fontSize = preview.fontSize
    end
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    RefreshRows()
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

function Addon.FontPickerMetrics()
    local settings = Addon.state and Addon.state.settings or {}
    local pickerPreview = Addon.sliderPreview and Addon.sliderPreview.fontSize
    local buttonHeight = math.max(22, Core.ResolveFontSize(12, tonumber(pickerPreview) or settings.fontSize) + 4)
    local metrics = { cols = 3, buttonWidth = 160, buttonHeight = buttonHeight, pad = 8, scrollbarWidth = 22 }
    metrics.visibleRows = math.max(1, math.floor(308 / buttonHeight))
    metrics.frameWidth = metrics.cols * metrics.buttonWidth + metrics.pad * 2 + metrics.scrollbarWidth
    metrics.frameHeight = metrics.visibleRows * buttonHeight + metrics.pad * 2
    return metrics
end

local function BuildFontPickerFrame()
    local metrics = Addon.FontPickerMetrics()
    local cols, buttonWidth = metrics.cols, metrics.buttonWidth
    local pad, scrollbarWidth = metrics.pad, metrics.scrollbarWidth

    local picker = CreateFrame("Frame", "DoYouNeedItFontPicker", UIParent, "BackdropTemplate")
    picker:SetSize(metrics.frameWidth, metrics.frameHeight)
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

    local metrics = Addon.FontPickerMetrics()
    local cols, buttonWidth = metrics.cols, metrics.buttonWidth
    local buttonHeight, visibleRows = metrics.buttonHeight, metrics.visibleRows
    local fonts = BuildFontsList(ActiveLocale())
    local currentPath = Addon.state and Addon.state.settings and Addon.state.settings.font
    local rows = math.ceil(#fonts / cols)
    local currentRow

    Addon.fontPickerFrame:SetSize(metrics.frameWidth, metrics.frameHeight)
    Addon.fontPickerContent:SetSize(cols * buttonWidth, math.max(rows * buttonHeight, 1))

    for index, font in ipairs(fonts) do
        local button = Addon.fontPickerButtons[index]
        if not button then
            button = CreateFrame("Button", nil, Addon.fontPickerContent)

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
        button:SetSize(buttonWidth, buttonHeight)
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

-- WHY eager-commit: leaving settings always saves the focused whisper
-- draft, like every other control applies instantly. No Save/Discard step.
function Addon.CommitFocusedWhisperTemplate()
    if Addon.whisperEditBox and Addon.whisperTemplateFocused and not Addon.committingWhisperTemplate then
        Addon.committingWhisperTemplate = true
        Addon.whisperTemplateFocused = false
        Addon.whisperResetArmedAt = nil
        SetWhisperTemplate(Addon.whisperEditBox:GetText())
        Addon.committingWhisperTemplate = false
    end
end

function Addon.EnterLootMode()
    local leavingSettings = Addon.contentMode == "settings" or (Addon.settingsFrame and Addon.settingsFrame:IsShown())
    if leavingSettings then
        Addon.CommitFocusedWhisperTemplate()
        Addon.CommitSliderChanges()
        -- An armed template reset belongs to the settings screen.
        Addon.whisperResetArmedAt = nil
        HideFontPicker()
        SafeCall(CloseDropDownMenus)
        CancelSettingsPreview()
    end
    Addon.contentMode = "loot"
    if Addon.frame then
        Addon.frame:SetHeight(WINDOW_HEIGHT)
    end
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
    frame:SetSize(508, SETTINGS_WINDOW_HEIGHT - 66)
    frame:SetPoint("TOPLEFT", Addon.frame, "TOPLEFT", 16, -50)
    frame:SetFrameLevel((Addon.frame and Addon.frame:GetFrameLevel() or 0) + 5)
    frame:EnableMouse(true)
    frame:SetScript("OnHide", function()
        Addon.CommitFocusedWhisperTemplate()
        if GameTooltip and CleanBoolean(SafeCall(GameTooltip.IsOwned, GameTooltip, frame.autoCheck)) == true then
            HideItemTooltip()
        end
        HideFontPicker()
        CancelSettingsPreview()
    end)

    frame.back = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,BackdropTemplate")
    frame.back:SetSize(70, 22)
    frame.back:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 2)
    Addon.StyleButton(frame.back, false)
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

    frame.resetPosition = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,BackdropTemplate")
    frame.resetPosition:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 2)
    frame.resetPosition:SetSize(132, 22)
    frame.resetPosition:SetText(L("Reset Position"))
    Addon.StyleButton(frame.resetPosition, false)
    RegisterButtonFont(frame.resetPosition, 11, nil, true)
    frame.resetPosition:SetScript("OnClick", function()
        if type(Addon.ResetWindowPosition) == "function" then
            Addon.ResetWindowPosition()
        end
    end)

    local function sectionLabel(key)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetWidth(470)
        text:SetText(L(key))
        text:SetTextColor(0.36, 0.76, 0.92, 1)
        text:SetJustifyH("LEFT")
        KeepOneLine(text)
        RegisterFontString(text, 10, nil, true)
        return text
    end
    frame.whispersHeading = sectionLabel("Whispers")
    frame.appearanceHeading = sectionLabel("Appearance")
    frame.appearanceRule = frame:CreateTexture(nil, "BACKGROUND")
    frame.appearanceRule:SetSize(488, 1)
    frame.appearanceRule:SetColorTexture(0.26, 0.34, 0.42, 0.55)
    frame.whisperHelp = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.whisperHelp:SetWidth(370)
    frame.whisperHelp:SetJustifyH("LEFT")
    frame.whisperHelp:SetTextColor(0.51, 0.61, 0.70, 1)
    frame.whisperHelp:SetText(L("Use {item} for the dropped item."))
    KeepOneLine(frame.whisperHelp)
    RegisterFontString(frame.whisperHelp, 10, nil, true)

    frame.headerRule = frame:CreateTexture(nil, "BACKGROUND")
    frame.headerRule:SetColorTexture(0.26, 0.34, 0.42, 0.55)
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
    frame.autoCheck:SetScript("OnEnter", function(check)
        Addon.ShowTextTooltip(check, L("Only eligible new drops. Off by default."))
    end)
    frame.autoCheck:SetScript("OnLeave", HideItemTooltip)
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
        SetDelay(math.floor((tonumber(value) or 10) + 0.5), true, true)
    end)
    -- Slider ticks apply instantly on screen but reach SavedVariables only on
    -- release (or when settings close), so a single drag is one disk write.
    frame.delaySlider:SetScript("OnMouseUp", function()
        Addon.CommitSliderChanges()
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
        Addon.whisperResetArmedAt = nil
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
        Addon.whisperResetArmedAt = nil
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

    frame.whisperResetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate,BackdropTemplate")
    frame.whisperResetButton:SetPoint("LEFT", frame.whisperEditBox, "RIGHT", 8, 0)
    frame.whisperResetButton:SetSize(58, 22)
    Addon.StyleButton(frame.whisperResetButton, false)
    frame.whisperResetButton:SetScript("OnClick", function()
        -- Two-click reset: the first click arms ("Reset?"), the second
        -- inside 5s restores the default; typing disarms.
        local armedAt = tonumber(Addon.whisperResetArmedAt)
        local now = Now()
        if armedAt and type(now) == "number" and now - armedAt <= 5 then
            Addon.whisperResetArmedAt = nil
            Addon.whisperTemplateFocused = false
            SetWhisperTemplate(nil)
            SafeCall(frame.whisperEditBox.ClearFocus, frame.whisperEditBox)
        else
            Addon.whisperResetArmedAt = Now()
            Addon.whisperTemplateFocused = false
            frame.whisperResetButton:SetText(L("Reset") .. "?")
        end
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
        SetFontSize(math.floor((tonumber(value) or 12) + 0.5), true)
    end)
    -- See the delay slider above: ticks preview, release persists.
    frame.fontSizeSlider:SetScript("OnMouseUp", function()
        Addon.CommitSliderChanges()
    end)
    Addon.fontSizeSlider = frame.fontSizeSlider

    frame.fontSizeValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.fontSizeValue:SetPoint("LEFT", frame.fontSizeSlider, "RIGHT", 12, 0)
    frame.fontSizeValue:SetWidth(40)
    frame.fontSizeValue:SetJustifyH("LEFT")
    RegisterFontString(frame.fontSizeValue, 12, nil, true)
    Addon.fontSizeValue = frame.fontSizeValue

    frame.fontWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.fontWarning:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -304)
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
    Addon.frame:SetHeight(SETTINGS_WINDOW_HEIGHT)
    Addon.frame:Show()
    Addon.settingsFrame:Show()
    RefreshRows()
    RefreshSettingsControls()
end

local function CancelAllPendingAuto(cancelManual)
    if type(Addon.state) ~= "table" then
        return
    end

    -- Drop queued automatic rows with the flags below; an armed pump then
    -- finds an empty queue and stops by itself.
    Addon.autoWhisperQueue = {}
    local seen = {}
    local function cancelList(list)
        if type(list) ~= "table" then
            return
        end
        for index = 1, #list do
            local row = list[index]
            if type(row) == "table" and not seen[row] then
                seen[row] = true
                CancelPendingAuto(row, cancelManual)
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

SetDelay = function(value, quiet, previewOnly)
    local number = tonumber(value)
    if previewOnly then
        -- See SetFontSize: drag ticks stage here, release/close commits.
        Addon.sliderPreview = Addon.sliderPreview or {}
        local bounds = Addon.state.settings
        Addon.sliderPreview.delay = math.floor(math.min(bounds.maxDelay, math.max(bounds.minDelay, number or bounds.autoDelay)) + 0.5)
        RefreshRows()
        RefreshSettingsControls()
        return
    end
    local old = Addon.state.settings.autoDelay
    Addon.state.settings.autoDelay = number or old
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    RefreshRows()
    RefreshSettingsControls()
    if not quiet and Addon.state.settings.autoDelay ~= number then
        Print("delay must be between " .. Addon.state.settings.minDelay .. " and " .. Addon.state.settings.maxDelay .. " seconds")
    end
end

SetWhisperTemplate = function(value)
    Addon.state.settings.whisperTemplate = Core.NormalizeWhisperTemplate(value)
    Addon.state.settings = Core.NormalizeSettings(Addon.state.settings)
    SaveDB()
    RefreshSettingsControls()
end

-- In-game self-check for human verification: out-of-combat only, read-only,
-- never drives real loot. Prints a short human summary plus chunked DYNI1:
-- machine-readable key=value lines, and persists one compact report to the
-- dedicated _G.DoYouNeedItSelfTest table (never DoYouNeedItDB.diagnostics,
-- which keeps its debug-off purge privacy semantics).
function Addon.RunSelfTest(mode)
    local sub = string.lower(CleanString(mode) or "")
    if sub == "stop" or Addon.selfTestActive == true then
        Addon.selfTestActive = false
        Addon.selfTestCopyPendingAfterCombat = false
        Addon.selfTestCopyText = nil
        _G.DoYouNeedItSelfTest = nil
        Print("selftest stopped; stored report discarded")
        return
    end
    if CleanBoolean(SafeCall(InCombatLockdown)) == true then
        Print("selftest needs out-of-combat; run /dyni selftest after combat ends")
        return
    end
    Addon.selfTestActive = true

    local build = CleanString(Core.VERSION) or "unknown"
    local tocVersion = CleanString(SafeCall(GetAddOnMetadata, Addon.name, "Version")) or "unknown"
    local _ignoredA, _ignoredB, _ignoredC, interfaceBuild = SafeCall(GetBuildInfo)
    local iface = CleanNumber(interfaceBuild) or 0
    local clientLocale = ClientLocale()
    local activeLocale = CleanString(ActiveLocale()) or "unknown"

    local dbOk = type(DoYouNeedItDB) == "table"
    local settings = Addon.state and Addon.state.settings
    local settingsOk = type(settings) == "table"
        and CleanNumber(settings.autoDelay) ~= nil
        and CleanBoolean(settings.autoWhisper) ~= nil

    local storedOk = Addon.NormalizeWindowPosition(DoYouNeedItDB and DoYouNeedItDB.windowPosition) ~= nil
    local liveWidth, liveHeight = WINDOW_WIDTH, WINDOW_HEIGHT
    local livePoint, liveRelative, liveRelativePoint, liveX, liveY
    if Addon.frame then
        liveWidth = SafeCall(Addon.frame.GetWidth, Addon.frame) or liveWidth
        liveHeight = SafeCall(Addon.frame.GetHeight, Addon.frame) or liveHeight
        livePoint, liveRelative, liveRelativePoint, liveX, liveY = SafeCall(Addon.frame.GetPoint, Addon.frame)
    end
    liveWidth = CleanNumber(liveWidth) or 0
    liveHeight = CleanNumber(liveHeight) or 0
    local cleanX, cleanY = CleanNumber(liveX), CleanNumber(liveY)
    local liveOk = CleanString(livePoint) ~= nil
        and (liveRelative == nil or liveRelative == UIParent)
        and cleanX ~= nil and cleanY ~= nil
        and math.abs(cleanX) <= 10000 and math.abs(cleanY) <= 10000
    local geomOk = storedOk and liveOk

    -- The "2" suffix is concatenated so this file carries no literal
    -- second slash name (the static suite forbids the joined form).
    local secondSlash = rawget(_G, "SLASH_DOYOUNEEDIT" .. "2")
    local slashOk = CleanString(SLASH_DOYOUNEEDIT1) == "/dyni"
        and type(SlashCmdList) == "table"
        and type(SlashCmdList.DOYOUNEEDIT) == "function"
        and secondSlash == nil

    -- Reuse the RecordDiagnostic sanitizer as the buffer health probe: NaN,
    -- infinite, or non-scalar fields are dropped there, so any lost field
    -- means the in-memory buffer is unhealthy. Stages are counted by name
    -- only; no diagnostic payload leaves this summary.
    local diagnostics = Addon.diagnostics
    local diagCount = (type(diagnostics) == "table" and #diagnostics) or 0
    local diagHealthy = type(diagnostics) == "table"
    local stageCounts = {}
    local stageTotal = 0
    if type(diagnostics) == "table" then
        for index = 1, diagCount do
            local entry = diagnostics[index]
            if type(entry) ~= "table" then
                diagHealthy = false
            else
                local probe = Core.RecordDiagnostic({}, entry, MAX_DIAGNOSTICS)
                local wantFields, keptFields = 0, 0
                for wantKey in pairs(entry) do wantFields = wantFields + 1 end
                if type(probe) == "table" then
                    for keptKey in pairs(probe) do keptFields = keptFields + 1 end
                end
                if type(probe) ~= "table" or keptFields < wantFields then
                    diagHealthy = false
                end
                local stage = CleanString(entry.stage) or "unknown"
                stage = string.sub(stage, 1, 40):gsub("%s", "_")
                if stageCounts[stage] == nil then
                    if stageTotal >= 24 then
                        stage = "other"
                    else
                        stageTotal = stageTotal + 1
                    end
                end
                stageCounts[stage] = (stageCounts[stage] or 0) + 1
            end
        end
    end

    local cacheEntries = CountEquipmentCacheEntries()
    local pendingBuckets = 0
    if type(Addon.pendingItems) == "table" then
        for pendingKey in pairs(Addon.pendingItems) do pendingBuckets = pendingBuckets + 1 end
    end

    BuildRoster()
    local rosterSize = #(Addon.rosterEntries or {})
    local inRaid = CleanBoolean(SafeCall(IsInRaid)) == true
    local inGroup = inRaid or CleanBoolean(SafeCall(IsInGroup)) == true
    local groupKind = inRaid and "raid" or (inGroup and "party" or "solo")

    -- Existing counters only: queue depths, throttle streak, and generation
    -- liveness numbers. No new counters are introduced anywhere.
    local scanQueue = #(Addon.equipmentScanQueue or {})
    local inspectQueue = #(Addon.inspectQueue or {})
    local inspectActive = Addon.inspectActive ~= nil
    local autoQueue = #(Addon.autoWhisperQueue or {})
    local whisperStreak = CleanNumber(Addon.fastWhisperStreak) or 0
    local lastSentAt = CleanNumber(Addon.lastWhisperSentAt) or 0
    local sessionRows = (Addon.state and #(Addon.state.sessionRows or {})) or 0
    local sessionAll = (Addon.state and #(Addon.state.sessionAllRows or {})) or 0
    local historyGroups = (Addon.state and #(Addon.state.history or {})) or 0
    local scanScheduled = Addon.equipmentScanScheduled == true
    local inspectGen = CleanNumber(Addon.inspectGeneration) or 0
    local lootGen = CleanNumber(Addon.lootGeneration) or 0
    local finishedAt = CleanNumber(Now()) or 0

    local report = {
        build = build,
        toc = tocVersion,
        iface = iface,
        locale = activeLocale,
        client = clientLocale,
        sv = dbOk,
        settings = settingsOk,
        geom = geomOk,
        slash = slashOk,
        diag = diagHealthy,
        diagN = diagCount,
        cache = cacheEntries,
        pending = pendingBuckets,
        group = groupKind,
        roster = rosterSize,
        rows = sessionRows,
        all = sessionAll,
        hist = historyGroups,
        scanq = scanQueue,
        inspq = inspectQueue,
        inspActive = inspectActive,
        autoq = autoQueue,
        streak = whisperStreak,
        sentAt = lastSentAt,
        scanSched = scanScheduled,
        inspGen = inspectGen,
        lootGen = lootGen,
        stages = stageCounts,
    }
    _G.DoYouNeedItSelfTest = { version = 1, finishedAt = finishedAt, report = report }

    Print("selftest: build=" .. build .. " toc=" .. tocVersion
        .. " iface=" .. tostring(iface) .. " locale=" .. activeLocale
        .. " group=" .. groupKind .. ":" .. tostring(rosterSize))
    Print("selftest: settings=" .. (settingsOk and "ok" or "FAIL")
        .. " geom=" .. (geomOk and "ok" or "FAIL")
        .. " slash=" .. (slashOk and "ok" or "FAIL")
        .. " diag=" .. (diagHealthy and ("ok(" .. tostring(diagCount) .. ")") or "FAIL")
        .. " cache=" .. tostring(cacheEntries))
    Print("selftest: rows=" .. tostring(sessionRows) .. "/" .. tostring(sessionAll)
        .. " hist=" .. tostring(historyGroups)
        .. " scanq=" .. tostring(scanQueue) .. " inspq=" .. tostring(inspectQueue)
        .. " autoq=" .. tostring(autoQueue))
    Print("selftest: NOT checked: live loot,Ask whispers,trade detection (needs real group drops)")
    Print("selftest: re-show this report with /dyni selftest show")
    Addon.ShowSelfTestCopy()
    Addon.selfTestActive = false
end

-- Builds the full DYNI1 export block from a stored selftest report. Report
-- fields are re-cleaned on the way out, so only plain values can reach the
-- copy window or the chat fallback.
function Addon.BuildSelfTestCopyLines(saved)
    if type(saved) ~= "table" or type(saved.report) ~= "table" then
        return nil
    end
    local report = saved.report
    local build = CleanString(report.build) or "unknown"
    local tocVersion = CleanString(report.toc) or "unknown"
    local iface = CleanNumber(report.iface) or 0
    local activeLocale = CleanString(report.locale) or "unknown"
    local finishedAt = CleanNumber(saved.finishedAt) or 0
    local groupKind = CleanString(report.group) or "unknown"
    local rosterSize = CleanNumber(report.roster) or 0
    local sessionRows = CleanNumber(report.rows) or 0
    local sessionAll = CleanNumber(report.all) or 0
    local historyGroups = CleanNumber(report.hist) or 0
    local cacheEntries = CleanNumber(report.cache) or 0
    local pendingBuckets = CleanNumber(report.pending) or 0
    local scanQueue = CleanNumber(report.scanq) or 0
    local inspectQueue = CleanNumber(report.inspq) or 0
    local autoQueue = CleanNumber(report.autoq) or 0
    local diagCount = CleanNumber(report.diagN) or 0

    local copyLines = {
        "DYNI1: v=1 build=" .. build .. " toc=" .. tocVersion
            .. " iface=" .. tostring(iface) .. " locale=" .. activeLocale
            .. " at=" .. tostring(finishedAt),
        "DYNI1: sv=" .. ((report.sv == true) and "ok" or "FAIL")
            .. " settings=" .. ((report.settings == true) and "ok" or "FAIL")
            .. " geom=" .. ((report.geom == true) and "ok" or "FAIL")
            .. " slash=" .. ((report.slash == true) and "ok" or "FAIL")
            .. " diag=" .. ((report.diag == true) and "ok" or "FAIL"),
        "DYNI1: group=" .. groupKind .. " size=" .. tostring(rosterSize)
            .. " rows=" .. tostring(sessionRows) .. " all=" .. tostring(sessionAll)
            .. " hist=" .. tostring(historyGroups),
        "DYNI1: cache=" .. tostring(cacheEntries) .. " pending=" .. tostring(pendingBuckets)
            .. " scanq=" .. tostring(scanQueue) .. " inspq=" .. tostring(inspectQueue)
            .. " autoq=" .. tostring(autoQueue) .. " dgn=" .. tostring(diagCount),
    }
    local stageTokens = {}
    if type(report.stages) == "table" then
        for stageName, stageCount in pairs(report.stages) do
            local cleanStage = CleanString(stageName)
            local cleanCount = CleanNumber(stageCount)
            if cleanStage and cleanCount then
                cleanStage = string.sub(cleanStage, 1, 40):gsub("%s", "_")
                stageTokens[#stageTokens + 1] = cleanStage .. "=" .. tostring(cleanCount)
            end
        end
    end
    table.sort(stageTokens)
    local stageLine = "DYNI1: stages"
    if #stageTokens == 0 then
        copyLines[#copyLines + 1] = stageLine .. "=none"
    else
        for tokenIndex = 1, #stageTokens do
            local piece = ((tokenIndex == 1) and " " or ",") .. stageTokens[tokenIndex]
            if string.len(stageLine) + string.len(piece) > 170 then
                copyLines[#copyLines + 1] = stageLine
                stageLine = "DYNI1: stages+" .. stageTokens[tokenIndex]
            else
                stageLine = stageLine .. piece
            end
        end
        copyLines[#copyLines + 1] = stageLine
    end
    copyLines[#copyLines + 1] = "DYNI1: nocheck=loot,whisper,tradeTimer"
    return copyLines
end

-- Shows the stored selftest report in a copy-friendly dialog. Combat defers
-- through the existing PLAYER_REGEN_ENABLED resume path (no new ticker);
-- when the popup API is unavailable the full block falls back to chat.
function Addon.ShowSelfTestCopy()
    local saved = _G.DoYouNeedItSelfTest
    if type(saved) ~= "table" or type(saved.report) ~= "table" then
        Print("selftest: no stored report; run /dyni selftest")
        return
    end
    if CleanBoolean(SafeCall(InCombatLockdown)) == true then
        Addon.selfTestCopyPendingAfterCombat = true
        Print("selftest: copy window deferred until combat ends")
        return
    end
    Addon.selfTestCopyPendingAfterCombat = false
    local copyLines = Addon.BuildSelfTestCopyLines(saved)
    if type(copyLines) ~= "table" or #copyLines == 0 then
        Print("selftest: stored report is unreadable; run /dyni selftest")
        return
    end
    Addon.selfTestCopyText = table.concat(copyLines, "\n")
    if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
        if StaticPopupDialogs["DOYOUNEED_SELFTEST_COPY"] == nil then
            StaticPopupDialogs["DOYOUNEED_SELFTEST_COPY"] = {
                text = "Do You Need It? self-check report (select all, Ctrl+C):",
                button1 = (type(CLOSE) == "string" and CLOSE) or "Close",
                hasEditBox = true,
                editBoxWidth = 320,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                OnShow = function(self)
                    local box = self.editBox
                    if box then
                        box:SetText(Addon.selfTestCopyText or "")
                        SafeCall(box.SetFocus, box)
                        SafeCall(box.HighlightText, box)
                    end
                end,
            }
        end
        if SafeCall(StaticPopup_Show, "DOYOUNEED_SELFTEST_COPY") ~= nil then
            Print("selftest: copy window opened; select all and press Ctrl+C to copy")
            return
        end
    end
    for lineIndex = 1, #copyLines do
        Print(copyLines[lineIndex])
    end
    Print("selftest: copy window unavailable; full report above")
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
    elseif command == "resetpos" then
        Addon.ResetWindowPosition()
    elseif command == "clear" then
        Addon.demoRows = nil
        CancelAllPendingAuto(true)
        InvalidatePendingLoot()
        CancelAllInspectWork()
        Addon.equipmentCache = {}
        Addon.state.currentRows = {}
        Addon.state.allRows = {}
        Addon.state.sessionRows = {}
        Addon.state.sessionAllRows = {}
        Addon.selectedView = "current"
        Addon.newLootPending = false
        Addon.selectedHistoryIndex = nil
        Addon.currentHistoryFallbackGroup = nil
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
        local layoutWidth, layoutHeight = WINDOW_WIDTH, WINDOW_HEIGHT
        if Addon.frame then
            layoutWidth = SafeCall(Addon.frame.GetWidth, Addon.frame) or layoutWidth
            layoutHeight = SafeCall(Addon.frame.GetHeight, Addon.frame) or layoutHeight
        end
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
            .. ", font=" .. tostring(FindFontName(Addon.ValidatedDisplayFont()))
            .. ", fontSize=" .. tostring(Addon.state.settings.fontSize)
            .. ", layout=" .. tostring(layoutWidth) .. "x" .. tostring(layoutHeight))
    elseif command == "selftest" then
        local sub = string.lower(CleanString(rest) or "")
        if sub == "show" then
            Addon.ShowSelfTestCopy()
        else
            Addon.RunSelfTest(sub)
        end
    else
        Print("commands: /dyni, /dyni settings, /dyni resetpos, /dyni test, /dyni scan, /dyni auto on|off, /dyni delay <seconds>, /dyni clear, /dyni history, /dyni debug on|off, /dyni diag, /dyni status, /dyni selftest [show|stop]")
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
    Addon.state.history = Core.SnapshotHistoryForSave(
        characterDB.history,
        Addon.state.settings.maxHistoryGroups,
        Addon.state.settings.maxSessionRows,
        ENCOUNTER_LOOT_GRACE,
        ActiveLocale()
    )
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
    Addon.combatInspectRows = {}
    Addon.combatInspectResumeToken = nil
    Addon.pendingItems = {}
    Addon.lootGeneration = 0
    Addon.recentLootKeys = {}
    Addon.lastWhisperSentAt = nil
    Addon.fastWhisperStreak = 0
    Addon.autoWhisperQueue = {}
    Addon.autoWhisperPumpScheduled = false
    Addon.autoWhisperLastDispatchAt = nil
    Addon.currentHistoryFallbackGroup = nil
    Addon.challengeCompletedAt = nil
    Addon.challengeFinalizeToken = nil
    Addon.recentEncounterFinalizeToken = nil
    Addon.equipmentScanQueue = {}
    Addon.equipmentScanScheduled = false
    Addon.rosterScanPendingAfterCombat = nil
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
        Addon.SaveWindowPosition()
        if Addon.state and (#Addon.state.currentRows > 0 or #(Addon.state.allRows or {}) > 0) then
            Addon.CompleteCurrentGroup(Addon.currentEncounterName)
        end
        SaveDB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Addon.demoRows = nil
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
            Addon.challengeFinalizeRearms = nil
            Addon.recentEncounterFinalizeToken = nil
            InvalidatePendingLoot()
        end
        Addon.currentInstanceName = instanceName
        BuildRoster()
        QueueEquipmentScan("entering_world", true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Addon.ResumeInspectWorkAfterCombat(3)
        if Addon.selfTestCopyPendingAfterCombat then
            Addon.selfTestCopyPendingAfterCombat = nil
            Addon.ShowSelfTestCopy()
        end
        if Addon.rosterScanPendingAfterCombat then
            Addon.rosterScanPendingAfterCombat = nil
            QueueEquipmentScan("group_roster_update", true)
        end
    elseif event == "CHALLENGE_MODE_START" then
        Addon.challengeCompletedAt = nil
        Addon.challengeFinalizeToken = nil
        Addon.challengeFinalizeRearms = nil
        Addon.recentEncounterFinalizeToken = nil
        QueueEquipmentScan("challenge_start", true)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        Addon.challengeCompletedAt = Now()
        Addon.ScheduleChallengeHistoryFinalize("challenge_completed")
    elseif event == "CHALLENGE_MODE_RESET" then
        Addon.challengeCompletedAt = nil
        Addon.challengeFinalizeToken = nil
        Addon.challengeFinalizeRearms = nil
        Addon.recentEncounterFinalizeToken = nil
    elseif event == "GROUP_ROSTER_UPDATE" then
        local previousCount = #(Addon.rosterEntries or {})
        local departed = BuildRoster()
        local currentEntries = Addon.rosterEntries or {}
        local currentSolo = #currentEntries == 1 and type(currentEntries[1]) == "table" and currentEntries[1].unit == "player"
        local stillGrouped = CleanBoolean(SafeCall(IsInGroup)) == true or CleanBoolean(SafeCall(IsInRaid)) == true
        if previousCount > 1 and currentSolo and stillGrouped then
            return
        end
        Addon.CancelPendingAutoForDeparted(departed)
        Addon.InvalidateEquipmentCacheForNames(departed)
        if type(Addon.state) == "table" then
            local parked = {}
            local function collectParked(list)
                if type(list) ~= "table" then
                    return
                end
                for index = 1, #list do
                    local parkedRow = list[index]
                    if type(parkedRow) == "table" and parkedRow.rangeParked == true then
                        parked[#parked + 1] = parkedRow
                    end
                end
            end
            collectParked(Addon.state.currentRows)
            collectParked(Addon.state.allRows)
            collectParked(Addon.state.sessionRows)
            collectParked(Addon.state.sessionAllRows)
            for index = 1, #parked do
                RequestInspectForRow(parked[index])
            end
        end
        if InCombatLockdown and InCombatLockdown() then
            -- Pause in combat: cache is already trimmed, the shared combat-end
            -- wakeup requeues the scan.
            Addon.rosterScanPendingAfterCombat = true
        elseif Addon.equipmentScanScheduled then
            -- Coalesce roster storms into the already armed scan: refresh
            -- membership without arming another timer.
            Addon.RebuildEquipmentScanQueue("group_roster_update")
        else
            QueueEquipmentScan("group_roster_update", true)
        end
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
        Addon.recentEncounterName = Addon.currentEncounterName
        Addon.recentEncounterEndedAt = Now()
        Addon.currentEncounterID = nil
        Addon.currentEncounterName = nil
        Addon.currentEncounterStartedAt = nil
        if Addon.HasCurrentLootRows() then
            Addon.ScheduleRecentEncounterHistoryFinalize("encounter_end")
        end
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
