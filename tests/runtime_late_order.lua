local Harness = dofile("tests/runtime_harness.lua")
dofile("DoYouNeedIt_Core.lua")
local Core = DoYouNeedItCore
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function ids(rows)
    local result = {}; for _, row in ipairs(rows) do result[#result + 1] = row.id end
    return table.concat(result, ",")
end
local function row(id, stamp, askable)
    return { id = id, timestamp = stamp, looter = "Other-Realm", itemID = 55100,
        itemLink = "|Hitem:55100:::::::::1:23:|h[Variant]|h", instanceName = "Raid", encounterName = "Boss A", askable = askable }
end
local state = Core.CreateState({maxSessionRows = 2})
local newer1 = Core.AddVisibleRow(state, row("newer1", 1001), true)
local newer2 = Core.AddVisibleRow(state, row("newer2", 1002), true)
local late = Core.AddVisibleRow(state, row("old-late", 1000), true)
check(ids(state.allRows) == "old-late,newer1,newer2", "current all-gear follows loot chronology")
check(ids(state.currentRows) == "old-late,newer1,newer2", "current askable follows loot chronology")
check(ids(state.sessionAllRows) == "newer1,newer2", "late oldest does not evict newer session gear")
check(ids(state.sessionRows) == "newer1,newer2", "late oldest does not evict newer session Ask rows")
check(state.allRows[1] == late and state.allRows[2] == newer1, "ordering preserves live row aliases")
Core.CompleteCurrentGroup(state, {instanceName = "Raid", encounterName = "Boss A", endedAt = 1003, mergeWindow = 120})
check(ids(state.history[1].allRows) == "newer1,newer2", "completion caps newest all-gear rows")
check(ids(state.history[1].rows) == "newer1,newer2", "completion caps newest Ask rows")
Core.AddVisibleRow(state, row("even-older-late", 999), true)
Core.CompleteCurrentGroup(state, {instanceName = "Raid", encounterName = "Boss A", endedAt = 1003, mergeWindow = 120})
check(ids(state.history[1].allRows) == "newer1,newer2", "late history merge cannot evict newer gear")
check(ids(state.history[1].rows) == "newer1,newer2", "late history merge cannot evict newer Ask rows")
check(state.history[1].allRows[1] == newer1 and state.history[1].allRows[2] == newer2, "history merge preserves row identity")

local unordered = {row("newer", 3), row("missing", nil), row("older", 1), row("same-a", 2), row("same-b", 2)}
local saved = Core.NormalizeSavedRows(unordered, 50)
check(ids(saved) == "older,same-a,same-b,newer,missing", "saved normalization stably orders known stamps and keeps unknown arrival")
check(ids(unordered) == "newer,missing,older,same-a,same-b", "normalization does not mutate saved source")
check(saved[1].itemLink == unordered[3].itemLink, "normalization keeps exact item variant")
check(ids(Core.NormalizeSavedAllRows(unordered, nil, 2)) == "newer,missing", "saved cap follows stable chronology including unknown rows")
local history = Core.SnapshotHistoryForSave({
    {instanceName = "Raid", encounterName = "Boss A", endedAt = 1003, allRows = {row("newer1", 1001), row("newer2", 1002)}, rows = {row("newer1", 1001), row("newer2", 1002)}},
    {instanceName = "Raid", encounterName = "Boss A", endedAt = 1002, allRows = {row("late-old", 1000)}, rows = {row("late-old", 1000)}},
}, 10, 2, 120, "enUS")
check(#history == 1 and ids(history[1].allRows) == "newer1,newer2", "snapshot duplicate merge caps chronological gear")
check(ids(history[1].rows) == "newer1,newer2", "snapshot duplicate merge caps chronological Ask rows")

local h = Harness.new({db = {settings = {maxSessionRows = 2}}}); h:loadAddon(); h.timers = {}
local held
local original = h.env.Item.CreateFromItemID
h.env.Item.CreateFromItemID = function(owner, id)
    if id == 55101 then return {ContinueOnItemLoad = function(_, callback) held = callback end} end
    return original(owner, id)
end
local function finalize()
    h:runTimers(0, 100)
    for index, timer in ipairs(h.timers) do
        if timer.delay == 10 then table.remove(h.timers, index).callback(); return end
    end
    error("missing finalization timer")
end
h:fire("ENCOUNTER_START", 510, "Boss A")
h:fireLoot("Otherplayer", h:addItem(55101, {name = "Old delayed", cacheLoaded = false}))
h.now = h.now + 1
h:fireLoot("Otherplayer", h:addItem(55102, {name = "New cached one"}))
h.now = h.now + 1
h:fireLoot("Otherplayer", h:addItem(55103, {name = "Newest cached two"}))
h:fire("ENCOUNTER_END", 510, "Boss A"); finalize()
h.now = h.now + 1
h.items[55101].cacheLoaded = true; held(); finalize()
local persisted = h.env.DoYouNeedItDB
check(persisted.history[1].allRows[1].itemID == 55102 and persisted.history[1].allRows[2].itemID == 55103,
    "actual held item completion retains newer history drops at cap")
check(persisted.sessionAllRows[1].itemID == 55102 and persisted.sessionAllRows[2].itemID == 55103,
    "actual held item completion retains newer session drops at cap")
local reloaded = Harness.new({db = persisted}); reloaded:loadAddon()
check(reloaded.env.DoYouNeedItDB.history[1].allRows[1].itemID == 55102, "reload retains chronological history")
check(#h.sentMessages == 0, "ordering never sends chat")

local addon
for index = 1, 30 do
    local name, value = debug.getupvalue(h.env.SlashCmdList.DOYOUNEEDIT, index)
    if name == "Addon" then addon = value end
end
local live = h.env.DoYouNeedItCore.CreateState({maxSessionRows = 2})
addon.state = live
local early = h.env.DoYouNeedItCore.AddVisibleRow(live, row("promoted-early", 10), false)
h.env.DoYouNeedItCore.AddVisibleRow(live, row("promoted-later", 20), true)
addon.SyncRowAskability(early, true)
check(ids(live.currentRows) == "promoted-early,promoted-later", "delayed Ask promotion retains current chronology")
check(ids(live.sessionRows) == "promoted-early,promoted-later", "delayed Ask promotion retains session chronology")
h.env.DoYouNeedItCore.CompleteCurrentGroup(live, {instanceName = "Raid", encounterName = "Boss A", endedAt = 21})
addon.SyncRowAskability(early, false); addon.SyncRowAskability(early, true)
check(ids(live.history[1].rows) == "promoted-early,promoted-later", "history re-promotion retains chronology")

local guarded = h.env.DoYouNeedItCore.CreateState({})
local originalSecretCheck = h.env.issecretvalue
h.env.issecretvalue = function(value)
    if type(value) == "number" and value == 0.5 then return true end
    return originalSecretCheck(value)
end
for _, pair in ipairs({{"known-three", 3}, {"missing", false}, {"nan", 0/0}, {"infinite", math.huge},
    {"secret", h:secretValue("loot time")}, {"restricted-number", 0.5}, {"known-one", 1}, {"known-two-a", 2}, {"known-two-b", 2}}) do
    h.env.DoYouNeedItCore.AddVisibleRow(guarded, row(pair[1], pair[2] ~= false and pair[2] or nil), true)
end
check(ids(guarded.allRows) == "known-one,known-two-a,known-two-b,known-three,missing,nan,infinite,secret,restricted-number",
    "restricted and nonfinite timestamps never enter comparisons; stable unknown and equal order")
local sanitized = h.env.DoYouNeedItCore.NormalizeSavedRows(guarded.allRows, 50)
check(sanitized[#sanitized].timestamp == nil, "restricted numeric timestamps are not persisted")
h.env.DoYouNeedItCore.CompleteCurrentGroup(guarded,
    {instanceName = "Raid", encounterName = "Boss A", endedAt = 5, mergeWindow = 120})
h.env.DoYouNeedItCore.AddVisibleRow(guarded, row("late-secret", h:secretValue("late loot time")), true)
h.env.DoYouNeedItCore.CompleteCurrentGroup(guarded,
    {instanceName = "Raid", encounterName = "Boss A", endedAt = 6, mergeWindow = 120})
check(#guarded.history == 1 and #guarded.history[1].allRows == 10,
    "history identity merge never stringifies restricted timestamps")
local retainedIdentity = {newer2, newer1}
check(Core.OrderRowsChronologically(retainedIdentity) == retainedIdentity and retainedIdentity[1] == newer1,
    "in-place chronological normalization preserves list and row identities")
local storedOne, storedTwo, earlyLive = row("stored-one", 101), row("stored-two", 102), row("early-live", 100)
local migrated = addon.MergeSavedRowsBeforeLive({storedOne, storedTwo}, {earlyLive}, 2)
check(ids(migrated) == "stored-one,stored-two", "runtime saved/live merge caps actual newest rows")
check(migrated[1] == storedOne and migrated[2] == storedTwo, "runtime saved/live merge preserves retained row identities")
local orderedInput, secretChecks = {}, 0
for index = 1, 500 do orderedInput[index] = row("ordered" .. index, index) end
local previousSecretCheck = _G.issecretvalue
_G.issecretvalue = function() secretChecks = secretChecks + 1; return false end
local orderedSnapshot = Core.NormalizeSavedRows(orderedInput, 50)
_G.issecretvalue = previousSecretCheck
check(#orderedSnapshot == 50 and orderedSnapshot[1].id == "ordered451", "large ordered snapshot keeps newest capped rows")
check(secretChecks < 6000, "normal ordered snapshot uses linear bounded timestamp reads")
print("Late row order regressions: PASS (" .. checks .. " assertions)")
