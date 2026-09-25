param(
    [switch]$Install,
    [string]$LuaPackageVersion = "5.1.5"
)

$ErrorActionPreference = "Stop"
$script:PublishedToolDirs = @{}

function Resolve-Tool {
    param([string[]]$Names)

    foreach ($name in $Names) {
        if (Test-Path -LiteralPath $name -PathType Leaf) {
            return (Resolve-Path -LiteralPath $name).Path
        }

        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return $command.Source
        }
    }

    return $null
}

function Install-Lua51 {
    $choco = Resolve-Tool -Names @("choco")
    if (-not $choco) {
        throw "Missing Chocolatey; cannot install lua51 automatically."
    }

    Write-Host "Installing lua51 $LuaPackageVersion with Chocolatey..."
    # The lua51 Chocolatey package publishes no checksums, so installs cannot
    # verify them. Integrity is anchored after install instead: the pinned
    # tool path wins resolution and Assert-Lua51Version requires the exact
    # pinned version below.
    & $choco install lua51 --version $LuaPackageVersion -y --no-progress --allow-empty-checksums 2>&1 |
        ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "choco install lua51 $LuaPackageVersion exited with code $LASTEXITCODE"
    }
}

function Require-Tool {
    param(
        [string]$Label,
        [string[]]$Names
    )

    $path = Resolve-Tool -Names $Names
    if (-not $path -and $Install) {
        Install-Lua51
        $path = Resolve-Tool -Names $Names
    }
    if (-not $path) {
        throw "Missing $Label. Re-run with -Install, or install Chocolatey package lua51 $LuaPackageVersion."
    }

    Write-Host "${Label}: $path"
    return $path
}

function Assert-Lua51Version {
    param(
        [string]$Label,
        [string]$Path,
        [string]$ExpectedVersion
    )

    $output = @(& $Path -v 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "$Label -v failed with exit code $LASTEXITCODE`: $($output -join ' ')"
    }
    $text = ($output -join "`n").Trim()
    # Exact pinned match: 5.1.5 must not accept 5.1.50 or a LuaJIT 5.1 shim.
    $escaped = [regex]::Escape($ExpectedVersion)
    if ($text -notmatch "Lua\s+$escaped(?!\.\d)") {
        throw "$Label must be Lua $ExpectedVersion, got: $text"
    }
    Write-Host "${Label} version: $text"
}

function Add-ToolDirectoryToPath {
    param([string]$ToolPath)

    $directory = Split-Path -Parent $ToolPath
    $pathParts = @($env:Path -split ';')
    $alreadyInPath = $false
    foreach ($part in $pathParts) {
        if ([System.StringComparer]::OrdinalIgnoreCase.Equals($part, $directory)) {
            $alreadyInPath = $true
            break
        }
    }

    if (-not $alreadyInPath) {
        $env:Path = "$directory;$env:Path"
        Write-Host "Added $directory to PATH for this process."
    }

    if ($env:GITHUB_PATH -and -not $script:PublishedToolDirs.ContainsKey($directory)) {
        Add-Content -LiteralPath $env:GITHUB_PATH -Value $directory -Encoding utf8
        $script:PublishedToolDirs[$directory] = $true
        Write-Host "Published $directory to GITHUB_PATH for later workflow steps."
    }
}

$lua = Require-Tool `
    -Label "lua5.1" `
    -Names @("C:\ProgramData\chocolatey\lib\lua51\tools\lua5.1.exe", "lua5.1")

$luac = Require-Tool `
    -Label "luac5.1" `
    -Names @("C:\ProgramData\chocolatey\lib\lua51\tools\luac5.1.exe", "luac5.1")

Add-ToolDirectoryToPath -ToolPath $lua
Add-ToolDirectoryToPath -ToolPath $luac

Assert-Lua51Version -Label "lua5.1" -Path $lua -ExpectedVersion $LuaPackageVersion
Assert-Lua51Version -Label "luac5.1" -Path $luac -ExpectedVersion $LuaPackageVersion

Write-Host "Do You Need It check tools are available."
