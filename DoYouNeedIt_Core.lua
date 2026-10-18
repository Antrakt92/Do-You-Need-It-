local Core = {}

Core.VERSION = "1.0.0"

local GLYPH_LATIN = "LATIN"
local GLYPH_CYR = "CYR"
local GLYPH_HANGUL = "HANGUL"
local GLYPH_HANS = "HANS"
local GLYPH_HANT = "HANT"

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local DEFAULT_WHISPER_TEMPLATE = "Hey, do you need {item}?"
local MAX_WHISPER_TEMPLATE_LENGTH = 160
local MAX_CHAT_VISIBLE_BYTES = 255
local MAX_CHAT_INVISIBLE_BYTES = 1023
local MAX_CHAT_BYTES = 1280

Core.DEFAULT_WHISPER_TEMPLATE = DEFAULT_WHISPER_TEMPLATE
Core.MAX_WHISPER_TEMPLATE_LENGTH = MAX_WHISPER_TEMPLATE_LENGTH

-- Bind types exposed by the item API: 1 pickup, 2 equip, 3 use, 4 quest.
-- 0 (unbound) stays numeric at use sites: it shares the likely set below
-- without being a named bind kind of its own.
Core.BIND_ON_PICKUP = 1
Core.BIND_ON_EQUIP = 2
Core.BIND_ON_USE = 3
Core.BIND_QUEST = 4

Core.LIKELY_TRADE_BINDTYPES = {
    [0] = true,
    [Core.BIND_ON_EQUIP] = true,
    [Core.BIND_ON_USE] = true,
}

-- Transfer-status text colors (UI-free data; rendering stays in main).
Core.TRADE_STATUS_COLORS = {
    trade_confirmed = { 0.25, 1.00, 0.35 },
    trade_likely = { 0.75, 0.90, 0.25 },
    trade_no = { 1.00, 0.35, 0.30 },
    trade_unknown = { 1.00, 0.75, 0.20 },
}

-- Sub-second repeat streaks are suspected chat throttling, not delivery.
Core.WHISPER_REPEAT_WINDOW = 1
Core.WHISPER_REPEAT_STREAK_LIMIT = 2

local LANGUAGE_OPTIONS = {
    { value = "auto", label = nil },
    { value = "enUS", label = "English" },
    { value = "deDE", label = "Deutsch" },
    { value = "esES", label = "Español (España)", compactLabel = "Español ES" },
    { value = "esMX", label = "Español (Latinoamérica)", compactLabel = "Español LA" },
    { value = "frFR", label = "Français" },
    { value = "itIT", label = "Italiano" },
    { value = "ptBR", label = "Português (Brasil)" },
    { value = "koKR", label = "한국어", compactLabel = "한국어" },
    { value = "ruRU", label = "Русский" },
    { value = "zhCN", label = "简体中文", compactLabel = "简体中文" },
    { value = "zhTW", label = "繁體中文", compactLabel = "繁體中文" },
}

local LOCALE_GLYPH_REQ = {
    enUS = GLYPH_LATIN, deDE = GLYPH_LATIN, esES = GLYPH_LATIN, esMX = GLYPH_LATIN,
    frFR = GLYPH_LATIN, itIT = GLYPH_LATIN, ptBR = GLYPH_LATIN,
    ruRU = GLYPH_CYR, koKR = GLYPH_HANGUL, zhCN = GLYPH_HANS, zhTW = GLYPH_HANT,
}

local FONT_GLYPH_SUPPORT = {}
local bundledFonts = {}
local bundledByPath = {}
local bundledByFile = {}
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
addFontGlyphSupport("Fonts\\FRIZQT__.TTF", { GLYPH_LATIN })
addFontGlyphSupport("Fonts\\K_Damage.TTF", { GLYPH_CYR, GLYPH_HANGUL })
addFontGlyphSupport("Fonts\\K_Pagetext.TTF", { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANGUL })
addFontGlyphSupport("Fonts\\MORPHEUS.TTF", { GLYPH_LATIN })
addFontGlyphSupport("Fonts\\MORPHEUS_CYR.TTF", { GLYPH_LATIN, GLYPH_CYR })
addFontGlyphSupport("Fonts\\NIM_____.ttf", { GLYPH_LATIN, GLYPH_CYR })
addFontGlyphSupport("Fonts\\SKURRI.TTF", { GLYPH_LATIN })
addFontGlyphSupport("Fonts\\SKURRI_CYR.TTF", { GLYPH_LATIN, GLYPH_CYR })

