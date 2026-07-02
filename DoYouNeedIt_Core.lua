local Core = {}

Core.VERSION = "0.2.2"

local GLYPH_LATIN = "LATIN"
local GLYPH_CYR = "CYR"
local GLYPH_HANGUL = "HANGUL"
local GLYPH_HANS = "HANS"
local GLYPH_HANT = "HANT"

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_WHISPER_TEMPLATE = "Hey, do you need {item}?"
local MAX_WHISPER_TEMPLATE_LENGTH = 160

Core.DEFAULT_WHISPER_TEMPLATE = DEFAULT_WHISPER_TEMPLATE
Core.MAX_WHISPER_TEMPLATE_LENGTH = MAX_WHISPER_TEMPLATE_LENGTH

local LANGUAGE_OPTIONS = {
    { value = "auto", label = nil },
    { value = "enUS", label = "English" },
    { value = "deDE", label = "Deutsch" },
    { value = "esES", label = "Español (España)", compactLabel = "Español ES" },
    { value = "esMX", label = "Español (México)", compactLabel = "Español MX" },
    { value = "frFR", label = "Français" },
    { value = "itIT", label = "Italiano" },
    { value = "ptBR", label = "Português (Brasil)" },
    { value = "koKR", label = "한국어 (Korean)", compactLabel = "한국어 / Korean" },
    { value = "ruRU", label = "Русский (Russian)" },
    { value = "zhCN", label = "中文 简体 (Simplified)", compactLabel = "中文 / Simpl." },
    { value = "zhTW", label = "中文 繁體 (Traditional)", compactLabel = "中文 / Trad." },
}

local LOCALE_GLYPH_REQ = {
    enUS = GLYPH_LATIN, deDE = GLYPH_LATIN, esES = GLYPH_LATIN, esMX = GLYPH_LATIN,
    frFR = GLYPH_LATIN, itIT = GLYPH_LATIN, ptBR = GLYPH_LATIN,
    ruRU = GLYPH_CYR, koKR = GLYPH_HANGUL, zhCN = GLYPH_HANS, zhTW = GLYPH_HANT,
}

local FONT_GLYPH_SUPPORT = {}
local function addFontGlyphSupport(path, glyphs)
    FONT_GLYPH_SUPPORT[(path:gsub("/", "\\"):lower())] = glyphs
end

addFontGlyphSupport("Fonts\\2002.ttf", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANGUL })
addFontGlyphSupport("Fonts\\2002B.ttf", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANGUL })
addFontGlyphSupport("Fonts\\ARHei.TTF", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS, GLYPH_HANT })
addFontGlyphSupport("Fonts\\ARIALN.TTF", { GLYPH_LATIN, GLYPH_CYR })
addFontGlyphSupport("Fonts\\ARKai_C.ttf", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS, GLYPH_HANT })
addFontGlyphSupport("Fonts\\ARKai_T.ttf", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS, GLYPH_HANT })
addFontGlyphSupport("Fonts\\bHEI00M.ttf", { GLYPH_HANT })
addFontGlyphSupport("Fonts\\bHEI01B.ttf", { GLYPH_HANT })
addFontGlyphSupport("Fonts\\bKAI00M.ttf", { GLYPH_HANT })
addFontGlyphSupport("Fonts\\bLEI00D.ttf", { GLYPH_HANT })
addFontGlyphSupport("Fonts\\FRIZQT___CYR.TTF", { GLYPH_CYR })
addFontGlyphSupport("Fonts\\K_Damage.TTF", { GLYPH_CYR, GLYPH_HANGUL })
addFontGlyphSupport("Fonts\\K_Pagetext.TTF", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANGUL })
addFontGlyphSupport("Fonts\\MORPHEUS.TTF", { GLYPH_LATIN })
addFontGlyphSupport("Fonts\\MORPHEUS_CYR.TTF", { GLYPH_LATIN, GLYPH_CYR })
addFontGlyphSupport("Fonts\\NIM_____.ttf", { GLYPH_LATIN, GLYPH_CYR })
addFontGlyphSupport("Fonts\\SKURRI.TTF", { GLYPH_LATIN })
addFontGlyphSupport("Fonts\\SKURRI_CYR.TTF", { GLYPH_LATIN, GLYPH_CYR })

local FONT_GLYPH_PATTERNS = {
    { pattern = "noto.*cjk", glyphs = { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS, GLYPH_HANT, GLYPH_HANGUL } },
    { pattern = "sourcehan", glyphs = { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS, GLYPH_HANT, GLYPH_HANGUL } },
    { pattern = "wenquanyi", glyphs = { GLYPH_LATIN, GLYPH_HANS, GLYPH_HANT } },
    { pattern = "wqy", glyphs = { GLYPH_LATIN, GLYPH_HANS, GLYPH_HANT } },
    { pattern = "pingfang", glyphs = { GLYPH_LATIN, GLYPH_HANS, GLYPH_HANT } },
    { pattern = "yahei", glyphs = { GLYPH_LATIN, GLYPH_HANS } },
    { pattern = "msyh", glyphs = { GLYPH_LATIN, GLYPH_HANS } },
    { pattern = "msjh", glyphs = { GLYPH_LATIN, GLYPH_HANT } },
    { pattern = "simsun", glyphs = { GLYPH_LATIN, GLYPH_HANS } },
    { pattern = "simhei", glyphs = { GLYPH_LATIN, GLYPH_HANS } },
    { pattern = "mingliu", glyphs = { GLYPH_LATIN, GLYPH_HANT } },
    { pattern = "applesdgothicneo", glyphs = { GLYPH_LATIN, GLYPH_HANGUL } },
    { pattern = "malgun.*gothic", glyphs = { GLYPH_LATIN, GLYPH_HANGUL } },
    { pattern = "nanum", glyphs = { GLYPH_LATIN, GLYPH_HANGUL } },
}

local CYRILLIC_UTF8_LEAD_PATTERN = "[\208\209]"

local BLIZZARD_SHIPPED_FONTS = {
    { path = "Fonts\\FRIZQT__.TTF", name = "Friz Quadrata TT" },
    { path = "Fonts\\ARIALN.TTF", name = "Arial Narrow" },
    { path = "Fonts\\SKURRI.TTF", name = "Skurri" },
    { path = "Fonts\\MORPHEUS.TTF", name = "Morpheus" },
    { path = "Fonts\\ARKai_T.ttf", name = "Chinese (Simplified)", locale = "zhCN" },
    { path = "Fonts\\bHEI00M.ttf", name = "Chinese (Traditional)", locale = "zhTW" },
    { path = "Fonts\\2002.ttf", name = "Korean", locale = "koKR" },
}

