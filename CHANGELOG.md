# Changelog

## 0.3.0 - 02-Jul-2026 — Askable filters, bonus loot, and history reliability

### Added

- **Bonus-roll loot is now marked in the loot window and history** — when WoW exposes bonus loot for you or another group member, Do You Need It? shows a small roll icon and saves that source with the drop.
- **The addon now has its own WoW AddOn List icon** — the in-game AddOn List shows the Do You Need It? icon instead of the default question-mark placeholder.

### Improved

- **Saved loot history is now per character** — alts no longer share the same recent dungeon and boss drop history.
- **`Current` stays useful after boss or dungeon completion** — if live loot has already been finalized into history, the Current view falls back to the latest completed drop group instead of showing an empty panel.
- **`All Gear` now includes your own drops for review** — your loot appears in All Gear, while Askable remains focused on items worth asking other players about.
- **`Askable` now follows player equip eligibility instead of upgrade guesses** — armor-slot drops must match your class armor type, while cloak, neck, ring, and trinket drops remain universal candidates; item level is not used to decide whether a row belongs in Askable.
- **Settings now open inside the main addon window** — the settings panel replaces the loot view instead of overlapping it, and returning from settings restores the loot view cleanly.
- **Release packaging now includes and validates the addon icon** — local checks confirm the icon metadata and packaged zip contents before release.
- **Release recovery is easier** — a manual CurseForge upload retry workflow is available for transient marketplace/API failures after the normal checks pass.
- **Public documentation is clearer** — README copy now lists supported language options and the current Retail `12.0.7` plus Midnight `12.1.0` compatibility targets.

### Fixed

- **Duplicate rows are filtered when Blizzard reports the same drop through different loot paths** — encounter loot and loot-event text with different item-link variants now resolve to one row for the same player and item.
- **Slow item-cache duplicate drops are merged correctly** — if encounter and chat loot events for the same player/item arrive with different item-link variants after the short live dedupe window, the pending drop resolves to one row and keeps the later link/source.
- **Late boss and chest loot merges into the correct history group** — delayed drops from the same dungeon/boss no longer create duplicate history entries.
- **Mythic+ end-chest loot is preserved more reliably** — drops that arrive around challenge completion stay attached to the completed run instead of being lost or split.
- **Delayed identity and item-link resolution no longer drops loot state** — rows survive while player names, realms, item links, and item metadata finish loading.
- **Bonus-loot source upgrades stay attached to existing rows** — late bonus-roll detection updates the current or pending row instead of duplicating it or losing the source marker.
- **Encounter loot handling is more defensive** — malformed or partial encounter loot payloads are ignored safely instead of corrupting the visible drop state.
- **Stale item-load callbacks can no longer re-add cleared loot** — callbacks from older loot contexts are cancelled before they can resurrect outdated rows.
- **Saved numeric data is hardened** — invalid `NaN` or infinite values are stripped during normalization instead of surviving into SavedVariables.
- **CurseForge upload now rebuilds the default package before upload** — stale files in `dist` can no longer be reused accidentally when publishing without an explicit `-ZipPath`.

### Updated

- **Packaged for Retail `12.0.7` and Midnight `12.1.0`.**

## 0.2.2 - 02-Jul-2026 — Compatibility hotfix

### Fixed

- **The addon no longer appears incompatible on the current Retail client** — Retail `12.0.7` metadata was restored while keeping Midnight `12.1.0` compatibility metadata.

## 0.2.1 - 02-Jul-2026 — Midnight 12.1.0 compatibility

### Changed

- **Retail compatibility metadata was retargeted for Midnight `12.1.0`** — CurseForge upload metadata now follows the updated game-version target.

## 0.2.0 - 02-Jul-2026 — First public release

### Added

- **Compact loot window for likely-tradeable group gear drops** — usable candidates appear in a focused in-game panel as loot is detected.
- **Separate `Askable` and `All Gear` tabs** — items worth asking about stay focused while other visible gear drops remain reviewable.
- **Session and boss/run history for recent drops** — recent loot can be reviewed after the immediate drop moment passes.
- **Dropped-vs-equipped item display** — live inspect retries and cached equipment fallback help compare the drop with the looter's current gear.
- **`/dyni scan` equipment pre-scan** — refreshes the group equipment cache before a dungeon or raid pull.
- **`/dyni test`, `/dyni status`, `/dyni debug on`, and `/dyni diag` support** — local verification and loot diagnostics are available without extra tools.
- **Optional delayed auto-whisper** — disabled by default, with user-adjustable timing.
- **Custom whisper text in settings** — players can rewrite the Ask message to match their own tone.
- **Language, font, and font-size settings with hover previews** — visual choices can be previewed before committing.
- **Class-colored looter names** — roster class data is used when available.

### Fixed

- **Cyrillic player names stay readable when the selected UI font lacks Cyrillic glyphs** — addon rows can fall back to a safer font for affected names.
- **Stale inspect and item-load callbacks no longer re-add cleared loot** — older asynchronous work is ignored after the relevant loot state changes.
- **Deprecated ranged-slot inspection reads are avoided** — invalid inventory-slot lookups no longer raise Lua errors on modern Retail clients.
- **`Askable` hides loot that is not useful to ask for** — non-gear loot, unusable askable gear, and non-tradeable bind-on-pickup drops are filtered out.
- **Manual Ask remains retryable after protected whisper failures** — a failed protected send does not permanently consume the row action.
- **Unsaved whisper-template drafts are preserved while adjusting settings** — editing the message is safer while browsing other controls.

### Known Limitations

- **Non-English/non-Russian locale tables intentionally fall back to English for some addon-specific labels.**
