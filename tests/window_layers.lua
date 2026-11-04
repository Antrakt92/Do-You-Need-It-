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

do
    local isolated=Harness.new()
    local chunk=assert(loadfile(paths[1]));setfenv(chunk,isolated.env);chunk()
    local layers=isolated.env.AntraktWindowLayers
    local root=isolated:newFrame("Frame",nil,isolated.env.UIParent);root:SetFrameLevel(330);root:Show()
    local close=isolated:newFrame("Button",nil,root);close:SetFrameLevel(100);close:Show()
    local nested=isolated:newFrame("Button",nil,close);nested:SetFrameLevel(50);nested:Show()
    local valid=isolated:newFrame("Button",nil,root);valid:SetFrameLevel(365);valid:Show()
    check(root:GetFrameLevel()==330 and close:GetFrameLevel()==100,"fixture reproduces native visible child below its opaque parent")
    layers.Register(root);layers.Focus(root)
    check(close:GetFrameLevel()>root:GetFrameLevel(),"focus repairs a descendant hidden below its parent background")
    check(nested:GetFrameLevel()>close:GetFrameLevel(),"focus repairs invalid descendants recursively")
    check(valid:GetFrameLevel()-root:GetFrameLevel()==35,"repair preserves existing valid positive child offsets")
    local blocker=isolated:newFrame("Frame",nil,isolated.env.UIParent);blocker:Show()
    layers.Attach(root,blocker,-1)
    for _=1,500 do layers.Focus(root)end
    check(close:GetFrameLevel()>root:GetFrameLevel() and nested:GetFrameLevel()>close:GetFrameLevel(),"repeated focus keeps repaired controls above their actual parents")
    check(root:GetFrameLevel()-blocker:GetFrameLevel()==1,"UIParent-owned attached blocker retains its intentional negative offset")
    check(valid:GetFrameLevel()-root:GetFrameLevel()==35 and valid:GetFrameLevel()<1000,"repaired ordering remains compact without growing valid offsets")
    local extraParent=isolated:newFrame("Frame",nil,isolated.env.UIParent);extraParent:Show()
    local extraChild=isolated:newFrame("Button",nil,extraParent);extraChild:Show()
    local extraNested=isolated:newFrame("Button",nil,extraChild);extraNested:Show()
    -- Registration order must not override the actual native parent hierarchy.
    layers.Attach(root,extraChild,-40)
    layers.Attach(root,extraParent,80)
    extraParent:SetFrameLevel(root:GetFrameLevel()+80)
    extraChild:SetFrameLevel(root:GetFrameLevel()-40)
    extraNested:SetFrameLevel(root:GetFrameLevel()-60)
    layers.Focus(root)
    check(extraChild:GetFrameLevel()>extraParent:GetFrameLevel(),"reverse attached extras still place actual children above their parent")
    check(extraNested:GetFrameLevel()>extraChild:GetFrameLevel(),"reverse attached extras repair nested descendants")
    check(extraParent:GetFrameLevel()-root:GetFrameLevel()==80,"reverse extras preserve the valid popup offset")
    for _=1,500 do layers.Focus(root)end
    check(extraChild:GetFrameLevel()>extraParent:GetFrameLevel() and extraNested:GetFrameLevel()>extraChild:GetFrameLevel(),"parent-first application preserves repaired extras across repeated focus")
    check(root:GetFrameLevel()-blocker:GetFrameLevel()==1,"reverse extras retain a separate UIParent blocker below the root")
    check(extraNested:GetFrameLevel()<1000,"reverse extras remain bounded after repeated focus")
end
for _,flavor in ipairs({"retail","forever"})do
    local native=Harness.new({flavor=flavor})
    if flavor=="forever"then
        native.env.GetBuildInfo=function()return "1.60.1","70755","",16001 end
        native.env.WOW_PROJECT_ID=18
    end
    native:loadAddon();native:slash("settings")
    local main=native.env.DoYouNeedItFrame
    main:SetFrameLevel(330);main.close:SetFrameLevel(100)
    native.env.AntraktWindowLayers.Focus(main)
    check(main.close:GetFrameLevel()>main:GetFrameLevel(),flavor.." real main close escapes parent background after native ordering corruption")
    check(main.strata=="DIALOG" and (main.close.strata==nil or main.close.strata=="DIALOG"),"repair keeps the normal dialog stratum")
    check(main.close.closeText==nil and #main.close.closeLines==2,"repair preserves font-independent close geometry")
    for _,line in ipairs(main.close.closeLines)do
        local color=line.colorTexture
        check(color[1]==0.62 and color[2]==0.71 and color[3]==0.79 and color[4]==1,"repair retains the restrained opaque gray close strokes")
    end
end

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
