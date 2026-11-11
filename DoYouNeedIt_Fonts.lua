local _, namespace = ...
local Core = _G.DoYouNeedItCore
local snapshot = assert(namespace and namespace.AntraktFontCatalog, "Missing font catalog")
local pack = { snapshot = snapshot, baselinePath = "Interface\\AddOns\\DoYouNeedIt\\fonts\\AntraktUISans.ttf", generation = 0, currentByID = {} }
Core.FontPack = pack
local byPath, byID = {}, {}
local function key(path) return Core.FontPathKey(path) end
local function copy(row)
    local result = {}
    for field, value in pairs(row) do result[field] = value end
    return result
end
for _, row in ipairs(snapshot.fonts) do
    byID[row.id] = row
    byPath[key(row.path)] = row.id
    for _, alias in ipairs(row.aliases) do byPath[key(alias)] = row.id end
end
byPath[key(pack.baselinePath)] = snapshot.baseline.id
function pack.Identity(path) return byPath[key(path)] or key(path) end
function pack.Coverage(path)
    local id = byPath[key(path)]
    return id == snapshot.baseline.id and snapshot.baseline or (pack.currentByID and pack.currentByID[id]) or byID[id]
end
function pack.Preferred(settings) return settings.fontBeforeAutoSwitch or settings.font end
function pack.Message(locale, id)
    return (snapshot.messages[locale] or snapshot.messages.enUS)[id] or snapshot.messages.enUS[id] or ""
end
function pack.Invalidate()
    pack.synced = false
    pack.generation = pack.generation + 1
end
local function clean(value, kind)
    local ok, result = pcall(function()
        if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
        if type(value) == kind then return value end
    end)
    if ok then return result end
end
local function api(name)
    local modern = rawget(_G, "C_AddOns")
    if type(modern) ~= "nil" then
        if not clean(modern, "table") or getmetatable(modern) ~= nil then return false, true end
        local method = rawget(modern, name)
        if type(method) ~= "nil" then return clean(method, "function") or false, true end
    end
    local method = rawget(_G, name)
    if type(method) ~= "nil" then return clean(method, "function") or false, false end
    return nil, false
end
local function query(method, ...)
    if type(method) ~= "function" then return nil end
    local ok, a,b,c,d,e,f = pcall(method, ...)
    if ok then return a,b,c,d,e,f end
end
function pack.RefreshMetadata()
    pack.enabledForCurrentCharacter = nil
    local existenceAPI = api("DoesAddOnExist")
    local exists = clean(query(existenceAPI, "AntraktFonts"), "boolean")
    if existenceAPI == nil then
        local info = api("GetAddOnInfo")
        -- Named GetAddOnInfo can echo a missing name; inspect actual indices.
        local countMethod = api("GetNumAddOns")
        local count = clean(query(countMethod), "number")
        if count and count >= 0 and count <= 1024 and count % 1 == 0 and info then
            local complete = true
            exists = false
            for index = 1, count do
                local name = clean(query(info, index), "string")
                if not name or #name == 0 or #name > 128 or name:find("%c") then complete = false
                elseif name == "AntraktFonts" then exists = true; break end
            end
            if not complete and exists ~= true then exists = nil end
        end
    end
    local _, loaded = query(api("IsAddOnLoaded"), "AntraktFonts")
    loaded = clean(loaded, "boolean")
    local status = "provider-not-loaded"
    if loaded == true then status = "provider-incompatible"
    elseif exists == false then status = "provider-unavailable"
    elseif exists == true then
        local method, modern = api("GetAddOnEnableState")
        local character = clean(query(rawget(_G, "UnitGUID"), "player"), "string")
        local enabled
        if character and #character > 0 and #character <= 128 and not character:find("%c") then
            if modern then enabled = query(method, "AntraktFonts", character)
            else enabled = query(method, character, "AntraktFonts") end
        end
        if clean(enabled, "number") == 0 then status = "provider-disabled" end
        if clean(enabled, "number") == 1 or clean(enabled, "number") == 2 then pack.enabledForCurrentCharacter = true end
    end
    pack.metadataStatus = status
    if pack.synced and pack.provider == nil then pack.status = status end
    return status
