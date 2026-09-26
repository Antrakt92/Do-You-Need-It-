local Harness = dofile("tests/runtime_harness.lua")

local function equal(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function truthy(value, message)
    if not value then
        error(message .. ": expected truthy, got " .. tostring(value), 2)
    end
end

local function fresh()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    return h
end

local function withPopup(h)
    h.env.StaticPopupDialogs = {}
    h.popupShown = {}
    h.env.StaticPopup_Show = function(name)
        h.popupShown[#h.popupShown + 1] = name
        return {}
    end
end

local function copyDialog(h)
    local dialogs = h.env.StaticPopupDialogs
    truthy(type(dialogs) == "table", "popup table exists after show")
    local dialog = dialogs["DOYOUNEED_SELFTEST_COPY"]
    truthy(type(dialog) == "table", "copy dialog is registered")
    return dialog
end

local function dialogText(h)
    local dialog = copyDialog(h)
    local box = h:newFrame("EditBox")
    dialog.OnShow({ editBox = box })
    return box:GetText()
end

local function exportLines(h)
    local lines = {}
    for _, message in ipairs(h.messages) do
        if message:find("DYNI1:", 1, true) then
            lines[#lines + 1] = message
        end
    end
    return lines
end

local function hasMessage(h, needle)
    for _, message in ipairs(h.messages) do
        if message:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function slashGlobals(h)
    local found = {}
    for key in pairs(h.env) do
        if type(key) == "string" and key:find("^SLASH_") then
            found[#found + 1] = key
        end
    end
    table.sort(found)
    return found
end

local function frameTextPresent(h, needle)
    for _, frame in ipairs(h.frames) do
        if type(frame.text) == "string" and frame.text:find(needle, 1, true) then
            return true
        end
    end
    return false
end

local function dbHasTestRows(h)
    local seen, found = {}, false
    local function scan(value, depth)
        if found or depth > 6 or type(value) ~= "table" or seen[value] then
            return
        end
        seen[value] = true
        if value.isTest == true then
            found = true
            return
        end
        for _, child in pairs(value) do
            scan(child, depth + 1)
        end
    end
    scan(h.env.DoYouNeedItDB, 0)
    return found
end

local tests = {}

function tests.selftestSlashOpensCopyWindowAndKeepsChatSlim()
    local h = fresh()
    withPopup(h)
    h:slash("selftest")
    equal(#h.popupShown, 1, "run opens the copy window once")
    equal(h.popupShown[1], "DOYOUNEED_SELFTEST_COPY", "run opens the canonical copy dialog")
    equal(#h.messages, 7, "chat stays slim when the copy window opens")
    equal(#exportLines(h), 0, "full export block leaves chat for the copy window")
    truthy(hasMessage(h, "NOT checked"), "human summary states what was not verified")
    truthy(hasMessage(h, "copy window opened"), "chat points at the copy window")
    truthy(hasMessage(h, "/dyni selftest show"), "chat advertises the re-show command")
    truthy(hasMessage(h, "demo rows=4 rendered=4"), "chat reports the demo render verdict")
    local saved = h.env.DoYouNeedItSelfTest
    equal(type(saved), "table", "selftest persists one report table")
    equal(saved.version, 1, "stored report carries version 1")
    equal(type(saved.finishedAt), "number", "stored report carries a numeric finish stamp")
    equal(saved.finishedAt, 1000, "stored finish stamp uses the clean clock")
    equal(type(saved.report), "table", "stored report carries a report section")
    equal(saved.report.build, h.env.DoYouNeedItCore.VERSION, "report build matches the core version")
    equal(saved.report.group, "party", "default harness context reports a party")
    equal(saved.report.roster, 5, "default harness context counts the five roster units")
    local reportKeys = 0
    for _ in pairs(saved.report) do reportKeys = reportKeys + 1 end
    truthy(reportKeys <= 30, "stored report stays capped in size")
end

function tests.selftestCopyDialogCarriesFullExportPayload()
    local h = fresh()
    withPopup(h)
    h:slash("selftest")
    local dialog = copyDialog(h)
    equal(dialog.hasEditBox, true, "copy dialog provides an edit box")
    equal(dialog.hideOnEscape, true, "copy dialog closes with Escape")
    equal(dialog.editBoxWidth, 320, "copy dialog uses a wide edit box")
    local text = dialogText(h)
    truthy(text:find("DYNI1: v=1", 1, true), "copy text carries the versioned prefix")
    truthy(text:find("DYNI1: nocheck=", 1, true), "copy text honestly lists uncovered areas")
    local textLines = 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        textLines = textLines + 1
        truthy(#line <= 185, "copy text lines stay copy-friendly")
        truthy(line:find("=", 1, true), "copy text lines carry key=value payload")
    end
    truthy(text:find("DYNI1: demo rows=4 rendered=4", 1, true), "copy text carries the demo verdict")
    truthy(textLines >= 7, "copy text carries the full export block")
    dialog.OnShow({})
    equal(dialog.OnShow ~= nil, true, "dialog show handler tolerates a missing edit box")
end

function tests.selftestFallsBackToChatWithoutPopupApi()
    local h = fresh()
    h:slash("selftest")
    local lines = exportLines(h)
    truthy(#lines >= 6, "fallback prints the full export block to chat")
    for _, line in ipairs(lines) do
        truthy(line:find("=", 1, true), "fallback lines carry key=value payload")
    end
    truthy(hasMessage(h, "DYNI1: v=1"), "fallback keeps the versioned prefix")
    truthy(hasMessage(h, "copy window unavailable"), "fallback explains the missing window")
end

function tests.selftestSlashRefusesInCombatWithoutPersisting()
    local h = fresh()
    withPopup(h)
    h.env.InCombatLockdown = function() return true end
    h:slash("selftest")
    truthy(hasMessage(h, "out-of-combat"), "combat run refuses with a clear reason")
    equal(#h.popupShown, 0, "refused run opens no window")
    equal(h.env.DoYouNeedItSelfTest, nil, "refused run persists nothing")
    equal(h.env.DoYouNeedItFrame:IsShown(), false, "refused run never shows the loot window")
end

function tests.selftestDemoPhaseRendersRealRowsAndCleansUp()
    local h = fresh()
    withPopup(h)
    h:slash("selftest")
    local demo = h.env.DoYouNeedItSelfTest.report.demo
    equal(type(demo), "table", "report carries a demo section")
    equal(demo.rows, 4, "demo builds four isolated rows")
    equal(demo.rendered, 4, "demo renders every built row through the real layout")
    equal(demo.cleaned, true, "demo phase reports a clean teardown")
    equal(demo.untouched, true, "demo phase reports live state untouched")
    truthy(frameTextPresent(h, "Тестовый меч"), "cyrillic item name passes through the real render")
    truthy(frameTextPresent(h, "Демолутер"), "cyrillic looter name passes through the real render")
    truthy(frameTextPresent(h, "Demo Long Link Item"), "long link row passes through the real render")
    equal(#h:visibleRows(), 0, "cleanup restores an empty current view")
    equal(h.env.DoYouNeedItFrame:IsShown(), false, "cleanup restores the hidden window")
end

function tests.selftestDemoPhaseLeavesLiveStateUntouched()
    local h = fresh()
    withPopup(h)
    h:slash("selftest")
    equal(dbHasTestRows(h), false, "saved state never stores demo rows")
    equal(#h.sentMessages, 0, "demo rows never queue whispers")
    equal(#h.timers, 0, "demo phase schedules no timers")
    equal(#h:visibleRows(), 0, "no demo row survives cleanup")
end

function tests.selftestShowDefersCopyWindowUntilCombatEnds()
    local h = fresh()
    withPopup(h)
    local combat = false
    h.env.InCombatLockdown = function() return combat end
    h:slash("selftest")
    equal(#h.popupShown, 1, "initial run opens the copy window")
    combat = true
    h:resetSideEffects()
    h:slash("selftest show")
    truthy(hasMessage(h, "deferred until combat ends"), "combat show defers with a clear reason")
    equal(#h.popupShown, 1, "deferred show opens no window yet")
    combat = false
    h:fire("PLAYER_REGEN_ENABLED")
    equal(#h.popupShown, 2, "combat exit opens the deferred copy window")
    truthy(hasMessage(h, "copy window opened"), "deferred window announces itself")
end

function tests.selftestShowWithoutReportPrintsHint()
    local h = fresh()
    withPopup(h)
    h:slash("selftest show")
    truthy(hasMessage(h, "no stored report"), "show without a report explains itself")
    equal(#h.popupShown, 0, "show without a report opens no window")
end

function tests.selftestShowReshowsWithoutRerunning()
    local h = fresh()
    withPopup(h)
    h:slash("selftest")
    local firstStamp = h.env.DoYouNeedItSelfTest.finishedAt
    h:resetSideEffects()
    h.popupShown = {}
    h:slash("selftest show")
    equal(#h.popupShown, 1, "show reopens the copy window")
    equal(h.env.DoYouNeedItSelfTest.finishedAt, firstStamp, "show does not rerun collection")
    truthy(hasMessage(h, "copy window opened"), "reshow announces itself")
    equal(hasMessage(h, "NOT checked"), false, "reshow stays quiet apart from the window hint")
end

function tests.selftestLeavesDebugOffDiagnosticsPurged()
    local h = fresh()
    withPopup(h)
    h:slash("selftest")
    equal(h.env.DoYouNeedItDB.diagnostics, nil, "selftest never persists diagnostics while debug is off")
    h:resetSideEffects()
    h:slash("diag")
    truthy(hasMessage(h, "diagnostics are off"), "diag still reports off after a selftest run")
    h:slash("debug on")
    h:slash("debug off")
    equal(h.env.DoYouNeedItDB.diagnostics, nil, "debug off still purges saved diagnostics after selftest")
end

function tests.selftestStopDiscardsStoredReportAndPendingWindow()
    local h = fresh()
    withPopup(h)
    local combat = false
    h.env.InCombatLockdown = function() return combat end
    h:slash("selftest")
    truthy(h.env.DoYouNeedItSelfTest ~= nil, "run stores a report first")
    combat = true
    h:slash("selftest show")
    truthy(hasMessage(h, "deferred until combat ends"), "window deferral is armed first")
    h:slash("selftest stop")
    equal(h.env.DoYouNeedItSelfTest, nil, "stop discards the stored report")
    truthy(hasMessage(h, "stopped"), "stop confirms the discard")
    combat = false
    local shownBefore = #h.popupShown
    h:fire("PLAYER_REGEN_ENABLED")
    equal(#h.popupShown, shownBefore, "stop cancels the deferred window")
end

function tests.selftestStageSummaryCountsWithoutPayload()
    local h = fresh()
    withPopup(h)
    h:slash("debug on")
    h:resetSideEffects()
    local item = h:addItem(31801, { name = "Selftest Stage Sword" })
    h:fireLoot("Otherplayer", item)
    h:runTimers(10, 100)
    h:slash("selftest")
    local saved = h.env.DoYouNeedItSelfTest
    truthy(saved ~= nil, "selftest stores a report after loot diagnostics")
    local stages = saved.report.stages
    equal(type(stages), "table", "report carries a stage summary table")
    local counted, stageKeys = 0, 0
    for stage, count in pairs(stages) do
        stageKeys = stageKeys + 1
        equal(type(stage), "string", "stage summary keys are names only")
        equal(type(count), "number", "stage summary values are counts only")
        counted = counted + count
    end
    truthy(stageKeys <= 25, "stage summary stays capped")
    equal(counted, saved.report.diagN, "stage counts add up to the buffer size")
    equal(saved.report.itemLink, nil, "stage summary carries no loot payload")
    equal(saved.report.looter, nil, "stage summary carries no looter payload")
    local text = dialogText(h)
    truthy(text:find("DYNI1: stages", 1, true), "copy text carries the stage summary")
end

function tests.selftestAddsNoSlashCommandGlobals()
    local h = fresh()
    local before = slashGlobals(h)
    equal(#before, 1, "one canonical slash global exists before selftest")
    equal(before[1], "SLASH_DOYOUNEEDIT1", "canonical slash global is intact before selftest")
    h:slash("selftest")
    local after = slashGlobals(h)
    equal(#after, 1, "selftest adds no slash globals")
    equal(after[1], "SLASH_DOYOUNEEDIT1", "canonical slash global is intact after selftest")
    equal(h.env.SlashCmdList.DOYOUNEEDIT2, nil, "no second slash handler is registered")
    truthy(hasMessage(h, "/dyni selftest show"), "selftest run advertises the re-show command")
end

local failed = 0
for name, test in pairs(tests) do
    local ok, failure = pcall(test)
    if ok then print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(failure)) end
end
if failed > 0 then error(tostring(failed) .. " runtime selftest checks failed") end
print("Runtime selftest checks passed")
