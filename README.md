# Do You Need It?

Do You Need It? is a small Retail World of Warcraft addon that helps you review likely-tradeable group gear drops and ask the looter if they need the item.

The addon focuses on quiet signal:

- shows likely-tradeable equipment drops only;
- separates the default askable loot list from an `All Gear` tab that records every visible gear drop;
- keeps `Askable` focused on gear your current character can use or wear;
- hides currency, reagents, recipes, consumables, quest items, and other non-gear loot;
- shows the dropped item next to the looter's currently equipped item when inspection data is safely available, retrying briefly when inspection data is delayed;
- shows real item tooltips when you hover dropped or equipped item links in the loot window;
- keeps a lightweight history for the current view, the last 50 saved session drops, and the last 10 completed boss/run groups;
- sends whispers only from row actions unless auto-whisper is explicitly enabled.
- includes an in-window auto-whisper checkbox and delay slider.
- uses a compact loot window that appears automatically when a new trade-candidate gear drop is detected.

## Commands

| Command | Action |
|---|---|
| `/dyni` | Toggle the loot window. |
| `/dyni auto on` | Enable delayed auto-whisper. |
| `/dyni auto off` | Disable auto-whisper. |
| `/dyni delay <seconds>` | Set auto-whisper delay, clamped to 3-30 seconds. |
| `/dyni clear` | Clear current live/session rows while keeping saved history. |
| `/dyni history` | Cycle the history view. |
| `/dyni test` | Add a local test row and auto-show the compact window. |
| `/dyni debug on` | Print loot-processing diagnostics and save the last 20 diagnostic entries. |
| `/dyni diag` | Print the newest saved diagnostic entries. |
| `/dyni status` | Print current settings, build, and layout. |

Auto-whisper is off by default. When enabled, it waits 10 seconds by default before sending, and pending sends are cancelled if you manually ask first, clear current rows, or turn auto-whisper off.

The loot window opens on the `Askable` tab by default. `Askable` only shows drops that the addon currently considers worth asking about and usable by your current character; `All Gear` shows every visible gear drop for review and hides the Ask button. If a drop has visible gear but no askable rows, the window opens directly on `All Gear` so the drop is not silent. The window also has an auto-whisper checkbox and a 3-30 second delay slider next to it, so you do not need slash commands for normal adjustments.

If you are checking whether the latest addon code loaded, run `/dyni status` and confirm it reports `build=0.1.13`, `session drops=...`, `all gear=...`, and `layout=460x310`, then run `/dyni test` to force a compact auto-show test row. Hover the dropped item or equipped item text to confirm the normal item tooltip appears, then switch to `All Gear` to confirm the bound test item appears without an Ask button. For live loot debugging, run `/dyni debug on` before a boss or dungeon chest and `/dyni diag` afterward; inspect problems are reported as `inspect_retry` or `inspect_failed`.

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

The check script runs the Lua regression tests, Lua 5.1 syntax checks, and a public-source leakage guard.

## License

MIT. This project is intended to be freely modifiable and redistributable under the license terms.
