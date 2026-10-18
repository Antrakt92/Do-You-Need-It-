param(
    [string]$OutDir = "dist",
    [ValidateSet("Retail", "Forever")][string]$Flavor = "Retail"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$addonName = "DoYouNeedIt"
$tocName = if ($Flavor -eq "Forever") { "DoYouNeedIt_Forever.toc" } else { "$addonName.toc" }
$tocPath = Join-Path $repoRoot $tocName

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
if ($version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw 'Package version must use canonical MAJOR.MINOR.PATCH format'
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
$zipName = if ($Flavor -eq "Forever") { "$addonName-$version-Forever-beta.zip" } else { "$addonName-$version.zip" }
$zipPath = Join-Path $resolvedOutDir $zipName

function Copy-PackageFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,
        [string]$DestinationPath = $RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains(':') -or
        $RelativePath -match '(^|[\\/])\.\.?([\\/]|$)' -or
        $RelativePath -match '^(\.git|\.github|\.idea|\.vscode|tests|scripts)([\\/]|$)' -or
        $RelativePath -match '(^|[\\/])\.env[^\\/]*([\\/]|$)') {
        throw "Unsafe package path: $RelativePath"
    }
    $source = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
    $destination = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $DestinationPath))
    $sourcePrefix = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $destinationPrefix = [System.IO.Path]::GetFullPath($addonRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $source.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $destination.StartsWith($destinationPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe package path: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Package source file is missing: $RelativePath"
    }
    # Lexical containment alone does not constrain a file below a junction.
    $inspectedPath = $source
    while ($inspectedPath.StartsWith($sourcePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $component = Get-Item -LiteralPath $inspectedPath -Force
        if (($component.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Unsafe package path through a link: $RelativePath"
        }
        $inspectedPath = Split-Path -Parent $inspectedPath
    }

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

    Copy-PackageFile $tocName "$addonName.toc"
    foreach ($entry in $tocEntries) {
        Copy-PackageFile ($entry -replace '/', '\')
    }
    $iconRelativePath = Resolve-AddonRelativeTexture -TexturePath $iconTexture
    if ($iconRelativePath) {
        Copy-PackageFile $iconRelativePath
    }
    Copy-PackageFile "README.md"
    if ($Flavor -eq "Forever") { Copy-PackageFile "CHANGELOG-FOREVER.md" "CHANGELOG.md" }
    else { Copy-PackageFile "CHANGELOG.md" }
    Copy-PackageFile "LICENSE"
    Copy-PackageFile "THIRD-PARTY-NOTICES.md"
    Copy-PackageFile "LICENSES/CallbackHandler-1.0-BSD-2-Clause.txt"
    Copy-PackageFile "LICENSES/LibSharedMedia-3.0-LGPL-2.1.txt"
    Copy-PackageFile "media/font-star-outline.tga"
    Copy-PackageFile "media/font-star-filled.tga"
    Copy-PackageFile "fonts/manifest.json"
    Copy-PackageFile "fonts/NOTICE.md"
    $fontManifest = Get-Content -LiteralPath (Join-Path $repoRoot 'fonts/manifest.json') -Raw | ConvertFrom-Json
    if ($fontManifest.schemaVersion -ne 1 -or @($fontManifest.fonts).Count -ne 46) {
        throw 'Invalid bundled font manifest'
    }
    foreach ($fontEntry in $fontManifest.fonts) {
        Copy-PackageFile $fontEntry.path
        if ((Get-FileHash -LiteralPath (Join-Path $repoRoot $fontEntry.path) -Algorithm SHA256).Hash -cne $fontEntry.sha256) {
            throw "Bundled font hash mismatch: $($fontEntry.path)"
        }
        Copy-PackageFile $fontEntry.licenseFile
    }

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
    $resolvedStaging = [System.IO.Path]::GetFullPath($stagingRoot)
    $outputPrefix = [System.IO.Path]::GetFullPath($resolvedOutDir).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedStaging.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Package cleanup escaped the output directory'
    }
    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force -ErrorAction SilentlyContinue
}
