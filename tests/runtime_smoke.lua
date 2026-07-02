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
    assertTruthy(h:registered("ENCOUNTER_LOOT_RECEIVED"), "encounter loot event registered")
    assertTruthy(h:registered("CHALLENGE_MODE_COMPLETED"), "challenge completion event registered")
    assertTruthy(h:registered("INSPECT_READY"), "inspect event registered")
    assertTruthy(h.env.DoYouNeedItFrame, "main frame created on load")
    assertEqual(h.env.DoYouNeedItFrame:IsShown(), false, "main frame starts hidden")

    h:slash("settings")
    assertTruthy(h.env.DoYouNeedItSettingsFrame, "settings frame created")
    assertEqual(h.env.DoYouNeedItFrame:IsShown(), true, "settings opens inside the main frame")
    assertEqual(h.env.DoYouNeedItSettingsFrame:GetParent(), h.env.DoYouNeedItFrame, "settings panel is embedded in the main window")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), true, "settings frame opens")
    assertEqual(h.env.DoYouNeedItFrame.tabAskable:IsShown(), false, "settings mode hides loot tabs")
    assertEqual(h.env.DoYouNeedItFrame.historyButton:IsShown(), false, "settings mode hides the history selector")
    assertTruthy(h.env.DoYouNeedItSettingsFrame.back, "settings panel has a back button")
    assertTruthy(h.env.DoYouNeedItLanguageDropdown.Text:GetText() ~= "", "language dropdown has visible text")
    assertTruthy(h.env.DoYouNeedItFontDropdown.Text:GetText() ~= "", "font dropdown has visible text")

    h.env.DoYouNeedItSettingsFrame.back:FireScript("OnClick")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), false, "back closes the embedded settings panel")
    assertEqual(h.env.DoYouNeedItFrame.tabAskable:IsShown(), true, "back restores loot tabs")
    assertEqual(h.env.DoYouNeedItFrame.historyButton:IsShown(), true, "back restores the history selector")
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
    assertEqual(h.sentMessages[1].message, "Hey, do you need " .. rows[1].row.itemLink .. "?", "manual Ask uses the default whisper template")
    assertEqual(rows[1].row.manualWhispered, true, "manual Ask marks row sent")
end

local function testLootSlashCommandsLeaveEmbeddedSettingsMode()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), true, "precondition: settings panel is open")

    h:slash("test")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), false, "test command leaves embedded settings mode")
    assertEqual(h.env.DoYouNeedItFrame.tabAskable:IsShown(), true, "test command restores loot tabs")
    assertEqual(#h:visibleRows(), 1, "test command shows the test loot row")

    h:slash("settings")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), true, "precondition: settings panel reopens")

    h:slash("history")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), false, "history command leaves embedded settings mode")
    assertEqual(h.env.DoYouNeedItFrame.historyButton:IsShown(), true, "history command restores the history selector")
end

local function testLootDropLeavesEmbeddedSettingsMode()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    local item = h:addItem(22100, {
        name = "Settings Interrupt Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fireLoot("Otherplayer", item)

    assertEqual(h.env.DoYouNeedItFrame:IsShown(), true, "loot drop keeps the main frame visible")
    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), false, "loot drop leaves embedded settings mode")
    assertEqual(h.env.DoYouNeedItFrame.tabAskable:IsShown(), true, "loot drop restores loot tabs")
    assertEqual(#h:visibleRows(), 1, "loot drop shows the visible loot row")
end

local function testLeavingSettingsClosesSharedDropdown()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    h.env.UIDROPDOWNMENU_OPEN_MENU = h.env.DoYouNeedItLanguageDropdown
    h.env.DropDownList1:Show()

    h.env.DoYouNeedItSettingsFrame.back:FireScript("OnClick")

    assertEqual(h.env.DropDownList1:IsShown(), false, "leaving settings closes the shared Blizzard dropdown")
    assertEqual(h.env.UIDROPDOWNMENU_OPEN_MENU, nil, "leaving settings clears the shared dropdown owner")
end

local function testClosingMainWindowCleansSettingsPopups()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    h.env.UIDROPDOWNMENU_OPEN_MENU = h.env.DoYouNeedItLanguageDropdown
    h.env.DropDownList1:Show()

    assertEqual(h.env.DropDownList1:IsShown(), true, "precondition: shared Blizzard dropdown is open")

    h.env.DoYouNeedItFrame:Hide()

    assertEqual(h.env.DoYouNeedItSettingsFrame:IsShown(), false, "main close hides embedded settings")
    assertEqual(h.env.DropDownList1:IsShown(), false, "main close closes the shared Blizzard dropdown")
    assertEqual(h.env.UIDROPDOWNMENU_OPEN_MENU, nil, "main close clears the shared dropdown owner")

    local pickerHarness = Harness.new()
    pickerHarness:loadAddon()
    pickerHarness:slash("settings")
    pickerHarness.env.DoYouNeedItFontDropdown.Button:FireScript("OnClick")

    assertEqual(pickerHarness.env.DoYouNeedItFontPicker:IsShown(), true, "precondition: custom font picker is open")

    pickerHarness.env.DoYouNeedItFrame:Hide()

    assertEqual(pickerHarness.env.DoYouNeedItSettingsFrame:IsShown(), false, "main close hides embedded settings with the font picker open")
    assertEqual(pickerHarness.env.DoYouNeedItFontPicker:IsShown(), false, "main close closes the custom font picker")
end

local function testCustomWhisperTemplateIsUsedForManualAsk()
    local h = Harness.new({
        db = {
            settings = {
                whisperTemplate = "Could you trade {item} please?",
            },
        },
    })
    h:loadAddon()
    h:slash("test")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "custom template test has one askable row")
    rows[1].whisper:FireScript("OnClick")
    h:runTimers(0)

    assertEqual(#h.sentMessages, 1, "custom template manual Ask sends one whisper")
    assertEqual(h.sentMessages[1].message, "Could you trade " .. rows[1].row.itemLink .. " please?", "manual Ask uses saved custom whisper template")
end

local function testManualWhisperFailureLeavesRowRetryable()
    local h = Harness.new()
    h.failWhisper = true
    h:loadAddon()
    h:slash("test")

    local rows = h:visibleRows()
    rows[1].whisper:FireScript("OnClick")
    h:runTimers(0)

    assertEqual(rows[1].row.statusKey, "whisper_failed", "failed manual whisper stores a stable failure status")
    assertEqual(rows[1].row.manualWhispered, nil, "failed manual whisper does not mark the row sent")
    assertEqual(rows[1].row.whisperInFlight, false, "failed manual whisper clears in-flight state")
    assertEqual(rows[1].whisper:IsEnabled(), true, "failed manual whisper leaves Ask retry enabled")
end

local function testMainWindowLayoutBoundsLongText()
    local h = Harness.new()
    h:loadAddon()
    h:slash("test")

    local frame = h.env.DoYouNeedItFrame
    assertTruthy(frame and frame.historyButton, "main window history button exists")
    assertTruthy(frame.historyButton:GetWidth() <= 270, "history selector leaves room for settings and close buttons")
    assertTruthy(frame.tabAskable:GetWidth() >= 104, "askable tab has enough width for localized labels")
    assertTruthy(frame.tabAllGear:GetWidth() >= 82, "all gear tab has enough width for localized labels")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "layout test has one visible row")
    local row = rows[1]
    local fontStrings = {
        row.looter,
        row.drop,
        row.equipped,
        row.status,
    }
    for index = 1, #fontStrings do
        assertEqual(fontStrings[index].maxLines, 1, "row font string " .. index .. " is capped to one line")
        assertEqual(fontStrings[index].wordWrap, false, "row font string " .. index .. " disables word wrap")
        assertEqual(fontStrings[index].nonSpaceWrap, false, "row font string " .. index .. " disables non-space wrap")
    end

    assertTruthy(row.drop:GetWidth() <= row.dropLink:GetWidth(), "drop hover target covers clipped drop text")
    assertTruthy(row.equipped:GetWidth() <= row.equippedLink:GetWidth(), "equipped hover target covers clipped equipped text")
    assertTruthy(row.status:GetWidth() <= 420, "status text leaves room for the Ask button column")