end
local function character()
    local guid = clean(query(rawget(_G,"UnitGUID"),"player"),"string")
    if guid and #guid>0 and #guid<=128 and not guid:find("%c") then return guid end
end
local function stateFor(guid)
    local callback, modern = api("GetAddOnEnableState")
    local state
    if modern then state=query(callback,"AntraktFonts",guid) else state=query(callback,guid,"AntraktFonts") end
    state=clean(state,"number")
    if state==0 or state==1 or state==2 then return state end
end
local function enabledFor(guid)
    local state=stateFor(guid)
    return state==1 or state==2
end
local function actionSafe()
    if clean(query(rawget(_G,"InCombatLockdown")),"boolean")~=false then return false end
    local list=rawget(_G,"AddonList")
    if type(list)=="nil" then return true end
    local known=false
    for _,name in ipairs({"IsShown","IsVisible"})do
        local ok,callback=pcall(function()return list[name]end)
        if not ok then return false end
        if type(callback)~="nil" then
            known=true
            if clean(query(clean(callback,"function"),list),"boolean")~=false then return false end
        end
    end
    return known and clean(query(rawget(_G,"InCombatLockdown")),"boolean")==false
end
local function actorSafe(guid)
    return character()==guid and actionSafe()
end
local function actionContext(status)
    if not actionSafe() then return nil end
    pack.RefreshMetadata();pack.Sync()
    if pack.status~=status then return nil end
    local guid,save=character(),api("SaveAddOns")
    if not guid or not clean(save,"function") then return nil end
    return guid,save
end
function pack.EnableProvider()
    local guid,save=actionContext("provider-disabled")
    local reload=clean(rawget(_G,"ReloadUI"),"function")
    if not guid or not reload then return "blocked" end
    local callback=api("EnableAddOn")
    if not clean(callback,"function") then return "failed" end
    if stateFor(guid)~=0 or not actorSafe(guid) then return "blocked" end
    if not pcall(callback,"AntraktFonts",guid) then pack.RefreshMetadata();return "failed" end
    if not enabledFor(guid) or not actorSafe(guid) then
        pack.RefreshMetadata();return "failed"
    end
    if not pcall(save) then pack.RefreshMetadata();return "failed" end
    if not actorSafe(guid) then pack.RefreshMetadata();return "blocked" end
    pack.RefreshMetadata();pack.Sync()
    if pack.status=="ready" then return "available" end
    if pack.status=="provider-not-loaded" and enabledFor(guid) and actorSafe(guid) then
        if pcall(reload) then return "reload-requested" end
    end
    return "failed"
end
function pack.ReloadProvider()
    local guid,save=actionContext("provider-not-loaded")
    local reload=clean(rawget(_G,"ReloadUI"),"function")
    if not guid or not reload or not enabledFor(guid) then return "blocked" end
    if not actorSafe(guid) then return "blocked" end
    if not pcall(save) then pack.RefreshMetadata();return "failed" end
    if not actorSafe(guid) then return "blocked" end
    pack.RefreshMetadata();pack.Sync()
    if pack.status~="provider-not-loaded" or not enabledFor(guid) or not actorSafe(guid) then return "blocked" end
    if pcall(reload) then return "reload-requested" end
    return "failed"
end
local western = { enUS = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true }
local glyphFields = { "latin", "cyrillic", "hans", "hant", "hangul", "japanese" }
local reservedFile = snapshot.baseline.file:lower()

local function plain(value)
    return clean(value, "table") and getmetatable(value) == nil
end

local function boundedText(value, maxBytes)
    return clean(value, "string") and #value > 0 and #value <= maxBytes and not value:find("[%c\127]")
end

