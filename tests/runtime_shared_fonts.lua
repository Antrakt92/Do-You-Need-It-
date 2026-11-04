local Harness = dofile("tests/runtime_harness.lua")
local checks = 0
local function check(ok, message) checks = checks + 1; assert(ok, message) end
for _, flavor in ipairs({ "retail", "forever" }) do
    local saved = "Interface\\AddOns\\DoYouNeedIt\\fonts\\DejaVuSans.ttf"
    local h = Harness.new({ flavor = flavor, legacyFontAssets = false,
        db = { settings = { font = saved, forceLocale = "zhTW" } } })
    if flavor == "forever" then
        h.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
        h.env.WOW_PROJECT_ID = 18
    end
    h:loadAddon()
    h:slash("settings")
    local core = h.env.DoYouNeedItCore
    check(type(core.FontPack) == "table", "shared font adapter loads: " .. flavor)
    check(h.env.DoYouNeedItDB.settings.font == saved, "missing package preserves preferred path")
    check(h.env.DoYouNeedItFrame.title:GetFont() == core.FontPack.baselinePath, "foreign UI uses embedded readable baseline")
    h:fire("PLAYER_LOGOUT")
    check(h.env.DoYouNeedItDB.settings.font == saved, "logout never saves fallback over preference")
end
local snapshot = assert(loadfile("AntraktFontCatalog.lua"))()
local function client(flavor, options)
    options = options or {}
    options.flavor, options.legacyFontAssets = flavor, false
    local h = Harness.new(options)
    if flavor == "forever" then
        h.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
        h.env.WOW_PROJECT_ID = 18
    end
    h:loadAddon()
    return h, h.env.DoYouNeedItCore.FontPack
