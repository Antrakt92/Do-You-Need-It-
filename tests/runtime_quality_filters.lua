local Harness = dofile("tests/runtime_harness.lua")
local checks = 0
local function check(ok, message) checks=checks+1; assert(ok,message) end
local function fresh(flavor, db)
    local h=Harness.new({flavor=flavor,db=db})
    if flavor=="forever" then
        h.env.GetBuildInfo=function() return "1.60.1","70450","",16001 end
        h.env.WOW_PROJECT_ID=18
    end
    h:loadAddon();h:slash("");return h
end
local function toggle(h, quality)
    h:slash("settings")
    h.env.DoYouNeedItSettingsFrame.qualityButtons[quality+1]:FireScript("OnClick")
    check(h.env.DoYouNeedItSettingsFrame:IsShown(),"quality toggle keeps Settings open")
    h.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
end
for _, flavor in ipairs({"retail","forever"}) do
    local h=fresh(flavor)
    local core=h.env.DoYouNeedItCore
    local settings=core.NormalizeSettings({minQuality=3, qualityFilters={[1]=true,[4]=false,[2]="bad"}})
    check(settings.qualityFilters[1] and not settings.qualityFilters[2] and settings.qualityFilters[3] and not settings.qualityFilters[4],"legacy threshold migration preserves explicit toggles")
    check(core.NormalizeSettings(settings).qualityFilters[4]==false,"normalization preserves disabled qualities")
    for quality=0,6 do
        local link=h:addItem(48000+quality,{quality=quality,name="Quality "..quality,bindType=2,linkColor=core.QUALITY_COLORS[quality]})
        h:fireLoot("Otherplayer",link)
    end
    check(#h.env.DoYouNeedItDB.sessionAllRows==7,"all real gear retained independent of display filters: "..flavor)
    check( #h:visibleRows()==5,"default hides gray and white, five rows visible: "..flavor)
    local width,height=h.env.DoYouNeedItFrame:GetWidth(),h.env.DoYouNeedItFrame:GetHeight()
    toggle(h,0);toggle(h,1)
    check(#h:visibleRows() == 6, "minimum window retains a full six-row single-item page")
    check(#h.env.DoYouNeedItDB.sessionAllRows==7,"toggle never deletes records")
    check(h.env.DoYouNeedItFrame:GetWidth()==width and h.env.DoYouNeedItFrame:GetHeight()==height,"Settings keeps the loot window dimensions")
    check(h.env.DoYouNeedItSettingsFrame.qualityButtons[1].check:IsShown(),"gray check marks selected quality")
    check(h.env.DoYouNeedItFrame.qualityButton == nil,"no separate header filter button")
    for quality=0,6 do if h.env.DoYouNeedItDB.settings.qualityFilters[quality] then toggle(h,quality) end end
    check(#h:visibleRows()==0,"all unchecked hides every known quality")
    check(not core.IsQualityVisible(h.env.DoYouNeedItDB.settings, {itemLink="unknown"}),"all unchecked also hides legacy unknown quality")
    check(not core.IsQualityVisible(settings,{quality=7}),"heirlooms are outside group-drop display")
    check(not core.IsQualityVisible(settings,{quality=8}),"currency quality is outside group-drop display")
    check(#h.env.DoYouNeedItDB.sessionAllRows==7,"empty view preserves full history")
    toggle(h,4)
    check(#h:visibleRows()==1 and h:visibleRows()[1].row.itemID==48004,"individual epic selection, not minimum threshold")
    h:slash("history")
    check(#h:visibleRows()==1,"same filter applies to session")
    local reload=fresh(flavor,h.env.DoYouNeedItDB)
    reload:slash("history")
    check(#reload:visibleRows()==1 and reload:visibleRows()[1].row.itemID==48004,"filters and row qualities survive reload")
    local off=core.NormalizeSettings({autoWhisper=true,qualityFilters={[4]=false}})
    local decision=core.GetAutoWhisperDecision(off,{quality=4,looter="Otherplayer",itemLink="item:48004",askable=true})
    check(not decision.shouldSchedule and decision.reason=="quality_filtered","disabled quality cannot schedule auto whisper")
    check(core.RowQuality({itemLink="|cff0070dd|Hitem:10|h[Old]|h|r"})==3,"legacy links resolve quality without saved metadata")
    check(core.QualityLabel(4,"ruRU")=="Эпическое","filter respects selected language")
end
-- Change filters while an eligible delayed whisper is already queued.
do
    local h=fresh("retail",{settings={autoWhisper=true,autoDelay=10}})
    local link=h:addItem(48900,{quality=4,bindType=2,name="Queued epic"})
    h:fireLoot("Otherplayer",link)
    check(h:visibleRows()[1].row.pendingAutoWhisper==true,"precondition: automatic whisper is genuinely queued")
    toggle(h,4)
    h:runTimers(35,200)
    check(#h.sentMessages==0,"disabling queued quality cancels deferred auto send")
    check(#h:visibleRows()==0,"hidden incoming loot stays hidden after asynchronous work")
    toggle(h,4)
    check(#h:visibleRows()==1,"restoring quality restores retained row")
    h:runTimers(35,200)
    check(#h.sentMessages==0,"showing retained loot never schedules a retroactive whisper")
end
-- Resizing and the Settings layout share dimensions in both supported clients.
for _, flavor in ipairs({"retail", "forever"}) do
    local h = fresh(flavor)
    h:slash("test")
    local main = h.env.DoYouNeedItFrame
    check(main:GetWidth() == 540 and main:GetHeight() == 300,
        "first launch defaults to the minimum window dimensions")
    check(#h:visibleRows() <= 6, "default window starts compact")
    local before = #h:visibleRows()
    local oldDropWidth = h:visibleRows()[1].drop:GetWidth()
    check(main.resizable and main.resizeBounds[1] == 540 and main.resizeBounds[2] == 300,
        "native resize bounds protect the compact layout")
    main.resizeGrip:FireScript("OnMouseDown", "RightButton")
    check(not main.sizing, "only left drag starts sizing")
    main.resizeGrip:FireScript("OnMouseDown", "LeftButton")
    check(main.sizing == "BOTTOMRIGHT", "corner drag invokes native sizing")
    main:SetSize(800, 600)
    main:FireScript("OnSizeChanged", 800, 600)
    h:runTimers(0)
    check(#h:visibleRows() > before, "taller window shows more drops")
    check(h:visibleRows()[1].drop:GetWidth() > oldDropWidth, "wider window expands item columns")
    check(main.historyButton:GetWidth() + main.demoButton:GetWidth() + 6 == main:GetWidth() - 32,
        "selector follows window width")
    main.resizeGrip:FireScript("OnMouseUp", "LeftButton")
    check(not main.sizing and h.env.DoYouNeedItDB.windowSize.width == 800
        and h.env.DoYouNeedItDB.windowSize.height == 600, "drag release persists dimensions")
    h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    check(main:GetWidth() == 800 and main:GetHeight() == 600, "Settings retains resized window dimensions")
    for _, row in ipairs(settings.qualityButtons) do
        check(row.points[1][4] + row:GetWidth() <= settings:GetWidth() - 8,
            "quality choices stay inside a widened window: " .. flavor)
    end
    check(settings.autoCheck.points[1][4] + settings.autoCheck:GetWidth() + settings.autoCheckLabelButton:GetWidth() + 8
        <= settings.delaySlider.points[1][4], "wide Settings preserves separate toggle/slider hit areas")
    settings.whisperEditBox:FireScript("OnEditFocusGained")
    settings.whisperEditBox:SetText("Keep draft {item}")
    settings.qualityButtons[5]:FireScript("OnClick")
    check(settings.whisperEditBox:GetText() == "Keep draft {item}", "inline quality changes preserve a draft")
    main.settingsButton:FireScript("OnClick")
    check(main:GetHeight() == 600 and main:GetWidth() == 800, "return to loot preserves dimensions")
    local reload = fresh(flavor, h.env.DoYouNeedItDB)
    local restored = reload.env.DoYouNeedItFrame
    check(restored:GetWidth() == 800 and restored:GetHeight() == 600, "size survives a fresh login")
    restored.resizeGrip:FireScript("OnMouseDown", "LeftButton")
    reload:fire("PLAYER_REGEN_DISABLED")
    check(not restored.sizing, "combat stops an active sizing operation")
    restored:SetSize(540, 300)
    restored:FireScript("OnSizeChanged", 540, 300)
    reload:runTimers(0)
    reload:slash("settings")
    reload.env.DoYouNeedItSettingsFrame.qualityButtons[5]:FireScript("OnClick")
    restored.settingsButton:FireScript("OnClick")
    reload:slash("test")
    check(#reload:visibleRows() == before, "shrinking hides surplus pooled rows")
    reload.env.InCombatLockdown = function() return true end
    restored.resizeGrip:FireScript("OnMouseDown", "LeftButton")
    check(not restored.sizing, "combat cannot start a new resize")
    local invalid = fresh(flavor, {windowSize = {width = 0/0, height = 500}})
    check(invalid.env.DoYouNeedItFrame:GetWidth() == 540, "non-finite saved dimensions use defaults")
    local bounded = fresh(flavor, {windowSize = {width = 1, height = 99999}})
    check(bounded.env.DoYouNeedItFrame:GetWidth() == 540 and bounded.env.DoYouNeedItFrame:GetHeight() == 900,
        "saved dimensions clamp to safe bounds")
end
print("Quality filters: PASS ("..checks.." assertions)")