local LABELS_BY_LOCALE = {
    enUS = {
        ["Do You Need It?"] = "Do You Need It?",
        ["Settings"] = "Settings",
        ["Askable"] = "Askable",
        ["All Gear"] = "All Gear",
        ["Current"] = "Current",
        ["This Session"] = "This Session",
        ["History"] = "History",
        ["Run"] = "Run",
        ["Loot"] = "Loot",
        ["Auto whisper"] = "Auto whisper",
        ["Delay"] = "Delay",
        ["Low"] = "Low",
        ["High"] = "High",
        ["Language:"] = "Language:",
        ["Font:"] = "Font:",
        ["Font Size:"] = "Font Size:",
        ["Whisper text:"] = "Whisper text:",
        ["Reset"] = "Reset",
        ["Auto (current: %s)"] = "Auto (current: %s)",
        ["No askable gear drops in this view."] = "No askable gear drops in this view.",
        ["No gear drops in this view."] = "No gear drops in this view.",
        ["Ask"] = "Ask",
        ["Sent"] = "Sent",
        ["Sending"] = "Sending",
        ["Auto: off"] = "Auto: off",
        ["Auto: %ds"] = "Auto: %ds",
        ["Equipped: "] = "Equipped: ",
        ["Cached: "] = "Cached: ",
        ["Equipped: unknown"] = "Equipped: unknown",
        ["Equipped: checking..."] = "Equipped: checking...",
        ["Equipped: unavailable"] = "Equipped: unavailable",
        ["drop_one"] = "drop",
        ["drop_few"] = "drops",
        ["drop_many"] = "drops",
        ["candidate"] = "candidate",
        ["sent"] = "sent",
        ["auto sent"] = "auto sent",
        ["auto_sent"] = "auto sent",
        ["sending"] = "sending",
        ["auto sending"] = "auto sending",
        ["auto_sending"] = "auto sending",
        ["auto_pending"] = "auto in %ds",
        ["whisper failed"] = "whisper failed",
        ["whisper_failed"] = "whisper failed",
        ["test row"] = "test row",
        ["test_row"] = "test row",
        ["bind_on_pickup"] = "bind on pickup",
        ["bind_unknown"] = "trade status unknown",
        ["not_askable"] = "not askable",
        ["quest_bound"] = "quest bound",
        ["player_cannot_equip"] = "cannot equip",
        ["player_equip_unknown"] = "equip unknown",
        ["self_loot"] = "own loot",
        ["bonus_roll"] = "bonus loot",
        ["not_tradeable"] = "not tradeable",
        ["looter_unresolved"] = "looter unresolved",
        ["Font may not render %s glyphs."] = "Font may not render %s glyphs.",
    },
    ruRU = {
        ["Do You Need It?"] = "Do You Need It?",
        ["Settings"] = "Настройки",
        ["Askable"] = "Можно спросить",
        ["All Gear"] = "Весь шмот",
        ["Current"] = "Текущий",
        ["This Session"] = "Эта сессия",
        ["History"] = "История",
        ["Run"] = "Проход",
        ["Loot"] = "Лут",
        ["Auto whisper"] = "Авто-виспер",
        ["Delay"] = "Задержка",
        ["Low"] = "Мин.",
        ["High"] = "Макс.",
        ["Language:"] = "Язык:",
        ["Font:"] = "Шрифт:",
        ["Font Size:"] = "Размер шрифта:",
        ["Whisper text:"] = "Текст виспера:",
        ["Reset"] = "Сброс",
        ["Auto (current: %s)"] = "Авто (сейчас: %s)",
        ["No askable gear drops in this view."] = "Нет шмота, о котором стоит спрашивать.",
        ["No gear drops in this view."] = "Нет шмота в этом виде.",
        ["Ask"] = "Ask",
        ["Sent"] = "Отпр.",
        ["Sending"] = "Отпр...",
        ["Auto: off"] = "Авто: выкл",
        ["Auto: %ds"] = "Авто: %dс",
        ["Equipped: "] = "Надето: ",
        ["Cached: "] = "Кэш: ",
        ["Equipped: unknown"] = "Надето: неизвестно",
        ["Equipped: checking..."] = "Надето: проверка...",
        ["Equipped: unavailable"] = "Надето: недоступно",
        ["drop_one"] = "дроп",
        ["drop_few"] = "дропа",
        ["drop_many"] = "дропов",
        ["candidate"] = "кандидат",
        ["sent"] = "отправлено",
        ["auto sent"] = "авто отправлено",
        ["auto_sent"] = "авто отправлено",
        ["sending"] = "отправка",
        ["auto sending"] = "авто-отправка",
        ["auto_sending"] = "авто-отправка",
        ["auto_pending"] = "авто через %dс",
        ["whisper failed"] = "виспер не отправлен",
        ["whisper_failed"] = "виспер не отправлен",
        ["test row"] = "тест",
        ["test_row"] = "тест",
        ["bind_on_pickup"] = "персональный",
        ["bind_unknown"] = "статус передачи неизвестен",
        ["not_askable"] = "не спрашивать",
        ["quest_bound"] = "квестовый предмет",
        ["player_cannot_equip"] = "не надеть",
        ["player_equip_unknown"] = "неизвестно, можно ли надеть",
        ["self_loot"] = "свой лут",
        ["bonus_roll"] = "доп. лут",
        ["not_tradeable"] = "не передать",
        ["looter_unresolved"] = "лутер не найден",
        ["Font may not render %s glyphs."] = "Шрифт может не отображать символы %s.",
    },
}

local simpleLocaleLabels = {
    deDE = { ["Settings"] = "Einstellungen", ["Language:"] = "Sprache:", ["Font:"] = "Schrift:", ["Font Size:"] = "Schriftgröße:", ["Delay"] = "Verzögerung", ["Low"] = "Niedrig", ["High"] = "Hoch", ["Auto whisper"] = "Auto-Flüstern" },
    esES = { ["Settings"] = "Opciones", ["Language:"] = "Idioma:", ["Font:"] = "Fuente:", ["Font Size:"] = "Tamaño:", ["Delay"] = "Retraso", ["Low"] = "Bajo", ["High"] = "Alto", ["Auto whisper"] = "Susurro auto" },
    esMX = { ["Settings"] = "Opciones", ["Language:"] = "Idioma:", ["Font:"] = "Fuente:", ["Font Size:"] = "Tamaño:", ["Delay"] = "Retraso", ["Low"] = "Bajo", ["High"] = "Alto", ["Auto whisper"] = "Susurro auto" },
    frFR = { ["Settings"] = "Options", ["Language:"] = "Langue :", ["Font:"] = "Police :", ["Font Size:"] = "Taille :", ["Delay"] = "Délai", ["Low"] = "Bas", ["High"] = "Haut", ["Auto whisper"] = "Chuchotement auto" },
    itIT = { ["Settings"] = "Impostazioni", ["Language:"] = "Lingua:", ["Font:"] = "Font:", ["Font Size:"] = "Dimensione:", ["Delay"] = "Ritardo", ["Low"] = "Basso", ["High"] = "Alto", ["Auto whisper"] = "Sussurro auto" },
    ptBR = { ["Settings"] = "Configurações", ["Language:"] = "Idioma:", ["Font:"] = "Fonte:", ["Font Size:"] = "Tamanho:", ["Delay"] = "Atraso", ["Low"] = "Baixo", ["High"] = "Alto", ["Auto whisper"] = "Sussurro auto" },
    koKR = { ["Settings"] = "설정", ["Language:"] = "언어:", ["Font:"] = "글꼴:", ["Font Size:"] = "글꼴 크기:", ["Delay"] = "지연", ["Low"] = "낮음", ["High"] = "높음", ["Auto whisper"] = "자동 귓속말" },
    zhCN = { ["Settings"] = "设置", ["Language:"] = "语言:", ["Font:"] = "字体:", ["Font Size:"] = "字体大小:", ["Delay"] = "延迟", ["Low"] = "低", ["High"] = "高", ["Auto whisper"] = "自动密语" },
    zhTW = { ["Settings"] = "設定", ["Language:"] = "語言:", ["Font:"] = "字型:", ["Font Size:"] = "字型大小:", ["Delay"] = "延遲", ["Low"] = "低", ["High"] = "高", ["Auto whisper"] = "自動密語" },
}

