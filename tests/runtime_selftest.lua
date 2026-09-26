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

local tests = {}

function tests.selftestSlashRunsOutOfCombatAndPersistsCompactReport()
    local h = fresh()
    h:slash("selftest")
    local lines = exportLines(h)
    truthy(#lines >= 5, "selftest prints a multi-line machine-readable block")
    for _, line in ipairs(lines) do
        truthy(#line <= 210, "export line stays within chat limits")
        truthy(line:find("=", 1, true), "export line carries key=value payload")
    end
    truthy(hasMessage(h, "DYNI1: v=1"), "export block carries the versioned prefix")
    truthy(hasMessage(h, "DYNI1: nocheck="), "export block honestly lists uncovered areas")
    truthy(hasMessage(h, "NOT checked"), "human summary states what was not verified")
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

function tests.selftestSlashRefusesInCombatWithoutPersisting()
    local h = fresh()
    h.env.InCombatLockdown = function() return true end
    h:slash("selftest")
    truthy(hasMessage(h, "out-of-combat"), "combat run refuses with a clear reason")
    equal(#exportLines(h), 0, "refused run prints no export block")
    equal(h.env.DoYouNeedItSelfTest, nil, "refused run persists nothing")
end

function tests.selftestLeavesDebugOffDiagnosticsPurged()
    local h = fresh()
    h:slash("selftest")
    equal(h.env.DoYouNeedItDB.diagnostics, nil, "selftest never persists diagnostics while debug is off")
    h:resetSideEffects()
    h:slash("diag")
    truthy(hasMessage(h, "diagnostics are off"), "diag still reports off after a selftest run")
    h:slash("debug on")
    h:slash("debug off")
    equal(h.env.DoYouNeedItDB.diagnostics, nil, "debug off still purges saved diagnostics after selftest")
end

function tests.selftestStopDiscardsStoredReport()
    local h = fresh()
    h:slash("selftest")
    truthy(h.env.DoYouNeedItSelfTest ~= nil, "run stores a report first")
    h:resetSideEffects()
    h:slash("selftest stop")
    equal(h.env.DoYouNeedItSelfTest, nil, "stop discards the stored report")
    truthy(hasMessage(h, "stopped"), "stop confirms the discard")
end

function tests.selftestStageSummaryCountsWithoutPayload()
    local h = fresh()
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
    truthy(hasMessage(h, "/dyni selftest") == false, "selftest run does not spam the command help")
end

local failed = 0
for name, test in pairs(tests) do
    local ok, failure = pcall(test)
    if ok then print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(failure)) end
end
if failed > 0 then error(tostring(failed) .. " runtime selftest checks failed") end
print("Runtime selftest checks passed")