end

local function testCyrillicLootTextUsesGlyphCapableFont()
    local h = Harness.new({
        db = {
            settings = {
                font = "Fonts\\FRIZQT__.TTF",
            },
        },
    })
    h:setUnit("party1", {
        name = "Игрок",
        realm = "Ravencrest",
        guid = "CyrillicGUID",
        classToken = "PALADIN",
    })
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22001, {
        name = "Eye of the Drowning Void",
        equipLoc = "INVTYPE_TRINKET",
        classID = 4,
        subclassID = 0,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fireLoot("Игрок", item)

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "cyrillic looter row is visible")
    assertEqual(rows[1].looter.font, "Fonts\\ARIALN.TTF", "cyrillic looter name falls back to Arial Narrow")
    assertEqual(rows[1].drop.font, "Fonts\\FRIZQT__.TTF", "latin item text keeps the selected Friz font")
    assertEqual(h.env.DoYouNeedItFrame.title.font, "Fonts\\FRIZQT__.TTF", "main title keeps the selected Friz font")
end

local function testLootLooterNameUsesClassColor()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22002, {
        name = "Class Color Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fireLoot("Otherplayer", item)

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "class-color loot row is visible")
    assertEqual(rows[1].row.classToken, "PALADIN", "loot row stores the looter class token")
    assertEqual(h.env.DoYouNeedItDB.sessionRows[1].classToken, "PALADIN", "saved loot row keeps the looter class token")
    assertEqual(rows[1].looter.textColor[1], 0.96, "paladin looter color red channel")
    assertEqual(rows[1].looter.textColor[2], 0.55, "paladin looter color green channel")
    assertEqual(rows[1].looter.textColor[3], 0.73, "paladin looter color blue channel")
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

