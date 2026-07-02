# Changelog

## 0.3.0 - 02-Jul-2026 - Bonus Loot and History Reliability

### Added

- Mark bonus-roll loot reported by Blizzard loot events with a small roll icon and save that source in history.
- Detect bonus loot for both your character and other group members when WoW exposes it through loot events.

### Improved

- Saved loot history is now scoped per character, so alts do not share the same recent drops.
- `Current` now falls back to the latest finalized drop group after boss or dungeon completion instead of showing an empty view.
- `All Gear` now includes your own gear drops for review while `Askable` stays focused on items worth asking other players about.
- Settings now open inside the main addon window, avoiding overlapping settings and loot windows.
- Public docs now list supported language choices and current Retail/Midnight compatibility.

### Fixed

- Prevented duplicate loot rows when Blizzard reports encounter loot and loot-event text with different item-link variants for the same player and item.
- Merged late boss/chest loot into the matching recent history group instead of creating duplicate dungeon entries.
- Preserved Mythic+ end-chest loot and delayed loot while player identity or item links are still resolving.
- Kept delayed bonus-loot source updates attached to the existing row instead of splitting or losing the source marker.
- Stopped stale item-load callbacks from re-adding loot after the relevant loot context has changed.
- Hardened saved numeric data so invalid `NaN` or infinite values do not survive normalization.

### Compatibility

- Packaged for Retail `12.0.7` and Midnight `12.1.0`.

## 0.2.2 - 02-Jul-2026 - Compatibility Hotfix

### Fixed

- Restored current Retail 12.0.7 interface metadata while keeping Midnight 12.1.0 file metadata, so the addon no longer appears as incompatible on the current client.

## 0.2.1 - 02-Jul-2026 - Midnight 12.1.0 Compatibility

### Changed

- Retargeted Retail compatibility metadata and CurseForge upload metadata to Midnight 12.1.0.

## 0.2.0 - 02-Jul-2026 - First Public Release

### Added

- Compact loot window for likely-tradeable group gear drops.
- Separate `Askable` and `All Gear` tabs so usable trade candidates stay focused while other visible gear drops remain reviewable.
- Session and boss/run history for recent drops.
- Dropped-vs-equipped item display with live inspect retries and cached equipment fallback.
- `/dyni scan` pre-scan command for group equipment cache refresh.
- `/dyni test`, `/dyni status`, `/dyni debug on`, and `/dyni diag` support for local verification and loot diagnostics.
- Optional delayed auto-whisper, disabled by default.
- Custom whisper text in settings.
- Language, font, and font-size settings with hover previews.
- Class-colored looter names when roster class data is available.

### Fixed

- Kept Cyrillic player names readable when the selected UI font lacks Cyrillic glyphs.
- Prevented stale inspect and item-load callbacks from re-adding cleared loot.
- Avoided invalid deprecated ranged-slot inspection reads.
- Hid non-gear loot, unusable askable gear, and non-tradeable bind-on-pickup drops from `Askable`.
- Kept manual Ask retryable when a protected whisper send fails.
- Preserved unsaved whisper-template drafts while adjusting settings.

### Known Limitations

- Non-English/non-Russian locale tables intentionally fall back to English for some addon-specific labels.
