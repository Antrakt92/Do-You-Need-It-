local Harness = dofile("tests/runtime_harness.lua")

local function fresh(db)
    local h = Harness.new({ db = db })
    h:loadAddon()
    h.timers = {}
    return h
end

local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function testHiddenSavedWarbandRowsAreNotDeleted()
    local rows = {
        { id = "legacy-warband", itemLink = "Warband", looter = "Otherplayer", reason = "warband_bound", askable = false },
        { id = "flags-warband", itemLink = "Account", looter = "Otherplayer", isAccountBound = true, askable = false },
        { id = "unknown", itemLink = "Unknown personal loot", looter = "Otherplayer", tradeStatusKey = "trade_unknown", askable = false },
    }
    local h = fresh({ characters = { ["Player-Ravencrest"] = { sessionAllRows = rows } } })
    h:slash("history")
    local visible = h:visibleRows()
    equal(#visible, 1, "saved view hides known account-bound loot")
    equal(visible[1].row.id, "unknown", "unknown personal loot remains reviewable")
    h:slash("delay 11")
    equal(#h.env.DoYouNeedItDB.sessionAllRows, 3, "filtering does not delete saved records")
end

local function testWarbandMetadataUpdateHidesExistingRow()
    local h = fresh()
    local generic = h:addItem(34001, { name = "Binding Update", bindType = 2 })
    h:fire("ENCOUNTER_LOOT_RECEIVED", 7, 34001, generic, 1, "Otherplayer", "PALADIN")
    equal(#h:visibleRows(), 1, "ordinary drop starts visible")
    h.items[34001].bindToAccountUntilEquip = true
    local detailed = "|cffa335ee|Hitem:34001::::::::::::1:9999:|h[Binding Update]|h|r"
    h:fireLoot("Otherplayer", detailed)
    equal(#h:visibleRows(), 0, "resolved warband binding hides a previously visible row")
    h:slash("history")
    equal(#h:visibleRows(), 0, "warband update stays hidden in session view")
    h:runTimers(30)
    equal(#h.sentMessages, 0, "hidden binding never starts a whisper")
end

local function testInvalidWhisperRemainsActionable()
    for _, template in ipairs({ string.rep("{item}", 24), "hello\n{item}" }) do
        local h = fresh({ settings = { whisperTemplate = template } })
        local item = h:addItem(34002, { name = string.rep("Long Item Name ", 8), bindType = 2 })
        h:fireLoot("Otherplayer", item)
        local frame = h:visibleRows()[1]
        frame.whisper:FireScript("OnClick")
        h:runTimers(0)
        equal(#h.sentMessages, 0, "invalid expanded message is not sent")
        assert(frame.row.statusKey == "whisper_too_long" or frame.row.statusKey == "whisper_invalid", "invalid message shows an actionable status")
        equal(frame.whisper:IsEnabled(), true, "message failure leaves Ask available after editing template")
        h:slash("settings")
        local edit = h.env.DoYouNeedItSettingsFrame.whisperEditBox
        edit:SetText("Need {item}?")
        edit:FireScript("OnEnterPressed")
        h.env.DoYouNeedItSettingsFrame.back:FireScript("OnClick")
        h:visibleRows()[1].whisper:FireScript("OnClick")
        h:runTimers(0)
        equal(#h.sentMessages, 1, "a corrected message sends once")
    end
end

local tests = { testHiddenSavedWarbandRowsAreNotDeleted, testWarbandMetadataUpdateHidesExistingRow, testInvalidWhisperRemainsActionable }
tests[#tests + 1] = function()
    local h = fresh()
    h:slash("history")
    local generic = h:addItem(34003, { name = "Hidden Pending Loot" })
    h:fireLoot("Otherplayer", generic)
    equal(h.env.DoYouNeedItFrame.newLootButton:IsShown(), true, "background loot starts a new-loot indicator")
    h.items[34003].bindToAccount = true
    local detailed = "|cffa335ee|Hitem:34003::::::::::::1:9999:|h[Hidden Pending Loot]|h|r"
    h:fireLoot("Otherplayer", detailed)
    equal(#h:visibleRows(), 0, "binding metadata hides the only pending drop")
    equal(h.env.DoYouNeedItFrame.newLootButton:IsShown(), false, "hidden-only drops do not leave a new-loot button pointing to an empty view")
end
tests[#tests + 1] = function()
    local h = fresh()
    local item = h:addItem(34004, { name = "Late Warband Sword", bindType = 2 })
    h:fireLoot("Otherplayer", item)
    equal(#h:visibleRows(), 1, "bind-on-equip drop starts visible")
    h.items[34004].bindToAccountUntilEquip = true
    h:runTimers(2, 100)
    equal(#h:visibleRows(), 0, "late warband confirmation hides the row")
    local saved = h.env.DoYouNeedItDB.sessionAllRows
    equal(#saved, 1, "bounded warband recheck keeps history")
    equal(saved[1].statusKey, "warband_bound", "bounded warband recheck stores an explicit reason")
    equal(saved[1].tradeStatusKey, "trade_no", "bounded warband recheck clears the likely-transfer claim")
    equal(#h.sentMessages, 0, "bounded warband recheck never starts a whisper")
end
tests[#tests + 1] = function()
    local h = fresh()
    local item = h:addItem(34005, { name = "Ordinary BoE Sword", bindType = 2 })
    h:fireLoot("Otherplayer", item)
    equal(#h:visibleRows(), 1, "ordinary drop starts visible")
    h:runTimers(2, 100)
    equal(#h:visibleRows(), 1, "bounded warband recheck leaves ordinary bind-on-equip visible")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "candidate", "unconfirmed row keeps its askable status")
end
tests[#tests + 1] = function()
    local h = fresh()
    local item = h:addItem(34050, { name = "Whispered BoE Sword", bindType = 2 })
    h:fireLoot("Otherplayer", item)
    equal(#h:visibleRows(), 1, "whispered drop starts visible")
    h:visibleRows()[1].whisper:FireScript("OnClick")
    h:runTimers(0, 10)
    equal(#h.sentMessages, 1, "manual whisper sends before warband recheck")
    h.items[34050].bindToAccountUntilEquip = true
    h:runTimers(2, 100)
    equal(#h:visibleRows(), 1, "warband recheck skips already-whispered row")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "sent", "whispered row keeps sent status")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].tradeStatusKey ~= "trade_no", true, "whispered row keeps its transfer claim")
end
tests[#tests + 1] = function()
    local h = fresh()
    h:addItem(34060, { name = "Rearm Drop", bindType = 2 })
    local generic = "|cffa335ee|Hitem:34060:::::::::::::|h[Rearm Drop]|h|r"
    local detailed = "|cffa335ee|Hitem:34060::::::::::::1:9999:|h[Rearm Drop]|h|r"
    h:fireLoot("Otherplayer", generic)
    equal(#h:visibleRows(), 1, "rearm drop starts visible")
    h:fireLoot("Otherplayer", detailed)
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].itemLink, detailed, "duplicate upgrades to detailed link")
    h.items[34060].bindToAccountUntilEquip = true
    h:runTimers(2, 100)
    equal(#h:visibleRows(), 0, "rearmed warband recheck hides duplicate-upgraded row")
    equal(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "warband_bound", "rearmed recheck stores warband reason")
end
tests[#tests + 1] = function()
    local h = fresh()
    h:addItem(34061, { name = "History Drop", bindType = 2 })
    local generic = "|cffa335ee|Hitem:34061:::::::::::::|h[History Drop]|h|r"
    local detailed = "|cffa335ee|Hitem:34061::::::::::::1:9999:|h[History Drop]|h|r"
    h:fireLoot("Otherplayer", generic)
    h:fire("ENCOUNTER_END", 123, "History Boss")
    h:runTimers(10, 100)
    equal(#h.env.DoYouNeedItDB.history, 1, "history holds the finalized run")
    h:slash("clear")
    h.items[34061].bindToAccountUntilEquip = true
    h:fireLoot("Otherplayer", detailed)
    h:runTimers(2, 100)
    local group = h.env.DoYouNeedItDB.history[1]
    local historyRow = (group.allRows or {})[1] or (group.rows or {})[1]
    assert(historyRow.tradeStatusKey ~= "trade_no", "warband recheck never mutates history groups")
    assert(historyRow.statusKey ~= "warband_bound", "history keeps its stored verdict")
end
tests[#tests + 1] = function()
    local h = fresh()
    local Core = h.env.DoYouNeedItCore
    for _, subclassID in ipairs({ 2, 3, 18 }) do
        local result = Core.ResolvePlayerCanEquip({ classID = 2, subclassID = subclassID }, "WARRIOR", nil)
        assert(result ~= false, "warrior ranged subclass " .. tostring(subclassID) .. " is not denied when the API is silent")
    end
end
tests[#tests + 1] = function()
    local h = fresh()
    local Core = h.env.DoYouNeedItCore
    local proxy = h:secretValue("itemID")
    local stored = { itemLink = "|cffa335ee|Hitem:29080:::::::::::::|h[Drop]|h|r", itemID = proxy }
    local incoming = { itemLink = "|cffa335ee|Hitem:29080::::::::::::1:9999:|h[Drop]|h|r", itemID = 29080 }
    local ok = pcall(Core.UpgradeRowLinkToDetailed, stored, incoming)
    assert(ok, "hostile itemID proxy never crashes link upgrade")
end
tests[#tests + 1] = function()
    local h = fresh()
    for id = 34010, 34018 do h:fireLoot("Otherplayer", h:addItem(id, {})) end
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    h:fireLoot("Otherplayer", h:addItem(34019, {}))
    equal(h.env.DoYouNeedItFrame.newLootButton:IsShown(), true, "new loot flags while reading older rows")
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", 1)
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", 1)
    equal(h:visibleRows()[1].row.itemID, 34019, "manual scrolling reaches latest loot")
    equal(h.env.DoYouNeedItFrame.newLootButton:IsShown(), false, "reading the newest current loot clears the indicator")
end
tests[#tests + 1] = function()
    local h = Harness.new({ locale = "ruRU", db = { settings = { font = "Fonts\\FRIZQT__.TTF" } } })
    h:loadAddon()
    h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    equal(settings.title:GetText(), "Настройки", "Russian client selects Russian settings")
    for _, control in ipairs({ settings.title, settings.autoCheckLabel, settings.delayLabel, settings.whisperLabel,
        settings.languageLabel, settings.fontLabel, settings.fontSizeLabel, settings.back:GetFontString() }) do
        equal(control.font, "Fonts\\ARIALN.TTF", "Russian settings use a Cyrillic-capable font")
    end
end
local failed = 0
for _, test in ipairs(tests) do
    local ok, message = pcall(test)
    if not ok then failed = failed + 1; print(message) end
end
assert(failed == 0, tostring(failed) .. " runtime filter/message regressions failed")
print("runtime filter/message regressions ok")