for locale, labels in pairs(simpleLocaleLabels) do
    LABELS_BY_LOCALE[locale] = {}
    for key, value in pairs(LABELS_BY_LOCALE.enUS) do
        LABELS_BY_LOCALE[locale][key] = labels[key] or value
    end
end

local DEFAULTS = {
    autoWhisper = false,
    debug = false,
    autoDelay = 10,
    whisperTemplate = DEFAULT_WHISPER_TEMPLATE,
    minDelay = 3,
    maxDelay = 30,
    maxHistoryGroups = 10,
    maxSessionRows = 50,
    minQuality = 2,
    forceLocale = "auto",
    font = DEFAULT_FONT,
    fontSize = 12,
    minFontSize = 8,
    maxFontSize = 24,
}

local VALID_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true,
    INVTYPE_SHIELD = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local PERSISTED_ROW_KEYS = {
    id = "string",
    looter = "string",
    classToken = "string",
    itemLink = "string",
    equipLoc = "string",
    itemID = "number",
    instanceName = "string",
    encounterName = "string",
    timestamp = "number",
    lootSource = "string",
    reason = "string",
    statusKey = "string",
    statusText = "string",
    equippedText = "string",
    unsafe = "boolean",
    manualWhispered = "boolean",
    autoWhispered = "boolean",
    askable = "boolean",
}

local PERSISTED_GROUP_KEYS = {
    title = "string",
    instanceName = "string",
    encounterName = "string",
    startedAt = "number",
    endedAt = "number",
}

local function asNumber(value, fallback)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clamp(number, minimum, maximum)
    if number < minimum then
        return minimum
    end
    if number > maximum then
        return maximum
    end
    return number
end

local function utf8CharByteLength(firstByte)
    if not firstByte then
        return 1
    end
    if firstByte < 128 then
        return 1
    end
    if firstByte >= 194 and firstByte < 224 then
        return 2
    end
    if firstByte >= 224 and firstByte < 240 then
        return 3
    end
    if firstByte >= 240 and firstByte < 245 then
        return 4
    end
    return 1
end

local function truncateUtf8Bytes(text, maxBytes)
    if #text <= maxBytes then
        return text
    end

    local index = 1
    local lastCompleteByte = 0
    while index <= maxBytes do
        local charLength = utf8CharByteLength(text:byte(index))
        local charEnd = index + charLength - 1
        if charEnd > maxBytes then
            break
        end
        lastCompleteByte = charEnd
        index = charEnd + 1
    end
    return text:sub(1, lastCompleteByte)
end

