local root = assert(loadfile("DoYouNeedIt_Core.lua"))()
local Core = _G.DoYouNeedItCore or root

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, label)
    if not value then
        error(label .. ": expected truthy value", 2)
    end
end

local settings = Core.NormalizeSettings({})
assertEqual(settings.autoWhisper, false, "auto whisper defaults off")
assertEqual(settings.autoDelay, 10, "auto delay defaults to 10")
assertEqual(settings.debug, false, "debug defaults off")
assertEqual(settings.maxSessionRows, 50, "session rows default to last 50")
assertEqual(settings.forceLocale, "auto", "language defaults to auto")
assertTruthy(settings.font ~= nil and settings.font ~= "", "font defaults to a usable path")
assertEqual(settings.fontSize, 12, "font size defaults to 12")
assertEqual(settings.fontBeforeAutoSwitch, nil, "auto-switch font memory defaults empty")
assertEqual(settings.whisperTemplate, "Hey, do you need {item}?", "whisper template defaults to item placeholder text")
assertEqual(Core.NormalizeSettings({ autoDelay = 1 }).autoDelay, 3, "delay clamps low")
assertEqual(Core.NormalizeSettings({ autoDelay = 45 }).autoDelay, 30, "delay clamps high")
assertEqual(Core.NormalizeSettings({ debug = true }).debug, true, "debug can be enabled")
assertEqual(Core.NormalizeSettings({ forceLocale = "ruRU" }).forceLocale, "ruRU", "explicit locale can be saved")
assertEqual(Core.NormalizeSettings({ forceLocale = "badLocale" }).forceLocale, "auto", "invalid locale resets to auto")
assertEqual(Core.NormalizeSettings({ font = "Fonts\\ARIALN.TTF" }).font, "Fonts\\ARIALN.TTF", "font path can be saved")
assertEqual(Core.NormalizeSettings({ font = "" }).font, settings.font, "empty font resets to default")
assertEqual(Core.NormalizeSettings({ fontSize = 4 }).fontSize, 8, "font size clamps low")
assertEqual(Core.NormalizeSettings({ fontSize = 50 }).fontSize, 24, "font size clamps high")
assertEqual(Core.NormalizeSettings({ fontBeforeAutoSwitch = "Fonts\\FRIZQT__.TTF" }).fontBeforeAutoSwitch, "Fonts\\FRIZQT__.TTF", "auto-switch font memory can be saved")
assertEqual(Core.NormalizeSettings({ whisperTemplate = "" }).whisperTemplate, settings.whisperTemplate, "empty whisper template resets to default")
assertEqual(Core.NormalizeSettings({ whisperTemplate = string.rep("x", 200) }).whisperTemplate, string.rep("x", 160), "whisper template clamps to chat-safe length")
assertEqual(Core.NormalizeSettings({ whisperTemplate = string.rep("€", 54) }).whisperTemplate, string.rep("€", 53), "whisper template clamp preserves UTF-8 characters")
assertEqual(Core.NormalizeSettings({ whisperTemplate = string.rep("x", 157) .. "{item}" }).whisperTemplate, string.rep("x", 157), "whisper template clamp drops a partial item placeholder")
local badNumericSettings = Core.NormalizeSettings({
    autoDelay = 0 / 0,
    minDelay = 0 / 0,
    maxDelay = 1 / 0,
    maxHistoryGroups = 1 / 0,
    maxSessionRows = 0 / 0,
    minQuality = 1 / 0,
    fontSize = 0 / 0,
})
assertEqual(badNumericSettings.minDelay, 3, "NaN min delay resets to default")
assertEqual(badNumericSettings.maxDelay, 30, "infinite max delay resets to default")
assertEqual(badNumericSettings.autoDelay, 10, "NaN auto delay resets to default")
assertEqual(badNumericSettings.maxHistoryGroups, 10, "infinite history limit resets to default")
assertEqual(badNumericSettings.maxSessionRows, 50, "NaN session row limit resets to default")
assertEqual(badNumericSettings.minQuality, 2, "infinite minimum quality resets to default")
assertEqual(badNumericSettings.fontSize, 12, "NaN font size resets to default")
assertEqual(Core.FormatWhisperMessage("Need {item}?", "|cffa335ee|Hitem:123::::::::|h[Test Item]|h|r"), "Need |cffa335ee|Hitem:123::::::::|h[Test Item]|h|r?", "whisper formatter replaces item placeholder")
assertEqual(Core.FormatWhisperMessage("Need?", "|cffa335ee|Hitem:123::::::::|h[Test Item]|h|r"), "Need? |cffa335ee|Hitem:123::::::::|h[Test Item]|h|r", "whisper formatter appends item link when placeholder is missing")
assertEqual(Core.FormatWhisperMessage(string.rep("x", 157) .. "{item}", "|cffa335ee|Hitem:123::::::::|h[Test Item]|h|r"), string.rep("x", 157) .. " |cffa335ee|Hitem:123::::::::|h[Test Item]|h|r", "whisper formatter avoids sending a partial item placeholder")
local repairedDelay = Core.NormalizeSettings({ minDelay = 50, maxDelay = 3, autoDelay = 10 })
assertEqual(repairedDelay.minDelay, 3, "invalid min delay resets to default")
assertEqual(repairedDelay.maxDelay, 30, "invalid max delay resets to default")
assertEqual(repairedDelay.autoDelay, 10, "auto delay survives repaired bounds")
local clampedMaxDelay = Core.NormalizeSettings({ minDelay = 3, maxDelay = 90, autoDelay = 80 })
assertEqual(clampedMaxDelay.maxDelay, 30, "oversized max delay resets to default")
assertEqual(clampedMaxDelay.autoDelay, 30, "auto delay clamps to repaired max delay")
assertEqual(Core.NormalizeSettings({ maxSessionRows = 2 }).maxSessionRows, 2, "session row limit can be lowered")

