local Harness = dofile("tests/runtime_harness.lua")

local function equal(actual, expected, message)
    if actual ~= expected then
        error(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function fresh(db)
    local h = Harness.new({ db = db })
    local createFrame = h.env.CreateFrame
    h.env.CreateFrame = function(...)
        local frame = createFrame(...)
        if frame.name == "DoYouNeedItFrame" then
            frame.GetPoint = function(self)
                local point = self.points and self.points[1]
                if not point then return nil end
                return point[1], point[2] or h.env.UIParent, point[3] or point[1], point[4] or 0, point[5] or 0
            end
            frame.SetUserPlaced = function(self, value) self.userPlaced = value end
        end
        return frame
    end
    h:loadAddon()
    h.timers = {}
    h:resetSideEffects()
    return h
end

local function loot(h, id)
    local link = h:addItem(id, { name = "Navigation Sword " .. id })
    h:fireLoot("Otherplayer", link)
    return link
end

local function populate(h)
    for id = 31001, 31008 do loot(h, id) end
end

local function topRow(h)
    local row = h:visibleRows()[1]
    return row and row.row.itemID
end

local function historyGroup(h, id, name)
    h:fire("ENCOUNTER_START", id, name)
    loot(h, id)
    h:fire("ENCOUNTER_END", id, name)
    h:runTimers(10, 100)
end

local tests = {}

function tests.sessionViewSurvivesNewLoot()
    local h = fresh()
    populate(h)
    h:slash("history")
    equal(h.env.DoYouNeedItFrame.historyButton:GetText(), "This Session", "precondition: session selected")
    loot(h, 31009)
    equal(h.env.DoYouNeedItFrame.historyButton:GetText(), "This Session", "new loot preserves selected session view")
end

function tests.scrolledCurrentKeepsReadingAnchor()
    local h = fresh()
    populate(h)
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    local anchor = topRow(h)
    loot(h, 31009)
    equal(topRow(h), anchor, "new current loot preserves the first visible row while reading older drops")
end

function tests.scrolledSessionKeepsReadingAnchor()
    local h = fresh()
    populate(h)
    h:slash("history")
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    local anchor = topRow(h)
    loot(h, 31009)
    equal(topRow(h), anchor, "new session loot preserves reading anchor")
end

function tests.currentAtTopFollowsLatestLoot()
    local h = fresh()
    populate(h)
    loot(h, 31009)
    equal(topRow(h), 31009, "unscrolled Current continues following latest loot")
end

function tests.historySelectionSurvivesLootAndInsertion()
    local h = fresh()
    historyGroup(h, 31101, "First Boss")
    h:slash("history")
    h:slash("history")
    local title = h.env.DoYouNeedItFrame.historyButton:GetText()
    local anchor = topRow(h)
    h:fire("ENCOUNTER_START", 31102, "Second Boss")
    loot(h, 31102)
    equal(h.env.DoYouNeedItFrame.historyButton:GetText(), title, "incoming loot leaves selected history group visible")
    h:fire("ENCOUNTER_END", 31102, "Second Boss")
    h:runTimers(10, 100)
    equal(h.env.DoYouNeedItFrame.historyButton:GetText(), title, "new history insertion preserves selected group identity")
    equal(topRow(h), anchor, "selected history still shows original group rather than its old numeric index")
end

function tests.finalizationKeepsScrolledCurrentAnchor()
    local h = fresh()
    h:fire("ENCOUNTER_START", 31201, "Long Loot Boss")
    populate(h)
    h.env.DoYouNeedItFrame:FireScript("OnMouseWheel", -1)
    local anchor = topRow(h)
    h:fire("ENCOUNTER_END", 31201, "Long Loot Boss")
    h:runTimers(10, 100)
    equal(topRow(h), anchor, "history finalization retains reading position in Current fallback")
end

local function move(h, x, y)
    local frame = h.env.DoYouNeedItFrame
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", h.env.UIParent, "CENTER", x, y)
    frame:FireScript("OnDragStop")
end

local function assertPosition(h, x, y, message)
    local _, _, _, actualX, actualY = h.env.DoYouNeedItFrame:GetPoint()
    equal(actualX, x, message .. " x")
    equal(actualY, y, message .. " y")
end

function tests.draggedWindowPositionSurvivesReload()
    local h = fresh()
    move(h, 140, -80)
    local reloaded = fresh(h.env.DoYouNeedItDB)
    assertPosition(reloaded, 140, -80, "dragged window position restores on load")
    equal(reloaded.env.DoYouNeedItFrame.userPlaced, true, "restored position is user placed")
end

function tests.logoutSavesFinalWindowPosition()
    local h = fresh()
    local frame = h.env.DoYouNeedItFrame
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", h.env.UIParent, "CENTER", -160, 75)
    h:fire("PLAYER_LOGOUT")
    assertPosition(fresh(h.env.DoYouNeedItDB), -160, 75, "logout saves final position without drag-stop")
end

function tests.resetPositionPersistsWithoutResettingSettings()
    local h = fresh()
    h:slash("delay 21")
    move(h, 140, -80)
    h:slash("resetpos")
    assertPosition(h, 0, 0, "resetpos recenters immediately")
    local reloaded = fresh(h.env.DoYouNeedItDB)
    assertPosition(reloaded, 0, 0, "resetpos survives reload")
    equal(reloaded.env.DoYouNeedItDB.settings.autoDelay, 21, "resetpos preserves unrelated settings")
end

function tests.missingPointCannotOverwriteSavedPosition()
    local h = fresh()
    move(h, 140, -80)
    h.env.DoYouNeedItFrame.GetPoint = function() return nil end
    h.env.DoYouNeedItFrame:FireScript("OnDragStop")
    h:fire("PLAYER_LOGOUT")
    assertPosition(fresh(h.env.DoYouNeedItDB), 140, -80, "missing point preserves prior valid position")
end

local failed = 0
function tests.invalidSavedPositionFallsBackToCenter()
    local positions = {
        { point = "BOGUS", relativePoint = "CENTER", x = 20, y = 30 },
        { point = "CENTER", relativePoint = "BOGUS", x = 20, y = 30 },
        { point = "CENTER", relativePoint = "CENTER", x = 0/0, y = 30 },
        { point = "CENTER", relativePoint = "CENTER", x = math.huge, y = 30 },
        { point = "CENTER", relativePoint = "CENTER", x = 20, y = -math.huge },
        { point = "CENTER", relativePoint = "CENTER", x = 1000000000, y = 30 },
    }
    for _, position in ipairs(positions) do
        assertPosition(fresh({ windowPosition = position }), 0, 0, "invalid saved position defaults to center")
    end
end

for name, test in pairs(tests) do
    local ok, failure = pcall(test)
    if ok then print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(failure)) end
end
if failed > 0 then error(tostring(failed) .. " navigation regressions failed") end
print("Runtime navigation regressions passed")
