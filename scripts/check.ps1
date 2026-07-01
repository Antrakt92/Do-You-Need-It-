$ErrorActionPreference = "Stop"

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & lua5.1 tests\run.lua
    if ($LASTEXITCODE -ne 0) {
        throw "lua5.1 tests\run.lua failed with exit code $LASTEXITCODE"
    }
    & lua5.1 tests\runtime_smoke.lua
    if ($LASTEXITCODE -ne 0) {
        throw "lua5.1 tests\runtime_smoke.lua failed with exit code $LASTEXITCODE"
    }
    & lua5.1 tests\runtime_inspect.lua
    if ($LASTEXITCODE -ne 0) {
        throw "lua5.1 tests\runtime_inspect.lua failed with exit code $LASTEXITCODE"
    }
    & luac5.1 -p `
        libs\LibStub\LibStub.lua `
        libs\CallbackHandler-1.0\CallbackHandler-1.0.lua `
        libs\LibSharedMedia-3.0\LibSharedMedia-3.0.lua `
        DoYouNeedIt_Core.lua `
        DoYouNeedIt.lua
    if ($LASTEXITCODE -ne 0) {
        throw "luac5.1 syntax check failed with exit code $LASTEXITCODE"
    }

    $forbidden = @(
        'C:\Users',
        'Documents\GitHub\WOW',
        'Codex',
        'superpowers',
        'AGENTS.md',
        'CLAUDE.md',
        'AUDIT.md',
        'PLAN.md',
        'do-you-need-it-meta'
    )

    $files = Get-ChildItem -File -Recurse |
        Where-Object {
            $_.FullName -notmatch '\\.git\\' -and
            $_.FullName -notmatch '\\scripts\\check\.ps1$'
        }

    foreach ($pattern in $forbidden) {
        $matches = $files | Select-String -SimpleMatch -Pattern $pattern
        if ($matches) {
            $matches | ForEach-Object {
                Write-Error "Forbidden public-source text '$pattern' in $($_.Path):$($_.LineNumber)"
            }
        }
    }

    Write-Host "Do You Need It checks passed."
}
finally {
    Pop-Location
}