assertEqual(Core.ResolveActiveLocale("auto", "ruRU"), "ruRU", "auto locale follows client locale")
assertEqual(Core.ResolveActiveLocale("badLocale", "ruRU"), "ruRU", "invalid force locale falls back to client locale")
assertEqual(Core.ResolveActiveLocale("frFR", "ruRU"), "frFR", "explicit locale overrides client locale")
assertEqual(Core.GetLocaleLabel("Settings", "ruRU"), "Настройки", "localized labels resolve by active locale")
assertEqual(Core.GetLocaleLabel("Low", "ruRU"), "Мин.", "slider low label is localized")
assertEqual(Core.GetLocaleLabel("High", "ruRU"), "Макс.", "slider high label is localized")
assertEqual(Core.GetLocaleLabel("Missing Label", "ruRU"), "Missing Label", "missing localized labels fall back to English key")
assertEqual(Core.GetLanguageOption("ruRU").label, "Русский (Russian)", "language option lookup returns bilingual label")
assertEqual(Core.GetLanguageOption("badLocale"), nil, "language option lookup returns nil for unknown locale")
assertEqual(Core.FontPathKey("Fonts/ARIALN.TTF"), "fonts\\arialn.ttf", "font path keys normalize slash and case")
assertEqual(Core.SameFontPath("Fonts/ARIALN.TTF", "fonts\\arialn.ttf"), true, "font path comparison is normalized")
assertEqual(Core.FontSupports("Fonts\\ARIALN.TTF", "CYR", "enUS"), true, "Arial Narrow supports Cyrillic on western clients")
assertEqual(Core.FontSupports("Fonts\\FRIZQT__.TTF", "CYR", "enUS"), false, "Friz does not guarantee Cyrillic on western clients")
assertEqual(Core.FontSupports("Fonts\\FRIZQT__.TTF", "CYR", "ruRU"), true, "Friz supports Cyrillic on ruRU clients")
assertEqual(Core.GetTextGlyphRequirement("Otherplayer"), nil, "latin-only text does not request a dynamic glyph fallback")
assertEqual(Core.GetTextGlyphRequirement("Игрок"), "CYR", "cyrillic text requests a dynamic glyph fallback")
assertEqual(Core.ResolveFontSize(11, 14), 13, "font size slider scales body text relative to default")
assertEqual(Core.ResolveFontSize(16, 14), 18, "font size slider scales title text relative to default")
assertEqual(Core.ResolveFontSize(10, 8), 8, "font size slider clamps tiny derived text")
assertEqual(Core.ResolveFontSize(nil, 15), 15, "font size slider uses selected size when no base size exists")
assertEqual(
    Core.FindCompatibleFont("Fonts\\FRIZQT__.TTF", "CYR", {
        { name = "Friz", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    }, "enUS"),
    "Fonts\\ARIALN.TTF",
    "compatible font lookup falls back to a glyph-capable font"
)
assertEqual(
    Core.FindCompatibleFont("Fonts\\FRIZQT__.TTF", Core.GetLocaleGlyphRequirement("koKR"), Core.GetBlizzardFonts("koKR"), "koKR"),
    "Fonts\\2002.ttf",
    "Korean font fallback chooses a Hangul-capable Blizzard font"
)
assertEqual(
    Core.FindCompatibleFont("Fonts\\FRIZQT__.TTF", Core.GetLocaleGlyphRequirement("zhCN"), Core.GetBlizzardFonts("zhCN"), "zhCN"),
    "Fonts\\ARKai_T.ttf",
    "Simplified Chinese font fallback chooses a Han-capable Blizzard font"
)
assertEqual(
    Core.FindCompatibleFont("Fonts\\FRIZQT__.TTF", Core.GetLocaleGlyphRequirement("zhTW"), Core.GetBlizzardFonts("zhTW"), "zhTW"),
    "Fonts\\bHEI00M.ttf",
    "Traditional Chinese font fallback chooses a Han-capable Blizzard font"
)

assertEqual(type(Core.ResolvePlayerCanEquip), "function", "core exposes player equip eligibility")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 4,
    equipLoc = "INVTYPE_CHEST",
}, "PALADIN", true), true, "plate armor slot is askable for plate classes")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 2,
    equipLoc = "INVTYPE_CHEST",
}, "PALADIN", true), false, "leather armor slot is not askable for plate classes")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 2,
    equipLoc = "INVTYPE_HAND",
}, "ROGUE", true), true, "leather armor slot is askable for leather classes")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 3,
    equipLoc = "INVTYPE_HEAD",
}, "HUNTER", true), true, "mail armor slot is askable for mail classes")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 1,
    equipLoc = "INVTYPE_ROBE",
}, "MAGE", true), true, "cloth armor slot is askable for cloth classes")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    equipLoc = "INVTYPE_SHOULDER",
}, "WARRIOR", true), nil, "armor slot with missing subclass is not blindly askable")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 1,
    equipLoc = "INVTYPE_CLOAK",
}, "DEATHKNIGHT", nil), true, "cloak is universally askable")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 1,
    equipLoc = "INVTYPE_CLOAK",
}, "DEATHKNIGHT", false), true, "cloak remains askable even when usability API is conservative")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 0,
    equipLoc = "INVTYPE_FINGER",
}, "PRIEST", nil), true, "ring is universally askable")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 0,
    equipLoc = "INVTYPE_TRINKET",
}, "DRUID", nil), true, "trinket is universally askable")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 4,
    subclassID = 0,
    equipLoc = "INVTYPE_NECK",
}, "SHAMAN", nil), true, "neck is universally askable")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 2,
    subclassID = 7,
    equipLoc = "INVTYPE_WEAPON",
}, "WARRIOR", true), true, "weapon eligibility follows WoW equip usability")
assertEqual(Core.ResolvePlayerCanEquip({
    classID = 2,
    subclassID = 7,
    equipLoc = "INVTYPE_WEAPON",
}, "MAGE", false), false, "unusable weapon is not askable")

local accepted = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
    canTrade = nil,
    bindType = 2,
    playerCanEquip = true,
}, "Otherplayer", "Player")
assertEqual(accepted.visible, true, "weapon from another player is visible")

local bindOnPickupGear = {
    link = "|cffa335ee|Hitem:19020:::::::::::::|h[Bound Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    bindType = 1,
}
local allGear = Core.ClassifyGearLoot(bindOnPickupGear, "Otherplayer", Core.NormalizeSettings({}))
assertEqual(allGear.visible, true, "bind-on-pickup gear is visible in all gear")
local bindOnPickupNotAskable = Core.ClassifyTradeCandidate(bindOnPickupGear, "Otherplayer", "Player")
assertEqual(bindOnPickupNotAskable.visible, false, "bind-on-pickup gear without trade warning is not askable")
assertEqual(bindOnPickupNotAskable.reason, "bind_on_pickup", "bind-on-pickup rejection is explicit")
local tradeWarningGear = {
    link = "|cffa335ee|Hitem:19021:::::::::::::|h[Tradeable Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    bindType = 1,
    tradeTimeRemaining = true,
    playerCanEquip = true,
}
local tradeWarningAskable = Core.ClassifyTradeCandidate(tradeWarningGear, "Otherplayer", "Player")
assertEqual(tradeWarningAskable.visible, true, "bind-on-pickup gear with trade warning is askable")

local unknownEquipGear = {
    link = "|cffa335ee|Hitem:19024:::::::::::::|h[Unknown Equip Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    bindType = 2,
}
local unknownEquipAllGear = Core.ClassifyGearLoot(unknownEquipGear, "Otherplayer", Core.NormalizeSettings({}))
assertEqual(unknownEquipAllGear.visible, true, "gear with unknown player usability stays visible in all gear")
local unknownEquipAskable = Core.ClassifyTradeCandidate(unknownEquipGear, "Otherplayer", "Player")
assertEqual(unknownEquipAskable.visible, false, "gear with unknown player usability is not askable")
assertEqual(unknownEquipAskable.reason, "player_equip_unknown", "unknown player usability rejection is explicit")

local unknownBindGear = {
    link = "|cffa335ee|Hitem:19023:::::::::::::|h[Unknown Bind Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    playerCanEquip = true,
}
local unknownBindAskable = Core.ClassifyTradeCandidate(unknownBindGear, "Otherplayer", "Player")
assertEqual(unknownBindAskable.visible, false, "gear without bind/trade evidence is not askable")
assertEqual(unknownBindAskable.reason, "bind_unknown", "unknown bind rejection is explicit")

local unusableForPlayer = {
    link = "|cffa335ee|Hitem:19022:::::::::::::|h[Other Class Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    bindType = 2,
    playerCanEquip = false,
}
local unusableAllGear = Core.ClassifyGearLoot(unusableForPlayer, "Otherplayer", Core.NormalizeSettings({}))
assertEqual(unusableAllGear.visible, true, "gear the player cannot equip stays visible in all gear")
local unusableAskable = Core.ClassifyTradeCandidate(unusableForPlayer, "Otherplayer", "Player")
assertEqual(unusableAskable.visible, false, "gear the player cannot equip is not askable")
assertEqual(unusableAskable.reason, "player_cannot_equip", "player equip rejection is explicit")

local currency = Core.ClassifyTradeCandidate({
    link = "|Hcurrency:3008:1|h[Currency]|h",
    quality = 4,
    classID = 10,
    equipLoc = "",
}, "Otherplayer", "Player")
assertEqual(currency.visible, false, "currency hidden")

local selfLoot = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
}, "Player", "Player")
assertEqual(selfLoot.visible, false, "player's own loot hidden")

local sameBaseDifferentRealm = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
    bindType = 2,
    playerCanEquip = true,
}, "Player-OtherRealm", "Player-Ravencrest")
assertEqual(sameBaseDifferentRealm.visible, true, "same short name on a different realm is not self loot")
local sameBaseDifferentRealmWithShortPlayerName = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
    bindType = 2,
    playerCanEquip = true,
}, "Player-OtherRealm", "Player")
assertEqual(sameBaseDifferentRealmWithShortPlayerName.visible, true, "same short name on another realm is not self loot when player realm is unavailable")

