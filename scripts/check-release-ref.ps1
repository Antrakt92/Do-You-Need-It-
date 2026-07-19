param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCommit,
    [string]$Remote = "origin"
)

$ErrorActionPreference = "Stop"

if ($Tag -notmatch '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw "Release tag must use canonical vMAJOR.MINOR.PATCH format"
}
if ($ExpectedCommit -cnotmatch '^[0-9a-f]{40}$') {
    throw "ExpectedCommit must be a lowercase 40-character SHA"
}

$directRef = "refs/tags/$Tag"
$peeledRef = "$directRef^{}"
$lines = @(git ls-remote --exit-code $Remote $directRef $peeledRef)
if ($LASTEXITCODE -ne 0) {
    throw "Could not resolve exact remote release tag $Tag"
}

$refs = @{}
foreach ($line in $lines) {
    if ($line -notmatch '^([0-9a-f]{40})\s+(.+)$') {
        throw "git ls-remote returned malformed release ref data"
    }
    $sha = $Matches[1]
    $name = $Matches[2]
    if ($name -cne $directRef -and $name -cne $peeledRef) {
        throw "git ls-remote returned an unexpected release ref: $name"
    }
    if (-not $refs.ContainsKey($name)) {
        $refs[$name] = @()
    }
    $refs[$name] = @($refs[$name]) + $sha
}

if (@($refs[$directRef]).Count -ne 1 -or @($refs[$peeledRef]).Count -gt 1) {
    throw "Remote release tag is missing or ambiguous: $Tag"
}
$actualCommit = if (@($refs[$peeledRef]).Count -eq 1) {
    [string]$refs[$peeledRef][0]
} else {
    [string]$refs[$directRef][0]
}
if ($actualCommit -cne $ExpectedCommit) {
    throw "Remote release tag $Tag resolves to $actualCommit, expected $ExpectedCommit"
}

Write-Output "Remote release tag $Tag resolves to $actualCommit."
