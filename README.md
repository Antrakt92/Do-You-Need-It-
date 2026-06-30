# Do You Need It?

Do You Need It? is a small Retail World of Warcraft addon that helps you review likely-tradeable group gear drops and ask the looter if they need the item.

The addon focuses on quiet signal:

- shows likely-tradeable equipment drops only;
- hides currency, reagents, recipes, consumables, quest items, and other non-gear loot;
- shows the dropped item next to the looter's currently equipped item when inspection data is safely available;
- keeps a lightweight history for the current view, the last 50 saved session drops, and the last 10 completed boss/run groups;
- sends whispers only from row actions unless auto-whisper is explicitly enabled.
- includes an in-window auto-whisper checkbox and delay slider.
- uses a compact loot window that appears automatically when a new trade-candidate gear drop is detected.

## Commands

| Command | Action |
|---|---|
| `/dyni` | Toggle the loot window. |
| `/duni` | Same as `/dyni`; short alias for the addon commands. |
| `/dyni auto on` | Enable delayed auto-whisper. |
| `/dyni auto off` | Disable auto-whisper. |
| `/dyni delay <seconds>` | Set auto-whisper delay, clamped to 3-30 seconds. |
| `/dyni clear` | Clear current live/session rows while keeping saved history. |
| `/dyni history` | Cycle the history view. |
| `/duni test` | Add a local test row and auto-show the compact window. |
| `/dyni debug on` | Print loot-processing diagnostics and save the last 20 diagnostic entries. |
| `/dyni diag` | Print the newest saved diagnostic entries. |
| `/dyni status` | Print current settings, build, and layout. |

Auto-whisper is off by default. When enabled, it waits 10 seconds by default before sending, and pending sends are cancelled if you manually ask first, clear current rows, or turn auto-whisper off.

The loot window also has an auto-whisper checkbox and a 3-30 second delay slider next to it, so you do not need slash commands for normal adjustments.

If you are checking whether the latest addon code loaded, run `/dyni status` and confirm it reports `build=0.1.8`, `session drops=...`, and `layout=460x310`, then run `/duni test` to force a compact auto-show test row. For live loot debugging, run `/dyni debug on` before a boss or dungeon chest and `/dyni diag` afterward.

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
