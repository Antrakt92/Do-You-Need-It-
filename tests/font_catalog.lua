dofile("DoYouNeedIt_Core.lua")
local namespace = {}
assert(loadfile("AntraktFontCatalog.lua"))("DoYouNeedIt", namespace)
assert(loadfile("DoYouNeedIt_Fonts.lua"))("DoYouNeedIt", namespace)
local Core = DoYouNeedItCore
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end
local fonts = Core.FontPack.snapshot.fonts
check(#fonts == 46, "shared collection metadata retains all existing families")
local seen = {}
local counts = {}
for _, font in ipairs(fonts) do
    local key = Core.FontPathKey(font.path)
    check(not seen[key], "catalog paths are unique")
    seen[key] = true
    check(#font.sha256 == 64, "shared face keeps pinned hash")
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
check(Core.FontSupportsLocale("Interface/AddOns/DoYouNeedIt/fonts/Neucha.ttf", "ruRU"), "known Neucha remains available in Russian")
check(not Core.FontSupportsLocale("Interface/AddOns/Test/Neucha.ttf", "ruRU"), "an unrelated same filename does not inherit verified coverage")
check(not Core.FontSupportsLocale("Interface/AddOns/Media/Unknown.ttf", "ptBR"), "unknown fonts do not promise accented translations")
check(Core.FontSupportsLocale("Interface/AddOns/Media/Unknown.ttf", "enUS"), "unknown media retains basic Latin availability")
check(not Core.FontSupportsText("Fonts/ARIALN.TTF", "Игрок 物品", "enUS"), "mixed-script text requires every script")
check(Core.FontSupportsText("Interface/AddOns/DoYouNeedIt/fonts/SourceHanSansCN-Regular.otf", "Игрок 物品", "enUS"), "mixed Cyrillic and Han can use Source Han")
check(Core.FontSupportsText("Interface/AddOns/DoYouNeedIt/fonts/SourceHanSansTW-Regular.otf", "繁體中文", "zhTW"), "Traditional UI text uses active locale context")
check(Core.FontSupportsText("Interface/AddOns/DoYouNeedIt/fonts/SourceHanSansTW-Regular.otf", "Игрок 繁體中文", "zhTW"), "mixed Cyrillic and Traditional text keeps TW font")
check(Core.GetTextGlyphRequirements("繁體中文", "zhTW")[1] == "HANT", "Han detection follows Traditional output context")
local providerFonts = "Interface/AddOns/AntraktFonts/fonts/"
local doHyeon = providerFonts .. "DoHyeon-Regular.ttf"
local nanumPen = providerFonts .. "NanumPenScript-Regular.ttf"
local kosugi = providerFonts .. "KosugiMaru-Regular.ttf"
check(Core.FontSupportsLocale(doHyeon, "koKR"), "Do Hyeon remains a choice for Korean UI")
check(not Core.FontSupportsText(doHyeon, "갂", "koKR"), "partial Hangul coverage cannot promise an arbitrary syllable")
check(Core.FontSupportsText(nanumPen, "갂", "koKR"), "full modern Hangul coverage accepts the same syllable")
check(Core.FontSupportsText(kosugi, "あ", "enUS"), "kana is not misclassified as Han")
local sawarabi = providerFonts .. "SawarabiMincho-Regular.ttf"
local dejavu = providerFonts .. "DejaVuSans.ttf"
for _, text in ipairs({ "ゔ", "゙", "゚", "々", "、" }) do
    check(not Core.FontSupportsText(dejavu, text, "enUS"), "Japanese text cannot pass as Latin")
    check(Core.FontSupportsText(sawarabi, text, "enUS"), "Sawarabi has this Japanese glyph")
end
for _, text in ipairs({ "ゔ", "゙", "゚" }) do
    check(not Core.FontSupportsText(kosugi, text, "enUS"), "Kosugi lacks this voiced kana glyph")
    check(Core.FontSupportsText(Core.FontPack.baselinePath, text, "enUS"), "baseline has this voiced kana glyph")
end
check(Core.FontSupportsText(kosugi, "々", "enUS"), "Kosugi has the ideographic iteration mark")
check(not Core.FontSupportsText(providerFonts .. "MaShanZheng-Regular.ttf", "々", "zhCN"), "Chinese script flags do not promise every Japanese punctuation mark")
check(not Core.FontSupportsText(dejavu, "ㄅ", "zhTW"), "Bopomofo cannot pass as Latin")
check(not Core.FontSupportsText(Core.FontPack.baselinePath, "ㇰ", "enUS"), "baseline lacks the Katakana phonetic extension")
check(Core.FontSupportsText(providerFonts .. "SourceHanSansTW-Regular.otf", "ㇰ", "enUS"), "Source Han has the Katakana phonetic extension")
for _, text in ipairs({ "ゕ", "ゖ", "ヿ" }) do
    check(not Core.FontSupportsText(Core.FontPack.baselinePath, text, "enUS"), "baseline lacks this extended kana glyph")
    check(Core.FontSupportsText(sawarabi, text, "enUS"), "Sawarabi has this extended kana glyph")
end
check(not Core.FontSupportsText(kosugi, "Игрок · Another", "ruRU"), "known missing punctuation rejects a Cyrillic face")
check(not Core.FontSupportsText(nanumPen, "한글 – 글꼴", "koKR"), "known missing punctuation rejects a Hangul face")
check(Core.FontSupportsText(Core.FontPack.baselinePath, "한글 – 글꼴", "koKR"), "baseline supports this mixed punctuation fixture")
check(not Core.FontSupportsText(Core.FontPack.baselinePath, "ᄀ", "koKR"), "conjoining Jamo is outside baseline coverage")
check(not Core.FontSupportsText(providerFonts .. "NotoSans-Regular.ttf", "𠀀", "zhCN"), "supplementary Han cannot pass as Latin")
check(not Core.FontSupportsText(kosugi, "\240\128\128\128", "enUS"), "malformed UTF-8 cannot promise coverage")
local protected = "protected あ"
_G.issecretvalue = function(value) return value == protected end
check(not Core.FontSupportsText(kosugi, protected, "enUS"), "restricted string never authorizes font selection")
_G.issecretvalue = function() error("unavailable") end
check(not Core.FontSupportsText(kosugi, protected, "enUS"), "failed secret check also withholds coverage")
_G.issecretvalue = nil
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
