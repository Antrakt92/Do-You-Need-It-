param(
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [switch]$Forever
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Repository)) {
    throw "Repository is required via -Repository or GITHUB_REPOSITORY"
}
if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
    throw "GH_TOKEN is required to verify release policy"
}

$policy = gh api "repos/$Repository/immutable-releases" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or
    $null -eq $policy -or
    $policy.enabled -isnot [bool] -or
    -not $policy.enabled) {
    throw "Repository release immutability must be enabled"
}

$summaries = @(gh api "repos/$Repository/rulesets?includes_parents=false" | ConvertFrom-Json |
    Where-Object { $_.name -ceq "Protect release tags" -and $_.target -ceq "tag" })
if ($LASTEXITCODE -ne 0 -or $summaries.Count -ne 1) {
    throw "Repository must have exactly one Protect release tags ruleset"
}

$ruleset = gh api "repos/$Repository/rulesets/$($summaries[0].id)?includes_parents=false" | ConvertFrom-Json
$included = @($ruleset.conditions.ref_name.include)
$validIncludes = ($included.Count -eq 1 -and $included[0] -ceq 'refs/tags/v*' -and -not $Forever) -or
    ($included.Count -eq 2 -and $included -ccontains 'refs/tags/v*' -and $included -ccontains 'refs/tags/forever-v*')
$ruleTypes = @($ruleset.rules | ForEach-Object { [string]$_.type } | Sort-Object)
if ($LASTEXITCODE -ne 0 -or
    $ruleset.enforcement -cne "active" -or
    @($ruleset.bypass_actors).Count -ne 0 -or
    -not $validIncludes -or
    @($ruleset.conditions.ref_name.exclude).Count -ne 0 -or
    ($ruleTypes -join ",") -cne "deletion,non_fast_forward") {
    throw "Release tags must reject deletion and non-fast-forward updates without bypass actors"
}

Write-Output "Immutable releases and protected v* tag history are enabled."