local function testInstanceChangeHistoryTitleUsesActiveLocale()
    local h = Harness.new({
        db = {
            settings = { forceLocale = "ruRU", font = "Fonts\\ARIALN.TTF" },
        },
    })
    h:loadAddon()
    h:slash("test")

    h.instanceName = "Halls of Infusion"
    h:fire("PLAYER_ENTERING_WORLD")

    assertEqual(#h.env.DoYouNeedItDB.history, 1, "localized instance change saves current drops to history")
    assertTruthy(h.env.DoYouNeedItDB.history[1].title:find("%(2 дропа%)"), "history title uses localized drop-count wording")
    assertEqual(h.env.DoYouNeedItDB.history[1].title:find("drops", 1, true), nil, "history title does not keep English drop-count wording")
end

local function testChallengeCompletionKeepsEndLootInHistory()
    local h = Harness.new()
    h:loadAddon()

    h:fire("CHALLENGE_MODE_COMPLETED")
    local item = h:addItem(22003, {
        name = "End Chest Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })
    h:fireLoot("Otherplayer", item)

    assertEqual(#h.env.DoYouNeedItDB.history, 0, "challenge end loot waits briefly for more chest drops")
    h:runTimers(3)

    assertEqual(#h.env.DoYouNeedItDB.history, 1, "challenge completion moves end loot to history")
    assertTruthy(h.env.DoYouNeedItDB.history[1].title:find("Ruby Life Pools", 1, true), "challenge history uses dungeon name")
    assertEqual(#h.env.DoYouNeedItDB.history[1].allRows, 1, "challenge history keeps all-gear end loot")
    assertEqual(#h.env.DoYouNeedItDB.characters["Player-Ravencrest"].history, 1, "challenge history is saved in the character bucket")

    h.env.DoYouNeedItFrame.historyButton:FireScript("OnClick")
    assertTruthy(h.menuButtons[3] and h.menuButtons[3].text:find("Ruby Life Pools", 1, true), "history menu lists the completed challenge group")
end

local function testPostEncounterLootMovesToHistoryAfterGrace()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    h:fire("ENCOUNTER_END", 777, "After End Boss")
    local item = h:addItem(22014, {
        name = "After End Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 777, 22014, item, 1, "Otherplayer", "PALADIN")

    assertEqual(#h.env.DoYouNeedItDB.history, 0, "post-encounter loot waits briefly for more loot rows")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "post-encounter loot is visible before the history finalize timer")
    h:runTimers(3)

    assertEqual(#h.env.DoYouNeedItDB.history, 1, "post-encounter loot moves into history after the grace timer")
    assertTruthy(h.env.DoYouNeedItDB.history[1].title:find("After End Boss", 1, true), "post-encounter history keeps the ended boss name")
    assertEqual(#h.env.DoYouNeedItDB.history[1].allRows, 1, "post-encounter history keeps all-gear loot")
end

local function testEncounterLootReceivedCreatesLootRow()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22004, {
        name = "Encounter Event Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22004, item, 1, "Otherplayer", "PALADIN")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "encounter loot event creates a visible row")
    assertTruthy(rows[1].drop:GetText():find("Encounter Event Sword", 1, true), "encounter loot row shows the item link")
    assertEqual(h.env.DoYouNeedItDB.sessionRows[1].itemID, 22004, "encounter loot persists to session rows")
end

local function testEncounterLootUsesEventClassTokenWhenRosterClassMissing()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    h.units.party1.classToken = nil

    local item = h:addItem(22015, {
        name = "Event Class Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22015, item, 1, "Otherplayer", "DEATHKNIGHT")

    assertEqual(h.env.DoYouNeedItDB.sessionRows[1].classToken, "DEATHKNIGHT", "encounter loot keeps the event class token")
    local rows = h:visibleRows()
    assertEqual(rows[1].looter.textColor[1], 0.77, "encounter event class colors the looter name")
end

local function testEncounterAndChatLootDeduplicateSameDrop()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22005, {
        name = "Deduped Event Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22005, item, 1, "Otherplayer", "PALADIN")
    h:fireLoot("Otherplayer", item)

    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "same encounter/chat loot is saved once in askable session")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "same encounter/chat loot is saved once in all-gear session")
    assertEqual(#h:visibleRows(), 1, "same encounter/chat loot is visible once")
end

local function testBonusLootChatIsAllGearOnlyWithSourceIcon()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22006, {
        name = "Bonus Roll Gloves",
        equipLoc = "INVTYPE_HAND",
        classID = 4,
        subclassID = 4,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fireBonusLoot("Otherplayer", item)

    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "other bonus loot is not saved as askable")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "other bonus loot is saved in all gear")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].lootSource, "bonus_roll", "other bonus loot stores its source")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "bonus_roll", "other bonus loot stores a stable display status")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "other bonus loot appears in the all gear view")
    assertEqual(rows[1].row.askable, false, "visible bonus loot row is not askable")
    assertEqual(rows[1].whisper:IsShown(), false, "visible bonus loot row has no Ask button")
    assertTruthy(rows[1].rollIcon and rows[1].rollIcon:IsShown(), "visible bonus loot row shows the roll source icon")
    assertEqual(rows[1].rollIcon.atlas, "lootroll-toast-icon-need-up", "visible bonus loot row uses Blizzard's roll atlas")

    h.env.DoYouNeedItFrame.tabAskable:FireScript("OnClick")
    assertEqual(#h:visibleRows(), 0, "other bonus loot is hidden from the askable tab")
end

local function testBonusLootChatUpgradesEarlierEncounterRow()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22007, {
        name = "Encounter Then Bonus Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22007, item, 1, "Otherplayer", "PALADIN")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "encounter loot starts as askable before source is known")

    h:fireBonusLoot("Otherplayer", item)

    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "later bonus loot chat removes the earlier askable row")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "later bonus loot chat keeps one all-gear row")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].lootSource, "bonus_roll", "later bonus loot chat source-tags the existing row")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "bonus_roll", "later bonus loot chat updates the existing row status")
end

local function testLateBonusLootChatUpgradesOutsideDedupeWindow()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22013, {
        name = "Late Bonus Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22013, item, 1, "Otherplayer", "PALADIN")
    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 1, "encounter loot starts as askable before late source is known")
    h.now = h.now + 20

    h:fireBonusLoot("Otherplayer", item)

    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "late bonus loot outside dedupe removes the askable row")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "late bonus loot outside dedupe does not duplicate all gear")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].lootSource, "bonus_roll", "late bonus loot outside dedupe source-tags the existing row")
end

local function testBonusLootUpgradeCancelsInFlightAutoWhisper()
    local h = Harness.new({
        db = {
            settings = {
                autoWhisper = true,
                autoDelay = 5,
                font = "Fonts\\FRIZQT__.TTF",
            },
        },
    })
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22010, {
        name = "In Flight Bonus Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fireLoot("Otherplayer", item)
    assertEqual(h.env.DoYouNeedItDB.sessionRows[1].statusKey, "candidate", "saved auto-pending row stays persistently candidate")

    local autoTimerIndex
    for index = 1, #h.timers do
        if h.timers[index].delay == 5 then
            autoTimerIndex = index
            break
        end
    end
    assertTruthy(autoTimerIndex, "auto whisper delay timer is queued")
    local autoTimer = table.remove(h.timers, autoTimerIndex)
    autoTimer.callback()
    local rows = h:visibleRows()
    assertEqual(#rows, 1, "auto whisper row is still tracked before the deferred send")
    assertEqual(rows[1].row.whisperInFlight, true, "auto whisper is in flight before the zero-delay send")

    h:fireBonusLoot("Otherplayer", item)
    h:runTimers(0, 10)

    assertEqual(#h.sentMessages, 0, "bonus loot upgrade cancels the deferred auto whisper send")
    assertEqual(h.env.DoYouNeedItDB.sessionRows[1], nil, "bonus loot upgrade removes the row from askable session")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "bonus_roll", "bonus loot upgrade still saves the row as bonus all gear")
end

local function testBonusLootChatUpgradesPendingEncounterRowBeforeItemLoads()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22009, {
        name = "Pending Then Bonus Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
        cacheLoaded = false,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22009, item, 1, "Otherplayer", "PALADIN")
    assertEqual(#(h.env.DoYouNeedItDB.sessionRows or {}), 0, "uncached encounter loot waits for item metadata")
    h:fireBonusLoot("Otherplayer", item)
    h:runTimers(0, 10)

    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "bonus loot source on a pending row keeps it out of askable")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "bonus loot source on a pending row still saves all gear")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].lootSource, "bonus_roll", "bonus loot source survives pending item load")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].statusKey, "bonus_roll", "pending bonus loot row renders with bonus status")
