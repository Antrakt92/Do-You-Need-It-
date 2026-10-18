local Harness = dofile("tests/runtime_harness.lua")
local checks, writes = 0, 0
local function check(ok, label) checks = checks + 1; assert(ok, label) end
local h = Harness.new({fontSetResult = function() writes = writes + 1; return true end})
h:loadAddon(); h:slash("settings")
local settings = h.env.DoYouNeedItSettingsFrame
h.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
local expectedPath, expectedSize, expectedFlags = settings.whisperLabel:GetFont()
writes = 0
for _ = 1, 10 do h:slash("delay 11") end
check(writes == 0, "unchanged refreshes must not reassign fonts, including hidden Settings")
settings.whisperLabel:SetFont(expectedPath, expectedSize + 1, expectedFlags)
h:slash("delay 12")
local path, size = settings.whisperLabel:GetFont()
check(path == expectedPath and size == expectedSize, "external font-size changes are repaired on refresh")
local foreign = h.env.CreateFont("ForeignFontForRegression")
foreign:SetFont(expectedPath, expectedSize, expectedFlags)
settings.whisperLabel:SetFontObject(foreign)
h:slash("delay 13")
check(settings.whisperLabel:GetFontObject() == settings.whisperLabel._dyniOwnedFont,
    "matching foreign FontObjects must still be detached")
h:slash("settings")
settings.fontSizeSlider:SetValue(24)
check(settings.whisperEditBox.fontSize >= expectedSize, "real size previews still apply")
settings.fontSizeSlider:FireScript("OnMouseUp")
check(h.env.DoYouNeedItDB.settings.fontSize == 24, "size changes still persist")
h.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
writes = 0
h:slash("delay 14")
check(writes == 0, "new stable size also avoids redundant assignments")
check(#h.sentMessages == 0, "font updates never send whispers")
print("Font update regressions: PASS (" .. checks .. " assertions)")
