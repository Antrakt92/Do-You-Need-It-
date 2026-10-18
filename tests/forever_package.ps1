$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$out = Join-Path ([System.IO.Path]::GetTempPath()) ('dyni-forever-check-' + [guid]::NewGuid().ToString('N'))
$count = 0
function Assert-Case([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:count++
}
try {
    $toc = Get-Content (Join-Path $repoRoot 'DoYouNeedIt_Forever.toc') -Raw
    Assert-Case ($toc -match '(?m)^## Interface: 16001\r?$') 'Forever interface mismatch'
    Assert-Case ($toc -match '(?m)^## Version: ([0-9]+\.[0-9]+\.[0-9]+)\r?$') 'Missing Forever version'
    $version = $Matches[1]
    $adapter = Get-Content (Join-Path $repoRoot 'DoYouNeedIt_Forever.lua') -Raw
    Assert-Case ($adapter.Contains('Core.VERSION = "' + $version + '"')) 'Forever runtime version differs from TOC'
    $changelog = Get-Content (Join-Path $repoRoot 'CHANGELOG-FOREVER.md') -Raw
    Assert-Case ($changelog -match ('(?m)^## ' + [regex]::Escape($version) + ' - ')) 'Forever changelog version mismatch'
    & (Join-Path $repoRoot 'scripts/package.ps1') -Flavor Forever -OutDir $out | Out-Null
    $zip = Join-Path $out "DoYouNeedIt-$version-Forever-beta.zip"
    $firstHash = (Get-FileHash $zip -Algorithm SHA256).Hash
    & (Join-Path $repoRoot 'scripts/package.ps1') -Flavor Forever -OutDir $out | Out-Null
    Assert-Case ((Get-FileHash $zip -Algorithm SHA256).Hash -ceq $firstHash) 'Forever package is not deterministic'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $names = @($archive.Entries.FullName)
        Assert-Case ($names -ccontains 'DoYouNeedIt/DoYouNeedIt_Forever.lua') 'Forever adapter is missing'
        Assert-Case ($names -ccontains 'DoYouNeedIt/DoYouNeedIt.toc') 'Canonical install TOC is missing'
        Assert-Case ($names -cnotcontains 'DoYouNeedIt/DoYouNeedIt_Forever.toc') 'Package must expose one install TOC'
        foreach ($entryName in @('DoYouNeedIt.toc', 'CHANGELOG.md')) {
            $reader = [System.IO.StreamReader]::new($archive.GetEntry("DoYouNeedIt/$entryName").Open())
            try { $actual = $reader.ReadToEnd() } finally { $reader.Dispose() }
            $expected = if ($entryName -eq 'CHANGELOG.md') { $changelog } else { $toc }
            Assert-Case ($actual -ceq $expected) "Wrong flavor's $entryName was packaged"
        }
    } finally { $archive.Dispose() }
    $result = & (Join-Path $repoRoot 'scripts/upload-curseforge.ps1') -Flavor Forever -ZipPath $zip -DryRun `
        -GameVersionsJson '[{"id":111,"name":"1.60.1","gameVersionTypeID":517},{"id":222,"name":"1.60.1","gameVersionTypeID":88568}]' | ConvertFrom-Json
    Assert-Case ($result.Metadata.releaseType -ceq 'beta') 'Forever upload must be beta'
    Assert-Case ($result.ExpectedGameVersionTypeId -eq 88568) 'Wrong marketplace flavor'
    Assert-Case (@($result.Metadata.gameVersions).Count -eq 1 -and $result.Metadata.gameVersions[0] -eq 222) 'Retail version must never be selected'
    $normalizedChangelog = $changelog -replace "`r`n?", "`n"
    $releaseHeading = [regex]::Match($normalizedChangelog, '(?m)^## ' + [regex]::Escape($version) + ' - ')
    $expectedReleaseNotes = $normalizedChangelog.Substring($releaseHeading.Index).Trim() + "`n"
    Assert-Case ($result.Metadata.changelog -ceq $expectedReleaseNotes) 'Wrong beta release notes or unreleased notes leaked'
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'scripts/upload-curseforge.ps1'), [ref]$null, [ref]$errors)
    Assert-Case (@($errors).Count -eq 0) 'Uploader syntax error'
    $resolver = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Resolve-ForeverVersionId' }, $true)
    . ([scriptblock]::Create($resolver.Extent.Text))
    foreach ($json in @('[]', '[{"id":1,"name":"1.60.1","gameVersionTypeID":517}]',
        '[{"id":1,"name":"1.60.1","gameVersionTypeID":88568},{"id":2,"name":"1.60.1","gameVersionTypeID":88568}]',
        '[{"id":"bad","name":"1.60.1","gameVersionTypeID":88568}]')) {
        $failed = $false
        try { Resolve-ForeverVersionId $json | Out-Null } catch { $failed = $true }
        Assert-Case $failed 'Missing/ambiguous/malformed Forever versions must fail closed'
    }
    $workflow = Get-Content (Join-Path $repoRoot '.github/workflows/forever-release.yml') -Raw
    $pattern = [regex]::Match($workflow, "GITHUB_REF_NAME -notmatch '([^']+)'").Groups[1].Value
    Assert-Case ('forever-v10.20.30' -match $pattern -and $Matches[1] -ceq '10.20.30') 'Forever tag version capture is wrong'
    foreach ($badTag in @('v1.0.0', 'forever-v01.0.0', 'forever-v1.0.0-rc1')) {
        Assert-Case ($badTag -notmatch $pattern) 'Noncanonical Forever release tag accepted'
    }
    foreach ($token in @('--prerelease', '--latest=false', '-Forever -Tag', '-Flavor Forever', 'check-release-policy.ps1 -Forever', 'github.run_attempt != 1', '$release.immutable')) {
        Assert-Case ($workflow.Contains($token)) "Missing Forever publication gate: $token"
    }
    foreach ($block in [regex]::Matches($workflow, '(?ms)        run: \|\r?\n(.*?)(?=\r?\n      - name:|\z)')) {
        $text = $block.Groups[1].Value -replace '(?m)^          ', ''
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$parseErrors)
        Assert-Case (@($parseErrors).Count -eq 0) "Forever workflow PowerShell syntax error: $parseErrors"
    }
    Write-Host "Forever package and publication checks passed ($count cases)."
} finally {
    $resolved = [System.IO.Path]::GetFullPath($out)
    $prefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Forever test cleanup escaped temporary root' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
