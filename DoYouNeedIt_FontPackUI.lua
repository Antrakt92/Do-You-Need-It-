local _, namespace = ...
local Core = _G.DoYouNeedItCore
local pack = Core.FontPack
local coordinator = namespace.AntraktFontNotice.GetCoordinator()
local function outOfCombat()
    local ok, combat = pcall(InCombatLockdown)
    if not ok or type(combat) ~= "boolean" then return false end
    if type(issecretvalue)=="function" then
        local guarded,secret=pcall(issecretvalue,combat)
        if not guarded or secret~=false then return false end
    end
    return combat == false
end
local function visible(frame)
    if not frame then return false end
    local ok,shown=pcall(frame.IsVisible or frame.IsShown,frame)
    if not ok or type(shown)~="boolean" then return false end
    if type(issecretvalue)=="function" then
        local guarded,secret=pcall(issecretvalue,shown)
        if not guarded or secret~=false then return false end
    end
    return shown==true
end
function pack.InstallUI(addon, existing, apply, refresh)
    if not existing and DoYouNeedItDB.fontPackNotice == nil then DoYouNeedItDB.fontPackNotice = "fresh" end
    local manualRequest = false
    local registeredState, registeredStatus, registered = nil, nil, false
    local executeAction
    local function locale() return Core.ResolveActiveLocale(addon.state.settings.forceLocale, GetLocale()) end
    local function text(id) return pack.Message(locale(), id) end
    local function guidance(owner, activeLocale, notice)
        local id = ({["provider-disabled"]="disabled", ["provider-not-loaded"]="notLoaded",
            ["provider-incompatible"]="incompatible", ready="ready"})[pack.status]
            or (notice and "missing" or "settingsMissing")
        if pack.status=="provider-disabled" and pack.actionResult=="failed" then id="enableFailed" end
        if pack.status=="provider-not-loaded" and pack.enabledForCurrentCharacter and pack.actionResult=="reload-required" then id="reloadRequired" end
        local message = pack.Message(activeLocale, id)
        local preferred = pack.Preferred(owner.state.settings)
        local missing = pack.Coverage(preferred) and not owner.FontAvailable(pack.Resolve(preferred))
        if missing then
            if pack.status == "ready" then message = pack.Message(activeLocale, "assetUnavailable") end
            message = message .. "\n" .. string.format(pack.Message(activeLocale, "selectedMissing"), pack.Name(preferred))
        end
        return message, missing
    end
    local function dismiss()
        if addon.fontPackNotice then
            addon.fontPackNotice:Hide()
            if not addon.fontPackNotice.initialized then addon.fontPackNotice = nil end
        end
        if addon.fontPackCopy then addon.fontPackCopy:Hide() end
    end
    local function copyLink()
        if pack.status == "ready" or pack.status == "provider-disabled" or pack.status == "provider-not-loaded" then return false end
        local links = pack.snapshot.links
        local url = links.curseforge or links.wago or links.github
        if type(url) ~= "string" or not url:match("^https://") then return false end
        local ok = pcall(addon.ShowDeveloperLink, url)
        if not ok then
            local partial = addon.linkFrame or _G.DoYouNeedItDeveloperLink
            if partial and type(partial.Hide) == "function" then pcall(partial.Hide, partial) end
            return false
        end
        if not addon.linkFrame then return false end
        if type(addon.linkFrame.IsVisible) == "function" then return addon.linkFrame:IsVisible() == true end
        return addon.linkFrame:IsShown() == true
    end
    local function updateAction(frame)
        frame.body:SetText(guidance(addon,locale(),true))
        frame.action=pack.status=="provider-disabled" and "enable"
            or pack.status=="provider-not-loaded" and pack.enabledForCurrentCharacter and "reload" or nil
        frame.actionButton:SetShown(frame.action~=nil)
        if frame.action then frame.actionButton:SetText(text(frame.action));frame.actionButton:Enable()
        else frame.actionButton:Disable() end
        local downloadNeeded=pack.status~="ready" and pack.status~="provider-disabled" and pack.status~="provider-not-loaded"
        frame.copy:SetShown(downloadNeeded)
        if not downloadNeeded then frame.copy:Disable()
        elseif not(pack.snapshot.links.curseforge or pack.snapshot.links.wago or pack.snapshot.links.github)then
            frame.body:SetText(frame.body:GetText().."\n\n"..text("linkUnavailable"));frame.copy:Disable()
        else frame.copy:Enable()end
        local ok,height=pcall(function() return frame.body:GetStringHeight() end)
        if not ok then return end
        if type(issecretvalue)=="function" then
            local guarded,secret=pcall(issecretvalue,height)
            if not guarded or secret~=false then return end
        end
        if type(height)~="number" or height~=height or height<=0 or height==math.huge then return end
        -- Body starts 46px below the top; keep 16px clear of the 26px button row.
        frame:SetHeight(math.max(210,math.ceil(height)+46+16+26+16))
    end
    local function show(confirm, suspend)
        if not addon.fontPackNotice then
            local frame = CreateFrame("Frame", "DoYouNeedItFontPackNotice", UIParent, "BackdropTemplate")
            addon.fontPackNotice = frame
            frame:SetSize(430, 210); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
            frame:SetClampedToScreen(true);frame:EnableMouse(true)
            addon.StylePopup(frame)
            frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            frame.title:SetPoint("TOPLEFT", 18, -16); frame.title:SetWidth(394)
            frame.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            frame.body:SetPoint("TOPLEFT", 18, -46); frame.body:SetWidth(394); frame.body:SetJustifyH("LEFT")
            frame.body:SetWordWrap(true)
            frame.close = addon.CreateFlatSettingsButton(frame, 106, true)
            frame.close:SetPoint("BOTTOMRIGHT", -16, 16)
            frame.cross = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
            frame.cross:SetPoint("TOPRIGHT", -3, -3)
            addon.StyleCloseButton(frame.cross)
            frame.copy = addon.CreateFlatSettingsButton(frame, 245, true)
            frame.copy:SetPoint("BOTTOMLEFT", 16, 16)
            frame.actionButton=addon.CreateFlatSettingsButton(frame,245,true)
            frame.actionButton:SetPoint("BOTTOMLEFT",16,16)
            frame.actionButton:SetScript("OnClick",function()executeAction(frame)end)
            frame:SetScript("OnHide", function()
                _G.AntraktWindowLayers.Unregister(frame)
                if frame.suspend then frame.suspend() end
            end)
            frame:EnableKeyboard(true)
            frame:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
                    if self.confirm then self.confirm() end
                    self:Hide()
                elseif self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
            end)
            frame.initialized = true
        end
        local frame = addon.fontPackNotice
        frame.confirm, frame.suspend = confirm, suspend
        frame.title:SetText(text("title"))
        if not addon.ApplyRegionFont(frame.title, pack.baselinePath, 15, "")
            or not addon.ApplyRegionFont(frame.body, pack.baselinePath, 12, "") then return false end
        updateAction(frame)
        frame.close:SetText(text("gotIt")); frame.copy:SetText(text("copyLink"))
        if not addon.ApplyRegionFont(frame.close:GetFontString(), pack.baselinePath, 12, "")
            or not addon.ApplyRegionFont(frame.copy:GetFontString(), pack.baselinePath, 12, "")
            or not addon.ApplyRegionFont(frame.actionButton:GetFontString(),pack.baselinePath,12,"") then return false end
        frame.close:SetScript("OnClick", function() confirm(); frame:Hide() end)
        frame.cross:SetScript("OnClick", function() confirm(); frame:Hide() end)
        frame.copy:SetScript("OnClick", function() if copyLink() then confirm(); frame:Hide() end end)
        _G.AntraktWindowLayers.Register(frame)
        frame:Show()
        _G.AntraktWindowLayers.Focus(frame)
        if type(frame.IsVisible) == "function" then return frame:IsVisible() == true end
        return frame:IsShown() == true
    end
    pack.registerNotice = function()
        local state = DoYouNeedItDB.fontPackNotice
        -- Legacy satisfied meant provider readiness, not an explicit user acknowledgement.
        if state ~= "fresh" and state ~= "acknowledged" then state = nil end
        if registered and registeredState == state and registeredStatus == pack.status then return end
        registered, registeredState, registeredStatus = true, state, pack.status
        coordinator:Register("DoYouNeedIt", {
            state = state,
            canShow = function()
                return addon.fontPackWorldReady == true and outOfCombat()
                    and not (not manualRequest and addon.settingsFrame and addon.settingsFrame:IsShown()
                        and addon.contentMode == "settings")
                    and not (addon.linkFrame and addon.linkFrame:IsShown())
                    and not (addon.fontPackNotice and addon.fontPackNotice:IsShown())
                    and not (type(StaticPopup_Visible) == "function" and StaticPopup_Visible("DOYOUNEED_SELFTEST_COPY"))
            end,
            show = show, dismiss = dismiss,
            acknowledge = function()
                if not outOfCombat() or type(DoYouNeedItDB) ~= "table" then return false end
                DoYouNeedItDB.fontPackNotice = "acknowledged"
                return true
            end,
        })
    end
    executeAction=function(frame)
        if not outOfCombat() or not visible(frame) or not visible(frame.actionButton) then return end
        local result
        if frame.action=="enable" then result=pack.EnableProvider()
        elseif frame.action=="reload" then result=pack.ReloadProvider()
        else return end
        pack.actionResult=result
        addon.availableFontPaths=nil;addon.fontListCache=nil
        apply();refresh()
        -- Keep this visible presentation's callbacks valid across a state change.
        registeredStatus=pack.status
        updateAction(frame)
    end
    pack.registerNotice()
    pack.RefreshMarker = function(owner, activeLocale)
        if not owner.settingsFrame then return end
        if not owner.fontPackMarker then
            local button = owner.CreateFlatSettingsButton(owner.settingsFrame, 24, true)
            button:SetSize(24,24)
            button:SetPoint("LEFT", owner.fontDropdown, "RIGHT", 8, 0)
            button:EnableMouse(true);button:RegisterForClicks("LeftButtonUp")
            button:SetFrameLevel(owner.fontDropdown:GetFrameLevel()+1)
            local label=button:GetFontString()
            label:ClearAllPoints();label:SetPoint("CENTER",button,"CENTER",0,0);label:SetSize(18,20)
            owner.ApplyRegionFont(label,pack.baselinePath,12,"")
            button:SetText("i")
            button:SetScript("OnClick", function()
                if not outOfCombat() or not visible(button) then return end
                manualRequest = true
                local ok,shown,host=pcall(coordinator.RequestInfo, coordinator, "DoYouNeedIt")
                manualRequest = false
                if ok and shown and host=="DoYouNeedIt" and visible(owner.fontPackNotice) then
                    _G.AntraktWindowLayers.Focus(owner.fontPackNotice)
                end
            end)
            button:SetScript("OnEnter", function(self)
                activeLocale = locale()
                local message = guidance(owner, activeLocale, false)
                owner.ShowTextTooltip(self, message)
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            owner.fontPackMarker = button
            owner.settingsFrame:HookScript("OnHide", function()
                if owner.fontPackWorldReady and outOfCombat() then coordinator:RequestShow() end
            end)
        end
        local _, missing = guidance(owner, activeLocale, false)
        owner.fontPackMarker:SetShown(pack.status ~= "ready" or missing == true)
    end
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_DISABLED" then dismiss(); return end
        if event == "ADDON_LOADED" and name ~= "AntraktFonts" then return end
        if event == "ADDON_LOADED" then pack.Invalidate(); addon.availableFontPaths = nil; addon.fontListCache = nil end
        if event == "PLAYER_ENTERING_WORLD" then addon.fontPackWorldReady = true end
        if outOfCombat() then pack.RefreshMetadata(); apply(); refresh(); pack.registerNotice(); coordinator:RequestShow() end
    end)
    if addon.frame and addon.frame.HookScript then
        addon.frame:HookScript("OnHide", function() if addon.fontPackWorldReady and outOfCombat() then coordinator:RequestShow() end end)
    end
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    if media and type(media.RegisterCallback) == "function" then
        media.RegisterCallback(addon, "LibSharedMedia_Registered", function(_, mediaType)
            if mediaType ~= "font" or addon.fontPackRefreshPending then return end
            addon.fontPackRefreshPending = true
            C_Timer.After(0, function()
                addon.fontPackRefreshPending = nil
                pack.Invalidate(); addon.availableFontPaths = nil; addon.fontListCache = nil
                if outOfCombat() then apply(); refresh(); pack.registerNotice() end
            end)
        end)
    end
end
