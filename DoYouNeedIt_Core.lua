local Core = {}

Core.VERSION = "0.1.7"

local DEFAULTS = {
    autoWhisper = false,
    debug = false,
    autoDelay = 10,
    minDelay = 3,
    maxDelay = 30,
    maxHistoryGroups = 10,
    maxSessionRows = 50,
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

local PERSISTED_ROW_KEYS = {
    id = true,
    looter = true,
    itemLink = true,
    equipLoc = true,
    itemID = true,
    instanceName = true,
    encounterName = true,
    timestamp = true,
    reason = true,
    statusText = true,
    equippedText = true,
    unsafe = true,
    manualWhispered = true,
    autoWhispered = true,
}

local PERSISTED_GROUP_KEYS = {
    title = true,
    instanceName = true,
    encounterName = true,
    startedAt = true,
    endedAt = true,
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

local function pruneListStart(list, limit)
    limit = math.max(1, math.floor(asNumber(limit, 1)))
    while #list > limit do
        table.remove(list, 1)
    end
end

local function copyPrimitiveFields(source, allowedKeys)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for key in pairs(allowedKeys) do
        local value = source[key]
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            copy[key] = value
        end
    end
    return copy
end

local function snapshotRowForSave(row)
    local saved = copyPrimitiveFields(row, PERSISTED_ROW_KEYS)
    if saved.statusText and saved.statusText:find("auto in", 1, true) == 1 then
        saved.statusText = "candidate"
    end
    return saved
end

local function snapshotRowsForSave(rows, limit)
    local saved = {}
    if type(rows) == "table" then
        for index = 1, #rows do
            if type(rows[index]) == "table" then
                saved[#saved + 1] = snapshotRowForSave(rows[index])
            end
        end
    end
    if limit ~= nil then
        pruneListStart(saved, limit)
    end
    return saved
end

local function baseName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name:match("^([^-]+)") or name
end

local function realmName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name:match("^[^-]+%-(.+)$")
end

local function samePlayerName(left, right)
    local leftBase = baseName(left)
    local rightBase = baseName(right)
    local leftRealm = realmName(left)
    local rightRealm = realmName(right)
    if leftRealm and rightRealm then
        return left == right
    end
    return leftBase ~= nil and rightBase ~= nil and leftBase == rightBase
end

local function stripChatMarkup(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|Hplayer:([^:|]+)[^|]*|h%[([^%]]+)%]|h", "%1 %2")
    text = text:gsub("|H.-|h%[(.-)%]|h", "%1")
    text = text:gsub("|A.-|a", "")
    return text
end

local function sortedRosterNames(roster)
    local names = {}
    if type(roster) ~= "table" then
        return names
    end
    for name in pairs(roster) do
        if type(name) == "string" and name ~= "" then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(left, right)
        if #left == #right then
            return left < right
        end
        return #left > #right
    end)
    return names
end

local function canonicalRosterName(candidate, roster)
    if type(candidate) ~= "string" or candidate == "" or type(roster) ~= "table" then
        return nil
    end
    if roster[candidate] ~= nil then
        return candidate
    end
    local names = sortedRosterNames(roster)
    for index = 1, #names do
        local name = names[index]
        if samePlayerName(name, candidate) then
            return name
        end
    end
    return nil
end

local function appendCandidate(list, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
        return
    end
    list[#list + 1] = value
    seen[value] = true
end

local function escapePatternChar(char)
    if char:find("[%(%).%%%+%-%*%?%[%]%^%$]", 1, false) then
        return "%" .. char
    end
    return char
end

local function lootFormatToPattern(formatText, captureFirstString)
    if type(formatText) ~= "string" or formatText == "" then
        return nil
    end

    local out = { "^" }
    local index = 1
    local capturedFirstString = false
    while index <= #formatText do
        local char = formatText:sub(index, index)
        local nextChar = formatText:sub(index + 1, index + 1)
        local position, positionalSpec = formatText:match("^%%(%d+)%$(%a)", index)
        if position and positionalSpec == "s" then
            if captureFirstString and tonumber(position) == 1 then
                out[#out + 1] = "(.+)"
            else
                out[#out + 1] = ".+"
            end
            index = index + #position + 3
        elseif position and positionalSpec == "d" then
            out[#out + 1] = "%d+"
            index = index + #position + 3
        elseif char == "%" and nextChar == "s" then
            if captureFirstString and not capturedFirstString then
                out[#out + 1] = "(.+)"
                capturedFirstString = true
            else
                out[#out + 1] = ".+"
            end
            index = index + 2
        elseif char == "%" and nextChar == "d" then
            out[#out + 1] = "%d+"
            index = index + 2
        else
            out[#out + 1] = escapePatternChar(char)
            index = index + 1
        end
    end
    return table.concat(out)
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
    settings.debug = saved.debug == true
    local minDelay = asNumber(saved.minDelay, DEFAULTS.minDelay)
    local maxDelay = asNumber(saved.maxDelay, DEFAULTS.maxDelay)
    if minDelay < 0 or minDelay > DEFAULTS.maxDelay or maxDelay < minDelay or maxDelay > DEFAULTS.maxDelay then
        minDelay = DEFAULTS.minDelay
        maxDelay = DEFAULTS.maxDelay
    end
    settings.minDelay = minDelay
    settings.maxDelay = maxDelay
    settings.autoDelay = clamp(asNumber(saved.autoDelay, DEFAULTS.autoDelay), settings.minDelay, settings.maxDelay)
    settings.maxHistoryGroups = math.max(1, math.floor(asNumber(saved.maxHistoryGroups, DEFAULTS.maxHistoryGroups)))
    settings.maxSessionRows = math.max(1, math.floor(asNumber(saved.maxSessionRows, DEFAULTS.maxSessionRows)))
    settings.minQuality = math.max(0, math.floor(asNumber(saved.minQuality, DEFAULTS.minQuality)))
    return settings
end

function Core.NormalizeSavedRows(rows, limit)
    return snapshotRowsForSave(rows, limit or DEFAULTS.maxSessionRows)
end

function Core.SnapshotRowsForSave(rows, limit)
    return snapshotRowsForSave(rows, limit or DEFAULTS.maxSessionRows)
end

function Core.SnapshotHistoryForSave(history, limit)
    local saved = {}
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" then
                local savedGroup = copyPrimitiveFields(group, PERSISTED_GROUP_KEYS)
                savedGroup.rows = snapshotRowsForSave(group.rows)
                saved[#saved + 1] = savedGroup
            end
        end
    end
    pruneListStart(saved, limit or DEFAULTS.maxHistoryGroups)
    return saved
end

function Core.GetNewestRowsFirst(rows, limit)
    local result = {}
    if type(rows) ~= "table" then
        return result
    end
    limit = math.max(1, math.floor(asNumber(limit, #rows)))
    for index = #rows, 1, -1 do
        local row = rows[index]
        if type(row) == "table" then
            result[#result + 1] = row
            if #result >= limit then
                break
            end
        end
    end
    return result
end

function Core.FindRosterNameInMessage(message, roster, playerName)
    if type(message) ~= "string" or type(roster) ~= "table" then
        return nil
    end

    local candidates = {}
    local seen = {}
    for target, label in message:gmatch("|Hplayer:([^:|]+)[^|]*|h%[([^%]]+)%]|h") do
        appendCandidate(candidates, seen, target)
        appendCandidate(candidates, seen, label)
    end

    local plainMessage = stripChatMarkup(message)
    if plainMessage then
        local names = sortedRosterNames(roster)
        for index = 1, #names do
            local name = names[index]
            if plainMessage:find(name, 1, true) then
                appendCandidate(candidates, seen, name)
            end
        end
    end

    for index = 1, #candidates do
        local name = canonicalRosterName(candidates[index], roster)
        if name and not samePlayerName(name, playerName) then
            return name
        end
    end
    return nil
end

function Core.RecordDiagnostic(log, entry, limit)
    if type(log) ~= "table" then
        return nil
    end
    limit = math.max(1, math.floor(asNumber(limit, 20)))
    entry = type(entry) == "table" and entry or {}

    local saved = {}
    for key, value in pairs(entry) do
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            saved[key] = value
        end
    end

    table.insert(log, 1, saved)
    while #log > limit do
        table.remove(log)
    end
    return saved
end

function Core.CreateLootMessagePatterns(formats)
    formats = type(formats) == "table" and formats or {}
    local patterns = {
        self = {},
        other = {},
    }

    local selfPattern = lootFormatToPattern(formats.lootSelf, false)
    if selfPattern then
        patterns.self[#patterns.self + 1] = selfPattern
    end
    local selfMultiplePattern = lootFormatToPattern(formats.lootSelfMultiple, false)
    if selfMultiplePattern then
        patterns.self[#patterns.self + 1] = selfMultiplePattern
    end
    local otherPattern = lootFormatToPattern(formats.lootOther, true)
    if otherPattern then
        patterns.other[#patterns.other + 1] = otherPattern
    end
    local otherMultiplePattern = lootFormatToPattern(formats.lootOtherMultiple, true)
    if otherMultiplePattern then
        patterns.other[#patterns.other + 1] = otherMultiplePattern
    end

    return patterns
end

function Core.ResolveLootMessageLooter(message, patterns, playerName)
    if type(message) ~= "string" or type(patterns) ~= "table" then
        return nil
    end

    local selfPatterns = type(patterns.self) == "table" and patterns.self or {}
    for index = 1, #selfPatterns do
        if message:match(selfPatterns[index]) then
            return {
                name = playerName,
                isSelf = true,
            }
        end
    end

    local otherPatterns = type(patterns.other) == "table" and patterns.other or {}
    for index = 1, #otherPatterns do
        local name = message:match(otherPatterns[index])
        if type(name) == "string" and name ~= "" then
            return {
                name = name,
                isSelf = false,
            }
        end
    end

    return nil
end

function Core.ExtractItemID(link)
    if type(link) ~= "string" then
        return nil
    end
    local itemID = link:match("item:(%d+)")
    return tonumber(itemID)
end

function Core.BuildItemMetadata(itemLink, instant, detailed)
    instant = type(instant) == "table" and instant or {}
    detailed = type(detailed) == "table" and detailed or {}

    local itemID = instant.itemID or detailed.itemID
    local quality = detailed.quality
    local equipLoc = detailed.equipLoc or instant.equipLoc
    if itemID == nil or quality == nil or equipLoc == nil then
        return nil
    end

    return {
        itemID = itemID,
        name = detailed.name,
        link = detailed.link or itemLink,
        quality = quality,
        itemLevel = detailed.itemLevel,
        classID = detailed.classID or instant.classID,
        subclassID = detailed.subclassID or instant.subclassID,
        equipLoc = equipLoc,
        bindType = detailed.bindType,
        isCraftingReagent = detailed.isCraftingReagent == true,
    }
end

function Core.ResolveDropEncounterName(currentEncounterName, recentEncounterName, recentEncounterEndedAt, now, graceSeconds)
    if type(currentEncounterName) == "string" and currentEncounterName ~= "" then
        return currentEncounterName
    end
    if type(recentEncounterName) ~= "string" or recentEncounterName == "" then
        return nil
    end
    if type(recentEncounterEndedAt) ~= "number" or type(now) ~= "number" or type(graceSeconds) ~= "number" then
        return nil
    end
    local age = now - recentEncounterEndedAt
    if age >= 0 and age <= graceSeconds then
        return recentEncounterName
    end
    return nil
end

function Core.FirstRowEncounterName(rows)
    if type(rows) ~= "table" then
        return nil
    end
    for index = 1, #rows do
        local row = rows[index]
        if type(row) == "table" and type(row.encounterName) == "string" and row.encounterName ~= "" then
            return row.encounterName
        end
    end
    return nil
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
    local limit = state.settings and state.settings.maxSessionRows or DEFAULTS.maxSessionRows
    pruneListStart(state.sessionRows, limit)
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

function Core.ShouldAutoShowWindow(row)
    return type(row) == "table" and row.itemLink ~= nil and row.itemLink ~= ""
end

_G.DoYouNeedItCore = Core
