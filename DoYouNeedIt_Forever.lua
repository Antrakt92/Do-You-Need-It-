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

-- These are illustrative equipment links, not a beta dungeon loot table.
-- Resolve names from the client's catalogue rather than shipping Retail names.
Core.demoItems = {
    { 16914, "Item #16914", "INVTYPE_HEAD" },
    { 16913, "Item #16913", "INVTYPE_HAND" },
    { 16916, "Item #16916", "INVTYPE_CHEST" },
    { 19379, "Item #19379", "INVTYPE_TRINKET" },
    { 19341, "Item #19341", "INVTYPE_TRINKET" },
    { 18832, "Item #18832", "INVTYPE_WEAPON" },
    { 13968, "Item #13968", "INVTYPE_TRINKET" },
    { 11815, "Item #11815", "INVTYPE_TRINKET" },
    { 19384, "Item #19384", "INVTYPE_FINGER" },
    { 19342, "Item #19342", "INVTYPE_TRINKET" },
    { 16915, "Item #16915", "INVTYPE_LEGS" },
    { 18713, "Item #18713", "INVTYPE_RANGED" },
}
Core.demoRing = { 19376, "Item #19376" }

function Core.RefreshForeverDemoNames()
    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then return end
    local function resolve(item)
        local ok, name = pcall(C_Item.GetItemInfo, "item:" .. item[1])
        if not ok then return end
        local clean, secret = pcall(issecretvalue, name)
        if clean and secret == false and type(name) == "string" and name ~= "" then item[2] = name end
    end
    for _, item in ipairs(Core.demoItems) do resolve(item) end
    resolve(Core.demoRing)
end