local FONT_GLYPH_PATTERNS = {
    { pattern = "noto.*cjk", glyphs = { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS, GLYPH_HANT, GLYPH_HANGUL } },
    { pattern = "^sourcehan.-cn[%-.]", glyphs = { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANS } },
    { pattern = "^sourcehan.-tw[%-.]", glyphs = { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANT } },
    { pattern = "^sourcehan.-jp[%-.]", glyphs = { GLYPH_LATIN, GLYPH_CYR } },
    { pattern = "^sourcehan.-kr[%-.]", glyphs = { GLYPH_LATIN, GLYPH_CYR, GLYPH_HANGUL } },
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
-- Hiragana/katakana share lead E3 with CJK Extension A; Unified Ideographs
-- span leads E4-E9. Lead bytes cannot tell Simplified from Traditional apart,
-- so foreign loot text uses HANS as a best-effort CJK hint. The language picker
-- and localized Settings use explicit script and regional coverage instead.
local CJK_UTF8_LEAD_PATTERN = "[\227-\233]"
-- Hangul syllables U+AC00-U+D7A3 encode with leads EA-ED.
local HANGUL_UTF8_LEAD_PATTERN = "[\234-\237]"

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
        ["Back"] = "Back",
        ["Askable"] = "Askable",
        ["All Gear"] = "All Gear",
        ["Current"] = "Current",
        ["This Session"] = "This Session",
        ["History"] = "History",
        ["Run"] = "Run",
        ["Loot"] = "Loot",
        ["You"] = "You",
        ["Auto whisper"] = "Auto whisper",
        ["Delay"] = "Delay",
        ["Low"] = "Low",
        ["High"] = "High",
        ["Language:"] = "Language:",
        ["Font:"] = "Font:",
        ["Font Size:"] = "Font Size:",
        ["Whisper text:"] = "Whisper text:",
        ["Whispers"] = "Whispers",
        ["Appearance"] = "Appearance",
        ["Use {item} for the dropped item."] = "Use {item} for the dropped item.",
        ["Only eligible new drops. Off by default."] = "Only eligible new drops. Off by default.",
        ["Waiting for group loot"] = "Waiting for group loot",
        ["Gear from your dungeon or raid will appear here."] = "Gear from your dungeon or raid will appear here.",
        ["Scroll to review older drops"] = "Scroll to review older drops",
        ["Reset Position"] = "Reset Position",
        ["New loot"] = "New loot",
        ["Reset"] = "Reset",
        ["Auto (current: %s)"] = "Auto (current: %s)",
        ["No askable gear drops in this view."] = "No askable gear drops in this view.",
        ["No gear drops in this view."] = "No gear drops in this view.",
        ["Player"] = "Player",
        ["Dropped"] = "Dropped",
        ["Equipped now"] = "Equipped now",
        ["Trade"] = "Trade",
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
        ["trade_confirmed"] = "Trade: yes",
        ["trade_likely"] = "Trade: likely",
        ["trade_no"] = "Trade: no",
        ["trade_unknown"] = "Trade: unknown",
        ["trade_confirmed_help"] = "A trade timer was detected when this drop was processed. It can still expire.",
        ["trade_likely_help"] = "The binding type or inspected slot item level indicates that this item is likely transferable. The timer can expire, and equipping or using it can bind it.",
        ["trade_no_help"] = "The available item data says this loot cannot be transferred.",
        ["trade_unknown_help"] = "WoW does not expose another player's personal-loot eligibility. Ask the looter to confirm.",
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
        ["whisper_too_long"] = "shorten whisper text",
        ["whisper_too_long_help"] = "The whisper is too long after adding the item link. Shorten the text in Settings or use fewer {item} placeholders.",
        ["whisper_invalid"] = "check whisper text",
        ["whisper_invalid_help"] = "Remove line breaks or control characters from the whisper text in Settings.",
        ["test row"] = "test row",
        ["test_row"] = "test row",
        ["bind_on_pickup"] = "bind on pickup",
        ["warband_bound"] = "warband bound",
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
        ["Back"] = "Назад",
        ["Askable"] = "Можно спросить",
        ["All Gear"] = "Весь шмот",
        ["Current"] = "Текущий",
        ["This Session"] = "Эта сессия",
        ["History"] = "История",
        ["Run"] = "Проход",
        ["Loot"] = "Лут",
        ["You"] = "Вы",
        ["Auto whisper"] = "Авто-виспер",
        ["Delay"] = "Задержка",
        ["Low"] = "Мин.",
        ["High"] = "Макс.",
        ["Language:"] = "Язык:",
        ["Font:"] = "Шрифт:",
        ["Font Size:"] = "Размер шрифта:",
        ["Whisper text:"] = "Текст виспера:",
        ["Whispers"] = "Висперы",
        ["Appearance"] = "Оформление",
        ["Use {item} for the dropped item."] = "{item} заменяется ссылкой на выпавший предмет.",
        ["Only eligible new drops. Off by default."] = "Только подходящий новый лут. По умолчанию выключено.",
        ["Waiting for group loot"] = "Ждём групповой лут",
        ["Gear from your dungeon or raid will appear here."] = "Здесь появится экипировка из вашего подземелья или рейда.",
        ["Scroll to review older drops"] = "Прокрутите список, чтобы увидеть прошлый лут",
        ["Reset Position"] = "Сброс позиции",
        ["New loot"] = "Новый лут",
        ["Reset"] = "Сброс",
        ["Auto (current: %s)"] = "Авто (сейчас: %s)",
        ["No askable gear drops in this view."] = "Нет шмота, о котором стоит спрашивать.",
        ["No gear drops in this view."] = "Нет шмота в этом виде.",
        ["Player"] = "Игрок",
        ["Dropped"] = "Выпало",
        ["Equipped now"] = "Надето сейчас",
        ["Trade"] = "Передача",
        -- "Спросить" (7 glyphs at button font 11) overflows the 48px whisper
        -- action button, so the Russian client deliberately keeps the short
        -- English label, matching the compact Sending/Sent states.
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
        ["trade_confirmed"] = "Передача: да",
        ["trade_likely"] = "Передача: вероятно",
        ["trade_no"] = "Передача: нет",
        ["trade_unknown"] = "Передача: неизвестно",
        ["trade_confirmed_help"] = "При обработке дропа был обнаружен таймер передачи. Он всё равно может истечь.",
        ["trade_likely_help"] = "Тип привязки или сравнение с надетым предметом указывает, что вещь, вероятно, можно передать. Таймер может истечь, а надевание или использование привяжет её.",
        ["trade_no_help"] = "Доступные данные о вещи указывают, что передать её нельзя.",
        ["trade_unknown_help"] = "WoW не раскрывает аддону возможность передачи чужого персонального лута. Нужно спросить владельца.",
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
        ["whisper_too_long"] = "сократите текст виспера",
        ["whisper_too_long_help"] = "После добавления ссылки на предмет виспер слишком длинный. Сократите текст в настройках или используйте меньше вставок {item}.",
        ["whisper_invalid"] = "проверьте текст виспера",
        ["whisper_invalid_help"] = "Уберите переносы строк и управляющие символы из текста виспера в настройках.",
        ["test row"] = "тест",
        ["test_row"] = "тест",
        ["bind_on_pickup"] = "персональный",
        ["warband_bound"] = "привязано к отряду",
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


-- Main-window and Settings labels share one vocabulary across locales.
local visibleLocaleKeys = { "Back", "Askable", "All Gear", "Current", "This Session", "History", "Run", "Loot", "You", "Whisper text:", "Whispers", "Appearance", "Use {item} for the dropped item.", "Only eligible new drops. Off by default.", "Waiting for group loot", "Gear from your dungeon or raid will appear here.", "Scroll to review older drops", "Reset Position", "New loot", "Reset", "Auto (current: %s)", "No askable gear drops in this view.", "No gear drops in this view.", "Player", "Dropped", "Equipped now", "Trade", "Ask", "Sent", "Sending", "Auto: off", "Auto: %ds", "Equipped: ", "Cached: ", "Equipped: unknown", "Equipped: checking...", "Equipped: unavailable", "trade_confirmed", "trade_likely", "trade_no", "trade_unknown", "drop_one", "drop_few", "drop_many" }
local visibleLocaleLabels = {
    deDE = { "Zurück", "Anfragbar", "Alle Ausrüstung", "Aktuell", "Diese Sitzung", "Verlauf", "Durchlauf", "Beute", "Du", "Flüstertext:", "Flüstern", "Darstellung", "Verwende {item} für den erhaltenen Gegenstand.", "Nur geeignete neue Beute. Standardmäßig aus.", "Warte auf Gruppenbeute", "Ausrüstung aus Dungeons oder Schlachtzügen erscheint hier.", "Scrollen, um ältere Beute anzusehen", "Position zurücksetzen", "Neue Beute", "Zurücksetzen", "Automatisch (aktuell: %s)", "Keine anfragbare Ausrüstung in dieser Ansicht.", "Keine Ausrüstung in dieser Ansicht.", "Spieler", "Erhalten", "Aktuell angelegt", "Handel", "Fragen", "Gesendet", "Wird gesendet", "Auto: aus", "Auto: %ds", "Angelegt: ", "Gespeichert: ", "Angelegt: unbekannt", "Angelegt: wird geprüft...", "Angelegt: nicht verfügbar", "Handel: ja", "Handel: wahrscheinlich", "Handel: nein", "Handel: unbekannt", "Gegenstand", "Gegenstände", "Gegenstände" },
    esES = { "Atrás", "Solicitables", "Todo el equipo", "Actual", "Esta sesión", "Historial", "Recorrido", "Botín", "Tú", "Texto del susurro:", "Susurros", "Apariencia", "Usa {item} para el objeto obtenido.", "Solo objetos nuevos aptos. Desactivado por defecto.", "Esperando botín del grupo", "Aquí aparecerá el equipo de tu mazmorra o banda.", "Desplázate para ver el botín anterior", "Restablecer posición", "Nuevo botín", "Restablecer", "Automático (actual: %s)", "No hay equipo que puedas solicitar en esta vista.", "No hay equipo en esta vista.", "Jugador", "Obtenido", "Equipo actual", "Intercambio", "Preguntar", "Enviado", "Enviando", "Auto: no", "Auto: %ds", "Equipado: ", "Guardado: ", "Equipado: desconocido", "Equipado: comprobando...", "Equipado: no disponible", "Intercambio: sí", "Intercambio: probable", "Intercambio: no", "Intercambio: desconocido", "objeto", "objetos", "objetos" },
    frFR = { "Retour", "Demandables", "Tout le butin", "Actuel", "Cette session", "Historique", "Sortie", "Butin", "Vous", "Texte du message :", "Messages privés", "Apparence", "Utilisez {item} pour l’objet obtenu.", "Nouveaux objets admissibles uniquement. Désactivé par défaut.", "En attente du butin du groupe", "L’équipement de votre donjon ou raid apparaîtra ici.", "Faites défiler pour voir les objets précédents", "Réinitialiser la position", "Nouveau butin", "Réinitialiser", "Auto (actuel : %s)", "Aucun équipement à demander dans cette vue.", "Aucun équipement dans cette vue.", "Joueur", "Obtenu", "Équipement actuel", "Échange", "Demander", "Envoyé", "Envoi en cours", "Auto : non", "Auto : %ds", "Équipé : ", "En cache : ", "Équipé : inconnu", "Équipé : vérification...", "Équipé : indisponible", "Échange : oui", "Échange : probable", "Échange : non", "Échange : inconnu", "objet", "objets", "objets" },
    itIT = { "Indietro", "Richiedibili", "Tutto l’equipaggiamento", "Attuale", "Questa sessione", "Cronologia", "Spedizione", "Bottino", "Tu", "Testo del sussurro:", "Sussurri", "Aspetto", "Usa {item} per l’oggetto ottenuto.", "Solo nuovi oggetti idonei. Disattivato per impostazione predefinita.", "In attesa del bottino del gruppo", "Qui apparirà l’equipaggiamento della spedizione o incursione.", "Scorri per vedere il bottino precedente", "Reimposta posizione", "Nuovo bottino", "Reimposta", "Auto (attuale: %s)", "Nessun equipaggiamento richiedibile in questa vista.", "Nessun equipaggiamento in questa vista.", "Giocatore", "Ottenuto", "Equipaggiato ora", "Scambio", "Chiedi", "Inviato", "Invio in corso", "Auto: no", "Auto: %ds", "Equipaggiato: ", "In memoria: ", "Equipaggiato: sconosciuto", "Equipaggiato: verifica...", "Equipaggiato: non disponibile", "Scambio: sì", "Scambio: probabile", "Scambio: no", "Scambio: sconosciuto", "oggetto", "oggetti", "oggetti" },
    ptBR = { "Voltar", "Pode pedir", "Todo equipamento", "Atual", "Esta sessão", "Histórico", "Percurso", "Saque", "Você", "Texto do sussurro:", "Sussurros", "Aparência", "Use {item} para o item recebido.", "Apenas novos itens elegíveis. Desativado por padrão.", "Aguardando saque do grupo", "Equipamentos da sua masmorra ou raide aparecerão aqui.", "Role para ver saques anteriores", "Redefinir posição", "Novo saque", "Redefinir", "Automático (atual: %s)", "Nenhum equipamento que possa ser pedido nesta visualização.", "Nenhum equipamento nesta visualização.", "Jogador", "Recebido", "Equipado agora", "Troca", "Perguntar", "Enviado", "Enviando", "Auto: não", "Auto: %ds", "Equipado: ", "Em cache: ", "Equipado: desconhecido", "Equipado: verificando...", "Equipado: indisponível", "Troca: sim", "Troca: provável", "Troca: não", "Troca: desconhecida", "item", "itens", "itens" },
    koKR = { "뒤로", "요청 가능", "모든 장비", "현재", "이번 세션", "기록", "진행", "전리품", "나", "귓속말 내용:", "귓속말", "외형", "획득한 아이템은 {item}으로 표시합니다.", "요청 가능한 새 전리품만 해당합니다. 기본값은 꺼짐입니다.", "파티 전리품 대기 중", "던전이나 공격대에서 획득한 장비가 여기에 표시됩니다.", "이전 전리품을 보려면 스크롤하세요", "위치 초기화", "새 전리품", "초기화", "자동 (현재: %s)", "이 보기에는 요청 가능한 장비가 없습니다.", "이 보기에는 장비가 없습니다.", "플레이어", "획득한 아이템", "현재 착용", "거래", "요청", "전송됨", "전송 중", "자동: 꺼짐", "자동: %ds", "착용: ", "캐시: ", "착용: 알 수 없음", "착용: 확인 중...", "착용: 확인 불가", "거래: 가능", "거래: 가능성 있음", "거래: 불가", "거래: 알 수 없음", "아이템", "아이템", "아이템" },
    zhCN = { "返回", "可询问", "所有装备", "当前", "本次会话", "历史", "行程", "战利品", "你", "密语内容：", "密语", "外观", "使用 {item} 表示掉落物品。", "仅限符合条件的新掉落。默认关闭。", "等待队伍战利品", "地下城或团队副本的装备将显示在此处。", "滚动查看较早的掉落", "重置位置", "新战利品", "重置", "自动（当前：%s）", "当前视图没有可询问的装备。", "当前视图没有装备。", "玩家", "掉落物品", "当前装备", "交易", "询问", "已发送", "发送中", "自动：关闭", "自动：%ds", "已装备：", "缓存：", "装备：未知", "装备：检查中...", "装备：不可用", "交易：可以", "交易：可能", "交易：不可以", "交易：未知", "件物品", "件物品", "件物品" },
    zhTW = { "返回", "可詢問", "所有裝備", "目前", "本次遊戲", "歷史", "行程", "戰利品", "你", "密語內容：", "密語", "外觀", "使用 {item} 表示掉落物品。", "僅限符合條件的新掉落。預設關閉。", "等待隊伍戰利品", "地城或團隊副本的裝備將顯示在此處。", "捲動查看較早的掉落", "重設位置", "新戰利品", "重設", "自動（目前：%s）", "目前檢視沒有可詢問的裝備。", "目前檢視沒有裝備。", "玩家", "掉落物品", "目前裝備", "交易", "詢問", "已傳送", "傳送中", "自動：關閉", "自動：%ds", "已裝備：", "快取：", "裝備：未知", "裝備：檢查中...", "裝備：無法取得", "交易：可以", "交易：可能", "交易：不可以", "交易：未知", "件物品", "件物品", "件物品" },
    esMX = { "Atrás", "Solicitables", "Todo el equipo", "Actual", "Esta sesión", "Historial", "Recorrido", "Botín", "Tú", "Texto del susurro:", "Susurros", "Apariencia", "Usa {item} para el objeto obtenido.", "Solo objetos nuevos aptos. Desactivado por defecto.", "Esperando botín del grupo", "Aquí aparecerá el equipo de tu mazmorra o banda.", "Desplázate para ver el botín anterior", "Restablecer posición", "Nuevo botín", "Restablecer", "Automático (actual: %s)", "No hay equipo que puedas solicitar en esta vista.", "No hay equipo en esta vista.", "Jugador", "Obtenido", "Equipo actual", "Intercambio", "Preguntar", "Enviado", "Enviando", "Auto: no", "Auto: %ds", "Equipado: ", "Guardado: ", "Equipado: desconocido", "Equipado: comprobando...", "Equipado: no disponible", "Intercambio: sí", "Intercambio: probable", "Intercambio: no", "Intercambio: desconocido", "objeto", "objetos", "objetos" },
}
for locale, values in pairs(visibleLocaleLabels) do
    for index, key in ipairs(visibleLocaleKeys) do
        simpleLocaleLabels[locale][key] = values[index]
    end
end

local statusLocaleKeys = { "candidate", "sent", "auto sent", "sending", "auto sending", "auto_pending", "whisper failed", "whisper_too_long", "whisper_invalid", "test row", "bind_on_pickup", "warband_bound", "bind_unknown", "not_askable", "quest_bound", "player_cannot_equip", "player_equip_unknown", "self_loot", "bonus_roll", "not_tradeable", "looter_unresolved", "Font may not render %s glyphs." }
local statusLocaleLabels = {
    deDE = { "Kandidat", "gesendet", "automatisch gesendet", "wird gesendet", "wird automatisch gesendet", "automatisch in %ds", "Flüstern fehlgeschlagen", "Flüstertext kürzen", "Flüstertext prüfen", "Testzeile", "beim Aufheben gebunden", "kriegsmeutengebunden", "Handelsstatus unbekannt", "nicht anfragbar", "questgebunden", "nicht anlegbar", "Anlegbarkeit unbekannt", "eigene Beute", "Bonusbeute", "nicht handelbar", "Spieler unbekannt", "Die Schrift unterstützt möglicherweise keine %s-Zeichen." },
    esES = { "candidato", "enviado", "enviado automáticamente", "enviando", "enviando automáticamente", "automático en %ds", "falló el susurro", "acorta el susurro", "revisa el susurro", "fila de prueba", "se liga al recogerlo", "ligado a la banda guerrera", "intercambio desconocido", "no se puede solicitar", "ligado a misión", "no puedes equiparlo", "uso desconocido", "botín propio", "botín extra", "no intercambiable", "jugador sin resolver", "La fuente podría no mostrar los caracteres %s." },
    frFR = { "candidat", "envoyé", "envoyé automatiquement", "envoi en cours", "envoi automatique en cours", "auto dans %ds", "échec du message", "raccourcissez le message", "vérifiez le message", "ligne de test", "lié quand ramassé", "lié au bataillon", "échange inconnu", "demande impossible", "lié à une quête", "impossible à équiper", "utilisation inconnue", "votre butin", "butin bonus", "non échangeable", "joueur non identifié", "La police risque de ne pas afficher les caractères %s." },
    itIT = { "candidato", "inviato", "inviato automaticamente", "invio in corso", "invio automatico in corso", "auto tra %ds", "sussurro non riuscito", "accorcia il sussurro", "controlla il sussurro", "riga di prova", "vincolato alla raccolta", "vincolato alla brigata", "scambio sconosciuto", "non richiedibile", "vincolato a una missione", "non equipaggiabile", "utilizzo sconosciuto", "bottino proprio", "bottino bonus", "non scambiabile", "giocatore non identificato", "Il font potrebbe non visualizzare i caratteri %s." },
    ptBR = { "candidato", "enviado", "enviado automaticamente", "enviando", "enviando automaticamente", "auto em %ds", "falha no sussurro", "encurte o sussurro", "verifique o sussurro", "linha de teste", "vincula ao pegar", "vinculado ao bando de guerra", "troca desconhecida", "não pode pedir", "vinculado a missão", "não pode equipar", "uso desconhecido", "saque próprio", "saque bônus", "não negociável", "jogador não identificado", "A fonte pode não exibir os caracteres %s." },
    koKR = { "후보", "전송됨", "자동 전송됨", "전송 중", "자동 전송 중", "%ds 후 자동 전송", "귓속말 실패", "귓속말을 줄이세요", "귓속말을 확인하세요", "테스트 행", "획득 시 귀속", "전투부대 귀속", "거래 상태 알 수 없음", "요청 불가", "퀘스트 귀속", "착용 불가", "착용 가능 여부 알 수 없음", "내 전리품", "추가 전리품", "거래 불가", "플레이어 확인 불가", "이 글꼴은 %s 문자를 표시하지 못할 수 있습니다." },
    zhCN = { "候选", "已发送", "已自动发送", "发送中", "自动发送中", "%ds 后自动发送", "密语失败", "请缩短密语", "请检查密语", "测试行", "拾取后绑定", "战团绑定", "交易状态未知", "不可询问", "任务绑定", "无法装备", "装备资格未知", "自己的战利品", "额外战利品", "无法交易", "玩家未确认", "此字体可能无法显示 %s 字符。" },
    zhTW = { "候選", "已傳送", "已自動傳送", "傳送中", "自動傳送中", "%ds 後自動傳送", "密語失敗", "請縮短密語", "請檢查密語", "測試列", "拾取後綁定", "戰隊綁定", "交易狀態未知", "不可詢問", "任務綁定", "無法裝備", "裝備資格未知", "自己的戰利品", "額外戰利品", "無法交易", "玩家未確認", "此字型可能無法顯示 %s 字元。" },
    esMX = { "candidato", "enviado", "enviado automáticamente", "enviando", "enviando automáticamente", "automático en %ds", "falló el susurro", "acorta el susurro", "revisa el susurro", "fila de prueba", "se liga al recogerlo", "ligado a la banda guerrera", "intercambio desconocido", "no se puede solicitar", "ligado a misión", "no puedes equiparlo", "uso desconocido", "botín propio", "botín extra", "no intercambiable", "jugador sin resolver", "La fuente podría no mostrar los caracteres %s." },
}
for locale, values in pairs(statusLocaleLabels) do
    local labels = simpleLocaleLabels[locale]
    for index, key in ipairs(statusLocaleKeys) do labels[key] = values[index] end
    labels.auto_sent = labels["auto sent"]
    labels.auto_sending = labels["auto sending"]
    labels.whisper_failed = labels["whisper failed"]
    labels.test_row = labels["test row"]
end

local helpLocaleKeys = { "trade_confirmed_help", "trade_likely_help", "trade_no_help", "trade_unknown_help", "whisper_invalid_help", "whisper_too_long_help" }
local helpLocaleLabels = {
    deDE = { "Beim Verarbeiten dieser Beute wurde ein Handelstimer erkannt. Er kann noch ablaufen.", "Bindungsart oder inspizierte Gegenstandsstufe des Platzes deuten darauf hin, dass dieser Gegenstand wahrscheinlich handelbar ist. Der Timer kann ablaufen; Anlegen oder Benutzen kann ihn binden.", "Laut verfügbaren Gegenstandsdaten kann diese Beute nicht übertragen werden.", "WoW zeigt die endgültige Handelsberechtigung für persönliche Beute anderer Spieler nicht an. Frage den Beuteempfänger.", "Entferne Zeilenumbrüche oder Steuerzeichen aus dem Flüstertext in den Einstellungen.", "Nach Einfügen des Gegenstandslinks ist der Flüstertext zu lang. Kürze ihn in den Einstellungen oder verwende weniger {item}-Platzhalter." },
    esES = { "Se detectó un temporizador de intercambio al procesar este objeto. Todavía puede caducar.", "El tipo de vínculo o el nivel del objeto equipado inspeccionado indican que este objeto probablemente se puede intercambiar. El temporizador puede caducar, y equiparlo o usarlo puede ligarlo.", "Los datos disponibles indican que este objeto no se puede transferir.", "WoW no muestra si otro jugador puede intercambiar su botín personal. Pide confirmación a quien lo recibió.", "Elimina los saltos de línea o caracteres de control del susurro en las opciones.", "El susurro es demasiado largo tras añadir el enlace del objeto. Acorta el texto en las opciones o usa menos marcadores {item}." },
    frFR = { "Un délai d’échange a été détecté lors du traitement de cet objet. Il peut encore expirer.", "Le type de liaison ou le niveau de l’objet inspecté à cet emplacement indique que cet objet est probablement échangeable. Le délai peut expirer, et équiper ou utiliser l’objet peut le lier.", "Les données disponibles indiquent que ce butin ne peut pas être échangé.", "WoW n’indique pas si un autre joueur peut échanger son butin personnel. Demandez confirmation au joueur qui l’a reçu.", "Retirez les sauts de ligne et caractères de contrôle du message dans les options.", "Le message est trop long après l’ajout du lien de l’objet. Raccourcissez-le dans les options ou utilisez moins de marqueurs {item}." },
    itIT = { "Durante l’elaborazione del bottino è stato rilevato un tempo limite per lo scambio. Può ancora scadere.", "Il tipo di vincolo o il livello dell’oggetto ispezionato nello stesso scomparto indicano che questo oggetto è probabilmente scambiabile. Il tempo limite può scadere e l’equipaggiamento o l’uso possono vincolarlo.", "I dati disponibili indicano che questo bottino non può essere trasferito.", "WoW non indica se un altro giocatore può scambiare il proprio bottino personale. Chiedi conferma a chi lo ha ricevuto.", "Rimuovi le interruzioni di riga o i caratteri di controllo dal sussurro nelle impostazioni.", "Il sussurro è troppo lungo dopo l’aggiunta del collegamento dell’oggetto. Accorcialo nelle impostazioni o usa meno segnaposto {item}." },
    ptBR = { "Um prazo de troca foi detectado ao processar este saque. Ele ainda pode expirar.", "O tipo de vínculo ou o nível do item inspecionado no mesmo espaço indica que este item provavelmente pode ser trocado. O prazo pode expirar, e equipar ou usar o item pode vinculá-lo.", "Os dados disponíveis indicam que este saque não pode ser transferido.", "O WoW não informa se outro jogador pode trocar seu saque pessoal. Peça a confirmação de quem recebeu o item.", "Remova quebras de linha ou caracteres de controle do sussurro nas configurações.", "O sussurro ficou longo demais após adicionar o link do item. Encurte o texto nas configurações ou use menos marcadores {item}." },
    koKR = { "전리품을 처리할 때 거래 제한 시간이 확인되었습니다. 이 시간은 만료될 수 있습니다.", "귀속 유형이나 살펴본 같은 부위의 아이템 레벨에 따르면 이 아이템은 거래 가능성이 있습니다. 제한 시간이 만료되거나 착용 또는 사용으로 귀속될 수 있습니다.", "확인 가능한 아이템 정보에 따르면 이 전리품은 거래할 수 없습니다.", "WoW는 다른 플레이어의 개인 전리품 거래 가능 여부를 공개하지 않습니다. 아이템을 획득한 플레이어에게 확인하세요.", "설정에서 귓속말 내용의 줄바꿈이나 제어 문자를 제거하세요.", "아이템 링크를 추가한 귓속말이 너무 깁니다. 설정에서 내용을 줄이거나 {item} 자리 표시자를 적게 사용하세요." },
    zhCN = { "处理此掉落时检测到了交易时限。该时限仍可能到期。", "绑定类型或通过观察获取的同部位物品等级表明，此物品可能可以交易。交易时限可能到期，装备或使用也可能使其绑定。", "现有物品数据表明此战利品无法转移。", "WoW 不提供其他玩家个人拾取的最终交易资格。请向拾取者确认。", "请在设置中删除密语内容的换行符或控制字符。", "添加物品链接后，密语过长。请在设置中缩短内容，或减少 {item} 占位符。" },
    zhTW = { "處理此掉落時偵測到了交易時限。該時限仍可能到期。", "綁定類型或透過觀察取得的同部位物品等級顯示，此物品可能可以交易。交易時限可能到期，裝備或使用也可能使其綁定。", "現有物品資料顯示此戰利品無法轉移。", "WoW 不提供其他玩家個人拾取的最終交易資格。請向拾取者確認。", "請在設定中刪除密語內容的換行符號或控制字元。", "加入物品連結後，密語過長。請在設定中縮短內容，或減少 {item} 預留位置。" },
    esMX = { "Se detectó un temporizador de intercambio al procesar este objeto. Todavía puede caducar.", "El tipo de vínculo o el nivel del objeto equipado inspeccionado indican que este objeto probablemente se puede intercambiar. El temporizador puede caducar, y equiparlo o usarlo puede ligarlo.", "Los datos disponibles indican que este objeto no se puede transferir.", "WoW no muestra si otro jugador puede intercambiar su botín personal. Pide confirmación a quien lo recibió.", "Elimina los saltos de línea o caracteres de control del susurro en las opciones.", "El susurro es demasiado largo tras añadir el enlace del objeto. Acorta el texto en las opciones o usa menos marcadores {item}." },
}
for locale, values in pairs(helpLocaleLabels) do
    for index, key in ipairs(helpLocaleKeys) do simpleLocaleLabels[locale][key] = values[index] end
end

for locale, labels in pairs(simpleLocaleLabels) do
    labels["Do You Need It?"] = "Do You Need It?"
    LABELS_BY_LOCALE[locale] = {}
    for key, value in pairs(LABELS_BY_LOCALE.enUS) do
        LABELS_BY_LOCALE[locale][key] = labels[key] or value
    end
end

local favoriteLocaleLabels = {
    enUS = { "Add favorite", "Remove favorite" },
    ruRU = { "Добавить в избранное", "Убрать из избранного" },
    deDE = { "Favorit hinzufügen", "Favorit entfernen" },
    esES = { "Añadir a favoritos", "Quitar de favoritos" },
    esMX = { "Añadir a favoritos", "Quitar de favoritos" },
    frFR = { "Ajouter aux favoris", "Retirer des favoris" },
    itIT = { "Aggiungi ai preferiti", "Rimuovi dai preferiti" },
    ptBR = { "Adicionar aos favoritos", "Remover dos favoritos" },
    koKR = { "즐겨찾기 추가", "즐겨찾기 제거" },
    zhCN = { "添加收藏", "取消收藏" },
    zhTW = { "加入收藏", "取消收藏" },
}
for locale, values in pairs(favoriteLocaleLabels) do
    LABELS_BY_LOCALE[locale]["Add favorite"] = values[1]
    LABELS_BY_LOCALE[locale]["Remove favorite"] = values[2]
end

-- Unknown transfer eligibility needs confirmation from the player who looted it.
local tradeConfirmationLabels = {
    enUS = "Check with looter", ruRU = "Уточнить у владельца",
    deDE = "Besitzer fragen", frFR = "Demander au joueur",
    esES = "Pregunta al dueño", esMX = "Pregunta al dueño",
    itIT = "Chiedi al giocatore", ptBR = "Confirme com o dono",
    koKR = "획득자에게 확인", zhCN = "向拾取者确认", zhTW = "向拾取者確認",
}
for locale, label in pairs(tradeConfirmationLabels) do
    LABELS_BY_LOCALE[locale].trade_unknown = label
end

local centerWindowLocaleLabels = {
    enUS = "Center window", ruRU = "По центру", deDE = "Fenster zentrieren",
    esES = "Centrar ventana", esMX = "Centrar ventana", frFR = "Centrer la fenêtre",
    itIT = "Centra finestra", ptBR = "Centralizar janela", koKR = "창 중앙 정렬",
    zhCN = "窗口居中", zhTW = "視窗置中",
}
for locale, label in pairs(centerWindowLocaleLabels) do
    LABELS_BY_LOCALE[locale]["Center window"] = label
end

local developerLinkLocaleLabels = {
    enUS = { "Support development", "Report a bug or suggest a feature" },
    ruRU = { "Поддержать разработку", "Сообщить об ошибке или предложить функцию" },
    deDE = { "Entwicklung unterstützen", "Fehler melden oder Funktion vorschlagen" },
    esES = { "Apoyar el desarrollo", "Informar de un error o sugerir una función" },
    esMX = { "Apoyar el desarrollo", "Reportar un error o sugerir una función" },
    frFR = { "Soutenir le développement", "Signaler un bug ou proposer une fonctionnalité" },
    itIT = { "Sostieni lo sviluppo", "Segnala un errore o suggerisci una funzione" },
    ptBR = { "Apoiar o desenvolvimento", "Relatar um erro ou sugerir uma função" },
    koKR = { "개발 후원", "버그 신고 또는 기능 제안" },
    zhCN = { "支持开发", "报告问题或建议新功能" },
    zhTW = { "支持開發", "回報問題或建議新功能" },
}
for locale, values in pairs(developerLinkLocaleLabels) do
    LABELS_BY_LOCALE[locale]["Support development"] = values[1]
    LABELS_BY_LOCALE[locale]["Report a bug or suggest a feature"] = values[2]
end

local demoLocaleLabels = {
    enUS = { "Demo", "Exit demo", "Preview sample loot. No whispers are sent." },
    ruRU = { "Демо", "Выйти из демо", "Пример добычи. Сообщения не отправляются." },
    deDE = { "Demo", "Demo beenden", "Beispielbeute ansehen. Es werden keine Flüsternachrichten gesendet." },
    esES = { "Demo", "Salir de demo", "Vista previa de botín. No se envían susurros." },
    esMX = { "Demo", "Salir de demo", "Vista previa de botín. No se envían susurros." },
    frFR = { "Démo", "Quitter la démo", "Aperçu du butin. Aucun chuchotement n'est envoyé." },
    itIT = { "Demo", "Esci dalla demo", "Anteprima del bottino. Nessun sussurro viene inviato." },
    ptBR = { "Demo", "Sair da demo", "Prévia de saque. Nenhum sussurro é enviado." },
    koKR = { "미리보기", "미리보기 종료", "예시 전리품을 표시합니다. 귓속말은 전송하지 않습니다." },
    zhCN = { "演示", "退出演示", "预览示例战利品。不会发送密语。" },
    zhTW = { "示範", "結束示範", "預覽範例戰利品。不會傳送密語。" },
}
for locale, values in pairs(demoLocaleLabels) do
    LABELS_BY_LOCALE[locale]["Demo"] = values[1]
    LABELS_BY_LOCALE[locale]["Exit demo"] = values[2]
    LABELS_BY_LOCALE[locale]["Preview sample loot. No whispers are sent."] = values[3]
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

local PLAYER_ARMOR_SUBCLASS_BY_CLASS = {
    DEATHKNIGHT = 4,
    DEMONHUNTER = 2,
    DRUID = 2,
    EVOKER = 3,
    HUNTER = 3,
    MAGE = 1,
    MONK = 2,
    PALADIN = 4,
    PRIEST = 1,
    ROGUE = 2,
    SHAMAN = 3,
    WARLOCK = 1,
    WARRIOR = 4,
}

local ARMOR_SPECIALIZATION_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
}

