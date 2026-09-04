local Harness = dofile("tests/runtime_harness.lua")

local function equal(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function fresh(auto)
    local h = Harness.new({ db = { settings = { autoWhisper = auto, autoDelay = 5 } } })
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    return h
end

local tests = {}

function tests.autoOffCancelsDeferredSend()
    local h = fresh(true)
    local item = h:addItem(29001, { name = "Deferred Auto Sword" })
    h:fireLoot("Otherplayer", item)
    for index, timer in ipairs(h.timers) do
        if timer.delay == 5 then table.remove(h.timers, index).callback(); break end
    end
    equal(h:visibleRows()[1].row.whisperInFlight, true, "send has reached its deferred boundary")
    h:slash("auto off")
    h:slash("auto on")
    h:runTimers(0, 10)
    equal(#h.sentMessages, 0, "turning auto off invalidates an in-flight send even if enabled again")
    equal(h:visibleRows()[1].row.statusKey, "candidate", "cancelled send restores Ask status")
end

function tests.clearCancelsHistoryDeferredManualSend()
    local h = fresh(false)
    local item = h:addItem(29002, { name = "History Deferred Sword" })
    h:fireLoot("Otherplayer", item)
    h:fire("ENCOUNTER_END", 123, "History Boss")
    h:runTimers(10, 100)
    equal(#h.env.DoYouNeedItDB.history, 1, "row remains in retained history")
    h:visibleRows()[1].whisper:FireScript("OnClick")
    h:slash("clear")
    h:runTimers(0, 10)
    equal(#h.sentMessages, 0, "clear cancels deferred sends for retained history rows")
end

function tests.pendingBonusVariantPreservesSourceAndLink()
    local h = fresh(false)
    local generic = "|cff0070dd|Hitem:29003:::::::::::::|h[Generic]|h|r"
    local full = "|cffa335ee|Hitem:29003:::::::::::::|h[Full]|h|r"
    h:addItem(29003, { cacheLoaded = false })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29003, generic, 1, "Otherplayer", "PALADIN")
    h:fireBonusLoot("Otherplayer", full)
    h:runTimers(0, 10)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "pending variants produce one drop")
    local row = h.env.DoYouNeedItDB.sessionAllRows[1]
    equal(row.lootSource, "bonus_roll", "pending variant preserves bonus source")
    equal(row.askable, false, "bonus variant cannot become askable")
    equal(row.itemLink, full, "pending variant preserves full chat link")
end

function tests.pendingOrdinaryVariantPreservesLink()
    local h = fresh(false)
    local generic = "|cff0070dd|Hitem:29004:::::::::::::|h[Generic]|h|r"
    local full = "|cffa335ee|Hitem:29004:::::::::::::|h[Full]|h|r"
    h:addItem(29004, { cacheLoaded = false })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29004, generic, 1, "Otherplayer", "PALADIN")
    h:fireLoot("Otherplayer", full)
    h:runTimers(0, 10)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "ordinary pending variants produce one drop")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].itemLink, full, "ordinary pending variant keeps full link")
end

function tests.pendingChatVariantSurvivesLaterGenericEncounterLink()
    local h = fresh(false)
    local generic = "|cffa335ee|Hitem:29012:::::::::::::|h[Generic Drop]|h|r"
    local full = "|cffa335ee|Hitem:29012::::::::::::1:9999:|h[Detailed Drop]|h|r"
    h:addItem(29012, { cacheLoaded = false })
    h:fireLoot("Otherplayer", full)
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29012, generic, 1, "Otherplayer", "PALADIN")
    h:runTimers(0, 30)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "reversed loot event order still produces one drop")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].itemLink, full, "later generic encounter data cannot downgrade a pending chat variant")
end

function tests.pendingVariantOnlyUpdatesItsOwnLooter()
    local h = fresh(false)
    local generic = "|cffa335ee|Hitem:29008:::::::::::::|h[Shared Drop]|h|r"
    local full = "|cffa335ee|Hitem:29008::::::::::::1:9999:|h[Shared Drop]|h|r"
    h:addItem(29008, { cacheLoaded = false })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29008, generic, 1, "Otherplayer", "PALADIN")
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29008, generic, 1, "Secondplayer", "MAGE")
    h:fireLoot("Otherplayer", full)
    h:runTimers(0, 10)
    local rows = h.env.DoYouNeedItDB.sessionAllRows
    equal(#rows, 2, "both looters retain a pending drop")
    local links = {}
    for _, row in ipairs(rows) do links[row.looter] = row.itemLink end
    equal(links["Otherplayer-Ravencrest"], full, "source looter receives their full item variant")
    equal(links["Secondplayer-Ravencrest"], generic, "another looter keeps their own pending item variant")
end

function tests.pendingVariantMergesWithExistingDestination()
    local h = fresh(false)
    h:setUnit("party3", { name = "Thirdplayer", realm = "Ravencrest", guid = "ThirdGUID", classToken = "MAGE" })
    local generic = "|cffa335ee|Hitem:29012:::::::::::::|h[Shared Drop]|h|r"
    local full = "|cffa335ee|Hitem:29012::::::::::::1:9999:|h[Shared Drop]|h|r"
    h:addItem(29012, { cacheLoaded = false })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29012, generic, 1, "Otherplayer", "PALADIN")
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29012, generic, 1, "Secondplayer", "MAGE")
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29012, full, 1, "Thirdplayer", "MAGE")
    h:fireLoot("Otherplayer", full)
    h:runTimers(0, 10)
    local rows = h.env.DoYouNeedItDB.sessionAllRows
    equal(#rows, 3, "existing source and destination waiters each survive once")
    local links = {}
    for _, row in ipairs(rows) do links[row.looter] = row.itemLink end
    equal(links["Otherplayer-Ravencrest"], full, "moving looter receives their detailed variant")
    equal(links["Secondplayer-Ravencrest"], generic, "remaining source looter retains generic link")
    equal(links["Thirdplayer-Ravencrest"], full, "existing destination looter retains detailed link")
end

function tests.newBonusLootDoesNotRewriteOldHistory()
    local h = fresh(false)
    local item = h:addItem(29005, { name = "Repeated Sword" })
    h:fire("ENCOUNTER_START", 123, "Old Boss")
    h:fireLoot("Otherplayer", item)
    h:fire("ENCOUNTER_END", 123, "Old Boss")
    h:runTimers(10, 100)
    h.now = h.now + 3600
    h:fire("ENCOUNTER_START", 124, "New Boss")
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 2, "new bonus drop creates its own row")
    equal(#h.env.DoYouNeedItDB.history[1].rows, 1, "old history retains its askable drop")
    equal(h.env.DoYouNeedItDB.history[1].allRows[1].lootSource, nil, "old history source is unchanged")
end

function tests.newEncounterSeparatesRecentSameItemBonusLoot()
    local h = fresh(false)
    local item = h:addItem(29006, { name = "Consecutive Boss Sword" })
    h:fire("ENCOUNTER_START", 123, "First Boss")
    h:fireLoot("Otherplayer", item)
    h:fire("ENCOUNTER_END", 123, "First Boss")
    h:runTimers(10, 100)
    h.now = h.now + 20
    h:fire("ENCOUNTER_START", 124, "Second Boss")
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 2, "a new encounter separates otherwise recent identical loot")
    equal(#h.env.DoYouNeedItDB.history[1].rows, 1, "recent prior encounter history is unchanged")
end

function tests.oldSameEncounterLootIsNotReclassified()
    local h = fresh(false)
    local item = h:addItem(29007, { name = "Repeated Later Sword" })
    h:fireLoot("Otherplayer", item)
    h.now = h.now + 121
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 2, "expired source-correlation window preserves separate drops")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].lootSource, nil, "old same-context loot is unchanged")
end

