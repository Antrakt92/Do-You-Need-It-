dofile("DoYouNeedIt_Core.lua")
dofile("DoYouNeedIt_Fonts.lua")
local Core = DoYouNeedItCore
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local fonts = Core.GetBundledFonts()
check(#fonts == 46, "all bundled families are exposed without a media addon")
local seen = {}
local counts = {}
for _, font in ipairs(fonts) do
    local key = Core.FontPathKey(font.path)
    check(not seen[key], "catalog paths are unique")
    seen[key] = true
    local file = assert(io.open("fonts/" .. font.file, "rb"))
    check(#file:read("*a") > 10000, "asset exists")
    file:close()
    check(Core.FontSupports(font.path, "CYR", "ruRU") == font.cyrillic, "Cyrillic comes from verified catalog")
    for _, locale in ipairs({"enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"}) do
        if Core.FontSupportsLocale(font.path, locale) then counts[locale] = (counts[locale] or 0) + 1 end
    end
end
for _, locale in ipairs({"enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"}) do
    check((counts[locale] or 0) >= 2, locale .. " has multiple compatible bundled faces")
end
check(not Core.FontSupportsLocale("Interface/AddOns/Test/SourceHanSansCN-Regular.otf", "koKR"), "CN font does not claim Korean support")
check(not Core.FontSupportsLocale("Interface/AddOns/Test/SourceHanSansTW-Regular.otf", "zhCN"), "TW region is excluded from Simplified picker")
check(not Core.FontSupportsLocale("Interface/AddOns/Test/Neucha.ttf", "ptBR"), "incomplete Portuguese accents exclude Neucha")
check(Core.FontSupportsLocale("Interface/AddOns/Test/Neucha.ttf", "ruRU"), "Neucha remains available in Russian")
check(not Core.FontSupportsLocale("Interface/AddOns/Media/Unknown.ttf", "ptBR"), "unknown fonts do not promise accented translations")
check(Core.FontSupportsLocale("Interface/AddOns/Media/Unknown.ttf", "enUS"), "unknown media retains basic Latin availability")
check(not Core.FontSupportsText("Fonts/ARIALN.TTF", "Игрок 物品", "enUS"), "mixed-script text requires every script")
check(Core.FontSupportsText("Interface/AddOns/DoYouNeedIt/fonts/SourceHanSansCN-Regular.otf", "Игрок 物品", "enUS"), "mixed Cyrillic and Han can use Source Han")
check(Core.FontSupportsText("Interface/AddOns/DoYouNeedIt/fonts/SourceHanSansTW-Regular.otf", "繁體中文", "zhTW"), "Traditional UI text uses active locale context")
check(Core.FontSupportsText("Interface/AddOns/DoYouNeedIt/fonts/SourceHanSansTW-Regular.otf", "Игрок 繁體中文", "zhTW"), "mixed Cyrillic and Traditional text keeps TW font")
check(Core.GetTextGlyphRequirements("繁體中文", "zhTW")[1] == "HANT", "Han detection follows Traditional output context")
local saved = {font = "Interface/AddOns/Old/font.ttf", fontFavorites = {["Fonts/ARIALN.TTF"] = true, [false] = true, ["bad"] = false}}
local settings = Core.NormalizeSettings(saved)
check(settings.font == saved.font, "normalization does not rewrite saved custom paths")
check(settings.fontFavorites["fonts\\arialn.ttf"], "favorite paths normalize")
check(settings.fontFavorites ~= saved.fontFavorites, "settings detach the favorite map")
check(settings.fontFavorites.bad == nil, "invalid favorites are discarded")
check(Core.GetLanguageOption("ruRU").label == "Русский", "Russian uses native name")
check(Core.GetLanguageOption("koKR").label == "한국어", "Korean uses native name")
check(Core.GetLanguageOption("zhCN").label == "简体中文", "Simplified Chinese uses native name")
check(Core.GetLanguageOption("zhTW").label == "繁體中文", "Traditional Chinese uses native name")
check(next(Core.NormalizeSettings({fontFavorites = true}).fontFavorites) == nil, "malformed favorite root is harmless")
check(next(Core.NormalizeSettings({fontFavorites = {[""] = true, [string.rep("x", 513)] = true}}).fontFavorites) == nil, "empty and excessive favorite paths are discarded")
local many = {}
for index = 1, 300 do many["Fonts/font" .. index .. ".ttf"] = true end
local normalized = Core.NormalizeSettings({fontFavorites = many}).fontFavorites
local count = 0
for _ in pairs(normalized) do count = count + 1 end
check(count == 256, "favorite storage is bounded")
local labels
for index = 1, 10 do
    local name, value = debug.getupvalue(Core.GetLocaleLabel, index)
    if name == "LABELS_BY_LOCALE" then labels = value end
end
check(type(labels) == "table", "translation table is available")
for _, locale in ipairs({"deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"}) do
    for key, english in pairs(labels.enUS) do
        check(type(labels[locale][key]) == "string", locale .. " translates " .. key)
        local function placeholders(text)
            local tokens = {}
            for token in text:gmatch("%%[ds]") do tokens[#tokens + 1] = token end
            table.sort(tokens)
            return table.concat(tokens, "|")
        end
        check(placeholders(Core.GetLocaleLabel(key, locale)) == placeholders(english), locale .. " preserves format tokens for " .. key)
        if english:find("{item}", 1, true) then
            check(Core.GetLocaleLabel(key, locale):find("{item}", 1, true), locale .. " preserves item placeholder")
        end
    end
end
print("font catalog: " .. checks .. " checks passed")