local UNIVERSAL_EQUIP_LOCS = {
    INVTYPE_NECK = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
}

-- Static weapon proficiency by class (item subclass IDs for classID 2).
-- Fallback only: consulted when the usability API is silent (nil), and only
-- ever denies. Known gaps resolve to false (never ask); allowed or unknown
-- combinations stay unknown (nil) so a silent API can never grant Ask.
local WEAPON_PROFICIENCY_BY_CLASS = {
    WARRIOR = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [18] = true },
    PALADIN = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    HUNTER = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [18] = true },
    ROGUE = { [0] = true, [2] = true, [3] = true, [4] = true, [7] = true, [13] = true, [15] = true, [18] = true },
    PRIEST = { [4] = true, [10] = true, [15] = true, [19] = true },
    DEATHKNIGHT = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
    SHAMAN = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },
    MAGE = { [7] = true, [10] = true, [15] = true, [19] = true },
    WARLOCK = { [7] = true, [10] = true, [15] = true, [19] = true },
    MONK = { [0] = true, [4] = true, [6] = true, [7] = true, [10] = true, [13] = true },
    DRUID = { [4] = true, [5] = true, [6] = true, [10] = true, [13] = true, [15] = true },
    DEMONHUNTER = { [0] = true, [7] = true, [9] = true, [13] = true, [15] = true },
    EVOKER = { [0] = true, [4] = true, [7] = true, [10] = true, [13] = true, [15] = true },
}

