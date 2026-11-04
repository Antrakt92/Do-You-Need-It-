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
print("Shared font runtime: " .. checks .. " checks passed")
