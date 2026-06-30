$ErrorActionPreference = "Stop"

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    lua5.1 tests\run.lua
    luac5.1 -p DoYouNeedIt_Core.lua DoYouNeedIt.lua

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
