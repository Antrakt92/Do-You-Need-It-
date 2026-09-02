$ErrorActionPreference = "Stop"
$guard = Join-Path $PSScriptRoot "../scripts/check-release-ref.ps1"
$commit = "0123456789abcdef0123456789abcdef01234567"
$tagObject = "abcdef0123456789abcdef0123456789abcdef01"
$direct = "refs/tags/v0.4.2"
$peeled = "$direct^{}"

function Assert-RefCase {
    param(
        [string]$Name,
        [string[]]$Lines,
        [string]$ExpectedError = "",
        [int]$ExitCode = 0
    )
    # Keep these scenarios offline; capture each response in the scoped stub.
    $caseLines = @($Lines)
    $caseExitCode = $ExitCode
    $stub = {
        $global:LASTEXITCODE = $caseExitCode
        $caseLines
    }.GetNewClosure()
    Set-Item -Path function:git -Value $stub
    $failure = $null
    try {
        $output = & $guard -Tag v0.4.2 -ExpectedCommit $commit -Remote test-only
    } catch {
        $failure = $_.Exception.Message
    }
    if ($ExpectedError) {
        if (-not $failure -or -not $failure.Contains($ExpectedError)) {
            throw "${Name}: expected '$ExpectedError', got '$failure'"
        }
    } elseif ($failure) {
        throw "${Name}: $failure"
    } elseif ($output -notmatch [regex]::Escape("resolves to $commit.")) {
        throw "${Name}: guard did not confirm the expected commit"
    }
}

Assert-RefCase "lightweight tag" @("$commit`t$direct")
Assert-RefCase "annotated tag" @("$tagObject`t$direct", "$commit`t$peeled")
Assert-RefCase "reversed annotated refs" @("$commit`t$peeled", "$tagObject`t$direct")
Assert-RefCase "missing tag" @() "missing or ambiguous"
Assert-RefCase "peeled ref without direct tag" @("$commit`t$peeled") "missing or ambiguous"
Assert-RefCase "duplicate direct refs" @("$commit`t$direct", "$commit`t$direct") "missing or ambiguous"
Assert-RefCase "duplicate peeled refs" @("$tagObject`t$direct", "$commit`t$peeled", "$commit`t$peeled") "missing or ambiguous"
Assert-RefCase "moved lightweight tag" @("$tagObject`t$direct") "expected $commit"
Assert-RefCase "moved annotated tag" @("$commit`t$direct", "$tagObject`t$peeled") "expected $commit"
Assert-RefCase "unexpected ref" @("$commit`t refs/heads/main") "unexpected release ref"
Assert-RefCase "malformed ref" @("invalid") "malformed release ref"
Assert-RefCase "remote read failure" @() "Could not resolve exact remote release tag" 2
$global:LASTEXITCODE = 0
Write-Output "Release ref checks passed (12 cases)."
