param(
    [int]$ProjectId = 0,
    [string]$ZipPath = "",
    [string]$DisplayName = "",
    [string[]]$GameVersionNames = @(),
    [ValidateSet("alpha", "beta", "release")]
    [string]$ReleaseType = "release",
    [switch]$ManualRelease,
    [string]$ChangelogPath = "CHANGELOG.md",
    [string]$ApiBaseUrl = "https://www.curseforge.com",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$addonName = "DoYouNeedIt"
$tocPath = Join-Path $repoRoot "$addonName.toc"

function Get-TocField {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $pattern = "(?m)^##\s*$([regex]::Escape($Name)):\s*(.+?)\s*$"
    $text = Get-Content -LiteralPath $tocPath -Raw
    if ($text -match $pattern) {
        return $Matches[1]
    }
    return $null
}

function Convert-InterfaceToGameVersionName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InterfaceValue
    )

    $clean = $InterfaceValue.Trim()
    if ($clean -notmatch '^\d{6}$') {
        throw "Unsupported WoW Interface value '$InterfaceValue'. Pass -GameVersionNames explicitly."
    }

    $major = [int]$clean.Substring(0, 2)
    $minor = [int]$clean.Substring(2, 2)
    $patch = [int]$clean.Substring(4, 2)
    return "$major.$minor.$patch"
}

function Get-TopChangelogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $resolvedPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    }
    else {
        Join-Path $repoRoot $Path
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Missing changelog: $resolvedPath"
    }

    $lines = Get-Content -LiteralPath $resolvedPath
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^##\s+$([regex]::Escape($Version))(\s|$)") {
            $start = $i
            break
        }
    }

    if ($start -lt 0) {
        throw "Could not find changelog entry for version $Version in $resolvedPath"
    }

    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+') {
            $end = $i
            break
        }
    }

    return (($lines[$start..($end - 1)]) -join "`n").Trim()
}

function Resolve-UploadZip {
    param(
        [string]$RequestedPath,
        [string]$Version
    )

    if ($RequestedPath) {
        $path = if ([System.IO.Path]::IsPathRooted($RequestedPath)) {
            $RequestedPath
        }
        else {
            Join-Path $repoRoot $RequestedPath
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Zip file does not exist: $path"
        }
        return (Resolve-Path -LiteralPath $path).Path
    }

    $defaultZip = Join-Path $repoRoot "dist\$addonName-$Version.zip"
    & (Join-Path $repoRoot "scripts\package.ps1") | Write-Host
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "scripts\package.ps1 failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $defaultZip -PathType Leaf)) {
        throw "Expected package was not created: $defaultZip"
    }
    return (Resolve-Path -LiteralPath $defaultZip).Path
}

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Missing addon TOC: $tocPath"
}

$version = Get-TocField -Name "Version"
if (-not $version) {
    throw "Could not read ## Version from $tocPath"
}

if (-not $ProjectId) {
    $projectIdText = Get-TocField -Name "X-Curse-Project-ID"
    if (-not $projectIdText -or $projectIdText -notmatch '^\d+$') {
        throw "Missing numeric ## X-Curse-Project-ID in $tocPath or -ProjectId parameter."
    }
    $ProjectId = [int]$projectIdText
}

if (-not $DisplayName) {
    $DisplayName = "$addonName $version"
}

if ($GameVersionNames.Count -eq 0) {
    $interfaceText = Get-TocField -Name "Interface"
    if (-not $interfaceText) {
        throw "Could not read ## Interface from $tocPath. Pass -GameVersionNames explicitly."
    }
    $GameVersionNames = @(
        $interfaceText -split ',' |
            ForEach-Object { Convert-InterfaceToGameVersionName $_ }
    )
}

$resolvedZipPath = Resolve-UploadZip -RequestedPath $ZipPath -Version $version
$changelog = Get-TopChangelogEntry -Path $ChangelogPath -Version $version

$metadata = [ordered]@{
    changelog = $changelog
    changelogType = "markdown"
    displayName = $DisplayName
    gameVersionNames = @($GameVersionNames)
    releaseType = $ReleaseType
    isMarkedForManualRelease = [bool]$ManualRelease
}
$metadataJson = $metadata | ConvertTo-Json -Depth 10 -Compress

if ($DryRun) {
    [pscustomobject]@{
        ProjectId = $ProjectId
        ZipPath = $resolvedZipPath
        Metadata = $metadata
    } | ConvertTo-Json -Depth 10
    return
}

$token = $env:CURSEFORGE_API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = $env:CF_API_KEY
}
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Set CURSEFORGE_API_TOKEN (or CF_API_KEY) before uploading to CurseForge."
}

Add-Type -AssemblyName System.Net.Http

$client = [System.Net.Http.HttpClient]::new()
$form = [System.Net.Http.MultipartFormDataContent]::new()
$stream = $null
try {
    $client.DefaultRequestHeaders.Add("X-Api-Token", $token)

    $metadataContent = [System.Net.Http.StringContent]::new(
        $metadataJson,
        [System.Text.Encoding]::UTF8,
        "application/json"
    )
    $form.Add($metadataContent, "metadata")

    $stream = [System.IO.File]::OpenRead($resolvedZipPath)
    $fileContent = [System.Net.Http.StreamContent]::new($stream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
    $form.Add($fileContent, "file", [System.IO.Path]::GetFileName($resolvedZipPath))

    $uri = "$($ApiBaseUrl.TrimEnd('/'))/api/projects/$ProjectId/upload-file"
    $response = $client.PostAsync($uri, $form).GetAwaiter().GetResult()
    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
        throw "CurseForge upload failed with HTTP $([int]$response.StatusCode) $($response.ReasonPhrase): $body"
    }

    Write-Host "CurseForge upload accepted for project $ProjectId."
    Write-Output $body
}
finally {
    if ($stream) {
        $stream.Dispose()
    }
    $form.Dispose()
    $client.Dispose()
}
