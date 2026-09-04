local Harness = dofile("tests/runtime_harness.lua")

local function testItemObjectLoad(clearBeforeLoad, synchronous)
    local h = Harness.new()
    local requested, callback
    h.env.C_Item.CreateFromItemID = nil
    h.env.Item = {}
    h.env.Item.CreateFromItemID = function(owner, itemID)
        assert(owner == h.env.Item, "Item factory requires its receiver")
        requested = itemID
        return {
            ContinueOnItemLoad = function(_, onLoad)
                callback = onLoad
                if synchronous then
                    h.items[itemID].cacheLoaded = true
                    onLoad()
                end
            end,
        }
    end
    h:loadAddon()
    h.timers = {}
    local link = h:addItem(33001, { name = "Delayed Sword", cacheLoaded = false })
    h:fireLoot("Otherplayer", link)
    assert(requested == 33001, "uncached loot must use Item:CreateFromItemID")
    assert(type(callback) == "function", "uncached loot must register a completion callback")
    if clearBeforeLoad then
        h:slash("clear")
    end
    h.items[33001].cacheLoaded = true
    callback()
    callback()
    h:runTimers(2.1, 20)
    local expected = clearBeforeLoad and 0 or 1
    assert(#h.env.DoYouNeedItDB.sessionAllRows == expected, "load completion must add once and respect clear")
end

testItemObjectLoad(false, false)
testItemObjectLoad(true, false)
testItemObjectLoad(false, true)

local h = Harness.new()
h:loadAddon()
h.timers = {}
local link = h:addItem(33002, { name = "Scaled Necklace", itemLevel = 500, equipLoc = "INVTYPE_NECK", classID = 4, bindType = 1 })
h.env.C_Item.GetDetailedItemLevelInfo = function() return 600 end
h:fireLoot("Otherplayer", link)
assert(h:visibleRows()[1].row.itemLevel == 600, "initial loot must use the detailed variant level")
print("runtime item regressions ok")
