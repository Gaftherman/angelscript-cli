param(
    [string]$Version = $env:ANGELSCRIPT_CLI_VERSION,
    [string]$Engine = $env:ANGELSCRIPT_ENGINE_VERSION,
    [switch]$Jit = [bool]$env:ANGELSCRIPT_CLI_JIT,
    [string]$Archive,
    [string]$Checksums,
    [string]$InstallDir = $env:ANGELSCRIPT_CLI_INSTALL_DIR,
    [ValidateSet('', 'x64', 'x86')][string]$TargetArch = $env:ANGELSCRIPT_CLI_ARCH,
    [switch]$NoPath,
    [switch]$Uninstall
)

# Keep preferences and helper functions local when the script is piped to iex.
& {
    $ErrorActionPreference = 'Stop'

    function Get-ComparablePath([string]$Path) {
        [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"')).Replace('/', '\').TrimEnd('\')
    }

    function Update-UserPath([string]$Directory, [bool]$Remove) {
        $keyName = 'Environment'
        $override = $env:ANGELSCRIPT_CLI_TEST_PATH_KEY
        if ($override) {
            if ($override -notmatch '^HKCU:\\Software\\.+$') {
                throw 'ANGELSCRIPT_CLI_TEST_PATH_KEY must be a key below HKCU:\Software.'
            }
            $keyName = $override.Substring(6)
        }
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($keyName, $true)
        if (-not $key) {
            if ($override) { throw "Test registry key does not exist: $override" }
            if ($Remove) { return }
            $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($keyName)
        }
        try {
            $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
            $current = $key.GetValue('Path', $null, 'DoNotExpandEnvironmentNames')
            if ($null -ne $current) {
                $kind = $key.GetValueKind('Path')
                if ($kind -notin @('String', 'ExpandString')) {
                    throw "Unexpected registry type for the user Path: $kind"
                }
            }
            $target = Get-ComparablePath $Directory
            $entries = @()
            if ($current) { $entries = $current.Split(';') }
            $remaining = @($entries | Where-Object { (Get-ComparablePath $_) -ne $target })
            $found = $entries.Count -ne $remaining.Count
            if ($Remove -and $found) {
                $key.SetValue('Path', ($remaining -join ';'), $kind)
            } elseif (-not $Remove -and -not $found) {
                $key.SetValue('Path', (($entries + $Directory) -join ';'), $kind)
            } else {
                return
            }
        } finally {
            $key.Dispose()
        }

        if ($override) { return }
        if (-not ('AngelScriptCli.EnvironmentChange' -as [type])) {
            Add-Type -Namespace AngelScriptCli -Name EnvironmentChange -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr window, uint message, System.UIntPtr wParam, string lParam,
    uint flags, uint timeout, out System.UIntPtr result);
'@
        }
        $result = [UIntPtr]::Zero
        [void][AngelScriptCli.EnvironmentChange]::SendMessageTimeout(
            [IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 2000, [ref]$result)
    }

    function Get-ListedHash([string[]]$Lines, [string]$AssetName) {
        $hashes = @(foreach ($line in $Lines) {
            if ($line -cmatch '^([a-fA-F0-9]{64})  (.+)$' -and $Matches[2] -ceq $AssetName) {
                $Matches[1]
            }
        })
        if ($hashes.Count -ne 1) { throw "Expected one SHA-256 entry for $AssetName in SHA256SUMS." }
        $hashes[0]
    }

    function Save-ReleaseFile([string]$Url, [string]$Destination) {
        $protocol = [Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol = $protocol -bor [Net.SecurityProtocolType]::Tls12
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
        } finally {
            [Net.ServicePointManager]::SecurityProtocol = $protocol
        }
    }

    function Get-InstalledVersion([string]$Directory) {
        $output = & (Join-Path $Directory 'angelscript.exe') --version
        if ($LASTEXITCODE -ne 0 -or $output -notmatch '^angelscript [0-9]+\.[0-9]+\.[0-9]+(?:\s|$)') {
            throw 'The executable did not report a valid angelscript version.'
        }
        $output
    }

    if ($Engine -and $Engine -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw 'The engine must be an AngelScript version such as 2.35.1.'
    }
    # One AngelScript release is installed at a time, like Python: -Engine and -Jit choose which build replaces the
    # installed one (same folder, same commands).
    if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\angelscript-cli' }
    $InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
    $InstallDir = $InstallDir.TrimEnd('\', '/')
    $parent = [IO.Path]::GetDirectoryName($InstallDir)
    if (-not $parent -or $InstallDir.Contains(';')) { throw 'Choose an install directory below the drive root with no semicolons.' }

    $packageFiles = @('angelscript.exe', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'README.md')
    $aliasFiles = @('asc.exe', 'angelscript-cli.exe')
    $existing = Get-Item -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if (-not $existing.PSIsContainer -or ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "The install path must be a regular directory: $InstallDir"
        }
        $contents = @(Get-ChildItem -LiteralPath $InstallDir -Force)
        $unknown = @($contents | Where-Object {
            $_.PSIsContainer -or ($_.Name -cnotin $packageFiles -and $_.Name -cnotin $aliasFiles) -or ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
        })
        if ($unknown.Count) { throw "The install directory contains files owned by something else: $InstallDir" }
    }
    if ($Uninstall) {
        if ($existing) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
        if (-not $NoPath) { Update-UserPath $InstallDir $true }
        Write-Output 'Uninstalled angelscript. Open a new terminal to pick up the PATH change.'
        return
    }

    $arch = $env:PROCESSOR_ARCHITEW6432
    if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
    if (-not $TargetArch -and $arch -eq 'ARM64') { throw 'No Windows arm64 build of angelscript-cli exists yet.' }
    $platform = if ($TargetArch) { $TargetArch } else { switch ($arch) { 'AMD64' { 'x64' } 'x86' { 'x86' } default { throw "Unsupported Windows architecture: $arch. The available builds are x64 and x86." } } }
    if (-not $Version) { $Version = 'latest' }
    if ($Version -cne 'latest' -and $Version -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw 'Version must be x.y.z or latest.'
    }

    [void][IO.Directory]::CreateDirectory($parent)
    $work = Join-Path $parent ('.angelscript-cli-' + [Guid]::NewGuid().ToString('N'))
    $stage = Join-Path $work 'stage'
    $backup = Join-Path $work 'previous'
    $keepBackup = $false
    [void][IO.Directory]::CreateDirectory($work)
    try {
        if ($Archive) {
            $zipPath = (Get-Item -LiteralPath $Archive).FullName
            $asset = [IO.Path]::GetFileName($zipPath)
            if (-not $Checksums) { Write-Output 'Local archive supplied without SHA256SUMS. Skipping checksum verification.' }
        } else {
            $base = 'https://github.com/Gaftherman/angelscript-cli/releases'
            if ($Version -eq 'latest') { $base += '/latest/download' } else { $base += "/download/v$Version" }
            if (-not $Checksums) {
                $Checksums = Join-Path $work 'SHA256SUMS'
                Save-ReleaseFile "$base/SHA256SUMS" $Checksums
            }
            if ($Version -eq 'latest') {
                $assets = @(foreach ($line in (Get-Content -LiteralPath $Checksums)) {
                    if ($line -cmatch ('^[a-fA-F0-9]{64}  (angelscript-cli-[0-9]+\.[0-9]+\.[0-9]+-windows-' + $platform + '\.zip)$')) {
                        $Matches[1]
                    }
                })
                if ($assets.Count -ne 1) { throw "Expected one Windows $platform asset in the latest release SHA256SUMS." }
                $asset = $assets[0]
            } else {
                $asset = "angelscript-cli-$Version-windows-$platform.zip"
            }
            if ($Engine -or $Jit) {
                # Builds against a given release are listed as angelscript-cli-<cli>-as<engine>[-jit]-windows-<arch>.zip.
                # With -Jit alone, the newest release that has a JIT build is used.
                $engineName = if ($Engine) { [regex]::Escape($Engine) } else { '[0-9]+\.[0-9]+\.[0-9]+' }
                $jitName = if ($Jit) { '-jit' } else { '' }
                $engineAssets = @(foreach ($line in (Get-Content -LiteralPath $Checksums)) {
                    if ($line -cmatch ('^[a-fA-F0-9]{64}  (angelscript-cli-[0-9]+\.[0-9]+\.[0-9]+-as(' + $engineName + ')' + $jitName + '-windows-' + $platform + '\.zip)$')) {
                        [pscustomobject]@{ Name = $Matches[1]; Engine = [version]$Matches[2] }
                    }
                })
                $asset = if ($engineAssets.Count) { ($engineAssets | Sort-Object Engine -Descending | Select-Object -First 1).Name } else { '' }
                if (-not $asset) {
                    $wanted = if ($Engine) { "AngelScript $Engine" } else { 'AngelScript' }
                    if ($Jit) {
                        $wanted += ' with the JIT'
                        $hint = 'Build it from source with: python scripts/build-engine.py <version> --jit (the JIT needs AngelScript 2.37 or later and a 64-bit system).'
                    } else {
                        $hint = "Build it from source with: python scripts/build-engine.py $Engine"
                    }
                    throw "No prebuilt build of $wanted for Windows $platform in this release. $hint"
                }
            }
            $zipPath = Join-Path $work $asset
            Save-ReleaseFile "$base/$asset" $zipPath
        }
        if ($Checksums) {
            $expected = Get-ListedHash (Get-Content -LiteralPath $Checksums) $asset
            if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $expected) {
                throw "SHA-256 mismatch for $asset."
            }
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $names = @($zip.Entries | ForEach-Object { $_.FullName })
            $missing = @($packageFiles | Where-Object { $_ -cnotin $names })
            if ($names.Count -ne $packageFiles.Count -or $missing.Count) {
                throw "Unexpected files in $asset. Expected $($packageFiles -join ', ') at the archive root."
            }
        } finally {
            $zip.Dispose()
        }
        [IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $stage)
        $null = Get-InstalledVersion $stage

        if ($existing) { [IO.Directory]::Move($InstallDir, $backup) }
        try {
            [IO.Directory]::Move($stage, $InstallDir)
        } catch {
            if ($existing) {
                $keepBackup = $true
                [IO.Directory]::Move($backup, $InstallDir)
                $keepBackup = $false
            }
            throw
        }
        foreach ($alias in $aliasFiles) {
            Copy-Item -LiteralPath (Join-Path $InstallDir 'angelscript.exe') -Destination (Join-Path $InstallDir $alias)
        }
        if (-not $NoPath) { Update-UserPath $InstallDir $false }
        Get-InstalledVersion $InstallDir
        Write-Output 'Open a new terminal to pick up the PATH change.'
    } finally {
        if ($keepBackup) {
            Write-Warning "The previous installation could not be restored. It is at $backup."
        } else {
            Remove-Item -LiteralPath $work -Recurse -Force
        }
    }
}
