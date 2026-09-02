local Harness = dofile("tests/runtime_harness.lua")

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

local function newLoadedHarness()
    local h = Harness.new()
    h:loadAddon()
    h:runNextTimer(0)
    h.timers = {}
    h:resetSideEffects()
    return h
end

local function newLoadedHarnessWithDB(db)
    local h = Harness.new({ db = db })
    h:loadAddon()
    h:runNextTimer(0)
    h.timers = {}
    h:resetSideEffects()
    return h
end

local function addWeapon(h, itemID, name)
    return h:addItem(itemID, {
        name = name,
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })
end

local function addUncachedWeapon(h, itemID, name)
    return h:addItem(itemID, {
        name = name,
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
        cacheLoaded = false,
    })
end

local function addNeverCachedWeapon(h, itemID, name)
    return h:addItem(itemID, {
        name = name,
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
        cacheLoaded = false,
        cacheNeverLoads = true,
    })
end

local function findDiagnostic(h, stage, reason)
    local diagnostics = h.env.DoYouNeedItDB.diagnostics or {}
    for index = 1, #diagnostics do
        local entry = diagnostics[index]
        if entry.stage == stage and (reason == nil or entry.reason == reason) then
            return entry
        end
    end
    return nil
end

local function testDifferentGuidLootInspectsAreSerialized()
    local h = newLoadedHarness()
    local first = addWeapon(h, 21001, "First Sword")
    local second = addWeapon(h, 21002, "Second Sword")

    h:fireLoot("Otherplayer", first)
    h:fireLoot("Secondplayer", second)

    assertEqual(#h.notifyInspectCalls, 1, "two loot rows start only one live inspect")
    assertEqual(h.notifyInspectCalls[1], "party1", "first loot inspect starts first")

    h:setInventoryLink("party1", "MainHandSlot", "|cff1eff00|Hitem:25:::::::::::::|h[Worn Sword]|h|r")
    h:fire("INSPECT_READY", "PartyGUID1")
    assertEqual(#h.notifyInspectCalls, 2, "second loot inspect starts after first ready")
    assertEqual(h.notifyInspectCalls[2], "party2", "second loot inspect starts for second looter")
end

local function testSameGuidLootInspectsCoalesce()
    local h = newLoadedHarness()
    local first = addWeapon(h, 21003, "First Ring")
    local second = addWeapon(h, 21004, "Second Ring")

    h:fireLoot("Otherplayer", first)
    h:fireLoot("Otherplayer", second)
    assertEqual(#h.notifyInspectCalls, 1, "same-guid loot rows share one NotifyInspect")

    h:setInventoryLink("party1", "MainHandSlot", "|cff1eff00|Hitem:26:::::::::::::|h[Shared Worn Sword]|h|r")
    h:fire("INSPECT_READY", "PartyGUID1")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 2, "same-guid loot rows both remain saved")
    assertTruthy(h.env.DoYouNeedItDB.sessionRows[1].equippedText:find("Shared Worn Sword", 1, true), "first same-guid row gets equipped text")
    assertTruthy(h.env.DoYouNeedItDB.sessionRows[2].equippedText:find("Shared Worn Sword", 1, true), "second same-guid row gets equipped text")
    assertEqual(h.clearInspectCalls, 1, "same-guid ready clears owned inspect state once")
end

local function testInspectTimeoutClearsOwnedInspectState()
    local h = newLoadedHarness()
    local item = addWeapon(h, 21005, "Timeout Sword")

    h:fireLoot("Otherplayer", item)
    assertEqual(#h.notifyInspectCalls, 1, "timeout test starts one inspect")
    assertEqual(h:runNextTimer(0.8), true, "timeout timer ran")
    assertEqual(h.clearInspectCalls, 1, "timeout clears Blizzard inspect state")
end

local function testCachedFallbackSurvivesLiveInspectFailure()
    local h = Harness.new()
    local cachedLink = "|cff1eff00|Hitem:27:::::::::::::|h[Cached Worn Sword]|h|r"
    h:setInventoryLink("party1", "MainHandSlot", cachedLink)
    h:loadAddon()
    assertEqual(h:runNextTimer(0), true, "pre-scan starts with player capture")
    assertEqual(h:runNextTimer(1.1), true, "pre-scan starts party inspect")
    h:fire("INSPECT_READY", "PartyGUID1")
    h.timers = {}
    h:resetSideEffects()
    h:setInventoryLink("party1", "MainHandSlot", nil)

    local item = addWeapon(h, 21006, "Cached Drop Sword")
    h:fireLoot("Otherplayer", item)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "cached fallback row is visible")
    assertTruthy(rows[1].row.equippedText:find("Cached: ", 1, true), "loot row uses cached equipped fallback before live ready")
    assertTruthy(rows[1].row.equippedText:find("Cached Worn Sword", 1, true), "cached equipped item is preserved")
    h:runNextTimer(0.8)
    assertTruthy(rows[1].row.equippedText:find("Cached Worn Sword", 1, true), "cached equipped fallback survives timeout")
end

local function testAutoPendingUsesStableStatusKey()
    local h = newLoadedHarnessWithDB({
        settings = {
            autoWhisper = true,
            autoDelay = 12,
            font = "Fonts\\FRIZQT__.TTF",
        },
    })
    local item = addWeapon(h, 21019, "Auto Pending Sword")

    h:fireLoot("Otherplayer", item)

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "auto-pending loot row is visible")
    assertEqual(rows[1].row.statusKey, "auto_pending", "auto whisper countdown stores a stable status key")
    assertEqual(rows[1].row.statusText, nil, "auto whisper countdown does not store English display text")
    assertEqual(rows[1].row.statusSeconds, 12, "auto whisper countdown stores the numeric delay separately")
    assertEqual(rows[1].status:GetText(), "auto in 12s", "auto whisper countdown still renders in the UI")
    assertEqual(h.env.DoYouNeedItDB.sessionRows[1].statusKey, "candidate", "saved auto-pending row falls back to stable candidate status")
    assertEqual(h.env.DoYouNeedItDB.sessionRows[1].statusText, nil, "saved auto-pending row does not persist display text")
end

local function testExpiredCachedFallbackIsIgnored()
    local h = Harness.new()
    local cachedLink = "|cff1eff00|Hitem:34:::::::::::::|h[Expired Cached Sword]|h|r"
    h:setInventoryLink("party1", "MainHandSlot", cachedLink)
    h:loadAddon()
    assertEqual(h:runNextTimer(0), true, "expired-cache test starts with player capture")
    assertEqual(h:runNextTimer(1.1), true, "expired-cache test starts party inspect")
    h:fire("INSPECT_READY", "PartyGUID1")
    h.now = h.now + 3600
    h.timers = {}
    h:resetSideEffects()
    h:setInventoryLink("party1", "MainHandSlot", nil)
    h.canInspect.party1 = false

    local item = addWeapon(h, 21018, "Expired Cache Drop Sword")
    h:fireLoot("Otherplayer", item)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "expired-cache loot row is visible")
    assertEqual(rows[1].row.equippedText:find("Cached: ", 1, true), nil, "expired cache does not mark the row as cached")
    assertEqual(rows[1].row.equippedText:find("Expired Cached Sword", 1, true), nil, "expired cache item text is not reused")
