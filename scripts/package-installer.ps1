#Requires -Version 5.1
<#
.SYNOPSIS
Builds the Windows setup program with Inno Setup and adds its checksum to dist/SHA256SUMS.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Binary,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$Version,
    [string]$Compiler,
    [string]$EngineDir,
    [ValidateSet('x64', 'x86')][string]$Arch = 'x64'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'

if (-not $Compiler) {
    $candidates = @(
        (Get-Command ISCC.exe -ErrorAction SilentlyContinue | ForEach-Object Source),
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    $Compiler = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}
if (-not $Compiler) { throw 'Inno Setup 6 was not found. Install it (winget install JRSoftware.InnoSetup) or pass -Compiler.' }

$binaryPath = (Resolve-Path -LiteralPath $Binary).Path
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$distFull = (Resolve-Path -LiteralPath $dist).Path

$engineArgs = @()
if ($EngineDir) {
    $engineFull = (Resolve-Path -LiteralPath $EngineDir).Path
    if (-not (Get-ChildItem -LiteralPath $engineFull -Filter "angelscript-*.exe")) { throw "No angelscript-<version>.exe in $engineFull" }
    $versions = @(Get-ChildItem -LiteralPath $engineFull -Filter 'angelscript-*.exe' |
        ForEach-Object { $_.BaseName -replace '^angelscript-', '' } |
        Where-Object { $_ -match '^[0-9]+\.[0-9]+\.[0-9]+[a-z]?$' } |
        Sort-Object { [version]($_ -replace '[a-z]$', '') } -Descending)
    if (-not $versions) { throw "No angelscript-<version>.exe in $engineFull" }
    $engineArgs = @("/DEngineDir=$engineFull", "/DEngineList=$($versions -join ';')")
}

& $Compiler @engineArgs "/DAppArch=$Arch" "/DAppVersion=$Version" "/DSourceExe=$binaryPath" "/DLicenseFile=$(Join-Path $root 'LICENSE')" `
    "/DNoticesFile=$(Join-Path $root 'docs/THIRD_PARTY_NOTICES.md')" "/DOutputDir=$distFull" `
    (Join-Path $root 'packaging\windows\angelscript.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

$asset = "angelscript-cli-$Version-windows-$Arch-setup.exe"
$assetPath = Join-Path $distFull $asset
if (-not (Test-Path -LiteralPath $assetPath)) { throw "Missing $assetPath" }

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $assetPath).Hash.ToLowerInvariant()
$manifest = Join-Path $distFull 'SHA256SUMS'
$lines = @()
if (Test-Path -LiteralPath $manifest) {
    $lines = @(Get-Content -LiteralPath $manifest | Where-Object { $_ -and $_ -notmatch ('  ' + [regex]::Escape($asset) + '$') })
}
$lines += "$hash  $asset"
$text = (($lines | Sort-Object) -join "`n") + "`n"
[System.IO.File]::WriteAllText($manifest, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host "Created $assetPath"
