param(
    [string]$OutDir = "dist"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$addonName = "DoYouNeedIt"
$tocPath = Join-Path $repoRoot "$addonName.toc"

if (-not (Test-Path -LiteralPath $tocPath)) {
    throw "Missing addon TOC: $tocPath"
}

$version = $null
$tocEntries = @()
foreach ($line in Get-Content -LiteralPath $tocPath) {
    if ($line -match '^##\s*Version:\s*(\S+)\s*$') {
        $version = $Matches[1]
        continue
    }
    if ($line -match '^\s*$' -or $line -match '^\s*##') {
        continue
    }
    $tocEntries += $line.Trim()
}

if (-not $version) {
    throw "Could not read addon version from $tocPath"
}

$resolvedOutDir = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir
}
else {
    Join-Path $repoRoot $OutDir
}
New-Item -ItemType Directory -Path $resolvedOutDir -Force | Out-Null

$stagingRoot = Join-Path $resolvedOutDir ("_package-" + [System.Guid]::NewGuid().ToString("N"))
$addonRoot = Join-Path $stagingRoot $addonName
$zipPath = Join-Path $resolvedOutDir "$addonName-$version.zip"

function Copy-PackageFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $source = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Package source file is missing: $RelativePath"
    }

    $destination = Join-Path $addonRoot $RelativePath
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

try {
    New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null

    Copy-PackageFile "$addonName.toc"
    foreach ($entry in $tocEntries) {
        Copy-PackageFile ($entry -replace '/', '\')
    }
    Copy-PackageFile "README.md"
    Copy-PackageFile "LICENSE"
    Copy-PackageFile "THIRD-PARTY-NOTICES.md"

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stagingRoot,
        $zipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    Write-Host "Created $zipPath"
}
finally {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
