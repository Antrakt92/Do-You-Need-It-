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

function tests.repeatedDelayedBonusEventUsesSourceConfirmationTime()
    local h = fresh(false)
    local item = h:addItem(31301, { name = "Delayed Bonus Sword" })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 31301, item, 1, "Otherplayer", "PALADIN")
    h.now = h.now + 20
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "delayed source upgrades its initial encounter row")
    h.now = h.now + 1
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "repeated source event dedupes from source confirmation time")
    h.now = h.now + 20
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 2, "genuinely later confirmed bonus drop remains separate")
end

function tests.automaticWhisperCancelsWhenLooterLeaves()
    local h = fresh(true)
    local item = h:addItem(31302, { name = "Departed Looter Sword" })
    h:fireLoot("Otherplayer", item)
    h:removeUnit("party1")
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(5, 100)
    equal(#h.sentMessages, 0, "automatic send cancels after its looter leaves the roster")
end

function tests.deferredAutomaticWhisperRechecksRosterAtSendBoundary()
    local h = fresh(true)
    local item = h:addItem(31303, { name = "Deferred Departed Sword" })
    h:fireLoot("Otherplayer", item)
    for index, timer in ipairs(h.timers) do
        if timer.delay == 5 then table.remove(h.timers, index).callback(); break end
    end
    equal(h:visibleRows()[1].row.whisperInFlight, true, "auto send reached its zero-delay boundary")
    h:removeUnit("party1")
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(0, 20)
    equal(#h.sentMessages, 0, "deferred automatic send revalidates its looter immediately before chat")
end

function tests.rosterSlotReuseCannotSendToDepartedLooter()
    local h = fresh(true)
    local item = h:addItem(31304, { name = "Reused Roster Slot Sword" })
    h:fireLoot("Otherplayer", item)
    h:setUnit("party1", { name = "Replacement", realm = "Ravencrest", guid = "ReplacementGUID" })
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(5, 100)
    equal(#h.sentMessages, 0, "same party token occupied by another person does not keep an automatic send valid")
end

function tests.encounterDuplicateAfterDelayedBonusCannotRestoreAsk()
    local h = fresh(false)
    local item = h:addItem(31305, { name = "Cross Source Delayed Bonus" })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 31305, item, 1, "Otherplayer", "PALADIN")
    h.now = h.now + 20
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "delayed bonus source upgrades the existing drop")
    equal(#h.env.DoYouNeedItDB.sessionRows, 0, "bonus classification removes Ask")
    h.now = h.now + 1
    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 31305, item, 1, "Otherplayer", "PALADIN")
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 1, "another event source shares bonus confirmation dedupe")
    equal(#h.env.DoYouNeedItDB.sessionRows, 0, "repeated encounter event cannot restore Ask for bonus loot")
    h.now = h.now + 20
    h:fireBonusLoot("Otherplayer", item)
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 2, "later genuine bonus drop remains separate")
end

local failed = 0
for name, test in pairs(tests) do
    local ok, failure = pcall(test)
    if ok then print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(failure)) end
end
if failed > 0 then error(tostring(failed) .. " runtime policy regressions failed") end
print("Runtime policy regressions passed")
