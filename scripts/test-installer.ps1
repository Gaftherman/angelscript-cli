#Requires -Version 5.1
<#
.SYNOPSIS
Runs the Windows setup program silently for the current user, checks it, then uninstalls it.
.DESCRIPTION
A setup installs one AngelScript release, like Python. Without -Releases the setup holds a single build and the
default install is checked. With -Releases (newest first, the versions bundled in the setup) the test also installs
another release as a custom install over the first one, and every release in -JitReleases with its JIT variant.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Setup,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$Version,
    [string[]]$Releases = @(),
    [string[]]$JitReleases = @()
)
$ErrorActionPreference = 'Stop'
$setupPath = (Resolve-Path -LiteralPath $Setup).Path
$target = Join-Path ([System.IO.Path]::GetTempPath()) ("angelscript-setup-" + [guid]::NewGuid().ToString('N'))
$log = Join-Path ([System.IO.Path]::GetTempPath()) ("angelscript-setup-" + [guid]::NewGuid().ToString('N') + '.log')
function Get-UserPath { [Environment]::GetEnvironmentVariable('Path', 'User') }
function Assert-True($condition, $message) { if (-not $condition) { throw $message } }
function Get-ComponentId([string]$Release) { 'as' + ($Release -replace '\.', '_') }
function Invoke-Setup([string[]]$Extra) {
    $run = Start-Process -FilePath $setupPath -Wait -PassThru -ArgumentList (@(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', "/DIR=$target", '/NOICONS', "/LOG=$log") + $Extra)
    Assert-True ($run.ExitCode -eq 0) "Setup exited with $($run.ExitCode). See $log"
}
# Every command must report the CLI version, and, when given, the AngelScript release and the JIT state.
function Assert-Installed([string]$Release, [string]$Jit) {
    foreach ($name in 'angelscript.exe', 'asc.exe', 'angelscript-cli.exe') {
        Assert-True (Test-Path -LiteralPath (Join-Path $target $name)) "Missing $name"
        $output = & (Join-Path $target $name) --version
        Assert-True ($LASTEXITCODE -eq 0 -and $output -match "^angelscript $([regex]::Escape($Version)) ") "Unexpected --version from ${name}: $output"
        if ($Release) {
            Assert-True ($output -match "AngelScript $([regex]::Escape($Release)),") "$name reports another AngelScript release (expected ${Release}): $output"
        }
        if ($Jit) {
            Assert-True ($output -match "jit: $Jit\)") "$name reports another JIT state (expected ${Jit}): $output"
        }
    }
    $stray = @(Get-ChildItem -LiteralPath $target -Filter 'angelscript-2.*.exe' -ErrorAction SilentlyContinue)
    Assert-True ($stray.Count -eq 0) "A setup installs one release, but found $($stray.Name -join ', ')"
}
$before = Get-UserPath
try {
    Invoke-Setup @('/TASKS=addtopath')
    if ($Releases.Count) {
        Assert-Installed $Releases[0] 'unavailable'
    } else {
        Assert-Installed $null $null
    }
    $entries = (Get-UserPath) -split ';'
    Assert-True ($entries -contains $target) 'The install folder is not on the user PATH'
    if ($Releases.Count -ge 2) {
        # A file left by setup 1.1 (other releases sat next to the default one) must go when the setup runs again.
        $leftover = Join-Path $target 'angelscript-2.35.1.exe'
        Copy-Item -LiteralPath (Join-Path $target 'angelscript.exe') -Destination $leftover
        $picked = $Releases[1]
        Invoke-Setup @("/COMPONENTS=main,engines,engines\$(Get-ComponentId $picked)")
        Assert-Installed $picked 'unavailable'
        Assert-True (-not (Test-Path -LiteralPath $leftover)) 'The setup left a file of an older layout'
    }
    foreach ($release in $JitReleases) {
        $id = Get-ComponentId $release
        Invoke-Setup @("/COMPONENTS=main,engines,engines\$id,engines\$id\jit")
        Assert-Installed $release 'angelsea'
        # Running it again without the JIT component goes back to the interpreter build of the same release.
        Invoke-Setup @("/COMPONENTS=main,engines,engines\$id")
        Assert-Installed $release 'unavailable'
    }
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
