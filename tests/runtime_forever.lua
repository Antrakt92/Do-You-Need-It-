local Harness = dofile("tests/runtime_harness.lua")
local count = 0
local function check(value, message)
    count = count + 1
    assert(value, message)
end
local function fresh(class)
    local h = Harness.new({ flavor = "forever" })
    h.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
    h.env.WOW_PROJECT_ID = 18
    h.env.C_PaperDollInfo = { GetInventorySlotInfo = h.env.GetInventorySlotInfo }
    h.env.GetInventorySlotInfo = nil
    h:setUnit("player", { name = "Player", classToken = class or "HUNTER" })
    h:loadAddon()
    h:slash("")
    h:runTimers(40, 150)
    h:resetSideEffects()
    return h
end

for _, class in ipairs({"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}) do
    local h = fresh(class)
    local core = h.env.DoYouNeedItCore
    check(core.flavor == "forever", "Forever adapter is selected")
    check(core.ResolvePlayerCanEquip({ classID = 4, subclassID = 1, equipLoc = "INVTYPE_CHEST" }, class, true) == true,
        class .. " accepts learned usable armor without Retail maximum-type filtering")
    check(core.ResolvePlayerCanEquip({ classID = 2, equipLoc = "INVTYPE_WEAPON" }, class, false) == false,
        class .. " preserves unavailable proficiency")
    check(core.ResolvePlayerCanEquip({ classID = 2, equipLoc = "INVTYPE_WEAPON" }, class, nil) == nil,
        class .. " never guesses a missing usability result")
    check(h.env.DoYouNeedItFrame.title:GetText() == "Do You Need It?", "window uses the shared addon title")
end

do
    local h = fresh()
    h:slash("settings")
    h.env.DoYouNeedItLanguageDropdown:FireScript("OnClick", "LeftButton")
    local picker = h.env.DoYouNeedItLanguagePicker
    check(picker:IsVisible(), "language picker opens in Forever")
    for _, row in ipairs(picker.buttons) do
        row:FireScript("OnEnter")
        check(not h.env.DoYouNeedItFrame.title:GetText():find("Forever Beta", 1, true),
            "language refresh keeps the shared title")
        row:FireScript("OnLeave")
        h:runTimers(0, 30)
    end
end

for _, loc in ipairs({"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC"}) do
    local h = fresh()
    local equipped = h:addItem(40001, { name = "Equipped ranged", equipLoc = loc })
    local main = h:addItem(40002, { name = "Melee weapon", equipLoc = "INVTYPE_WEAPON" })
    h:setInventoryLink("party1", "RangedSlot", equipped)
    h:setInventoryLink("party1", "MainHandSlot", main)
    local link = h:addItem(40003, { name = "New ranged", equipLoc = loc, bindType = 2 })
    h:fireLoot("Otherplayer", link)
    h:fire("INSPECT_READY", h.units.party1.guid)
    h:runTimers(3, 70)
    local rows = h:visibleRows()
    check(#rows == 1, loc .. " is gear")
    check(rows[1].row.equippedText:find(equipped, 1, true), loc .. " compares the ranged slot through the namespaced API")
    check(not rows[1].row.equippedText:find(main, 1, true), loc .. " does not compare main hand")
end

do
    local h = fresh()
    local equipped = h:addItem(40011, { name = "High level chest", equipLoc = "INVTYPE_CHEST", itemLevel = 200 })
    h:setInventoryLink("party1", "ChestSlot", equipped)
    local bop = h:addItem(40012, { name = "Bound chest", equipLoc = "INVTYPE_CHEST", bindType = 1, itemLevel = 100 })
    h:fireLoot("Otherplayer", bop)
    h:fire("INSPECT_READY", h.units.party1.guid)
    h:runTimers(40, 150)
    local row = h:visibleRows()[1].row
    check(not row.askable, "higher inspected level does not authorize a Forever BoP whisper")
    check(row.tradeStatusKey ~= "trade_likely", "Retail personal-loot trade rule is excluded")
    check(#h.sentMessages == 0, "Forever is opt-in and never sends from the estimate")
end

do
    local h = fresh()
    h.env.C_Item.IsUsableItem = nil
    local link = h:addItem(40021, { name = "Unknown weapon", equipLoc = "INVTYPE_WEAPON", bindType = 2 })
    h:fireLoot("Otherplayer", link)
    check(not h:visibleRows()[1].row.askable, "generic equippability does not substitute for missing player usability")
    h.env.C_Item.IsUsableItem = function() return h:secretValue("usability") end
    h:fireLoot("Otherplayer", h:addItem(40022, { bindType = 2 }))
    check(not h:visibleRows()[2].row.askable, "restricted usability remains unknown")
    h:slash("test")
    local demo = h.env.DoYouNeedItCore.BuildDemoRows({}, 100)
    check(#demo == 12, "Forever demo has twelve isolated examples")
    for _, row in ipairs(demo) do
        check(row.instanceName == "Forever Beta — Demo", "demo does not claim Retail instance membership")
        check(row.itemID < 20000, "Retail Midnight sample IDs are excluded")
    end
    check(#h.sentMessages == 0, "demo and restricted metadata cannot send")
end

for _, identity in ipairs({ { 120105, 1 }, { 16001, 2 }, { 16001, 18 } }) do
    local h = Harness.new({ flavor = "forever" })
    h.env.GetBuildInfo = function() return "", "", "", identity[1] end
    h.env.WOW_PROJECT_ID = identity[2]
    h:loadAddon()
    check((h.env.DoYouNeedItFrame ~= nil) == (identity[2] == 18), "package requires the exact beta project and interface")
    h:fire("PLAYER_ENTERING_WORLD")
end

do
    local h = Harness.new({ flavor = "forever", unsupportedEvents = {
        CHALLENGE_MODE_START = true, CHALLENGE_MODE_COMPLETED = true, CHALLENGE_MODE_RESET = true,
    } })
    h.env.GetBuildInfo = function() return "1.60.1", "70450", "", 16001 end
    h.env.WOW_PROJECT_ID = 18
    h:loadAddon()
    check(h.env.DoYouNeedItFrame ~= nil, "missing optional challenge events do not prevent startup")
    h.env.GetBuildInfo = function() return "", "", "", h:secretValue("interface") end
    check(not h.env.DoYouNeedItCore.IsSupportedForeverClient(), "restricted client identity cannot enable beta")
end

do
    local h = fresh()
    h:addItem(16914, { name = "Client-localized helmet", equipLoc = "INVTYPE_HEAD", cacheLoaded = false })
    h:slash("test")
    h:runTimers(0, 100)
    check(h.env.DoYouNeedItCore.demoItems[1][2] == "Client-localized helmet", "cold demo names refresh from client item data")
    local found = false
    for _, frame in ipairs(h:visibleRows()) do
        if frame.row.itemID == 16914 then found = frame.row.itemLink:find("Client-localized helmet", 1, true) ~= nil end
    end
    -- The helmet can be on another page; the underlying preview factory must agree.
    local rows = h.env.DoYouNeedItCore.BuildDemoRows({}, 100)
    for _, row in ipairs(rows) do
        if row.itemID == 16914 then found = row.itemLink:find("Client-localized helmet", 1, true) ~= nil end
    end
    check(found, "localized name is included in the preview link")
    h:slash("test")
    h:runTimers(40, 100)
    check(#h:visibleRows() == 0, "late preview callbacks do not resurrect a dismissed demo")
end

print("Forever runtime regressions passed (" .. count .. " checks).")