end
for _, flavor in ipairs({ "retail", "forever" }) do
    local calls = 0
    local provider = { GetCatalog = function()
        calls = calls + 1
        return { formatMajor = 1, catalogRevision = "future-compatible-revision", fonts = snapshot.fonts }
    end }
    local old = "Interface\\AddOns\\StatsPro\\fonts\\PT_Sans-Web-Regular.ttf"
    local h, pack = client(flavor, { db = { settings = { font = old } } })
    check(pack.status == "provider-unavailable", "package is optional")
    h.env.AntraktFonts = provider
    h:fire("ADDON_LOADED", "AntraktFonts")
    check(pack.status == "ready", "late compatible provider revision accepted")
    local canonical = "Interface\\AddOns\\AntraktFonts\\fonts\\PT_Sans-Web-Regular.ttf"
    check(h.env.DoYouNeedItFrame.title:GetFont() == canonical, "known historical path resolves to exact provider asset: " .. tostring(h.env.DoYouNeedItFrame.title:GetFont()))
    check(h.env.DoYouNeedItDB.settings.font == old, "canonical resolution does not rewrite saved preference")
    for index = 1, 12 do h:slash("delay 11") end
    check(calls == 1, "detached GetCatalog is cached off repaint hot path")
    local favorites = { [old] = true, ["interface/addons/doyouneedit/fonts/pt_sans-web-regular.ttf"] = true }
    check(pack.IsFavorite(favorites, canonical), "favorites follow canonical identity")
    pack.ToggleFavorite(favorites, canonical)
    check(next(favorites) == nil, "unstar removes every historical alias")
    check(pack.Identity("Interface\\AddOns\\StatsPro\\fonts\\FiraMono-Regular.ttf") == "hack", "retired aliases retain replacement")
    h.env.AntraktFonts = { GetCatalog = function() return { formatMajor = 2, catalogRevision = "future", fonts = {} } end }
    h:fire("ADDON_LOADED", "AntraktFonts")
    check(pack.status == "provider-incompatible", "unknown major uses readable fallback")
    check(h.env.DoYouNeedItFrame.title:GetFont() == pack.baselinePath, "incompatible package never paints invalid provider path")
    check(h.env.DoYouNeedItDB.settings.font == old, "incompatible provider preserves preference")
    for _, bad in ipairs({ {formatMajor=1,catalogRevision="x",fonts={}}, {formatMajor=1,catalogRevision="x",fonts={{id="bad",name="Bad",file="../bad.ttf"}}} }) do
        check(pack.Validate(bad) == nil, "malformed catalogue rejected")
    end
    for _, locale in ipairs({"enUS","deDE","esES","esMX","frFR","itIT","ptBR","ruRU","koKR","zhCN","zhTW"}) do
        local translated, adapted = client(flavor, { db = { settings = { font = old, forceLocale = locale } } })
        translated:slash("settings")
        check(translated.env.DoYouNeedItSettingsFrame.title:GetFont() == adapted.baselinePath, "Settings baseline covers " .. locale)
        check(translated.env.DoYouNeedItDB.settings.font == old, "locale adaptation preserves preference " .. locale)
    end
    local pending = client(flavor, { db = { settings = { font = old } } })
    pending:fire("PLAYER_ENTERING_WORLD")
    local notice = pending.env.DoYouNeedItFontPackNotice
    check(notice and notice:IsShown(), "existing users receive one migration notice")
    check(notice.copy.enabled == false, "unpublished download URL is not fabricated")
    notice:FireScript("OnKeyDown", "ESCAPE")
    check(pending.env.DoYouNeedItDB.fontPackNotice == "acknowledged", "Escape acknowledges before OnHide suspension")
    pending:fire("PLAYER_ENTERING_WORLD")
    check(not notice:IsShown(), "acknowledged notice never repeats on world events")
    local fresh = client(flavor)
    fresh:fire("PLAYER_ENTERING_WORLD")
    check(fresh.env.DoYouNeedItDB.fontPackNotice == "fresh" and not fresh.env.DoYouNeedItFontPackNotice, "fresh install does not get migration popup")
    check(#pending.sentMessages == 0 and #fresh.sentMessages == 0, "font notices never send whispers")
    local ready, readyPack = client(flavor, { fontProvider = provider, db = { settings = { font = old } } })
    ready:fire("PLAYER_ENTERING_WORLD")
    check(not ready.env.DoYouNeedItFontPackNotice, "ready provider suppresses automatic existing-user notice")
    check(ready.env.DoYouNeedItDB.fontPackNotice == "satisfied", "ready provider durably resolves pending campaign without acknowledgement")
    local removed = client(flavor, { db = ready.env.DoYouNeedItDB })
    removed:fire("PLAYER_ENTERING_WORLD")
    check(not removed.env.DoYouNeedItFontPackNotice and removed.env.DoYouNeedItDB.fontPackNotice == "satisfied", "provider removal after reload never revives resolved campaign")
    removed:slash("settings")
    for _, child in ipairs(removed.env.DoYouNeedItSettingsFrame.children) do
        if child.GetText and child:GetText() == "i" then child:FireScript("OnClick") end
    end
    check(removed.env.DoYouNeedItFontPackNotice:IsVisible(), "satisfied account retains explicit information")
    removed.env.DoYouNeedItFontPackNotice.close:FireScript("OnClick")
    check(removed.env.DoYouNeedItDB.fontPackNotice == "acknowledged", "manual satisfied confirmation may acknowledge")
    local late = client(flavor, { db = { settings = { font = old } } })
    late:fire("PLAYER_ENTERING_WORLD")
    local lateNotice = late.env.DoYouNeedItFontPackNotice
    late.env.AntraktFonts = provider; late:fire("ADDON_LOADED", "AntraktFonts")
    check(not lateNotice:IsShown() and late.env.DoYouNeedItDB.fontPackNotice == "satisfied", "late ready package dismisses automatic notice without acknowledgement")
    local peerShown, peerAcknowledged = false, false
    local common = late.env.AntraktFontNoticeCoordinator
    common:Register("PendingPeer", { canShow = function() return true end,
        show = function() peerShown = true; return true end,
        dismiss = function() peerShown = false end,
        acknowledge = function() peerAcknowledged = true; return true end })
    common:RequestShow()
    check(peerShown and not peerAcknowledged, "satisfied owner never suppresses another pending consumer")
    for _, state in ipairs({"fresh", "acknowledged"}) do
        local stable = client(flavor, {fontProvider=provider, db={fontPackNotice=state,settings={font=old}}})
        stable:fire("PLAYER_ENTERING_WORLD")
        check(stable.env.DoYouNeedItDB.fontPackNotice == state and not stable.env.DoYouNeedItFontPackNotice,
            "ready provider preserves existing campaign state: " .. state)
    end
    local safeReady = client(flavor, {fontProvider=provider,db={settings={font=old}}})
    safeReady.env.InCombatLockdown = function() return true end
    safeReady:fire("PLAYER_ENTERING_WORLD")
    check(safeReady.env.DoYouNeedItDB.fontPackNotice == nil and not safeReady.env.DoYouNeedItFontPackNotice,
        "ready resolution waits for safe lifecycle without opening a popup")
    safeReady.env.InCombatLockdown = function() return false end
    safeReady:fire("PLAYER_REGEN_ENABLED")
    check(safeReady.env.DoYouNeedItDB.fontPackNotice == "satisfied", "safe regen persists ready resolution")
    local incompatible, badPack = client(flavor,{fontProvider={GetCatalog=function()return{formatMajor=2}end},db={settings={font=old}}})
    incompatible:fire("PLAYER_ENTERING_WORLD")
    check(incompatible.env.DoYouNeedItFontPackNotice.body:GetText():find(badPack.Message("enUS","incompatible"),1,true),
        "incompatible provider uses translated compatibility guidance")
    local inCombat = true
    local deferred = client(flavor, { db = { settings = { font = old } } })
    deferred.env.InCombatLockdown = function() return inCombat end
    deferred:fire("PLAYER_ENTERING_WORLD")
    check(not deferred.env.DoYouNeedItFontPackNotice, "combat defers notice construction")
    inCombat = false; deferred:fire("PLAYER_REGEN_ENABLED")
    local deferredNotice = deferred.env.DoYouNeedItFontPackNotice
    check(deferredNotice and deferredNotice:IsShown(), "normal regen resumes notice")
    inCombat = true; deferred:fire("PLAYER_REGEN_DISABLED")
    check(not deferredNotice:IsShown() and deferred.env.DoYouNeedItDB.fontPackNotice == nil, "combat hiding is not acknowledgement")
    inCombat = false; deferred:fire("PLAYER_REGEN_ENABLED")
    check(deferredNotice:IsShown(), "suspended presentation returns after combat")
    deferredNotice.close:FireScript("OnClick")
    local previousDB = deferred.env.DoYouNeedItDB
    deferred:fire("PLAYER_LOGOUT")
    local reloaded = client(flavor, { db = previousDB })
    reloaded:fire("PLAYER_ENTERING_WORLD")
    check(not reloaded.env.DoYouNeedItFontPackNotice, "campaign acknowledgement survives real settings reload")
    local legacy, legacyPack = client(flavor, { db = { settings = { font = "Fonts\\FRIZQT__.TTF", fontBeforeAutoSwitch = old } }, fontProvider = provider })
    check(legacy.env.DoYouNeedItFrame.title:GetFont() == canonical, "legacy autoswitch intent resolves without destroying preference")
    check(legacy.env.DoYouNeedItDB.settings.fontBeforeAutoSwitch == old, "original autoswitch intent remains saved")
    legacy:slash("settings")
    check(legacy.env.DoYouNeedItSettingsFrame:IsShown(), "settings remains independently usable")
    local missing, missingPack = client(flavor, { db = { settings = { font = old } } })
    missing:slash("settings")
    check(missing.env.DoYouNeedItFontDropdown.Text:GetText() == "PT Sans", "missing preferred face keeps friendly name")
    local marker
    for _, child in ipairs(missing.env.DoYouNeedItSettingsFrame.children) do
        if child.GetText and child:GetText() == "i" then marker = child end
    end
    check(marker and marker:IsShown(), "missing package marker appears beside Font")
    missing.env.AntraktFonts = provider; missing:fire("ADDON_LOADED", "AntraktFonts")
    check(not marker:IsShown(), "ready provider removes install marker")
    local title
    local failedPath = "Interface\\AddOns\\AntraktFonts\\fonts\\Hack-Regular.ttf"
    local selected, selectedPack = client(flavor, {
        fontProvider = provider, db = { settings = { font = old, fontBeforeAutoSwitch = old } },
        fontSetResult = function(region, path)
            return path ~= failedPath or not title or (region ~= title and region ~= title._dyniOwnedFont)
        end,
    })
    title = selected.env.DoYouNeedItFrame.title
    selected:slash("settings")
    selected.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local failedButton
    for _, button in ipairs(selected.env.DoYouNeedItFontPickerContent.children) do
        if button.fontPath == failedPath then failedButton = button end
    end
    check(failedButton ~= nil, "actual picker offers probe-available face")
    failedButton:FireScript("OnClick", "LeftButton")
    check(selected.env.DoYouNeedItDB.settings.font == old and selected.env.DoYouNeedItDB.settings.fontBeforeAutoSwitch == old,
        "failed actual title application does not commit preference")
    selected.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    for _, button in ipairs(selected.env.DoYouNeedItFontPickerContent.children) do
        if button.fontPath == selectedPack.baselinePath then button:FireScript("OnClick", "LeftButton"); break end
    end
    check(selected.env.DoYouNeedItDB.settings.font == selectedPack.baselinePath
        and selected.env.DoYouNeedItDB.settings.fontBeforeAutoSwitch == nil, "successful explicit choice replaces old intent")
    local starred = client(flavor, { fontProvider = provider,
        db = { settings = { font = old, fontFavorites = { [old] = true } } } })
    starred:slash("settings"); starred.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local starredRow
    for _, button in ipairs(starred.env.DoYouNeedItFontPickerContent.children) do
        if button.fontPath == canonical then starredRow = button end
    end
    check(starredRow and starredRow.selected, "canonical picker face keeps historical selection")
    check(starredRow.star.icon.texture:find("filled", 1, true), "historical favorite paints a filled canonical star")
    starredRow.star:FireScript("OnClick")
    check(next(starred.env.DoYouNeedItDB.settings.fontFavorites) == nil, "real star button removes historical favorite")
    local hidden = client(flavor, { db = { settings = { font = old } } })
    hidden.env.UIParent:Hide(); hidden:fire("PLAYER_ENTERING_WORLD")
    check(not hidden.env.DoYouNeedItFontPackNotice or not hidden.env.DoYouNeedItFontPackNotice:IsShown(), "hidden ancestry is failed display, not successful presentation")
    check(hidden.env.DoYouNeedItDB.fontPackNotice == nil, "failed actual visibility never acknowledges")
    hidden.env.UIParent:Show(); hidden:fire("PLAYER_ENTERING_WORLD")
    check(hidden.env.DoYouNeedItFontPackNotice:IsVisible(), "normal event recovers actual visibility")
    local copyClient, copyPack = client(flavor, { db = { settings = { font = old } } })
    -- A non-routable test URL exercises the copy UI; product links remain unset.
    copyPack.snapshot.links.github = "https://example.invalid/fonts"
    copyClient:fire("PLAYER_ENTERING_WORLD")
    local originalCreate = copyClient.env.CreateFrame
    copyClient.env.CreateFrame = function(kind, name, parent, template)
        local frame = originalCreate(kind, name, parent, template)
        if name == "DoYouNeedItDeveloperLink" then frame.SetSize = function() error("partial link setup") end end
        return frame
    end
    copyClient.env.DoYouNeedItFontPackNotice.copy:FireScript("OnClick")
    check(copyClient.env.DoYouNeedItDB.fontPackNotice == nil, "failed copy dialog cannot acknowledge")
    check(not copyClient.env.DoYouNeedItDeveloperLink:IsShown(), "partial copy dialog is cleaned up")
    copyClient.env.CreateFrame = originalCreate
    copyClient.env.DoYouNeedItFontPackNotice.copy:FireScript("OnClick")
    check(copyClient.env.DoYouNeedItDB.fontPackNotice == "acknowledged"
        and copyClient.env.DoYouNeedItDeveloperLink:IsVisible(), "only usable visible copy dialog acknowledges")
    check(not copyClient.env.DoYouNeedItFontPackNotice:IsShown(), "successful copy hands presentation to link dialog")
    local function markerFor(h)
        for _, child in ipairs(h.env.DoYouNeedItSettingsFrame.children) do
            if child.GetText and child:GetText() == "i" then return child end
        end
        error("font information marker missing")
    end
    for _, state in ipairs({ "pending", "fresh", "acknowledged" }) do
        local manual = client(flavor, { db = { fontPackNotice = state ~= "pending" and state or nil,
            settings = { font = old } } })
        manual:slash("settings"); manual:fire("PLAYER_ENTERING_WORLD")
        local info = markerFor(manual)
        manual.env.InCombatLockdown = function() return true end
        info:FireScript("OnClick")
        check(not manual.env.DoYouNeedItFontPackNotice, "manual marker respects combat: " .. state)
        manual.env.InCombatLockdown = function() return false end
        info:FireScript("OnClick")
        local window = manual.env.DoYouNeedItFontPackNotice
        check(window and window:IsVisible(), "manual marker opens from Settings: " .. state)
        check(manual.env.DoYouNeedItDB.fontPackNotice == (state ~= "pending" and state or nil), "manual opening never acknowledges")
        window:Hide()
        check(manual.env.DoYouNeedItDB.fontPackNotice == (state ~= "pending" and state or nil), "manual generic hide never acknowledges")
        info:FireScript("OnClick"); window.close:FireScript("OnClick")
        check(manual.env.DoYouNeedItDB.fontPackNotice == "acknowledged", "manual Got It durably acknowledges: " .. state)
        manual.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
        check(not window:IsShown(), "closing Settings after manual Got It never repeats campaign")
        manual:slash("settings"); info:FireScript("OnClick")
        check(window:IsVisible(), "acknowledged owner can revisit manual information")
        window:FireScript("OnKeyDown", "ESCAPE")
    end
    local busyClient = client(flavor, { db = { settings = { font = old } } })
    busyClient:slash("settings"); busyClient:fire("PLAYER_ENTERING_WORLD")
    local shared = busyClient.env.AntraktFontNoticeCoordinator
    local releaseOther
    shared:Register("OtherHost", { state = "fresh", canShow = function() return true end,
        show = function(_, suspend) releaseOther = suspend; return true end,
        dismiss = function() if releaseOther then releaseOther() end end,
        acknowledge = function() return true end })
    shared:RequestInfo("OtherHost")
    markerFor(busyClient):FireScript("OnClick")
    check(not busyClient.env.DoYouNeedItFontPackNotice, "actual marker shares another host's busy presentation")
    releaseOther()
    local requestInfo = shared.RequestInfo
    shared.RequestInfo = function() error("manual coordinator failure") end
    markerFor(busyClient):FireScript("OnClick")
    shared.RequestInfo = requestInfo
    busyClient:fire("PLAYER_REGEN_ENABLED")
    check(not busyClient.env.DoYouNeedItFontPackNotice, "failed manual request clears Settings bypass exception-safely")
    markerFor(busyClient):FireScript("OnClick")
    check(busyClient.env.DoYouNeedItFontPackNotice:IsVisible(), "actual marker recovers after busy/error deferral")
    busyClient:fire("PLAYER_REGEN_DISABLED")
    check(not busyClient.env.DoYouNeedItFontPackNotice:IsShown()
        and busyClient.env.DoYouNeedItDB.fontPackNotice == nil, "combat hides manual information without acknowledgement")
    local queued = client(flavor, { db = { settings = { font = old } } })
    queued:slash("settings"); queued:fire("PLAYER_ENTERING_WORLD")
    check(not queued.env.DoYouNeedItFontPackNotice, "active Settings defers migration notice")
    queued.env.DoYouNeedItFrame.settingsButton:FireScript("OnClick")
    check(queued.env.DoYouNeedItFontPackNotice and queued.env.DoYouNeedItFontPackNotice:IsVisible(), "closing Settings resumes pending notice without polling")
end
for _, flavor in ipairs({ "retail", "forever" }) do
    local h, pack = client(flavor)
    local addon
    for index = 1, 30 do
        local name, value = debug.getupvalue(h.env.SlashCmdList.DOYOUNEEDIT, index)
        if name == "Addon" then addon = value end
    end
    assert(addon)
    local region = h.env.UIParent:CreateFontString(nil, "OVERLAY")
    local actualFlags = "OUTLINE, THICKOUTLINE"
    local originalGetFont = region.GetFont
    region.GetFont = function(self)
        local path, size = originalGetFont(self)
        return path, size, actualFlags
    end
    check(addon.ApplyRegionFont(region, pack.baselinePath, 14, "THICKOUTLINE"),
        "native thick outline readback accepts implied OUTLINE: " .. flavor)
    for _, case in ipairs({
        {" THICKOUTLINE , OUTLINE ", "THICKOUTLINE", true},
        {"MONOCHROME, THICKOUTLINE, OUTLINE", "THICKOUTLINE, MONOCHROME", true},
        {"OUTLINE, MONOCHROME", " MONOCHROME , OUTLINE ", true},
        {"", nil, true}, {"OUTLINE", "THICKOUTLINE", false},
        {"THICKOUTLINE", "OUTLINE", false},
        {"THICKOUTLINE, MONOCHROME", "THICKOUTLINE", false},
        {"OUTLINE, UNKNOWN", "OUTLINE", false},
        {"OUTLINE,,THICKOUTLINE", "THICKOUTLINE", false},
        {"OUTLINE,", "OUTLINE", false}, {"OUTLINE OUTLINE", "OUTLINE", false},
        {"OUTLINE,OUTLINE", "OUTLINE", false},
        {"OUTLINE", "UNKNOWN", false},
    }) do
        actualFlags = case[1]
        check(addon.RegionFontMatches(region, pack.baselinePath, 14, case[2]) == case[3],
            "font flag semantics reject missing, extra or malformed effects: " .. case[1])
    end
    actualFlags = h:secretValue("font flags")
    check(not addon.RegionFontMatches(region, pack.baselinePath, 14, ""), "secret flags cannot prove successful application")
end
for _, flavor in ipairs({ "retail", "forever" }) do
    local updated = {}
    for index, row in ipairs(snapshot.fonts) do updated[index] = row end
    updated[1] = {}
    for key, value in pairs(snapshot.fonts[1]) do updated[1][key] = value end
    updated[1].name = "Updated Provider Face"
    local _, pack = client(flavor, {fontProvider={GetCatalog=function()
        return {formatMajor=1,catalogRevision="independent-name-update",fonts=updated}
    end}})
    check(pack.Name(updated[1].path) == updated[1].name, "current provider name wins for canonical path")
    check(pack.Name(updated[1].aliases[1]) == updated[1].name, "current provider name wins for saved legacy alias")
end
for _, flavor in ipairs({"retail", "forever"}) do
    local calls = 0
    local provider = {GetCatalog=function()
        calls = calls + 1
        return {formatMajor=1,catalogRevision="settings-preview",fonts=snapshot.fonts}
    end}
    local baseline = "Interface\\AddOns\\DoYouNeedIt\\fonts\\AntraktUISans.ttf"
    local h = client(flavor, {fontProvider=provider,db={settings={font=baseline,forceLocale="enUS"}}})
    h:slash("settings")
    local settings = h.env.DoYouNeedItSettingsFrame
    local regions = {settings.title,settings.whisperLabel,settings.autoCheckLabel,settings.delayLabel,
        settings.languageLabel,settings.fontLabel,settings.fontSizeLabel,settings.qualityHeading,
        settings.qualityButtons[1].text,settings.whisperResetButton:GetFontString(),
        settings.languageDropdown.Text,settings.fontDropdown.Text,settings.whisperEditBox}
    local saved = {}
    for index, region in ipairs(regions) do saved[index]={region:GetFont()} end
    h.env.DoYouNeedItFontDropdown:FireScript("OnClick", "LeftButton")
    local row
    for _, candidate in ipairs(h.env.DoYouNeedItFontPickerContent.children) do
        if candidate.fontPath and candidate.fontPath:find("DejaVuSans.ttf",1,true) then row=candidate end
    end
    assert(row,"preview face is available")
    local catalogFace = row.text:GetFont()
    local resetText = settings.whisperResetButton:GetFontString()
    resetText.GetStringWidth = function(self) return self:GetFont()==row.fontPath and 200 or 20 end
    local function assertFont(path, context)
        for _, region in ipairs(regions) do
            check(region:GetFont()==path,context .. ": " .. tostring(region:GetText()))
        end
    end
    row:FireScript("OnEnter")
    assertFont(row.fontPath,"hover previews every owned Settings text group")
    check(row.text:GetFont()==catalogFace,"catalogue labels remain independent of hovered face")
    check(settings.whisperResetButton:GetWidth()==100,"hover reflows wide label metrics within Settings bounds")
    check(h.env.DoYouNeedItDB.settings.font==baseline,"hover leaves saved font untouched")
    row:FireScript("OnLeave"); h:runTimers()
    for index,region in ipairs(regions) do
        local path,size,flags=region:GetFont()
        check(path==saved[index][1] and size==saved[index][2] and flags==saved[index][3],"leaving restores exact font style")
    end
    check(settings.whisperResetButton:GetWidth()==60,"leaving restores compact label layout")
    row:FireScript("OnEnter")
    h.env.DoYouNeedItFontPicker:Hide()
    assertFont(baseline,"picker cancellation restores saved face")
    h.env.DoYouNeedItFontDropdown:FireScript("OnClick","LeftButton")
    row:FireScript("OnEnter"); row:FireScript("OnClick","LeftButton")
    assertFont(baseline,"explicit selection restores normal Settings typography")
    check(h.env.DoYouNeedItFrame.title:GetFont()==row.fontPath,"explicit selection still updates loot typography")
    check(h.env.DoYouNeedItDB.settings.font==row.fontPath,"only explicit click persists face")
    local selected=row.fontPath
    h.env.DoYouNeedItLanguageDropdown:FireScript("OnClick","LeftButton")
    local chinese
    for _,button in ipairs(h.env.DoYouNeedItLanguagePicker.buttons) do if button.value=="zhTW" then chinese=button end end
    assert(chinese)
    chinese:FireScript("OnEnter")
    for _,region in ipairs(regions) do
        check(h.env.DoYouNeedItCore.FontSupportsLocale(region:GetFont(),"zhTW","enUS"),"foreign language preview keeps Settings readable")
    end
    check(h.env.DoYouNeedItDB.settings.font==selected and h.env.DoYouNeedItDB.settings.forceLocale=="enUS","language hover preserves chosen preferences")
    h.env.DoYouNeedItLanguagePicker:Hide()
    assertFont(baseline,"language cancellation restores normal Settings typography")
    check(calls==1,"hover and restore never clone provider catalogue per text region")
end
for _,flavor in ipairs({"retail","forever"}) do
    local h,pack=client(flavor,{db={settings={font="Fonts\\ARIALN.TTF"}}})
    h.env.C_AddOns={DoesAddOnExist=function()return true end,
        GetAddOnEnableState=function(name)check(name=="AntraktFonts","modern enable argument order");return 0 end,
        IsAddOnLoaded=function()return false,false end}
    pack.RefreshMetadata();pack.Invalidate();pack.Sync()
    check(pack.status=="provider-disabled","proved installed but disabled has truthful state")
end
for _,flavor in ipairs({"retail","forever"}) do
    for _,case in ipairs({
        {"missing",false,0,false,false,"provider-unavailable","missing"},
        {"disabled",true,0,false,false,"provider-disabled","disabled"},
        {"enabled not loaded",true,2,false,false,"provider-not-loaded","notLoaded"},
        {"loading only",true,2,true,false,"provider-not-loaded","notLoaded"},
        {"ambiguous modern tuple",true,2,true,nil,"provider-not-loaded","notLoaded"},
        {"secret modern loaded",true,2,true,"secret","provider-not-loaded","notLoaded"},
        {"malformed modern loaded",true,2,true,"invalid","provider-not-loaded","notLoaded"},
        {"loaded invalid API",true,2,true,true,"provider-incompatible","incompatible"},
        {"missing APIs",nil,nil,nil,nil,"provider-not-loaded","notLoaded"},
        {"existence throws","throw",0,false,false,"provider-not-loaded","notLoaded"},
        {"secret existence","secret",0,false,false,"provider-not-loaded","notLoaded"},
        {"unknown character",true,0,false,false,"provider-not-loaded","notLoaded",nil,"noGUID"},
        {"secret character",true,0,false,false,"provider-not-loaded","notLoaded",nil,"secretGUID"},
        {"secret enabled",true,"secret",false,false,"provider-not-loaded","notLoaded"},
        {"legacy disabled",true,0,false,false,"provider-disabled","disabled","legacy"},
        {"ambiguous legacy tuple",true,2,true,nil,"provider-not-loaded","notLoaded","legacy"},
        {"legacy missing echo",false,0,false,false,"provider-unavailable","missing","legacy"},
        {"unproved legacy echo",true,0,false,false,"provider-not-loaded","notLoaded","legacy",nil,"unindexed"},
    }) do
        local h,pack=client(flavor,{db={settings={font="Fonts\\ARIALN.TTF"}}})
        local restricted=h:secretValue("addon metadata")
        local reads,enables=0,0
        h.env.UnitGUID=function() return case[9]=="noGUID" and nil or case[9]=="secretGUID" and restricted or "Player-1-123ABC" end
        if case[9]=="noGUID" then h.env.UnitGUID=function()return nil end end
        local function enable(a,b)
            enables=enables+1
            check((case[8]=="legacy" and a=="Player-1-123ABC" and b=="AntraktFonts")
                or (case[8]~="legacy" and a=="AntraktFonts" and b=="Player-1-123ABC"),"explicit current-character enable arguments")
            return case[3]=="secret" and restricted or case[3]
        end
        local info=function(index)
            check(type(index)=="number","existence fallback uses bounded actual indices, never a name echo")
            return case[2]==false and "OtherAddon" or "AntraktFonts","title","notes",false,""
        end
        h.env.C_AddOns=nil
        if case[8]=="legacy" then
            h.env.GetAddOnInfo=info;h.env.GetAddOnEnableState=enable
            h.env.IsAddOnLoaded=function()return case[4],case[5]=="secret" and restricted or case[5] end
            if case[10]~="unindexed" then h.env.GetNumAddOns=function()return 1 end end
        elseif case[2]~=nil then
            h.env.C_AddOns={DoesAddOnExist=function()
                reads=reads+1
                if case[2]=="throw" then error("metadata unavailable") end
                return case[2]=="secret" and restricted or case[2]
            end,GetAddOnInfo=info,GetAddOnEnableState=enable,IsAddOnLoaded=function()return case[4],case[5]=="secret" and restricted or case[5] end}
        end
        h:fire("PLAYER_ENTERING_WORLD")
        check(pack.status==case[6],"honest provider state: "..case[1].." / "..flavor)
        if case[2]==false or case[2]=="throw" or case[2]=="secret" or case[9] then check(enables==0,"unknown or missing installation/character never authorizes enable-state inference") end
        local window=assert(h.env.DoYouNeedItFontPackNotice)
        local message=pack.Message("enUS",case[7])
        check(message~="" and window.body:GetText():find(message,1,true),"notice body reports actual package state")
        if case[6]=="provider-disabled" or case[6]=="provider-not-loaded" then
            check(not window.copy:IsShown() and not window.copy:IsEnabled(),"installed or uncertain package needs no download action")
            check(not window.body:GetText():find(pack.Message("enUS","linkUnavailable"),1,true),"no false unavailable-link claim")
        end
        window.close:FireScript("OnClick");h:slash("settings")
        local marker
        for _,child in ipairs(h.env.DoYouNeedItSettingsFrame.children)do if child.GetText and child:GetText()=="i" then marker=child end end
        marker:FireScript("OnEnter")
        local hint=case[7]=="missing" and pack.Message("enUS","settingsMissing") or message
        check(h.env.GameTooltip:GetText():find(hint,1,true),"marker uses same truthful state before selected-font detail")
        local before=reads;local generation=pack.generation
        for _=1,5 do marker:FireScript("OnEnter");h:slash("delay 11") end
        check(reads==before and pack.generation==generation,"hover/repaint never polls addon installation or invalidates catalogue")
        check(h.env.DoYouNeedItDB.settings.font=="Fonts\\ARIALN.TTF","metadata guidance leaves preference untouched")
    end
end
for _,flavor in ipairs({"retail","forever"}) do
    local h,pack=client(flavor,{db={settings={font="Fonts\\ARIALN.TTF"}}})
    local enabled,reads,calls=0,0,0
    h.env.C_AddOns={DoesAddOnExist=function()reads=reads+1;return true end,
        GetAddOnEnableState=function()return enabled end,IsAddOnLoaded=function()return false,false end}
    h:slash("settings");check(pack.status=="provider-disabled","opening Settings refreshes disabled state")
    local generation=pack.generation
    enabled=2;h:slash("settings")
    check(pack.status=="provider-not-loaded" and pack.generation==generation,"changed enable state refreshes without rebuilding font catalogue")
    h:fire("PLAYER_ENTERING_WORLD")
    h.env.AntraktFonts={GetCatalog=function()calls=calls+1;return{formatMajor=1,catalogRevision="loaded-later",fonts=snapshot.fonts}end}
    h:fire("ADDON_LOADED","AntraktFonts")
    check(pack.status=="ready" and h.env.DoYouNeedItDB.fontPackNotice=="satisfied","late compatible package resolves campaign quietly")
    local marker
    for _,child in ipairs(h.env.DoYouNeedItSettingsFrame.children)do if child.GetText and child:GetText()=="i" then marker=child end end
    check(not marker:IsShown(),"compatible loaded package removes state marker")
    for _=1,8 do h:slash("delay 11") end
    check(calls==1,"late loaded provider catalogue remains cached")
    local saved="Interface\\AddOns\\StatsPro\\fonts\\DejaVuSans.ttf"
    local old,legacy=client(flavor,{db={settings={font=saved}}})
    old.env.C_AddOns={DoesAddOnExist=function()return true end,GetAddOnEnableState=function()return 0 end}
    old:fire("PLAYER_ENTERING_WORLD")
    check(legacy.Resolve(saved)==saved and old.env.DoYouNeedItFrame.title:GetFont()==saved,"disabled package preserves usable historical consumer asset")
    check(not old.env.DoYouNeedItFontPackNotice.body:GetText():find(legacy.Message("enUS","selectedMissing"):gsub("%%s","DejaVu Sans"),1,true),"working legacy face is not falsely missing")
end
for _,flavor in ipairs({"retail","forever"})do
    for _,case in ipairs({{0,"provider-unavailable"},{1,"provider-unavailable"},{1025,"provider-not-loaded"},{0/0,"provider-not-loaded"},{false,"provider-not-loaded"},{1,"provider-not-loaded",true}})do
        local h,pack=client(flavor)
        local queries=0
        h.env.C_AddOns=nil
        h.env.GetNumAddOns=function()return case[1]end
        h.env.GetAddOnInfo=function(index)
            queries=queries+1;check(index==1,"bounded enumeration never queries a name or out-of-range index")
            if case[3]then return h:secretValue("indexed addon name")end
            return "OtherAddon"
        end
        pack.RefreshMetadata()
        check(pack.status==case[2],"unproved or malformed inventories stay neutral")
        check(queries<=1,"oversized and invalid addon counts never enumerate")
    end
end
for _,flavor in ipairs({"retail","forever"})do
    local h,pack=client(flavor)
    h.env.DoesAddOnExist=function()return false end
    h.env.GetNumAddOns=function()return 0 end
    h.env.GetAddOnInfo=function()error("invalid modern method must also block indexed fallback")end
    for _,namespace in ipairs({{DoesAddOnExist=123},123,setmetatable({},{}) ,h:secretValue("addon namespace"),{DoesAddOnExist=h:secretValue("addon method")}})do
        h.env.C_AddOns=namespace
        pack.RefreshMetadata()
        check(pack.status=="provider-not-loaded","present invalid modern API never falls back to conflicting legacy evidence")
    end
end
for _,flavor in ipairs({"retail","forever"})do
    for _,enabled in ipairs({0,2})do
        local h,pack=client(flavor,{db={settings={font="Fonts\\ARIALN.TTF"}}})
        pack.snapshot.links.github="https://example.invalid/shared-fonts"
        h:fire("PLAYER_ENTERING_WORLD")
        local window=h.env.DoYouNeedItFontPackNotice
        check(window.copy:IsEnabled(),"real test URL makes stale download action exercisable")
        h.env.C_AddOns={DoesAddOnExist=function()return true end,GetAddOnEnableState=function()return enabled end}
        pack.RefreshMetadata()
        window.copy:FireScript("OnClick")
        check(not h.env.DoYouNeedItDeveloperLink and h.env.DoYouNeedItDB.fontPackNotice==nil,
            "stale rendered download callback cannot open or acknowledge after installed-state transition")
    end
end
for _,flavor in ipairs({"retail","forever"})do
    for _,state in ipairs({"provider-disabled","provider-not-loaded","provider-unavailable"})do
        for _,available in ipairs({true,false})do
            local preferred="Interface\\AddOns\\AntraktFonts\\fonts\\DejaVuSans.ttf"
            local h,pack=client(flavor,{sharedFontAssets=true,db={fontPackNotice="acknowledged",settings={font=preferred}},
                fontSetResult=function(_,path)return path~=preferred or available end})
            h.env.C_AddOns={DoesAddOnExist=function()return state~="provider-unavailable"end,
                GetAddOnEnableState=function()return state=="provider-disabled" and 0 or 2 end,
                IsAddOnLoaded=function()return false,false end}
            h:fire("PLAYER_ENTERING_WORLD");h:slash("settings")
            check(pack.status==state,"physical availability never changes package guidance state")
            check(pack.Resolve(preferred)==preferred,"known exact canonical filename keeps its physical path")
            check(h.env.DoYouNeedItFrame.title:GetFont()==(available and preferred or pack.baselinePath),
                "actual canonical readback alone authorizes selected face: "..state)
            check(h.env.DoYouNeedItDB.settings.font==preferred,"canonical preference survives every package/file state")
            check(h.env.DoYouNeedItFontDropdown.Text:GetText()=="DejaVu Sans","caption retains the selected face name")
            local marker
            for _,child in ipairs(h.env.DoYouNeedItSettingsFrame.children)do if child.GetText and child:GetText()=="i"then marker=child end end
            marker:FireScript("OnEnter")
            local hint=h.env.GameTooltip:GetText()
            local base=pack.Message("enUS",state=="provider-disabled" and "disabled" or state=="provider-not-loaded" and "notLoaded" or "settingsMissing")
            check(hint:find(base,1,true),"package state remains the leading guidance")
            check((hint:find(string.format(pack.Message("enUS","selectedMissing"),"DejaVu Sans"),1,true)~=nil)==not available,
                "only a genuinely failed physical face receives missing-font detail")
            local retired="Interface\\AddOns\\StatsPro\\fonts\\FiraMono-Regular.ttf"
            check(pack.Resolve(retired)~=retired and pack.Identity(retired)=="hack","retired alias still resolves its retained replacement")
        end
    end
    local unknown="Interface\\AddOns\\AntraktFonts\\fonts\\UnknownFace.ttf"
    local h,pack=client(flavor,{sharedFontAssets=true,db={settings={font=unknown}}})
    h:fire("PLAYER_ENTERING_WORLD")
    check(h.env.DoYouNeedItFrame.title:GetFont()==pack.baselinePath,"unregistered unknown canonical filename never inherits owned-font approval")
end
for _,flavor in ipairs({"retail","forever"})do
    local h,pack=client(flavor)
    local enabled,saves,reloads=0,0,0
    h.env.ReloadUI=function()reloads=reloads+1 end
    h.env.C_AddOns={DoesAddOnExist=function()return true end,
        GetAddOnEnableState=function()return enabled end,IsAddOnLoaded=function()return false,false end,
        EnableAddOn=function(name,character)
            check(name=="AntraktFonts" and character=="PlayerGUID","enable targets only current character")
            enabled=2
        end,SaveAddOns=function()saves=saves+1 end,IsAddOnLoadOnDemand=function()return false end}
    check(pack.EnableProvider()=="reload-requested" and enabled==2 and saves==1 and reloads==1,
        "one explicit enable click saves and reloads the current-character package")
end
for _,flavor in ipairs({"retail","forever"})do
    local function actionClient(legacy)
        local h,pack=client(flavor,{db={settings={font="Fonts\\ARIALN.TTF"}}})
        local state={enabled=0,enables=0,saves=0,reloads=0,exists=true}
        local methods={DoesAddOnExist=function()return state.exists end,IsAddOnLoaded=function()return false,false end,
            GetAddOnEnableState=function(a,b)
                check(legacy and a=="PlayerGUID" and b=="AntraktFonts" or not legacy and a=="AntraktFonts" and b=="PlayerGUID","enable-state query is character-scoped")
                return state.enabled
            end,
            EnableAddOn=function(name,guid)
                check(name=="AntraktFonts" and guid=="PlayerGUID","modern and legacy enable both use name then GUID")
                state.enables=state.enables+1;state.enabled=2
            end,SaveAddOns=function(...)
                check(select("#",...)==0,"save receives no helper return values")
                state.saves=state.saves+1
            end,LoadAddOn=function()error("non-load-on-demand provider must never be loaded implicitly")end}
        if legacy then h.env.C_AddOns=nil;for name,method in pairs(methods)do h.env[name]=method end
        else h.env.C_AddOns=methods end
        h.env.ReloadUI=function()state.reloads=state.reloads+1 end
        h:fire("PLAYER_ENTERING_WORLD")
        return h,pack,state,methods
    end
    for _,legacy in ipairs({false,true})do
        local h,pack,state=actionClient(legacy)
        local window=h.env.DoYouNeedItFontPackNotice
        check(window.action=="enable" and window.actionButton:IsVisible(),"disabled information offers explicit Enable")
        window.actionButton:FireScript("OnClick")
        check(state.enables==1 and state.saves==1 and state.reloads==1,"one explicit enable click saves and reloads exactly once")
        check(window:IsVisible() and window.action=="reload" and window.actionButton:GetText()==pack.Message("enUS","reload"),"same owned presentation now offers explicit Reload UI")
        check(h.env.DoYouNeedItDB.fontPackNotice==nil and h.env.DoYouNeedItDB.settings.font=="Fonts\\ARIALN.TTF","enable never acknowledges notice or changes font preference")
        local busy,owner=h.env.AntraktFontNoticeCoordinator:RequestShow()
        check(busy and owner=="DoYouNeedIt","enable state transition retains common modal ownership")
    end
    for _,mode in ipairs({"combat","secretCombat","secretGUID","missingGUID","missing","ready","reloadMissing","saveMissing","saveInvalid","listVisible","listHiddenParent","listUnknown","enableError","partialEnableError","unchanged","saveError","hidden"})do
        local h,pack,state,methods=actionClient(false)
        local window=h.env.DoYouNeedItFontPackNotice
        if mode=="combat"then h.env.InCombatLockdown=function()return true end
        elseif mode=="secretCombat"then h.env.InCombatLockdown=function()return h:secretValue("combat")end
        elseif mode=="secretGUID"then h.env.UnitGUID=function()return h:secretValue("character")end
        elseif mode=="missingGUID"then h.env.UnitGUID=function()return nil end
        elseif mode=="missing"then state.exists=false
        elseif mode=="ready"then h.env.AntraktFonts={GetCatalog=function()return{formatMajor=1,catalogRevision="ready-before-click",fonts=snapshot.fonts}end}
        elseif mode=="reloadMissing"then h.env.ReloadUI=nil
        elseif mode=="saveMissing"then methods.SaveAddOns=nil
        elseif mode=="saveInvalid"then methods.SaveAddOns=123;h.env.SaveAddOns=function()error("no conflicting legacy save")end
        elseif mode=="listVisible"then h.env.AddonList={IsVisible=function()return true end}
        elseif mode=="listHiddenParent"then h.env.AddonList={IsVisible=function()return false end,IsShown=function()return true end}
        elseif mode=="listUnknown"then h.env.AddonList={IsVisible=function()error("unknown visibility")end}
        elseif mode=="enableError"then methods.EnableAddOn=function()state.enables=state.enables+1;error("enable failed")end
        elseif mode=="partialEnableError"then methods.EnableAddOn=function()state.enables=state.enables+1;state.enabled=2;error("enable partly changed state")end
        elseif mode=="unchanged"then methods.EnableAddOn=function()state.enables=state.enables+1 end
        elseif mode=="saveError"then methods.SaveAddOns=function()state.saves=state.saves+1;error("save failed")end
        elseif mode=="hidden"then window:Hide()end
        window.actionButton:FireScript("OnClick")
        check(state.reloads==0,"guarded or failed enable never reloads: "..mode)
        if mode=="enableError"or mode=="unchanged"then
            check(state.saves==0 and window.body:GetText():find(pack.Message("enUS","enableFailed"),1,true),"failed enable stays truthful before saving")
        elseif mode=="partialEnableError"then check(state.enables==1 and state.saves==0 and pack.actionResult=="failed","partial enable error never saves or reloads despite changed readback")
        elseif mode=="saveError"then check(state.enables==1 and state.saves==1 and pack.actionResult=="failed","save failure is contained without success claim")
        else check(state.enables==0 and state.saves==0,"unsafe or stale enable performs no global writes: "..mode)end
    end
    for _,mode in ipairs({"combat","missing","disabled","ready","saveError","disabledDuringSave","combatDuringSave","hidden"})do
        local h,pack,state,methods=actionClient(false)
        local window=h.env.DoYouNeedItFontPackNotice
        window.actionButton:FireScript("OnClick")
        state.reloads=0 -- The mock returned from the completed enable/reload; test a later recovery action.
        local before=state.saves
        if mode=="combat"then h.env.InCombatLockdown=function()return true end
        elseif mode=="missing"then state.exists=false
        elseif mode=="disabled"then state.enabled=0
        elseif mode=="ready"then h.env.AntraktFonts={GetCatalog=function()return{formatMajor=1,catalogRevision="ready-before-reload",fonts=snapshot.fonts}end}
        elseif mode=="saveError"then methods.SaveAddOns=function()state.saves=state.saves+1;error("save failed")end
        elseif mode=="disabledDuringSave"then methods.SaveAddOns=function()state.saves=state.saves+1;state.enabled=0 end
        elseif mode=="combatDuringSave"then methods.SaveAddOns=function()state.saves=state.saves+1;h.env.InCombatLockdown=function()return true end end
        elseif mode=="hidden"then window:Hide()end
        window.actionButton:FireScript("OnClick")
        check(state.reloads==0,"stale, hidden, combat or save-failed reload is blocked: "..mode)
        check(state.saves==before+((mode=="saveError" or mode=="disabledDuringSave" or mode=="combatDuringSave") and 1 or 0),"reload guards precede global saves")
    end
end
for _,flavor in ipairs({"retail","forever"})do
    for _,action in ipairs({"enable","reload"})do
        local h,pack=client(flavor)
        local enabled,combat,saves,reloads,armed=0,false,0,0,false
        h.env.InCombatLockdown=function()return combat end
        h.env.C_AddOns={DoesAddOnExist=function()return true end,IsAddOnLoaded=function()return false,false end,
            GetAddOnEnableState=function()
                if enabled==2 and (action=="enable" or armed)then combat=true end
                return enabled
            end,EnableAddOn=function()enabled=2 end,
            SaveAddOns=function()saves=saves+1;armed=true end}
        h.env.ReloadUI=function()reloads=reloads+1 end
        if action=="enable"then
            pack.EnableProvider()
            check(saves==0,"combat discovered during enabled readback blocks SaveAddOns")
        else
            pack.EnableProvider()
            check(reloads==0,"combat discovered during enable final metadata blocks same-click reload")
            armed=false;combat=false;reloads=0
            pack.ReloadProvider()
            check(reloads==0 and saves==2,"combat discovered in post-save metadata blocks ReloadUI")
        end
    end
end
for _,flavor in ipairs({"retail","forever"})do
    local h,pack=client(flavor)
    local createFrame=h.env.CreateFrame
    local markerTextReady=false
    h.env.CreateFrame=function(...)
        local frame=createFrame(...)
        local setText=frame.SetText
        frame.SetText=function(self,value)
            if value=="i" and self:GetWidth()==24 and self.GetFontString and self:GetFontString()then
                check(self:GetFontString():GetFont()==pack.baselinePath,"marker font is initialized before its first glyph")
                markerTextReady=true
            end
            return setText(self,value)
        end
        return frame
    end
    h:slash("settings");h:fire("PLAYER_ENTERING_WORLD")
    local settings=h.env.DoYouNeedItSettingsFrame
    local marker
    for _,child in ipairs(settings.children)do if child.GetText and child:GetText()=="i"then marker=child end end
    check(marker:GetFontString():GetFont()==pack.baselinePath,"information marker has an explicit readable font")
    check(markerTextReady and marker.mouseEnabled==true,"information marker is initialized and mouse enabled")
    local addon
    for index=1,30 do local name,value=debug.getupvalue(h.env.SlashCmdList.DOYOUNEEDIT,index);if name=="Addon"then addon=value end end
    for _,width in ipairs({540,840})do
        h.env.DoYouNeedItFrame:SetWidth(width);addon.LayoutSettings()
        local x=settings.fontDropdown.points[1][4]
        local gap=marker.points[1][4]
        local right=x+settings.fontDropdown:GetWidth()+gap+marker:GetWidth()
        local surfaceRight=settings.appearanceSurface.points[2][4]
        check(gap>=8 and marker:GetWidth()>=24 and marker:GetHeight()>=24,"marker has a separate full click target")
        check(right<=surfaceRight-8,"marker stays inside Appearance instead of overlapping its gutter")
        check(right+8<=settings.qualityButtons[1].points[1][4],"information target never overlaps quality controls")
    end
    marker:FireScript("OnClick")
    local notice=h.env.DoYouNeedItFontPackNotice
    check(notice and notice:IsVisible() and notice:GetFrameLevel()>settings:GetFrameLevel(),"information click opens above Settings, not behind it")
    h.env.AntraktWindowLayers.Focus(h.env.DoYouNeedItFrame)
    marker:FireScript("OnClick")
    check(notice:GetFrameLevel()>settings:GetFrameLevel(),"repeated information click raises the existing coordinated window")
    check(h.env.DoYouNeedItDB.fontPackNotice=="fresh","information display alone never acknowledges")
    notice.cross:FireScript("OnClick")
    check(not notice:IsVisible(),"information window closes normally after layering")
    local before=settings.fontDropdown:GetWidth()
    h.env.AntraktFonts={GetCatalog=function()return{formatMajor=1,catalogRevision="marker-ready",fonts=snapshot.fonts}end}
    h:fire("ADDON_LOADED","AntraktFonts")
    check(not marker:IsShown() and settings.fontDropdown:GetWidth()==before,"loaded provider hides marker without moving its reserved font field")
end
for _, flavor in ipairs({ "retail", "forever" }) do
    for _, locale in ipairs({"enUS","deDE","esES","esMX","frFR","itIT","ptBR","ruRU","koKR","zhCN","zhTW"}) do
        local h, pack = client(flavor, {db={settings={font="Interface\\AddOns\\DoYouNeedIt\\fonts\\DejaVuSans.ttf",forceLocale=locale}}})
        local message=pack.Message
        local long=true
        pack.Message=function(active,id)
            if id=="missing" and long then return string.rep(message(active,id).." ",4) end
            return message(active,id)
        end
        h:fire("PLAYER_ENTERING_WORLD")
        local window=h.env.DoYouNeedItFontPackNotice
        local measured=0
        window.body.GetStringHeight=function(self)
            check(self:GetFont()==pack.baselinePath,"notice measures the applied readable baseline")
            measured=measured+1
            return long and 236 or 36
        end
        window:Hide();h:fire("PLAYER_ENTERING_WORLD")
        check(window.body:GetText():find(message(locale,"linkUnavailable"),1,true)
            and window.body:GetText():find(string.format(message(locale,"selectedMissing"),pack.Name(pack.Preferred({font="Interface\\AddOns\\DoYouNeedIt\\fonts\\DejaVuSans.ttf"}))),1,true),
            "long notice includes selected-file and unpublished-link guidance")
        check(measured>0 and window:GetHeight()>=46+236+16+window.close:GetHeight()+16,
            "wrapped localized notice leaves a clear gap above its bottom buttons: "..flavor..locale)
        long=false;window:Hide();h:fire("PLAYER_ENTERING_WORLD")
        check(window:GetHeight()==210,"reused notice shrinks after its body becomes short")
        if locale=="enUS" then
            for _,invalid in ipairs({math.huge,-math.huge,0,0/0,"240",h:secretValue("notice height")}) do
                window.body.GetStringHeight=function()return invalid end
                window:Hide();h:fire("PLAYER_ENTERING_WORLD")
                check(window:GetHeight()==210,"invalid or restricted measurements preserve the last clean notice size")
            end
            window.body.GetStringHeight=function()error("measurement unavailable")end
            window:Hide();h:fire("PLAYER_ENTERING_WORLD")
            check(window:GetHeight()==210,"failed measurement preserves the last clean notice size")
        end
    end
end
print("Shared font runtime: " .. checks .. " checks passed")
