local Harness = dofile("tests/runtime_harness.lua")
local count = 0
local function check(value, message)
    count = count + 1
    assert(value, message)
end
local function click(button) button:FireScript("OnClick") end

do
    local h = Harness.new()
    h:loadAddon(); h:slash("")
    h:runTimers(40)
    local inspectBefore = #h.notifyInspectCalls
    h.env.GameTooltip.IsOwned = function(self, owner) return self.owner == owner end
    local frame = h.env.DoYouNeedItFrame
    check(frame.demoButton:IsShown(), "demo is available in the empty window")
    frame.demoButton:FireScript("OnEnter")
    check(h.env.GameTooltip:GetText():find("No whispers", 1, true), "tooltip explains the preview boundary")
    frame:Hide()
    check(not h.env.GameTooltip:IsShown(), "closing the main window dismisses the demo tooltip")
    frame:Show()
    local demo = h.env.DoYouNeedItCore.BuildDemoRows({}, 100)
    check(#demo == 12, "expanded demo contains twelve items")
    local ids, sources, trade, paired = {}, {}, {}, 0
    for _, row in ipairs(demo) do
        check(row.isTest and not ids[row.itemID], "every example is isolated and has a distinct real item ID")
        ids[row.itemID], sources[row.instanceName], trade[row.tradeStatusKey] = true, true, true
        check(row.itemLink:find("Hitem:" .. row.itemID .. ":", 1, true), "displayed item matches the tooltip ID")
        local _, links = row.equippedText:gsub("|Hitem:", "")
        if links == 2 then paired = paired + 1 end
    end
    check(sources["The Unbinding of Kith'ix"] and sources["Murder Row"], "Midnight raid and dungeon samples included")
    check(trade.trade_likely and trade.trade_unknown and trade.trade_no and trade.trade_confirmed, "all transfer states demonstrated")
    check(paired >= 3, "rings and trinkets exercise two equipped tooltip targets")
    click(frame.demoButton)
    check(frame.historyButton:GetText() == "Demo" and frame.demoButton:GetText() == "Exit demo", "demo has a clear mode and exit action")
    check(#h:visibleRows() == 4 and frame.scrollText:GetText():find("12", 1, true), "first page renders with an overflow count")
    for _, row in ipairs(h:visibleRows()) do
        check(row.row.isTest and not row.whisper:IsEnabled(), "demo Ask controls cannot send")
        click(row.whisper)
    end
    h:runTimers(40)
    check(#h.sentMessages == 0 and #h.notifyInspectCalls == inspectBefore, "demo sends no whispers and requests no inspection")
    click(frame.demoButton)
    check(#h:visibleRows() == 0 and frame.demoButton:GetText() == "Demo", "second click restores the empty real view")
    h:slash("test")
    check(#h:visibleRows() == 4, "slash uses the same demo path")
    h:slash("test")
    check(#h:visibleRows() == 0, "slash also exits without duplicate rows")
end

do
    local h = Harness.new()
    h:loadAddon(); h.timers = {}
    local function loot(id)
        local link = h:addItem(id, {name = "Live gear " .. id})
        h:fireLoot("Otherplayer", link)
        return link
    end
    h:fire("ENCOUNTER_START", 31101, "First Boss")
    loot(31101)
    h:fire("ENCOUNTER_END", 31101, "First Boss")
    h:runTimers(10, 100)
    h:fire("ENCOUNTER_START", 31102, "Second Boss")
    loot(31102)
    h:slash("history"); h:slash("history")
    local frame = h.env.DoYouNeedItFrame
    local previousTitle = frame.historyButton:GetText()
    check(previousTitle:find("First Boss", 1, true), "precondition: older history selected")
    click(frame.demoButton)
    h:fire("ENCOUNTER_END", 31102, "Second Boss")
    h:runTimers(10, 100)
    click(frame.demoButton)
    check(frame.historyButton:GetText() == previousTitle, "exit restores the same encounter after history insertion")
    click(frame.demoButton)
    local realLink = loot(31103)
    check(frame.demoButton:GetText() == "Demo", "incoming real loot exits the preview")
    local found = false
    for _, row in ipairs(h:visibleRows()) do
        check(not row.row.isTest, "incoming loot restores only real rows")
        if row.row.itemLink == realLink then found = true end
    end
    check(found, "incoming drop remains visible")
end

do
    local h = Harness.new()
    h:loadAddon(); h:slash("auto on"); h:slash("test")
    local frame = h.env.DoYouNeedItFrame
    h:fire("PLAYER_LOGOUT")
    check(#(h.env.DoYouNeedItDB.sessionAllRows or {}) == 0, "logout excludes sample loot")
    check(#(h.env.DoYouNeedItDB.history or {}) == 0, "logout creates no sample history")
    h:slash("settings")
    check(not frame.demoButton:IsShown(), "demo control does not overlap Settings")
    h:slash("test")
    check(not h.env.DoYouNeedItSettingsFrame:IsShown(), "exiting demo from Settings returns to loot")
    h:runTimers(40)
    check(#h.sentMessages == 0, "auto-whisper stays isolated from demo")
end

for _, locale in ipairs({"enUS", "ruRU", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "koKR", "zhCN", "zhTW"}) do
    local h = Harness.new({db = {settings = {forceLocale = locale, fontSize = 24}}})
    h:loadAddon(); h:slash("test")
    local frame, core = h.env.DoYouNeedItFrame, h.env.DoYouNeedItCore
    check(frame.demoButton:GetText() == core.GetLocaleLabel("Exit demo", locale), "exit button is localized")
    check(frame.historyButton:GetWidth() + frame.demoButton:GetWidth() + 6 <= frame:GetWidth() - 32, "selector and demo target fit together")
    local _, labelSize = frame.demoButton:GetFontString():GetFont()
    check(labelSize <= 12, "button label stays readable inside the target at large font size")
end
print("Demo regressions: PASS (" .. count .. " assertions)")
