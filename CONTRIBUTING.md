# Contributing to Do You Need It?

[Player guide](README.md) · [Development reference](docs/DEVELOPMENT.md)

## Report a problem

Open a [GitHub issue](https://github.com/Antrakt92/Do-You-Need-It-/issues) with
your addon version, WoW client and language, reproduction steps, expected result
and exact error. Include a screenshot for layout problems. Redact player names
and other personal details from diagnostics.

## Run checks

The runtime uses Lua 5.1. From the repository root, run:

```powershell
.\scripts\check.ps1
```

This checks Lua behavior and syntax, fonts, library licenses, release metadata
and deterministic packages for Retail and Forever. It does not upload files.
If Lua tools are missing on Windows, install the pinned tools with:

```powershell
.\scripts\install-check-tools.ps1 -Install
```

Game-facing changes also need `/reload`, `/dyni test`, small and large fonts,
incoming loot while browsing history, and a real group drop. Check relevant
combat transitions and delayed inspection/item data. Demo does not test whispers.

## Submit a change

Keep changes focused. Explain the effect on players, add regression coverage
for behavior fixes and list the checks you ran. Preserve saved settings,
opt-in whispers, full changelog history and third-party notices.

See the [development reference](docs/DEVELOPMENT.md) for the source layout,
local packages and release procedures.
