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
assertEqual(Core.GetLocaleLabel("Missing Label", "ruRU"), "Missing Label", "missing localized labels fall back to English key")
assertEqual(Core.GetLanguageOption("ruRU").label, "Русский (Russian)", "language option lookup returns bilingual label")
assertEqual(Core.GetLanguageOption("badLocale"), nil, "language option lookup returns nil for unknown locale")
assertEqual(Core.FontPathKey("Fonts/ARIALN.TTF"), "fonts\\arialn.ttf", "font path keys normalize slash and case")
assertEqual(Core.SameFontPath("Fonts/ARIALN.TTF", "fonts\\arialn.ttf"), true, "font path comparison is normalized")
assertEqual(Core.FontSupports("Fonts\\ARIALN.TTF", "CYR", "enUS"), true, "Arial Narrow supports Cyrillic on western clients")
assertEqual(Core.FontSupports("Fonts\\FRIZQT__.TTF", "CYR", "enUS"), false, "Friz does not guarantee Cyrillic on western clients")
assertEqual(Core.FontSupports("Fonts\\FRIZQT__.TTF", "CYR", "ruRU"), true, "Friz supports Cyrillic on ruRU clients")
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
}, "Player-OtherRealm", "Player-Ravencrest")
assertEqual(sameBaseDifferentRealm.visible, true, "same short name on a different realm is not self loot")
local sameBaseDifferentRealmWithShortPlayerName = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
    bindType = 2,
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

local emptyState = Core.CreateState({ maxHistoryGroups = 10 })
Core.CompleteCurrentGroup(emptyState, { title = "No Drops", endedAt = 1 })
assertEqual(#emptyState.history, 0, "empty groups are not saved")

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

assertEqual(
    Core.GetAutoShowTabForRow({ currentRows = {} }, { askable = false, itemLink = "|cff0070dd|Hitem:101:::::::::::::|h[All Only]|h|r" }),
    "all",
    "all-only loot opens all gear when no askable rows exist"
)
assertEqual(
    Core.GetAutoShowTabForRow({ currentRows = { { id = "askable-row" } } }, { askable = false, itemLink = "|cff0070dd|Hitem:101:::::::::::::|h[All Only]|h|r" }),
    "askable",
    "all-only loot keeps askable selected when askable rows exist"
)
assertEqual(
    Core.GetAutoShowTabForRow({ currentRows = {} }, { askable = true, itemLink = "|cff0070dd|Hitem:100:::::::::::::|h[Askable]|h|r" }),
    "askable",
    "askable loot opens askable"
)

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
    Core.GetCachedEquippedText(equipmentCache, "Otherplayer", "INVTYPE_CHEST"),
    nil,
    "equipment cache returns nil for missing slots"
)
assertEqual(
    Core.StoreEquipmentCache(equipmentCache, "Emptyplayer", {}, 1235),
    false,
    "equipment cache rejects empty captures"
)

