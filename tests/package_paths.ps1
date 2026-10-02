$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$caseRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dyni-path-tests-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $caseRoot 'source'
$caseCount = 0
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/package.ps1') -Destination (Join-Path $fixture 'scripts/package.ps1')
    $files = @('DoYouNeedIt.toc', 'DoYouNeedIt.lua', 'DoYouNeedIt_Core.lua', 'README.md', 'CHANGELOG.md', 'LICENSE',
        'THIRD-PARTY-NOTICES.md', 'LICENSES/CallbackHandler-1.0-BSD-2-Clause.txt', 'LICENSES/LibSharedMedia-3.0-LGPL-2.1.txt',
        'libs/LibStub/LibStub.lua', 'libs/CallbackHandler-1.0/CallbackHandler-1.0.lua', 'libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua', 'media/icon.png')
    foreach ($file in $files) {
        $destination = Join-Path $fixture $file
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $destination
    }
    $tocPath = Join-Path $fixture 'DoYouNeedIt.toc'
    $toc = Get-Content -LiteralPath $tocPath -Raw
    Set-Content -LiteralPath (Join-Path $caseRoot 'outside.lua') -Value '-- harmless outside fixture'
    Set-Content -LiteralPath (Join-Path $fixture '.env.local') -Value 'FIXTURE=harmless'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'tests') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture 'tests/fixture.lua') -Value '-- developer fixture'
    $linkedSource = Join-Path $caseRoot 'linked-source'
    New-Item -ItemType Directory -Path $linkedSource | Out-Null
    Set-Content -LiteralPath (Join-Path $linkedSource 'outside.lua') -Value '-- harmless linked fixture'
    New-Item -ItemType Junction -Path (Join-Path $fixture 'linked') -Value $linkedSource | Out-Null
    foreach ($entry in @('../outside.lua', 'tests/fixture.lua', '.env.local', (Join-Path $caseRoot 'outside.lua'), 'linked/outside.lua')) {
        Set-Content -LiteralPath $tocPath -Value ($toc + "`n$entry`n")
        $failure = $null
        try {
            & (Join-Path $fixture 'scripts/package.ps1') -OutDir (Join-Path $caseRoot "out-$caseCount") | Out-Null
        } catch { $failure = $_.Exception.Message }
        if (-not $failure -or -not $failure.Contains('Unsafe package path')) {
            throw "Unsafe TOC entry '$entry' was not rejected at the packaging boundary: $failure"
        }
        if (@(Get-ChildItem -LiteralPath (Join-Path $caseRoot "out-$caseCount") -Filter '*.zip' -ErrorAction SilentlyContinue).Count -ne 0) {
            throw 'Unsafe source must be rejected before an archive is produced'
        }
        $caseCount++
    }
    Set-Content -LiteralPath $tocPath -Value ($toc -replace '(?m)^## Version:.*$', '## Version: 00.6.0')
    $failure = $null
    try {
        & (Join-Path $fixture 'scripts/package.ps1') -OutDir (Join-Path $caseRoot 'invalid-version') | Out-Null
    } catch { $failure = $_.Exception.Message }
    if (-not $failure -or -not $failure.Contains('canonical MAJOR.MINOR.PATCH')) { throw "Invalid package version was accepted: $failure" }
    $caseCount++
    Set-Content -LiteralPath $tocPath -Value $toc
    & (Join-Path $fixture 'scripts/package.ps1') -OutDir (Join-Path $caseRoot 'valid') | Out-Null
    $caseCount++
    Write-Host "Package path checks passed ($caseCount cases)."
} finally {
    $resolved = [System.IO.Path]::GetFullPath($caseRoot)
    $tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Path test cleanup escaped temp root' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
