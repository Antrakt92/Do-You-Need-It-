local _, namespace = ...
local Core = _G.DoYouNeedItCore
local pack = Core.FontPack
local coordinator = namespace.AntraktFontNotice.GetCoordinator()
local function outOfCombat()
    local ok, combat = pcall(InCombatLockdown)
    if not ok or type(combat) ~= "boolean" then return false end
    if type(issecretvalue) == "function" and issecretvalue(combat) then return false end
    return combat == false
end
function pack.InstallUI(addon, existing, apply, refresh)
    if not existing and DoYouNeedItDB.fontPackNotice == nil then DoYouNeedItDB.fontPackNotice = "fresh" end
    local manualRequest = false
    local function locale() return Core.ResolveActiveLocale(addon.state.settings.forceLocale, GetLocale()) end
    local function text(id) return pack.Message(locale(), id) end
    local function dismiss()
        if addon.fontPackNotice then
            addon.fontPackNotice:Hide()
            if not addon.fontPackNotice.initialized then addon.fontPackNotice = nil end
        end
        if addon.fontPackCopy then addon.fontPackCopy:Hide() end
    end
    local function copyLink()
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
    local function show(confirm, suspend)
        if not addon.fontPackNotice then
            local frame = CreateFrame("Frame", "DoYouNeedItFontPackNotice", UIParent, "BackdropTemplate")
            addon.fontPackNotice = frame
            frame:SetSize(430, 210); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
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
            frame:SetScript("OnHide", function() if frame.suspend then frame.suspend() end end)
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
        frame.body:SetText(text(pack.status == "ready" and "ready"
            or pack.status == "provider-incompatible" and "incompatible" or "missing"))
        if not addon.ApplyRegionFont(frame.title, pack.baselinePath, 15, "")
            or not addon.ApplyRegionFont(frame.body, pack.baselinePath, 12, "") then return false end
        frame.close:SetText(text("gotIt")); frame.copy:SetText(text("copyLink"))
        if not addon.ApplyRegionFont(frame.close:GetFontString(), pack.baselinePath, 12, "")
            or not addon.ApplyRegionFont(frame.copy:GetFontString(), pack.baselinePath, 12, "") then return false end
        frame.close:SetScript("OnClick", function() confirm(); frame:Hide() end)
        frame.cross:SetScript("OnClick", function() confirm(); frame:Hide() end)
        frame.copy:SetScript("OnClick", function() if copyLink() then confirm(); frame:Hide() end end)
        if not (pack.snapshot.links.curseforge or pack.snapshot.links.wago or pack.snapshot.links.github) then
            frame.body:SetText(frame.body:GetText() .. "\n\n" .. text("linkUnavailable")); frame.copy:Disable()
        else frame.copy:Enable() end
        frame:Show()
        if type(frame.IsVisible) == "function" then return frame:IsVisible() == true end
        return frame:IsShown() == true
    end
    local registeredState, registeredStatus, registered = nil, nil, false
    pack.registerNotice = function()
        local state = DoYouNeedItDB.fontPackNotice
        if state ~= "fresh" and state ~= "acknowledged" and state ~= "satisfied" then state = nil end
        if state == nil and pack.status == "ready" and addon.fontPackWorldReady and outOfCombat() then
            DoYouNeedItDB.fontPackNotice = "satisfied"
            state = "satisfied"
        end
        -- Readiness resolves this owner's campaign; it is not a shared user acknowledgement.
        if state == "satisfied" or (state == nil and pack.status == "ready") then state = "fresh" end
        if registered and registeredState == state and registeredStatus == pack.status then return end
        registered, registeredState, registeredStatus = true, state, pack.status
        coordinator:Register("DoYouNeedIt", {
            state = state,
            canShow = function()
                return addon.fontPackWorldReady == true and outOfCombat()
                    and (manualRequest or pack.status ~= "ready")
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
    pack.registerNotice()
    pack.RefreshMarker = function(owner, activeLocale)
        if not owner.settingsFrame then return end
        if not owner.fontPackMarker then
            local button = owner.CreateFlatSettingsButton(owner.settingsFrame, 24, true)
            button:SetPoint("LEFT", owner.fontDropdown, "RIGHT", 4, 0)
            button:SetText("i")
            button:SetScript("OnClick", function()
                manualRequest = true
                pcall(coordinator.RequestInfo, coordinator, "DoYouNeedIt")
                manualRequest = false
            end)
            button:SetScript("OnEnter", function(self)
                activeLocale = locale()
                local preferred = pack.Preferred(owner.state.settings)
                local message = pack.Message(activeLocale, "settingsMissing")
                if pack.status == "provider-unavailable" then message = message .. "\n" .. pack.Message(activeLocale, "disabled") end
                if pack.Identity(owner.ValidatedDisplayFont()) ~= pack.Identity(preferred) then
                    message = string.format(pack.Message(activeLocale, "selectedMissing"), pack.Name(preferred))
                    if pack.status == "ready" and Core.FontSupportsLocale(preferred, activeLocale) then
                        message = message .. "\n" .. pack.Message(activeLocale, "assetUnavailable")
                    end
                end
                if pack.status == "provider-incompatible" then message = pack.Message(activeLocale, "incompatible") end
                owner.ShowTextTooltip(self, message)
            end)
            button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            owner.fontPackMarker = button
            owner.settingsFrame:HookScript("OnHide", function()
                if owner.fontPackWorldReady and outOfCombat() then coordinator:RequestShow() end
            end)
        end
        owner.fontPackMarker:SetShown(pack.status ~= "ready"
            or pack.Identity(owner.ValidatedDisplayFont()) ~= pack.Identity(pack.Preferred(owner.state.settings)))
    end
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_REGEN_DISABLED" then dismiss(); return end
        if event == "ADDON_LOADED" and name ~= "AntraktFonts" then return end
        if event == "ADDON_LOADED" then pack.Invalidate(); addon.availableFontPaths = nil; addon.fontListCache = nil end
        if event == "PLAYER_ENTERING_WORLD" then addon.fontPackWorldReady = true end
        if outOfCombat() then apply(); refresh(); pack.registerNotice(); coordinator:RequestShow() end
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
