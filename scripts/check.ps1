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

    $tocText = Get-Content -LiteralPath .\DoYouNeedIt.toc -Raw
    $coreText = Get-Content -LiteralPath .\DoYouNeedIt_Core.lua -Raw
    $readmeText = Get-Content -LiteralPath .\README.md -Raw
    if ($tocText -notmatch '(?m)^##\s*Version:\s*(\S+)\s*$') {
        throw "DoYouNeedIt.toc is missing ## Version"
    }
    $tocVersion = $Matches[1]
    if ($coreText -notmatch 'Core\.VERSION\s*=\s*"([^"]+)"') {
        throw "DoYouNeedIt_Core.lua is missing Core.VERSION"
    }
    $coreVersion = $Matches[1]
    if ($readmeText -notmatch 'build=([0-9]+\.[0-9]+\.[0-9]+)') {
        throw "README.md is missing the /dyni status build version"
    }
    $readmeVersion = $Matches[1]
    if ($tocVersion -ne $coreVersion -or $tocVersion -ne $readmeVersion) {
        throw "version drift: TOC=$tocVersion Core=$coreVersion README=$readmeVersion"
    }

    $expectedLibraryHashes = @{
        'libs\LibStub\LibStub.lua' = '247B1B25646A47DD62C297AB59A9499F6E8200634A5EA5A8A171EED71416A753'
        'libs\CallbackHandler-1.0\CallbackHandler-1.0.lua' = '699C3C7C14DD4794A105A49F6DC727F9B82E5918A50C2E14735C9DD2849F9AC6'
        'libs\LibSharedMedia-3.0\LibSharedMedia-3.0.lua' = 'C0D81C14450C379C19134530F7D9F8DC462CFE78A20D36F84CEA3D653FF3E985'
    }
    foreach ($path in $expectedLibraryHashes.Keys) {
        $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
        $expectedHash = $expectedLibraryHashes[$path].ToUpperInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "vendored library hash drift for ${path}: expected $expectedHash, got $actualHash"
        }
    }

    $packageTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("dyni-package-check-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $packageTemp | Out-Null
    try {
        & .\scripts\package.ps1 -OutDir $packageTemp
        if ($LASTEXITCODE -ne 0) {
            throw "scripts\package.ps1 failed with exit code $LASTEXITCODE"
        }

        $zips = @(Get-ChildItem -Path $packageTemp -Filter "DoYouNeedIt-*.zip")
        if ($zips.Count -ne 1) {
            throw "expected exactly one DoYouNeedIt package zip, found $($zips.Count)"
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zips[0].FullName)
        try {
            $entries = @($archive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
            $required = @(
                "DoYouNeedIt/DoYouNeedIt.toc",
                "DoYouNeedIt/DoYouNeedIt_Core.lua",
                "DoYouNeedIt/DoYouNeedIt.lua",
                "DoYouNeedIt/libs/LibStub/LibStub.lua",
                "DoYouNeedIt/libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
                "DoYouNeedIt/libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua",
                "DoYouNeedIt/CHANGELOG.md",
                "DoYouNeedIt/LICENSE",
                "DoYouNeedIt/THIRD-PARTY-NOTICES.md"
            )
            foreach ($entry in $required) {
                if ($entries -notcontains $entry) {
                    throw "package is missing $entry"
                }
            }
            foreach ($entry in $entries) {
                if ($entry -notmatch '^DoYouNeedIt/') {
                    throw "package entry is outside DoYouNeedIt root: $entry"
                }
                if ($entry -match '^DoYouNeedIt/(tests|scripts|\.git|\.github)/' -or $entry -eq "DoYouNeedIt/.gitignore") {
                    throw "package includes development-only entry: $entry"
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        Remove-Item -LiteralPath $packageTemp -Recurse -Force -ErrorAction SilentlyContinue
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

    $files = git ls-files |
        Where-Object { $_ -ne 'scripts/check.ps1' } |
        ForEach-Object { Get-Item -LiteralPath $_ }

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
