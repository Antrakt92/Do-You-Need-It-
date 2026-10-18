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
            and frame.strata == "FULLSCREEN_DIALOG" then result[#result + 1] = frame end
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
    check(menu.strata == "FULLSCREEN_DIALOG" and menu:GetFrameLevel() > h.env.DoYouNeedItFrame:GetFrameLevel(), "menu above owner")
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
    check(picker:IsVisible() and picker.strata == "FULLSCREEN_DIALOG", "font picker above settings")
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
    for _, button in ipairs({settings.back, settings.resetPosition, settings.whisperResetButton}) do
        check(button.template == "BackdropTemplate", "Settings button uses its own consistent surface")
        check(button:GetHeight() >= 26 and button:GetFontString():GetFont(), "button has readable text and a large target")
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
print("Settings popup regressions: PASS (" .. count .. " assertions)")
