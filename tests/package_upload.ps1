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
                if ($Name -eq 'missing-lgpl' -and $entry.FullName.EndsWith('/LibSharedMedia-3.0-LGPL-2.1.txt')) { continue }
                if ($Name -eq 'missing-bsd' -and $entry.FullName.EndsWith('/CallbackHandler-1.0-BSD-2-Clause.txt')) { continue }
                $entryName = $entry.FullName
                if ($Name -eq 'wrong-root') { $entryName = $entryName.Replace('DoYouNeedIt/', 'OtherAddon/') }
                if ($Name -eq 'wrong-case') { $entryName = $entryName.ToUpperInvariant() }
                $copy = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::NoCompression)
                $destination = $copy.Open()
                $source = $entry.Open()
                try {
                    if (($Name -eq 'same-size-change' -and $entryName.EndsWith('/DoYouNeedIt.lua')) -or
                        ($Name -eq 'modified-license' -and $entryName.EndsWith('/LibSharedMedia-3.0-LGPL-2.1.txt'))) {
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
        $rawJson = & $upload -ZipPath $zip -DryRun
        $result = $rawJson | ConvertFrom-Json
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
    } elseif ($result.Metadata.changelog -cne $expectedChangelog) {
        throw "${Name}: upload must carry the complete released history"
    }
    if (-not $ExpectedError) { Assert-RequiredFonts $result $rawJson }
    $script:caseCount++
}

function Assert-RequiredFonts {
    param($Result, [string]$RawJson)
    $projects = $Result.Metadata.relations.projects
    if ($projects -isnot [array] -or $projects.Count -ne 1 -or
        $projects[0].slug -cne 'antrakt-fonts' -or
        ($projects[0].projectID -isnot [int] -and $projects[0].projectID -isnot [long]) -or
        $projects[0].projectID -ne 1783613 -or $projects[0].type -cne 'requiredDependency') {
        throw 'Font dependency projectID must be the exact JSON integer 1783613 in a project array'
    }
    if ($RawJson -notmatch '"projectID"\s*:\s*1783613(?=\s*[,}])') {
        throw 'Raw upload JSON must serialize projectID as an integer, never a quoted string'
    }
}

$reference = $null
try {
    $fullChangelog = ((Get-Content -LiteralPath (Join-Path $repoRoot 'CHANGELOG.md') -Raw -Encoding UTF8) -replace "`r`n?", "`n").Trim() + "`n"
    # Preserve every released entry; future work must stay excluded.
    $changelogHeadings = @([regex]::Matches($fullChangelog, '(?m)^##[ \t]+([^\n]+)'))
    $firstReleaseHeading = 0
    if ($changelogHeadings.Count -gt 0 -and $changelogHeadings[0].Groups[1].Value.Trim() -ceq 'Unreleased') { $firstReleaseHeading = 1 }
    $notesStart = $changelogHeadings[$firstReleaseHeading].Index
    $expectedChangelog = $fullChangelog.Substring($notesStart).Trim() + "`n"
    & (Join-Path $repoRoot 'scripts/package.ps1') -OutDir $caseRoot
    $referenceZip = @(Get-ChildItem -LiteralPath $caseRoot -Filter '*.zip' -File)[0]
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $reference = [System.IO.Compression.ZipFile]::OpenRead($referenceZip.FullName)
    Assert-PackageCase 'recompressed-valid'
    $customChangelog = Join-Path $caseRoot 'CHANGELOG.md'
    $futureCopy = if ($firstReleaseHeading -eq 1) {
        $fullChangelog
    } else {
        $fullChangelog.Replace("# Changelog`n`n", "# Changelog`n`n## Unreleased`n`n- Future work.`n`n")
    }
    [System.IO.File]::WriteAllText($customChangelog, $futureCopy, [System.Text.UTF8Encoding]::new($false))
    $customJson = & $upload -ZipPath $referenceZip.FullName -ChangelogPath $customChangelog -DryRun
    $customResult = $customJson | ConvertFrom-Json
    if ($customResult.Metadata.changelog -cne $expectedChangelog) {
        throw 'Future work must be excluded while keeping the current release notes'
    }
    Assert-RequiredFonts $customResult $customJson
    $caseCount++
    $beforeHash = (Get-FileHash $referenceZip.FullName -Algorithm SHA256).Hash
    $overrideJson = & $upload -ZipPath $referenceZip.FullName -ProjectId 123456 -DryRun
    $overrideResult = $overrideJson | ConvertFrom-Json
    Assert-RequiredFonts $overrideResult $overrideJson
    $quotedJson = $overrideJson -replace '("projectID"\s*:\s*)1783613', '$1"1783613"'
    $quotedRejected = $false
    try { Assert-RequiredFonts ($quotedJson | ConvertFrom-Json) $quotedJson } catch { $quotedRejected = $true }
    if (-not $quotedRejected) { throw 'Quoted dependency project IDs must be rejected by the upload regression' }
    $caseCount++
    if ($overrideResult.ProjectId -ne 123456 -or (Get-FileHash $referenceZip.FullName -Algorithm SHA256).Hash -cne $beforeHash) {
        throw 'Consumer project override must not alter the archive'
    }
    $caseCount++
    Assert-PackageCase 'invalid-zip' '*'
    Assert-PackageCase 'missing-file' 'missing required files'
    Assert-PackageCase 'missing-lgpl' 'missing required files'
    Assert-PackageCase 'missing-bsd' 'missing required files'
    Assert-PackageCase 'modified-license' 'content differs'
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
