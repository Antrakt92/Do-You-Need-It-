local _, namespace = ...
local Core = _G.DoYouNeedItCore
local snapshot = assert(namespace and namespace.AntraktFontCatalog, "Missing font catalog")
local pack = { snapshot = snapshot, baselinePath = "Interface\\AddOns\\DoYouNeedIt\\fonts\\AntraktUISans.ttf", generation = 0 }
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
function pack.Validate(catalog)
    if type(catalog) ~= "table" or catalog.formatMajor ~= 1
        or type(catalog.catalogRevision) ~= "string" or #catalog.catalogRevision < 1 or #catalog.catalogRevision > 128
        or type(catalog.fonts) ~= "table" or #catalog.fonts < 1 or #catalog.fonts > 256 then return nil end
    local ids, paths, rows = {}, {}, {}
    for index, row in ipairs(catalog.fonts) do
        if type(row) ~= "table" or type(row.id) ~= "string" or not row.id:match("^[a-z0-9%-]+$") or #row.id > 96
            or type(row.name) ~= "string" or #row.name < 1 or #row.name > 128
            or type(row.file) ~= "string" or #row.file > 160 or not row.file:match("^[A-Za-z0-9_.%-]+%.[to][tt]f$")
            or row.path ~= "Interface\\AddOns\\AntraktFonts\\fonts\\" .. row.file
            or type(row.sha256) ~= "string" or #row.sha256 ~= 64 or row.sha256:find("[^a-fA-F0-9]")
            or ids[row.id] or paths[key(row.path)] then return nil end
        for _, flag in ipairs({ "latin", "cyrillic", "hans", "hant", "hangul", "japanese" }) do
            if type(row[flag]) ~= "boolean" then return nil end
        end
        if row.region ~= nil and row.region ~= "zhCN" and row.region ~= "zhTW" then return nil end
        if row.latinLocales ~= nil then
            if type(row.latinLocales) ~= "table" then return nil end
            local count = 0
            for locale, supported in pairs(row.latinLocales) do
                count = count + 1
                if count > 11 then return nil end
                if not snapshot.messages[locale] or type(supported) ~= "boolean" then return nil end
            end
        end
        ids[row.id], paths[key(row.path)] = true, true
        rows[index] = copy(row)
    end
    local count = 0
    for index in pairs(catalog.fonts) do
        count = count + 1
        if count > 256 then return nil end
        if type(index) ~= "number" or index < 1 or index > #rows or index % 1 ~= 0 then return nil end
    end
    return rows
end
function pack.Sync()
    local provider = rawget(_G, "AntraktFonts")
    if pack.synced and provider == pack.provider then return end
    pack.provider, pack.synced = provider, true
    pack.status = "provider-unavailable"
    local rows
    if type(provider) == "table" and type(provider.GetCatalog) == "function" then
        local ok, catalog = pcall(provider.GetCatalog)
        local valid, result = pcall(pack.Validate, ok and catalog or nil)
        if valid and result then rows = result; pack.status = "ready" else pack.status = "provider-incompatible" end
    elseif provider ~= nil then pack.status = "provider-incompatible" end
    pack.rows = {}
    pack.currentByID = {}
    local baseline = copy(snapshot.baseline)
    baseline.path = pack.baselinePath
    pack.rows[1], pack.currentByID[baseline.id] = baseline, baseline
    for _, source in ipairs(rows or snapshot.fonts) do
        local row = copy(source)
        if not rows then row.path = "Interface\\AddOns\\DoYouNeedIt\\fonts\\" .. row.file end
        pack.rows[#pack.rows + 1], pack.currentByID[row.id] = row, row
        byPath[key(row.path)] = row.id
    end
    Core.SetBundledFonts(pack.rows)
    pack.generation = pack.generation + 1
end
function pack.Resolve(path)
    pack.Sync()
    local original = byID[byPath[key(path)]]
    if pack.status == "provider-unavailable" and original and type(path) == "string"
        and not path:find("AntraktFonts", 1, true)
        and path:match("[^\\/]+$"):lower() == original.file:lower() then return path end
    local row = pack.currentByID[pack.Identity(path)]
    return row and row.path or path
end
function pack.Name(path)
    local id = pack.Identity(path)
    local row = byID[id] or pack.currentByID[id]
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