function pack.Validate(catalog)
    if not plain(catalog) or clean(catalog.formatMajor, "number") ~= 1
        or not boundedText(catalog.catalogRevision, 64) or #catalog.catalogRevision ~= 64
        or not catalog.catalogRevision:match("^[a-f0-9]+$") or not plain(catalog.fonts) then return nil end
    local count = 0
    for index in pairs(catalog.fonts) do
        count = count + 1
        if count > 256 or not clean(index, "number") or index < 1 or index > 256 or index % 1 ~= 0 then return nil end
    end
    if count == 0 then return nil end

    local ids, files, rows = {}, {}, {}
    for index = 1, count do
        local row = catalog.fonts[index]
        if not plain(row) or not boundedText(row.id, 64) or not row.id:match("^[a-z0-9][a-z0-9%-]*$")
            or row.id == snapshot.baseline.id or ids[row.id] or not boundedText(row.name, 128)
            or not boundedText(row.file, 128) or not row.file:match("^[A-Za-z0-9_.%-]+%.[to]tf$")
            or row.file:lower() == reservedFile or files[row.file:lower()]
            or clean(row.path, "string") ~= "Interface\\AddOns\\AntraktFonts\\fonts\\" .. row.file
            or not boundedText(row.sha256, 64) or #row.sha256 ~= 64 or not row.sha256:match("^[a-f0-9]+$") then return nil end
        local validated = { id = row.id, name = row.name, file = row.file, path = row.path, sha256 = row.sha256 }
        for _, field in ipairs(glyphFields) do
            local value = clean(row[field], "boolean")
            if value == nil then return nil end
            validated[field] = value
        end
        if type(row.region) ~= "nil" then
            local region = clean(row.region, "string")
            if region ~= "zhCN" and region ~= "zhTW" then return nil end
            validated.region = region
        end
        if type(row.latinLocales) ~= "nil" then
            if not plain(row.latinLocales) then return nil end
            local locales, total = {}, 0
            for locale, supported in pairs(row.latinLocales) do
                total = total + 1
                if total > 7 or not clean(locale, "string") or not western[locale]
                    or clean(supported, "boolean") ~= true then return nil end
                locales[locale] = true
            end
            validated.latinLocales = locales
        end
        ids[row.id], files[row.file:lower()], rows[index] = true, true, validated
    end
    return rows
end

local syncing = false
function pack.Sync()
    if syncing then return end
    local exported = rawget(_G, "AntraktFonts")
    local provider
    if type(exported) ~= "nil" then provider = plain(exported) and exported or false end
    if pack.synced and rawequal(provider, pack.provider) then return end
    syncing = true
    local status = pack.metadataStatus or pack.RefreshMetadata()
    local rows
    if provider then
        local getter = clean(rawget(provider, "GetCatalog"), "function")
        rows = pack.Validate(query(getter))
    end
    if rows then status = "ready"
    elseif provider ~= nil then status = "provider-incompatible" end

    local baseline = copy(snapshot.baseline)
    baseline.path = pack.baselinePath
    local candidate, currentByID = {baseline}, {[baseline.id] = baseline}
    for _, source in ipairs(rows or snapshot.fonts) do
        local row = copy(source)
        if not rows then row.path = "Interface\\AddOns\\DoYouNeedIt\\fonts\\" .. row.file end
        candidate[#candidate + 1], currentByID[row.id] = row, row
    end
    Core.SetBundledFonts(candidate)
    for index = 2, #candidate do
        local row = candidate[index]
        byPath[key(row.path)] = row.id
    end
    pack.rows, pack.currentByID, pack.status = candidate, currentByID, status
    pack.provider, pack.synced, pack.generation = provider, true, pack.generation + 1
    syncing = false
end
function pack.Resolve(path)
    pack.Sync()
    local original = byID[byPath[key(path)]]
    if (pack.status == "provider-unavailable" or pack.status == "provider-disabled" or pack.status == "provider-not-loaded")
        and original and type(path) == "string"
        and path:match("[^\\/]+$"):lower() == original.file:lower() then return path end
    local row = pack.currentByID[pack.Identity(path)]
    return row and row.path or path
end
function pack.Name(path)
    local id = pack.Identity(path)
    local row = pack.currentByID[id] or byID[id]
    return row and row.name or (type(path) == "string" and path:match("[^\\/]+$")) or snapshot.baseline.name
end
function pack.IsFavorite(favorites, path)
    local id = pack.Identity(path)
    for saved, enabled in pairs(favorites or {}) do
        if enabled == true and pack.Identity(saved) == id then return true end
    end
    return false
end
function pack.ToggleFavorite(favorites, path)
    local id, selected = pack.Identity(path), pack.IsFavorite(favorites, path)
    if selected then
        for saved in pairs(favorites) do if pack.Identity(saved) == id then favorites[saved] = nil end end
    else favorites[key(path)] = true end
end
pack.Sync()
