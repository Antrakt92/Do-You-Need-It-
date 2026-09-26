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

function tests.rosterUpdateProactivelyCancelsDepartedAutoWhisper()
    local h = fresh(true)
    local item = h:addItem(31306, { name = "Proactive Departed Sword" })
    h:fireLoot("Otherplayer", item)
    local row = h:visibleRows()[1].row
    equal(row.statusKey, "auto_pending", "auto send is pending before departure")
    h:removeUnit("party1")
    h:fire("GROUP_ROSTER_UPDATE")
    equal(row.statusKey, "candidate", "departure proactively clears pending auto status")
    equal(row.pendingAutoWhisper or false, false, "departure proactively clears pending auto flag")
    h:runTimers(10, 100)
    equal(#h.sentMessages, 0, "proactively cancelled auto never sends")
end

-- Task 1: a manual Ask fired inside the pacing gap of a fresh automatic
-- dispatch waits out the remainder instead of bursting.
function tests.manualAskRightAfterAutoSendWaitsForGap()
    local h = fresh(true)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31401, { name = "Auto Gap Sword" }))
    h:runTimers(5, 10)
    h:runTimers(0, 10)
    equal(#h.sentMessages, 1, "automatic whisper sends first")
    h:fireLoot("Secondplayer", h:addItem(31402, { name = "Manual Gap Sword" }))
    local manualFrame = nil
    for _, frame in ipairs(h:visibleRows()) do
        if frame.row.looter:find("Secondplayer", 1, true) then
            manualFrame = frame
        end
    end
    if manualFrame == nil then
        error("manual gap row is not visible")
    end
    manualFrame.whisper:FireScript("OnClick")
    h:runTimers(0, 10)
    equal(#h.sentMessages, 1, "manual Ask right after an automatic send waits out the pacing gap")
    h.now = h.now + 2
    h:runTimers(3, 10)
    equal(#h.sentMessages, 2, "deferred manual Ask sends after the gap")
    equal(h.sentMessages[2].target, manualFrame.row.looter, "deferred manual Ask still targets its own looter")
end

-- Task 1 (documented deviation): same-tick manual streaks without prior
-- automatic traffic still reach chat immediately; the frozen loot gate pins
-- triple-same-tick delivery, so manual-manual pacing stays with the
-- chat-throttle backstop instead of deferring.
function tests.twoManualAsksWithoutPriorAutoSendImmediately()
    local h = fresh(false)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31403, { name = "Manual First Sword" }))
    h:fireLoot("Secondplayer", h:addItem(31404, { name = "Manual Second Sword" }))
    for _, frame in ipairs(h:visibleRows()) do
        frame.whisper:FireScript("OnClick")
    end
    h:runTimers(0, 10)
    equal(#h.sentMessages, 2, "manual streak without prior automatic traffic still reaches chat immediately")
    for _, frame in ipairs(h:visibleRows()) do
        equal(frame.row.statusKey, "sent", "unthrottled manual pair reports sent")
    end
end

-- Task 2: pump with no trustworthy clock re-arms instead of dispatching.
function tests.pumpWithUntrustworthyClockRearmsWithoutDispatch()
    local h = fresh(true)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31405, { name = "Clockless Sword" }))
    h.env.GetServerTime = function() return h:secretValue("clock") end
    h.env.time = function() return h:secretValue("clock-fallback") end
    h:runTimers(5, 10)
    equal(#h.sentMessages, 0, "pump without trustworthy time never dispatches")
    equal(h:visibleRows()[1].row.pendingAutoWhisper, true, "fail-closed pump keeps the queued automatic row")
    if #h.timers == 0 then
        error("fail-closed pump must re-arm itself")
    end
    h.env.GetServerTime = function() return h.now end
    h.env.time = function() return h.now end
    h.now = h.now + 6
    h:runTimers(6, 10)
    h:runTimers(0, 10)
    equal(#h.sentMessages, 1, "restored clock lets the preserved row send")
end

-- Task 6b: a secret-tagged clock never persists as diagnostic time; the
-- clean fallback clock is stored instead.
function tests.secretClockFallsBackToCleanTimeForDiagnostics()
    local h = Harness.new({ db = { settings = { autoWhisper = false, autoDelay = 5, debug = true } } })
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    h.env.GetServerTime = function() return h:secretValue("clock") end
    h:slash("scan")
    local found = nil
    for _, entry in ipairs(h.env.DoYouNeedItDB.diagnostics or {}) do
        if entry.stage == "scan_queued" then
            found = entry
            break
        end
    end
    if found == nil then
        error("scan_queued diagnostic is missing")
    end
    equal(type(found.at), "number", "secret clock never persists as diagnostic time")
    equal(found.at, h.now, "secret clock falls back to the clean clock")
end

-- Task 6a: SaveDB sweeps secret-tagged fields from persisted rows. The
-- harness secret detector is pointed at a plain sentinel string (swapped
-- before load, as the addon captures it at load): the sentinel survives
-- the type-checked snapshot, so only the main-side sweep can remove it.
function tests.saveDBClearsSecretTaggedRowFields()
    local h = Harness.new({ db = { settings = { autoWhisper = false, autoDelay = 5 } } })
    h.env.issecretvalue = function(value) return value == "POISON-ENCOUNTER" end
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    h:fireLoot("Otherplayer", h:addItem(31410, { name = "Sweep Sword" }))
    local row = h:visibleRows()[1].row
    row.encounterName = "POISON-ENCOUNTER"
    h:fire("PLAYER_LOGOUT")
    local function containsPoison(value, depth)
        if value == "POISON-ENCOUNTER" then
            return true
        end
        if type(value) == "table" and (depth or 0) < 3 then
            for _, nested in pairs(value) do
                if containsPoison(nested, (depth or 0) + 1) then
                    return true
                end
            end
        end
        return false
    end
    equal(containsPoison(h.env.DoYouNeedItDB), false, "SaveDB sweeps secret-tagged fields from persisted rows")
end

-- Task 3: reload preserves retryable semantics through statusKey alone.
-- (whisperRetryable writes are intentionally kept: the frozen loot gate
-- asserts the in-memory flag, which Core cannot persist without touching
-- the forbidden Core.lua.)
function tests.reloadKeepsWhisperFailedRetryableViaStatusKey()
    local h = fresh(false)
    h.failWhisper = true
    h:fireLoot("Otherplayer", h:addItem(31420, { name = "Failed Reload Sword" }))
    h:visibleRows()[1].whisper:FireScript("OnClick")
    h:runTimers(0, 10)
    equal(h:visibleRows()[1].row.statusKey, "whisper_failed", "failed manual Ask stores a stable failure status")
    h.failWhisper = false
    h:fire("PLAYER_LOGOUT")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "whisper_failed", "failure status persists across save")
    local h2 = Harness.new({ db = h.env.DoYouNeedItDB })
    h2:loadAddon()
    local found = nil
    local function scanRows(list)
        for _, candidate in ipairs(type(list) == "table" and list or {}) do
            if type(candidate) == "table" and candidate.statusKey == "whisper_failed" then
                found = candidate
            end
        end
    end
    scanRows(h2.env.DoYouNeedItDB.sessionAllRows)
    scanRows(h2.env.DoYouNeedItDB.sessionRows)
    for _, group in ipairs(h2.env.DoYouNeedItDB.history or {}) do
        if type(group) == "table" then
            scanRows(group.rows)
            scanRows(group.allRows)
        end
    end
    if found == nil then
        error("whisper_failed row is missing after reload")
    end
    local state = h2.env.DoYouNeedItCore.GetWhisperButtonState(nil, "current", found)
    equal(state.visible, true, "reloaded failure keeps Ask visible")
    equal(state.enabled, true, "reloaded failure keeps Ask retry enabled")
end

-- Task 4: INSPECT_READY in combat completes the row without errors and keeps
-- the deferred automatic whisper armed. Behavior is intentionally unchanged;
-- the test pins the combat decision documented on CompleteActiveInspectRequest.
function tests.inspectReadyInCombatCompletesRowAndKeepsAutoPending()
    local h = fresh(true)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31430, { name = "Combat Ready Sword" }))
    h:runTimers(0, 10)
    equal(#h.notifyInspectCalls, 1, "inspect starts out of combat")
    local row = h:visibleRows()[1].row
    equal(row.statusKey, "auto_pending", "automatic whisper is armed before combat")
    h.env.InCombatLockdown = function() return true end
    h:fire("INSPECT_READY", "PartyGUID1")
    equal(row.inspectPending, false, "INSPECT_READY in combat still completes the row")
    equal(row.pendingAutoWhisper, true, "combat completion keeps the deferred automatic whisper armed")
    equal(row.statusKey, "auto_pending", "combat completion preserves pending auto status")
end

-- Task 7: departed full names cancel short-stored pending rows.
function tests.departedShortNameCancelsPendingAuto()
    local h = fresh(true)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31440, { name = "Short Departed Sword" }))
    local row = h:visibleRows()[1].row
    equal(row.statusKey, "auto_pending", "auto send is pending before departure")
    row.looter = "Otherplayer"
    h:removeUnit("party1")
    h:fire("GROUP_ROSTER_UPDATE")
    equal(row.statusKey, "candidate", "departed full name cancels short-stored pending auto immediately")
    equal(row.pendingAutoWhisper or false, false, "departed full name clears short-stored pending flag")
    h:runTimers(10, 100)
    equal(#h.sentMessages, 0, "short-matched cancelled auto never sends")
end

-- Task 7: queue purge evicts the departed row but keeps the survivor sendable.
function tests.departedQueuePurgeKeepsSurvivorAutoSend()
    local h = fresh(true)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31441, { name = "Purged Departed Sword" }))
    h:fireLoot("Secondplayer", h:addItem(31442, { name = "Survivor Sword" }))
    h:removeUnit("party1")
    h:fire("GROUP_ROSTER_UPDATE")
    h.now = h.now + 6
    h:runTimers(6, 20)
    h:runTimers(0, 20)
    equal(#h.sentMessages, 1, "only the surviving looter sends after a departure purge")
    if not h.sentMessages[1].target:find("Secondplayer", 1, true) then
        error("survivor send went to " .. tostring(h.sentMessages[1].target))
    end
end

-- Task 8: a send wedged in-flight past the watchdog fails retryable.
function tests.stalledInFlightFailsRetryableAfterWatchdog()
    local h = fresh(true)
    h:stubRandom(0)
    h:slash("debug on")
    h:fireLoot("Otherplayer", h:addItem(31450, { name = "Stalled Auto Sword" }))
    h:fireLoot("Secondplayer", h:addItem(31451, { name = "Stalled Manual Sword" }))
    local rowA, rowB = nil, nil
    for _, frame in ipairs(h:visibleRows()) do
        if frame.row.looter:find("Otherplayer", 1, true) then
            rowA = frame.row
        elseif frame.row.looter:find("Secondplayer", 1, true) then
            rowB = frame.row
        end
    end
    if rowA == nil or rowB == nil then
        error("stalled rows are not visible")
    end
    rowA.whisperInFlight = true
    rowA.dispatchStartedAt = h.now
    rowB.whisperInFlight = true
    rowB.dispatchStartedAt = h.now
    h.now = h.now + 11
    h:runTimers(6, 20)
    equal(rowA.statusKey, "whisper_failed", "stalled automatic send fails retryable after the watchdog")
    equal(rowB.statusKey, "whisper_failed", "stalled manual send fails retryable after the watchdog")
    equal(#h.sentMessages, 0, "watchdog frees wedged rows without sending")
    local stalled = false
    for _, entry in ipairs(h.env.DoYouNeedItDB.diagnostics or {}) do
        if entry.stage == "whisper_stalled" then
            stalled = true
        end
    end
    equal(stalled, true, "watchdog records a whisper_stalled diagnostic")
end

-- Task 9: throttle edges. A pair spaced past the repeat window both sends;
-- four same-tick clicks send, send, fail retryable, send (the streak resets
-- on the third, so the fourth is accepted again).
function tests.spacedManualPairBothSend()
    local h = fresh(false)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31460, { name = "Spaced First Sword" }))
    h:visibleRows()[1].whisper:FireScript("OnClick")
    h:runTimers(0, 10)
    h.now = h.now + 1
    h:fireLoot("Secondplayer", h:addItem(31461, { name = "Spaced Second Sword" }))
    local secondFrame = nil
    for _, frame in ipairs(h:visibleRows()) do
        if frame.row.looter:find("Secondplayer", 1, true) then
            secondFrame = frame
        end
    end
    if secondFrame == nil then
        error("spaced second row is not visible")
    end
    secondFrame.whisper:FireScript("OnClick")
    h:runTimers(0, 10)
    equal(#h.sentMessages, 2, "manual pair spaced past the repeat window both send")
    for _, frame in ipairs(h:visibleRows()) do
        equal(frame.row.statusKey, "sent", "spaced manual pair reports sent")
    end
end

function tests.fourthSameTickClickSendsAfterThirdFails()
    local h = fresh(false)
    h:stubRandom(0)
    h:fireLoot("Otherplayer", h:addItem(31462, { name = "Burst One Sword" }))
    h:fireLoot("Secondplayer", h:addItem(31463, { name = "Burst Two Sword" }))
    h:fireLoot("Thirdplayer", h:addItem(31464, { name = "Burst Three Sword" }))
    h:fireLoot("Fourthplayer", h:addItem(31465, { name = "Burst Four Sword" }))
    local frames = h:visibleRows()
    equal(#frames, 4, "four manual asks start in the same tick")
    for _, frame in ipairs(frames) do
        frame.whisper:FireScript("OnClick")
    end
    h:runTimers(0, 10)
    equal(#h.sentMessages, 4, "every same-tick repeat still reaches the chat API")
    local sent, failed = 0, 0
    local failedFrame = nil
    for _, frame in ipairs(frames) do
        if frame.row.statusKey == "sent" then
            sent = sent + 1
        elseif frame.row.statusKey == "whisper_failed" then
            failed = failed + 1
            failedFrame = frame
        end
    end
    equal(sent, 3, "three of four same-tick repeats are accepted")
    equal(failed, 1, "third same-tick repeat is suspected throttling")
    if failedFrame == nil then
        error("throttled frame is missing")
    end
    equal(failedFrame.row.manualWhispered, nil, "suspected throttling never marks the row sent")
    equal(failedFrame.whisper:IsEnabled(), true, "suspected throttling leaves Ask enabled")
end

local failed = 0
for name, test in pairs(tests) do
    local ok, failure = pcall(test)
    if ok then print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(failure)) end
end
if failed > 0 then error(tostring(failed) .. " runtime policy regressions failed") end
print("Runtime policy regressions passed")
