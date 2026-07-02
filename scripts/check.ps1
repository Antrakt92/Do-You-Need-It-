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
    if ($tocText -notmatch '(?m)^##\s*X-Curse-Project-ID:\s*1595368\s*$') {
        throw "DoYouNeedIt.toc is missing the expected CurseForge project id"
    }
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

    function Get-NormalizedTextFileSha256 {
        param([string]$Path)

        $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
        $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
        $normalizedBytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return (($sha256.ComputeHash($normalizedBytes) | ForEach-Object { $_.ToString("X2") }) -join "")
        }
        finally {
            $sha256.Dispose()
        }
    }

    # WHY: this guard should catch vendored library edits, not CRLF/LF churn
    # between older Windows checkouts and fresh CI checkouts.
    $expectedLibraryHashes = @{
        'libs\LibStub\LibStub.lua' = 'C6D9599EFE3D24B90BC175629AD5464981B10DDB7E74A18274658E5C56875B85'
        'libs\CallbackHandler-1.0\CallbackHandler-1.0.lua' = '7A0BD63D0DCB126359A60204862D21A7AC2C9FF18D61480D4F5C554751553F5D'
        'libs\LibSharedMedia-3.0\LibSharedMedia-3.0.lua' = '39445CC0486FB0FDBA7367AAE9979CAA342D2AB194CDBC5ED1C6FED72FDD8D6E'
    }
    foreach ($path in $expectedLibraryHashes.Keys) {
        $actualHash = (Get-NormalizedTextFileSha256 -Path $path).ToUpperInvariant()
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

    $uploadDryRun = .\scripts\upload-curseforge.ps1 -DryRun | ConvertFrom-Json
    if ($uploadDryRun.ProjectId -ne 1595368) {
        throw "CurseForge upload dry run used unexpected project id: $($uploadDryRun.ProjectId)"
    }
    if ($uploadDryRun.Metadata.releaseType -ne 'release') {
        throw "CurseForge upload dry run used unexpected release type: $($uploadDryRun.Metadata.releaseType)"
    }
    $actualGameVersionNames = @($uploadDryRun.Metadata.gameVersionNames)
    $expectedGameVersionNames = @("12.1.0")
    if (($actualGameVersionNames -join ',') -ne ($expectedGameVersionNames -join ',')) {
        throw "CurseForge upload dry run used unexpected game versions: $($actualGameVersionNames -join ', ')"
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
