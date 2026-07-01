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
    h.notifyInspectCalls = {}
    h.clearInspectCalls = 0
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

local function fireLoot(h, looterName, itemLink)
    h:fire("CHAT_MSG_LOOT", looterName .. " receives loot: " .. itemLink .. ".")
end

local function testDifferentGuidLootInspectsAreSerialized()
    local h = newLoadedHarness()
    local first = addWeapon(h, 21001, "First Sword")
    local second = addWeapon(h, 21002, "Second Sword")

    fireLoot(h, "Otherplayer", first)
    fireLoot(h, "Secondplayer", second)

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

    fireLoot(h, "Otherplayer", first)
    fireLoot(h, "Otherplayer", second)
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

    fireLoot(h, "Otherplayer", item)
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
    h.notifyInspectCalls = {}
    h.clearInspectCalls = 0
    h:setInventoryLink("party1", "MainHandSlot", nil)

    local item = addWeapon(h, 21006, "Cached Drop Sword")
    fireLoot(h, "Otherplayer", item)
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "cached fallback row is visible")
    assertTruthy(rows[1].row.equippedText:find("Cached: ", 1, true), "loot row uses cached equipped fallback before live ready")
    assertTruthy(rows[1].row.equippedText:find("Cached Worn Sword", 1, true), "cached equipped item is preserved")
    h:runNextTimer(0.8)
    assertTruthy(rows[1].row.equippedText:find("Cached Worn Sword", 1, true), "cached equipped fallback survives timeout")
end

testDifferentGuidLootInspectsAreSerialized()
testSameGuidLootInspectsCoalesce()
testInspectTimeoutClearsOwnedInspectState()
testCachedFallbackSurvivesLiveInspectFailure()

print("runtime inspect ok")
