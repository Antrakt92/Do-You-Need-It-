local Harness = {}

local slotIDs = {
    HeadSlot = 1,
    NeckSlot = 2,
    ShoulderSlot = 3,
    ShirtSlot = 4,
    ChestSlot = 5,
    WaistSlot = 6,
    LegsSlot = 7,
    FeetSlot = 8,
    WristSlot = 9,
    HandsSlot = 10,
    Finger0Slot = 11,
    Finger1Slot = 12,
    Trinket0Slot = 13,
    Trinket1Slot = 14,
    BackSlot = 15,
    MainHandSlot = 16,
    SecondaryHandSlot = 17,
}

local slotNamesByID = {}
for name, id in pairs(slotIDs) do
    slotNamesByID[id] = name
end

local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:GetName()
    return self.name
end

function FrameMethods:GetParent()
    return self.parent
end

function FrameMethods:SetSize(width, height)
    self.width = width
    self.height = height
end

function FrameMethods:GetSize()
    return self.width, self.height
end

function FrameMethods:SetWidth(width)
    self.width = width
end

function FrameMethods:GetWidth()
    return self.width
end

function FrameMethods:SetHeight(height)
    self.height = height
end

function FrameMethods:GetHeight()
    return self.height
end

function FrameMethods:SetPoint(...)
    self.points = self.points or {}
    self.points[#self.points + 1] = { ... }
end

function FrameMethods:ClearAllPoints()
    self.points = {}
end

function FrameMethods:SetAllPoints(parent)
    self.allPoints = parent or true
end

function FrameMethods:SetFrameStrata(strata)
    self.strata = strata
end

function FrameMethods:SetFrameLevel(level)
    self.frameLevel = level
end

function FrameMethods:GetFrameLevel()
    return self.frameLevel or 0
end

function FrameMethods:SetClampedToScreen(clamped)
    self.clampedToScreen = clamped == true
end

function FrameMethods:EnableMouse(enabled)
    self.mouseEnabled = enabled
end

function FrameMethods:SetMovable(movable)
    self.movable = movable
end

function FrameMethods:RegisterForDrag(...)
    self.dragButtons = { ... }
end

function FrameMethods:RegisterForClicks(...)
    self.clickButtons = { ... }
end

function FrameMethods:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
    self.harness.eventFrames[self] = true
end

function FrameMethods:SetScript(scriptName, handler)
    self.scripts[scriptName] = handler
end

function FrameMethods:GetScript(scriptName)
    return self.scripts[scriptName]
end

function FrameMethods:HookScript(scriptName, handler)
    self.hooks[scriptName] = self.hooks[scriptName] or {}
    self.hooks[scriptName][#self.hooks[scriptName] + 1] = handler
end

function FrameMethods:FireScript(scriptName, ...)
    local handler = self.scripts[scriptName]
    if type(handler) == "function" then
        handler(self, ...)
    end
    local hooks = self.hooks[scriptName]
    if type(hooks) == "table" then
        for index = 1, #hooks do
            hooks[index](self, ...)
        end
    end
end

function FrameMethods:Show()
    self.shown = true
    self:FireScript("OnShow")
end

function FrameMethods:Hide()
    self.shown = false
    self:FireScript("OnHide")
    if self.name == "DropDownList1" and self.harness.options.blankSettingsDropdownCaptionsAfterListHide then
        local env = self.harness.env
        if env.DoYouNeedItLanguageDropdown and env.DoYouNeedItLanguageDropdown.Text then
            env.DoYouNeedItLanguageDropdown.Text:SetText("")
        end
        if env.DoYouNeedItFontDropdown and env.DoYouNeedItFontDropdown.Text then
            env.DoYouNeedItFontDropdown.Text:SetText("")
        end
    end
end

function FrameMethods:IsShown()
    return self.shown == true
end

function FrameMethods:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end

function FrameMethods:SetText(text)
    self.text = text == nil and "" or tostring(text)
end

function FrameMethods:GetText()
    return self.text
end

function FrameMethods:SetFont(path, size, flags)
    self.font = path
    self.fontSize = size
    self.fontFlags = flags
end

function FrameMethods:GetFont()
    return self.font, self.fontSize, self.fontFlags
end

function FrameMethods:SetTextColor(...)
    self.textColor = { ... }
end

function FrameMethods:SetJustifyH(justify)
    self.justifyH = justify
end

function FrameMethods:SetBackdrop(backdrop)
    self.backdrop = backdrop
end

function FrameMethods:SetBackdropColor(...)
    self.backdropColor = { ... }
end

function FrameMethods:SetNormalTexture(texture)
    self.normalTexture = texture
end

function FrameMethods:SetPushedTexture(texture)
    self.pushedTexture = texture
end

function FrameMethods:SetHighlightTexture(texture, blendMode)
    self.highlightTexture = texture
    self.highlightBlendMode = blendMode
    if not self.highlightTextureFrame then
        self.highlightTextureFrame = self.harness:newFrame("Texture", nil, self)
    end
    self.highlightTextureFrame.texture = texture
end

function FrameMethods:GetHighlightTexture()
    return self.highlightTextureFrame
end

function FrameMethods:SetColorTexture(...)
    self.colorTexture = { ... }
end

function FrameMethods:SetBlendMode(blendMode)
    self.blendMode = blendMode
end

function FrameMethods:SetVertexColor(...)
    self.vertexColor = { ... }
end

function FrameMethods:SetAlpha(alpha)
    self.alpha = alpha
end

function FrameMethods:Enable()
    self.enabled = true
end

function FrameMethods:Disable()
    self.enabled = false
end

function FrameMethods:SetEnabled(enabled)
    self.enabled = enabled == true
end

function FrameMethods:IsEnabled()
    return self.enabled ~= false
end

function FrameMethods:SetChecked(checked)
    self.checked = checked == true
end

function FrameMethods:GetChecked()
    return self.checked == true
end

function FrameMethods:SetMinMaxValues(minValue, maxValue)
    self.minValue = minValue
    self.maxValue = maxValue
end

function FrameMethods:GetMinMaxValues()
    return self.minValue, self.maxValue
end

function FrameMethods:SetValueStep(step)
    self.valueStep = step
end

function FrameMethods:SetObeyStepOnDrag(obey)
    self.obeyStepOnDrag = obey
end

function FrameMethods:SetValue(value)
    self.value = value
    self:FireScript("OnValueChanged", value)
end

function FrameMethods:GetValue()
    return self.value
end

function FrameMethods:SetScrollChild(child)
    self.scrollChild = child
end

function FrameMethods:SetVerticalScroll(value)
    self.verticalScroll = value
end

function FrameMethods:GetVerticalScroll()
    return self.verticalScroll or 0
end

function FrameMethods:GetFontString()
    if not self.fontString then
        self.fontString = self.harness:newFrame("FontString", nil, self)
    end
    return self.fontString
end

function FrameMethods:CreateFontString(name)
    return self.harness:newFrame("FontString", name, self)
end

function FrameMethods:CreateTexture(name)
    return self.harness:newFrame("Texture", name, self)
end

function FrameMethods:SetWordWrap(enabled)
    self.wordWrap = enabled == true
end

function FrameMethods:SetMaxLines(lines)
    self.maxLines = lines
end

function FrameMethods:SetNonSpaceWrap(enabled)
    self.nonSpaceWrap = enabled == true
end

function FrameMethods:SetOwner(owner, anchor)
    self.owner = owner
    self.anchor = anchor
end

function FrameMethods:SetHyperlink(link)
    self.hyperlink = link
end

function FrameMethods:AddMessage(message)
    self.harness.messages[#self.harness.messages + 1] = tostring(message)
end

function FrameMethods:StartMoving()
    self.moving = true
end

function FrameMethods:StopMovingOrSizing()
    self.moving = false
end

function Harness:newFrame(frameType, name, parent, template)
    local frame = setmetatable({
        harness = self,
        frameType = frameType,
        name = name,
        parent = parent,
        template = template,
        children = {},
        scripts = {},
        hooks = {},
        shown = false,
        enabled = true,
        text = "",
    }, FrameMethods)

    if parent and parent.children then
        parent.children[#parent.children + 1] = frame
    end
    self.frames[#self.frames + 1] = frame
    if name then
        self.env[name] = frame
    end

    if template == "UIDropDownMenuTemplate" and name then
        frame.Text = self:newFrame("FontString", name .. "Text", frame)
        frame.Button = self:newFrame("Button", name .. "Button", frame)
        frame.Left = self:newFrame("Texture", name .. "Left", frame)
        frame.Middle = self:newFrame("Texture", name .. "Middle", frame)
        frame.Right = self:newFrame("Texture", name .. "Right", frame)
    end

    if template == "OptionsSliderTemplate" then
        frame.Text = self:newFrame("FontString", name and name .. "Text" or nil, frame)
        frame.Text:SetText("0")
        frame.Low = self:newFrame("FontString", name and name .. "Low" or nil, frame)
        frame.Low:SetText("Low")
        frame.High = self:newFrame("FontString", name and name .. "High" or nil, frame)
        frame.High:SetText("High")
    end

    return frame
end

local function linkItemID(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    return tonumber(itemLink:match("item:(%d+)"))
end

local function defaultItemName(itemID)
    return "Test Item " .. tostring(itemID or 0)
end

function Harness:itemInfo(itemLink)
    local itemID = linkItemID(itemLink)
    local info = self.items[itemID] or {}
    local name = info.name or defaultItemName(itemID)
    local link = info.link or itemLink
    return itemID,
        nil,
        nil,
        info.equipLoc or "INVTYPE_WEAPON",
        nil,
        info.classID or 2,
        info.subclassID or 7,
        name,
        link,
        info.quality or 4,
        info.itemLevel or 500,
        0,
        nil,
        nil,
        1,
        info.equipLoc or "INVTYPE_WEAPON",
        nil,
        0,
        info.classID or 2,
        info.subclassID or 7,
        info.bindType or 2,
        nil,
        nil,
        info.isCraftingReagent == true
end

function Harness:addItem(itemID, fields)
    fields = fields or {}
    self.items[itemID] = fields
    return fields.link or string.format("|cffa335ee|Hitem:%d:::::::::::::|h[%s]|h|r", itemID, fields.name or defaultItemName(itemID))
end

function Harness:setInventoryLink(unit, slotName, link)
    self.inventoryLinks[unit] = self.inventoryLinks[unit] or {}
    self.inventoryLinks[unit][slotName] = link
end

function Harness:setUnit(unit, fields)
    fields = fields or {}
    local current = self.units[unit] or {}
    local updated = {}
    for key, value in pairs(current) do
        updated[key] = value
    end
    for key, value in pairs(fields) do
        updated[key] = value
    end
    self.units[unit] = updated
end

function Harness:removeUnit(unit)
    self.units[unit] = nil
    self.inventoryLinks[unit] = nil
    self.canInspect[unit] = nil
end

function Harness:resetSideEffects()
    self.messages = {}
    self.sentMessages = {}
    self.notifyInspectCalls = {}
    self.clearInspectCalls = 0
    self.inventoryReadCalls = {}
end

function Harness:fireLoot(looterName, itemLink)
    self:fire("CHAT_MSG_LOOT", looterName .. " receives loot: " .. itemLink .. ".")
end

function Harness:findFrame(predicate, root)
    root = root or self.env.UIParent
    if predicate(root) then
        return root
    end
    for index = 1, #(root.children or {}) do
        local found = self:findFrame(predicate, root.children[index])
        if found then
            return found
        end
    end
    return nil
end

function Harness:visibleRows()
    local rows = {}
    local function visit(frame)
        if frame.row and frame:IsShown() then
            rows[#rows + 1] = frame
        end
        for index = 1, #(frame.children or {}) do
            visit(frame.children[index])
        end
    end
    visit(self.env.UIParent)
    return rows
end

function Harness:slash(message)
    local handler = self.env.SlashCmdList and self.env.SlashCmdList.DOYOUNEEDIT
    assert(type(handler) == "function", "slash command is not registered")
    handler(message or "")
end

function Harness:fire(event, ...)
    for frame in pairs(self.eventFrames) do
        if frame.events and frame.events[event] then
            local handler = frame:GetScript("OnEvent")
            if type(handler) == "function" then
                handler(frame, event, ...)
            end
        end
    end
end

function Harness:runTimers(maxDelay, maxCount)
    maxCount = maxCount or 100
    local ran = 0
    while ran < maxCount do
        if not self:runNextTimer(maxDelay) then
            break
        end
        ran = ran + 1
    end
    return ran
end

function Harness:runNextTimer(maxDelay)
    local foundIndex
    for index = 1, #self.timers do
        local timer = self.timers[index]
        if maxDelay == nil or timer.delay <= maxDelay then
            foundIndex = index
            break
        end
    end
    if not foundIndex then
        return false
    end
    local timer = table.remove(self.timers, foundIndex)
    timer.callback()
    return true
end

function Harness:registered(event)
    for frame in pairs(self.eventFrames) do
        if frame.events and frame.events[event] then
            return true
        end
    end
    return false
end

function Harness:loadAddon()
    local coreChunk = assert(loadfile("DoYouNeedIt_Core.lua"))
    setfenv(coreChunk, self.env)
    coreChunk()

    local runtimeChunk = assert(loadfile("DoYouNeedIt.lua"))
    setfenv(runtimeChunk, self.env)
    runtimeChunk("DoYouNeedIt")

    self:fire("ADDON_LOADED", "DoYouNeedIt")
end

function Harness.new(options)
    local self = setmetatable({
        options = options or {},
        env = {},
        frames = {},
        eventFrames = {},
        timers = {},
        messages = {},
        sentMessages = {},
        notifyInspectCalls = {},
        clearInspectCalls = 0,
        inventoryReadCalls = {},
        dropdownAdds = {},
        menuButtons = {},
        items = {},
        inventoryLinks = {},
        canInspect = {},
        instanceName = "Ruby Life Pools",
        now = 1000,
    }, { __index = Harness })

    local env = self.env
    setmetatable(env, { __index = _G })
    env._G = env
    env.DoYouNeedItDB = options and options.db or {}
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.BIND_TRADE_TIME_REMAINING = "You may trade this item with eligible players for %s"
    env.LOOT_ITEM_SELF = "You receive loot: %s."
    env.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
    env.LOOT_ITEM = "%s receives loot: %s."
    env.LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
    env.ITEM_CLASS_WEAPON = 2
    env.ITEM_CLASS_ARMOR = 4
    env.LE_ITEM_CLASS_WEAPON = 2
    env.LE_ITEM_CLASS_ARMOR = 4
    env.Enum = { ItemClass = { Weapon = 2, Armor = 4 } }

    env.UIParent = self:newFrame("Frame", "UIParent", nil)
    env.DEFAULT_CHAT_FRAME = self:newFrame("Frame", "DefaultChatFrame", env.UIParent)
    env.GameTooltip = self:newFrame("GameTooltip", "GameTooltip", env.UIParent)
    env.DropDownList1 = self:newFrame("Frame", "DropDownList1", env.UIParent)
    for index = 1, 64 do
        self:newFrame("Button", "DropDownList1Button" .. index, env.DropDownList1)
    end

    local configuredFonts = self.options.lsmFonts or {
        { name = "Friz Quadrata TT", path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    }
    local lsm = {
        List = function(_, kind)
            if kind == "font" then
                local names = {}
                for index = 1, #configuredFonts do
                    names[#names + 1] = configuredFonts[index].name
                end
                return names
            end
            return {}
        end,
        Fetch = function(_, kind, name)
            if kind ~= "font" then
                return nil
            end
            for index = 1, #configuredFonts do
                if configuredFonts[index].name == name then
                    return configuredFonts[index].path
                end
            end
            return nil
        end,
    }
    env.LibStub = function(name, silent)
        if name == "LibSharedMedia-3.0" then
            return lsm
        end
        if silent then
            return nil
        end
        error("missing library " .. tostring(name))
    end

    env.CreateFrame = function(frameType, name, parent, template)
        return self:newFrame(frameType, name, parent, template)
    end
    env.UIDropDownMenu_SetWidth = function(dropdown, width)
        dropdown.width = width
    end
    env.UIDropDownMenu_JustifyText = function(dropdown, justify)
        dropdown.justify = justify
    end
    env.UIDropDownMenu_Initialize = function(dropdown, callback)
        dropdown.initialize = callback
    end
    env.UIDropDownMenu_CreateInfo = function()
        return {}
    end
    env.UIDropDownMenu_AddButton = function(info)
        self.dropdownAdds[#self.dropdownAdds + 1] = info
        local button = env["DropDownList1Button" .. tostring(#self.dropdownAdds)]
        if button then
            button.value = info.value
            button:SetText(info.text)
            button.func = info.func
        end
    end
    env.UIDropDownMenu_SetText = function(dropdown, text)
        dropdown:SetText(text)
        if dropdown.Text then
            dropdown.Text:SetText(text)
        end
    end
    env.CloseDropDownMenus = function()
        env.UIDROPDOWNMENU_OPEN_MENU = nil
        env.DropDownList1:Hide()
    end
    env.MenuUtil = {
        CreateContextMenu = function(owner, builder)
            local root = {
                CreateButton = function(_, text, callback)
                    local button = {
                        owner = owner,
                        text = text,
                        callback = callback,
                    }
                    self.menuButtons[#self.menuButtons + 1] = button
                    return button
                end,
            }
            builder(owner, root)
        end,
    }

    env.C_Timer = {
        After = function(delay, callback)
            self.timers[#self.timers + 1] = {
                delay = tonumber(delay) or 0,
                callback = callback,
            }
        end,
    }
    env.GetServerTime = function()
        return self.now
    end
    env.time = function()
        return self.now
    end
    env.GetLocale = function()
        return "enUS"
    end
    env.GetInstanceInfo = function()
        return self.instanceName
    end
    env.InCombatLockdown = function()
        return false
    end
    env.issecretvalue = function()
        return false
    end

    self.units = {
        player = { name = "Player", realm = "Ravencrest", guid = "PlayerGUID", classToken = "WARRIOR" },
        party1 = { name = "Otherplayer", realm = "Ravencrest", guid = "PartyGUID1", classToken = "PALADIN" },
        party2 = { name = "Secondplayer", realm = "Ravencrest", guid = "PartyGUID2", classToken = "MAGE" },
        party3 = { name = "Thirdplayer", realm = "Ravencrest", guid = "PartyGUID3", classToken = "ROGUE" },
        party4 = { name = "Fourthplayer", realm = "Ravencrest", guid = "PartyGUID4", classToken = "DRUID" },
    }
    env.UnitName = function(unit)
        local entry = self.units[unit]
        if entry then
            return entry.name, entry.realm
        end
        return nil
    end
    env.UnitGUID = function(unit)
        return self.units[unit] and self.units[unit].guid or nil
    end
    env.UnitClassBase = function(unit)
        return self.units[unit] and self.units[unit].classToken or nil
    end
    env.UnitClass = function(unit)
        local token = self.units[unit] and self.units[unit].classToken or nil
        return token, token, 1
    end
    env.CanInspect = function(unit)
        if self.canInspect[unit] ~= nil then
            return self.canInspect[unit]
        end
        return unit ~= "player" and self.units[unit] ~= nil
    end

    env.GetInventorySlotInfo = function(slotName)
        local slotID = slotIDs[slotName]
        if not slotID then
            error("Invalid inventory slot in GetInventorySlotInfo")
        end
        return slotID
    end
    env.GetInventoryItemLink = function(unit, slotID)
        local slotName = slotNamesByID[slotID] or slotID
        self.inventoryReadCalls[#self.inventoryReadCalls + 1] = {
            unit = unit,
            slotName = slotName,
        }
        local links = self.inventoryLinks[unit]
        return links and links[slotName] or nil
    end

    env.C_Item = {
        GetItemInfoInstant = function(itemLink)
            local itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID = self:itemInfo(itemLink)
            return itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID
        end,
        GetItemInfo = function(itemLink)
            local itemID = linkItemID(itemLink)
            local info = self.items[itemID] or {}
            if info.cacheLoaded == false then
                return nil
            end
            local _, _, _, _, _, _, _, name, link, quality, itemLevel, requiredLevel, itemTypeText,
                itemSubTypeText, stackCount, equipLoc, itemIcon, sellPrice, classID, subclassID, bindType,
                expansionID, setID, isCraftingReagent = self:itemInfo(itemLink)
            return name, link, quality, itemLevel, requiredLevel, itemTypeText, itemSubTypeText, stackCount,
                equipLoc, itemIcon, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent
        end,
        IsEquippableItem = function(itemLink)
            local itemID = linkItemID(itemLink)
            local info = self.items[itemID] or {}
            return info.equippable ~= false
        end,
        IsUsableItem = function(itemLink)
            local itemID = linkItemID(itemLink)
            local info = self.items[itemID] or {}
            return info.usable ~= false
        end,
        CreateFromItemID = function(itemID)
            return {
                ContinueOnItemLoad = function(_, callback)
                    env.C_Timer.After(0, function()
                        if self.items[itemID] then
                            self.items[itemID].cacheLoaded = true
                        end
                        callback()
                    end)
                end,
            }
        end,
    }
    env.C_TooltipInfo = {
        GetHyperlink = function(itemLink)
            local itemID = linkItemID(itemLink)
            local info = self.items[itemID] or {}
            return { lines = info.tooltipLines or {} }
        end,
    }
    env.TooltipUtil = {
        SurfaceArgs = function()
        end,
    }
    env.C_ChatInfo = {
        SendChatMessage = function(message, chatType, language, target)
            self.sentMessages[#self.sentMessages + 1] = {
                message = message,
                chatType = chatType,
                language = language,
                target = target,
            }
            if self.failWhisper then
                error("send failed")
            end
            return true
        end,
    }
    env.SendChatMessage = env.C_ChatInfo.SendChatMessage
    env.NotifyInspect = function(unit)
        self.notifyInspectCalls[#self.notifyInspectCalls + 1] = unit
    end
    env.ClearInspectPlayer = function()
        self.clearInspectCalls = self.clearInspectCalls + 1
    end
    env.HandleModifiedItemClick = function()
        return false
    end

    return self
end

return Harness
