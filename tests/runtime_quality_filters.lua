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
    local b=h.env.DoYouNeedItFrame.qualityButton
    if not h.env.DoYouNeedItQualityPicker or not h.env.DoYouNeedItQualityPicker:IsShown() then b:FireScript("OnClick") end
    h.env.DoYouNeedItQualityPicker.buttons[quality+1]:FireScript("OnClick")
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
    check(#h.env.DoYouNeedItDB.sessionAllRows==7,"toggle never deletes records")
    check(h.env.DoYouNeedItFrame:GetWidth()==width and h.env.DoYouNeedItFrame:GetHeight()==height,"popup leaves window geometry unchanged")
    check(h.env.DoYouNeedItQualityPicker:IsShown(),"picker stays open for several toggles")
    check(h.env.DoYouNeedItQualityPicker.buttons[1].check:IsShown(),"gray check marks selected quality")
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
    reload.env.DoYouNeedItFrame.qualityButton:FireScript("OnClick")
    reload:fire("PLAYER_REGEN_DISABLED")
    check(not reload.env.DoYouNeedItQualityPicker:IsShown() and not reload.env.DoYouNeedItQualityCatcher:IsShown(),"combat closes popup and catcher")
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
print("Quality filters: PASS ("..checks.." assertions)")
