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

local function topOffset(frame)
    local point = frame.points and frame.points[1]
    assertTruthy(point and point[1] == "TOPLEFT" and point[3] == "TOPLEFT", "control has a top-left anchor")
    return -(point[5] or 0)
end

local function testSettingsControlsStayInsideWindow()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")
    local main = h.env.DoYouNeedItFrame
    local settings = h.env.DoYouNeedItSettingsFrame
    local panelTop = topOffset(settings)

    assertEqual(main:GetWidth(), 540, "settings retain compact window width")
    assertTruthy(main:GetHeight() > 300, "settings expand vertically to fit their controls")
    assertTruthy(panelTop + settings:GetHeight() <= main:GetHeight() - 8, "settings panel fits above the window bottom border")
    for _, control in ipairs({
        settings.autoCheck,
        settings.delaySlider,
        settings.whisperEditBox,
        settings.languageDropdown,
        settings.fontDropdown,
        settings.fontSizeSlider,
        settings.fontWarning,
    }) do
        local bottom = topOffset(control) + (control:GetHeight() or control.fontSize or 24)
        assertTruthy(bottom <= settings:GetHeight(), "settings control stays inside its panel")
        assertTruthy(panelTop + bottom <= main:GetHeight() - 8, "settings control stays above the window border")
    end
    local sizeBottom = topOffset(settings.fontSizeSlider) + settings.fontSizeSlider:GetHeight()
    assertTruthy(topOffset(settings.fontWarning) >= sizeBottom + 6, "font warning is below the last control with a readable gap")
end

local function testLeavingSettingsRestoresLootHeight()
    local h = Harness.new()
    h:loadAddon()
    local main = h.env.DoYouNeedItFrame
    assertEqual(main:GetHeight(), 300, "loot starts at compact height")
    h:slash("settings")
    assertTruthy(main:GetHeight() > 300, "settings use expanded height")
    h.env.DoYouNeedItSettingsFrame.back:FireScript("OnClick")
    assertEqual(main:GetHeight(), 300, "Back restores loot height")
    h:slash("settings")
    main:Hide()
    h:slash("")
    assertEqual(main:GetHeight(), 300, "closing settings and reopening restores loot height")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), false, "reopening shows loot mode")
end

local function testMainWindowEscapeAndClamping()
    local h = Harness.new()
    h:loadAddon()
    assertEqual(h.env.DoYouNeedItFrame.clampedToScreen, true, "main window cannot be dragged offscreen")
    local registrations = 0
    for _, name in ipairs(h.env.UISpecialFrames) do
        if name == "DoYouNeedItFrame" then
            registrations = registrations + 1
        end
    end
    assertEqual(registrations, 1, "main window registers once for Escape dismissal")
end

