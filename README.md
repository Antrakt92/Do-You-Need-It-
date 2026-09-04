# Do You Need It?

Do You Need It? is a Retail World of Warcraft addon for Midnight 12.x, currently packaged for Retail 12.0.7 and 12.1.0. It tracks likely-tradeable Mythic+ and raid gear drops, compares the drop with the looter's equipped item, and helps you ask with optional delayed whispers.

The addon focuses on quiet signal:

- Shows grouped dungeon/raid gear drops in one compact scrollable list, including own loot and bonus loot, while hiding known warband/account-bound items.
- Shows the `Ask` action only on rows that look worth asking for and usable by your current character.
- Hides currency, reagents, recipes, consumables, quest items, and other non-gear loot.
- Clearly labels the dropped item and the looter's currently equipped item in separate columns, using live inspection when safely available and retrying briefly when inspection data is delayed.
- Shows an honest transfer status for every gear row: confirmed by a trade timer, likely for fresh bind-on-equip/use gear, unavailable when explicitly blocked, or unknown when WoW does not expose another player's personal-loot eligibility.
- Pre-scans group equipment into a session cache, then shows `Cached:` equipped items if live inspection is blocked or delayed.
- Shows real item tooltips when you hover dropped or equipped item links in the loot window.
- Colors looter names by class when roster data is available.
- Keeps Cyrillic player names readable with dynamic font fallback even when the selected UI font lacks those glyphs.
- Keeps per-character lightweight history for the current view, the last 50 saved session drops, and the last 10 completed boss/run groups.
- Sends whispers only from row actions unless auto-whisper is explicitly enabled.
- Includes a settings gear with auto-whisper, delay, whisper text, language, font, and font-size controls.
- Previews language and font choices on hover, then rolls back if you close the picker without selecting.
- Uses a compact loot window with clear row separators, transfer colors, and separate Whispers and Appearance settings.
- Expands the settings window to fit every control, keeps drafts open when loot arrives, and supports Escape to close.
- Keeps local demo rows separate from real loot history and whispers.
- Preserves the history view and reading position when more loot arrives, with a shortcut back to new loot.
- Remembers the window position between reloads, offers Reset Position in settings, and adapts visible row count to your chosen font size.
- Gives each compared ring, trinket, or weapon its own tooltip and click target.

## Commands

| Command | Action |
|---|---|
| `/dyni` | Toggle the loot window. |
| `/dyni settings` | Open the settings view inside the loot window. |
| `/dyni auto on` | Enable delayed auto-whisper. |
| `/dyni auto off` | Disable auto-whisper. |
| `/dyni delay <seconds>` | Set auto-whisper delay, clamped to 3-30 seconds. |
| `/dyni clear` | Clear current live/session rows while keeping saved history. |
| `/dyni resetpos` | Center the window without resetting your settings or history. |
| `/dyni history` | Cycle the history view. |
| `/dyni scan` | Queue a manual group equipment pre-scan. |
| `/dyni test` | Show local comparison examples with disabled Ask buttons; sends no chat and saves no demo loot. |
| `/dyni debug on` | Save the last 20 loot-processing diagnostic entries. |
| `/dyni diag` | Print the newest saved diagnostic entries. |
| `/dyni status` | Print current settings, build, and layout. |

Auto-whisper is off by default. When enabled, it waits 10 seconds by default before sending, and pending sends are cancelled if you manually ask first, clear current rows, or turn auto-whisper off.

Automatic messages are also cancelled when the looter leaves your group. Messages are validated after inserting the item link; if a template produces an oversized or invalid message, the row explains that it needs editing and Ask remains retryable.

The loot window uses one unified list. Known warband/account-bound gear is hidden because it cannot be passed to another group member. Unknown personal-loot transfer eligibility stays visible. The `Ask` button appears only on rows that the addon currently considers worth asking about and usable by your current character. Bonus loot, your own loot, and other review-only drops stay visible without pointless Ask buttons. Existing saved records are preserved even when filtered out of the window. Use the gear button or `/dyni settings` to adjust whispers and appearance.