local PERSISTED_ROW_KEYS = {
    id = "string",
    looter = "string",
    classToken = "string",
    itemLink = "string",
    equipLoc = "string",
    itemID = "number",
    itemLevel = "number",
    instanceName = "string",
    encounterName = "string",
    timestamp = "number",
    lootSource = "string",
    reason = "string",
    statusKey = "string",
    statusText = "string",
    equippedText = "string",
    tradeStatusKey = "string",
    unsafe = "boolean",
    manualWhispered = "boolean",
    autoWhispered = "boolean",
    askable = "boolean",
    isAccountBound = "boolean",
    isAccountBoundUntilEquipped = "boolean",
}

local PERSISTED_GROUP_KEYS = {
    title = "string",
    instanceName = "string",
    encounterName = "string",
    dropCount = "number",
    startedAt = "number",
    endedAt = "number",
}

local function safeTonumber(value)
    -- WHY: in combat Blizzard may hand us secret-tagged values; a bare
    -- tonumber on those raises inside the loot event flow. pcall keeps the
    -- row alive and lets callers fall back to unknown/not-askable.
    local ok, number = pcall(tonumber, value)
    if not ok then
        return nil
    end
    return number
end

local function asNumber(value, fallback)
    local number = safeTonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

local function isFiniteNumber(value)
    if type(value) ~= "number" then return false end
    if type(_G.issecretvalue) == "function" then
        local ok, secret = pcall(_G.issecretvalue, value)
        if not ok or secret then return false end
    end
    return value == value and value ~= math.huge and value ~= -math.huge
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
        message = message:gsub("{item}", function()
            return itemText
        end)
    elseif itemText ~= "" then
        message = message .. (message:match("%s$") and "" or " ") .. itemText
    end

    if message:find("%c") then
        return nil, "whisper_invalid"
    end
    if #message > MAX_CHAT_BYTES then
        return nil, "whisper_too_long"
    end
    -- Match Blizzard's chat edit-box budgets without clipping UTF-8 or links.
    local visible, invisible, index = 0, 0, 1
    while index <= #message do
        local pair = message:sub(index, index + 1)
        local _, linkEnd, label = message:find("^|Hitem:%d+:[^|]*|h([^|]*)|h", index)
        if not linkEnd then
            _, linkEnd, label = message:find("^|Hitem:%d+|h([^|]*)|h", index)
        end
        if pair == "||" then
            visible = visible + 2
            index = index + 2
        elseif linkEnd then
            visible = visible + #label
            invisible = invisible + linkEnd - index + 1 - #label
            index = linkEnd + 1
        elseif message:find("^|c%x%x%x%x%x%x%x%x", index) then
            invisible = invisible + 10
            index = index + 10
        elseif pair == "|r" then
            invisible = invisible + 2
            index = index + 2
        else
            visible = visible + 1
            index = index + 1
        end
    end
    if visible > MAX_CHAT_VISIBLE_BYTES or invisible > MAX_CHAT_INVISIBLE_BYTES then
        return nil, "whisper_too_long"
    end
    return message
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