local function testDemoNeverSendsRealWhispers()
    local h = Harness.new()
    h:loadAddon()
    h:slash("auto on")
    h:slash("test")
    local rows = h:visibleRows()
    assertEqual(#rows, 2, "demo retains both comparison examples")
    for _, frame in ipairs(rows) do
        if frame.whisper:IsShown() then
            frame.whisper:FireScript("OnClick")
        end
    end
    h:runTimers(30)
    assertEqual(#h.sentMessages, 0, "demo row actions and timers never send live chat")
end

local function settingsWithLoot()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    settings.whisperEditBox:FireScript("OnEditFocusGained")
    settings.whisperEditBox:SetText("Could you spare {item} please?")
    local item = h:addItem(22391, {
        name = "Settings Arrival Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })
    h:fireLoot("Otherplayer", item)
    return h, settings
end

local function testNewLootKeepsSettingsAndDraft()
    local h, settings = settingsWithLoot()
    assertEqual(settings:IsShown(), true, "incoming loot does not interrupt settings")
    assertEqual(settings.whisperEditBox:GetText(), "Could you spare {item} please?", "incoming loot preserves the focused draft")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, "Hey, do you need {item}?", "incoming loot does not prematurely commit a draft")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "incoming loot is retained while settings are open")
    settings.back:FireScript("OnClick")
    assertEqual(#h:visibleRows(), 1, "Back reveals the retained new loot")
    assertEqual(h.env.DoYouNeedItFrame:GetHeight(), 300, "Back after incoming loot restores compact height")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, "Could you spare {item} please?", "leaving settings deliberately saves the draft")
end

local function testHistoryFinalizationKeepsSettings()
    local h, settings = settingsWithLoot()
    h:slash("settings")
    h:fire("ENCOUNTER_END", 901, "Settings Boss")
    h:runTimers(11)
    assertEqual(#h.env.DoYouNeedItDB.history, 1, "loot still finalizes into history")
    assertEqual(settings:IsShown(), true, "background history finalization does not close settings")
    assertTruthy(h.env.DoYouNeedItFrame:GetHeight() > 300, "background finalization retains settings height")
end

local function addRealGear(h, itemID)
    local item = h:addItem(itemID, {
        name = "Tooltip Sword " .. tostring(itemID),
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })
    h:fireLoot("Otherplayer", item)
    return item
end

local function tooltipHarness(itemCount)
    local h = Harness.new()
    local tooltip = h.env.GameTooltip
    tooltip.GetOwner = function(self)
        return self.owner
    end
    tooltip.IsOwned = function(self, owner)
        return self.owner == owner
    end
    h:loadAddon()
    for index = 1, itemCount do
        addRealGear(h, 22400 + index)
    end
    return h, tooltip
end

local function testRecycledDropTooltipDoesNotKeepOldItem()
    local h, tooltip = tooltipHarness(8)
    local row = h:visibleRows()[1]
    local before = row.dropLink.itemLink
    row.dropLink:FireScript("OnEnter")
    assertEqual(tooltip.hyperlink, before, "precondition: hover shows the original item")
    assertEqual(tooltip:IsShown(), true, "precondition: original tooltip is visible")
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    assertTruthy(row.dropLink.itemLink ~= before, "scroll reuses the hovered frame for another drop")
    assertTruthy(not tooltip:IsShown() or tooltip.hyperlink == row.dropLink.itemLink,
        "recycled row hides or refreshes its old item tooltip")
end

local function testClosingWindowHidesOwnedTooltip()
    local h, tooltip = tooltipHarness(1)
    h:visibleRows()[1].dropLink:FireScript("OnEnter")
    assertEqual(tooltip:IsShown(), true, "precondition: item tooltip is visible")
    h.env.DoYouNeedItFrame:Hide()
    assertEqual(tooltip:IsShown(), false, "closing the main window dismisses its item tooltip")
end

local function testOpeningSettingsHidesOwnedTooltip()
    local h, tooltip = tooltipHarness(1)
    h:visibleRows()[1].tradeInfo:FireScript("OnEnter")
    assertEqual(tooltip:IsShown(), true, "precondition: trade explanation is visible")
    h:slash("settings")
    assertEqual(tooltip:IsShown(), false, "switching to settings dismisses the hidden row's tooltip")
end

local function testRowRefreshPreservesUnrelatedTooltip()
    local h, tooltip = tooltipHarness(8)
    h:visibleRows()[1].dropLink:FireScript("OnEnter")
    local externalOwner = h:newFrame("Button", nil, h.env.UIParent)
    tooltip:SetOwner(externalOwner, "ANCHOR_RIGHT")
    tooltip:SetText("Another window's tooltip")
    tooltip:Show()
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    assertEqual(tooltip:IsShown(), true, "row refresh does not hide another window's tooltip")
    assertEqual(tooltip:GetOwner(), externalOwner, "row refresh does not steal tooltip ownership")
    assertEqual(tooltip:GetText(), "Another window's tooltip", "row refresh preserves unrelated tooltip content")
end

local function testDemoPersistencePreservesOnlyRealLoot()
    local h = Harness.new()
    h:loadAddon()
    local item = addRealGear(h, 22420)
    h:slash("test")
    h:slash("delay 11")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "settings save excludes demo rows")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].itemLink, item, "settings save preserves preexisting real loot")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "settings save preserves only real askable loot")
    h:fire("PLAYER_LOGOUT")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "logout keeps demo rows out of session storage")
    assertEqual(#h.env.DoYouNeedItDB.history, 1, "logout creates only the real loot history group")
    assertEqual(#h.env.DoYouNeedItDB.history[1].allRows, 1, "history excludes demonstration drops")
    assertEqual(h.env.DoYouNeedItDB.history[1].allRows[1].itemLink, item, "history preserves the real drop")
    assertEqual(#h.env.DoYouNeedItDB.history[1].rows, 1, "history askable list excludes demonstration drops")
end

local function testDemoAloneDoesNotCreateSavedHistory()
    local h = Harness.new()
    h:loadAddon()
    h:slash("test")
    h:slash("delay 11")
    h:fire("PLAYER_LOGOUT")
    assertEqual(#(h.env.DoYouNeedItDB.sessionAllRows or {}), 0, "demo alone leaves saved session gear empty")
    assertEqual(#(h.env.DoYouNeedItDB.sessionRows or {}), 0, "demo alone leaves saved askable loot empty")
    assertEqual(#(h.env.DoYouNeedItDB.history or {}), 0, "demo alone creates no history group")
end

local function testBothEquippedItemsHaveSeparateTargets()
    local h, tooltip = tooltipHarness(1)
    local row = h:visibleRows()[1]
    local first = h:addItem(22430, { name = "First Equipped Ring" })
    local second = h:addItem(22431, { name = "Second Equipped Ring" })
    row.row.equippedText = "Cached: " .. first .. " / " .. second
    h:slash("delay 11")
    assertEqual(row.equippedLink.itemLink, first, "first equipped target retains first item")
    assertEqual(row.equippedLink2.itemLink, second, "second equipped target exposes the other item")
    assertEqual(row.equippedLink2:IsShown(), true, "second equipped target is visible")
    assertTruthy(row.equipped:GetText():find("Cached:", 1, true), "paired items retain cached evidence label")
    assertEqual(row.equipped2:GetText(), second, "second equipped item has its own readable label")
    assertTruthy(row.equippedLink.points[1][4] + row.equippedLink:GetWidth() <= row.equippedLink2.points[1][4],
        "equipped hover targets do not overlap")
    row.equippedLink:FireScript("OnEnter")
    assertEqual(tooltip.hyperlink, first, "first equipped hover opens first item")
    row.equippedLink2:FireScript("OnEnter")
    assertEqual(tooltip.hyperlink, second, "second equipped hover opens second item")
    local clicked
    h.env.HandleModifiedItemClick = function(link)
        clicked = link
        return true
    end
    row.equippedLink2:FireScript("OnClick")
    assertEqual(clicked, second, "second item supports normal modified item clicks")
    row.row.equippedText = "Equipped: " .. first
    h:slash("delay 12")
    assertEqual(row.equippedLink2:IsShown(), false, "single-item comparison removes second hover target")
    assertEqual(tooltip:IsShown(), false, "removing the second equipped item clears its owned tooltip")
    assertEqual(row.equipped:GetWidth(), 150, "single item uses the full equipped column")
end

local function testLargeFontsAdaptRowsWithoutClipping()
    local h = tooltipHarness(8)
    h:slash("settings")
    h.env.DoYouNeedItSettingsFrame.fontSizeSlider:SetValue(24)
    local settings = h.env.DoYouNeedItSettingsFrame
    assertTruthy(settings:GetHeight() + topOffset(settings) <= h.env.DoYouNeedItFrame:GetHeight() - 8,
        "large-font settings panel stays inside expanded window")
    assertTruthy(topOffset(settings.fontWarning) + settings.fontWarning.fontSize <= settings:GetHeight(),
        "large-font warning stays inside settings")
    settings.back:FireScript("OnClick")
    local rows = h:visibleRows()
    assertTruthy(#rows < 6 and #rows >= 3, "large fonts use fewer taller rows")
    assertEqual(h.env.DoYouNeedItFrame:GetHeight(), 300, "large-font loot stays compact")
    assertEqual(rows[1].drop.fontSize, 23, "large-font preference is honored rather than capped")
    local previousBottom = 0
    for _, row in ipairs(rows) do
        local top = topOffset(row)
        assertTruthy(top >= previousBottom, "large-font rows do not overlap")
        assertTruthy(row.looter:GetHeight() + row.status.fontSize + 4 <= row:GetHeight(), "two text lines fit inside each row")
        previousBottom = top + row:GetHeight()
        assertTruthy(previousBottom <= 292, "large-font rows stay above the window bottom")
    end
    for index = 1, 12 do
        h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    end
    rows = h:visibleRows()
    assertTruthy(rows[#rows].drop:GetText():find("22401", 1, true), "large-font scrolling still reaches oldest loot")
    h:slash("settings")
    settings.fontSizeSlider:SetValue(8)
    settings.back:FireScript("OnClick")
    rows = h:visibleRows()
    assertEqual(#rows, 6, "small font restores full six-row capacity")
    assertEqual(rows[1].drop.fontSize, 8, "small-font preference remains supported")
end

local function testSettingsTooltipDismissalIsOwnerScoped()
    for _, close in ipairs({ "back", "main" }) do
        local h, tooltip = tooltipHarness(0)
        h:slash("settings")
        local settings = h.env.DoYouNeedItSettingsFrame
        settings.autoCheck:FireScript("OnEnter")
        assertEqual(tooltip:GetOwner(), settings.autoCheck, "checkbox owns its help tooltip")
        assertEqual(tooltip:IsShown(), true, "checkbox help appears before closing settings")
        if close == "back" then
            settings.back:FireScript("OnClick")
        else
            h.env.DoYouNeedItFrame:Hide()
        end
        assertEqual(tooltip:IsShown(), false, close .. " dismisses checkbox help")

        h:slash("settings")
        settings.autoCheck:FireScript("OnEnter")
        local externalOwner = h:newFrame("Button", nil, h.env.UIParent)
        tooltip:SetOwner(externalOwner, "ANCHOR_RIGHT")
        tooltip:SetText("Unrelated help")
        tooltip:Show()
        if close == "back" then
            settings.back:FireScript("OnClick")
        else
            h.env.DoYouNeedItFrame:Hide()
        end
        assertEqual(tooltip:IsShown(), true, close .. " preserves unrelated tooltip visibility")
        assertEqual(tooltip:GetOwner(), externalOwner, close .. " preserves unrelated tooltip ownership")
        assertEqual(tooltip:GetText(), "Unrelated help", close .. " preserves unrelated tooltip text")
    end
end

local function testNewLootButtonLeavesScrolledSessionReadingIntact()
    local h = tooltipHarness(8)
    local main = h.env.DoYouNeedItFrame
    h:slash("history")
    main:FireScript("OnMouseWheel", -1)
    local anchor = h:visibleRows()[1].row
    assertEqual(main.historyButton:GetText(), "This Session", "precondition: session view selected")
    local fresh = addRealGear(h, 22440)
    assertEqual(h:visibleRows()[1].row, anchor, "new loot preserves the scrolled session row anchor")
    assertEqual(main.historyButton:GetText(), "This Session", "new loot preserves the session selection")
    assertEqual(main.newLootButton:IsShown(), true, "new loot offers a jump without moving the reader")
    main.newLootButton:FireScript("OnClick")
    assertEqual(main.historyButton:GetText(), "Current", "New loot jumps back to Current")
    assertEqual(h:visibleRows()[1].row.itemLink, fresh, "New loot jumps to the latest drop")
    assertEqual(main.newLootButton:IsShown(), false, "New loot indicator clears after jumping")
end

local function testNewLootButtonLeavesScrolledHistoryReadingIntact()
    local h = tooltipHarness(8)
    local main = h.env.DoYouNeedItFrame
    h:fire("ENCOUNTER_END", 904, "Archived Boss")
    h:runTimers(11)
    h.menuButtons = {}
    main.historyButton:FireScript("OnClick")
    assertTruthy(h.menuButtons[3], "precondition: completed history group exists")
    h.menuButtons[3].callback()
    main:FireScript("OnMouseWheel", -1)
    local anchor = h:visibleRows()[1].row
    local title = main.historyButton:GetText()
    h:fire("ENCOUNTER_START", 905, "Next Boss")
    local fresh = addRealGear(h, 22441)
    assertEqual(h:visibleRows()[1].row, anchor, "new loot keeps the historical row anchor")
    assertEqual(main.historyButton:GetText(), title, "new loot keeps the selected history title")
    h:fire("ENCOUNTER_END", 905, "Next Boss")
    h:runTimers(11)
    assertEqual(main.historyButton:GetText(), title, "new history insertion retains the earlier selected group")
    assertEqual(h:visibleRows()[1].row, anchor, "new history insertion retains the scrolled historical row")
    assertEqual(main.newLootButton:IsShown(), true, "historical reader sees the New loot shortcut")
    main.newLootButton:FireScript("OnClick")
    assertEqual(main.historyButton:GetText(), "Current", "history New loot shortcut returns to Current")
    assertEqual(h:visibleRows()[1].row.itemLink, fresh, "history shortcut reveals the latest finalized loot")
    assertEqual(main.newLootButton:IsShown(), false, "history shortcut clears the New loot indicator")
end

local function testSettingsResetPositionPersists()
    local h = Harness.new({ db = {
        windowPosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 123, y = -87 },
    } })
    h:loadAddon()
    local main = h.env.DoYouNeedItFrame
    assertEqual(main.points[1][4], 123, "precondition: saved horizontal position restored")
    h:slash("settings")
    h.env.DoYouNeedItSettingsFrame.resetPosition:FireScript("OnClick")
    assertEqual(main.points[1][1], "CENTER", "Reset Position centers the window")
    assertEqual(main.points[1][4], 0, "Reset Position clears horizontal offset")
    assertEqual(main.points[1][5], 0, "Reset Position clears vertical offset")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), true, "Reset Position keeps settings open")
    assertEqual(h.env.DoYouNeedItDB.windowPosition.point, "CENTER", "Reset Position saves the centered anchor")
    h:fire("PLAYER_LOGOUT")
    local reloaded = Harness.new({ db = h.env.DoYouNeedItDB })
    reloaded:loadAddon()
    local frame = reloaded.env.DoYouNeedItFrame
    assertEqual(frame.points[1][1], "CENTER", "centered position survives reload")
    assertEqual(frame.points[1][4], 0, "centered horizontal position survives reload")
    assertEqual(frame.points[1][5], 0, "centered vertical position survives reload")
end

local tests = {
    { "settings containment", testSettingsControlsStayInsideWindow },
    { "settings height restoration", testLeavingSettingsRestoresLootHeight },
    { "window Escape and clamping", testMainWindowEscapeAndClamping },
    { "local demo isolation", testDemoNeverSendsRealWhispers },
    { "incoming loot preserves settings", testNewLootKeepsSettingsAndDraft },
    { "history finalization preserves settings", testHistoryFinalizationKeepsSettings },
    { "recycled drop tooltip", testRecycledDropTooltipDoesNotKeepOldItem },
    { "main close dismisses tooltip", testClosingWindowHidesOwnedTooltip },
    { "settings dismiss hidden row tooltip", testOpeningSettingsHidesOwnedTooltip },
    { "unrelated tooltip ownership", testRowRefreshPreservesUnrelatedTooltip },
    { "demo persistence preserves real loot", testDemoPersistencePreservesOnlyRealLoot },
    { "demo does not create history", testDemoAloneDoesNotCreateSavedHistory },
    { "both equipped item targets", testBothEquippedItemsHaveSeparateTargets },
    { "adaptive large-font geometry", testLargeFontsAdaptRowsWithoutClipping },
    { "settings tooltip owner-scoped dismissal", testSettingsTooltipDismissalIsOwnerScoped },
    { "new loot from scrolled session", testNewLootButtonLeavesScrolledSessionReadingIntact },
    { "new loot from scrolled history", testNewLootButtonLeavesScrolledHistoryReadingIntact },
    { "settings Reset Position persists", testSettingsResetPositionPersists },
}

local failed = 0
for _, test in ipairs(tests) do
    local ok, failure = pcall(test[2])
    if ok then
        print("PASS: " .. test[1])
    else
        failed = failed + 1
        print("FAIL: " .. test[1] .. ": " .. tostring(failure))
    end
end
if failed > 0 then
    error(tostring(failed) .. " UI regression tests failed")
end
print("UI regression tests passed: " .. tostring(#tests))
