param(
    [Parameter(Mandatory = $true)] [string]$Archive,
    [Parameter(Mandatory = $true)] [string]$Checksums,
    [string]$TempRoot = $env:TEMP
)

$ErrorActionPreference = 'Stop'
$archiveFile = (Get-Item -LiteralPath $Archive).FullName
$checksumFile = (Get-Item -LiteralPath $Checksums).FullName
$assetName = [IO.Path]::GetFileName($archiveFile)
if ($assetName -cnotmatch '^angelscript-cli-([0-9]+\.[0-9]+\.[0-9]+)-windows-(x64|x86)\.zip$') {
    throw 'Pass the packaged Windows x64 or x86 archive.'
}
$expectedVersion = $Matches[1]
$archiveArch = $Matches[2]
$installer = Join-Path $PSScriptRoot 'install.ps1'
$id = 'AngelScriptCliInstallTest-' + [Guid]::NewGuid().ToString('N')
$root = Join-Path (Get-Item -LiteralPath $TempRoot).FullName $id
[void][IO.Directory]::CreateDirectory($root)
$install = Join-Path $root 'test install'
$exe = Join-Path $install 'angelscript.exe'
$aliases = @('asc.exe', 'angelscript-cli.exe')
$keyName = "Software\$id"
$savedOverride = $env:ANGELSCRIPT_CLI_TEST_PATH_KEY
$savedVersion = $env:ANGELSCRIPT_CLI_VERSION
$savedInstallDir = $env:ANGELSCRIPT_CLI_INSTALL_DIR
$savedArch = $env:ANGELSCRIPT_CLI_ARCH
$original = '%LOCALAPPDATA%\existing;C:\Tools'
$kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
$reg = $null

function Assert-Path([string]$Expected) {
    if ($reg.GetValue('Path', $null, 'DoNotExpandEnvironmentNames') -cne $Expected -or $reg.GetValueKind('Path') -ne $kind) {
        throw "Unexpected isolated registry Path. Expected $Expected with type $kind."
    }
}

function Assert-Version {
    foreach ($candidate in @($exe) + @($aliases | ForEach-Object { Join-Path $install $_ })) {
        $output = & $candidate --version
        if ($LASTEXITCODE -ne 0 -or $output -notmatch ('^angelscript ' + [regex]::Escape($expectedVersion) + '(?:\s|$)')) {
            throw "Unexpected installed version from ${candidate}: $output"
        }
    }
}

try {
    $reg = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($keyName)
    $reg.SetValue('Path', $original, $kind)
    $env:ANGELSCRIPT_CLI_TEST_PATH_KEY = "HKCU:\$keyName"

    & $installer -Archive $archiveFile -InstallDir $install -NoPath
    Assert-Version
    Assert-Path $original
    & $installer -Uninstall -InstallDir $install -NoPath
    if (Test-Path -LiteralPath $install) { throw 'Install directory still exists after -NoPath uninstall.' }
    Assert-Path $original

    1..2 | ForEach-Object {
        & $installer -Archive $archiveFile -Checksums $checksumFile -InstallDir $install
        Assert-Version
        Assert-Path "$original;$install"
    }

    $badChecksums = Join-Path $root 'bad-checksums'
    Set-Content -LiteralPath $badChecksums -Encoding Ascii -Value (('0' * 64) + "  $assetName")
    $rejected = $false
    try {
        & $installer -Archive $archiveFile -Checksums $badChecksums -InstallDir $install
    } catch {
        if ($_ -notmatch 'SHA-256 mismatch') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Installer accepted an incorrect SHA-256.' }
    Assert-Version
    Assert-Path "$original;$install"

    # Substitute local release assets for network requests and exercise the documented iex invocation.
    & $installer -Uninstall -InstallDir $install
    Assert-Path $original
    & {
        function Invoke-WebRequest($Uri, $OutFile, [switch]$UseBasicParsing) {
            $base = 'https://github.com/angelscript-tools/angelscript-cli/releases/latest/download'
            if ($Uri -ceq "$base/SHA256SUMS") {
                Copy-Item -LiteralPath $checksumFile -Destination $OutFile
            } elseif ($Uri -ceq "$base/$assetName") {
                Copy-Item -LiteralPath $archiveFile -Destination $OutFile
            } else {
                throw "Unexpected download URL: $Uri"
            }
        }
        $env:ANGELSCRIPT_CLI_ARCH = $archiveArch
        $env:ANGELSCRIPT_CLI_VERSION = 'latest'
        $env:ANGELSCRIPT_CLI_INSTALL_DIR = $install
        Get-Content -LiteralPath $installer -Raw | Invoke-Expression
    }
    Assert-Version
    Assert-Path "$original;$install"

    1..2 | ForEach-Object {
        & $installer -Uninstall -InstallDir $install
        if (Test-Path -LiteralPath $install) { throw 'Install directory still exists after uninstall.' }
        Assert-Path $original
    }
    Write-Output 'Offline Windows installer test passed.'
} finally {
    $env:ANGELSCRIPT_CLI_TEST_PATH_KEY = $savedOverride
    $env:ANGELSCRIPT_CLI_VERSION = $savedVersion
    $env:ANGELSCRIPT_CLI_INSTALL_DIR = $savedInstallDir
    $env:ANGELSCRIPT_CLI_ARCH = $savedArch
    if ($reg) {
        $reg.Dispose()
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($keyName)
    }
    Remove-Item -LiteralPath $root -Recurse -Force
}
