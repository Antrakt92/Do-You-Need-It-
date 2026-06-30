local root = assert(loadfile("DoYouNeedIt_Core.lua"))()
local Core = _G.DoYouNeedItCore or root

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

local settings = Core.NormalizeSettings({})
assertEqual(settings.autoWhisper, false, "auto whisper defaults off")
assertEqual(settings.autoDelay, 10, "auto delay defaults to 10")
assertEqual(settings.debug, false, "debug defaults off")
assertEqual(Core.NormalizeSettings({ autoDelay = 1 }).autoDelay, 3, "delay clamps low")
assertEqual(Core.NormalizeSettings({ autoDelay = 45 }).autoDelay, 30, "delay clamps high")
assertEqual(Core.NormalizeSettings({ debug = true }).debug, true, "debug can be enabled")

local accepted = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
    canTrade = nil,
}, "Otherplayer", "Player")
assertEqual(accepted.visible, true, "weapon from another player is visible")

local currency = Core.ClassifyTradeCandidate({
    link = "|Hcurrency:3008:1|h[Currency]|h",
    quality = 4,
    classID = 10,
    equipLoc = "",
}, "Otherplayer", "Player")
assertEqual(currency.visible, false, "currency hidden")

local selfLoot = Core.ClassifyTradeCandidate({
    link = "|cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r",
    quality = 3,
    classID = 2,
    equipLoc = "INVTYPE_WEAPON",
}, "Player", "Player")
assertEqual(selfLoot.visible, false, "player's own loot hidden")

local reagent = Core.ClassifyTradeCandidate({
    link = "|cff1eff00|Hitem:190456:::::::::::::|h[Test Reagent]|h|r",
    quality = 2,
    classID = 7,
    equipLoc = "",
    isCraftingReagent = true,
}, "Otherplayer", "Player")
assertEqual(reagent.visible, false, "reagent hidden")

local notTradeable = Core.ClassifyTradeCandidate({
    link = "|cffa335ee|Hitem:19020:::::::::::::|h[Bound Chest]|h|r",
    quality = 4,
    classID = 4,
    equipLoc = "INVTYPE_CHEST",
    canTrade = false,
}, "Otherplayer", "Player")
assertEqual(notTradeable.visible, false, "explicit non-tradeable item hidden")

local state = Core.CreateState({ maxHistoryGroups = 10 })
for index = 1, 12 do
    Core.AddVisibleRow(state, {
        id = "row" .. index,
        looter = "Otherplayer",
        itemLink = "|cff0070dd|Hitem:" .. index .. ":::::::::::::|h[Test]|h|r",
        timestamp = index,
    })
    Core.CompleteCurrentGroup(state, {
        title = "Boss " .. index,
        instanceName = "Dungeon",
        encounterName = "Boss " .. index,
        endedAt = index,
    })
