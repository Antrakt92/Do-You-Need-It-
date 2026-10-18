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
check(select(2, settings.whisperEditBox:GetFont()) >= expectedSize, "real size previews still apply")
settings.fontSizeSlider:FireScript("OnMouseUp")
check(h.env.DoYouNeedItDB.settings.fontSize == 24, "size changes still persist")
h.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
writes = 0
h:slash("delay 14")
check(writes == 0, "new stable size also avoids redundant assignments")
check(#h.sentMessages == 0, "font updates never send whispers")
for _, flavor in ipairs({"retail", "forever"}) do
    local custom = "Interface\\AddOns\\DoYouNeedIt\\fonts\\DejaVuSans.ttf"
    local rejected = "Interface\\AddOns\\DoYouNeedIt\\fonts\\Bangers-Regular.ttf"
    local client = Harness.new({
        flavor = flavor,
        fontSetResult = function(region, path)
            if path == rejected then return false end
            -- The client accepts the face through a FontObject, while direct
            -- FontString application can fail without invalidating that object.
            return region.frameType == "Font" or not path:find("AddOns", 1, true)
        end,
        fontSetReturn = function(region)
            if region.frameType == "Font" then return nil end
            return false
        end,
    })
    if flavor == "forever" then
        client.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
        client.env.WOW_PROJECT_ID = 18
    end
    client:loadAddon(); client:slash("settings")
    client.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local selected, available = nil, 0
    for _, row in ipairs(client.env.DoYouNeedItFontPickerContent.children) do
        if row:IsShown() and row.fontPath then
            available = available + 1
            check(row.fontPath ~= rejected, "unloadable face stays hidden: " .. flavor)
            if row.fontPath == custom then selected = row end
        end
    end
    check(selected ~= nil, "nil-return FontObject keeps bundled face available: " .. flavor)
    check(available > 20, "full compatible catalogue remains available: " .. flavor)
    selected:FireScript("OnEnter")
    local path, size, flags = client.env.DoYouNeedItFrame.title:GetFont()
    check(path == custom and size == 16 and (flags or "") == "", "hover applies effective face/size/flags: " .. flavor)
    selected:FireScript("OnClick", "LeftButton")
    check(client.env.DoYouNeedItDB.settings.font == custom, "selection persists: " .. flavor)
    check(client.env.DoYouNeedItFrame.title:GetFont() == custom, "selection remains rendered: " .. flavor)
    client:slash("delay 13")
    check(client.env.DoYouNeedItFrame.title:GetFont() == custom, "refresh preserves selected face: " .. flavor)
    check(#client.sentMessages == 0, "font selection has no chat side effect: " .. flavor)
end
print("Font update regressions: PASS (" .. checks .. " assertions)")
