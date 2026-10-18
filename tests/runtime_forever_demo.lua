local Harness = dofile("tests/runtime_harness.lua")
local count = 0
local function check(value, message)
    count = count + 1
    assert(value, message)
end
local function fresh()
    local h = Harness.new({ flavor = "forever" })
    h.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
    h.env.WOW_PROJECT_ID = 18
    local read = h.env.C_Item.GetItemInfo
    h.env.C_Item.GetItemInfo = function(link)
        local id = tonumber(type(link) == "string" and link:match("item:(%d+)"))
        if not id or not h.items[id] then return nil end
        return read(link)
    end
    return h
end
local helmet = "|cff0070dd|Hitem:16914:2564:0:0:0:0:0:0:60:0:0:0|h[Client Helmet]|h|r"

do
    local h = fresh()
    h:addItem(16914, { name = "Client Helmet", link = helmet, equipLoc = "INVTYPE_HEAD", quality = 3 })
    h:loadAddon(); h:slash("test"); h:runTimers(0, 100)
    local rows = h:visibleRows()
    check(#rows == 1, "unavailable catalogue IDs must not become placeholder rows")
    check(rows[1].row.itemLink == helmet, "demo preserves the client's complete hyperlink and quality color")
    check(rows[1].row.equippedText:find(helmet, 1, true), "comparison uses the same canonical client link")
    rows[1].dropLink:FireScript("OnEnter")
    check(h.env.GameTooltip.hyperlink == helmet, "tooltip receives the exact client hyperlink")
    check(#h.sentMessages == 0, "demo never sends")
end

do
    local h = fresh()
    local ring = "|cff1eff00|Hitem:60001:0:0:0:0:0:0:0:10|h[Equipped Ring]|h|r"
    h:addItem(60001, { name = "Equipped Ring", link = ring, equipLoc = "INVTYPE_FINGER", classID = 4 })
    h:setInventoryLink("player", "Finger0Slot", ring)
    h:loadAddon(); h:slash("test"); h:runTimers(0, 100)
    check(#h:visibleRows() == 1, "client equipment supplies samples when old catalogue IDs are unavailable")
    check(h:visibleRows()[1].row.itemLink == ring, "equipped fallback retains its actual link")
    check(not h:visibleRows()[1].row.equippedText:find("Item #", 1, true), "paired-slot comparison never invents a missing second item")
end

do
    local h = fresh()
    h:loadAddon(); h:slash("test")
    check(#h:visibleRows() == 0, "a cold catalogue shows no fabricated item links")
    h:runTimers(12, 150)
    check(#h:visibleRows() == 0, "failed item loads do not produce placeholders")
    check(h.env.DoYouNeedItFrame.emptyText:GetText():find("Demo", 1, true), "empty demo has its own explanation")
    h:slash("test")
    check(not h.env.DoYouNeedItFrame.historyButton:GetText():find("Demo", 1, true), "empty demo can still be dismissed")
end

do
    local h = fresh()
    h:addItem(16914, { name = "Client Helmet", link = helmet, equipLoc = "INVTYPE_HEAD", cacheLoaded = false })
    h:loadAddon(); h:slash("test")
    check(#h:visibleRows() == 0, "cold data waits for a successful load")
    h:runTimers(0, 100)
    check(#h:visibleRows() == 1 and h:visibleRows()[1].row.itemLink == helmet, "late data adds the real row in place")
    h:slash("test"); h:slash("test"); h:slash("test")
    h:runTimers(40, 150)
    check(#h:visibleRows() == 0, "late callbacks cannot resurrect dismissed previews")
    check(#h.sentMessages == 0, "late data does not send whispers")
end

do
    local h = fresh()
    local first = "|cff0070dd|Hitem:13968:0:0:0:0:0:0:0:60|h[Client Trinket One]|h|r"
    local second = "|cff1eff00|Hitem:11815:0:0:0:0:0:0:0:60|h[Client Trinket Two]|h|r"
    h:addItem(13968, { name = "Client Trinket One", link = first, equipLoc = "INVTYPE_TRINKET", classID = 4 })
    h:addItem(11815, { name = "Client Trinket Two", link = second, equipLoc = "INVTYPE_TRINKET", classID = 4 })
    h:loadAddon(); h:slash("test"); h:runTimers(0, 100)
    check(#h:visibleRows() == 2, "two ready catalogue entries render without unavailable neighbours")
    for _, row in ipairs(h:visibleRows()) do
        check(row.row.equippedText:find(first, 1, true) and row.row.equippedText:find(second, 1, true), "both comparison links come from resolved client data")
        check(row.equippedLink.itemLink == first and row.equippedLink2.itemLink == second, "paired tooltip targets preserve both canonical links")
    end
end

print("Forever demo catalogue regressions passed (" .. count .. " checks).")