local reagent = Core.ClassifyTradeCandidate({
    link = "|cff1eff00|Hitem:190456:::::::::::::|h[Test Reagent]|h|r",
    quality = 2,
    classID = 7,
    equipLoc = "",
    isCraftingReagent = true,
}, "Otherplayer", "Player")
assertEqual(reagent.visible, false, "reagent hidden")

local notTradeable = Core.ClassifyTradeCandidate({
    link = "|cffa335ee|Hitem:19020:::::::::::::|h[Bound Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    canTrade = false,
}, "Otherplayer", "Player")
assertEqual(notTradeable.visible, false, "explicit non-tradeable item hidden")

local state = Core.CreateState({ maxHistoryGroups = 10 })
for index = 1, 12 do
    Core.AddVisibleRow(state, {
        id = "row" .. index,
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:" .. index .. ":::::::::::::|h[Test]|h|r",
        timestamp = index,
    })
    Core.CompleteCurrentGroup(state, {
        title = "Boss " .. index,
        instanceName = "Dungeon",
        encounterName = "Boss " .. index,
        endedAt = index,
    })
end
assertEqual(#state.history, 10, "history prunes to 10")
assertEqual(state.history[1].title, "Dungeon - Boss 12 (1 drop)", "newest group first")
assertEqual(state.history[10].title, "Dungeon - Boss 3 (1 drop)", "oldest retained group")
local oversizedSavedHistory = {}
for index = 12, 1, -1 do
    oversizedSavedHistory[#oversizedSavedHistory + 1] = {
        title = "Saved Boss " .. index,
        rows = {
            { id = "saved-row-" .. index },
        },
    }
end
local prunedSavedHistory = Core.SnapshotHistoryForSave(oversizedSavedHistory, 10)
assertEqual(#prunedSavedHistory, 10, "history save snapshot prunes to limit")
assertEqual(prunedSavedHistory[1].title, "Saved Boss 12", "history save snapshot keeps newest group")
assertEqual(prunedSavedHistory[10].title, "Saved Boss 3", "history save snapshot drops oldest groups")
local oversizedHistoryGroup = {
    title = "Saved Oversized Boss",
    rows = {},
    allRows = {},
}
for index = 1, 6 do
    oversizedHistoryGroup.rows[#oversizedHistoryGroup.rows + 1] = { id = "askable-history-" .. index }
    oversizedHistoryGroup.allRows[#oversizedHistoryGroup.allRows + 1] = { id = "all-history-" .. index }
end
local cappedSavedHistory = Core.SnapshotHistoryForSave({ oversizedHistoryGroup }, 10, 3)
assertEqual(#cappedSavedHistory[1].rows, 3, "history save snapshot caps askable rows per group")
assertEqual(cappedSavedHistory[1].rows[1].id, "askable-history-4", "history askable row cap keeps newest retained row first")
assertEqual(#cappedSavedHistory[1].allRows, 3, "history save snapshot caps all-gear rows per group")
assertEqual(cappedSavedHistory[1].allRows[1].id, "all-history-4", "history all-gear row cap keeps newest retained row first")
local bonusSavedRows = Core.SnapshotRowsForSave({
    {
        id = "bonus-row",
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:303:::::::::::::|h[Bonus Drop]|h|r",
        lootSource = "bonus_roll",
        statusKey = "bonus_roll",
        askable = false,
    },
}, 10)
assertEqual(bonusSavedRows[1].lootSource, "bonus_roll", "saved rows keep the bonus-roll source marker")
assertEqual(bonusSavedRows[1].statusKey, "bonus_roll", "saved rows keep the bonus-roll display status")

local emptyState = Core.CreateState({ maxHistoryGroups = 10 })
Core.CompleteCurrentGroup(emptyState, { title = "No Drops", endedAt = 1 })
assertEqual(#emptyState.history, 0, "empty groups are not saved")

local oversizedCurrentState = Core.CreateState({ maxHistoryGroups = 10, maxSessionRows = 3 })
for index = 1, 6 do
    Core.AddVisibleRow(oversizedCurrentState, {
        id = "current-row-" .. index,
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:" .. (200 + index) .. ":::::::::::::|h[Test]|h|r",
        timestamp = index,
    }, true)
end
local cappedCurrentGroup = Core.CompleteCurrentGroup(oversizedCurrentState, { instanceName = "Dungeon", encounterName = "Boss", endedAt = 1 })
assertEqual(#cappedCurrentGroup.rows, 3, "completed history group caps askable rows")
assertEqual(cappedCurrentGroup.rows[1].id, "current-row-4", "completed askable row cap keeps newest retained row first")
assertEqual(#cappedCurrentGroup.allRows, 3, "completed history group caps all-gear rows")
assertEqual(cappedCurrentGroup.allRows[1].id, "current-row-4", "completed all-gear row cap keeps newest retained row first")

local mixedState = Core.CreateState({ maxHistoryGroups = 10, maxSessionRows = 10 })
Core.AddVisibleRow(mixedState, {
    id = "askable-row",
    looter = "Otherplayer",
    itemLink = "|cff0070dd|Hitem:100:::::::::::::|h[Askable]|h|r",
    askable = true,
}, true)
Core.AddVisibleRow(mixedState, {
    id = "all-only-row",
    looter = "Otherplayer",
    itemLink = "|cff0070dd|Hitem:101:::::::::::::|h[All Only]|h|r",
    askable = false,
}, false)
assertEqual(#mixedState.currentRows, 1, "askable rows stay in current askable list")
assertEqual(#mixedState.allRows, 2, "all gear keeps askable and non-askable rows")
assertEqual(#mixedState.sessionRows, 1, "askable session keeps only askable rows")
assertEqual(#mixedState.sessionAllRows, 2, "all gear session keeps every gear row")
local mixedGroup = Core.CompleteCurrentGroup(mixedState, { instanceName = "Dungeon", encounterName = "Boss", endedAt = 1 })
assertEqual(#mixedGroup.rows, 1, "history askable rows stay filtered")
assertEqual(#mixedGroup.allRows, 2, "history all gear keeps every gear row")
assertEqual(#mixedState.currentRows, 0, "completion clears current askable rows")
assertEqual(#mixedState.allRows, 0, "completion clears current all gear rows")

local mergeState = Core.CreateState({ maxHistoryGroups = 10, maxSessionRows = 10 })
Core.AddVisibleRow(mergeState, {
    id = "merge-askable-row",
    looter = "Otherplayer",
    itemLink = "|cff0070dd|Hitem:110:::::::::::::|h[Merge Askable]|h|r",
    askable = true,
}, true)
Core.CompleteCurrentGroup(mergeState, { instanceName = "Dungeon", encounterName = "Merge Boss", endedAt = 100, mergeWindow = 10 })
Core.AddVisibleRow(mergeState, {
    id = "merge-bonus-row",
    looter = "Secondplayer",
    itemLink = "|cff0070dd|Hitem:111:::::::::::::|h[Merge Bonus]|h|r",
    lootSource = "bonus_roll",
    statusKey = "bonus_roll",
    askable = false,
}, false)
local mergedGroup = Core.CompleteCurrentGroup(mergeState, { instanceName = "Dungeon", encounterName = "Merge Boss", endedAt = 105, mergeWindow = 10 })
assertEqual(#mergeState.history, 1, "matching recent history groups are merged")
assertEqual(#mergedGroup.rows, 1, "merged group keeps askable rows filtered")
assertEqual(#mergedGroup.allRows, 2, "merged group keeps late all-gear rows")
assertEqual(mergedGroup.title, "Dungeon - Merge Boss (2 drops)", "merged group title updates the drop count")

Core.AddVisibleRow(mergeState, {
    id = "merge-later-row",
    looter = "Thirdplayer",
    itemLink = "|cff0070dd|Hitem:112:::::::::::::|h[Merge Later]|h|r",
}, true)
Core.CompleteCurrentGroup(mergeState, { instanceName = "Dungeon", encounterName = "Merge Boss", endedAt = 130, mergeWindow = 10 })
assertEqual(#mergeState.history, 2, "same boss outside merge window creates a new history group")

local localizedHistoryState = Core.CreateState({ maxHistoryGroups = 10, maxSessionRows = 10 })
Core.AddVisibleRow(localizedHistoryState, {
    id = "localized-row-1",
    looter = "Otherplayer",
    itemLink = "|cff0070dd|Hitem:301:::::::::::::|h[Localized One]|h|r",
}, true)
Core.AddVisibleRow(localizedHistoryState, {
    id = "localized-row-2",
    looter = "Otherplayer",
    itemLink = "|cff0070dd|Hitem:302:::::::::::::|h[Localized Two]|h|r",
}, false)
local localizedGroup = Core.CompleteCurrentGroup(localizedHistoryState, {
    instanceName = "Dungeon",
    encounterName = "Boss",
    locale = "ruRU",
    endedAt = 1,
})
assertEqual(localizedGroup.title, "Dungeon - Boss (2 дропа)", "history title localizes drop-count wording")

local equipmentCache = {}
local cachedWeapon = "Cached: |cff1eff00|Hitem:25:::::::::::::|h[Worn Shortsword]|h|r"
assertEqual(
    Core.StoreEquipmentCache(equipmentCache, { "Otherplayer", "Otherplayer-Realm" }, { INVTYPE_WEAPON = cachedWeapon }, 1234),
    true,
    "equipment cache stores usable slot text"
)
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer", "INVTYPE_WEAPON"),
    cachedWeapon,
    "equipment cache returns cached text by short name"
)
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer-Realm", "INVTYPE_WEAPON"),
    cachedWeapon,
    "equipment cache returns cached text by full name"
)
assertEqual(equipmentCache.Otherplayer.timestamp, 1234, "equipment cache keeps scan timestamp")
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer", "INVTYPE_WEAPON", 1240, 10),
    cachedWeapon,
    "equipment cache returns fresh cached text when age is within the freshness limit"
)
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer", "INVTYPE_WEAPON", 1300, 10),
    nil,
    "equipment cache returns nil when the cache entry is older than the freshness limit"
)
assertEqual(
    Core.GetCachedEquippedText({ MissingTimestamp = { slots = { INVTYPE_WEAPON = cachedWeapon } } }, "MissingTimestamp", "INVTYPE_WEAPON", 1300, 10),
    nil,
    "equipment cache returns nil for untimestamped entries when freshness is required"
)
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer", "INVTYPE_CHEST"),
    nil,
    "equipment cache returns nil for missing slots"
)
assertEqual(
    Core.StoreEquipmentCache(equipmentCache, "Emptyplayer", {}, 1235),
    false,
    "equipment cache rejects empty captures"
)
assertEqual(
    Core.StoreEquipmentCache(equipmentCache, { "Otherplayer", "Otherplayer-Realm" }, {}, 1236),
    false,
    "equipment cache empty capture reports no usable slots for existing aliases"
)
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer", "INVTYPE_WEAPON"),
    nil,
    "equipment cache empty capture clears stale short-name alias"
)
assertEqual(
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer-Realm", "INVTYPE_WEAPON"),
    nil,
    "equipment cache empty capture clears stale full-name alias"
)

local rosterIndex = Core.CreateRosterIndex({
    { unit = "player", fullName = "Player-Ravencrest", shortName = "Player" },
    { unit = "party1", fullName = "Otherplayer-Ravencrest", shortName = "Otherplayer" },
    { unit = "party2", fullName = "Alex-RealmA", shortName = "Alex" },
    { unit = "party3", fullName = "Alex-RealmB", shortName = "Alex" },
    { unit = "party4", fullName = "UNKNOWNOBJECT", shortName = "UNKNOWNOBJECT" },
})
assertEqual(Core.IsPlaceholderName("UNKNOWNOBJECT"), true, "placeholder identity is recognized")
assertEqual(Core.ResolveRosterName("Otherplayer", rosterIndex, "Player-Ravencrest"), "Otherplayer-Ravencrest", "unambiguous short roster alias resolves")
assertEqual(Core.GetRosterUnit(rosterIndex, "Otherplayer"), "party1", "roster unit lookup resolves through unambiguous short alias")
assertEqual(Core.ResolveRosterName("Alex", rosterIndex, "Player-Ravencrest"), nil, "ambiguous short roster alias is rejected")
assertEqual(Core.ResolveRosterName("Alex-RealmA", rosterIndex, "Player-Ravencrest"), "Alex-RealmA", "full cross-realm roster name resolves")
assertEqual(Core.ResolveRosterName("UNKNOWNOBJECT", rosterIndex, "Player-Ravencrest"), nil, "placeholder roster name is rejected")

local pendingItems = {}
local pendingItemLink = "|cff0070dd|Hitem:500:::::::::::::|h[Pending Sword]|h|r"
local bucket, created = Core.AddPendingItemWaiter(pendingItems, pendingItemLink, { looter = "One", generation = 1 })
assertEqual(created, true, "first pending item waiter creates bucket")
bucket.attempts = 2
bucket.loadRequested = true
local sameBucket, secondCreated = Core.AddPendingItemWaiter(pendingItems, pendingItemLink, { looter = "Two", generation = 1 })
assertEqual(secondCreated, false, "second pending item waiter reuses bucket")
assertEqual(sameBucket, bucket, "pending item waiters share one bucket per full item link")
assertEqual(sameBucket.attempts, 2, "adding a waiter does not consume a retry attempt")
assertEqual(#sameBucket.waiters, 2, "pending item bucket keeps every looter waiter")
local duplicateBucket, duplicateCreated = Core.AddPendingItemWaiter(pendingItems, pendingItemLink, { looter = "Two", generation = 1 })
assertEqual(duplicateCreated, false, "duplicate pending item waiter reuses bucket")
assertEqual(duplicateBucket, bucket, "duplicate pending item waiter keeps the same bucket")
assertEqual(#sameBucket.waiters, 2, "pending item bucket deduplicates the same looter and generation")
local staleDrain = Core.DrainPendingItemWaiters(pendingItems, pendingItemLink, 2)
assertEqual(#staleDrain, 0, "stale pending item generation drains no waiters")
assertEqual(pendingItems[pendingItemLink], bucket, "stale pending item generation preserves current bucket")
local drainedWaiters = Core.DrainPendingItemWaiters(pendingItems, pendingItemLink, 1)
assertEqual(#drainedWaiters, 2, "current pending item generation drains all waiters")
assertEqual(pendingItems[pendingItemLink], nil, "draining pending item waiters clears bucket")

local sessionState = Core.CreateState({ maxSessionRows = 3 })
for index = 1, 5 do
    Core.AddVisibleRow(sessionState, {
        id = "session" .. index,
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:" .. index .. ":::::::::::::|h[Test]|h|r",
        timestamp = index,
    })
end
assertEqual(#sessionState.sessionRows, 3, "session rows prune to configured limit")
assertEqual(sessionState.sessionRows[1].id, "session3", "session pruning keeps oldest retained row first")
assertEqual(sessionState.sessionRows[3].id, "session5", "session pruning keeps newest row")
local displayRows = Core.GetNewestRowsFirst(sessionState.sessionRows, 2)
assertEqual(#displayRows, 2, "display rows respect visible limit")
assertEqual(displayRows[1].id, "session5", "display rows show newest first")
assertEqual(displayRows[2].id, "session4", "display rows show next newest second")
local loadedSessionRows = Core.NormalizeSavedRows({
    { id = "old" },
    { id = "middle" },
    { id = "new" },
}, 2)
assertEqual(#loadedSessionRows, 2, "loaded session rows prune to limit")
assertEqual(loadedSessionRows[1].id, "middle", "loaded session rows keep retained order")
assertEqual(loadedSessionRows[2].id, "new", "loaded session rows keep newest retained row")
local loadedLegacyAllSessionRows = Core.NormalizeSavedAllRows(nil, {
    { id = "legacy-askable" },
    { id = "legacy-new" },
}, 10)
assertEqual(#loadedLegacyAllSessionRows, 2, "legacy session rows backfill missing all-gear session rows")
assertEqual(loadedLegacyAllSessionRows[1].id, "legacy-askable", "legacy all-gear session fallback keeps row order")
local loadedExplicitAllSessionRows = Core.NormalizeSavedAllRows({
    { id = "explicit-all" },
}, {
    { id = "legacy-askable" },
}, 10)
assertEqual(#loadedExplicitAllSessionRows, 1, "explicit all-gear session rows do not merge legacy askable rows")
assertEqual(loadedExplicitAllSessionRows[1].id, "explicit-all", "explicit all-gear session rows win over fallback")
local persistedRows = Core.SnapshotRowsForSave({
    {
        id = "pending",
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
        statusText = "auto in 10s",
        equippedText = "Equipped: checking...",
        pendingAutoWhisper = true,
        autoToken = {},
        runtimeOnly = {},
    },
    {
        id = "sent",
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:19020:::::::::::::|h[Test Chest]|h|r",
        statusText = "sent",
        manualWhispered = true,
    },
    {
        id = "sending",
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:19021:::::::::::::|h[Test Ring]|h|r",
        statusText = "sending",
        whisperInFlight = true,
    },
}, 10)
assertEqual(#persistedRows, 3, "save snapshot keeps persistable rows")
assertEqual(persistedRows[1].statusKey, "candidate", "save snapshot clears stale pending auto status key")
assertEqual(persistedRows[1].statusText, nil, "save snapshot drops migrated pending auto status text")
assertEqual(persistedRows[1].equippedText, "Equipped: unknown", "save snapshot clears stale pending inspect status")
assertEqual(persistedRows[1].pendingAutoWhisper, nil, "save snapshot drops pending auto flag")
assertEqual(persistedRows[1].autoToken, nil, "save snapshot drops runtime auto token")
assertEqual(persistedRows[1].runtimeOnly, nil, "save snapshot drops non-primitive runtime fields")
assertEqual(persistedRows[2].statusKey, "sent", "save snapshot migrates stable sent status key")
assertEqual(persistedRows[2].statusText, nil, "save snapshot drops migrated sent status text")
assertEqual(persistedRows[2].manualWhispered, true, "save snapshot keeps sent whisper state")
assertEqual(persistedRows[3].statusKey, "candidate", "save snapshot clears transient whisper sending status key")
assertEqual(persistedRows[3].statusText, nil, "save snapshot drops migrated transient whisper status text")
assertEqual(persistedRows[3].whisperInFlight, nil, "save snapshot drops transient whisper in-flight flag")
local malformedSavedRows = Core.NormalizeSavedRows({
    {
        id = 123,
        looter = true,
        itemLink = 42,
        itemID = "19019",
        timestamp = "bad",
        statusText = 99,
        equippedText = true,
        askable = "yes",
    },
    {
        id = "bad-numbers",
        itemID = 1 / 0,
        timestamp = 0 / 0,
    },
}, 10)
assertEqual(#malformedSavedRows, 2, "malformed saved rows do not abort normalization")
assertEqual(malformedSavedRows[1].statusText, nil, "malformed status text is dropped during row normalization")
assertEqual(malformedSavedRows[1].statusKey, nil, "malformed status key is dropped during row normalization")
assertEqual(malformedSavedRows[1].itemLink, nil, "malformed item link is dropped during row normalization")
assertEqual(malformedSavedRows[1].askable, nil, "malformed askable flag is dropped during row normalization")
assertEqual(malformedSavedRows[2].itemID, nil, "infinite saved row item id is dropped during row normalization")
assertEqual(malformedSavedRows[2].timestamp, nil, "NaN saved row timestamp is dropped during row normalization")
local persistedHistory = Core.SnapshotHistoryForSave({
    {
        title = "Dungeon - Boss (1 drop)",
        rows = {
            {
                id = "history-pending",
                looter = "Otherplayer",
                itemLink = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
                statusText = "auto in 10s",
                pendingAutoWhisper = true,
                autoToken = {},
            },
        },
        allRows = {
            {
                id = "history-all-only",
                looter = "Otherplayer",
                itemLink = "|cff0070dd|Hitem:19022:::::::::::::|h[Test Boots]|h|r",
                askable = false,
            },
        },
        transient = {},
    },
}, 10)
assertEqual(#persistedHistory, 1, "history save snapshot keeps group")
assertEqual(persistedHistory[1].rows[1].statusKey, "candidate", "history snapshot clears stale pending auto status key")
assertEqual(persistedHistory[1].rows[1].statusText, nil, "history snapshot drops migrated pending auto status text")
assertEqual(persistedHistory[1].rows[1].autoToken, nil, "history snapshot drops runtime auto token")
assertEqual(#persistedHistory[1].allRows, 1, "history snapshot keeps all gear rows")
assertEqual(persistedHistory[1].allRows[1].askable, false, "history snapshot keeps non-askable marker")
assertEqual(persistedHistory[1].transient, nil, "history snapshot drops runtime group fields")
local legacyPersistedHistory = Core.SnapshotHistoryForSave({
    {
        title = "Legacy Dungeon - Boss (1 drop)",
        rows = {
            {
                id = "legacy-history-row",
                looter = "Otherplayer",
                itemLink = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
            },
        },
    },
    {
        title = "Legacy Empty All Rows",
        rows = {
            {
                id = "legacy-empty-all-row",
                looter = "Otherplayer",
                itemLink = "|cff0070dd|Hitem:19020:::::::::::::|h[Test Chest]|h|r",
            },
        },
        allRows = {},
    },
}, 10)
assertEqual(#legacyPersistedHistory[1].allRows, 1, "legacy history without allRows backfills all-gear rows")
assertEqual(legacyPersistedHistory[1].allRows[1].id, "legacy-history-row", "legacy history fallback keeps row payload")
assertEqual(#legacyPersistedHistory[2].allRows, 1, "legacy history with empty allRows still backfills all-gear rows")
assertEqual(legacyPersistedHistory[2].allRows[1].id, "legacy-empty-all-row", "empty allRows fallback keeps row payload")

local auto = Core.GetAutoWhisperDecision(
    Core.NormalizeSettings({ autoWhisper = true, autoDelay = 12 }),
    { looter = "Otherplayer", itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r", unsafe = false }
)
assertEqual(auto.shouldSchedule, true, "auto whisper schedules for eligible row")
assertEqual(auto.delay, 12, "auto whisper uses configured delay")

local blocked = Core.GetAutoWhisperDecision(
    Core.NormalizeSettings({ autoWhisper = true, autoDelay = 12 }),
    { looter = "Otherplayer", itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r", unsafe = true }
)
assertEqual(blocked.shouldSchedule, false, "unsafe rows do not schedule auto whisper")
local inFlightAuto = Core.GetAutoWhisperDecision(
    Core.NormalizeSettings({ autoWhisper = true, autoDelay = 12 }),
    { looter = "Otherplayer", itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r", whisperInFlight = true }
)
assertEqual(inFlightAuto.shouldSchedule, false, "in-flight whispers do not schedule another auto whisper")
local askButton = Core.GetWhisperButtonState(nil, "current", { askable = true })
assertEqual(askButton.visible, true, "current askable row shows Ask button without a selected tab")
assertEqual(askButton.enabled, true, "current askable row enables Ask button")
assertEqual(askButton.text, "Ask", "current askable row uses Ask text")
local sentButton = Core.GetWhisperButtonState(nil, "current", { askable = true, manualWhispered = true })
assertEqual(sentButton.visible, true, "sent current row keeps visible status button")
assertEqual(sentButton.enabled, false, "sent current row disables whisper button")
assertEqual(sentButton.text, "Sent", "sent current row uses Sent text")
local sendingButton = Core.GetWhisperButtonState(nil, "current", { askable = true, whisperInFlight = true })
assertEqual(sendingButton.visible, true, "in-flight current row keeps visible status button")
assertEqual(sendingButton.enabled, false, "in-flight current row disables whisper button")
assertEqual(sendingButton.text, "Sending", "in-flight current row uses Sending text")
local allOnlyButton = Core.GetWhisperButtonState(nil, "current", { askable = false })
assertEqual(allOnlyButton.visible, false, "non-askable current rows do not show Ask button")
local sessionButton = Core.GetWhisperButtonState(nil, "session", { askable = true })
assertEqual(sessionButton.visible, false, "session rows do not show Ask button")
assertEqual(Core.GetLocaleLabel("sent", "ruRU"), "отправлено", "manual whisper success status is localized")
assertEqual(Core.GetLocaleLabel("auto sent", "ruRU"), "авто отправлено", "auto whisper success status is localized")
assertEqual(Core.GetRowStatusText({ statusKey = "auto_pending", statusSeconds = 12 }, "enUS"), "auto in 12s", "status key formats auto countdown in English")
assertEqual(Core.GetRowStatusText({ statusKey = "auto_pending", statusSeconds = 12 }, "ruRU"), "авто через 12с", "status key formats auto countdown in Russian")
assertEqual(Core.GetRowStatusText({ statusText = "auto in 7s" }, "enUS"), "auto in 7s", "legacy auto status text still renders")
assertEqual(Core.GetRowStatusText({ statusText = "auto sent" }, "ruRU"), "авто отправлено", "legacy auto sent status text migrates for display")
assertEqual(
    Core.ShouldAutoShowWindow({ itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r" }, { isGroupInstance = true }),
    true,
    "group dungeon or raid loot rows auto-show the window"
)
assertEqual(
    Core.ShouldAutoShowWindow({ itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r" }, { isGroupInstance = false }),
    false,
    "open-world loot rows do not auto-show the window"
)
assertEqual(
    Core.ShouldAutoShowWindow({ itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r" }, { forceAutoShow = true }),
    true,
    "manual test rows can force the window open"
)
assertEqual(Core.ShouldAutoShowWindow(nil, { isGroupInstance = true }), false, "missing rows do not auto-show the window")

local roster = {
    ["Player-Ravencrest"] = "player",
    Player = "player",
    ["Otherplayer-Ravencrest"] = "party1",
    Otherplayer = "party1",
}
local playerLinkedMessage = "|Hplayer:Otherplayer-Ravencrest:1|h[Otherplayer]|h receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(
    Core.FindRosterNameInMessage(playerLinkedMessage, roster, "Player-Ravencrest"),
    "Otherplayer-Ravencrest",
    "loot parser resolves full names from player links"
)
local coloredMessage = "|cffaad372Otherplayer|r receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(
    Core.FindRosterNameInMessage(coloredMessage, roster, "Player-Ravencrest"),
    "Otherplayer",
    "loot parser resolves names through color markup"
)
local ownMessage = "Player receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(Core.FindRosterNameInMessage(ownMessage, roster, "Player-Ravencrest"), nil, "loot parser ignores own drops")
local sameBaseRealmRoster = {
    Player = "player",
    ["Player-OtherRealm"] = "party1",
}
local sameBaseRealmMessage = "|Hplayer:Player-OtherRealm:1|h[Player]|h receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(
    Core.FindRosterNameInMessage(sameBaseRealmMessage, sameBaseRealmRoster, "Player"),
    "Player-OtherRealm",
    "loot parser keeps same-base cross-realm looters when player realm is unavailable"
)
local indexedPlayerLinkMessage = "|Hplayer:Otherplayer-Ravencrest:1|h[Otherplayer]|h receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(
    Core.FindRosterNameInMessage(indexedPlayerLinkMessage, rosterIndex, "Player-Ravencrest"),
    "Otherplayer-Ravencrest",
    "loot parser resolves full names through roster identity index"
)
local substringRoster = Core.CreateRosterIndex({
    { unit = "party1", fullName = "Ann-Realm", shortName = "Ann" },
})
assertEqual(
    Core.FindRosterNameInMessage("Annie receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.", substringRoster, "Player"),
    nil,
    "loot parser does not match roster names inside longer player names"
)
assertEqual(
    Core.FindRosterNameInMessage("Someone receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Anniversary Sword]|h|r.", substringRoster, "Player"),
    nil,
    "loot parser does not match roster names inside item names"
)

local lootPatterns = Core.CreateLootMessagePatterns({
    lootSelf = "You receive loot: %s.",
    lootSelfMultiple = "You receive loot: %sx%d.",
    lootOther = "%s receives loot: %s.",
    lootOtherMultiple = "%s receives loot: %sx%d.",
    bonusSelf = "You receive bonus loot: %s.",
    bonusOther = "%s receives bonus loot: %s.",
})
local resolvedOther = Core.ResolveLootMessageLooter(
    "Otherplayer receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    lootPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedOther.name, "Otherplayer", "localized loot patterns resolve other looter")
assertEqual(resolvedOther.isSelf, false, "localized other loot is not self loot")
local resolvedOtherMultiple = Core.ResolveLootMessageLooter(
    "Otherplayer receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|rx2.",
    lootPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedOtherMultiple.name, "Otherplayer", "localized multiple loot patterns resolve other looter")
local resolvedSelf = Core.ResolveLootMessageLooter(
    "You receive loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    lootPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedSelf.name, "Player-Ravencrest", "localized self loot returns player name")
assertEqual(resolvedSelf.isSelf, true, "localized self loot marks self")
local resolvedBonusOther = Core.ResolveLootMessageLooter(
    "Otherplayer receives bonus loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    lootPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedBonusOther.name, "Otherplayer", "localized bonus loot patterns resolve other looter")
assertEqual(resolvedBonusOther.isSelf, false, "localized other bonus loot is not self loot")
assertEqual(resolvedBonusOther.lootSource, "bonus_roll", "localized other bonus loot is source-tagged")
local resolvedBonusSelf = Core.ResolveLootMessageLooter(
    "You receive bonus loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    lootPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedBonusSelf.name, "Player-Ravencrest", "localized self bonus loot returns player name")
assertEqual(resolvedBonusSelf.isSelf, true, "localized self bonus loot marks self")
assertEqual(resolvedBonusSelf.lootSource, "bonus_roll", "localized self bonus loot is source-tagged")
local positionalPatterns = Core.CreateLootMessagePatterns({
    lootOther = "%1$s receives loot: %2$s.",
    bonusOther = "%1$s receives bonus loot: %2$s.",
})
local resolvedPositional = Core.ResolveLootMessageLooter(
    "Otherplayer receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    positionalPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedPositional.name, "Otherplayer", "positional localized loot pattern resolves looter")
local resolvedBonusPositional = Core.ResolveLootMessageLooter(
    "Otherplayer receives bonus loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    positionalPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedBonusPositional.name, "Otherplayer", "positional localized bonus loot pattern resolves looter")
assertEqual(resolvedBonusPositional.lootSource, "bonus_roll", "positional localized bonus loot pattern is source-tagged")
assertEqual(Core.ExtractItemID("|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r"), 19019, "item id extracted from item link")

local metadata = Core.BuildItemMetadata("|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r", {
    itemID = 19019,
    equipLoc = "INVTYPE_WEAPON",
    classID = 2,
    subclassID = 7,
}, {
    name = "Test Sword",
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    itemLevel = 42,
    equipLoc = "INVTYPE_WEAPON",
    classID = 2,
    subclassID = 7,
    bindType = 1,
    playerCanEquip = false,
    isCraftingReagent = false,
})
assertEqual(metadata.itemID, 19019, "metadata keeps item id from instant info")
assertEqual(metadata.quality, 3, "metadata maps quality from detailed info")
assertEqual(metadata.itemLevel, 42, "metadata maps item level from detailed info")
assertEqual(metadata.equipLoc, "INVTYPE_WEAPON", "metadata maps equip location")
assertEqual(metadata.classID, 2, "metadata maps class id")
assertEqual(metadata.playerCanEquip, false, "metadata maps player equip usability")

local missingMetadata = Core.BuildItemMetadata("|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r", {
    itemID = 19019,
    equipLoc = "INVTYPE_WEAPON",
    classID = 2,
}, {
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    equipLoc = "INVTYPE_WEAPON",
    classID = 2,
})
assertEqual(missingMetadata, nil, "metadata waits when detailed quality is missing")

assertEqual(
    Core.ResolveDropEncounterName("Current Boss", "Previous Boss", 100, 105, 120),
    "Current Boss",
    "current encounter wins for live boss drops"
)
assertEqual(
    Core.ResolveDropEncounterName(nil, "Previous Boss", 100, 105, 120),
    "Previous Boss",
    "recent encounter labels loot that arrives after encounter end"
)
assertEqual(
    Core.ResolveDropEncounterName(nil, "Previous Boss", 100, 300, 120),
    nil,
    "stale encounter is not reused for later trash drops"
)
assertEqual(
    Core.FirstRowEncounterName({
        { encounterName = "" },
        { encounterName = "Stored Boss" },
    }),
    "Stored Boss",
    "completed group can recover encounter from rows"
)

local diagnostics = {}
for index = 1, 12 do
    Core.RecordDiagnostic(diagnostics, { stage = "stage" .. index, itemLink = "item" .. index }, 10)
end
assertEqual(#diagnostics, 10, "diagnostics prune to limit")
assertEqual(diagnostics[1].stage, "stage12", "newest diagnostic first")
assertEqual(diagnostics[10].stage, "stage3", "oldest retained diagnostic kept at limit")
local badNumericDiagnostic = Core.RecordDiagnostic({}, {
    stage = "bad_numeric",
    at = 0 / 0,
    attempt = 1 / 0,
    itemLink = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
}, 10)
assertEqual(badNumericDiagnostic.stage, "bad_numeric", "diagnostics keep safe string fields")
assertEqual(badNumericDiagnostic.at, nil, "diagnostics drop NaN timestamps")
assertEqual(badNumericDiagnostic.attempt, nil, "diagnostics drop infinite counters")

assertEqual(Core.VERSION, "0.3.0", "core exposes current version")

local function readFile(path)
    local handle = assert(io.open(path, "rb"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local toc = readFile("DoYouNeedIt.toc")
assertTruthy(toc:find("## Title: Do You Need It?", 1, true), "toc title present")
assertTruthy(toc:find("## Interface: 120007, 120100", 1, true), "toc interface supports current Retail and Midnight 12.1.0")
assertTruthy(toc:find("## Version: 0.3.0", 1, true), "toc version present")
assertTruthy(toc:find("## IconTexture: Interface\\AddOns\\DoYouNeedIt\\media\\icon.png", 1, true), "toc addon list icon present")
assertTruthy(toc:find("## SavedVariables: DoYouNeedItDB", 1, true), "toc saved variables present")
assertTruthy(toc:find("DoYouNeedIt_Core.lua", 1, true), "toc loads core first")
assertTruthy(toc:find("DoYouNeedIt.lua", 1, true), "toc loads runtime")
local libStubPos = toc:find("libs\\LibStub\\LibStub.lua", 1, true)
local callbackPos = toc:find("libs\\CallbackHandler%-1.0\\CallbackHandler%-1.0.lua")
local sharedMediaPos = toc:find("libs\\LibSharedMedia%-3.0\\LibSharedMedia%-3.0.lua")
local corePos = toc:find("DoYouNeedIt_Core.lua", 1, true)
assertTruthy(libStubPos, "toc loads LibStub")
assertTruthy(callbackPos, "toc loads CallbackHandler")
assertTruthy(sharedMediaPos, "toc loads LibSharedMedia")
assertTruthy(libStubPos < callbackPos and callbackPos < sharedMediaPos and sharedMediaPos < corePos, "toc loads libraries before addon core")
assertTruthy(readFile("libs/LibStub/LibStub.lua"):find("LibStub", 1, true), "LibStub vendored")
assertTruthy(readFile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua"):find("CallbackHandler-1.0", 1, true), "CallbackHandler vendored")
assertTruthy(readFile("libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua"):find("LibSharedMedia-3.0", 1, true), "LibSharedMedia vendored")
assertTruthy(readFile("THIRD-PARTY-NOTICES.md"):find("LibSharedMedia-3.0", 1, true), "third-party notices include LibSharedMedia")

local runtime = readFile("DoYouNeedIt.lua")
assertTruthy(runtime:find("CHAT_MSG_LOOT", 1, true), "runtime listens to loot chat")
assertTruthy(runtime:find("ENCOUNTER_END", 1, true), "runtime tracks encounter completion")
assertTruthy(runtime:find("C_Timer.After", 1, true), "runtime defers whisper sends")
assertTruthy(runtime:find("DoYouNeedItCore.ClassifyTradeCandidate", 1, true), "runtime filters before display")
assertTruthy(runtime:find("OptionsSliderTemplate", 1, true), "runtime provides a delay slider")
assertTruthy(runtime:find("autoCheck", 1, true), "runtime provides an auto whisper checkbox")
assertTruthy(runtime:find("delaySlider", 1, true), "runtime wires the delay slider")
assertTruthy(runtime:find("settingsButton", 1, true), "runtime provides a settings gear button")
assertTruthy(runtime:find("CreateSettingsUI", 1, true), "runtime creates a settings panel")
assertTruthy(runtime:find("UIDropDownMenuTemplate", 1, true), "runtime uses Blizzard dropdowns for settings")
assertTruthy(runtime:find("PreviewLanguage", 1, true), "runtime previews language on hover")
assertTruthy(runtime:find("CancelLanguagePreview", 1, true), "runtime cancels language preview")
assertTruthy(runtime:find("PreviewFont", 1, true), "runtime previews font on hover")
assertTruthy(runtime:find("CancelFontPreview", 1, true), "runtime cancels font preview")
assertTruthy(runtime:find("CancelSettingsPreview", 1, true), "runtime force-clears settings hover previews")
assertTruthy(runtime:find("DoYouNeedItFontPicker", 1, true), "runtime uses a custom font picker instead of the shared dropdown list")
assertTruthy(runtime:find("UIPanelScrollFrameTemplate", 1, true), "runtime font picker is scrollable")
assertTruthy(runtime:find("ToggleFontPicker", 1, true), "runtime font dropdown button toggles the custom picker")
assertTruthy(runtime:find("SetDropdownTextSafe", 1, true), "runtime repairs dropdown captions after preview changes")
assertTruthy(runtime:find("HookScript(\"OnLeave\"", 1, true), "runtime restores font previews when leaving dropdown buttons")
assertTruthy(runtime:find("frame:SetScript(\"OnHide\", function()", 1, true), "settings panel uses a close handler")
assertTruthy(runtime:find("HideFontPicker()", 1, true), "settings panel closes the custom font picker")
assertTruthy(runtime:find("CancelSettingsPreview()", 1, true), "settings panel restores previews on close")
assertTruthy(runtime:find("LibSharedMedia%-3%.0", 1, false), "runtime reads LibSharedMedia fonts")
assertTruthy(runtime:find("DropDownList1:HookScript(\"OnHide\"", 1, true), "runtime rolls back dropdown hover previews on close")
assertTruthy(runtime:find("Core.GetLocaleLabel", 1, true), "runtime localizes visible UI strings")
assertTruthy(runtime:find("RegisterFontString", 1, true), "runtime tracks owned font strings")
assertTruthy(runtime:find("ApplyCurrentFont", 1, true), "runtime applies chosen or previewed font")
assertTruthy(runtime:find("Core.ResolveFontSize", 1, true), "runtime applies font-size slider to registered font strings")
assertTruthy(runtime:find("local WINDOW_WIDTH = 540", 1, true), "runtime uses compact non-overlapping window width")
assertTruthy(runtime:find("local WINDOW_HEIGHT = 300", 1, true), "runtime uses compact settings-enabled window height")
assertTruthy(runtime:find("local ROW_START_Y = -82", 1, true), "runtime leaves a compact header area above rows")
assertTruthy(runtime:find("local HEADER_HISTORY_WIDTH = 456", 1, true), "runtime uses freed tab space for the history selector")
assertTruthy(runtime:find("frame.historyButton:SetSize(HEADER_HISTORY_WIDTH, 22)", 1, true), "runtime uses the bounded history selector width")
assertTruthy(runtime:find("KeepOneLine", 1, true), "runtime caps long labels and loot rows to one line")
assertEqual(runtime:find("frame.tabAskable", 1, true), nil, "runtime no longer creates an askable tab")
assertEqual(runtime:find("frame.tabAllGear", 1, true), nil, "runtime no longer creates an all-gear tab")
assertTruthy(runtime:find("local MAX_VISIBLE_ROWS = 6", 1, true), "runtime uses freed settings space for another visible row")
assertTruthy(runtime:find("DoYouNeedItCore.ShouldAutoShowWindow", 1, true), "runtime auto-shows on new loot rows")
assertEqual(runtime:find("GetAutoShowTabForRow", 1, true), nil, "runtime no longer selects between loot tabs")
assertEqual(runtime:find("if askable and DoYouNeedItCore.ShouldAutoShowWindow", 1, true), nil, "runtime does not limit auto-show to askable rows")
assertTruthy(runtime:find("QueueEquipmentScan", 1, true), "runtime queues equipment pre-scans")
assertTruthy(runtime:find("StartEquipmentScan", 1, true), "runtime processes equipment scans one unit at a time")
assertEqual(runtime:find("RangedSlot", 1, true), nil, "runtime does not use removed ranged inventory slot")
assertTruthy(runtime:find("Core.GetCachedEquippedText", 1, true), "runtime applies cached equipped fallback to loot rows")
assertTruthy(runtime:find("command == \"scan\"", 1, true), "runtime wires /dyni scan")
assertTruthy(runtime:find("Cached:", 1, true), "runtime labels cached equipped data distinctly")
assertEqual(runtime:find("Print(\"debug:", 1, true), nil, "runtime does not print diagnostic spam to chat")
assertEqual(runtime:find("equipment scan queued", 1, true), nil, "runtime keeps scan queue quiet")
assertEqual(runtime:find("test rows added", 1, true), nil, "runtime keeps test command quiet")
assertEqual(runtime:find("Print(\"auto whisper ", 1, true), nil, "runtime keeps auto toggle quiet")
assertEqual(runtime:find("auto whisper delay set", 1, true), nil, "runtime keeps delay command quiet")
assertEqual(runtime:find("current session rows cleared", 1, true), nil, "runtime keeps clear command quiet")
assertEqual(runtime:find("debug enabled", 1, true), nil, "runtime keeps debug toggle quiet")
assertEqual(runtime:find("debug disabled", 1, true), nil, "runtime keeps debug toggle quiet")
assertTruthy(runtime:find("AddTestRow", 1, true), "runtime has a local test row command")
assertTruthy(runtime:find("command == \"test\"", 1, true), "runtime wires /dyni test")
assertTruthy(runtime:find("/dyni test", 1, true), "runtime documents /dyni test in command help")
assertEqual(runtime:find("/duni", 1, true), nil, "runtime does not register typo alias")
assertEqual(runtime:find("SLASH_DOYOUNEEDIT2", 1, true), nil, "runtime keeps only the canonical slash command")
assertTruthy(runtime:find("dropLink", 1, true), "runtime has a hover target for dropped item links")
assertTruthy(runtime:find("equippedLink", 1, true), "runtime has a hover target for equipped item links")
assertTruthy(runtime:find("GameTooltip.SetHyperlink", 1, true), "runtime shows real item tooltips from item links")
assertTruthy(runtime:find("pcall(GameTooltip.SetHyperlink", 1, true), "runtime guards tooltip hyperlink API errors")
assertTruthy(runtime:find("HandleModifiedItemClick", 1, true), "runtime supports standard modified item-link clicks")
assertTruthy(runtime:find("MAX_INSPECT_RETRIES", 1, true), "runtime retries equipped-item inspect")
assertTruthy(runtime:find("EQUIPPED_PENDING", 1, true), "runtime shows pending equipped-item state")
assertTruthy(runtime:find("inspect_retry", 1, true), "runtime records inspect retry diagnostics")
assertTruthy(runtime:find("inspect_failed", 1, true), "runtime records inspect failure diagnostics")
assertTruthy(runtime:find("attempt=", 1, true), "runtime prints inspect diagnostic attempt counts")
assertTruthy(runtime:find("command == \"debug\"", 1, true), "runtime wires /dyni debug")
assertTruthy(runtime:find("RecordDiagnostic", 1, true), "runtime records loot diagnostics")
assertTruthy(runtime:find("HandleLootMessage(...)", 1, true), "runtime passes full loot event payload")
assertTruthy(runtime:find("CreateLootMessagePatterns", 1, true), "runtime uses localized loot message patterns")
assertTruthy(runtime:find("ResolveLootMessageLooter", 1, true), "runtime resolves looters through localized loot patterns")
assertTruthy(runtime:find("ContinueOnItemLoad", 1, true), "runtime waits for uncached item data")
assertTruthy(runtime:find("BuildItemMetadata", 1, true), "runtime maps item info through core metadata helper")
assertTruthy(runtime:find("DoYouNeedItDB.sessionRows", 1, true), "runtime persists session rows")
assertTruthy(runtime:find("DoYouNeedItDB.sessionAllRows", 1, true), "runtime persists all gear session rows")
assertEqual(runtime:find("selectedTab", 1, true), nil, "runtime does not keep a loot tab state")
assertTruthy(runtime:find("RowsForSelectedView", 1, true), "runtime still routes current/session/history rows through one view helper")
assertTruthy(runtime:find("TooltipHasTradeTimer", 1, true), "runtime detects trade timer tooltip lines")
assertTruthy(runtime:find("CanPlayerEquipItem", 1, true), "runtime detects whether the player can equip a drop")
assertTruthy(runtime:find("C_Item.IsUsableItem", 1, true), "runtime asks WoW whether the player can use the item")
assertTruthy(runtime:find("Core.ResolvePlayerCanEquip", 1, true), "runtime filters askable gear through core equip eligibility")
assertTruthy(runtime:find("ClassifyGearLoot", 1, true), "runtime classifies all gear before askable filtering")
assertTruthy(runtime:find("SnapshotRowsForSave", 1, true), "runtime sanitizes saved session rows")
assertTruthy(runtime:find("SnapshotHistoryForSave", 1, true), "runtime sanitizes saved history")
assertTruthy(runtime:find("session drops=", 1, true), "runtime reports saved session drop count in status")
assertTruthy(runtime:find("all gear=", 1, true), "runtime reports saved all gear drop count in status")
assertTruthy(runtime:find("NewestRowsWindow", 1, true), "runtime displays newest rows through a scrollable window")
assertTruthy(runtime:find("OnMouseWheel", 1, true), "runtime lets raid-sized loot lists scroll")
assertEqual(runtime:find("UnitExistsClean", 1, true), nil, "runtime does not gate roster building through UnitExists")
assertTruthy(runtime:find("layout=540x300", 1, true), "runtime reports compact settings-enabled layout in status")

print("tests ok")
