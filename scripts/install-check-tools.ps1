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
        [string]$Path
    )

    $output = @(& $Path -v 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "$Label -v failed with exit code $LASTEXITCODE`: $($output -join ' ')"
    }
    $text = ($output -join "`n").Trim()
    if ($text -notmatch "Lua\s+5\.1") {
        throw "$Label must be Lua 5.1, got: $text"
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
    -Names @("lua5.1", "C:\ProgramData\chocolatey\lib\lua51\tools\lua5.1.exe")

$luac = Require-Tool `
    -Label "luac5.1" `
    -Names @("luac5.1", "C:\ProgramData\chocolatey\lib\lua51\tools\luac5.1.exe")

Add-ToolDirectoryToPath -ToolPath $lua
Add-ToolDirectoryToPath -ToolPath $luac

Assert-Lua51Version -Label "lua5.1" -Path $lua
Assert-Lua51Version -Label "luac5.1" -Path $luac

Write-Host "Do You Need It check tools are available."
