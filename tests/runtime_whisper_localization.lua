local Harness = dofile('tests/runtime_harness.lua')
local count = 0
local function check(value, message) count=count+1;assert(value,message) end
local function clone(value)
    if type(value)~='table' then return value end
    local result={};for key,child in pairs(value)do result[key]=clone(child)end;return result
end
local function fresh(flavor,settings,db)
    local h=Harness.new({flavor=flavor,db=db or {settings=settings or {}}})
    if flavor=='forever' then
        h.env.GetBuildInfo=function()return '1.60.1','70755','',16001 end
        h.env.WOW_PROJECT_ID=18
    end
    h:loadAddon();h:slash('settings')
    return h,h.env.DoYouNeedItCore,h.env.DoYouNeedItSettingsFrame
end
local function language(h,locale,commit)
    if not h.env.DoYouNeedItLanguagePicker or not h.env.DoYouNeedItLanguagePicker:IsShown()then
        h.env.DoYouNeedItLanguageDropdown:FireScript('OnClick')
    end
    for _,row in ipairs(h.env.DoYouNeedItLanguagePicker.buttons)do
        if row.value==locale then row:FireScript(commit and 'OnClick' or 'OnEnter');return end
    end
    error('Missing language '..locale)
end
local function ask(h,id)
    local item=h:addItem(id,{name='Localized Whisper Sword',bindType=2})
    h:fireLoot('Otherplayer',item)
    for _,row in ipairs(h:visibleRows())do
        if row.row and row.row.itemLink==item and row.whisper:IsShown()then
            row.whisper:FireScript('OnClick');h:runTimers(0);return item
        end
    end
    error('Missing usable live loot')
end
for _,flavor in ipairs({'retail','forever'})do
    for _,locale in ipairs({'enUS','deDE','esES','esMX','frFR','itIT','ptBR','ruRU','koKR','zhCN','zhTW'})do
        local h,core,ui=fresh(flavor,{forceLocale='enUS'})
        local translated=core.GetDefaultWhisperTemplate(locale)
        language(h,locale,false)
        check(ui.whisperEditBox:GetText()==translated,'language hover previews its standard whisper')
        check(h.env.DoYouNeedItDB.settings.forceLocale=='enUS','hover never commits the selected language')
        check(core.ResolveWhisperTemplate(h.env.DoYouNeedItDB.settings,'enUS')==core.DEFAULT_WHISPER_TEMPLATE,'hover cannot alter the outgoing language')
        language(h,locale,true)
        check(ui.whisperEditBox:GetText()==translated,'committed language updates the standard editor')
        ui.whisperEditBox:FireScript('OnEditFocusGained');ui.whisperEditBox:FireScript('OnEditFocusLost')
        check(h.env.DoYouNeedItDB.settings.whisperTemplateMode=='auto','untouched translated text never becomes custom')
        h.env.DoYouNeedItFrame.settingsButton:FireScript('OnClick')
        local item=ask(h,28901)
        check(#h.sentMessages==1 and h.sentMessages[1].message==core.FormatWhisperMessage(translated,item),'real Ask uses the committed localized default')
        local saved=clone(h.env.DoYouNeedItDB)
        local _,again,againUI=fresh(flavor,nil,saved)
        check(againUI.whisperEditBox:GetText()==translated,'saved auto mode reopens on its localized default')
        check(again.ResolveWhisperTemplate(saved.settings,'enUS')==translated,'reload preserves committed outgoing language')
    end
    local h,core,ui=fresh(flavor,{forceLocale='ruRU'})
    local english=core.DEFAULT_WHISPER_TEMPLATE
    ui.whisperEditBox:SetText(english);ui.whisperEditBox:FireScript('OnEditFocusLost')
    check(h.env.DoYouNeedItDB.settings.whisperTemplateMode=='custom','deliberate English stock wording can remain custom')
    language(h,'zhCN',true)
    check(ui.whisperEditBox:GetText()==english,'custom English is preserved on Chinese UI')
    ui.whisperResetButton:FireScript('OnClick')
    check(h.env.DoYouNeedItDB.settings.whisperTemplateMode=='custom','first Reset click never erases custom text')
    ui.whisperResetButton:FireScript('OnClick')
    check(ui.whisperEditBox:GetText()==core.GetDefaultWhisperTemplate('zhCN'),'confirmed Reset restores the current language default')
    check(h.env.DoYouNeedItDB.settings.whisperTemplateMode=='auto','Reset restores automatic mode')
    language(h,'ruRU',true)
    ui.whisperEditBox:FireScript('OnEditFocusGained');ui.whisperEditBox:SetText(english)
    language(h,'enUS',false)
    check(ui.whisperEditBox:GetText()==english,'a draft coinciding with a hovered default is preserved')
    ui.whisperEditBox:FireScript('OnEditFocusLost')
    check(h.env.DoYouNeedItDB.settings.whisperTemplateMode=='custom','a coincident preview cannot adopt an unsaved draft as the clean default')
    local custom='Мой текст {item}, пожалуйста'
    ui.whisperEditBox:SetText(custom)
    language(h,'deDE',true)
    check(ui.whisperEditBox:GetText()==custom,'language selection preserves an uncommitted custom draft')
    h:fire('PLAYER_LOGOUT')
    check(h.env.DoYouNeedItDB.settings.whisperTemplate==custom and h.env.DoYouNeedItDB.settings.whisperTemplateMode=='custom','logout saves the original draft as custom')
    local preview,previewCore,previewUI=fresh(flavor,{forceLocale='enUS'})
    language(preview,'ruRU',false)
    preview.env.DoYouNeedItFrame.settingsButton:FireScript('OnClick')
    check(preview.env.DoYouNeedItDB.settings.forceLocale=='enUS' and previewCore.IsDefaultWhisperTemplate(preview.env.DoYouNeedItDB.settings),'closing a preview keeps the committed language and automatic mode')
    check(previewCore.ResolveWhisperTemplate(preview.env.DoYouNeedItDB.settings,'enUS')==english,'closing preview never persists translated display text')
    local before=preview.env.DoYouNeedItDB.settings.whisperTemplate
    preview:slash('settings');previewUI.whisperEditBox:SetText('Discard this {item}')
    previewUI.whisperEditBox:FireScript('OnEscapePressed')
    check(previewUI.whisperEditBox:GetText()==english and preview.env.DoYouNeedItDB.settings.whisperTemplate==before,'Escape restores the effective default without committing a draft')
    local auto,autoCore=fresh(flavor,{forceLocale='enUS',autoWhisper=true,autoDelay=3})
    local item=auto:addItem(28902,{name='Pending Localized Sword',bindType=2});auto:fireLoot('Otherplayer',item)
    language(auto,'ruRU',false);auto:runTimers(4)
    check(#auto.sentMessages==1 and auto.sentMessages[1].message==autoCore.FormatWhisperMessage(english,item),'pending automatic whisper ignores a concurrent language hover')
end
print('Localized whisper runtime: '..count..' checks passed')
