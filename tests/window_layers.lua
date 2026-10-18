local Harness = dofile("tests/runtime_harness.lua")
local count = 0
local function check(value, message)
    count = count + 1
    assert(value, message)
end
local h = Harness.new()
local env = h.env
local paths = {arg and arg[1] or "AntraktWindowLayers.lua"}
if arg then for index = 2, #arg do paths[#paths + 1] = arg[index] end end
local service, bytes
for _, path in ipairs(paths) do
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a"); file:close()
    if bytes then check(source == bytes, "shared window service copies match exactly") end
    bytes = source
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
    check(not service or service == env.AntraktWindowLayers, "load order reuses one shared service")
    service = env.AntraktWindowLayers
end
local function frame(parent, offset)
    local result = h:newFrame("Frame", nil, parent or env.UIParent)
    if parent then result:SetFrameLevel(parent:GetFrameLevel() + offset) end
    result:Show()
    return result
end
local a, b, c = frame(), frame(), frame()
local controls = {frame(a, 35), frame(b, 12), frame(c, 70)}
local menu, catcher = frame(), frame()
menu:Hide(); catcher:Hide()
service.Register(a, function() menu:Hide(); catcher:Hide() end)
service.Register(b); service.Register(c)
service.Attach(a, menu, 80); service.Attach(a, catcher, 79)
local function foreground(root, control, others)
    for _, other in ipairs(others) do
        check(root:GetFrameLevel() > other:GetFrameLevel(), "foreground background covers every other window control")
    end
    check(control:GetFrameLevel() > root:GetFrameLevel(), "foreground controls stay above their own background")
end
service.Focus(a); service.Focus(b); service.Focus(c)
foreground(c, controls[3], {a, b, controls[1], controls[2]})
controls[1]:FireScript("OnMouseDown", "LeftButton")
foreground(a, controls[1], {b, c, controls[2], controls[3]})
menu:Show(); catcher:Show()
check(menu.strata == "DIALOG" and menu:GetFrameLevel() > controls[1]:GetFrameLevel(), "popup shares its owner's ordered family")
controls[2]:FireScript("OnMouseDown", "LeftButton")
check(not menu:IsShown() and not catcher:IsShown(), "focus change releases another window's popup and catcher")
foreground(b, controls[2], {a, c, controls[1], controls[3]})
local late = frame(a, 45)
service.Focus(a)
late:FireScript("OnMouseDown", "LeftButton")
for index = 1, 500 do service.Focus(index % 2 == 0 and a or c) end
check(a:GetFrameLevel() < 1000 and c:GetFrameLevel() < 1000, "focus changes compact levels instead of growing forever")
check(controls[1]:GetFrameLevel() - a:GetFrameLevel() == 35, "native parent propagation preserves control offsets")
check(late:GetFrameLevel() - a:GetFrameLevel() == 45, "new descendants join their window family")
service.Detach(a, menu); service.Detach(a, catcher)
service.Register(menu); service.Attach(menu, catcher, -1)
menu:Show(); catcher:Show()
check(menu:GetFrameLevel() == catcher:GetFrameLevel() + 1, "standalone modal blocker stays below its report")
service.Unregister(menu)
service.Attach(a, menu, 80); service.Attach(a, catcher, 79)
menu:Show()
check(menu:GetFrameLevel() - a:GetFrameLevel() == 80, "reused dialog can rejoin its original window")

h:loadAddon(); h:slash("settings")
local main = env.DoYouNeedItFrame
local foreign = frame()
local foreignControl = frame(foreign, 90)
service.Register(foreign)
env.DoYouNeedItLanguageDropdown:FireScript("OnClick")
check(env.DoYouNeedItLanguagePicker:IsShown(), "real language popup opens")
service.Focus(foreign)
check(not env.DoYouNeedItLanguagePicker:IsShown(), "real popup closes when a sibling addon is focused")
for _, candidate in ipairs(h.frames) do
    if candidate.allPoints == env.UIParent and candidate.mouseEnabled then
        check(not candidate:IsShown(), "focus change releases every popup catcher")
    end
end
foreground(foreign, foreignControl, {main, env.DoYouNeedItSettingsFrame, env.DoYouNeedItFontDropdown})
env.DoYouNeedItFontDropdown:FireScript("OnMouseDown", "LeftButton")
foreground(main, env.DoYouNeedItFontDropdown, {foreign, foreignControl})
print("Window family regressions: PASS (" .. count .. " assertions)")
