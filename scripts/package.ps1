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
$iconTexture = $null
$tocEntries = @()
foreach ($line in Get-Content -LiteralPath $tocPath) {
    if ($line -match '^##\s*Version:\s*(\S+)\s*$') {
        $version = $Matches[1]
        continue
    }
    if ($line -match '^##\s*IconTexture:\s*(.+?)\s*$') {
        $iconTexture = $Matches[1].Trim()
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

function Resolve-AddonRelativeTexture {
    param([string]$TexturePath)

    if ([string]::IsNullOrWhiteSpace($TexturePath)) {
        return $null
    }
    if ($TexturePath -match '^\d+$') {
        return $null
    }

    $normalized = $TexturePath -replace '/', '\'
    $prefix = "Interface\AddOns\$addonName\"
    if ($normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalized.Substring($prefix.Length)
    }
    return $null
}

try {
    New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null

    Copy-PackageFile "$addonName.toc"
    foreach ($entry in $tocEntries) {
        Copy-PackageFile ($entry -replace '/', '\')
    }
    $iconRelativePath = Resolve-AddonRelativeTexture -TexturePath $iconTexture
    if ($iconRelativePath) {
        Copy-PackageFile $iconRelativePath
    }
    Copy-PackageFile "README.md"
    Copy-PackageFile "CHANGELOG.md"
    Copy-PackageFile "LICENSE"
    Copy-PackageFile "THIRD-PARTY-NOTICES.md"

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression
    $zipStream = [System.IO.File]::Open(
        $zipPath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $archive = [System.IO.Compression.ZipArchive]::new(
            $zipStream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            $fixedTimestamp = [System.DateTimeOffset]::new(
                2000,
                1,
                1,
                0,
                0,
                0,
                [System.TimeSpan]::Zero
            )
            $files = @(
                Get-ChildItem -LiteralPath $stagingRoot -Recurse -File |
                    Sort-Object { $_.FullName.Substring($stagingRoot.Length + 1) }
            )
            foreach ($file in $files) {
                $relativePath = $file.FullName.Substring($stagingRoot.Length + 1) -replace '\\', '/'
                $entry = $archive.CreateEntry(
                    $relativePath,
                    [System.IO.Compression.CompressionLevel]::Optimal
                )
                $entry.LastWriteTime = $fixedTimestamp
                $sourceStream = $file.OpenRead()
                try {
                    $entryStream = $entry.Open()
                    try {
                        $sourceStream.CopyTo($entryStream)
                    }
                    finally {
                        $entryStream.Dispose()
                    }
                }
                finally {
                    $sourceStream.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $zipStream.Dispose()
    }

    Write-Host "Created $zipPath"
}
finally {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
