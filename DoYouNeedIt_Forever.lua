-- Loaded only by the Forever package, after the shared core.
local Core = _G.DoYouNeedItCore
Core.flavor = "forever"
Core.VERSION = "1.0.0"
Core.equipLocOverrides = {
    INVTYPE_RANGED = { "RangedSlot" },
    INVTYPE_RANGEDRIGHT = { "RangedSlot" },
    INVTYPE_THROWN = { "RangedSlot" },
    INVTYPE_RELIC = { "RangedSlot" },
}

function Core.IsSupportedForeverClient()
    if type(GetBuildInfo) ~= "function" then return false end
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    if not ok then return false end
    if type(issecretvalue) ~= "function" then return false end
    local clean, secret = pcall(issecretvalue, interface)
    if not clean or secret ~= false then return false end
    clean, secret = pcall(issecretvalue, WOW_PROJECT_ID)
    if not clean or secret ~= false then return false end
    return interface == 16001 and WOW_PROJECT_ID == 18
end

-- Request a bounded candidate set, but display only data the client resolved.
Core.demoItemIDs = { 16914, 16913, 16916, 19379, 19341, 18832, 13968, 11815, 19384, 19342, 16915, 18713, 19376 }
Core.demoItems = {}
Core.foreverDemoRequests = {}
Core.foreverDemoComparisons = {}

local function Clean(value, kind)
    local ok, secret = pcall(issecretvalue, value)
    if ok and secret == false and type(value) == kind then return value end
end

function Core.RefreshForeverDemoNames()
    local requests, requested, resolved, items, comparisons = {}, {}, {}, {}, {}
    local function collect(query)
        query = Clean(query, "string")
        local id = query and Core.ExtractItemID(query)
        if not id then return end
        if not requested[id] then
            requested[id] = true
            requests[#requests + 1] = query
        end
        if resolved[id] or not C_Item or type(C_Item.GetItemInfo) ~= "function" then return end
        local values = { pcall(C_Item.GetItemInfo, query) }
        if not values[1] then return end
        local name, link = Clean(values[2], "string"), Clean(values[3], "string")
        local equipLoc, classID = Clean(values[10], "string"), Clean(values[13], "number")
        if not name or name == "" or not link or not link:find("|Hitem:", 1, true)
            or Core.ExtractItemID(link) ~= id or not equipLoc or equipLoc == ""
            or (classID ~= 2 and classID ~= 4) then return end
        resolved[id] = true
        items[#items + 1] = { id, name, equipLoc, link = link }
        comparisons[equipLoc] = comparisons[equipLoc] or {}
        if #comparisons[equipLoc] < 2 then
            comparisons[equipLoc][#comparisons[equipLoc] + 1] = link
        end
    end
    for _, id in ipairs(Core.demoItemIDs) do collect("item:" .. id) end
    -- Equipped items provide real beta examples even if old item IDs were removed.
    if type(GetInventoryItemLink) == "function" then
        for slot = 1, 18 do
            if slot ~= 4 then
                local ok, link = pcall(GetInventoryItemLink, "player", slot)
                if ok then collect(link) end
            end
        end
    end
    while #items > 12 do table.remove(items) end
    Core.demoItems, Core.foreverDemoRequests, Core.foreverDemoComparisons = items, requests, comparisons
end

function Core.GetForeverDemoEquippedText(item)
    local links = Core.foreverDemoComparisons[item[3]] or { item.link }
    return (#links > 1 and "Cached: " or "Equipped: ") .. table.concat(links, " / ")
end
