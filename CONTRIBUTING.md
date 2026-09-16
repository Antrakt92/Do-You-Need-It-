# Contributing

Report bugs and suggest changes in [GitHub Issues](https://github.com/Antrakt92/Do-You-Need-It-/issues). For bugs, include the addon version, WoW client version and language, reproduction steps, expected result, and the exact error. Screenshots help with layout problems. Redact player names and other personal details before posting diagnostics.

Keep pull requests focused on one change. Explain its effect on players and how you checked it. Add a regression test for a behavior fix. Keep earlier changelog entries and preserve third-party notices.

## Source layout

- `DoYouNeedIt_Core.lua`: loot rules, settings, history, and data normalization.
- `DoYouNeedIt.lua`: game events, inspection, whispers, and the loot/settings windows.
- `DoYouNeedIt.toc`: client compatibility, version, and file loading order.
- `libs/`, `LICENSES/`, and `THIRD-PARTY-NOTICES.md`: bundled libraries and their terms.
- `media/`: addon icon.
- `tests/` and `scripts/`: regression tests, checks, packaging, and release validation.

## Checks

The runtime targets Lua 5.1. From the repository root, run:

```powershell
.\scripts\check.ps1
```

This runs Lua regressions and syntax checks, release-reference tests, library/license integrity checks, deterministic package validation, upload metadata dry-runs, and public-source checks. It does not upload anything.

If `lua5.1` or `luac5.1` is missing on Windows, install the pinned check tools with:

```powershell
.\scripts\install-check-tools.ps1 -Install
```

Game-facing changes also need a client check: `/reload`, `/dyni test`, settings at small and large fonts, incoming loot while reading history, and a real grouped dungeon or raid drop. Check relevant combat transitions and delayed item/inspection data. Demo rows do not test live whispers.

## Packaging

```powershell
.\scripts\package.ps1
.\scripts\upload-curseforge.ps1 -DryRun
```

The package is `dist/DoYouNeedIt-<version>.zip`, rooted at `DoYouNeedIt/`. It contains runtime files, the icon, README, complete changelog, license, and third-party notices/license texts. Tests, scripts, contributor instructions, and local development files are excluded.

Upload validation rebuilds the default archive and checks its contents against the current checkout. `-ZipPath <path>` selects an existing archive, which must pass the same checks. Changelog metadata includes the complete release history, starting with the current release; an `Unreleased` section is excluded.

## Maintainer publication

Keep the TOC version, `Core.VERSION`, README status example, and dated changelog heading aligned. A fresh `vMAJOR.MINOR.PATCH` tag invokes the release workflow: it checks the exact tag and package, prepares a GitHub draft, uploads to CurseForge, then publishes the GitHub release.

The upload script reads the project ID, version, and client interfaces from the TOC. Live uploads require `CURSEFORGE_API_TOKEN` in the process environment; never put credentials in source files or reports. Use `-DryRun` when checking metadata.

Do not rerun an uncertain upload or move a published tag. The manual recovery workflow requires an exact existing tag and a verified state: either upload never started or CurseForge confirmed acceptance.