The `Dropped`, `Equipped now`, and `Trade` columns keep the comparison explicit. `Trade: yes` means a trade timer was detected, while `Trade: likely` covers gear that is normally transferable until equipped or used, including personal loot whose item level is no higher than the inspected gear in the same slot. `Trade: unknown` is deliberately conservative: WoW does not expose another player's final personal-loot eligibility to addons, so the looter still needs to confirm.

Incoming drops keep recording while you edit settings or read history. Use Back to return to the loot list and **New loot** to jump to incoming drops when ready. The window stays within the screen when dragged, remembers its position after reload, and closes with Escape. Use **Reset Position** in settings or `/dyni resetpos` to center it. `/dyni test` temporarily previews two examples; real loot replaces the preview, and `/dyni history` returns to your recorded drops.

## Language and Fonts

Language defaults to `Auto`, which follows your WoW client locale. You can also force a locale from settings:

| Language | Locale |
|---|---|
| Auto | Current WoW client locale |
| English | `enUS` |
| Deutsch | `deDE` |
| Español | `esES`, `esMX` |
| Français | `frFR` |
| Italiano | `itIT` |
| Português do Brasil | `ptBR` |
| Русский | `ruRU` |
| 한국어 | `koKR` |
| 中文 简体 | `zhCN` |
| 中文 繁體 | `zhTW` |

English and Russian currently have the most complete addon-specific text. Other locales cover the core settings labels and fall back to English for unreviewed addon labels.

Font choices use bundled LibSharedMedia support plus Blizzard fallbacks. Hovering a language or font previews it live, closing the picker without selecting restores the saved setting, and loot-row names can temporarily fall back to glyph-capable fonts such as Arial Narrow for Cyrillic names. Russian settings also replace saved Latin-only fonts with a Cyrillic-capable fallback.

## Quick In-Game Check

After installing a new build:

1. Run `/reload`.
2. Run `/dyni status` and confirm it reports `build=0.5.0`, `session drops=...`, `all gear=...`, `cache=...`, and `layout=540x300`.
3. Run `/dyni scan` before a dungeon to pre-cache group equipment.
4. Run `/dyni test`, hover the dropped and equipped item text, and confirm the bound test item appears in the same list without an Ask button.
5. For live loot debugging, run `/dyni debug on` before a boss or dungeon chest and `/dyni diag` afterward. Inspect/cache problems appear as `inspect_retry`, `inspect_failed`, `scan_retry`, or `scan_failed`.

## Install

Copy this folder to:

```text
World of Warcraft/_retail_/Interface/AddOns/DoYouNeedIt
```

Then reload the game UI with `/reload`.

## Development Checks

Run from the repository root:

```powershell
.\scripts\check.ps1
```

The check script runs the Lua regression tests, Lua 5.1 syntax checks, package-shape validation, CurseForge upload dry-run metadata validation, and a public-source leakage guard. If `lua5.1` or `luac5.1` are missing on a Windows machine, run:

```powershell
.\scripts\install-check-tools.ps1 -Install
```

Build a local addon zip with:

```powershell
.\scripts\package.ps1
```

The package is written to `dist\DoYouNeedIt-<version>.zip` with `DoYouNeedIt/` as the zip root. It includes the addon TOC, Lua files, bundled runtime libraries, addon-list icon, README, changelog, license, and third-party notices, while excluding tests, scripts, and local development files. The main check script also validates this package shape.

Upload a prepared package to CurseForge with:

```powershell
$env:CURSEFORGE_API_TOKEN = "<token from CurseForge>"
.\scripts\upload-curseforge.ps1
```

The upload script rebuilds the default `dist\DoYouNeedIt-<version>.zip`, reads `## X-Curse-Project-ID`, `## Version`, and `## Interface` from the TOC, uses the top matching `CHANGELOG.md` entry, and sends the package through CurseForge's upload API. Pass `-ZipPath` only when you intentionally want to upload a specific prepared archive. Run `.\scripts\upload-curseforge.ps1 -DryRun` to inspect the metadata without uploading.

## License

MIT. This project is intended to be freely modifiable and redistributable under the license terms.
