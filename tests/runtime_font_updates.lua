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
    client:slash("fontdiag")
    local report = client.env.DoYouNeedItSelfTest.fontDiagnostics
    check(report.version == 3 and #report.lines == 11, "bounded font trace is saved: " .. flavor)
    check(client.env.DoYouNeedItDB.settings.font == custom, "font trace preserves selection: " .. flavor)
    check(#client.sentMessages == 0, "font trace never sends chat: " .. flavor)
end
for _, delta in ipairs({0.000001, -0.000001, 0.25}) do
    local custom = "Interface\\AddOns\\DoYouNeedIt\\fonts\\DejaVuSans.ttf"
    local rounded = Harness.new({fontSetReturn = function(region, path)
        if path == custom then region.fontSize = region.fontSize + delta end
        return true
    end})
    rounded:loadAddon(); rounded:slash("settings")
    rounded.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local found = false
    for _, row in ipairs(rounded.env.DoYouNeedItFontPickerContent.children) do
        if row:IsShown() and row.fontPath == custom then found = true end
    end
    check(found == (math.abs(delta) < 0.01), "small client rounding is accepted, real size mismatch rejected: " .. delta)
end
for _, flavor in ipairs({"retail", "forever"}) do
    local cold = Harness.new({flavor = flavor, fontColdAssets = true})
    if flavor == "forever" then
        cold.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
        cold.env.WOW_PROJECT_ID = 18
    end
    cold:loadAddon(); cold:slash("settings")
    cold.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local selected, count = nil, 0
    for _, row in ipairs(cold.env.DoYouNeedItFontPickerContent.children) do
        if row:IsShown() and row.fontPath and row.fontPath:find("AddOns", 1, true) then
            count = count + 1
            selected = row
        end
    end
    local expected = 0
    for _, font in ipairs(cold.env.DoYouNeedItCore.GetBundledFonts()) do
        if cold.env.DoYouNeedItCore.FontSupportsLocale(font.path, "enUS", "enUS") then expected = expected + 1 end
    end
    check(expected > 20 and count == expected, "cold catalogue activates every compatible face without a diagnostic warm-up: " .. flavor)
    selected:FireScript("OnClick", "LeftButton")
    check(cold.env.DoYouNeedItFrame.title:GetFont() == selected.fontPath, "cold face applies after selection: " .. flavor)
    cold.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
    cold:slash("settings")
    cold.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local again = 0
    for _, row in ipairs(cold.env.DoYouNeedItFontPickerContent.children) do
        if row:IsShown() and row.fontPath and row.fontPath:find("AddOns", 1, true) then again = again + 1 end
    end
    check(again == count, "reopening retains the full cold-loaded catalogue: " .. flavor)
end
for _, flavor in ipairs({"retail", "forever"}) do
    local preferred = "Interface\\AddOns\\DoYouNeedIt\\fonts\\DoHyeon-Regular.ttf"
    local client = Harness.new({flavor = flavor, db = {settings = {font = preferred, forceLocale = "koKR"}}})
    if flavor == "forever" then
        client.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
        client.env.WOW_PROJECT_ID = 18
    end
    client:setUnit("party1", {name = "갂", realm = "Ravencrest", guid = "KoreanGUID", classToken = "PALADIN"})
    client:loadAddon()
    client:slash("")
    local item = client:addItem(22001, {
        name = "Sample Trinket", equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0,
        quality = 4, bindType = 2, equippable = true, usable = true,
    })
    client:fireLoot("갂", item)
    client:runTimers(3, 70)
    local row = assert(client:visibleRows()[1])
    local core = client.env.DoYouNeedItCore
    check(row.looter:GetFont() ~= preferred and core.FontSupportsText(row.looter:GetFont(), "갂", "koKR"),
        "a Hangul loot name falls back from a partial face: " .. flavor)
    check(row.drop:GetFont() == preferred, "ASCII loot text preserves the selected face: " .. flavor)
    check(client.env.DoYouNeedItDB.settings.font == preferred, "loot fallback preserves saved choice: " .. flavor)
    if flavor == "retail" then
        local protected = client:secretValue("restricted loot name")
        row.drop.GetText = function() return protected end
        client:slash("delay 15")
        check(row.drop:GetFont() == core.GetDefaultFont(), "restricted loot text uses the baseline")
        check(client.env.DoYouNeedItDB.settings.font == preferred, "restricted text leaves the saved choice intact")
    end
end
do
    local preferred = "Interface\\AddOns\\DoYouNeedIt\\fonts\\SourceHanSansTW-Regular.otf"
    local client = Harness.new({db = {settings = {font = preferred, forceLocale = "zhTW"}}})
    client:loadAddon()
    -- U+20021 is in this Source Han face, but not the embedded baseline.
    local item = client:addItem(22001, {
        name = "𠀡", equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0,
        quality = 4, bindType = 2, equippable = true, usable = true,
    })
    client:fireLoot("Otherplayer", item)
    local row = assert(client:visibleRows()[1])
    check(row.drop:GetFont() == preferred, "unverified supplementary text keeps the selected Han face")
end
for _, flavor in ipairs({"retail", "forever"}) do
    local preferred = "Interface\\AddOns\\DoYouNeedIt\\fonts\\DejaVuSans.ttf"
    local client = Harness.new({flavor = flavor, db = {settings = {font = preferred}}})
    if flavor == "forever" then
        client.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
        client.env.WOW_PROJECT_ID = 18
    end
    client:loadAddon()
    client:slash("")
    local items = {
        { name = "々ゔ゙", known = "々ゔ゙" },
        { name = "한글 𠀡", known = "한글" },
        { name = "𠀡", known = nil },
    }
    for index, sample in ipairs(items) do
        local item = client:addItem(22001 + index, {
            name = sample.name, equipLoc = "INVTYPE_TRINKET", classID = 4, subclassID = 0,
            quality = 4, bindType = 2, equippable = true, usable = true,
        })
        client:fireLoot("Otherplayer", item)
    end
    client:runTimers(3, 70)
    local core = client.env.DoYouNeedItCore
    local rows = {}
    for _, row in ipairs(client:visibleRows()) do rows[row.drop:GetText():match("|h%[(.-)%]|h")] = row.drop:GetFont() end
    for _, sample in ipairs(items) do
        local font = rows[sample.name]
        check(font ~= nil, "expected sample has a visible loot row: " .. flavor)
        if sample.known then
            check(font ~= preferred and core.FontSupportsText(font, sample.known, "enUS"),
                "known Japanese or Hangul text selects a suitable face: " .. flavor)
        else
            check(font == preferred, "supplementary-only loot text retains its selected face: " .. flavor)
        end
    end
    check(client.env.DoYouNeedItDB.settings.font == preferred, "runtime adaptation preserves the selected face: " .. flavor)
end
print("Font update regressions: PASS (" .. checks .. " assertions)")
