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

local function assertFalsy(value, label)
    if value then
        error(label .. ": expected falsy value, got " .. tostring(value), 2)
    end
end

local function testLoadAndSettings()
    local h = Harness.new()
    h:loadAddon()

    assertTruthy(h.env.SlashCmdList.DOYOUNEEDIT, "slash command registered")
    assertTruthy(h:registered("CHAT_MSG_LOOT"), "loot event registered")
    assertTruthy(h:registered("INSPECT_READY"), "inspect event registered")
    assertTruthy(h.env.DoYouNeedItFrame, "main frame created on load")
    assertEqual(h.env.DoYouNeedItFrame:IsShown(), false, "main frame starts hidden")

    h:slash("settings")
    assertTruthy(h.env.DoYouNeedItSettingsFrame, "settings frame created")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), true, "settings frame opens")
    assertTruthy(h.env.DoYouNeedItLanguageDropdown.Text:GetText() ~= "", "language dropdown has visible text")
    assertTruthy(h.env.DoYouNeedItFontDropdown.Text:GetText() ~= "", "font dropdown has visible text")
end

local function testSlashTestRowsAndManualWhisper()
    local h = Harness.new()
    h:loadAddon()
    h:slash("test")

    assertEqual(h.env.DoYouNeedItFrame:IsShown(), true, "test command shows main frame")
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "askable tab shows only askable test row")
    assertEqual(rows[1].row.looter, "Example", "test row looter visible")
    assertTruthy(rows[1].drop:GetText():find("Test Sword", 1, true), "test row item text visible")
    assertTruthy(rows[1].equipped:GetText():find("Worn Shortsword", 1, true), "test row equipped item visible")

    rows[1].whisper:FireScript("OnClick")
    h:runTimers(0)
    assertEqual(#h.sentMessages, 1, "manual Ask sends one whisper")
    assertEqual(h.sentMessages[1].target, "Example", "manual Ask whispers the row looter")
    assertEqual(rows[1].row.manualWhispered, true, "manual Ask marks row sent")
end

local function testInstanceChangeCompletesCurrentGroup()
    local h = Harness.new()
    h:loadAddon()
    h:slash("test")

    h.instanceName = "Halls of Infusion"
    h:fire("PLAYER_ENTERING_WORLD")

    assertEqual(#h.env.DoYouNeedItDB.history, 1, "instance change saves current drops to history")
    assertTruthy(h.env.DoYouNeedItDB.history[1].title:find("Ruby Life Pools", 1, true), "history keeps old instance name")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "session askable loot survives instance change")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 2, "session all gear loot survives instance change")
end

local function testDebugPersistenceIsOptIn()
    local h = Harness.new()
    h:loadAddon()

    h:slash("scan")
    assertFalsy(h.env.DoYouNeedItDB.diagnostics, "debug off does not persist scan diagnostics")

    h:slash("debug on")
    assertEqual(type(h.env.DoYouNeedItDB.diagnostics), "table", "debug on creates diagnostic buffer")
    assertEqual(#h.env.DoYouNeedItDB.diagnostics, 0, "debug on starts with a fresh diagnostic buffer")
    h:slash("scan")
    assertEqual(#h.env.DoYouNeedItDB.diagnostics, 1, "debug on persists new diagnostics")

    h:slash("debug off")
    assertFalsy(h.env.DoYouNeedItDB.diagnostics, "debug off clears persisted diagnostics")
    h:slash("scan")
    assertFalsy(h.env.DoYouNeedItDB.diagnostics, "debug off stops later diagnostic persistence")
end

local function testDebugPersistenceLoadState()
    local debugOff = Harness.new({
        db = {
            settings = { debug = false, font = "Fonts\\FRIZQT__.TTF" },
            diagnostics = {
                { stage = "old", looter = "Otherplayer" },
            },
        },
    })
    debugOff:loadAddon()
    assertFalsy(debugOff.env.DoYouNeedItDB.diagnostics, "debug-off load purges stale persisted diagnostics")

    local debugOn = Harness.new({
        db = {
            settings = { debug = true, font = "Fonts\\FRIZQT__.TTF" },
            diagnostics = {
                { stage = "old", looter = "Otherplayer" },
            },
        },
    })
    debugOn:loadAddon()
    assertEqual(#debugOn.env.DoYouNeedItDB.diagnostics, 2, "debug-on load keeps old diagnostics and records startup diagnostics")
    assertEqual(debugOn.env.DoYouNeedItDB.diagnostics[2].stage, "old", "debug-on load preserves diagnostic payload")
end

local function testLegacySavedAllGearFallbackDisplays()
    local sessionItem = "|cff0070dd|Hitem:30001:::::::::::::|h[Legacy Session Sword]|h|r"
    local historyItem = "|cff0070dd|Hitem:30002:::::::::::::|h[Legacy History Sword]|h|r"
    local h = Harness.new({
        db = {
            settings = { font = "Fonts\\FRIZQT__.TTF" },
            sessionRows = {
                {
                    id = "legacy-session",
                    looter = "Otherplayer-Ravencrest",
                    itemLink = sessionItem,
                    equippedText = "Equipped: unknown",
                    askable = true,
                },
            },
            history = {
                {
                    title = "Legacy Boss",
                    rows = {
                        {
                            id = "legacy-history",
                            looter = "Otherplayer-Ravencrest",
                            itemLink = historyItem,
                            equippedText = "Equipped: unknown",
                            askable = true,
                        },
                    },
                },
            },
        },
    })
    h:loadAddon()

    h:slash("history")
    local allGearTab = h:findFrame(function(frame)
        return type(frame.GetText) == "function" and frame:GetText() == "All Gear"
    end)
    assertTruthy(allGearTab, "all gear tab is findable")
    allGearTab:FireScript("OnClick")
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "legacy session fallback displays in all gear")
    assertEqual(rows[1].row.id, "legacy-session", "legacy session fallback keeps row identity")

    h:slash("history")
    rows = h:visibleRows()
    assertEqual(#rows, 1, "legacy history fallback displays in all gear")
    assertEqual(rows[1].row.id, "legacy-history", "legacy history fallback keeps row identity")
end

local function testLegacyPlainItemTextDoesNotCreateDropHoverTarget()
    local h = Harness.new({
        db = {
            settings = { font = "Fonts\\FRIZQT__.TTF" },
            sessionRows = {
                {
                    id = "legacy-plain-item",
                    looter = "Otherplayer-Ravencrest",
                    itemLink = "Legacy Plain Item Name",
                    equippedText = "Equipped: unknown",
                    askable = true,
                },
            },
        },
    })
    h:loadAddon()
    h:slash("history")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "legacy plain item row remains visible")
    assertEqual(rows[1].dropLink:IsShown(), false, "plain item text does not expose a tooltip hover target")
    assertEqual(rows[1].dropLink.itemLink, nil, "plain item text is not treated as an item hyperlink")
end

testLoadAndSettings()
testSlashTestRowsAndManualWhisper()
testInstanceChangeCompletesCurrentGroup()
testDebugPersistenceIsOptIn()
testDebugPersistenceLoadState()
testLegacySavedAllGearFallbackDisplays()
testLegacyPlainItemTextDoesNotCreateDropHoverTarget()

print("runtime smoke ok")
