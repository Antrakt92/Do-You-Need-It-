# Do You Need It?

Compare dungeon and raid gear drops with the looter's equipped items, review recent loot, and use **Ask** to send a whisper. Automatic whispers are optional and off by default.

[Install on CurseForge](https://www.curseforge.com/wow/addons/do-you-need-it) · [Download the latest ZIP](https://github.com/Antrakt92/Do-You-Need-It-/releases/latest) · [Report a problem](https://github.com/Antrakt92/Do-You-Need-It-/issues)

For World of Warcraft Retail / Midnight 12.x. The current package supports 12.1.0 and the 12.1.5 PTR.

## Install

Install through CurseForge, or extract the `DoYouNeedIt-<version>.zip` release asset into `World of Warcraft/_retail_/Interface/AddOns/`. The resulting folder must be named `DoYouNeedIt` and contain `DoYouNeedIt.toc` directly inside it.

Run `/reload`, then `/dyni` to open the window. `/dyni status` should report `build=0.6.0`. Use `/dyni test` to preview sample rows; these cannot send whispers and are not saved to your history.

## Loot and comparison

- One list shows group gear drops, including your own and bonus loot. Non-gear loot and known warband/account-bound items are hidden.
- **Dropped**, **Equipped now**, and **Trade** columns show the item, the looter's equipment, and its estimated transfer status. Hover item links for tooltips; paired rings, trinkets, and weapons each have their own target.
- **Ask** appears only on eligible drops your character can use. It does not mean the item is an upgrade for you.
- Equipment comparisons use live inspection when available, with items labelled **Cached:** when using an earlier scan. `/dyni scan` queues a group equipment scan before a dungeon or raid.
- History is saved per character: up to 50 session drops and 10 completed boss/run groups. New drops preserve your reading position; **New loot** returns to incoming drops.

### What Trade means

| Status | Meaning |
|---|---|
| **Yes** | A trade timer was detected. |
| **Likely** | Bind-on-equip/use gear, or personal loot whose item level is no higher than the looter's inspected gear in the same slot. |
| **Unknown** | The addon cannot determine whether the item can be traded. |
| **No** | A transfer restriction was detected. |

WoW does not expose another player's final personal-loot eligibility. **Likely** is an estimate; the looter must confirm. Inspection also depends on range, combat state, throttling, and item data availability. Old saved records are retained even when they are filtered out of the window.

## Whispers and settings

Open the gear button or `/dyni settings` to change whispers, language, font, and font size. The window remembers its position, closes with Escape, and can be centered with **Reset Position**.

Auto-whisper is **off by default**. If enabled, it waits 10 seconds by default; the delay can be set from 3 to 30 seconds. A pending whisper is cancelled when you ask manually, clear the current rows, disable auto-whisper, or the looter leaves the group.

Use `{item}` in a custom message, for example: `Hey, do you need {item}?` If the completed message is too long or contains invalid characters, the row explains the problem. Edit the message and use Ask again.

Language defaults to **Auto**, following your client locale. English and Russian have the most complete text. German, Spanish (Spain/Mexico), French, Italian, Brazilian Portuguese, Korean, and Simplified/Traditional Chinese are selectable, with English fallback for untranslated labels. Font and language pickers preview on hover and restore the saved choice if closed without a selection. Bundled LibSharedMedia and Blizzard fonts provide font choices and Cyrillic fallback.

## Commands

| Command | Action |
|---|---|
| `/dyni` | Toggle the loot window. |
| `/dyni settings` | Open settings. |
| `/dyni auto on` / `/dyni auto off` | Enable or disable automatic whispers. |
| `/dyni delay <seconds>` | Set the delay, clamped to 3–30 seconds. |
| `/dyni clear` | Clear current live/session rows while keeping saved history. |
| `/dyni resetpos` | Center the window without resetting settings or history. |
| `/dyni history` | Cycle history views. |
| `/dyni scan` | Queue a group equipment scan. |
| `/dyni test` | Preview sample rows without whispers or saved demo loot. |
| `/dyni status` | Print settings, build, and layout. |
| `/dyni debug on` | Save the last 20 loot-processing diagnostic entries. |
| `/dyni debug off` | Stop saving diagnostic entries and clear saved diagnostics. |
| `/dyni diag` | Print the newest diagnostic entries. |
| `/dyni selftest` | Run a self-check and print a chat summary. |

## Help and development

For a loot problem, enable `/dyni debug on` before the drop, then collect `/dyni diag` and `/dyni status`. Include the client language, addon version, steps to reproduce, and any Lua error in a [bug report](https://github.com/Antrakt92/Do-You-Need-It-/issues). Remove player names or other personal details you do not want to share.

See [CONTRIBUTING.md](https://github.com/Antrakt92/Do-You-Need-It-/blob/main/CONTRIBUTING.md) for development checks and packaging.

## License

The addon code is [MIT licensed](LICENSE). Bundled libraries retain their own licenses; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and the included `LICENSES/` directory.