local function rowTimestamp(row)
    if type(row) ~= "table" then return nil end
    local stamp = row.timestamp
    if type(stamp) ~= "number" then return nil end
    -- Zero is the legacy saved-row placeholder for an unavailable timestamp.
    return isFiniteNumber(stamp) and stamp > 0 and stamp or nil
end

function Core.InsertRowChronologically(rows, row)
    if type(rows) ~= "table" or type(row) ~= "table" then return false end
    local stamp = rowTimestamp(row)
    local position = #rows + 1
    if stamp then
        local lastKnown
        for index = #rows, 1, -1 do
            lastKnown = rowTimestamp(rows[index])
            if lastKnown then break end
        end
        if not lastKnown or lastKnown <= stamp then
            rows[position] = row
            return true
        end
        for index = 1, #rows do
            local existing = rowTimestamp(rows[index])
            if existing and existing > stamp then position = index; break end
        end
    end
    -- Equal and unknown timestamps retain arrival order; no comparator can
    -- accidentally make missing timestamps violate sort transitivity.
    table.insert(rows, position, row)
    return true
end

function Core.OrderRowsChronologically(rows)
    if type(rows) ~= "table" then return rows end
    local ordered = {}
    for index = 1, #rows do Core.InsertRowChronologically(ordered, rows[index]) end
    for index = 1, #rows do rows[index] = ordered[index] end
    return rows
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
    -- Rendered ruRU labels, kept so carried-over saves map back to keys.
    ["кандидат"] = "candidate",
    ["отправлено"] = "sent",
    ["авто отправлено"] = "auto_sent",
    ["отправка"] = "sending",
    ["авто-отправка"] = "auto_sending",
    ["виспер не отправлен"] = "whisper_failed",
    ["тест"] = "test_row",
    ["Отпр."] = "sent",
    ["Отпр..."] = "sending",
}

local TRANSIENT_STATUS_KEYS = {
    auto_pending = true,
    sending = true,
    auto_sending = true,
}

local TRADE_STATUS_KEYS = {
    trade_confirmed = true,
    trade_likely = true,
    trade_no = true,
    trade_unknown = true,
}

local TRADE_NO_REASON_KEYS = {
    bonus_roll = true,
    not_tradeable = true,
    quest_bound = true,
    warband_bound = true,
}

local TRADE_UNKNOWN_REASON_KEYS = {
    bind_on_pickup = true,
    bind_unknown = true,
}

local function resolveTradeStatusKey(row)
    if type(row) ~= "table" then
        return "trade_unknown"
    end
    if TRADE_STATUS_KEYS[row.tradeStatusKey] then
        return row.tradeStatusKey
    end
    if TRADE_NO_REASON_KEYS[row.reason] or TRADE_NO_REASON_KEYS[row.statusKey] then
        return "trade_no"
    end
    if TRADE_UNKNOWN_REASON_KEYS[row.reason] or TRADE_UNKNOWN_REASON_KEYS[row.statusKey] then
        return "trade_unknown"
    end
    return "trade_unknown"
