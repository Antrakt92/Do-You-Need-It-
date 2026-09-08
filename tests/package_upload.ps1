$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$upload = Join-Path $repoRoot 'scripts/upload-curseforge.ps1'
$caseRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dyni-upload-tests-' + [guid]::NewGuid().ToString('N'))
$caseCount = 0

function Assert-PackageCase {
    param([string]$Name, [string]$ExpectedError = '')
    $zip = Join-Path $caseRoot "$Name.zip"
    if ($Name -eq 'invalid-zip') {
        [System.IO.File]::WriteAllText($zip, 'not a zip')
    } else {
        $stream = [System.IO.File]::Create($zip)
        $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($entry in $reference.Entries) {
                if ($Name -eq 'missing-file' -and $entry.FullName.EndsWith('/README.md')) { continue }
                $entryName = $entry.FullName
                if ($Name -eq 'wrong-root') { $entryName = $entryName.Replace('DoYouNeedIt/', 'OtherAddon/') }
                if ($Name -eq 'wrong-case') { $entryName = $entryName.ToUpperInvariant() }
                $copy = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::NoCompression)
                $destination = $copy.Open()
                $source = $entry.Open()
                try {
                    if ($Name -eq 'same-size-change' -and $entryName.EndsWith('/DoYouNeedIt.lua')) {
                        $destination.WriteByte($source.ReadByte() -bxor 1)
                    }
                    $source.CopyTo($destination)
                    if (($Name -eq 'stale-runtime' -and $entryName.EndsWith('/DoYouNeedIt.lua')) -or
                        ($Name -eq 'stale-version' -and $entryName.EndsWith('/DoYouNeedIt.toc'))) {
                        $destination.WriteByte(32)
                    }
                } finally {
                    $source.Dispose()
                    $destination.Dispose()
                }
            }
            if ($Name -eq 'extra-file') { [void]$archive.CreateEntry('DoYouNeedIt/private.txt') }
            if ($Name -eq 'traversal') { [void]$archive.CreateEntry('DoYouNeedIt/../outside.txt') }
            if ($Name -eq 'duplicate-file') { [void]$archive.CreateEntry('DoYouNeedIt/DoYouNeedIt.lua') }
        } finally {
            $archive.Dispose()
            $stream.Dispose()
        }
    }
    $failure = $null
    try {
        $result = & $upload -ZipPath $zip -DryRun | ConvertFrom-Json
    } catch {
        $failure = $_.Exception.Message
    }
    if ($ExpectedError) {
        if (-not $failure -or ($ExpectedError -ne '*' -and -not $failure.Contains($ExpectedError))) {
            throw "${Name}: expected '$ExpectedError', got '$failure'"
        }
    } elseif ($failure) {
        throw "${Name}: $failure"
    } elseif ($result.ProjectId -ne 1595368 -or $result.ZipPath -ne $zip) {
        throw "${Name}: unexpected upload metadata"
    }
    $script:caseCount++
}

$reference = $null
try {
    & (Join-Path $repoRoot 'scripts/package.ps1') -OutDir $caseRoot
    $referenceZip = @(Get-ChildItem -LiteralPath $caseRoot -Filter '*.zip' -File)[0]
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $reference = [System.IO.Compression.ZipFile]::OpenRead($referenceZip.FullName)
    Assert-PackageCase 'recompressed-valid'
    Assert-PackageCase 'invalid-zip' '*'
    Assert-PackageCase 'missing-file' 'missing required files'
    Assert-PackageCase 'stale-runtime' 'content differs'
    Assert-PackageCase 'same-size-change' 'content differs'
    Assert-PackageCase 'stale-version' 'content differs'
    Assert-PackageCase 'extra-file' 'Unexpected package entry'
    Assert-PackageCase 'wrong-root' 'Unexpected package entry'
    Assert-PackageCase 'wrong-case' 'Unexpected package entry'
    Assert-PackageCase 'traversal' 'Unexpected package entry'
    Assert-PackageCase 'duplicate-file' 'Duplicate package entry'
    Write-Host "Package upload checks passed ($caseCount cases)."
} finally {
    if ($reference) { $reference.Dispose() }
    $resolvedCaseRoot = [System.IO.Path]::GetFullPath($caseRoot)
    $tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedCaseRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Upload test cleanup escaped the temporary directory'
    }
    if (Test-Path -LiteralPath $resolvedCaseRoot) { Remove-Item -LiteralPath $resolvedCaseRoot -Recurse -Force }
}
