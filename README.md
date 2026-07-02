# Do You Need It?

Do You Need It? is a Retail World of Warcraft addon for Midnight 12.x. It tracks likely-tradeable Mythic+ and raid gear drops, compares the drop with the looter's equipped item, and helps you ask with optional delayed whispers.

The addon focuses on quiet signal:

- Shows likely-tradeable equipment drops only.
- Separates the default askable loot list from an `All Gear` tab that records every visible gear drop.
- Keeps `Askable` focused on gear your current character can use or wear.
- Hides currency, reagents, recipes, consumables, quest items, and other non-gear loot.
- Shows the dropped item next to the looter's currently equipped item when inspection data is safely available, retrying briefly when inspection data is delayed.
- Pre-scans group equipment into a session cache, then shows `Cached:` equipped items if live inspection is blocked or delayed.
- Shows real item tooltips when you hover dropped or equipped item links in the loot window.
- Colors looter names by class when roster data is available.
- Keeps Cyrillic player names readable with dynamic font fallback even when the selected UI font lacks those glyphs.
- Keeps a lightweight history for the current view, the last 50 saved session drops, and the last 10 completed boss/run groups.
- Sends whispers only from row actions unless auto-whisper is explicitly enabled.
- Includes a settings gear with auto-whisper, delay, whisper text, language, font, and font-size controls.
- Previews language and font choices on hover, then rolls back if you close the picker without selecting.
- Uses a compact loot window with separated title, tabs, history, and settings controls.

## Commands

| Command | Action |
|---|---|
| `/dyni` | Toggle the loot window. |
| `/dyni settings` | Open the settings window. |
| `/dyni auto on` | Enable delayed auto-whisper. |
| `/dyni auto off` | Disable auto-whisper. |
| `/dyni delay <seconds>` | Set auto-whisper delay, clamped to 3-30 seconds. |
| `/dyni clear` | Clear current live/session rows while keeping saved history. |
| `/dyni history` | Cycle the history view. |
| `/dyni scan` | Queue a manual group equipment pre-scan. |
| `/dyni test` | Add a local test row and auto-show the compact window. |
| `/dyni debug on` | Save the last 20 loot-processing diagnostic entries. |
| `/dyni diag` | Print the newest saved diagnostic entries. |
| `/dyni status` | Print current settings, build, and layout. |

Auto-whisper is off by default. When enabled, it waits 10 seconds by default before sending, and pending sends are cancelled if you manually ask first, clear current rows, or turn auto-whisper off.

The loot window opens on the `Askable` tab by default. `Askable` only shows drops that the addon currently considers worth asking about and usable by your current character; `All Gear` shows every visible gear drop for review and hides the Ask button. If a drop has visible gear but no askable rows, the window opens directly on `All Gear` so the drop is not silent. Use the gear button or `/dyni settings` for auto-whisper, delay, whisper text, language, font, and font-size controls.

Language defaults to `Auto`, which follows your WoW client locale. You can also force English (`enUS`), German (`deDE`), Spanish (`esES`/`esMX`), French (`frFR`), Italian (`itIT`), Brazilian Portuguese (`ptBR`), Russian (`ruRU`), Korean (`koKR`), Simplified Chinese (`zhCN`), or Traditional Chinese (`zhTW`). English and Russian currently have the most complete addon-specific text; other locales cover the core settings labels and fall back to English for unreviewed addon labels.

Font choices use bundled LibSharedMedia support plus Blizzard fallbacks. Hovering a language or font previews it live, closing the picker without selecting restores the saved setting, and loot-row names can temporarily fall back to glyph-capable fonts such as Arial Narrow for Cyrillic names.

If you are checking whether the latest addon code loaded, run `/dyni status` and confirm it reports `build=0.2.2`, `session drops=...`, `all gear=...`, `cache=...`, and `layout=540x300`, then run `/dyni scan` before a dungeon to pre-cache group equipment. `/dyni test` forces a compact auto-show test row without a chat confirmation. Hover the dropped item or equipped item text to confirm the normal item tooltip appears, then switch to `All Gear` to confirm the bound test item appears without an Ask button. For live loot debugging, run `/dyni debug on` before a boss or dungeon chest and `/dyni diag` afterward; inspect/cache problems are reported as `inspect_retry`, `inspect_failed`, `scan_retry`, or `scan_failed`.

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

The package is written to `dist\DoYouNeedIt-<version>.zip` with `DoYouNeedIt/` as the zip root. It includes the addon TOC, Lua files, bundled runtime libraries, README, changelog, license, and third-party notices, while excluding tests, scripts, and local development files. The main check script also validates this package shape.

Upload a prepared package to CurseForge with:

```powershell
$env:CURSEFORGE_API_TOKEN = "<token from CurseForge>"
.\scripts\upload-curseforge.ps1
```

The upload script reads `## X-Curse-Project-ID`, `## Version`, and `## Interface` from the TOC, uses the top matching `CHANGELOG.md` entry, and sends the package through CurseForge's upload API. Run `.\scripts\upload-curseforge.ps1 -DryRun` to inspect the metadata without uploading.

## License

MIT. This project is intended to be freely modifiable and redistributable under the license terms.
