# Project Rules - Do You Need It?

Do You Need It? is a public Retail World of Warcraft addon. Keep changes small,
evidence-backed, and compatible with the supported Retail interface versions in
`DoYouNeedIt.toc`.

## Before Editing

- Read `README.md`, `CHANGELOG.md`, and `DoYouNeedIt.toc` before release,
  packaging, command, or user-facing behavior changes.
- Check `git status --short --branch` before editing and preserve unrelated
  local work.
- Treat `DoYouNeedIt_Core.lua`, `DoYouNeedIt.lua`, packaging scripts, release
  workflows, and vendored libraries as high-risk surfaces because mistakes can
  break the public addon or marketplace upload.
- Do not put private local paths, workspace names, planning notes, or assistant
  metadata into tracked public files.

## Addon Invariants

- Runtime code must remain Lua 5.1 compatible.
- `DoYouNeedIt.toc`, `DoYouNeedIt_Core.lua` `Core.VERSION`, `README.md`
  `/dyni status` build text, and the top `CHANGELOG.md` entry must stay aligned
  for release work.
- Auto-whisper must remain opt-in. Manual row actions are the safe default.
- Loot rows should stay quiet and useful: show grouped dungeon/raid gear drops,
  hide non-gear noise, and only show `Ask` when the item is usable by the current
  character and worth asking about.
- Preserve the current inspect/cache fallback model. Delayed inspection, item
  loading, and stale callbacks must not resurrect cleared or old loot state.
- Keep Cyrillic and non-Latin font fallback behavior working when changing
  locale, font, row, or tooltip code.
- Keep bundled third-party library files byte-stable unless intentionally
  updating the vendored dependency and the hash guard together.

## Packaging And Release

- `scripts\package.ps1` must produce a zip rooted at `DoYouNeedIt/` and exclude
  tests, scripts, VCS metadata, and local development files.
- CurseForge upload behavior is a live public side effect. Use
  `scripts\upload-curseforge.ps1 -DryRun` for metadata inspection unless the user
  explicitly asked to publish.
- Do not push release tags, rerun release uploads, or invoke marketplace upload
  paths without explicit user approval.
- Release tags must match the addon version in `DoYouNeedIt.toc`.

## Verification

Run from the repository root after any code, packaging, workflow, or public-copy
change:

```powershell
.\scripts\check.ps1
```

That script is the canonical local gate. It runs Lua regression tests, Lua 5.1
syntax checks, package-shape validation, CurseForge dry-run metadata checks, and
public-source leakage checks.

If Lua 5.1 tools are missing on Windows, run the tool check first:

```powershell
.\scripts\install-check-tools.ps1
```

Use the install flag only when the user has approved installing local tooling.
