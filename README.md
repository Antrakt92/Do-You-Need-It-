# Do You Need It?

Compare dungeon and raid gear drops with the looter's equipped items, review recent loot, and use **Ask** to send a whisper. Automatic whispers are optional and off by default.

[CurseForge](https://www.curseforge.com/wow/addons/do-you-need-it) · [GitHub Releases](https://github.com/Antrakt92/Do-You-Need-It-/releases/latest) · [Report a problem](https://github.com/Antrakt92/Do-You-Need-It-/issues)

**1.0 is the first stable release.** Existing settings and loot history carry forward. For World of Warcraft Retail / Midnight 12.1.5.

**WoW Forever beta has a separate build:**
[Forever release](https://github.com/Antrakt92/Do-You-Need-It-/releases/tag/forever-v1.1.0)
for Forever 1.60.1 (Interface 16001). Retail and Forever update independently.
The screenshots below show Retail.

![Real raid loot and equipped-item comparisons](https://raw.githubusercontent.com/Antrakt92/Do-You-Need-It-/v1.0.0/screenshots/loot-comparison.png)

<details>
<summary>More in-game screenshots: bonus loot, Settings, fonts and languages</summary>

![Bonus loot and transfer-status labels](https://raw.githubusercontent.com/Antrakt92/Do-You-Need-It-/v1.0.0/screenshots/bonus-loot.png)

![Whisper and appearance settings](https://raw.githubusercontent.com/Antrakt92/Do-You-Need-It-/v1.0.0/screenshots/settings.png)

![Font choices and favorites](https://raw.githubusercontent.com/Antrakt92/Do-You-Need-It-/v1.0.0/screenshots/font-picker.png)

![Language menu with native names](https://raw.githubusercontent.com/Antrakt92/Do-You-Need-It-/v1.0.0/screenshots/language-picker.png)

</details>

## Quality filter

Open Settings to choose which item qualities appear using the checkboxes on
the right. Each checkbox is independent: you can keep green
and purple gear while hiding blue gear. The same selection applies to current
loot, session history, saved encounters and Demo, and is saved across reloads.
Green and higher qualities are shown by default; gray and white can be enabled.
Hidden gear remains in retained history and reappears when enabled. Hidden
qualities never open the window or start automatic whispers; showing an old row
again does not send a delayed whisper. Non-equipment loot remains excluded.
The filter is shared by Retail and Forever. Settings uses the same compact
window size as the loot view. Drag the lower-right corner to resize the window;
columns and the number of visible loot rows adapt, and your size is saved across
reloads. Switching between Settings and loot keeps the same dimensions.

## Try the window

Type `/dyni` to open the window. Click **Demo** to preview sample gear, then
**Exit demo** to return to your loot. Demo rows send no whispers and are not
saved to history.

For troubleshooting, `/dyni status` shows the build; the current Retail build
reports `build=1.1.0`.

### Forever beta

Forever uses the same `/dyni` commands, Settings, fonts, history and opt-in whispers.

Forever comparisons include the separate ranged/relic slot. Player usability
comes from the beta client, including learned proficiencies and level restrictions;
no Retail armor-specialization filter is applied. Real drops use the beta's item,
instance and encounter names. Demo examples use Classic-era item IDs with names
resolved from the client, and do not describe a beta dungeon's loot table.
Only items with resolved client names and hyperlinks are shown; unavailable
examples are omitted. Your equipped gear can supply additional beta examples.

Forever does not use Retail's personal-loot item-level transfer estimate.
BoP items remain **Check with looter** unless a trade timer is detected; BoE,
unbound and bind-on-use items retain the binding-based **Likely** estimate.
Startup after reload, command registration, saved settings, window geometry and
demo rendering passed the client self-check on Interface 16001. Real group loot,
inspection timing, combat and whisper delivery still need beta coverage.
Other Classic branches are not supported by this package. See the
[Forever changelog](CHANGELOG-FOREVER.md) for its separate release history.

## Loot and comparison

- One list shows group gear drops, including your own and bonus loot. Non-gear loot and known warband/account-bound items are hidden.
- **Dropped**, **Equipped now**, and **Trade** columns show the item, the looter's equipment, and its estimated transfer status. Hover item links for tooltips; paired rings, trinkets, and weapons each have their own target.
- **Ask** appears only on eligible drops your character can use. It does not mean the item is an upgrade for you.
- Equipment comparisons use live inspection when available, with items labelled **Cached:** when using an earlier scan. `/dyni scan` queues a group equipment scan before a dungeon or raid.
- The history selector lists encounters with their instance, date, and drop count. Scroll the menu to browse older runs; hover an entry for its full name.
- History is saved per character: up to 50 session drops and 10 completed boss/run groups. New drops preserve your reading position; **New loot** returns to incoming drops.

### What Trade means

| Status | Meaning |
|---|---|
| **Yes** | A trade timer was detected. |
| **Likely** | Bind-on-equip/use gear, or personal loot whose item level is no higher than the looter's inspected gear in the same slot. |
| **Check with looter** | Ask the player who received the item whether they can trade it; the addon has no confirmation. |
| **No** | A transfer restriction was detected. |

WoW does not expose another player's final personal-loot eligibility. **Likely** is an estimate; the looter must confirm. Inspection also depends on range, combat state, throttling, and item data availability. Old saved records are retained even when they are filtered out of the window.

## Whispers and settings

Open the gear button or `/dyni settings` to change whispers, language, font, and font size. The gear becomes a return arrow in Settings; click it to return to loot. The window remembers its position, closes with Escape, and can be centered with `/dyni resetpos`.

Auto-whisper is **off by default**. If enabled, it waits 10 seconds by default; the delay can be set from 3 to 30 seconds. A pending whisper is cancelled when you ask manually, clear the current rows, disable auto-whisper, or the looter leaves the group.

Use `{item}` in a custom message, for example: `Hey, do you need {item}?` If the completed message is too long or contains invalid characters, the row explains the problem. Edit the message and use Ask again.

Language defaults to **Auto**, following your client locale. Settings and loot-status labels are translated into English, Russian, German, Spanish (Spain/Latin America), French, Italian, Brazilian Portuguese, Korean, and Simplified/Traditional Chinese. Language names use their native spelling.

The addon includes 46 fonts alongside available LibSharedMedia and Blizzard fonts. The picker shows available faces compatible with your selected language; star your favorites to keep them first. Font and language hover previews restore the saved choice when dismissed. Menus open beside their fields and stay above the window.

The heart and feedback buttons in the title bar open copyable links to support the addon or report a problem on GitHub.

## Commands

| Command | Action |
|---|---|
| `/dyni` | Toggle the loot window. |
| `/dyni settings` | Open settings. |
| `/dyni auto on` / `/dyni auto off` | Enable or disable automatic whispers. |
| `/dyni clear` | Clear current live/session rows while keeping saved history. |
| `/dyni resetpos` | Center the window without resetting settings or history. |
| `/dyni history` | Cycle history views. |
| `/dyni scan` | Queue a group equipment scan. |
| `/dyni selftest` | Run a self-check and open a copyable report. Close Settings first to include the demo-row check. |
| `/dyni selftest show` | Reopen the last saved self-check report. |

<details>
<summary>Diagnostics and advanced commands</summary>


| Command | Action |
|---|---|
| `/dyni test` | Toggle the same 12-item preview as the Demo button. Trade and equipment states are illustrative. |
| `/dyni debug on` | Save the last 20 loot-processing diagnostic entries. |
| `/dyni debug off` | Stop saving diagnostic entries and clear saved diagnostics. |
| `/dyni diag` | Print the newest diagnostic entries. |
| `/dyni fontdiag` | Record a small font-loading report; `/reload` saves it for troubleshooting. |
| `/dyni status` | Print settings, build, and layout. |
| `/dyni delay <seconds>` | Set the delay, clamped to 3–30 seconds. |

</details>

## Help and development

For a loot problem, enable `/dyni debug on` before the drop, then collect `/dyni diag` and `/dyni status`. Include the client language, addon version, steps to reproduce, and any Lua error in a [bug report](https://github.com/Antrakt92/Do-You-Need-It-/issues). Remove player names or other personal details you do not want to share.

See [CONTRIBUTING.md](https://github.com/Antrakt92/Do-You-Need-It-/blob/main/CONTRIBUTING.md) for development checks and packaging.

## More by Antrakt
- [StatsPro](https://www.curseforge.com/wow/addons/statspro) — customizable stats and gear HUD
- [ApplicantScout](https://www.curseforge.com/wow/addons/applicantscout-lfg-overlay) — LFG & Party overlay with WCL and RaiderIO context

## License

Do You Need It? is free to use. Future copies carrying the [Antrakt Attribution and CurseForge Rewards License 1.3](https://github.com/Antrakt92/Do-You-Need-It-/blob/main/LICENSE) may be modified and shared without asking first.

For a public fork, port or substantial reuse of my original feature code, keep the license, credit **antrakt92**, and name and link to [Do You Need It?](https://www.curseforge.com/wow/addons/do-you-need-it). If that derivative earns CurseForge Reward Points, allocate a **positive share of that project's points** to `antrakt92` through Members. You choose the percentage, considering the extent and significance of the reused work; there is no fixed minimum. One share covers all my projects reused in it. No points earned means no payment. Personal income, donations and other revenue are excluded. Permission applies automatically: no prior contact, negotiation or approval is needed, and contacting me is optional. A pending Members invitation awaiting my acceptance does not block permission.

Small snippets, independent code and translations, compatibility patches, dependencies and collection links require no share by themselves. Earlier grants remain; this permission replaces my fixed-minimum and separate-share requirements in all earlier custom versions with the same self-selected positive share. Other earlier terms, MIT grants and third-party rights remain unchanged. [Third-party material](https://github.com/Antrakt92/Do-You-Need-It-/blob/main/THIRD-PARTY-NOTICES.md) keeps its own terms.