end

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
        -- Legacy free text has no status evidence; fall back to candidate.
        return LEGACY_STATUS_TEXT_TO_KEY[text] or "candidate", nil
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
    if type(saved.id) ~= "string" or saved.id == "" then
        saved.id = ""
    end
    if type(saved.timestamp) ~= "number" then
        if type(row) == "table" and type(row.timestamp) == "nil" then
            saved.timestamp = 0
        end
    end
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
    if saved.tradeStatusKey == "trade_confirmed" or saved.tradeStatusKey == "trade_likely" then
        saved.tradeStatusKey = "trade_unknown"
    end
    return saved
end

local function snapshotRowsForSave(rows, limit)
    local saved = {}
    if type(rows) == "table" then
        for index = 1, #rows do
            if type(rows[index]) == "table" then
                Core.InsertRowChronologically(saved, snapshotRowForSave(rows[index]))
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
    local number = asNumber(classID, nil)
    return number == 2 or number == 4
end

local function isVisibleQuality(quality, minQuality)
    local number = asNumber(quality, nil)
    return number ~= nil and number >= asNumber(minQuality, 0)
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
    -- WHY: WoW Lua is byte-based; this only detects UTF-8 lead bytes
    -- and does not slice or transform the user-visible text.
    if text:find(CYRILLIC_UTF8_LEAD_PATTERN) then
        return GLYPH_CYR
    end
    if text:find(HANGUL_UTF8_LEAD_PATTERN) then
        return GLYPH_HANGUL
    end
    -- Hangul Jamo U+1100-U+11FF encodes as E1 84 80-E1 87 BF. Lead E1
    -- alone would also match Myanmar/Ethiopic, so the second byte is
    -- constrained to 0x84-0x87 (U+10FF ends in 0x83, U+1200 starts 0x88).
    if text:find("\225[\132-\135]") then
        return GLYPH_HANGUL
    end
    if text:find(CJK_UTF8_LEAD_PATTERN) then
        return GLYPH_HANS
    end
    return nil
end

