param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedZip = if ([System.IO.Path]::IsPathRooted($ZipPath)) {
    $ZipPath
} else {
    Join-Path $repoRoot $ZipPath
}
$resolvedZip = (Resolve-Path -LiteralPath $resolvedZip).Path
$comparisonRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("dyni-package-verify-" + [guid]::NewGuid().ToString("N"))
$expectedArchive = $null
$actualArchive = $null

function Get-EntryHash {
    param([System.IO.Compression.ZipArchiveEntry]$Entry)
    $stream = $Entry.Open()
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($hash.ComputeHash($stream))
    } finally {
        $hash.Dispose()
        $stream.Dispose()
    }
}

try {
    # Compare files, not ZIP bytes: archive compression and timestamps may differ.
    & (Join-Path $PSScriptRoot "package.ps1") -OutDir $comparisonRoot
    $expectedZips = @(Get-ChildItem -LiteralPath $comparisonRoot -Filter '*.zip' -File)
    if ($expectedZips.Count -ne 1) {
        throw "Expected exactly one reference package"
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $expectedArchive = [System.IO.Compression.ZipFile]::OpenRead($expectedZips[0].FullName)
    $actualArchive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZip)
    $expectedEntries = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $expectedArchive.Entries) {
        $expectedEntries.Add($entry.FullName, $entry)
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $actualArchive.Entries) {
        if (-not $expectedEntries.ContainsKey($entry.FullName)) {
            throw "Unexpected package entry: $($entry.FullName)"
        }
        if (-not $seen.Add($entry.FullName)) {
            throw "Duplicate package entry: $($entry.FullName)"
        }
        $expected = $expectedEntries[$entry.FullName]
        if ($entry.Length -ne $expected.Length -or (Get-EntryHash $entry) -cne (Get-EntryHash $expected)) {
            throw "Package content differs from current source: $($entry.FullName)"
        }
    }
    if ($seen.Count -ne $expectedEntries.Count) {
        throw "Package is missing required files"
    }
    Write-Host "Package contents match the current source."
} finally {
    if ($actualArchive) { $actualArchive.Dispose() }
    if ($expectedArchive) { $expectedArchive.Dispose() }
    # Only remove this invocation's generated directory inside the temp root.
    $resolvedComparison = [System.IO.Path]::GetFullPath($comparisonRoot)
    $tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedComparison.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package comparison cleanup escaped the temporary directory"
    }
    if (Test-Path -LiteralPath $resolvedComparison) {
        Remove-Item -LiteralPath $resolvedComparison -Recurse -Force
    }
}