end
assertEqual(#state.history, 10, "history prunes to 10")
assertEqual(state.history[1].title, "Dungeon - Boss 12 (1 drop)", "newest group first")
assertEqual(state.history[10].title, "Dungeon - Boss 3 (1 drop)", "oldest retained group")

local emptyState = Core.CreateState({ maxHistoryGroups = 10 })
Core.CompleteCurrentGroup(emptyState, { title = "No Drops", endedAt = 1 })
assertEqual(#emptyState.history, 0, "empty groups are not saved")

local auto = Core.GetAutoWhisperDecision(
    Core.NormalizeSettings({ autoWhisper = true, autoDelay = 12 }),
    { looter = "Otherplayer", itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r", unsafe = false }
)
assertEqual(auto.shouldSchedule, true, "auto whisper schedules for eligible row")
assertEqual(auto.delay, 12, "auto whisper uses configured delay")

local blocked = Core.GetAutoWhisperDecision(
    Core.NormalizeSettings({ autoWhisper = true, autoDelay = 12 }),
    { looter = "Otherplayer", itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r", unsafe = true }
)
assertEqual(blocked.shouldSchedule, false, "unsafe rows do not schedule auto whisper")
assertEqual(Core.ShouldAutoShowWindow({ itemLink = "|cff0070dd|Hitem:1:::::::::::::|h[Test]|h|r" }), true, "new loot rows auto-show the window")
assertEqual(Core.ShouldAutoShowWindow(nil), false, "missing rows do not auto-show the window")

local roster = {
    ["Player-Ravencrest"] = "player",
    Player = "player",
    ["Otherplayer-Ravencrest"] = "party1",
    Otherplayer = "party1",
}
local playerLinkedMessage = "|Hplayer:Otherplayer-Ravencrest:1|h[Otherplayer]|h receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(
    Core.FindRosterNameInMessage(playerLinkedMessage, roster, "Player-Ravencrest"),
    "Otherplayer-Ravencrest",
    "loot parser resolves full names from player links"
)
local coloredMessage = "|cffaad372Otherplayer|r receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(
    Core.FindRosterNameInMessage(coloredMessage, roster, "Player-Ravencrest"),
    "Otherplayer",
    "loot parser resolves names through color markup"
)
local ownMessage = "Player receives loot: |cff0070dd|Hitem:19019:::::::::::::|h[Test Sword]|h|r."
assertEqual(Core.FindRosterNameInMessage(ownMessage, roster, "Player-Ravencrest"), nil, "loot parser ignores own drops")

local diagnostics = {}
for index = 1, 12 do
    Core.RecordDiagnostic(diagnostics, { stage = "stage" .. index, itemLink = "item" .. index }, 10)
end
assertEqual(#diagnostics, 10, "diagnostics prune to limit")
assertEqual(diagnostics[1].stage, "stage12", "newest diagnostic first")
assertEqual(diagnostics[10].stage, "stage3", "oldest retained diagnostic kept at limit")

assertEqual(Core.VERSION, "0.1.2", "core exposes current version")

local function readFile(path)
    local handle = assert(io.open(path, "rb"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local toc = readFile("DoYouNeedIt.toc")
assertTruthy(toc:find("## Title: Do You Need It?", 1, true), "toc title present")
assertTruthy(toc:find("## Version: 0.1.2", 1, true), "toc version present")
assertTruthy(toc:find("## SavedVariables: DoYouNeedItDB", 1, true), "toc saved variables present")
assertTruthy(toc:find("DoYouNeedIt_Core.lua", 1, true), "toc loads core first")
assertTruthy(toc:find("DoYouNeedIt.lua", 1, true), "toc loads runtime")

local runtime = readFile("DoYouNeedIt.lua")
assertTruthy(runtime:find("CHAT_MSG_LOOT", 1, true), "runtime listens to loot chat")
assertTruthy(runtime:find("ENCOUNTER_END", 1, true), "runtime tracks encounter completion")
assertTruthy(runtime:find("C_Timer.After", 1, true), "runtime defers whisper sends")
assertTruthy(runtime:find("DoYouNeedItCore.ClassifyTradeCandidate", 1, true), "runtime filters before display")
assertTruthy(runtime:find("OptionsSliderTemplate", 1, true), "runtime provides a delay slider")
assertTruthy(runtime:find("autoCheck", 1, true), "runtime provides an auto whisper checkbox")
assertTruthy(runtime:find("delaySlider", 1, true), "runtime wires the delay slider")
assertTruthy(runtime:find("local WINDOW_WIDTH = 460", 1, true), "runtime uses tighter compact window width")
assertTruthy(runtime:find("local WINDOW_HEIGHT = 310", 1, true), "runtime uses tighter compact window height")
assertTruthy(runtime:find("local MAX_VISIBLE_ROWS = 5", 1, true), "runtime limits visible rows for compact height")
assertTruthy(runtime:find("DoYouNeedItCore.ShouldAutoShowWindow", 1, true), "runtime auto-shows on new loot rows")
assertTruthy(runtime:find("AddTestRow", 1, true), "runtime has a local test row command")
assertTruthy(runtime:find("command == \"test\"", 1, true), "runtime wires /dyni test")
assertTruthy(runtime:find("command == \"debug\"", 1, true), "runtime wires /dyni debug")
assertTruthy(runtime:find("RecordDiagnostic", 1, true), "runtime records loot diagnostics")
assertTruthy(runtime:find("HandleLootMessage(...)", 1, true), "runtime passes full loot event payload")
assertTruthy(runtime:find("layout=460x310", 1, true), "runtime reports compact layout in status")

print("tests ok")