end

local function testBonusLootChatUpgradesEarlierCompletedHistoryRow()
    local h = Harness.new()
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local item = h:addItem(22008, {
        name = "History Then Bonus Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22008, item, 1, "Otherplayer", "PALADIN")
    h:fire("ENCOUNTER_END", 123, "Late Bonus Boss")
    assertEqual(#h.env.DoYouNeedItDB.history, 1, "encounter completion saves the first loot row to history")
    assertEqual(#h.env.DoYouNeedItDB.history[1].rows, 1, "history initially treats the earlier encounter row as askable")

    h:fireBonusLoot("Otherplayer", item)

    assertEqual(#h.env.DoYouNeedItDB.sessionRows, 0, "late bonus loot chat removes the completed row from session askable")
    assertEqual(#h.env.DoYouNeedItDB.history[1].rows, 0, "late bonus loot chat removes the completed row from history askable")
    assertEqual(#h.env.DoYouNeedItDB.history[1].allRows, 1, "late bonus loot chat keeps the completed row in history all gear")
    assertEqual(h.env.DoYouNeedItDB.history[1].allRows[1].lootSource, "bonus_roll", "late bonus loot chat source-tags the completed history row")
end

local function testBonusLootChatUpgradesHistoryRowAfterSessionPrune()
    local h = Harness.new({
        db = {
            settings = {
                maxSessionRows = 1,
                font = "Fonts\\FRIZQT__.TTF",
            },
        },
    })
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()

    local firstItem = h:addItem(22011, {
        name = "Pruned History Bonus Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })
    local secondItem = h:addItem(22012, {
        name = "Later Normal Sword",
        equipLoc = "INVTYPE_WEAPON",
        classID = 2,
        subclassID = 7,
        quality = 4,
        bindType = 2,
        equippable = true,
        usable = true,
    })

    h:fire("ENCOUNTER_LOOT_RECEIVED", 123, 22011, firstItem, 1, "Otherplayer", "PALADIN")
    h:fire("ENCOUNTER_END", 123, "Pruned Bonus Boss")
    h:fire("ENCOUNTER_LOOT_RECEIVED", 124, 22012, secondItem, 1, "Otherplayer", "PALADIN")
    assertEqual(#h.env.DoYouNeedItDB.sessionAllRows, 1, "session all gear prunes to the configured limit")
    assertEqual(h.env.DoYouNeedItDB.sessionAllRows[1].itemID, 22012, "session all gear pruned away the earlier row")
    assertEqual(#h.env.DoYouNeedItDB.history[1].rows, 1, "history still has the earlier row as askable")

    h:fireBonusLoot("Otherplayer", firstItem)

    assertEqual(#h.env.DoYouNeedItDB.history[1].rows, 0, "late bonus loot upgrades history-only askable rows")
    assertEqual(#h.env.DoYouNeedItDB.history[1].allRows, 1, "late bonus loot keeps the history-only row in all gear")
    assertEqual(h.env.DoYouNeedItDB.history[1].allRows[1].lootSource, "bonus_roll", "late bonus loot source-tags the history-only row")
end

local function testDebugPersistenceIsOptIn()
    local h = Harness.new()
    h:loadAddon()

    h:slash("scan")
    assertFalsy(h.env.DoYouNeedItDB.diagnostics, "debug off does not persist scan diagnostics")
    h:slash("diag")
    assertTruthy(h.messages[#h.messages]:find("debug diagnostics are off", 1, true), "debug-off diag reports disabled diagnostics")
    assertEqual(h.messages[#h.messages]:find("diag 1:", 1, true), nil, "debug-off diag does not reveal in-memory diagnostic entries")

    h:slash("debug on")
    assertEqual(type(h.env.DoYouNeedItDB.diagnostics), "table", "debug on creates diagnostic buffer")
    assertEqual(#h.env.DoYouNeedItDB.diagnostics, 0, "debug on starts with a fresh diagnostic buffer")
    h:slash("scan")
    assertEqual(#h.env.DoYouNeedItDB.diagnostics, 1, "debug on persists new diagnostics")
    h:slash("diag")
    assertTruthy(h.messages[#h.messages]:find("diag 1:", 1, true), "debug-on diag prints diagnostic entries")

    h:slash("debug off")
    assertFalsy(h.env.DoYouNeedItDB.diagnostics, "debug off clears persisted diagnostics")
    h:slash("scan")
    assertFalsy(h.env.DoYouNeedItDB.diagnostics, "debug off stops later diagnostic persistence")
    h:slash("diag")
    assertTruthy(h.messages[#h.messages]:find("debug diagnostics are off", 1, true), "debug-off diag stays disabled after toggling off")
    assertEqual(h.messages[#h.messages]:find("diag 1:", 1, true), nil, "debug-off diag stays quiet after toggling off")
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
            characters = {
                ["Player-Ravencrest"] = {
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

local function testAccountWideSavedDropsDoNotLeakIntoCharacterHistory()
    local h = Harness.new({
        db = {
            settings = { font = "Fonts\\FRIZQT__.TTF" },
            sessionRows = {
                {
                    id = "account-wide-session",
                    looter = "Otherplayer-Ravencrest",
                    itemLink = "|cff0070dd|Hitem:30011:::::::::::::|h[Other Character Session]|h|r",
                    equippedText = "Equipped: unknown",
                    askable = true,
                },
            },
            sessionAllRows = {
                {
                    id = "account-wide-all",
                    looter = "Otherplayer-Ravencrest",
                    itemLink = "|cff0070dd|Hitem:30012:::::::::::::|h[Other Character All]|h|r",
                    equippedText = "Equipped: unknown",
                    askable = false,
                },
            },
            history = {
                {
                    title = "Other Character Boss",
                    rows = {
                        {
                            id = "account-wide-history",
                            looter = "Otherplayer-Ravencrest",
                            itemLink = "|cff0070dd|Hitem:30013:::::::::::::|h[Other Character History]|h|r",
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
    assertEqual(#h:visibleRows(), 0, "account-wide legacy session rows do not show for the current character")
    h:slash("history")
    assertEqual(#h:visibleRows(), 0, "account-wide legacy history groups do not show for the current character")
    assertTruthy(h.env.DoYouNeedItDB.characters, "per-character drop buckets are created")
    assertTruthy(h.env.DoYouNeedItDB.characters["Player-Ravencrest"], "current character gets a drop bucket")
    assertEqual(#(h.env.DoYouNeedItDB.characters["Player-Ravencrest"].sessionRows or {}), 0, "current character session starts empty")
    assertTruthy(h.env.DoYouNeedItDB.legacyAccountDrops, "old account-wide drops are preserved separately")
    assertEqual(#(h.env.DoYouNeedItDB.legacyAccountDrops.sessionRows or {}), 1, "legacy backup keeps old session rows")
    assertEqual(#(h.env.DoYouNeedItDB.legacyAccountDrops.history or {}), 1, "legacy backup keeps old history groups")
end

local function testDelayedPlayerIdentityLoadsCharacterDrops()
    local savedItem = "|cff0070dd|Hitem:30014:::::::::::::|h[Delayed Identity Sword]|h|r"
    local h = Harness.new({
        db = {
            settings = { font = "Fonts\\FRIZQT__.TTF" },
            characters = {
                ["Player-Ravencrest"] = {
                    sessionRows = {
                        {
                            id = "delayed-identity-session",
                            looter = "Otherplayer-Ravencrest",
                            itemLink = savedItem,
                            equippedText = "Equipped: unknown",
                            askable = true,
                        },
                    },
                },
            },
        },
    })
    h.units.player = nil
    h:loadAddon()
    h:slash("history")
    assertEqual(#h:visibleRows(), 0, "precondition: unavailable player identity does not load another character's session rows")

    h:setUnit("player", { name = "Player", realm = "Ravencrest", guid = "PlayerGUID", classToken = "WARRIOR" })
    h:fire("PLAYER_ENTERING_WORLD")

    assertEqual(h.env.DoYouNeedItDB.currentCharacter, "Player-Ravencrest", "entering world repairs the saved character key")
    assertEqual(#h:visibleRows(), 1, "entering world loads the real character's saved session rows")
    assertEqual(h:visibleRows()[1].row.id, "delayed-identity-session", "delayed identity keeps the real character row payload")
end

local function testLegacySavedRowBackfillsLooterClassColor()
    local h = Harness.new({
        db = {
            settings = { font = "Fonts\\FRIZQT__.TTF" },
            characters = {
                ["Player-Ravencrest"] = {
                    sessionRows = {
                        {
                            id = "legacy-class-row",
                            looter = "Otherplayer-Ravencrest",
                            itemLink = "|cff0070dd|Hitem:30003:::::::::::::|h[Legacy Class Sword]|h|r",
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

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "legacy class-color row is visible")
    assertEqual(rows[1].row.classToken, "PALADIN", "legacy row backfills the looter class token from the current roster")
    assertEqual(rows[1].looter.textColor[1], 0.96, "legacy paladin looter color red channel")
    assertEqual(rows[1].looter.textColor[2], 0.55, "legacy paladin looter color green channel")
    assertEqual(rows[1].looter.textColor[3], 0.73, "legacy paladin looter color blue channel")
end

local function testLegacyPlainItemTextDoesNotCreateDropHoverTarget()
    local h = Harness.new({
        db = {
            settings = { font = "Fonts\\FRIZQT__.TTF" },
            characters = {
                ["Player-Ravencrest"] = {
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

local function testLocalizedEquippedDisplayKeepsSavedTextStable()
    local h = Harness.new({
        db = {
            settings = { forceLocale = "ruRU", font = "Fonts\\ARIALN.TTF" },
        },
    })
    h:loadAddon()
    h:slash("test")

    local rows = h:visibleRows()
    assertEqual(#rows, 1, "localized test row is visible")
    assertTruthy(rows[1].equipped:GetText():find("Надето:", 1, true), "equipped display label is localized")
    assertTruthy(rows[1].equipped:GetText():find("Worn Shortsword", 1, true), "localized equipped display keeps the item link text")
    assertTruthy(rows[1].row.equippedText:find("Equipped:", 1, true), "stored equipped text remains migration-stable")

    local cachedLink = "|cff1eff00|Hitem:25:::::::::::::|h[Cached Worn Shortsword]|h|r"
    local cached = Harness.new({
        db = {
            settings = { forceLocale = "ruRU", font = "Fonts\\ARIALN.TTF" },
            characters = {
                ["Player-Ravencrest"] = {
                    sessionRows = {
                        {
                            id = "cached-display",
                            looter = "Otherplayer-Ravencrest",
                            itemLink = "|cff0070dd|Hitem:30001:::::::::::::|h[Cached Drop]|h|r",
                            equippedText = "Cached: " .. cachedLink,
                            askable = true,
                        },
                    },
                },
            },
        },
    })
    cached:loadAddon()
    cached:slash("history")

    rows = cached:visibleRows()
    assertEqual(#rows, 1, "cached session row is visible")
    assertTruthy(rows[1].equipped:GetText():find("Кэш:", 1, true), "cached equipped display label is localized")
    assertTruthy(rows[1].equipped:GetText():find("Cached Worn Shortsword", 1, true), "localized cached display keeps the item link text")
    assertTruthy(rows[1].row.equippedText:find("Cached:", 1, true), "stored cached text remains migration-stable")
end

local function testHistoryMenuUsesLocalizedStaticLabels()
    local h = Harness.new({
        db = {
            settings = { forceLocale = "ruRU", font = "Fonts\\ARIALN.TTF" },
            characters = {
                ["Player-Ravencrest"] = {
                    history = {
                        {
                            rows = {},
                            allRows = {},
                        },
                    },
                },
            },
        },
    })
    h:loadAddon()
    h:slash("test")

    h.env.DoYouNeedItFrame.historyButton:FireScript("OnClick")

    assertEqual(h.menuButtons[1].text, "Текущий", "history menu localizes the current view entry")
    assertEqual(h.menuButtons[2].text, "Эта сессия", "history menu localizes the session view entry")
    assertEqual(h.menuButtons[3].text, "История 1", "history menu localizes fallback history entry titles")
end

local function testMissingSavedFontPathRepairsToAvailableFont()
    local staleFontPath = "Interface\\AddOns\\RemovedFontPack\\Gone.ttf"
    local h = Harness.new({
        db = {
            settings = { font = staleFontPath },
        },
        lsmFonts = {
            { name = "Readable One", path = "Interface\\AddOns\\Readable\\One.ttf" },
        },
    })
    h:loadAddon()

    assertEqual(h.env.DoYouNeedItDB.settings.font, "Fonts\\FRIZQT__.TTF", "load repairs a saved font path that is no longer available")
    assertEqual(h.env.DoYouNeedItFrame.title.font, "Fonts\\FRIZQT__.TTF", "main window uses the repaired font")

    h:slash("settings")
    assertEqual(h.env.DoYouNeedItFontDropdown.Text:GetText(), "Friz Quadrata TT", "font caption names the repaired font")
end

local function testForcedCjkLocalesUseLocaleSpecificBlizzardFontsOnWesternClients()
    local cases = {
        { locale = "koKR", font = "Fonts\\2002.ttf" },
        { locale = "zhCN", font = "Fonts\\ARKai_T.ttf" },
        { locale = "zhTW", font = "Fonts\\bHEI00M.ttf" },
    }
    for index = 1, #cases do
        local case = cases[index]
        local h = Harness.new({
            db = {
                settings = {
                    forceLocale = case.locale,
                    font = "Fonts\\FRIZQT__.TTF",
                },
            },
            lsmFonts = {},
        })
        h:loadAddon()

        assertEqual(h.env.DoYouNeedItDB.settings.font, case.font, case.locale .. " load switches to a locale-capable Blizzard font")
        assertEqual(h.env.DoYouNeedItFrame.title.font, case.font, case.locale .. " main title uses the locale-capable Blizzard font")
    end
end

local function testCustomFontPickerGridPreviewAndCommit()
    local brokenFontPath = "Interface\\AddOns\\Broken\\Unreadable.ttf"
    local h = Harness.new({
        lsmFonts = {
            { name = "Readable One", path = "Interface\\AddOns\\Readable\\One.ttf" },
            { name = "Readable Two", path = "Interface\\AddOns\\Readable\\Two.ttf" },
            { name = "Broken Font", path = brokenFontPath },
            { name = "Readable Four", path = "Interface\\AddOns\\Readable\\Four.ttf" },
        },
    })
    h:loadAddon()
    h:slash("settings")

    local settingsFrame = h.env.DoYouNeedItSettingsFrame
    local fontDropdown = h.env.DoYouNeedItFontDropdown
    assertTruthy(settingsFrame and settingsFrame.title, "settings title exists")
    assertTruthy(fontDropdown and fontDropdown.Button, "font dropdown button exists")

    fontDropdown.Button:FireScript("OnClick")
    local picker = h.env.DoYouNeedItFontPicker
    assertTruthy(picker and picker:IsShown(), "font button opens the custom picker")
    assertEqual(h.env.DropDownList1:IsShown(), false, "font picker does not use Blizzard shared dropdown list")

    local brokenButton = h:findFrame(function(frame)
        return frame.fontPath == brokenFontPath
    end, picker)
    assertTruthy(brokenButton and brokenButton.text, "broken font option is present in the custom picker")

    local firstButton = h:findFrame(function(frame)
        return frame.fontName == "Friz Quadrata TT"
    end, picker)
    local secondButton = h:findFrame(function(frame)
        return frame.fontName == "Arial Narrow"
    end, picker)
    local fourthButton = h:findFrame(function(frame)
        return frame.fontName == "Readable One"
    end, picker)
    assertTruthy(firstButton and secondButton and fourthButton, "picker has enough font buttons to prove grid layout")
    assertEqual(firstButton.points[1][3], secondButton.points[1][3], "first-row font buttons share a row")
    assertTruthy(firstButton.points[1][2] ~= secondButton.points[1][2], "first-row font buttons use different columns")
    assertTruthy(fourthButton.points[1][3] < firstButton.points[1][3], "fourth font starts the next row")

    brokenButton:FireScript("OnEnter")

    assertEqual(h.env.DoYouNeedItFrame.title.font, brokenFontPath, "font hover previews on the main window")
    assertEqual(settingsFrame.title.font == brokenFontPath, false, "font hover does not apply preview font to settings title")
    assertEqual(h.env.DoYouNeedItLanguageDropdown.Text.font == brokenFontPath, false, "font hover does not apply preview font to language caption")
    assertEqual(h.env.DoYouNeedItFontDropdown.Text.font == brokenFontPath, false, "font hover does not apply preview font to font caption")
    assertTruthy(h.env.DoYouNeedItLanguageDropdown.Text:GetText() ~= "", "language caption survives font hover")
    assertTruthy(h.env.DoYouNeedItFontDropdown.Text:GetText() ~= "", "font caption survives font hover")

    brokenButton:FireScript("OnLeave")
    h:runTimers(0, 10)
    assertEqual(h.env.DoYouNeedItFrame.title.font == brokenFontPath, false, "leaving a font option restores the committed font")

    brokenButton:FireScript("OnClick")
    assertEqual(h.env.DoYouNeedItDB.settings.font, brokenFontPath, "clicking a font option saves the font")
    assertEqual(picker:IsShown(), false, "clicking a font option closes the custom picker")
    assertEqual(h.env.DoYouNeedItFontDropdown.Text:GetText(), "Broken Font", "font caption updates after choosing a font")
end

local function testLanguageDropdownCloseRepairsCaptionsAfterSharedListCleanup()
    local h = Harness.new({
        blankSettingsDropdownCaptionsAfterListHide = true,
    })
    h:loadAddon()
    h:slash("settings")

    local languageDropdown = h.env.DoYouNeedItLanguageDropdown
    languageDropdown.Button:FireScript("OnClick")
    h:runTimers(0, 10)
    h.dropdownAdds = {}
    h.env.UIDROPDOWNMENU_OPEN_MENU = languageDropdown
    languageDropdown.initialize()
    h.env.DropDownList1:Show()

    local languageButton = h:findFrame(function(frame)
        return frame.value == "ruRU"
    end, h.env.DropDownList1)
    assertTruthy(languageButton, "language option is present")
    languageButton:FireScript("OnEnter")
    h.env.DropDownList1:Hide()
    h:runTimers(0, 10)

    assertTruthy(h.env.DoYouNeedItLanguageDropdown.Text:GetText() ~= "", "language caption is repaired after dropdown cleanup")
    assertTruthy(h.env.DoYouNeedItFontDropdown.Text:GetText() ~= "", "font caption is repaired after dropdown cleanup")
end

local function testSettingsSliderTemplateTextDoesNotLeak()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    local frame = h.env.DoYouNeedItSettingsFrame
    assertTruthy(frame.delaySlider and frame.delaySlider.Text, "delay slider template text exists")
    assertTruthy(frame.fontSizeSlider and frame.fontSizeSlider.Text, "font size slider template text exists")
    assertEqual(frame.delaySlider.Text:GetText(), "", "delay slider hides unused template value text")
    assertEqual(frame.fontSizeSlider.Text:GetText(), "", "font size slider hides unused template value text")
end

local function testSettingsControlsUseFixedColumnLayout()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    local frame = h.env.DoYouNeedItSettingsFrame
    assertTruthy(frame, "settings frame exists")
    assertTruthy((frame.delayLabel:GetWidth() or 999) <= 96, "delay label is width-bounded")
    assertTruthy((frame.whisperLabel:GetWidth() or 999) <= 96, "whisper label is width-bounded")
    assertTruthy((frame.languageLabel:GetWidth() or 999) <= 96, "language label is width-bounded")
    assertTruthy((frame.fontLabel:GetWidth() or 999) <= 96, "font label is width-bounded")
    assertTruthy((frame.fontSizeLabel:GetWidth() or 999) <= 96, "font size label is width-bounded")

    assertEqual(frame.delaySlider.points[1][2], frame, "delay slider is anchored to the settings frame column")
    assertEqual(frame.whisperEditBox.points[1][2], frame, "whisper edit box is anchored to the settings frame column")
    assertEqual(frame.languageDropdown.points[1][2], frame, "language dropdown is anchored to the settings frame column")
    assertEqual(frame.fontDropdown.points[1][2], frame, "font dropdown is anchored to the settings frame column")
    assertEqual(frame.fontSizeSlider.points[1][2], frame, "font size slider is anchored to the settings frame column")

    local labels = {
        frame.delayLabel,
        frame.whisperLabel,
        frame.languageLabel,
        frame.fontLabel,
        frame.fontSizeLabel,
    }
    for index = 1, #labels do
        assertEqual(labels[index].maxLines, 1, "settings label " .. index .. " is capped to one line")
        assertEqual(labels[index].wordWrap, false, "settings label " .. index .. " disables word wrap")
        assertEqual(labels[index].nonSpaceWrap, false, "settings label " .. index .. " disables non-space wrap")
    end
end

local function testSettingsWhisperTemplateEditBoxSaves()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    local frame = h.env.DoYouNeedItSettingsFrame
    assertTruthy(frame.whisperEditBox, "whisper template edit box exists")
    assertTruthy(frame.whisperResetButton, "whisper template reset button exists")

    frame.whisperEditBox:SetText("Need {item} for transmog?")
    frame.whisperEditBox:FireScript("OnEnterPressed")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, "Need {item} for transmog?", "whisper template edit box saves custom text")

    frame.whisperEditBox:SetText("")
    frame.whisperEditBox:FireScript("OnEnterPressed")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, "Hey, do you need {item}?", "empty whisper edit box saves default fallback")

    frame.whisperEditBox:SetText("temporary")
    frame.whisperResetButton:FireScript("OnClick")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, "Hey, do you need {item}?", "whisper template reset button restores default")
    assertEqual(frame.whisperEditBox:GetText(), "Hey, do you need {item}?", "whisper template reset refreshes edit box text")
end

local function testSettingsRefreshKeepsFocusedWhisperDraft()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    local frame = h.env.DoYouNeedItSettingsFrame
    local draft = "Could you spare {item}?"
    frame.whisperEditBox:FireScript("OnEditFocusGained")
    frame.whisperEditBox:SetText(draft)

    frame.fontSizeSlider:SetValue(13)
    assertEqual(frame.whisperEditBox:GetText(), draft, "settings refresh keeps focused whisper template draft")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, "Hey, do you need {item}?", "focused whisper draft is not saved before commit")

    frame.whisperEditBox:FireScript("OnEditFocusLost")
    assertEqual(h.env.DoYouNeedItDB.settings.whisperTemplate, draft, "focused whisper draft saves on focus loss")
end

local function testSettingsCloseSavesFocusedWhisperDraft()
    local h = Harness.new()
    h:loadAddon()
    h:slash("settings")

    local frame = h.env.DoYouNeedItSettingsFrame
    local draft = "Mind trading {item}?"
    frame.whisperEditBox:FireScript("OnEditFocusGained")
    frame.whisperEditBox:SetText(draft)

    frame:Hide()
    assertEqual((h.env.DoYouNeedItDB.settings or {}).whisperTemplate, draft, "closing settings saves focused whisper template draft")
    assertEqual(frame.whisperEditBox:GetText(), draft, "closing settings does not overwrite the saved whisper template draft")
end

testLoadAndSettings()
testSlashTestRowsAndManualWhisper()
testLootSlashCommandsLeaveEmbeddedSettingsMode()
testLootDropLeavesEmbeddedSettingsMode()
testLeavingSettingsClosesSharedDropdown()
testClosingMainWindowCleansSettingsPopups()
testCustomWhisperTemplateIsUsedForManualAsk()
testManualWhisperFailureLeavesRowRetryable()
testMainWindowLayoutBoundsLongText()
testCyrillicLootTextUsesGlyphCapableFont()
testLootLooterNameUsesClassColor()
testInstanceChangeCompletesCurrentGroup()
testInstanceChangeHistoryTitleUsesActiveLocale()
testChallengeCompletionKeepsEndLootInHistory()
testPostEncounterLootMovesToHistoryAfterGrace()
testEncounterLootReceivedCreatesLootRow()
testEncounterLootUsesEventClassTokenWhenRosterClassMissing()
testEncounterAndChatLootDeduplicateSameDrop()
testBonusLootChatIsAllGearOnlyWithSourceIcon()
testBonusLootChatUpgradesEarlierEncounterRow()
testLateBonusLootChatUpgradesOutsideDedupeWindow()
testBonusLootUpgradeCancelsInFlightAutoWhisper()
testBonusLootChatUpgradesPendingEncounterRowBeforeItemLoads()
testBonusLootChatUpgradesEarlierCompletedHistoryRow()
testBonusLootChatUpgradesHistoryRowAfterSessionPrune()
testDebugPersistenceIsOptIn()
testDebugPersistenceLoadState()
testLegacySavedAllGearFallbackDisplays()
testAccountWideSavedDropsDoNotLeakIntoCharacterHistory()
testDelayedPlayerIdentityLoadsCharacterDrops()
testLegacySavedRowBackfillsLooterClassColor()
testLegacyPlainItemTextDoesNotCreateDropHoverTarget()
testLocalizedEquippedDisplayKeepsSavedTextStable()
testHistoryMenuUsesLocalizedStaticLabels()
testMissingSavedFontPathRepairsToAvailableFont()
testForcedCjkLocalesUseLocaleSpecificBlizzardFontsOnWesternClients()
testCustomFontPickerGridPreviewAndCommit()
testLanguageDropdownCloseRepairsCaptionsAfterSharedListCleanup()
testSettingsSliderTemplateTextDoesNotLeak()
testSettingsControlsUseFixedColumnLayout()
testSettingsWhisperTemplateEditBoxSaves()
testSettingsRefreshKeepsFocusedWhisperDraft()
testSettingsCloseSavesFocusedWhisperDraft()

print("runtime smoke ok")
