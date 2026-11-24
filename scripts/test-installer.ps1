#Requires -Version 5.1
<#
.SYNOPSIS
Runs the Windows setup program silently for the current user, checks it, then uninstalls it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Setup,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$Version
)

$ErrorActionPreference = 'Stop'
$setupPath = (Resolve-Path -LiteralPath $Setup).Path
$target = Join-Path ([System.IO.Path]::GetTempPath()) ("angelscript-setup-" + [guid]::NewGuid().ToString('N'))
$log = Join-Path ([System.IO.Path]::GetTempPath()) ("angelscript-setup-" + [guid]::NewGuid().ToString('N') + '.log')

function Get-UserPath { [Environment]::GetEnvironmentVariable('Path', 'User') }
function Assert-True($condition, $message) { if (-not $condition) { throw $message } }

$before = Get-UserPath
try {
    $install = Start-Process -FilePath $setupPath -Wait -PassThru -ArgumentList @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', "/DIR=$target", '/TASKS=addtopath', "/LOG=$log")
    Assert-True ($install.ExitCode -eq 0) "Setup exited with $($install.ExitCode). See $log"

    foreach ($name in 'angelscript.exe', 'asc.exe', 'angelscript-cli.exe') {
        Assert-True (Test-Path -LiteralPath (Join-Path $target $name)) "Missing $name"
        $output = & (Join-Path $target $name) --version
        Assert-True ($LASTEXITCODE -eq 0 -and $output -match "^angelscript $([regex]::Escape($Version)) ") "Unexpected --version from ${name}: $output"
    }
    $entries = (Get-UserPath) -split ';'
    Assert-True ($entries -contains $target) 'The install folder is not on the user PATH'

    $uninstaller = Join-Path $target 'unins000.exe'
    Assert-True (Test-Path -LiteralPath $uninstaller) 'Missing uninstaller'
    $remove = Start-Process -FilePath $uninstaller -Wait -PassThru -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
    Assert-True ($remove.ExitCode -eq 0) "Uninstaller exited with $($remove.ExitCode)"
    for ($i = 0; $i -lt 50 -and (Test-Path -LiteralPath (Join-Path $target 'angelscript.exe')); $i++) { Start-Sleep -Milliseconds 200 }

    Assert-True (-not (Test-Path -LiteralPath (Join-Path $target 'angelscript.exe'))) 'The uninstaller left angelscript.exe'
    Assert-True (((Get-UserPath) -split ';') -notcontains $target) 'The install folder is still on the user PATH'
    $beforeEntries = @($before -split ';' | Where-Object { $_ })
    $afterEntries = @((Get-UserPath) -split ';' | Where-Object { $_ })
    Assert-True (($beforeEntries -join ';') -eq ($afterEntries -join ';')) 'The user PATH entries differ from the ones before installing'
    Write-Host 'Windows setup test passed.'
}
finally {
    if ((Get-UserPath) -ne $before) { [Environment]::SetEnvironmentVariable('Path', $before, 'User') }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
}
