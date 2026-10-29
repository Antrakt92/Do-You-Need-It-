# Do You Need It? development reference

[Contributor setup](../CONTRIBUTING.md) · [Player guide](../README.md)

Run commands from the repository root.

## Source layout

- `DoYouNeedIt_Core.lua`: loot rules, settings, history, and data normalization.
- `DoYouNeedIt_Fonts.lua` and `fonts/`: bundled font catalog, original assets, provenance and licenses.
- `DoYouNeedIt.lua`: game events, inspection, whispers, and the loot/settings windows.
- `DoYouNeedIt.toc`: client compatibility, version, and file loading order.
- `DoYouNeedIt_Forever.lua` and `DoYouNeedIt_Forever.toc`: Forever beta adapter and independent metadata.
- `libs/`, `LICENSES/`, and `THIRD-PARTY-NOTICES.md`: bundled libraries and their terms.
- `media/`: addon icon.
- `tests/` and `scripts/`: regression tests, checks, packaging, and release validation.

## Packaging

```powershell
.\scripts\package.ps1
.\scripts\upload-curseforge.ps1 -DryRun
```

The package is `dist/DoYouNeedIt-<version>.zip`, rooted at `DoYouNeedIt/`. It contains runtime files, the icon, README, complete changelog, license, and third-party notices/license texts. Tests, scripts, contributor instructions, and local development files are excluded.

Upload validation rebuilds the default archive and checks its contents against the current checkout. `-ZipPath <path>` selects an existing archive, which must pass the same checks. Changelog metadata includes the complete release history, starting with the current release; an `Unreleased` section is excluded.

For Forever, run `scripts/package.ps1 -Flavor Forever` and
`scripts/upload-curseforge.ps1 -Flavor Forever -DryRun`. Its ZIP is
`DoYouNeedIt-<version>-Forever-beta.zip`; the Forever TOC and
`CHANGELOG-FOREVER.md` become the archive's canonical TOC and changelog.
Retail packages exclude the Forever adapter. The full check covers both flavors.

## Maintainer publication

Keep the TOC version, `Core.VERSION`, README status example, and dated changelog heading aligned. A fresh `vMAJOR.MINOR.PATCH` tag invokes the release workflow: it checks the exact tag and package, prepares a GitHub draft, uploads to CurseForge, then publishes the GitHub release.

Forever versions are independent: align its TOC, adapter version and Forever
changelog, then use `forever-vMAJOR.MINOR.PATCH` with `forever-release.yml`.
It publishes a GitHub prerelease without replacing Retail's latest release and
a CurseForge beta for exact Forever 1.60.1 / game version type 88568. Both tag
namespaces must reject deletion and non-fast-forward updates. The Retail recovery
workflow does not handle Forever tags; reconcile an uncertain beta upload and
recover forward with a new version.

The upload script reads the project ID, version, and client interfaces from the TOC. Live uploads require `CURSEFORGE_API_TOKEN` in the process environment; never put credentials in source files or reports. Use `-DryRun` when checking metadata.

Do not rerun an uncertain upload or move a published tag. The manual recovery workflow requires an exact existing tag and a verified state: either upload never started or CurseForge confirmed acceptance.
