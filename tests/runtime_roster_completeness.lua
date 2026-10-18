local Harness = dofile("tests/runtime_harness.lua")
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

local function fresh(raid)
    local h = Harness.new({inRaid = raid, db = {settings = {autoWhisper = true, autoDelay = 5}}})
    local size = 5
    h.env.GetNumGroupMembers = function() return size end
    if raid then
        -- The player appears through player and raid1. They are one member.
        for index = 1, 5 do
            local unit = index == 1 and "player" or "party" .. (index - 1)
            h:setUnit("raid" .. index, h.units[unit])
        end
        for index = 1, 4 do h:removeUnit("party" .. index) end
    end
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    local link = h:addItem(53801, {name = "Roster completeness sword"})
    h:fireLoot("Otherplayer", link)
    local frame = h:visibleRows()[1]
    check(frame, "initial loot row exists")
    local row = frame.row
    check(row.pendingAutoWhisper == true, "complete initial snapshot schedules automatic whisper")
    return h, row, function(value) size = value end, raid and "raid2" or "party1"
end

for _, raid in ipairs({false, true}) do
    local h, row, _, unit = fresh(raid)
    local original, token = h.units[unit], row.autoToken
    h:removeUnit(unit)
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == true and row.autoToken == token,
        "partial " .. (raid and "raid" or "party") .. " snapshot preserves countdown and token")
    h:setUnit(unit, original)
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(#h.sentMessages == 1, "restored complete roster sends its existing pending whisper once")
    check(h.sentMessages[1].target == "Otherplayer-Ravencrest", "restored whisper keeps exact recipient")
end

for _, raid in ipairs({false, true}) do
    local h, row, setSize, unit = fresh(raid)
    h:removeUnit(unit)
    setSize(4)
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == false, "authoritative member-count reduction cancels a real departure")
    h:runTimers(20, 200)
    check(#h.sentMessages == 0, "departed player never receives an automatic whisper")
end

for _, raid in ipairs({false, true}) do
    local h, row, setSize, unit = fresh(raid)
    h:removeUnit(unit)
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == true, "partial snapshot retains the last complete identity set")
    setSize(4)
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == false, "a later complete snapshot still detects the actual departure")
end

for _, mode in ipairs({"nil", "secret", "error", "nan", "infinite", "fractional", "zero", "negative", "too-large"}) do
    local h, row, _, unit = fresh(false)
    local original, token = h.units[unit], row.autoToken
    local secret = h:secretValue("roster member count")
    h.env.GetNumGroupMembers = function()
        if mode == "nil" then return nil end
        if mode == "secret" then return secret end
        if mode == "error" then error("count unavailable") end
        if mode == "nan" then return 0 / 0 end
        if mode == "infinite" then return math.huge end
        if mode == "zero" then return 0 end
        if mode == "negative" then return -1 end
        if mode == "too-large" then return 41 end
        return 4.5
    end
    h:removeUnit(unit)
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == true and row.autoToken == token,
        "unavailable " .. mode .. " member count cannot publish a departure")
    h.env.GetNumGroupMembers = function() return 4 end
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == false, "fresh authoritative count still cancels departure after " .. mode)
    h:setUnit(unit, original)
end

do
    local h, row, _, unit = fresh(false)
    h.env.GetNumGroupMembers = nil
    h:removeUnit(unit)
    h:fire("GROUP_ROSTER_UPDATE")
    check(row.pendingAutoWhisper == false, "absent count API retains historical roster behavior")
end

for _, raid in ipairs({false, true}) do
    local h, row, _, unit = fresh(raid)
    local original = h.units[unit]
    h:removeUnit(unit)
    h:fire("GROUP_ROSTER_UPDATE")
    local attempts = h:runTimers(20, 200)
    check(attempts < 200, "incomplete roster retry work is bounded")
    check(row.pendingAutoWhisper == true and #h.sentMessages == 0,
        "due whisper stays pending while looter name is unavailable")
    h:setUnit(unit, original)
    h.now = h.now + 20
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(#h.sentMessages == 1 and row.autoWhispered == true,
        "parked due whisper resumes once from a complete roster")
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(#h.sentMessages == 1, "repeated complete snapshots do not duplicate a recovered send")
end

do
    local h, row, _, unit = fresh(false)
    -- Dispatch schedules a zero-delay callback; names can disappear before it.
    for index, timer in ipairs(h.timers) do
        if timer.delay == 5 then
            table.remove(h.timers, index)
            timer.callback()
            break
        end
    end
    check(row.whisperInFlight == true, "zero-delay boundary fixture reaches dispatch")
    local original = h.units[unit]
    h:removeUnit(unit)
    h:runTimers(20, 200)
    check(row.pendingAutoWhisper == true and row.whisperInFlight == false and #h.sentMessages == 0,
        "boundary race requeues instead of losing or sending a due whisper")
    h:setUnit(unit, original)
    h.now = h.now + 20
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(#h.sentMessages == 1, "boundary race recovery sends exactly once")
end

do
    local h, row = fresh(false)
    h.env.GetNumGroupMembers = function() return nil end
    h:runTimers(20, 200)
    check(row.pendingAutoWhisper == true and #h.sentMessages == 0,
        "unreadable count pauses automatic sending even when every name is readable")
    h.env.GetNumGroupMembers = function() return 5 end
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(#h.sentMessages == 1, "readable member count resumes a parked whisper")
end

for _, action in ipairs({"clear", "departure", "opt-out"}) do
    local h, row, setSize, unit = fresh(false)
    local original = h.units[unit]
    h:removeUnit(unit)
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(row.pendingAutoWhisper == true and #h.sentMessages == 0, "cancellation fixture is parked")
    if action == "clear" then
        h:slash("clear")
    elseif action == "departure" then
        setSize(4)
        h:fire("GROUP_ROSTER_UPDATE")
    else
        h:slash("auto off")
    end
    h:setUnit(unit, original)
    setSize(5)
    h.now = h.now + 20
    h:fire("GROUP_ROSTER_UPDATE")
    h:runTimers(20, 200)
    check(#h.sentMessages == 0 and row.pendingAutoWhisper == false,
        action .. " cancels parked work without resurrection")
end

print("Roster completeness regressions: PASS (" .. checks .. " assertions)")