end

local function testRosterUpdateDoesNotReadReplacementUnitForActiveLootInspect()
    local h = newLoadedHarness()
    local item = addWeapon(h, 21007, "Roster Swap Sword")
    local replacementLink = "|cff1eff00|Hitem:28:::::::::::::|h[Replacement Worn Sword]|h|r"

    h:fireLoot("Otherplayer", item)
    assertEqual(#h.notifyInspectCalls, 1, "roster swap test starts one inspect")
    h:setUnit("party1", {
        name = "Replacement",
        realm = "Ravencrest",
        guid = "ReplacementGUID",
        classToken = "WARRIOR",
    })
    h:setInventoryLink("party1", "MainHandSlot", replacementLink)
    h:fire("GROUP_ROSTER_UPDATE")
    h:fire("INSPECT_READY", "PartyGUID1")

    local rows = h.env.DoYouNeedItDB.sessionRows
    assertEqual(#rows, 1, "stale ready keeps original loot row saved")
    assertEqual(rows[1].equippedText:find("Replacement Worn Sword", 1, true), nil, "stale ready does not read replacement unit gear")
end

local function testClearCancelsInspectWorkAndUnblocksNewLoot()
    local h = newLoadedHarness()
    local first = addWeapon(h, 21008, "Clear First Sword")
    local second = addWeapon(h, 21009, "Clear Second Sword")
    local third = addWeapon(h, 21010, "Clear Third Sword")

    h:fireLoot("Otherplayer", first)
    h:fireLoot("Secondplayer", second)
    assertEqual(#h.notifyInspectCalls, 1, "clear test starts only the active inspect")

    h:slash("clear")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "clear removes askable session rows")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 0, "clear removes all-gear session rows")
    assertEqual(h.clearInspectCalls, 1, "clear releases Blizzard inspect ownership")

    h:resetSideEffects()
    h:fireLoot("Thirdplayer", third)
    assertEqual(#h.notifyInspectCalls, 1, "new loot starts inspect immediately after clear")
    assertEqual(h.notifyInspectCalls[1], "party3", "new loot inspect is not blocked by stale requests")
end

local function testStaleInspectRetryAfterClearDoesNotRequeueOldRow()
    local h = newLoadedHarness()
    local item = addWeapon(h, 21011, "Retry After Clear Sword")

    h:fireLoot("Otherplayer", item)
    assertEqual(#h.notifyInspectCalls, 1, "retry-after-clear test starts inspect")
    h:slash("clear")
    h:resetSideEffects()

    h:runTimers(0.8, 5)
    assertEqual(#h.notifyInspectCalls, 0, "stale inspect timers do not requeue old rows after clear")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "stale retry does not repersist cleared askable rows")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 0, "stale retry does not repersist cleared all-gear rows")
end

local function testStaleItemLoadAfterClearDoesNotAddOldLoot()
    local h = newLoadedHarness()
    local item = addUncachedWeapon(h, 21018, "Slow Cache Sword")

    h:fireLoot("Otherplayer", item)
    assertEqual(#h:visibleRows(), 0, "uncached item waits for item metadata before adding rows")

    h:slash("clear")
    h:runTimers(0, 10)
    h:runTimers(3, 10)

    assertEqual(#h:visibleRows(), 0, "stale item-load callback after clear does not show old loot")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "stale item-load callback after clear does not repersist askable rows")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 0, "stale item-load callback after clear does not repersist all-gear rows")

    h:fireLoot("Otherplayer", item)
    assertEqual(#h:visibleRows(), 1, "fresh loot after item cache load still adds a row")
end

local function testNeverLoadedItemMetadataFailsAndClearsPendingLoot()
    local h = newLoadedHarnessWithDB({
        settings = {
            debug = true,
            font = "Fonts\\FRIZQT__.TTF",
        },
    })
    local item = addNeverCachedWeapon(h, 21020, "Never Cached Sword")

    h:fireLoot("Otherplayer", item)
    assertEqual(#h:visibleRows(), 0, "never-cached item waits for item metadata before adding rows")

    h:runTimers(3, 20)

    assertEqual(#h:visibleRows(), 0, "never-cached item does not show an unverified loot row after retry limit")
    assertEqual(#(h.env.DoYouNeedItDB.sessionRows or {}), 0, "never-cached item does not persist askable rows after retry limit")
    assertEqual(#(h.env.DoYouNeedItDB.sessionAllRows or {}), 0, "never-cached item does not persist all-gear rows after retry limit")
    assertTruthy(findDiagnostic(h, "metadata_failed", "retry_limit"), "never-cached item records a retry-limit metadata diagnostic")

    h:resetSideEffects()
    h:fireLoot("Otherplayer", item)
    h:runTimers(3, 20)
    assertEqual(#h:visibleRows(), 0, "retry-limit cleanup lets later failed loot start and finish without stale rows")
end

local function testUnresolvedLootMessageNameCreatesUnsafeAllGearOnlyRow()
    local h = newLoadedHarnessWithDB({
        settings = {
            autoWhisper = true,
            font = "Fonts\\FRIZQT__.TTF",
        },
    })
    local item = addWeapon(h, 21021, "Unresolved Looter Sword")

    h:fireLoot("Crossrealmhero", item)

    assertEqual(#(h.env.DoYouNeedItDB.sessionRows or {}), 0, "unresolved live looter is not saved as askable")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "unresolved live looter is saved in all-gear history")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].unsafe, true, "unresolved live looter row is marked unsafe")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "looter_unresolved", "unresolved live looter keeps a visible reason")
    assertEqual(#h.notifyInspectCalls, 0, "unresolved live looter does not start inspect")
    h:runTimers(20, 10)
    assertEqual(#h.sentMessages, 0, "unresolved live looter does not auto-whisper")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "unresolved live looter appears in the unified loot list when there are no askable rows")
    assertEqual(rows[1].row.askable, false, "unresolved live looter visible row is review-only")
    assertEqual(rows[1].whisper:IsShown(), false, "unresolved live looter row hides Ask")
end

local function testPlaceholderLootMessageNameIsIgnored()
    local h = newLoadedHarness()
    local item = addWeapon(h, 21022, "Placeholder Looter Sword")

    h:fireLoot("UNKNOWNOBJECT", item)

    assertEqual(#(h.env.DoYouNeedItDB.sessionRows or {}), 0, "placeholder live looter does not create askable rows")
    assertEqual(#(h.env.DoYouNeedItDB.sessionAllRows or {}), 0, "placeholder live looter does not create all-gear rows")
    assertEqual(#h.notifyInspectCalls, 0, "placeholder live looter does not inspect")
end

local function testQueuedInspectRejectsUnitGuidMismatchBeforeNotify()
    local h = newLoadedHarness()
    local first = addWeapon(h, 21012, "Queued First Sword")
    local second = addWeapon(h, 21013, "Queued Second Sword")

    h:fireLoot("Otherplayer", first)
    h:fireLoot("Secondplayer", second)
    assertEqual(#h.notifyInspectCalls, 1, "queued mismatch test starts only first inspect")

    h:setUnit("party2", {
        name = "Replacement",
        realm = "Ravencrest",
        guid = "ReplacementGUID",
        classToken = "WARRIOR",
    })
    h:fire("GROUP_ROSTER_UPDATE")
    h:setInventoryLink("party1", "MainHandSlot", "|cff1eff00|Hitem:29:::::::::::::|h[First Worn Sword]|h|r")
    h:fire("INSPECT_READY", "PartyGUID1")

    assertEqual(#h.notifyInspectCalls, 1, "queued inspect with mismatched unit GUID is not notified")
end

local function testSameGuidRosterMoveStillCompletes()
    local h = newLoadedHarness()
    local item = addWeapon(h, 21014, "Moved Roster Sword")
    local movedLink = "|cff1eff00|Hitem:30:::::::::::::|h[Moved Worn Sword]|h|r"

    h:fireLoot("Otherplayer", item)
    assertEqual(#h.notifyInspectCalls, 1, "same-guid move test starts one inspect")
    h:setUnit("party1", {
        name = "Replacement",
        realm = "Ravencrest",
        guid = "ReplacementGUID",
        classToken = "WARRIOR",
    })
    h:setUnit("party2", {
        name = "Otherplayer",
        realm = "Ravencrest",
        guid = "PartyGUID1",
        classToken = "PALADIN",
    })
    h:setInventoryLink("party2", "MainHandSlot", movedLink)
    h:fire("GROUP_ROSTER_UPDATE")
    h:fire("INSPECT_READY", "PartyGUID1")

    assertTruthy(h.env.DoYouNeedItDB.sessionRows[1].equippedText:find("Moved Worn Sword", 1, true), "same GUID roster move still reads the moved unit")
end

local function testClearDropsCachedFallbackForFutureLoot()
    local h = Harness.new()
    local cachedLink = "|cff1eff00|Hitem:31:::::::::::::|h[Cached Clear Sword]|h|r"
    h:setInventoryLink("party1", "MainHandSlot", cachedLink)
    h:loadAddon()
    assertEqual(h:runNextTimer(0), true, "clear-cache test starts with player capture")
    assertEqual(h:runNextTimer(1.1), true, "clear-cache test starts party inspect")
    h:fire("INSPECT_READY", "PartyGUID1")
    h.timers = {}
    h:slash("clear")
    h:resetSideEffects()
    h:setInventoryLink("party1", "MainHandSlot", nil)
    h.canInspect.party1 = false

    local item = addWeapon(h, 21015, "After Clear Drop Sword")
    h:fireLoot("Otherplayer", item)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "post-clear loot row is visible")
    assertEqual(rows[1].row.equippedText:find("Cached Clear Sword", 1, true), nil, "clear prevents stale cached fallback on future loot")
end

local function testRosterUpdateDropsCachedFallbackForChangedIdentity()
    local h = Harness.new()
    local cachedLink = "|cff1eff00|Hitem:32:::::::::::::|h[Cached Roster Sword]|h|r"
    h:setInventoryLink("party1", "MainHandSlot", cachedLink)
    h:loadAddon()
    assertEqual(h:runNextTimer(0), true, "roster-cache test starts with player capture")
    assertEqual(h:runNextTimer(1.1), true, "roster-cache test starts party inspect")
    h:fire("INSPECT_READY", "PartyGUID1")
    h.timers = {}
    h:setUnit("party1", {
        name = "Replacement",
        realm = "Ravencrest",
        guid = "ReplacementGUID",
        classToken = "WARRIOR",
    })
    h:fire("GROUP_ROSTER_UPDATE")
    h.timers = {}
    h:setInventoryLink("party1", "MainHandSlot", nil)
    h.canInspect.party1 = false

    local item = addWeapon(h, 21016, "After Roster Drop Sword")
    h:fireLoot("Otherplayer", item)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "post-roster loot row is visible")
    assertEqual(rows[1].row.equippedText:find("Cached Roster Sword", 1, true), nil, "roster identity change prevents stale cached fallback")
end

local function testStaleScanReadyDoesNotCacheReplacementUnit()
    local h = Harness.new()
    local replacementLink = "|cff1eff00|Hitem:33:::::::::::::|h[Stale Scan Replacement Sword]|h|r"
    h:setInventoryLink("party1", "MainHandSlot", replacementLink)
    h:loadAddon()
    assertEqual(h:runNextTimer(0), true, "stale-scan test starts with player capture")
    assertEqual(h:runNextTimer(1.1), true, "stale-scan test starts party inspect")

    h:setUnit("party1", {
        name = "Replacement",
        realm = "Ravencrest",
        guid = "ReplacementGUID",
        classToken = "WARRIOR",
    })
    h:fire("INSPECT_READY", "PartyGUID1")
    h.timers = {}
    h:resetSideEffects()
    h:setInventoryLink("party1", "MainHandSlot", nil)
    h.canInspect.party1 = false

    local item = addWeapon(h, 21017, "Replacement Drop Sword")
    h:fireLoot("Replacement", item)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "replacement loot row is visible after stale scan ready")
    assertEqual(rows[1].row.equippedText:find("Stale Scan Replacement Sword", 1, true), nil, "stale scan ready does not cache replacement unit gear")
end

local function testInstanceChangeCancelsPendingInspectBeforeHistory()
    local h = newLoadedHarness()
    local item = addWeapon(h, 21019, "Instance Change Sword")

    h:fireLoot("Otherplayer", item)
    assertEqual(#h.notifyInspectCalls, 1, "instance-change test starts a live inspect")
    local liveRows = h:visibleRows()
    assertEqual(liveRows[1].row.equippedText, "Equipped: checking...", "precondition: loot row is waiting for inspect")

    h.instanceName = "Next Dungeon"
    h:fire("PLAYER_ENTERING_WORLD")

    assertEqual(h.clearInspectCalls, 1, "instance change releases the stale inspect request")
    local historyRows = h:visibleRows()
    assertEqual(#historyRows, 1, "instance change moves the pending loot row into history")
    assertEqual(historyRows[1].row.equippedText, "Equipped: unknown", "history row does not keep a stale inspect-pending label")
    assertEqual(h.env.DoYouNeedItDB.history[1].allRows[1].equippedText, "Equipped: unknown", "saved history also clears stale inspect-pending text")
end

local function testSameItemLevelPersonalLootBecomesAskableAfterInspect()
    local h = newLoadedHarness()
    local dropped = h:addItem(21101, {
        name = "Pendant of Malefic Fury",
        equipLoc = "INVTYPE_NECK",
        classID = 4,
        subclassID = 0,
        quality = 4,
        bindType = 1,
        itemLevel = 311,
        equippable = true,
        usable = true,
    })
    local equipped = h:addItem(21102, {
        name = "Strand of Warding Fangs",
        equipLoc = "INVTYPE_NECK",
        classID = 4,
        subclassID = 0,
        quality = 4,
        bindType = 1,
        itemLevel = 311,
        equippable = true,
        usable = true,
    })

    h:fireLoot("Otherplayer", dropped)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "personal neck drop is visible while trade eligibility is unknown")
    assertEqual(rows[1].row.askable, false, "personal neck drop starts non-askable before inspect")
    assertEqual(rows[1].whisper:IsShown(), false, "Ask stays hidden before equal-level evidence")

    h:setInventoryLink("party1", "NeckSlot", equipped)
    h:fire("INSPECT_READY", "PartyGUID1")

    rows = h:visibleRows()
    assertEqual(rows[1].row.askable, true, "equal-level equipped neck promotes the personal drop to askable")
    assertEqual(rows[1].row.tradeStatusKey, "trade_likely", "equal-level equipped neck marks transfer as likely")
    assertEqual(rows[1].whisper:IsShown(), true, "Ask appears after equal-level evidence")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "promoted personal drop is saved with askable session rows")

    local higherDropHarness = newLoadedHarness()
    local higherDrop = higherDropHarness:addItem(21103, {
        name = "Higher Pendant",
        equipLoc = "INVTYPE_NECK",
        classID = 4,
        subclassID = 0,
        quality = 4,
        bindType = 1,
        itemLevel = 312,
        equippable = true,
        usable = true,
    })
    local lowerEquipped = higherDropHarness:addItem(21104, {
        name = "Lower Strand",
        equipLoc = "INVTYPE_NECK",
        classID = 4,
        subclassID = 0,
        quality = 4,
        bindType = 1,
        itemLevel = 311,
        equippable = true,
        usable = true,
    })
    higherDropHarness:fireLoot("Otherplayer", higherDrop)
    higherDropHarness:setInventoryLink("party1", "NeckSlot", lowerEquipped)
    higherDropHarness:fire("INSPECT_READY", "PartyGUID1")
    local higherRows = higherDropHarness:visibleRows()
    assertEqual(higherRows[1].row.askable, false, "higher personal drop stays non-askable after inspect")
    assertEqual(higherRows[1].row.tradeStatusKey, "trade_unknown", "higher personal drop keeps unknown transfer status")
    assertEqual(higherRows[1].whisper:IsShown(), false, "Ask stays hidden when item-level evidence is insufficient")
end

local function testLootInspectWaitsForCombatWithoutUsingRetries()
    local h = newLoadedHarness()
    h:slash("clear")
    local combat = true
    h.env.InCombatLockdown = function() return combat end
    local item = addWeapon(h, 21901, "Combat Drop")
    h:fireLoot("Otherplayer", item)
    local row = h:visibleRows()[1].row
    assertEqual(#h.timers, 0, "combat loot inspect parks without timers")
    assertEqual(row.inspectRetryCount, nil, "combat wait does not spend the inspect retry budget")
    assertEqual(#h.notifyInspectCalls, 0, "combat loot cannot issue NotifyInspect")
    combat = false
    h:fire("PLAYER_REGEN_ENABLED")
    assertEqual(#h.notifyInspectCalls, 1, "combat-end resumes loot even with an empty scan queue")
    h:setInventoryLink("party1", "MainHandSlot", "|cff1eff00|Hitem:25:::::::::::::|h[Combat Equipped Sword]|h|r")
    h:fire("INSPECT_READY", "PartyGUID1")
    assertTruthy(row.equippedText:find("Combat Equipped Sword", 1, true), "resumed loot receives equipment")
end

local function testLongCombatDoesNotExhaustLootInspection()
    local h = newLoadedHarness()
    h:slash("clear")
    local combat = true
    h.env.InCombatLockdown = function() return combat end
    h:fireLoot("Otherplayer", addWeapon(h, 21908, "Long Fight Sword"))
    local row = h:visibleRows()[1].row
    h:runTimers(nil, 50)
    assertEqual(row.inspectRetryCount, nil, "a long fight must not exhaust loot inspection")
    assertEqual(#h.timers, 0, "long combat has no remaining polling timers")
    combat = false
    h:fire("PLAYER_REGEN_ENABLED")
    assertEqual(#h.notifyInspectCalls, 1, "long-fight loot still inspects after combat")
end

local function testEquipmentScanParksDuringCombat()
    local h = Harness.new()
    local combat = true
    h.env.InCombatLockdown = function() return combat end
    h:loadAddon()
    h:runTimers(nil, 20)
    assertEqual(#h.timers, 0, "combat scan waits for the regen event without polling")
    assertEqual(#h.notifyInspectCalls, 0, "combat scan never inspects")
    combat = false
    h:fire("PLAYER_REGEN_ENABLED")
    h:runNextTimer(1.1)
    assertEqual(#h.notifyInspectCalls, 1, "parked scan resumes after combat")

    h:slash("clear")
    h:runTimers(nil, 20)
    combat = true
    h:fire("PLAYER_REGEN_ENABLED")
    assertEqual(#h.timers, 0, "empty queue does not start a combat retry loop")
end

local function testCombatParksAnAlreadyScheduledLootRetry()
    local h = newLoadedHarness()
    h:slash("clear")
    local combat = false
    h.env.InCombatLockdown = function() return combat end
    h:fireLoot("Otherplayer", addWeapon(h, 21902, "Retry Combat Drop"))
    local row = h:visibleRows()[1].row
    h:runNextTimer(0.8)
    assertEqual(row.inspectRetryCount, 1, "real timeout spends one retry")
    combat = true
    h:runNextTimer(0.8)
    assertEqual(row.inspectRetryCount, 1, "queued retry reaching combat preserves its budget")
    assertEqual(#h.timers, 0, "queued retry parks instead of scheduling more combat timers")
    combat = false
    h:fire("PLAYER_REGEN_ENABLED")
    assertEqual(#h.notifyInspectCalls, 2, "parked retry resumes once after combat")
end

local function testCombatLootWakeupIsBoundedAndCancellationSafe()
    local h = newLoadedHarness()
    h:slash("clear")
    local combat = true
    h.env.InCombatLockdown = function() return combat end
    h:fireLoot("Otherplayer", addWeapon(h, 21903, "Cleared Combat Drop"))
    for _ = 1, 20 do h:fire("PLAYER_REGEN_ENABLED") end
    assertEqual(#h.timers, 1, "lagging regen events share one pending wakeup")
    local staleTimer = table.remove(h.timers, 1)
    h:slash("clear")
    h:fireLoot("Secondplayer", addWeapon(h, 21904, "Current Combat Drop"))
    h:fire("PLAYER_REGEN_ENABLED")
    combat = false
    staleTimer.callback()
    assertEqual(#h.notifyInspectCalls, 0, "old wakeup cannot consume a replacement loot queue")
    assertEqual(#h.timers, 1, "old wakeup leaves the current callback intact")
    h:runNextTimer(0.25)
    assertEqual(#h.notifyInspectCalls, 1, "current wakeup resumes exactly once")
    assertEqual(h.notifyInspectCalls[1], "party2", "cleared loot was not resurrected")

    local blocked = newLoadedHarness()
    blocked:slash("clear")
    blocked.env.InCombatLockdown = function() return true end
    blocked:fireLoot("Otherplayer", addWeapon(blocked, 21905, "Long Combat Drop"))
    blocked:fire("PLAYER_REGEN_ENABLED")
    assertEqual(blocked:runTimers(nil, 20), 3, "loot-only wakeup has the same three-retry budget")
    assertEqual(#blocked.timers, 0, "loot-only wakeup cannot poll forever")
    assertEqual(blocked:visibleRows()[1].row.inspectRetryCount, nil, "API lag does not spend loot retries")
end

local function testSameLooterCombatRowsShareOneResumedInspect()
    local h = newLoadedHarness()
    h:slash("clear")
    local combat = true
    h.env.InCombatLockdown = function() return combat end
    h:fireLoot("Otherplayer", addWeapon(h, 21906, "First Combat Sword"))
    h:fireLoot("Otherplayer", addWeapon(h, 21907, "Second Combat Sword"))
    assertEqual(#h.timers, 0, "multiple combat drops remain timer-free")
    combat = false
    h:fire("PLAYER_REGEN_ENABLED")
    assertEqual(#h.notifyInspectCalls, 1, "same-looter parked rows coalesce after combat")
    h:setInventoryLink("party1", "MainHandSlot", "|cff1eff00|Hitem:25:::::::::::::|h[Shared Combat Sword]|h|r")
    h:fire("INSPECT_READY", "PartyGUID1")
    for _, frame in ipairs(h:visibleRows()) do
        assertTruthy(frame.row.equippedText:find("Shared Combat Sword", 1, true), "each coalesced row receives equipment")
    end
end

local function testClearedScanTimerCannotConsumeReplacementQueue()
    local h = Harness.new()
    h:loadAddon()
    local staleTimer = table.remove(h.timers, 1)
    assertTruthy(staleTimer, "initial scan timer exists")
    h:slash("clear")
    h:slash("scan")
    local readsBefore = #h.inventoryReadCalls
    local timersBefore = #h.timers
    staleTimer.callback()
    assertEqual(#h.inventoryReadCalls, readsBefore, "cleared callback cannot read replacement roster")
    assertEqual(#h.timers, timersBefore, "cleared callback cannot fork replacement scan timers")
    h:runNextTimer(0)
    assertTruthy(#h.inventoryReadCalls > readsBefore, "current scan timer still runs")
end

local function testCombatEndStateLagRecoversBoundedly()
    local h = Harness.new()
    local combat = true
    h.env.InCombatLockdown = function() return combat end
    h:loadAddon()
    h:runTimers(nil, 20)
    h:fire("PLAYER_REGEN_ENABLED")
    assertEqual(#h.timers, 1, "combat end with a lagging API schedules a bounded retry")
    combat = false
    h:runNextTimer(0.25)
    h:runNextTimer(1.1)
    assertEqual(#h.notifyInspectCalls, 1, "lagging combat end eventually resumes inspection")

    local blocked = Harness.new()
    blocked.env.InCombatLockdown = function() return true end
    blocked:loadAddon()
    blocked:runTimers(nil, 20)
    blocked:fire("PLAYER_REGEN_ENABLED")
    assertEqual(blocked:runTimers(nil, 20), 3, "combat-end recovery has a three-retry budget")
    assertEqual(#blocked.timers, 0, "persistent combat cannot restart polling")
    assertEqual(#blocked.notifyInspectCalls, 0, "recovery never bypasses combat lockdown")
end

testLongCombatDoesNotExhaustLootInspection()
testLootInspectWaitsForCombatWithoutUsingRetries()
testCombatParksAnAlreadyScheduledLootRetry()
testCombatLootWakeupIsBoundedAndCancellationSafe()
testSameLooterCombatRowsShareOneResumedInspect()
testCombatEndStateLagRecoversBoundedly()
testEquipmentScanParksDuringCombat()
testClearedScanTimerCannotConsumeReplacementQueue()
testDifferentGuidLootInspectsAreSerialized()
testSameGuidLootInspectsCoalesce()
testInspectTimeoutClearsOwnedInspectState()
testCachedFallbackSurvivesLiveInspectFailure()
testAutoPendingUsesStableStatusKey()
testExpiredCachedFallbackIsIgnored()
testRosterUpdateDoesNotReadReplacementUnitForActiveLootInspect()
testClearCancelsInspectWorkAndUnblocksNewLoot()
testStaleInspectRetryAfterClearDoesNotRequeueOldRow()
testStaleItemLoadAfterClearDoesNotAddOldLoot()
testNeverLoadedItemMetadataFailsAndClearsPendingLoot()
testUnresolvedLootMessageNameCreatesUnsafeAllGearOnlyRow()
testPlaceholderLootMessageNameIsIgnored()
testQueuedInspectRejectsUnitGuidMismatchBeforeNotify()
testSameGuidRosterMoveStillCompletes()
testClearDropsCachedFallbackForFutureLoot()
testRosterUpdateDropsCachedFallbackForChangedIdentity()
testStaleScanReadyDoesNotCacheReplacementUnit()
testInstanceChangeCancelsPendingInspectBeforeHistory()
testSameItemLevelPersonalLootBecomesAskableAfterInspect()

print("runtime inspect ok")
