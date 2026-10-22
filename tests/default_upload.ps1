param(
    [Parameter(Mandatory = $true)]
    [string]$ReferenceZip
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$caseRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dyni-default-upload-' + [guid]::NewGuid().ToString('N'))
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    [void][System.IO.Directory]::CreateDirectory($caseRoot)
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path -LiteralPath $ReferenceZip).Path, $caseRoot)
    $fixtureRoot = Join-Path $caseRoot 'DoYouNeedIt'
    $fixtureScripts = Join-Path $fixtureRoot 'scripts'
    [void][System.IO.Directory]::CreateDirectory($fixtureScripts)
    foreach ($name in @('package.ps1', 'check-package.ps1', 'upload-curseforge.ps1')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts/$name") -Destination (Join-Path $fixtureScripts $name)
    }
    $fixtureToc = Get-Content -LiteralPath (Join-Path $fixtureRoot 'DoYouNeedIt.toc') -Raw
    if ($fixtureToc -notmatch '(?m)^##\s*Version:\s*(\S+)\s*$') { throw 'Fixture TOC is missing its version' }
    $tocVersion = $Matches[1]
    $defaultUploadZip = Join-Path $fixtureRoot "dist\DoYouNeedIt-$tocVersion.zip"
    New-Item -ItemType Directory -Path (Split-Path -Parent $defaultUploadZip) -Force | Out-Null
    Set-Content -LiteralPath $defaultUploadZip -Value "stale-upload-check" -NoNewline

    $uploadDryRun = & (Join-Path $fixtureRoot 'scripts/upload-curseforge.ps1') -DryRun | ConvertFrom-Json
    if ($uploadDryRun.ProjectId -ne 1595368) {
        throw "CurseForge upload dry run used unexpected project id: $($uploadDryRun.ProjectId)"
    }
    if ($uploadDryRun.Metadata.releaseType -ne 'release') {
        throw "CurseForge upload dry run used unexpected release type: $($uploadDryRun.Metadata.releaseType)"
    }
    $actualGameVersionNames = @($uploadDryRun.Metadata.gameVersionNames)
    $expectedGameVersionNames = @("12.1.5")
    if (($actualGameVersionNames -join ',') -ne ($expectedGameVersionNames -join ',')) {
        throw "CurseForge upload dry run used unexpected game versions: $($actualGameVersionNames -join ', ')"
    }
    $uploadArchive = [System.IO.Compression.ZipFile]::OpenRead($uploadDryRun.ZipPath)
    try {
        $uploadEntries = @($uploadArchive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
        if ($uploadEntries -notcontains "DoYouNeedIt/DoYouNeedIt.lua") {
            throw "CurseForge upload dry run did not rebuild a valid addon package"
        }
    }
    finally { $uploadArchive.Dispose() }
    if ([System.IO.Path]::GetFullPath($uploadDryRun.ZipPath) -cne [System.IO.Path]::GetFullPath($defaultUploadZip)) {
        throw 'Default upload did not use the disposable fixture archive'
    }
    Write-Host 'Default upload rebuild checks passed in a disposable package fixture.'
}
finally {
    $resolvedCaseRoot = [System.IO.Path]::GetFullPath($caseRoot)
    $tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedCaseRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        [System.IO.Path]::GetFileName($resolvedCaseRoot) -notmatch '^dyni-default-upload-[0-9a-f]{32}$') {
        throw 'Default upload fixture cleanup escaped its temporary directory'
    }
    if (Test-Path -LiteralPath $resolvedCaseRoot) { Remove-Item -LiteralPath $resolvedCaseRoot -Recurse -Force }
}
