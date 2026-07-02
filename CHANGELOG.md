# Changelog

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
