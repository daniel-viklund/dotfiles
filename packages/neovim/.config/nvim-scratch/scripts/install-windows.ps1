#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidatePattern('^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$')]
    [string]$AppName = 'nvim',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$configSource = Split-Path -Parent $PSScriptRoot
$configBase = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { $env:LOCALAPPDATA }

if ($DryRun) {
    Write-Output @"
Source: $configSource
Destination: $configBase\$AppName
Use WinGet to ensure Neovim >= 0.12, Git, tree-sitter-cli >= 0.26.1,
ripgrep, lazygit, 7-Zip, and WinLibs GCC (reuse existing GCC).
Reuse Windows curl, tar, and PowerShell; expose Git's GNU tar to Neovim.
Back up any existing destination, then copy the config.
Install locked plugins, compile configured parsers, and install
Lua/Rust language servers through Mason. Install stable GNU Rust with rustup,
including rustfmt and Clippy, for development and Blink's matcher.
"@
    return
}

if ($env:OS -ne 'Windows_NT') { throw 'This installer requires Windows.' }
$architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($architecture -ne 'AMD64') { throw 'This installer currently supports Windows x64.' }
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'Install/update App Installer from Microsoft Store (https://aka.ms/getwinget), then rerun.'
}

function Update-SessionPath {
    # Keep paths from the current shell, including an activated compiler environment.
    $paths = @($env:Path) + @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
    )
    $env:Path = (($paths -join ';') -split ';' | Where-Object { $_ } | Select-Object -Unique) -join ';'
}

function Install-Package([string]$Id, [string]$Override = '') {
    $extraArguments = @()
    if ($Override) { $extraArguments = @('--override', $Override) }
    & winget.exe install --id $Id --exact --source winget --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity @extraArguments
    # WinGet uses this status when a package is already current.
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        throw "WinGet failed for $Id (exit $LASTEXITCODE)."
    }
    Update-SessionPath
}

function Ensure-Tool([string]$Executable, [string]$Id, [version]$Minimum = '0.0.0') {
    $command = Get-Command $Executable -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        if ($Minimum -eq [version]'0.0.0') { return }
        $output = (& $command.Source --version | Select-Object -First 1)
        if ($output -match '(\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge $Minimum) { return }
    }
    Install-Package $Id
    $command = Get-Command $Executable -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) { throw "$Executable is not on PATH. Open a new PowerShell window and rerun." }
    if ($Minimum -ne [version]'0.0.0') {
        $output = (& $command.Source --version | Select-Object -First 1)
        if ($output -notmatch '(\d+\.\d+\.\d+)' -or [version]$Matches[1] -lt $Minimum) {
            throw "$Executable >= $Minimum is required. An older installation may be shadowing WinGet's version on PATH."
        }
    }
}

Update-SessionPath
Ensure-Tool 'nvim.exe' 'Neovim.Neovim' '0.12.0'
Ensure-Tool 'git.exe' 'Git.Git'
Ensure-Tool 'tree-sitter.exe' 'tree-sitter.tree-sitter-cli' '0.26.1'
Ensure-Tool 'rg.exe' 'BurntSushi.ripgrep.MSVC'
Ensure-Tool 'lazygit.exe' 'JesseDuffield.lazygit'

# 7-Zip does not add itself to PATH. Only Neovim needs the extra archive paths.
$extraPaths = @()
$sevenZip = Join-Path $env:ProgramFiles '7-Zip'
if (-not (Get-Command 7z.exe -ErrorAction SilentlyContinue) -and -not (Test-Path "$sevenZip\7z.exe")) {
    Install-Package '7zip.7zip'
}
if (Test-Path "$sevenZip\7z.exe") { $extraPaths += $sevenZip }

$gitExecutable = (Get-Command git.exe -CommandType Application).Source
$gitRoot = Split-Path -Parent (Split-Path -Parent $gitExecutable)
$gitUsrBin = Join-Path $gitRoot 'usr\bin'
if (Test-Path "$gitUsrBin\tar.exe") { $extraPaths += $gitUsrBin }

# GCC serves both Tree-sitter and Rust's GNU toolchain.
if (-not (Get-Command gcc.exe -ErrorAction SilentlyContinue)) {
    Install-Package 'BrechtSanders.WinLibs.POSIX.UCRT'
    if (-not (Get-Command gcc.exe -ErrorAction SilentlyContinue)) {
        throw 'GCC is not on PATH. Open a new PowerShell window and rerun.'
    }
}

$cargoBase = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
$env:Path = (Join-Path $cargoBase 'bin') + ';' + $env:Path
if (-not (Get-Command rustup.exe -ErrorAction SilentlyContinue)) {
    Install-Package 'Rustlang.Rustup' '-y --profile minimal --default-host x86_64-pc-windows-gnu --default-toolchain stable'
}
& rustup.exe toolchain install stable-x86_64-pc-windows-gnu --profile minimal --component rustfmt --component clippy
if ($LASTEXITCODE -ne 0) { throw 'Rust toolchain installation failed.' }
$toolchains = & rustup.exe toolchain list
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Rust toolchains.' }
if (-not ($toolchains -match '\(default\)')) {
    & rustup.exe default stable-x86_64-pc-windows-gnu
    if ($LASTEXITCODE -ne 0) { throw 'Could not set the initial Rust toolchain.' }
}

foreach ($tool in @('curl.exe', 'tar.exe')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool is required (included in current Windows 10/11)." }
}

$previousAppName = $env:NVIM_APPNAME
$previousSource = $env:NVIM_CONFIG_SOURCE
$previousExtraPaths = $env:NVIM_INSTALL_EXTRA_PATHS
try {
    $env:NVIM_APPNAME = $AppName
    $env:NVIM_CONFIG_SOURCE = $configSource
    $env:NVIM_INSTALL_EXTRA_PATHS = $extraPaths -join ';'
    & nvim.exe --headless -u NONE -S (Join-Path $PSScriptRoot 'bootstrap.lua')
    if ($LASTEXITCODE -ne 0) { throw "Neovim setup failed (exit $LASTEXITCODE). See the output above." }
} finally {
    $env:NVIM_APPNAME = $previousAppName
    $env:NVIM_CONFIG_SOURCE = $previousSource
    $env:NVIM_INSTALL_EXTRA_PATHS = $previousExtraPaths
}
Write-Host "Installed. Launch with: `$env:NVIM_APPNAME='$AppName'; nvim"
