local Harness = dofile("tests/runtime_harness.lua")
local count = 0
local function check(value, label)
    count = count + 1
    assert(value, label)
end
local function click(button)
    button:FireScript("OnMouseDown", "LeftButton")
    button:FireScript("OnMouseUp", "LeftButton")
    button:FireScript("OnClick", "LeftButton")
end
local function catchers(h)
    local result = {}
    for _, frame in ipairs(h.frames) do
        if frame.mouseEnabled and frame.allPoints == h.env.UIParent
            and frame.strata == "DIALOG" then result[#result + 1] = frame end
    end
    return result
end
local function released(h)
    for _, frame in ipairs(catchers(h)) do check(not frame:IsShown(), "mouse catcher released") end
end

for _, locale in ipairs({"enUS", "ruRU", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "koKR", "zhCN", "zhTW"}) do
    local h = Harness.new({db = {settings = {forceLocale = locale}}})
    h:loadAddon()
    h:slash("settings")
    local trigger = h.env.DoYouNeedItLanguageDropdown
    trigger.GetBottom = function() return 5 end
    trigger.GetEffectiveScale = function() return 1 end
    click(trigger)
    local menu = h.env.DoYouNeedItLanguagePicker
    check(menu:IsVisible(), locale .. " language menu actually visible")
    check(not h.env.DropDownList1:IsShown(), "native menu never opens during press")
    check(menu:GetParent() == h.env.UIParent, "menu independent of window ancestry")
    check(menu.strata == "DIALOG" and menu:GetFrameLevel() > h.env.DoYouNeedItFrame:GetFrameLevel(), "menu above owner in its window family")
    check(menu.points[1][1] == "BOTTOMLEFT" and menu.points[1][2] == trigger, "menu flips above a low trigger")
    check(menu.clampedToScreen, "language menu clamped")
    for _, row in ipairs(menu.buttons) do
        local rowLocale = row.value == "auto" and "enUS" or row.value
        check(h.env.DoYouNeedItCore.FontSupportsText(row.text:GetFont(), row.text:GetText(), rowLocale),
            "native row text has glyph coverage: " .. locale .. "/" .. row.value .. "/" .. row.text:GetText() .. "/" .. tostring(row.text:GetFont()))
        local fontBefore = row.text:GetFont()
        row:FireScript("OnEnter")
        check(row.text:GetFont() == fontBefore, "language hover preserves native row font")
        row:FireScript("OnLeave")
        h:runTimers(0, 30)
    end
    menu:Hide()
    check(h.env.DoYouNeedItDB.settings.forceLocale == locale, "cancel preserves saved language")
    released(h)
    click(h.env.DoYouNeedItFontDropdown)
    local picker = h.env.DoYouNeedItFontPicker
    check(picker:IsVisible() and picker.strata == "DIALOG", "font picker above settings")
    check(picker.points[1][2] == h.env.DoYouNeedItFontDropdown, "font picker anchored to field")
    local first
    for _, row in ipairs(h.env.DoYouNeedItFontPickerContent.children) do
        if row.fontPath and row:IsShown() then
            check(h.env.DoYouNeedItCore.FontSupportsLocale(row.fontPath, locale, "enUS"), "font list contains only compatible faces")
            check(row.star:GetHeight() <= row:GetHeight(), "favorite target fits its row")
            first = first or row
        end
    end
    check(first ~= nil, "compatible font list not empty")
    local original = h.env.DoYouNeedItDB.settings.font
    first:FireScript("OnEnter")
    picker:Hide()
    check(h.env.DoYouNeedItDB.settings.font == original, "hover never commits a font")
    released(h)
    click(trigger)
    h:fire("PLAYER_REGEN_DISABLED")
    check(not menu:IsShown(), "combat closes language menu")
    released(h)
    h.env.DoYouNeedItFrame:Hide()
    released(h)
end

do
    local rejected = "Interface\\AddOns\\DoYouNeedIt\\fonts\\Bangers-Regular.ttf"
    local h = Harness.new({fontSetResult = function(_, path) return path ~= rejected end})
    h:loadAddon(); h:slash("settings"); click(h.env.DoYouNeedItFontDropdown)
    for _, row in ipairs(h.env.DoYouNeedItFontPickerContent.children) do
        if row:IsShown() and row.fontPath then check(row.fontPath ~= rejected, "nonthrowing SetFont failure hides unavailable face") end
    end
    local picker = h.env.DoYouNeedItFontPicker
    picker:Hide()
    picker.Show = function() error("synthetic popup failure") end
    click(h.env.DoYouNeedItFontDropdown)
    released(h)
end

do
    local h = Harness.new()
    h:loadAddon(); h:slash("settings"); click(h.env.DoYouNeedItFontDropdown)
    local row = h.env.DoYouNeedItFontPickerContent.children[1]
    local main = h.env.DoYouNeedItFrame
    for _, pair in ipairs({
        {main.settingsButton, h.env.DoYouNeedItSupportButton, 4},
        {h.env.DoYouNeedItFeedbackButton, main.close, 2},
        {h.env.DoYouNeedItSupportButton, h.env.DoYouNeedItFeedbackButton, 4},
    }) do
        local point = pair[1].points[1]
        check(point[1] == "RIGHT" and point[2] == pair[2] and point[3] == "LEFT",
            "header controls follow the preceding control toward Close")
        check(point[4] == -pair[3] and point[5] == 0, "header controls keep compact aligned gaps")
        check(pair[1]:GetWidth() == 24 and pair[1]:GetHeight() == 24, "header controls retain convenient click targets")
    end
    check(main.close.closeText:GetText() == "×", "close uses the restrained cross glyph")
    check(not main.close.closeHover:IsShown(), "close hover starts hidden")
    main.close:FireScript("OnEnter")
    check(main.close.closeHover:IsShown(), "close hover is visible on entry")
    main.close:FireScript("OnMouseDown")
    check(main.close.closePressed, "close tracks pressed feedback")
    main.close:FireScript("OnLeave")
    check(not main.close.closeHover:IsShown() and not main.close.closePressed,
        "leaving clears close hover and pressed feedback")
    check(row and row.star, "favorite control exists")
    local path = row.fontPath
    click(row.star)
    check(h.env.DoYouNeedItDB.settings.fontFavorites[h.env.DoYouNeedItCore.FontPathKey(path)], "favorite persists")
    check(h.env.DoYouNeedItFontPickerContent.children[1].fontPath == path, "favorite sorts first")
    h.env.DoYouNeedItFontPicker:Hide()
    click(h.env.DoYouNeedItSupportButton)
    local dialog = h.env.DoYouNeedItDeveloperLink
    check(dialog:IsVisible() and dialog.editBox:GetText() == "https://ko-fi.com/antrakt92", "heart opens correct copyable link")
    click(h.env.DoYouNeedItFeedbackButton)
    check(dialog.editBox:GetText() == "https://github.com/Antrakt92/Do-You-Need-It-/issues", "feedback uses this addon issue page")
    check(#h.sentMessages == 0, "UI testing never sends whispers")
    h.env.DoYouNeedItFrame:Hide()
    check(not dialog:IsShown(), "owner hide closes link dialog")
    released(h)
end
do
    local h = Harness.new({db = {settings = {forceLocale = "ruRU", fontSize = 24, autoWhisper = false}}})
    h:loadAddon(); h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    local draft = "Please keep this unsaved draft {item}"
    settings.whisperEditBox:SetText(draft)
    check(settings.autoCheck.points[1][4] == 126, "checkbox aligns with the input column")
    check(settings.autoCheckLabelButton.points[1][2] == settings.autoCheck, "label target follows checkbox")
    click(settings.autoCheckLabelButton)
    check(h.env.DoYouNeedItDB.settings.autoWhisper == true, "label click enables auto-whisper explicitly")
    check(settings.whisperEditBox:GetText() == draft, "label click preserves the message draft")
    click(settings.autoCheckLabelButton)
    check(h.env.DoYouNeedItDB.settings.autoWhisper == false, "second label click disables auto-whisper")
    for _, button in ipairs({settings.back, settings.whisperResetButton}) do
        check(button.template == "BackdropTemplate", "Settings button uses its own consistent surface")
        check(button:GetHeight() == 24 and button:GetFontString():GetFont(), "compact actions retain a 24-pixel target")
        check(button:GetWidth() <= 156 and button:GetFontString().fontSize <= 11,
            "secondary actions stay smaller than the main Settings controls")
    end
    check(settings.delaySlider:GetHeight() >= 24 and settings.fontSizeSlider:GetHeight() >= 24,
        "slim slider tracks retain convenient hit areas")
    check(settings.whisperEditBox:GetHeight() >= 32, "large input text fits vertically")
    h.env.DoYouNeedItSupportButton:FireScript("OnEnter")
    local supportTip = h.env.GameTooltip:GetText() or ""
    check(supportTip:find(h.env.DoYouNeedItCore.GetLocaleLabel("Support development", "ruRU"), 1, true)
        and supportTip:find("https://ko-fi.com/antrakt92", 1, true), "support tooltip explains action and destination")
    h.env.DoYouNeedItFeedbackButton:FireScript("OnEnter")
    local feedbackTip = h.env.GameTooltip:GetText() or ""
    check(feedbackTip:find(h.env.DoYouNeedItCore.GetLocaleLabel("Report a bug or suggest a feature", "ruRU"), 1, true)
        and feedbackTip:find("https://github.com/Antrakt92/Do-You-Need-It-/issues", 1, true), "feedback tooltip explains action and destination")
    check(#h.sentMessages == 0, "Settings controls never send a whisper")
end
do
    local h = Harness.new()
    h:loadAddon(); h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    local draft = "Keep this pending reset draft {item}"
    settings.whisperEditBox:FireScript("OnEditFocusGained")
    settings.whisperEditBox:SetText(draft)
    click(settings.whisperResetButton)
    click(h.env.DoYouNeedItFontDropdown)
    h.env.DoYouNeedItFontPickerContent.children[1]:FireScript("OnEnter")
    check(settings.whisperEditBox:GetText() == draft, "font preview preserves draft after the first Reset click")
    check((h.env.DoYouNeedItDB.settings or {}).whisperTemplate ~= draft, "arming Reset does not prematurely save a draft")
    h.env.DoYouNeedItFontPicker:Hide()
    settings.fontSizeSlider:FireScript("OnMouseDown")
    settings.fontSizeSlider:SetValue(18)
    h:fire("PLAYER_LOGOUT")
    check(h.env.DoYouNeedItDB.settings.whisperTemplate == draft, "logout saves the active message draft")
    check(h.env.DoYouNeedItDB.settings.fontSize == 18, "logout saves the active slider value")
end
do
    local h = Harness.new()
    h:loadAddon(); h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    settings.whisperEditBox:FireScript("OnEditFocusGained")
    settings.whisperEditBox:SetText("First {item} draft")
    click(settings.whisperResetButton)
    settings.whisperEditBox:SetText("Edited {item} draft")
    settings.whisperEditBox:FireScript("OnTextChanged", true)
    click(settings.whisperResetButton)
    check(settings.whisperEditBox:GetText() == "Edited {item} draft", "typing disarms Reset before the next click")
    check(settings.whisperResetButton:GetText() == "Reset?", "Reset rearms for the edited draft")
end
do
    local h = Harness.new({db = {settings = {fontSize = 24}}})
    h:loadAddon(); h:slash("settings")
    click(h.env.DoYouNeedItFontDropdown)
    local row
    for _, candidate in ipairs(h.env.DoYouNeedItFontPickerContent.children) do
        if candidate:IsShown() and candidate.fontName and #candidate.fontName > 15 then
            row = candidate
            break
        end
    end
    check(row ~= nil, "font list contains a long name to inspect")
    row:FireScript("OnEnter")
    check(h.env.GameTooltip:IsOwned(row) and h.env.GameTooltip:GetText() == row.fontName,
        "hovering a font name exposes its complete name")
    row:FireScript("OnLeave")
    check(not h.env.GameTooltip:IsShown(), "leaving a font row clears its tooltip")
    row:FireScript("OnEnter")
    row.star:FireScript("OnEnter")
    row:FireScript("OnLeave")
    check(h.env.GameTooltip:IsOwned(row.star) and h.env.GameTooltip:IsShown(),
        "row leave preserves the favorite target's replacement tooltip")
    row:FireScript("OnHide")
    check(not h.env.GameTooltip:IsShown(), "a recycled or hidden row clears its owned tooltip")
    row:FireScript("OnEnter")
    click(row)
    check(not h.env.GameTooltip:IsShown(), "selecting a font clears the row tooltip")
    released(h)
end
print("Settings popup regressions: PASS (" .. count .. " assertions)")