local pendingRow = { id = "pending" }
local otherPendingRow = { id = "other" }
local pendingRows = {
    inspectGuid = { pendingRow, otherPendingRow, pendingRow },
}
assertEqual(Core.RemovePendingRow(pendingRows, "inspectGuid", pendingRow), 2, "pending inspect cleanup removes duplicate row references")
assertEqual(#pendingRows.inspectGuid, 1, "pending inspect cleanup keeps unrelated rows")
assertEqual(pendingRows.inspectGuid[1], otherPendingRow, "pending inspect cleanup preserves row order")
assertEqual(Core.RemovePendingRow(pendingRows, "inspectGuid", otherPendingRow), 1, "pending inspect cleanup removes the final row")
assertEqual(pendingRows.inspectGuid, nil, "pending inspect cleanup drops empty guid buckets")
assertEqual(Core.RemovePendingRow(pendingRows, "missingGuid", pendingRow), 0, "pending inspect cleanup tolerates missing buckets")

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
}, 10)
assertEqual(#persistedRows, 2, "save snapshot keeps persistable rows")
assertEqual(persistedRows[1].statusText, "candidate", "save snapshot clears stale pending auto status")
assertEqual(persistedRows[1].equippedText, "Equipped: unknown", "save snapshot clears stale pending inspect status")
assertEqual(persistedRows[1].pendingAutoWhisper, nil, "save snapshot drops pending auto flag")
assertEqual(persistedRows[1].autoToken, nil, "save snapshot drops runtime auto token")
assertEqual(persistedRows[1].runtimeOnly, nil, "save snapshot drops non-primitive runtime fields")
assertEqual(persistedRows[2].manualWhispered, true, "save snapshot keeps sent whisper state")
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
assertEqual(persistedHistory[1].rows[1].statusText, "candidate", "history snapshot clears stale pending auto status")
assertEqual(persistedHistory[1].rows[1].autoToken, nil, "history snapshot drops runtime auto token")
assertEqual(#persistedHistory[1].allRows, 1, "history snapshot keeps all gear rows")
assertEqual(persistedHistory[1].allRows[1].askable, false, "history snapshot keeps non-askable marker")
assertEqual(persistedHistory[1].transient, nil, "history snapshot drops runtime group fields")

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
assertEqual(Core.ShouldAutoShowWindow({ itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r" }), true, "new loot rows auto-show the window")
assertEqual(Core.ShouldAutoShowWindow(nil), false, "missing rows do not auto-show the window")

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

local lootPatterns = Core.CreateLootMessagePatterns({
    lootSelf = "You receive loot: %s.",
    lootSelfMultiple = "You receive loot: %sx%d.",
    lootOther = "%s receives loot: %s.",
    lootOtherMultiple = "%s receives loot: %sx%d.",
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
local positionalPatterns = Core.CreateLootMessagePatterns({
    lootOther = "%1$s receives loot: %2$s.",
})
local resolvedPositional = Core.ResolveLootMessageLooter(
    "Otherplayer receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r.",
    positionalPatterns,
    "Player-Ravencrest"
)
assertEqual(resolvedPositional.name, "Otherplayer", "positional localized loot pattern resolves looter")
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

assertEqual(Core.VERSION, "0.1.21", "core exposes current version")

local function readFile(path)
    local handle = assert(io.open(path, "rb"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local toc = readFile("DoYouNeedIt.toc")
assertTruthy(toc:find("## Title: Do You Need It?", 1, true), "toc title present")
assertTruthy(toc:find("## Version: 0.1.21", 1, true), "toc version present")
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
assertTruthy(runtime:find("CreateSettingsUI", 1, true), "runtime creates a settings window")
assertTruthy(runtime:find("UIDropDownMenuTemplate", 1, true), "runtime uses Blizzard dropdowns for settings")
assertTruthy(runtime:find("PreviewLanguage", 1, true), "runtime previews language on hover")
assertTruthy(runtime:find("CancelLanguagePreview", 1, true), "runtime cancels language preview")
assertTruthy(runtime:find("PreviewFont", 1, true), "runtime previews font on hover")
assertTruthy(runtime:find("CancelFontPreview", 1, true), "runtime cancels font preview")
assertTruthy(runtime:find("CancelSettingsPreview", 1, true), "runtime force-clears settings hover previews")
assertTruthy(runtime:find("SetDropdownTextSafe", 1, true), "runtime repairs dropdown captions after preview changes")
assertTruthy(runtime:find("HookScript(\"OnLeave\"", 1, true), "runtime restores font previews when leaving dropdown buttons")
assertTruthy(runtime:find("frame:SetScript(\"OnHide\", CancelSettingsPreview)", 1, true), "settings window restores previews on close")
assertTruthy(runtime:find("LibSharedMedia%-3%.0", 1, false), "runtime reads LibSharedMedia fonts")
assertTruthy(runtime:find("DropDownList1:HookScript(\"OnHide\"", 1, true), "runtime rolls back dropdown hover previews on close")
assertTruthy(runtime:find("Core.GetLocaleLabel", 1, true), "runtime localizes visible UI strings")
assertTruthy(runtime:find("RegisterFontString", 1, true), "runtime tracks owned font strings")
assertTruthy(runtime:find("ApplyCurrentFont", 1, true), "runtime applies chosen or previewed font")
assertTruthy(runtime:find("Core.ResolveFontSize", 1, true), "runtime applies font-size slider to registered font strings")
assertTruthy(runtime:find("local WINDOW_WIDTH = 540", 1, true), "runtime uses compact non-overlapping window width")
assertTruthy(runtime:find("local WINDOW_HEIGHT = 300", 1, true), "runtime uses compact settings-enabled window height")
assertTruthy(runtime:find("local ROW_START_Y = -82", 1, true), "runtime leaves a compact header area above rows")
assertTruthy(runtime:find("frame.historyButton:SetSize(350, 22)", 1, true), "runtime gives history selector enough width for boss names")
assertTruthy(runtime:find("frame.tabAskable:SetPoint(\"TOPLEFT\", frame, \"TOPLEFT\", 16, -42)", 1, true), "runtime moves tabs below the title row")
assertTruthy(runtime:find("local MAX_VISIBLE_ROWS = 6", 1, true), "runtime uses freed settings space for another visible row")
assertTruthy(runtime:find("DoYouNeedItCore.ShouldAutoShowWindow", 1, true), "runtime auto-shows on new loot rows")
assertTruthy(runtime:find("GetAutoShowTabForRow", 1, true), "runtime selects all gear when only non-askable loot drops")
assertEqual(runtime:find("if askable and DoYouNeedItCore.ShouldAutoShowWindow", 1, true), nil, "runtime does not limit auto-show to askable rows")
assertTruthy(runtime:find("QueueEquipmentScan", 1, true), "runtime queues equipment pre-scans")
assertTruthy(runtime:find("StartEquipmentScan", 1, true), "runtime processes equipment scans one unit at a time")
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
assertTruthy(runtime:find("GameTooltip:SetHyperlink", 1, true), "runtime shows real item tooltips from item links")
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
assertTruthy(runtime:find("selectedTab", 1, true), "runtime has askable/all gear tabs")
assertTruthy(runtime:find("tabAllGear", 1, true), "runtime creates all gear tab")
assertTruthy(runtime:find("TooltipHasTradeTimer", 1, true), "runtime detects trade timer tooltip lines")
assertTruthy(runtime:find("CanPlayerEquipItem", 1, true), "runtime detects whether the player can equip a drop")
assertTruthy(runtime:find("C_Item.IsUsableItem", 1, true), "runtime asks WoW whether the player can use the item")
assertTruthy(runtime:find("PREFERRED_ARMOR_SUBCLASS_BY_CLASS", 1, true), "runtime filters askable armor by player class armor type")
assertTruthy(runtime:find("ClassifyGearLoot", 1, true), "runtime classifies all gear before askable filtering")
assertTruthy(runtime:find("SnapshotRowsForSave", 1, true), "runtime sanitizes saved session rows")
assertTruthy(runtime:find("SnapshotHistoryForSave", 1, true), "runtime sanitizes saved history")
assertTruthy(runtime:find("session drops=", 1, true), "runtime reports saved session drop count in status")
assertTruthy(runtime:find("all gear=", 1, true), "runtime reports saved all gear drop count in status")
assertTruthy(runtime:find("Core.GetNewestRowsFirst", 1, true), "runtime displays newest rows first")
assertEqual(runtime:find("UnitExistsClean", 1, true), nil, "runtime does not gate roster building through UnitExists")
assertTruthy(runtime:find("layout=540x300", 1, true), "runtime reports compact settings-enabled layout in status")

print("tests ok")