function tests.distinctLaterBonusDropIsNotMerged()
    local h = fresh(false)
    local item = h:addItem(29009, { name = "Repeated Bonus Sword" })
    h:fireBonusLoot("Otherplayer", item)
    h.now = h.now + 20
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 2, "a later confirmed bonus drop creates a separate row")
end

local function variantHarness(loaded)
    local h = fresh(true)
    local generic = "|cffa335ee|Hitem:29010:::::::::::::|h[Generic Neck]|h|r"
    local full = "|cffa335ee|Hitem:29010::::::::::::1:9999:|h[Full Neck]|h|r"
    h:addItem(29010, { equipLoc = "INVTYPE_NECK", classID = 4, subclassID = 0, bindType = 1, itemLevel = 500 })
    local equipped = h:addItem(29011, { equipLoc = "INVTYPE_NECK", classID = 4, subclassID = 0, itemLevel = 500 })
    h:setInventoryLink("party1", "NeckSlot", equipped)
    local getInfo = h.env.C_Item.GetItemInfo
    h.variantLoaded = loaded
    h.env.C_Item.GetItemInfo = function(link)
        if link == full and not h.variantLoaded then return nil end
        local values = { getInfo(link) }
        if link == full then values[4] = 600 end
        return unpack(values, 1, 17)
    end
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 29010, generic, 1, "Otherplayer", "PALADIN")
    equal(h:visibleRows()[1].row.askable, true, "generic variant initially meets equipped comparison")
    return h, full
end

function tests.detailedVariantRevalidatesItemLevelAndAutoSend()
    local h, full = variantHarness(true)
    for index, timer in ipairs(h.timers) do
        if timer.delay == 5 then table.remove(h.timers, index).callback(); break end
    end
    h:fireLoot("Otherplayer", full)
    local row = h:visibleRows()[1].row
    equal(row.itemLevel, 600, "detailed variant replaces generic item level")
    equal(row.askable, false, "higher detailed variant loses Ask")
    equal(row.tradeStatusKey, "trade_unknown", "higher detailed variant loses likely transfer claim")
    h:runTimers(5, 100)
    equal(#h.sentMessages, 0, "detailed variant cancels an already deferred automatic send")
end

function tests.unloadedDetailedVariantCannotUseOldComparison()
    local h, full = variantHarness(false)
    h:fireLoot("Otherplayer", full)
    equal(h:visibleRows()[1].row.askable, false, "unloaded detailed variant immediately loses stale Ask")
    equal(h:visibleRows()[1].row.itemLevel, nil, "unloaded detailed variant cannot retain generic level")
    h.variantLoaded = true
    h:runTimers(5, 100)
    equal(h:visibleRows()[1].row.itemLevel, 600, "detailed variant recovers when metadata loads")
    equal(h:visibleRows()[1].row.askable, false, "loaded higher variant remains review only")
    equal(#h.sentMessages, 0, "pending auto sends never use old variant evidence")
end

function tests.clearInvalidatesDetailedMetadataRecovery()
    local h, full = variantHarness(false)
    h:fireLoot("Otherplayer", full)
    local row = h:visibleRows()[1].row
    h:slash("clear")
    h.variantLoaded = true
    h:runTimers(5, 100)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 0, "late variant metadata cannot restore cleared loot")
    equal(row.itemLevel, nil, "cleared row rejects stale metadata callbacks")
    equal(#h.sentMessages, 0, "cleared metadata recovery cannot start a whisper")
end

local failed = 0
for name, test in pairs(tests) do
    local ok, failure = pcall(test)
    if ok then
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(failure))
    end
end
if failed > 0 then error(tostring(failed) .. " loot lifecycle regressions failed") end
print("Runtime loot lifecycle regressions passed")