local function stripPartialItemPlaceholder(text)
    local placeholder = "{item}"
    for length = #placeholder - 1, 1, -1 do
        local suffix = text:sub(-length)
        if suffix == placeholder:sub(1, length) then
            return text:sub(1, #text - length)
        end
    end
    return text
end

function Core.NormalizeWhisperTemplate(template)
    if type(template) ~= "string" or not template:match("%S") then
        return DEFAULT_WHISPER_TEMPLATE
    end
    if #template > MAX_WHISPER_TEMPLATE_LENGTH then
        return stripPartialItemPlaceholder(truncateUtf8Bytes(template, MAX_WHISPER_TEMPLATE_LENGTH))
    end
    return template
end

function Core.FormatWhisperMessage(template, itemLink)
    local message = Core.NormalizeWhisperTemplate(template)
    local itemText = type(itemLink) == "string" and itemLink or ""
    if message:find("{item}", 1, true) then
        return (message:gsub("{item}", function()
            return itemText
        end))
    end
    if itemText == "" then
        return message
    end
    if message:match("%s$") then
        return message .. itemText
    end
    return message .. " " .. itemText
end

local function copyList(list)
    local copy = {}
    if type(list) ~= "table" then
        return copy
    end
    for index = 1, #list do
        copy[index] = list[index]
    end
    return copy
end

local function pruneListStart(list, limit)
    limit = math.max(1, math.floor(asNumber(limit, 1)))
    while #list > limit do
        table.remove(list, 1)
    end
end

local function pruneListEnd(list, limit)
    limit = math.max(1, math.floor(asNumber(limit, 1)))
    while #list > limit do
        table.remove(list)
    end
end

local function copyPrimitiveFields(source, allowedKeys)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for key in pairs(allowedKeys) do
        local value = source[key]
        local valueType = type(value)
        local allowedType = allowedKeys[key]
        if allowedType == true and (valueType == "string" or valueType == "number" or valueType == "boolean") then
            if valueType ~= "number" or isFiniteNumber(value) then
                copy[key] = value
            end
        elseif allowedType == valueType then
            if valueType ~= "number" or isFiniteNumber(value) then
                copy[key] = value
            end
        end
    end
    return copy
end

local LEGACY_STATUS_TEXT_TO_KEY = {
    ["candidate"] = "candidate",
    ["sent"] = "sent",
    ["auto sent"] = "auto_sent",
    ["sending"] = "sending",
    ["auto sending"] = "auto_sending",
    ["whisper failed"] = "whisper_failed",
    ["test row"] = "test_row",
}

local TRANSIENT_STATUS_KEYS = {
    auto_pending = true,
    sending = true,
    auto_sending = true,
}

local function resolveRowStatus(row, useFallback)
    if type(row) ~= "table" then
        return useFallback ~= false and "candidate" or nil, nil
    end

    if type(row.statusKey) == "string" and row.statusKey ~= "" then
        return row.statusKey, tonumber(row.statusSeconds)
    end

    local text = type(row.statusText) == "string" and row.statusText or nil
    if text and text ~= "" then
        local seconds = text:match("^auto in (%d+)s$")
        if seconds then
            return "auto_pending", tonumber(seconds)
        end
        return LEGACY_STATUS_TEXT_TO_KEY[text] or text, nil
    end

    if type(row.reason) == "string" and row.reason ~= "" then
        return row.reason, nil
    end
    if useFallback ~= false then
        return "candidate", nil
    end
    return nil, nil
end

local function snapshotRowForSave(row)
    local saved = copyPrimitiveFields(row, PERSISTED_ROW_KEYS)
    local statusKey = resolveRowStatus(row, false)
    if statusKey then
        if TRANSIENT_STATUS_KEYS[statusKey] then
            statusKey = "candidate"
        end
        saved.statusKey = statusKey
    end
    saved.statusText = nil
    if saved.equippedText == "Equipped: checking..." then
        saved.equippedText = "Equipped: unknown"
    end
    return saved
end

local function snapshotRowsForSave(rows, limit)
    local saved = {}
    if type(rows) == "table" then
        for index = 1, #rows do
            if type(rows[index]) == "table" then
                saved[#saved + 1] = snapshotRowForSave(rows[index])
            end
        end
    end
    if limit ~= nil then
        pruneListStart(saved, limit)
    end
    return saved
end

local function snapshotRowsForSaveWithFallback(rows, fallbackRows, limit)
    local saved = snapshotRowsForSave(rows, limit)
    if #saved == 0 then
        saved = snapshotRowsForSave(fallbackRows, limit)
    end
    return saved
end

local function copyEquipmentSlots(slots)
    local copy = {}
    if type(slots) ~= "table" then
        return copy, 0
    end

    local count = 0
    for equipLoc, text in pairs(slots) do
        if type(equipLoc) == "string" and equipLoc ~= "" and type(text) == "string" and text ~= "" then
            copy[equipLoc] = text
            count = count + 1
        end
    end
    return copy, count
end

local function baseName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name:match("^([^-]+)") or name
end

local function realmName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name:match("^[^-]+%-(.+)$")
end

local function samePlayerName(left, right)
    local leftBase = baseName(left)
    local rightBase = baseName(right)
    local leftRealm = realmName(left)
    local rightRealm = realmName(right)
    if leftRealm and rightRealm then
        return left == right
    end
    return leftBase ~= nil and rightBase ~= nil and leftBase == rightBase
end

local function isSelfLootName(looter, playerName)
    local looterBase = baseName(looter)
    local playerBase = baseName(playerName)
    if looterBase == nil or playerBase == nil or looterBase ~= playerBase then
        return false
    end

    local looterRealm = realmName(looter)
    local playerRealm = realmName(playerName)
    if looterRealm and playerRealm then
        return looter == playerName
    end
    if looterRealm and not playerRealm then
        return false
    end
    return true
end

function Core.IsPlaceholderName(name)
    return name == "UNKNOWNOBJECT" or name == "UNKNOWN" or name == "Unknown"
end

local function stripRosterSearchText(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|Hplayer:([^:|]+)[^|]*|h%[([^%]]+)%]|h", "%1 %2")
    text = text:gsub("|H.-|h%[.-%]|h", " ")
    text = text:gsub("|A.-|a", "")
    return text
end

local function isNameByte(byte)
    return byte ~= nil and (
        (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
        or byte == 45
        or byte >= 128
    )
end

local function findPlainName(text, name)
    if type(text) ~= "string" or type(name) ~= "string" or text == "" or name == "" then
        return nil
    end

    local start = 1
    while true do
        local foundStart, foundEnd = text:find(name, start, true)
        if not foundStart then
            return nil
        end
        local previousByte = foundStart > 1 and text:byte(foundStart - 1) or nil
        local nextByte = foundEnd < #text and text:byte(foundEnd + 1) or nil
        if not isNameByte(previousByte) and not isNameByte(nextByte) then
            return foundStart, foundEnd
        end
        start = foundStart + 1
    end
end

local function sortedRosterNames(roster)
    local names = {}
    if type(roster) ~= "table" then
        return names
    end
    local aliases = type(roster.aliases) == "table" and roster.aliases or roster
    for name in pairs(aliases) do
        if type(name) == "string" and name ~= "" then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(left, right)
        if #left == #right then
            return left < right
        end
        return #left > #right
    end)
    return names
end

local function canonicalRosterName(candidate, roster)
    if type(candidate) ~= "string" or candidate == "" or type(roster) ~= "table" then
        return nil
    end
    if Core.IsPlaceholderName(candidate) then
        return nil
    end
    if type(roster.aliases) == "table" then
        return roster.aliases[candidate]
    end
    if roster[candidate] ~= nil then
        return candidate
    end
    local names = sortedRosterNames(roster)
    for index = 1, #names do
        local name = names[index]
        if samePlayerName(name, candidate) then
            return name
        end
    end
    return nil
end

function Core.CreateRosterIndex(entries)
    local roster = {
        aliases = {},
        units = {},
        ambiguous = {},
    }
    local shortOwners = {}
    entries = type(entries) == "table" and entries or {}

    for index = 1, #entries do
        local entry = entries[index]
        if type(entry) == "table" then
            local fullName = type(entry.fullName) == "string" and entry.fullName ~= "" and entry.fullName or nil
            local shortName = type(entry.shortName) == "string" and entry.shortName ~= "" and entry.shortName or nil
            if fullName and not Core.IsPlaceholderName(fullName) then
                roster.aliases[fullName] = fullName
                if type(entry.unit) == "string" and entry.unit ~= "" then
                    roster.units[fullName] = entry.unit
                end
                if shortName and shortName ~= fullName and not Core.IsPlaceholderName(shortName) then
                    local owner = shortOwners[shortName]
                    if owner == nil then
                        shortOwners[shortName] = fullName
                    elseif owner ~= fullName then
                        shortOwners[shortName] = false
                        roster.ambiguous[shortName] = true
                    end
                end
            end
        end
    end

    for shortName, fullName in pairs(shortOwners) do
        if type(fullName) == "string" and not roster.ambiguous[shortName] then
            roster.aliases[shortName] = fullName
        end
    end
    return roster
end

function Core.ResolveRosterName(candidate, roster)
    return canonicalRosterName(candidate, roster)
end

function Core.GetRosterUnit(roster, name)
    if type(roster) ~= "table" then
        return nil
    end
    local canonical = canonicalRosterName(name, roster)
    if type(roster.units) == "table" then
        return canonical and roster.units[canonical] or nil
    end
    return canonical and roster[canonical] or nil
end

local function appendCandidate(list, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
        return
    end
    list[#list + 1] = value
    seen[value] = true
end

local function escapePatternChar(char)
    if char:find("[%(%).%%%+%-%*%?%[%]%^%$]", 1, false) then
        return "%" .. char
    end
    return char
end

local function lootFormatToPattern(formatText, captureFirstString)
    if type(formatText) ~= "string" or formatText == "" then
        return nil
    end

    local out = { "^" }
    local index = 1
    local capturedFirstString = false
    while index <= #formatText do
        local char = formatText:sub(index, index)
        local nextChar = formatText:sub(index + 1, index + 1)
        local position, positionalSpec = formatText:match("^%%(%d+)%$(%a)", index)
        if position and positionalSpec == "s" then
            if captureFirstString and tonumber(position) == 1 then
                out[#out + 1] = "(.+)"
            else
                out[#out + 1] = ".+"
            end
            index = index + #position + 3
        elseif position and positionalSpec == "d" then
            out[#out + 1] = "%d+"
            index = index + #position + 3
        elseif char == "%" and nextChar == "s" then
            if captureFirstString and not capturedFirstString then
                out[#out + 1] = "(.+)"
                capturedFirstString = true
            else
                out[#out + 1] = ".+"
            end
            index = index + 2
        elseif char == "%" and nextChar == "d" then
            out[#out + 1] = "%d+"
            index = index + 2
        else
            out[#out + 1] = escapePatternChar(char)
            index = index + 1
        end
    end
    return table.concat(out)
end

local function isItemLink(link)
    return type(link) == "string" and link:find("|Hitem:", 1, true) ~= nil
end

local function isValidClassID(classID)
    local number = tonumber(classID)
    return number == 2 or number == 4
end

local function isVisibleQuality(quality, minQuality)
    local number = tonumber(quality)
    return number ~= nil and number >= minQuality
end

function Core.FontPathKey(fontPath)
    if type(fontPath) ~= "string" then
        return nil
    end
    return (fontPath:gsub("/", "\\"):lower())
end

function Core.SameFontPath(left, right)
    local leftKey = Core.FontPathKey(left)
    local rightKey = Core.FontPathKey(right)
    return leftKey ~= nil and rightKey ~= nil and leftKey == rightKey
end

function Core.IsBlizzardFontPath(fontPath)
    local key = Core.FontPathKey(fontPath)
    return key ~= nil and key:sub(1, 6) == "fonts\\"
end

function Core.LocaleAwareDefaultFont(standardTextFont)
    if Core.IsBlizzardFontPath(standardTextFont) then
        return standardTextFont
    end
    return DEFAULT_FONT
end

function Core.GetDefaultFont()
    return DEFAULT_FONT
end

function Core.GetLanguageOption(value)
    for index = 1, #LANGUAGE_OPTIONS do
        if LANGUAGE_OPTIONS[index].value == value then
            return LANGUAGE_OPTIONS[index]
        end
    end
    return nil
end

function Core.GetLanguageOptions()
    return copyList(LANGUAGE_OPTIONS)
end

function Core.NormalizeForceLocale(value)
    if Core.GetLanguageOption(value) then
        return value
    end
    return "auto"
end

function Core.ResolveActiveLocale(forceLocale, clientLocale)
    local force = Core.NormalizeForceLocale(forceLocale)
    local client = Core.GetLanguageOption(clientLocale) and clientLocale or "enUS"
    if force == "auto" then
        return client
    end
    return force
end

function Core.GetLocaleGlyphRequirement(locale)
    return LOCALE_GLYPH_REQ[locale] or GLYPH_LATIN
end

function Core.GetTextGlyphRequirement(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    -- WHY: WoW Lua is byte-based; this only detects UTF-8 Cyrillic lead bytes
    -- and does not slice or transform the user-visible text.
    if text:find(CYRILLIC_UTF8_LEAD_PATTERN) then
        return GLYPH_CYR
    end
    return nil
end

function Core.GetLocaleLabel(key, locale)
    local labels = LABELS_BY_LOCALE[locale] or LABELS_BY_LOCALE.enUS
    return labels[key] or LABELS_BY_LOCALE.enUS[key] or key
end

function Core.GetRowStatusText(row, locale)
    local key, seconds = resolveRowStatus(row, true)
    local label = Core.GetLocaleLabel(key, locale)
    if key == "auto_pending" then
        local ok, formatted = pcall(string.format, label, math.max(0, math.floor(tonumber(seconds) or 0)))
        if ok then
            return formatted
        end
    end
    return label
end

function Core.GetBlizzardFonts(clientLocale)
    local fonts = {}
    for index = 1, #BLIZZARD_SHIPPED_FONTS do
        local font = BLIZZARD_SHIPPED_FONTS[index]
        if font.locale == nil or font.locale == clientLocale then
            fonts[#fonts + 1] = {
                name = font.name,
                path = font.path,
            }
        end
    end
    return fonts
end

function Core.FontSupports(fontPath, glyph, clientLocale)
    if fontPath == nil then
        return glyph == GLYPH_LATIN
    end

    local key = Core.FontPathKey(fontPath)
    if not key then
        return glyph == GLYPH_LATIN
    end

    local frizKey = Core.FontPathKey(DEFAULT_FONT)
    local entry
    if key == frizKey then
        entry = clientLocale == "ruRU" and { GLYPH_LATIN, GLYPH_CYR } or { GLYPH_LATIN }
    else
        entry = FONT_GLYPH_SUPPORT[key]
    end
    if not entry then
        local lowerName = (fontPath:match("[^\\/]+$") or fontPath):lower()
        for index = 1, #FONT_GLYPH_PATTERNS do
            local pattern = FONT_GLYPH_PATTERNS[index]
            if lowerName:find(pattern.pattern) then
                entry = pattern.glyphs
                FONT_GLYPH_SUPPORT[key] = entry
                break
            end
        end
    end
    if not entry then
        return glyph == GLYPH_LATIN
    end
    for index = 1, #entry do
        if entry[index] == glyph then
            return true
        end
    end
    return false
end

function Core.FindCompatibleFont(currentFont, glyph, fonts, clientLocale)
    if Core.FontSupports(currentFont, glyph, clientLocale) then
        return currentFont
    end

    fonts = type(fonts) == "table" and fonts or {}
    for index = 1, #fonts do
        local font = fonts[index]
        if type(font) == "table" and Core.FontSupports(font.path, glyph, clientLocale) then
            return font.path
        end
    end

    local blizzardFonts = Core.GetBlizzardFonts(clientLocale)
    for index = 1, #blizzardFonts do
        if Core.FontSupports(blizzardFonts[index].path, glyph, clientLocale) then
            return blizzardFonts[index].path
        end
    end
    return currentFont or DEFAULT_FONT
end

function Core.NormalizeSettings(saved)
    saved = type(saved) == "table" and saved or {}

    local settings = {}
    settings.autoWhisper = saved.autoWhisper == true
    settings.debug = saved.debug == true
    settings.whisperTemplate = Core.NormalizeWhisperTemplate(saved.whisperTemplate)
    local minDelay = asNumber(saved.minDelay, DEFAULTS.minDelay)
    local maxDelay = asNumber(saved.maxDelay, DEFAULTS.maxDelay)
    if minDelay < 0 or minDelay > DEFAULTS.maxDelay or maxDelay < minDelay or maxDelay > DEFAULTS.maxDelay then
        minDelay = DEFAULTS.minDelay
        maxDelay = DEFAULTS.maxDelay
    end
    settings.minDelay = minDelay
    settings.maxDelay = maxDelay
    settings.autoDelay = clamp(asNumber(saved.autoDelay, DEFAULTS.autoDelay), settings.minDelay, settings.maxDelay)
    settings.maxHistoryGroups = math.max(1, math.floor(asNumber(saved.maxHistoryGroups, DEFAULTS.maxHistoryGroups)))
    settings.maxSessionRows = math.max(1, math.floor(asNumber(saved.maxSessionRows, DEFAULTS.maxSessionRows)))
    settings.minQuality = math.max(0, math.floor(asNumber(saved.minQuality, DEFAULTS.minQuality)))
    settings.forceLocale = Core.NormalizeForceLocale(saved.forceLocale)
    settings.font = type(saved.font) == "string" and saved.font ~= "" and saved.font or DEFAULTS.font
    settings.fontSize = math.floor(clamp(asNumber(saved.fontSize, DEFAULTS.fontSize), DEFAULTS.minFontSize, DEFAULTS.maxFontSize) + 0.5)
    settings.fontBeforeAutoSwitch = type(saved.fontBeforeAutoSwitch) == "string" and saved.fontBeforeAutoSwitch ~= "" and saved.fontBeforeAutoSwitch or nil
    return settings
end

function Core.ResolveFontSize(baseSize, selectedSize)
    local base = asNumber(baseSize, DEFAULTS.fontSize)
    local selected = math.floor(clamp(asNumber(selectedSize, DEFAULTS.fontSize), DEFAULTS.minFontSize, DEFAULTS.maxFontSize) + 0.5)
    local resolved = selected + (base - DEFAULTS.fontSize)
    return math.floor(clamp(resolved, DEFAULTS.minFontSize, DEFAULTS.maxFontSize) + 0.5)
end

function Core.NormalizeSavedRows(rows, limit)
    return snapshotRowsForSave(rows, limit or DEFAULTS.maxSessionRows)
end

function Core.NormalizeSavedAllRows(rows, fallbackRows, limit)
    return snapshotRowsForSaveWithFallback(rows, fallbackRows, limit or DEFAULTS.maxSessionRows)
end

function Core.SnapshotRowsForSave(rows, limit)
    return snapshotRowsForSave(rows, limit or DEFAULTS.maxSessionRows)
end

function Core.SnapshotHistoryForSave(history, limit, rowLimit)
    local saved = {}
    local perGroupRowLimit = rowLimit or DEFAULTS.maxSessionRows
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" then
                local savedGroup = copyPrimitiveFields(group, PERSISTED_GROUP_KEYS)
                savedGroup.rows = snapshotRowsForSave(group.rows, perGroupRowLimit)
                savedGroup.allRows = snapshotRowsForSaveWithFallback(group.allRows, group.rows, perGroupRowLimit)
                saved[#saved + 1] = savedGroup
            end
        end
    end
    pruneListEnd(saved, limit or DEFAULTS.maxHistoryGroups)
    return saved
end

function Core.GetNewestRowsFirst(rows, limit)
    local result = {}
    if type(rows) ~= "table" then
        return result
    end
    limit = math.max(1, math.floor(asNumber(limit, #rows)))
    for index = #rows, 1, -1 do
        local row = rows[index]
        if type(row) == "table" then
            result[#result + 1] = row
            if #result >= limit then
                break
            end
        end
    end
    return result
end

function Core.StoreEquipmentCache(cache, names, equippedByLoc, timestamp)
    if type(cache) ~= "table" then
        return false
    end

    local nameList = {}
    if type(names) == "string" then
        nameList[1] = names
    elseif type(names) == "table" then
        for index = 1, #names do
            nameList[#nameList + 1] = names[index]
        end
    end

    local slots, slotCount = copyEquipmentSlots(equippedByLoc)
    if slotCount == 0 then
        for index = 1, #nameList do
            local name = nameList[index]
            if type(name) == "string" and name ~= "" then
                cache[name] = nil
            end
        end
        return false
    end

    local wrote = false
    for index = 1, #nameList do
        local name = nameList[index]
        if type(name) == "string" and name ~= "" then
            cache[name] = {
                slots = slots,
                timestamp = timestamp,
            }
            wrote = true
        end
    end
    return wrote
end

function Core.GetCachedEquippedText(cache, name, equipLoc, now, maxAge)
    if type(cache) ~= "table" or type(name) ~= "string" or name == "" or type(equipLoc) ~= "string" or equipLoc == "" then
        return nil
    end

    local entry = cache[name]
    if type(entry) ~= "table" or type(entry.slots) ~= "table" then
        return nil
    end
    if now ~= nil or maxAge ~= nil then
        now = tonumber(now)
        maxAge = tonumber(maxAge)
        if not now or not maxAge or maxAge < 0 or type(entry.timestamp) ~= "number" then
            return nil
        end
        local age = now - entry.timestamp
        if age < 0 or age > maxAge then
            return nil
        end
    end

    local text = entry.slots[equipLoc]
    if type(text) == "string" and text ~= "" then
        return text
    end
    return nil
end

function Core.AddPendingItemWaiter(pending, itemLink, waiter)
    if type(pending) ~= "table" or type(itemLink) ~= "string" or itemLink == "" or type(waiter) ~= "table" then
        return nil, false
    end

    local bucket = pending[itemLink]
    local created = false
    if type(bucket) ~= "table" then
        bucket = {
            itemLink = itemLink,
            waiters = {},
            attempts = 0,
            loadRequested = false,
            generation = waiter.generation,
        }
        pending[itemLink] = bucket
        created = true
    end
    bucket.waiters = type(bucket.waiters) == "table" and bucket.waiters or {}
    bucket.waiters[#bucket.waiters + 1] = waiter
    return bucket, created
end

function Core.DrainPendingItemWaiters(pending, itemLink, generation)
    if type(pending) ~= "table" or type(itemLink) ~= "string" or itemLink == "" then
        return {}
    end

    local bucket = pending[itemLink]
    if type(bucket) ~= "table" then
        return {}
    end
    if generation ~= nil and bucket.generation ~= generation then
        return {}
    end

    pending[itemLink] = nil
    local waiters = type(bucket.waiters) == "table" and bucket.waiters or {}
    bucket.waiters = {}
    return waiters
end

function Core.FindRosterNameInMessage(message, roster, playerName)
    if type(message) ~= "string" or type(roster) ~= "table" then
        return nil
    end

    local candidates = {}
    local seen = {}
    for target, label in message:gmatch("|Hplayer:([^:|]+)[^|]*|h%[([^%]]+)%]|h") do
        appendCandidate(candidates, seen, target)
        appendCandidate(candidates, seen, label)
    end

    local plainMessage = stripRosterSearchText(message)
    if plainMessage then
        local names = sortedRosterNames(roster)
        for index = 1, #names do
            local name = names[index]
            if findPlainName(plainMessage, name) then
                appendCandidate(candidates, seen, name)
            end
        end
    end

    for index = 1, #candidates do
        local name = canonicalRosterName(candidates[index], roster)
        if name and not isSelfLootName(name, playerName) then
            return name
        end
    end
    return nil
end

function Core.RecordDiagnostic(log, entry, limit)
    if type(log) ~= "table" then
        return nil
    end
    limit = math.max(1, math.floor(asNumber(limit, 20)))
    entry = type(entry) == "table" and entry or {}

    local saved = {}
    for key, value in pairs(entry) do
        local valueType = type(value)
        if valueType == "string" or valueType == "boolean" or (valueType == "number" and isFiniteNumber(value)) then
            saved[key] = value
        end
    end

    table.insert(log, 1, saved)
    while #log > limit do
        table.remove(log)
    end
    return saved
end

function Core.CreateLootMessagePatterns(formats)
    formats = type(formats) == "table" and formats or {}
    local patterns = {
        self = {},
        other = {},
        bonusSelf = {},
        bonusOther = {},
    }

    local selfPattern = lootFormatToPattern(formats.lootSelf, false)
    if selfPattern then
        patterns.self[#patterns.self + 1] = selfPattern
    end
    local selfMultiplePattern = lootFormatToPattern(formats.lootSelfMultiple, false)
    if selfMultiplePattern then
        patterns.self[#patterns.self + 1] = selfMultiplePattern
    end
    local otherPattern = lootFormatToPattern(formats.lootOther, true)
    if otherPattern then
        patterns.other[#patterns.other + 1] = otherPattern
    end
    local otherMultiplePattern = lootFormatToPattern(formats.lootOtherMultiple, true)
    if otherMultiplePattern then
        patterns.other[#patterns.other + 1] = otherMultiplePattern
    end
    local bonusSelfPattern = lootFormatToPattern(formats.bonusSelf, false)
    if bonusSelfPattern then
        patterns.bonusSelf[#patterns.bonusSelf + 1] = bonusSelfPattern
    end
    local bonusOtherPattern = lootFormatToPattern(formats.bonusOther, true)
    if bonusOtherPattern then
        patterns.bonusOther[#patterns.bonusOther + 1] = bonusOtherPattern
    end

    return patterns
end

function Core.ResolveLootMessageLooter(message, patterns, playerName)
    if type(message) ~= "string" or type(patterns) ~= "table" then
        return nil
    end

    local bonusSelfPatterns = type(patterns.bonusSelf) == "table" and patterns.bonusSelf or {}
    for index = 1, #bonusSelfPatterns do
        if message:match(bonusSelfPatterns[index]) then
            return {
                name = playerName,
                isSelf = true,
                lootSource = "bonus_roll",
            }
        end
    end

    local bonusOtherPatterns = type(patterns.bonusOther) == "table" and patterns.bonusOther or {}
    for index = 1, #bonusOtherPatterns do
        local name = message:match(bonusOtherPatterns[index])
        if type(name) == "string" and name ~= "" then
            return {
                name = name,
                isSelf = false,
                lootSource = "bonus_roll",
            }
        end
    end

    local selfPatterns = type(patterns.self) == "table" and patterns.self or {}
    for index = 1, #selfPatterns do
        if message:match(selfPatterns[index]) then
            return {
                name = playerName,
                isSelf = true,
            }
        end
    end

    local otherPatterns = type(patterns.other) == "table" and patterns.other or {}
    for index = 1, #otherPatterns do
        local name = message:match(otherPatterns[index])
        if type(name) == "string" and name ~= "" then
            return {
                name = name,
                isSelf = false,
            }
        end
    end

    return nil
end

function Core.ExtractItemID(link)
    if type(link) ~= "string" then
        return nil
    end
    local itemID = link:match("item:(%d+)")
    return tonumber(itemID)
end

function Core.BuildItemMetadata(itemLink, instant, detailed)
    instant = type(instant) == "table" and instant or {}
    detailed = type(detailed) == "table" and detailed or {}

    local itemID = instant.itemID or detailed.itemID
    local quality = detailed.quality
    local equipLoc = detailed.equipLoc or instant.equipLoc
    if itemID == nil or quality == nil or equipLoc == nil then
        return nil
    end
    local playerCanEquip
    if type(detailed.playerCanEquip) == "boolean" then
        playerCanEquip = detailed.playerCanEquip
    end

    return {
        itemID = itemID,
        name = detailed.name,
        link = detailed.link or itemLink,
        quality = quality,
        itemLevel = detailed.itemLevel,
        classID = detailed.classID or instant.classID,
        subclassID = detailed.subclassID or instant.subclassID,
        equipLoc = equipLoc,
        bindType = detailed.bindType,
        tradeTimeRemaining = detailed.tradeTimeRemaining == true,
        playerCanEquip = playerCanEquip,
        isCraftingReagent = detailed.isCraftingReagent == true,
    }
end

function Core.ResolveDropEncounterName(currentEncounterName, recentEncounterName, recentEncounterEndedAt, now, graceSeconds)
    if type(currentEncounterName) == "string" and currentEncounterName ~= "" then
        return currentEncounterName
    end
    if type(recentEncounterName) ~= "string" or recentEncounterName == "" then
        return nil
    end
    if type(recentEncounterEndedAt) ~= "number" or type(now) ~= "number" or type(graceSeconds) ~= "number" then
        return nil
    end
    local age = now - recentEncounterEndedAt
    if age >= 0 and age <= graceSeconds then
        return recentEncounterName
    end
    return nil
end

function Core.FirstRowEncounterName(rows)
    if type(rows) ~= "table" then
        return nil
    end
    for index = 1, #rows do
        local row = rows[index]
        if type(row) == "table" and type(row.encounterName) == "string" and row.encounterName ~= "" then
            return row.encounterName
        end
    end
    return nil
end

function Core.ClassifyGearLoot(item, looter, settings)
    settings = Core.NormalizeSettings(settings or {})

    if type(item) ~= "table" then
        return { visible = false, reason = "missing_item" }
    end
    if not isItemLink(item.link) then
        return { visible = false, reason = "not_item_link" }
    end
    if looter == nil or looter == "" then
        return { visible = false, reason = "missing_looter" }
    end
    if item.isCraftingReagent == true then
        return { visible = false, reason = "crafting_reagent" }
    end
    if not isVisibleQuality(item.quality, settings.minQuality) then
        return { visible = false, reason = "low_quality" }
    end
    if not isValidClassID(item.classID or item.itemClassID) then
        return { visible = false, reason = "not_equipment_class" }
    end
    if VALID_EQUIP_LOCS[item.equipLoc or ""] ~= true then
        return { visible = false, reason = "not_equipment_slot" }
    end

    return {
        visible = true,
        reason = "gear_drop",
    }
end

function Core.ClassifyTradeCandidate(item, looter, playerName, settings)
    local gear = Core.ClassifyGearLoot(item, looter, settings)
    if not gear.visible then
        return gear
    end
    if item.lootSource == "bonus_roll" then
        return { visible = false, reason = "bonus_roll" }
    end
    if isSelfLootName(looter, playerName) then
        return { visible = false, reason = "self_loot" }
    end
    if item.canTrade == false then
        return { visible = false, reason = "not_tradeable" }
    end
    local bindType = tonumber(item.bindType)
    if bindType == nil and item.tradeTimeRemaining ~= true and item.canTrade ~= true then
        return { visible = false, reason = "bind_unknown" }
    end
    if bindType == 1 and item.tradeTimeRemaining ~= true then
        return { visible = false, reason = "bind_on_pickup" }
    end
    if bindType == 4 then
        return { visible = false, reason = "quest_bound" }
    end
    if item.playerCanEquip ~= true then
        return { visible = false, reason = item.playerCanEquip == false and "player_cannot_equip" or "player_equip_unknown" }
    end

    return {
        visible = true,
        reason = "trade_candidate",
        tradeGuaranteed = item.canTrade == true or item.tradeTimeRemaining == true,
    }
end

function Core.CreateState(settings)
    local normalized = Core.NormalizeSettings(settings or {})
    return {
        settings = normalized,
        currentRows = {},
        allRows = {},
        sessionRows = {},
        sessionAllRows = {},
        history = {},
        selectedView = "current",
        nextRowID = 1,
    }
end

function Core.AddVisibleRow(state, row, askable)
    if type(state) ~= "table" or type(row) ~= "table" then
        return nil
    end

    local saved = {}
    for key, value in pairs(row) do
        saved[key] = value
    end
    if saved.id == nil then
        saved.id = "row" .. tostring(state.nextRowID or 1)
        state.nextRowID = (state.nextRowID or 1) + 1
    end
    saved.askable = askable ~= false

    state.allRows = state.allRows or {}
    state.sessionAllRows = state.sessionAllRows or {}
    state.allRows[#state.allRows + 1] = saved
    state.sessionAllRows[#state.sessionAllRows + 1] = saved
    local limit = state.settings and state.settings.maxSessionRows or DEFAULTS.maxSessionRows
    pruneListStart(state.sessionAllRows, limit)

    if saved.askable then
        state.currentRows[#state.currentRows + 1] = saved
        state.sessionRows[#state.sessionRows + 1] = saved
    end
    pruneListStart(state.sessionRows, limit)
    return saved
end

local function localizedDropNoun(locale, dropCount)
    local count = math.abs(math.floor(asNumber(dropCount, 0)))
    if locale == "ruRU" then
        local mod10 = count % 10
        local mod100 = count % 100
        if mod10 == 1 and mod100 ~= 11 then
            return Core.GetLocaleLabel("drop_one", locale)
        end
        if mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14) then
            return Core.GetLocaleLabel("drop_few", locale)
        end
        return Core.GetLocaleLabel("drop_many", locale)
    end
    return Core.GetLocaleLabel(dropCount == 1 and "drop_one" or "drop_many", locale)
end

local function groupTitle(meta, dropCount)
    local instanceName = type(meta.instanceName) == "string" and meta.instanceName ~= "" and meta.instanceName or nil
    local encounterName = type(meta.encounterName) == "string" and meta.encounterName ~= "" and meta.encounterName or nil
    local title = type(meta.title) == "string" and meta.title ~= "" and meta.title or nil
    local locale = type(meta.locale) == "string" and meta.locale ~= "" and meta.locale or "enUS"

    local base
    if instanceName and encounterName then
        base = instanceName .. " - " .. encounterName
    elseif instanceName then
        base = instanceName .. " - " .. Core.GetLocaleLabel("Run", locale)
    elseif encounterName then
        base = encounterName
    else
        base = title or Core.GetLocaleLabel("Loot", locale)
    end

    local noun = localizedDropNoun(locale, dropCount)
    return base .. " (" .. tostring(dropCount) .. " " .. noun .. ")"
end

function Core.CompleteCurrentGroup(state, groupMeta)
    if type(state) ~= "table" then
        return nil
    end
    state.currentRows = type(state.currentRows) == "table" and state.currentRows or {}
    state.allRows = type(state.allRows) == "table" and state.allRows or {}
    if #state.currentRows == 0 and #state.allRows == 0 then
        return nil
    end

    groupMeta = type(groupMeta) == "table" and groupMeta or {}
    local dropCount = #state.allRows > 0 and #state.allRows or #state.currentRows
    local rowLimit = state.settings and state.settings.maxSessionRows or DEFAULTS.maxSessionRows
    local rows = copyList(state.currentRows)
    local allRows = copyList(state.allRows)
    pruneListStart(rows, rowLimit)
    pruneListStart(allRows, rowLimit)

    local group = {
        title = groupTitle(groupMeta, dropCount),
        instanceName = groupMeta.instanceName,
        encounterName = groupMeta.encounterName,
        startedAt = groupMeta.startedAt,
        endedAt = groupMeta.endedAt,
        rows = rows,
        allRows = allRows,
    }

    table.insert(state.history, 1, group)
    local limit = state.settings and state.settings.maxHistoryGroups or DEFAULTS.maxHistoryGroups
    while #state.history > limit do
        table.remove(state.history)
    end
    state.currentRows = {}
    state.allRows = {}
    return group
end

function Core.GetAutoWhisperDecision(settings, row)
    settings = Core.NormalizeSettings(settings or {})
    if settings.autoWhisper ~= true then
        return { shouldSchedule = false, reason = "disabled" }
    end
    if type(row) ~= "table" then
        return { shouldSchedule = false, reason = "missing_row" }
    end
    if row.askable == false then
        return { shouldSchedule = false, reason = "not_askable" }
    end
    if row.unsafe == true then
        return { shouldSchedule = false, reason = "unsafe" }
    end
    if row.looter == nil or row.looter == "" or row.itemLink == nil or row.itemLink == "" then
        return { shouldSchedule = false, reason = "incomplete_row" }
    end
    if row.manualWhispered == true or row.autoWhispered == true or row.pendingAutoWhisper == true or row.whisperInFlight == true then
        return { shouldSchedule = false, reason = "already_handled" }
    end
    return {
        shouldSchedule = true,
        reason = "eligible",
        delay = settings.autoDelay,
    }
end

function Core.GetWhisperButtonState(selectedTab, selectedView, row)
    local state = {
        visible = false,
        enabled = false,
        text = "Ask",
    }
    if selectedTab ~= "askable" or selectedView ~= "current" or type(row) ~= "table" or row.askable == false then
        return state
    end

    state.visible = true
    if row.whisperInFlight == true then
        state.text = "Sending"
        return state
    end
    if row.manualWhispered == true or row.autoWhispered == true then
        state.text = "Sent"
        return state
    end

    state.enabled = true
    return state
end

function Core.ShouldAutoShowWindow(row)
    return type(row) == "table" and row.itemLink ~= nil and row.itemLink ~= ""
end

function Core.GetAutoShowTabForRow(state, row)
    if type(row) ~= "table" then
        return "askable"
    end
    if row.askable ~= false then
        return "askable"
    end
    if type(state) == "table" and type(state.currentRows) == "table" and #state.currentRows > 0 then
        return "askable"
    end
    return "all"
end

_G.DoYouNeedItCore = Core
