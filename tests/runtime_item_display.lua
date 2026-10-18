local Harness = dofile("tests/runtime_harness.lua")
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function fresh(mode)
    local seed = Harness.new(); seed:loadAddon()
    local db = seed.env.DoYouNeedItDB
    local key = next(db.characters)
    local bare = "|Hitem:33099:::::::::9:11:1:23:|h[Cold History Epic]|h"
    local row = { id = "cold-row", looter = "Otherplayer", itemLink = bare, itemID = 33099, timestamp = 900, askable = false }
    db.characters[key].sessionRows = {}
    db.characters[key].sessionAllRows = {row}
    local h = Harness.new({db = db})
    h:addItem(33099, {name = "Cold History Epic", quality = 4, cacheLoaded = false})
    local requests, completions = 0, {}
    h.env.Item.CreateFromItemID = function(owner, id)
        check(owner == h.env.Item and id == 33099, "loader uses exact item ID and receiver")
        requests = requests + 1
        return {ContinueOnItemLoad = function(_, callback)
            completions[#completions + 1] = callback
            if mode == "sync-empty" then callback() end
        end}
    end
    h:loadAddon(); h:runTimers(10, 100); h.timers = {}
    h:slash("history")
    local frame = assert(h:visibleRows()[1])
    local addon
    for i = 1, 30 do
        local name, value = debug.getupvalue(h.env.SlashCmdList.DOYOUNEEDIT, i)
        if name == "Addon" then addon = value end
    end
    return h, frame, assert(addon), bare, completions, function() return requests end
end

local h, frame, addon, bare, completions, requests = fresh()
check(frame.drop:GetText() == bare, "cold saved link remains readable")
check(requests() == 1, "cold saved display requests metadata")
for _ = 1, 20 do addon.ItemDisplayText(bare) end
check(requests() == 1, "repaints deduplicate the same item")
h.items[33099].cacheLoaded = true
local equippedVariant = "|Hitem:33099:::::::::9:12:1:99:|h[Equipped Variant]|h"
frame.equipped:SetText("Equipped: " .. equippedVariant)
completions[1]()
check(frame.drop:GetText() == bare, "callback defers painting outside completion stack")
h:runTimers(1, 100)
check(frame.drop:GetText() == "|cffa335ee" .. bare .. "|r", "completion colors visible saved row without user action")
check(frame.equipped:GetText() == "Equipped: |cffa335ee" .. equippedVariant .. "|r", "same-ID equipped variant retains its own payload")
check(frame.row.itemLink == bare and frame.dropLink.itemLink == bare, "color does not rewrite item variant or click target")
check(#h.sentMessages == 0, "display loading sends no whispers")
completions[1](); h:runTimers(1, 100)
check(requests() == 1, "repeated completion is harmless")

local hs, fs, as, bs, cs, rs = fresh("sync-empty")
hs:runTimers(1, 100)
for _ = 1, 100 do as.ItemDisplayText(bs) end
check(rs() == 1, "synchronous empty-cache completion does not recurse or retry")
check(fs.drop:GetText() == bs, "empty cache leaves original readable text")

local hh, fh, ah, bh, ch = fresh()
hh:runTimers(10, 100)
hh.env.DoYouNeedItFrame:Hide()
hh.items[33099].cacheLoaded = true
ch[1](); hh:runTimers(1, 100)
check(not hh.env.DoYouNeedItFrame:IsShown(), "hidden window stays hidden")
check(fh.drop:GetText() == bh, "hidden child is not repainted")
hh:slash("history")
hh:slash("history")
check(fh.drop:GetText():find("|cffa335ee", 1, true), "next normal view render uses loaded metadata")

local hc, fc, ac, bc, cc = fresh()
hc:runTimers(10, 100)
hc:slash("clear")
hc.items[33099].cacheLoaded = true
cc[1](); hc:runTimers(1, 100)
check(#hc:visibleRows() == 0, "completion after clear cannot resurrect cleared rows")
check(#hc.sentMessages == 0, "cleared display completion cannot send")

local hl, fl, al, bl, cl, rl = fresh()
hl:runTimers(10, 100)
check(al.itemDisplayLoads.pending == 0, "timeout releases the request before metadata arrives")
check(fl.drop:GetText() == bl, "timed-out cache is still readable")
hl.items[33099].cacheLoaded = true
cl[1](); hl:runTimers(1, 100)
check(fl.drop:GetText() == "|cffa335ee" .. bl .. "|r", "metadata arriving after timeout still colors current text")
cl[1](); hl:runTimers(1, 100)
check(al.itemDisplayLoads.pending == 0 and #al.itemDisplayLoads.completed == 1 and rl() == 1,
    "late duplicate callbacks do not double-account or retry")

local hp, fp, ap, bp = fresh()
hp.items[33099].cacheLoaded = true
hp.items[33099].secretValues = true
local ok = pcall(ap.ItemDisplayText, bp)
check(ok, "restricted item quality remains safe")
local explicit = "|cff0070dd" .. bp .. "|r"
check(ap.ItemDisplayText(explicit) == explicit, "existing explicit color remains authoritative")

local hb, fb, ab, bb, cb = fresh()
hb:slash("settings")
hb.items[33099].cacheLoaded = true
cb[1](); hb:runTimers(1, 100)
check(ab.contentMode == "settings" and fb.drop:GetText() == bb, "completion preserves settings and hidden row text")

local he, fe, ae, be = fresh()
he.env.Item.CreateFromItemID = function() error("unavailable loader") end
local failureLink = he:addItem(33100, {cacheLoaded = false})
failureLink = failureLink:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
for _ = 1, 10 do check(ae.ItemDisplayText(failureLink) == failureLink, "loader failure remains readable") end
local failedState = ae.itemDisplayLoads
check(failedState.pending == 1, "failed request releases its pending slot; only earlier cold row remains pending")
check(failedState.entries[33100].finished == true, "failed ID stays remembered")

local completedLoads = 0
he.env.Item.CreateFromItemID = function()
    return {ContinueOnItemLoad = function(_, callback) completedLoads = completedLoads + 1; callback() end}
end
for id = 34000, 34399 do
    he:addItem(id, {cacheLoaded = false})
    ae.ItemDisplayText("|Hitem:" .. id .. ":::::::::::::|h[Cold]|h")
end
local entryCount = 0
for _ in pairs(failedState.entries) do entryCount = entryCount + 1 end
check(completedLoads == 400, "long sessions keep accepting new item IDs after eviction")
check(#failedState.completed == 256 and entryCount == 257, "completed bookkeeping stays bounded alongside the pending row")

local pendingLoads = 0
he.env.Item.CreateFromItemID = function()
    return {ContinueOnItemLoad = function() pendingLoads = pendingLoads + 1 end}
end
for id = 35000, 35099 do
    he:addItem(id, {cacheLoaded = false})
    ae.ItemDisplayText("|Hitem:" .. id .. ":::::::::::::|h[Pending]|h")
end
check(pendingLoads == 63 and failedState.pending == 64, "concurrent metadata requests have a strict limit")
he:runTimers(10, 2000)
check(failedState.pending == 0, "timeouts release never-completing requests")
for _, release in ipairs({"completion", "timeout"}) do
    local hs, fs, as, bs, cs = fresh()
    local loads, held = {}, {}
    hs.env.Item.CreateFromItemID = function(_, id)
        loads[id] = (loads[id] or 0) + 1
        return {ContinueOnItemLoad = function(_, callback) held[id] = callback end}
    end
    for id = 36000, 36062 do
        hs:addItem(id, {cacheLoaded = false})
        as.ItemDisplayText("|Hitem:" .. id .. ":::::::::::::|h[Earlier view]|h")
    end
    check(as.itemDisplayLoads.pending == 64, "capacity fixture reaches the bounded pending limit")
    local blocked = "|Hitem:36063:::::::::::::|h[Current view]|h"
    hs:addItem(36063, {cacheLoaded = false})
    fs.row.itemLink, fs.dropLink.itemLink = blocked, blocked
    fs.drop:SetText(as.ItemDisplayText(blocked))
    check(loads[36063] == nil, "new visible item does not exceed pending capacity")
    if release == "completion" then
        hs.items[33099].cacheLoaded = true
        cs[1]()
        hs:runTimers(1, 100)
    else
        hs:runTimers(10, 1000)
    end
    check(loads[36063] == 1, "visible skipped link is requested after " .. release .. " frees capacity")
    check(as.itemDisplayLoads.pending <= 64, "refill preserves the pending limit")
    hs.items[36063].cacheLoaded = true
    held[36063]()
    hs:runTimers(1, 100)
    check(fs.drop:GetText() == "|cffa335ee" .. blocked .. "|r", "refilled request colors the current view")
    check(#hs.sentMessages == 0, "display refill never sends a whisper")
end

for quality = 0, 7 do
    local link = "|cff" .. addon.ItemDisplayColors[quality] .. bare .. "|r"
    check(addon.ItemLinkQuality(link) == quality, "shared parser preserves quality " .. quality)
    check(addon.ItemLinkQuality(link:gsub("|cff", "|cFF"):gsub("a335ee", "A335EE")) == quality,
        "shared parser preserves uppercase color syntax " .. quality)
end
check(addon.ItemLinkQuality("|cff00ccff" .. bare .. "|r") == 7, "shared heirloom/token color preserves existing rank")
check(addon.ItemLinkQuality(bare) == nil, "bare link does not invent a quality rank")
check(addon.ItemLinkQuality("|cff123456" .. bare .. "|r") == nil, "unknown color does not invent a quality rank")
check(addon.ItemLinkQuality(h:secretValue("quality link")) == nil, "restricted link never enters color parsing")

print("runtime item display: " .. checks .. " checks passed")
