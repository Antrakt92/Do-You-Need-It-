local Core = {}

Core.VERSION = "0.1.0"

local DEFAULTS = {
    autoWhisper = false,
    autoDelay = 10,
    minDelay = 3,
    maxDelay = 30,
    maxHistoryGroups = 10,
    minQuality = 2,
}

local VALID_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true,
    INVTYPE_SHIELD = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local function asNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then
        return fallback
    end
    return number
end

local function clamp(number, minimum, maximum)
    if number < minimum then
        return minimum
    end
    if number > maximum then
        return maximum
    end
    return number
end

local function copyList(list)
    local copy = {}
    if type(list) ~= "table" then
        return copy
    end
    for index = 1, #list do
        copy[index] = list[index]
    end
    return copy
end

local function baseName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name:match("^([^-]+)") or name
end

local function samePlayerName(left, right)
    local leftBase = baseName(left)
    local rightBase = baseName(right)
    return leftBase ~= nil and rightBase ~= nil and leftBase == rightBase
end

local function isItemLink(link)
    return type(link) == "string" and link:find("|Hitem:", 1, true) ~= nil
end

local function isValidClassID(classID)
    local number = tonumber(classID)
    return number == 2 or number == 4
end

local function isVisibleQuality(quality, minQuality)
    local number = tonumber(quality)
    return number ~= nil and number >= minQuality
end

function Core.NormalizeSettings(saved)
    saved = type(saved) == "table" and saved or {}

    local settings = {}
    settings.autoWhisper = saved.autoWhisper == true
    settings.minDelay = asNumber(saved.minDelay, DEFAULTS.minDelay)
    settings.maxDelay = asNumber(saved.maxDelay, DEFAULTS.maxDelay)
    if settings.minDelay < 0 then
        settings.minDelay = DEFAULTS.minDelay
    end
    if settings.maxDelay < settings.minDelay then
        settings.maxDelay = DEFAULTS.maxDelay
    end
    settings.autoDelay = clamp(asNumber(saved.autoDelay, DEFAULTS.autoDelay), settings.minDelay, settings.maxDelay)
    settings.maxHistoryGroups = math.max(1, math.floor(asNumber(saved.maxHistoryGroups, DEFAULTS.maxHistoryGroups)))
    settings.minQuality = math.max(0, math.floor(asNumber(saved.minQuality, DEFAULTS.minQuality)))
    return settings
end

function Core.ClassifyTradeCandidate(item, looter, playerName, settings)
    settings = Core.NormalizeSettings(settings or {})

    if type(item) ~= "table" then
        return { visible = false, reason = "missing_item" }
    end
    if not isItemLink(item.link) then
        return { visible = false, reason = "not_item_link" }
    end
    if looter == nil or looter == "" then
        return { visible = false, reason = "missing_looter" }
    end
    if samePlayerName(looter, playerName) then
        return { visible = false, reason = "self_loot" }
    end
    if item.canTrade == false then
        return { visible = false, reason = "not_tradeable" }
    end
    if item.isCraftingReagent == true then
        return { visible = false, reason = "crafting_reagent" }
    end
    if not isVisibleQuality(item.quality, settings.minQuality) then
        return { visible = false, reason = "low_quality" }
    end
    if not isValidClassID(item.classID or item.itemClassID) then
        return { visible = false, reason = "not_equipment_class" }
    end
    if VALID_EQUIP_LOCS[item.equipLoc or ""] ~= true then
        return { visible = false, reason = "not_equipment_slot" }
    end

    return {
        visible = true,
        reason = "trade_candidate",
        tradeGuaranteed = item.canTrade == true,
    }
end

function Core.CreateState(settings)
    local normalized = Core.NormalizeSettings(settings or {})
    return {
        settings = normalized,
        currentRows = {},
        sessionRows = {},
        history = {},
        selectedView = "current",
        nextRowID = 1,
    }
end

function Core.AddVisibleRow(state, row)
    if type(state) ~= "table" or type(row) ~= "table" then
        return nil
    end

    local saved = {}
    for key, value in pairs(row) do
        saved[key] = value
    end
    if saved.id == nil then
        saved.id = "row" .. tostring(state.nextRowID or 1)
        state.nextRowID = (state.nextRowID or 1) + 1
    end

    state.currentRows[#state.currentRows + 1] = saved
    state.sessionRows[#state.sessionRows + 1] = saved
    return saved
end

local function groupTitle(meta, dropCount)
    local instanceName = type(meta.instanceName) == "string" and meta.instanceName ~= "" and meta.instanceName or nil
    local encounterName = type(meta.encounterName) == "string" and meta.encounterName ~= "" and meta.encounterName or nil
    local title = type(meta.title) == "string" and meta.title ~= "" and meta.title or nil

    local base
    if instanceName and encounterName then
        base = instanceName .. " - " .. encounterName
    elseif instanceName then
        base = instanceName .. " - Run"
    elseif encounterName then
        base = encounterName
    else
        base = title or "Loot"
    end

    local noun = dropCount == 1 and "drop" or "drops"
    return base .. " (" .. tostring(dropCount) .. " " .. noun .. ")"
end

function Core.CompleteCurrentGroup(state, groupMeta)
    if type(state) ~= "table" or type(state.currentRows) ~= "table" or #state.currentRows == 0 then
        return nil
    end

    groupMeta = type(groupMeta) == "table" and groupMeta or {}
    local group = {
        title = groupTitle(groupMeta, #state.currentRows),
        instanceName = groupMeta.instanceName,
        encounterName = groupMeta.encounterName,
        startedAt = groupMeta.startedAt,
        endedAt = groupMeta.endedAt,
        rows = copyList(state.currentRows),
    }

    table.insert(state.history, 1, group)
    local limit = state.settings and state.settings.maxHistoryGroups or DEFAULTS.maxHistoryGroups
    while #state.history > limit do
        table.remove(state.history)
    end
    state.currentRows = {}
    return group
end

function Core.GetAutoWhisperDecision(settings, row)
    settings = Core.NormalizeSettings(settings or {})
    if settings.autoWhisper ~= true then
        return { shouldSchedule = false, reason = "disabled" }
    end
    if type(row) ~= "table" then
        return { shouldSchedule = false, reason = "missing_row" }
    end
    if row.unsafe == true then
        return { shouldSchedule = false, reason = "unsafe" }
    end
    if row.looter == nil or row.looter == "" or row.itemLink == nil or row.itemLink == "" then
        return { shouldSchedule = false, reason = "incomplete_row" }
    end
    if row.manualWhispered == true or row.autoWhispered == true or row.pendingAutoWhisper == true then
        return { shouldSchedule = false, reason = "already_handled" }
    end
    return {
        shouldSchedule = true,
        reason = "eligible",
        delay = settings.autoDelay,
    }
end

_G.DoYouNeedItCore = Core