function Core.GetTextGlyphRequirements(text, locale)
    local glyphs = {}
    if type(text) ~= "string" then return glyphs end
    if text:find(CYRILLIC_UTF8_LEAD_PATTERN) then glyphs[#glyphs + 1] = GLYPH_CYR end
    if text:find(HANGUL_UTF8_LEAD_PATTERN) or text:find("\225[\132-\135]") then glyphs[#glyphs + 1] = GLYPH_HANGUL end
    -- Han codepoints alone do not identify a regional language. Use the active
    -- locale as context; actual bundled glyph coverage is verified offline.
    if text:find(CJK_UTF8_LEAD_PATTERN) then
        glyphs[#glyphs + 1] = locale == "zhTW" and GLYPH_HANT or GLYPH_HANS
    end
    return glyphs
end

function Core.FontSupportsText(path, text, locale)
    for _, glyph in ipairs(Core.GetTextGlyphRequirements(text, locale)) do
        if not Core.FontSupports(path, glyph, locale) then return false end
    end
    return true
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

function Core.GetTradeStatusKey(row)
    return resolveTradeStatusKey(row)
end

function Core.GetTradeStatusText(row, locale)
    return Core.GetLocaleLabel(resolveTradeStatusKey(row), locale)
end

function Core.GetTradeStatusTooltip(row, locale)
    return Core.GetLocaleLabel(resolveTradeStatusKey(row) .. "_help", locale)
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

-- Verified character-map coverage is separate from client asset activation.
function Core.SetBundledFonts(fonts)
    bundledFonts = type(fonts) == "table" and fonts or {}
    bundledByPath = {}
    bundledByFile = {}
    for _, font in ipairs(bundledFonts) do
        bundledByPath[Core.FontPathKey(font.path)] = font
        bundledByFile[font.file:lower()] = font
    end
end

function Core.GetBundledFonts()
    return copyList(bundledFonts)
end

function Core.FontSupportsLocale(path, locale)
    local key = Core.FontPathKey(path)
    if not key then return false end
    local font = bundledByPath[key] or bundledByFile[(key:match("[^\\]+$") or key)]
    if font and font.region and (locale == "zhCN" or locale == "zhTW") and font.region ~= locale then
        return false
    end
    local glyph = Core.GetLocaleGlyphRequirement(locale)
    local supported = Core.FontSupports(path, glyph, locale)
    -- Unknown media paths only promise basic Latin. Accented translations
    -- require catalog coverage or a recognized family, not a filename guess.
    if glyph == GLYPH_LATIN and locale ~= "enUS" and not font and not FONT_GLYPH_SUPPORT[key] then
        return false
    end
    return supported
end

function Core.FontSupports(fontPath, glyph, clientLocale)
    if fontPath == nil then
        return glyph == GLYPH_LATIN
    end

    local key = Core.FontPathKey(fontPath)
    if not key then
        return glyph == GLYPH_LATIN
    end

    local file = key:match("[^\\]+$") or key
    local bundled = bundledByPath[key] or bundledByFile[file]
    if bundled then
        if glyph == GLYPH_LATIN then
            if bundled.latinLocales and clientLocale then return bundled.latinLocales[clientLocale] == true end
            return bundled.latin ~= false
        end
        if glyph == GLYPH_CYR then return bundled.cyrillic == true end
        if glyph == GLYPH_HANS then return bundled.hans == true end
        if glyph == GLYPH_HANT then return bundled.hant == true end
        if glyph == GLYPH_HANGUL then return bundled.hangul == true end
        return false
    end
    local entry = FONT_GLYPH_SUPPORT[key]
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
    settings.fontFavorites = {}
    if type(saved.fontFavorites) == "table" then
        local count = 0
        for path, selected in pairs(saved.fontFavorites) do
            local key = Core.FontPathKey(path)
            if selected == true and key and #key > 0 and #key <= 512 and count < 256 then
                settings.fontFavorites[key] = true
                count = count + 1
            end
        end
    end
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

local groupTitle
local appendUniqueRows
local matchingRecentHistoryGroup

function Core.NormalizeSavedRows(rows, limit)
    return snapshotRowsForSave(rows, limit or DEFAULTS.maxSessionRows)
end

function Core.NormalizeSavedAllRows(rows, fallbackRows, limit)
    return snapshotRowsForSaveWithFallback(rows, fallbackRows, limit or DEFAULTS.maxSessionRows)
end

function Core.SnapshotRowsForSave(rows, limit)
    return snapshotRowsForSave(rows, limit or DEFAULTS.maxSessionRows)
end

function Core.SnapshotHistoryForSave(history, limit, rowLimit, mergeWindow, locale)
    local saved = {}
    local perGroupRowLimit = rowLimit or DEFAULTS.maxSessionRows
    if type(history) == "table" then
        for index = 1, #history do
            local group = history[index]
            if type(group) == "table" then
                local savedGroup = copyPrimitiveFields(group, PERSISTED_GROUP_KEYS)
                savedGroup.rows = snapshotRowsForSave(group.rows, perGroupRowLimit)
                savedGroup.allRows = snapshotRowsForSaveWithFallback(group.allRows, group.rows, perGroupRowLimit)
                local latest = saved[#saved]
                if matchingRecentHistoryGroup(latest, {
                    instanceName = savedGroup.instanceName,
                    encounterName = savedGroup.encounterName,
                    endedAt = savedGroup.endedAt,
                    mergeWindow = mergeWindow,
                }) then
                    -- History groups arrive newest first; row lists remain oldest first.
                    latest.rows = appendUniqueRows(savedGroup.rows, latest.rows, true)
                    latest.allRows = appendUniqueRows(savedGroup.allRows, latest.allRows, true)
                    pruneListStart(latest.rows, perGroupRowLimit)
                    pruneListStart(latest.allRows, perGroupRowLimit)
                    local latestStartedAt = tonumber(latest.startedAt)
                    local savedStartedAt = tonumber(savedGroup.startedAt)
                    if savedStartedAt and (not latestStartedAt or savedStartedAt < latestStartedAt) then
                        latest.startedAt = savedStartedAt
                    end
                    local latestEndedAt = tonumber(latest.endedAt)
                    local savedEndedAt = tonumber(savedGroup.endedAt)
                    if savedEndedAt and (not latestEndedAt or savedEndedAt > latestEndedAt) then
                        latest.endedAt = savedEndedAt
                    end
                    local mergedDropCount = #latest.allRows > 0 and #latest.allRows or #latest.rows
                    latest.dropCount = mergedDropCount
                    latest.title = groupTitle({
                        instanceName = latest.instanceName,
                        encounterName = latest.encounterName,
                        title = latest.title,
                        locale = locale,
                    }, mergedDropCount)
                else
                    saved[#saved + 1] = savedGroup
                end
            end
        end
    end
    pruneListEnd(saved, limit or DEFAULTS.maxHistoryGroups)
    return saved
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

function Core.MergePendingWaiterContext(waiter, context)
    if type(waiter) ~= "table" or type(context) ~= "table" then
        return
    end

    waiter.context = type(waiter.context) == "table" and waiter.context or {}
    if context.lootSource == "bonus_roll" then
        waiter.context.lootSource = "bonus_roll"
        waiter.context.source = waiter.context.source or context.source
    end
    if waiter.context.classToken == nil and context.classToken ~= nil then
        waiter.context.classToken = context.classToken
    end
    if context.isSelfLoot == true then
        waiter.context.isSelfLoot = true
    end
    if context.unsafe == true then
        waiter.context.unsafe = true
        waiter.context.unsafeReason = waiter.context.unsafeReason or context.unsafeReason
    end
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
    for index = 1, #bucket.waiters do
        local existing = bucket.waiters[index]
        if type(existing) == "table" and existing.looter == waiter.looter and existing.generation == waiter.generation then
            Core.MergePendingWaiterContext(existing, waiter.context)
            return bucket, false
        end
    end
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
        isAccountBound = detailed.isAccountBound == true,
        isAccountBoundUntilEquipped = detailed.isAccountBoundUntilEquipped == true,
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

function Core.IsHiddenLootRow(row)
    return type(row) == "table" and (
        row.isAccountBound == true or row.isAccountBoundUntilEquipped == true
        or row.reason == "warband_bound" or row.statusKey == "warband_bound"
    )
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
    if Core.IsHiddenLootRow(item) then
        return { visible = false, reason = "warband_bound" }
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

function Core.ResolvePlayerCanEquip(item, playerClassToken, apiCanEquip)
    if type(item) ~= "table" then
        return nil
    end

    local equipLoc = item.equipLoc or ""
    if UNIVERSAL_EQUIP_LOCS[equipLoc] == true then
        -- Universal slots are usable by every class, but a conservative
        -- usability API still wins: explicit false is never overridden.
        if apiCanEquip == false then
            return false
        end
        return true
    end

    local classID = asNumber(item.classID or item.itemClassID, nil)
    if classID == 4 and ARMOR_SPECIALIZATION_EQUIP_LOCS[equipLoc] == true then
        local subclassID = asNumber(item.subclassID or item.itemSubclassID, nil)
        local preferredSubclassID = PLAYER_ARMOR_SUBCLASS_BY_CLASS[playerClassToken or ""]
        if subclassID == nil or preferredSubclassID == nil then
            return nil
        end
        return subclassID == preferredSubclassID
    end

    if classID == 2 and apiCanEquip == nil then
        local subclassID = asNumber(item.subclassID or item.itemSubclassID, nil)
        local proficient = WEAPON_PROFICIENCY_BY_CLASS[playerClassToken or ""]
        if type(proficient) == "table" and subclassID ~= nil and proficient[subclassID] ~= true then
            return false
        end
        return nil
    end

    if type(apiCanEquip) == "boolean" then
        return apiCanEquip
    end
    return nil
end

function Core.ResolveTradeStatus(item)
    if type(item) ~= "table" then
        return "trade_unknown"
    end
    if item.canTrade == false or item.lootSource == "bonus_roll" then
        return "trade_no"
    end
    if item.isAccountBound == true or item.isAccountBoundUntilEquipped == true then
        return "trade_no"
    end

    local bindType = asNumber(item.bindType, nil)
    if bindType == Core.BIND_QUEST then
        return "trade_no"
    end
    if item.canTrade == true or item.tradeTimeRemaining == true then
        return "trade_confirmed"
    end
    if Core.LIKELY_TRADE_BINDTYPES[bindType] then
        return "trade_likely"
    end
    return "trade_unknown"
end

function Core.IsLikelyTradeableFromItemLevels(dropItemLevel, equippedItemLevels, requiredSlotCount)
    local dropLevel = asNumber(dropItemLevel, nil)
    if not dropLevel or dropLevel <= 0 or type(equippedItemLevels) ~= "table" then
        return nil
    end

    local required = math.max(1, math.floor(asNumber(requiredSlotCount, 1)))
    local compared = 0
    for index = 1, #equippedItemLevels do
        local equippedLevel = asNumber(equippedItemLevels[index], nil)
        if equippedLevel and equippedLevel > 0 then
            if equippedLevel < dropLevel then
                return false
            end
            compared = compared + 1
            if compared >= required then
                return true
            end
        end
    end
    return nil
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
    local bindType = asNumber(item.bindType, nil)
    if bindType == nil and item.tradeTimeRemaining ~= true and item.canTrade ~= true then
        return { visible = false, reason = "bind_unknown" }
    end
    if bindType == Core.BIND_ON_PICKUP and item.tradeTimeRemaining ~= true then
        return { visible = false, reason = "bind_on_pickup" }
    end
    if bindType == Core.BIND_QUEST then
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
        -- Saved rows survive reload while the runtime sequence starts over.
        local usedIDs = {}
        local function rememberIDs(rows)
            for index = 1, #(rows or {}) do
                local existing = rows[index]
                if type(existing) == "table" and type(existing.id) == "string" then
                    usedIDs[existing.id] = true
                end
            end
        end
        rememberIDs(state.currentRows)
        rememberIDs(state.allRows)
        rememberIDs(state.sessionRows)
        rememberIDs(state.sessionAllRows)
        for index = 1, #(state.history or {}) do
            local group = state.history[index]
            if type(group) == "table" then
                rememberIDs(group.rows)
                rememberIDs(group.allRows)
            end
        end
        local nextID = state.nextRowID or 1
        repeat
            saved.id = "row" .. tostring(nextID)
            nextID = nextID + 1
        until not usedIDs[saved.id]
        state.nextRowID = nextID
    end
    saved.askable = askable ~= false

    state.allRows = state.allRows or {}
    state.sessionAllRows = state.sessionAllRows or {}
    Core.InsertRowChronologically(state.allRows, saved)
    Core.InsertRowChronologically(state.sessionAllRows, saved)
    local limit = state.settings and state.settings.maxSessionRows or DEFAULTS.maxSessionRows
    pruneListStart(state.sessionAllRows, limit)

    if saved.askable then
        Core.InsertRowChronologically(state.currentRows, saved)
        Core.InsertRowChronologically(state.sessionRows, saved)
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

groupTitle = function(meta, dropCount)
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

-- Display-time history title: re-rendered on the active locale.
-- Legacy groups without names keep their stored title verbatim.
function Core.GetHistoryGroupTitle(group, locale)
    if type(group) ~= "table" then
        return nil
    end
    locale = type(locale) == "string" and locale ~= "" and locale or "enUS"
    local instanceName = type(group.instanceName) == "string" and group.instanceName ~= "" and group.instanceName or nil
    local encounterName = type(group.encounterName) == "string" and group.encounterName ~= "" and group.encounterName or nil
    if not instanceName and not encounterName then
        if type(group.title) == "string" and group.title ~= "" then
            return group.title
        end
        return nil
    end
    local dropCount = asNumber(group.dropCount, nil)
    if dropCount == nil then
        local allRows = type(group.allRows) == "table" and group.allRows or {}
        local rows = type(group.rows) == "table" and group.rows or {}
        dropCount = #allRows > 0 and #allRows or #rows
    end
    return groupTitle({
        instanceName = instanceName,
        encounterName = encounterName,
        locale = locale,
    }, dropCount)
end

local function rowMergeKey(row)
    if type(row) ~= "table" then
        return nil
    end
    local id = type(row.id) == "string" and row.id or ""
    local itemID = safeTonumber(row.itemID) or Core.ExtractItemID(row.itemLink)
    local timestamp = isFiniteNumber(row.timestamp) and row.timestamp or nil
    -- Identity is id+looter+itemID+timestamp; the full link only upgrades
    -- variants below, never tells rows apart.
    return id .. "\031" .. tostring(row.looter or "") .. "\031"
        .. tostring(itemID or "") .. "\031"
        .. tostring(timestamp or "")
end

function Core.UpgradeRowLinkToDetailed(stored, incoming)
    if type(stored) ~= "table" or type(incoming) ~= "table" then
        return false
    end
    local newLink = incoming.itemLink
    local oldLink = stored.itemLink
    if type(newLink) ~= "string" or newLink == "" or newLink == oldLink then
        return false
    end
    if type(oldLink) == "string" and oldLink ~= "" and #newLink <= #oldLink then
        return false
    end
    local newID = Core.ExtractItemID(newLink)
    if not newID then
        return false
    end
    local oldID = safeTonumber(stored.itemID) or Core.ExtractItemID(oldLink)
    if oldID ~= nil and oldID ~= newID then
        return false
    end
    stored.itemLink = newLink
    stored.itemID = newID
    return true
end

appendUniqueRows = function(target, rows, preferIncoming)
    target = type(target) == "table" and target or {}
    if type(rows) ~= "table" then
        return target
    end

    local seen = {}
    for index = 1, #target do
        local key = rowMergeKey(target[index])
        if key then
            seen[key] = index
        end
    end
    for index = 1, #rows do
        local row = rows[index]
        local key = rowMergeKey(row)
        if key and not seen[key] then
            target[#target + 1] = row
            seen[key] = #target
        elseif key and preferIncoming then
            target[seen[key]] = row
        elseif key then
            Core.UpgradeRowLinkToDetailed(target[seen[key]], row)
        end
    end
    return Core.OrderRowsChronologically(target)
end

matchingRecentHistoryGroup = function(group, meta)
    if type(group) ~= "table" or type(meta) ~= "table" then
        return false
    end
    local window = tonumber(meta.mergeWindow)
    if not window or window < 0 then
        return false
    end

    local instanceName = type(meta.instanceName) == "string" and meta.instanceName ~= "" and meta.instanceName or nil
    local encounterName = type(meta.encounterName) == "string" and meta.encounterName ~= "" and meta.encounterName or nil
    if not instanceName and not encounterName then
        return false
    end
    if instanceName and group.instanceName ~= instanceName then
        return false
    end
    if encounterName and group.encounterName ~= encounterName then
        return false
    end

    local groupEndedAt = tonumber(group.endedAt)
    local endedAt = tonumber(meta.endedAt)
    return groupEndedAt ~= nil and endedAt ~= nil and math.abs(endedAt - groupEndedAt) <= window
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
    -- Item data can arrive after the next encounter starts. Keep the captured
    -- loot owner instead of attributing a delayed drop to the completion event.
    local sourceRows = #state.allRows > 0 and state.allRows or state.currentRows
    local partitions, ordered = {}, {}
    local rowPartitions = {}
    local needsPartition = false
    for index = 1, #sourceRows do
        local row = sourceRows[index]
        local instanceName = row.instanceName or groupMeta.instanceName
        local encounterName = row.encounterName or groupMeta.encounterName
        local key = (instanceName or "") .. "\031" .. (encounterName or "")
        local part = partitions[key]
        if not part then
            part = { allRows = {}, currentRows = {}, settings = state.settings, history = state.history,
                order = #ordered + 1,
                meta = { instanceName = instanceName, encounterName = encounterName,
                    locale = groupMeta.locale, mergeWindow = groupMeta.mergeWindow } }
            partitions[key] = part
            ordered[#ordered + 1] = part
        end
        part.allRows[#part.allRows + 1] = row
        rowPartitions[row] = part
        if instanceName ~= groupMeta.instanceName or encounterName ~= groupMeta.encounterName then
            needsPartition = true
        end
        local stamp = rowTimestamp(row)
        if stamp then
            part.meta.startedAt = math.min(part.meta.startedAt or stamp, stamp)
            part.meta.endedAt = math.max(part.meta.endedAt or stamp, stamp)
        end
    end
    if needsPartition then
        table.sort(ordered, function(left, right)
            local leftCurrent = left.meta.instanceName == groupMeta.instanceName and left.meta.encounterName == groupMeta.encounterName
            local rightCurrent = right.meta.instanceName == groupMeta.instanceName and right.meta.encounterName == groupMeta.encounterName
            if leftCurrent ~= rightCurrent then return rightCurrent end
            local leftTime, rightTime = left.meta.endedAt or -math.huge, right.meta.endedAt or -math.huge
            if leftTime ~= rightTime then return leftTime < rightTime end
            return left.order < right.order
        end)
        for index = 1, #state.currentRows do
            local row = state.currentRows[index]
            local part = rowPartitions[row]
            if part then part.currentRows[#part.currentRows + 1] = row end
        end
        local completed
        for index = 1, #ordered do
            local part = ordered[index]
            if part.meta.instanceName == groupMeta.instanceName and part.meta.encounterName == groupMeta.encounterName then
                part.meta.startedAt = groupMeta.startedAt or part.meta.startedAt
                part.meta.endedAt = groupMeta.endedAt or part.meta.endedAt
            end
            completed = Core.CompleteCurrentGroup(part, part.meta)
        end
        state.currentRows, state.allRows = {}, {}
        return completed
    end
    local dropCount = #state.allRows > 0 and #state.allRows or #state.currentRows
    local rowLimit = state.settings and state.settings.maxSessionRows or DEFAULTS.maxSessionRows
    local rows = Core.OrderRowsChronologically(copyList(state.currentRows))
    local allRows = Core.OrderRowsChronologically(copyList(state.allRows))
    pruneListStart(rows, rowLimit)
    pruneListStart(allRows, rowLimit)

    local group = {
        title = groupTitle(groupMeta, dropCount),
        instanceName = groupMeta.instanceName,
        encounterName = groupMeta.encounterName,
        dropCount = dropCount,
        startedAt = groupMeta.startedAt,
        endedAt = groupMeta.endedAt,
        rows = rows,
        allRows = allRows,
    }

    local latest
    local closestDistance
    for index = 1, #(state.history or {}) do
        local existing = state.history[index]
        if matchingRecentHistoryGroup(existing, groupMeta) then
            local distance = math.abs(tonumber(groupMeta.endedAt) - tonumber(existing.endedAt))
            if not closestDistance or distance < closestDistance then
                latest, closestDistance = existing, distance
            end
        end
    end
    if latest then
        latest.rows = appendUniqueRows(latest.rows, rows)
        latest.allRows = appendUniqueRows(latest.allRows, allRows)
        pruneListStart(latest.rows, rowLimit)
        pruneListStart(latest.allRows, rowLimit)
        latest.instanceName = latest.instanceName or group.instanceName
        latest.encounterName = latest.encounterName or group.encounterName
        local oldStart, newStart = asNumber(latest.startedAt, nil), asNumber(group.startedAt, nil)
        local oldEnd, newEnd = asNumber(latest.endedAt, nil), asNumber(group.endedAt, nil)
        latest.startedAt = oldStart and newStart and math.min(oldStart, newStart) or oldStart or newStart
        latest.endedAt = oldEnd and newEnd and math.max(oldEnd, newEnd) or oldEnd or newEnd
        local mergedDropCount = #latest.allRows > 0 and #latest.allRows or #latest.rows
        latest.dropCount = mergedDropCount
        latest.title = groupTitle({
            instanceName = latest.instanceName,
            encounterName = latest.encounterName,
            title = latest.title,
            locale = groupMeta.locale,
        }, mergedDropCount)
        state.currentRows = {}
        state.allRows = {}
        return latest
    end

    -- Late item metadata must not evict more recent encounters at the cap.
    local position = 1
    local endedAt = asNumber(group.endedAt, nil)
    if endedAt then
        while position <= #state.history do
            local existingEnd = asNumber(state.history[position].endedAt, nil)
            if not existingEnd or existingEnd <= endedAt then break end
            position = position + 1
        end
    end
    table.insert(state.history, position, group)
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
    if row.askable == false or Core.IsHiddenLootRow(row) then
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

function Core.GetWhisperButtonState(_selectedTab, selectedView, row)
    local state = {
        visible = false,
        enabled = false,
        text = "Ask",
    }
    if selectedView ~= "current" or type(row) ~= "table" or row.askable == false or Core.IsHiddenLootRow(row) then
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

function Core.ShouldAutoShowWindow(row, context)
    if type(row) ~= "table" or row.itemLink == nil or row.itemLink == "" then
        return false
    end
    if type(context) == "table" and context.forceAutoShow == true then
        return true
    end
    return type(context) == "table" and context.isGroupInstance == true
end

-- Real item IDs; trade and equipment states below are illustrative, not loot predictions.
function Core.BuildDemoRows(settings, timestamp)
    local items = {
        {281239, "Corroded Hulk's Skullcap", "INVTYPE_HEAD", "raid"},
        {281238, "Aberrant Commander's Gauntlets", "INVTYPE_HAND", "raid"},
        {281236, "Chestwrap of Palpable Terror", "INVTYPE_CHEST", "raid"},
        {280617, "Lightbearer's Shield Fragment", "INVTYPE_TRINKET", "raid"},
        {280835, "Sigil of the Impending Eclipse", "INVTYPE_TRINKET", "raid"},
        {281056, "Sanctified Knight's Phoenixblade", "INVTYPE_WEAPON", "raid"},
        {250215, "Freightrunner's Flask", "INVTYPE_TRINKET", "dungeon"},
        {250243, "Manaheart's Binding Flame", "INVTYPE_TRINKET", "dungeon"},
        {281029, "Band of the Swarmcaller", "INVTYPE_FINGER", "raid"},
        {281215, "Twisted Horror's Tendril", "INVTYPE_TRINKET", "raid"},
        {281235, "Voidweaver's Leggings", "INVTYPE_LEGS", "raid"},
        {280799, "Lu'selama, Light's Justice", "INVTYPE_2HWEAPON", "raid"},
    }
    local function link(item)
        return "|cffa335ee|Hitem:" .. item[1] .. ":::::::::::::|h[" .. item[2] .. "]|h|r"
    end
    local demo = Core.CreateState(settings)
    local names = {"Aeloria", "Бранн", "Selene", "Torvald", "Mira", "Kaelin"}
    local classes = {"MAGE", "WARRIOR", "DRUID", "PALADIN", "PRIEST", "HUNTER"}
    for index, item in ipairs(items) do
        local askable = index % 3 ~= 2 and index ~= 4
        local equipped
        if item[3] == "INVTYPE_FINGER" then
            equipped = "Equipped: " .. link(item) .. " / " .. link({251136, "Signet of Snarling Servitude"})
        elseif item[3] == "INVTYPE_TRINKET" then equipped = "Cached: " .. link(items[7]) .. " / " .. link(items[8])
        elseif index == 11 then equipped = "Equipped: unknown"
        else equipped = "Equipped: " .. link(item) end
        Core.AddVisibleRow(demo, {
            isTest = true, looter = names[(index - 1) % #names + 1],
            classToken = classes[(index - 1) % #classes + 1],
            itemID = item[1], itemLink = link(item), equipLoc = item[3],
            instanceName = item[4] == "raid" and "The Unbinding of Kith'ix" or "Murder Row",
            encounterName = item[4] == "raid" and "Kith'ix" or (index == 7 and "Zaen Bladesorrow" or "Kystia Manaheart"),
            timestamp = timestamp, reason = index == 4 and "not_tradeable" or (askable and "test row" or "bind_on_pickup"),
            statusKey = index == 4 and "not_tradeable" or (askable and "test_row" or "bind_on_pickup"), equippedText = equipped,
            tradeStatusKey = index == 4 and "trade_no" or (index == 7 and "trade_confirmed" or (not askable and "trade_unknown" or "trade_likely")),
            unsafe = false,
        }, askable)
    end
    return demo.allRows
end

_G.DoYouNeedItCore = Core
