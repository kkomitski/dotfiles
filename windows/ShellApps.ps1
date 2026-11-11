# Portable Windows Terminal instances keep data and IPC identity separate.
function Install-PortableRuntime([string]$InstallRoot, $Spec, [string]$CacheDirectory) {
    $runtime = Join-Path $InstallRoot 'runtime'
    $versionFile = Join-Path $runtime 'runtime-version.txt'
    if ((Test-Path $versionFile) -and [IO.File]::ReadAllText($versionFile) -eq $Spec.version -and (Test-Path (Join-Path $runtime 'WindowsTerminal.exe'))) {
        if (-not (Test-Path (Join-Path $runtime '.portable'))) { throw ('Portable marker missing: '+$runtime) }
        return $runtime
    }
    if (Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq (Join-Path $runtime 'WindowsTerminal.exe')}) {
        throw ('Close '+$InstallRoot+' windows before upgrading its runtime. Existing sessions have not been stopped.')
    }
    [IO.Directory]::CreateDirectory($CacheDirectory) | Out-Null
    $zip = Join-Path $CacheDirectory ('WindowsTerminal-'+$Spec.version+'-'+$Spec.architecture+'.zip')
    if (-not (Test-Path $zip)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $Spec.url -OutFile $zip -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $Spec.sha256) { throw 'Portable terminal download checksum mismatch.' }
    $expanded = Join-Path $CacheDirectory ('terminal-'+$Spec.version+'-expanded')
    if (-not (Test-Path (Join-Path $expanded ('terminal-'+$Spec.version+'\WindowsTerminal.exe')))) {
        Expand-Archive -LiteralPath $zip -DestinationPath $expanded -Force
    }
    [IO.Directory]::CreateDirectory($runtime) | Out-Null
    Copy-Item -Path (Join-Path $expanded ('terminal-'+$Spec.version+'\*')) -Destination $runtime -Recurse -Force
    [IO.File]::WriteAllText((Join-Path $runtime '.portable'),'')
    [IO.File]::WriteAllText($versionFile,$Spec.version)
    return $runtime
}
function Build-ShellLauncher([string]$Name,[string]$InstallRoot,[string]$AssetsDirectory,[string]$IconPath,[string]$Compiler,[string]$Source,[string]$Define) {
    [IO.Directory]::CreateDirectory($InstallRoot) | Out-Null
    [IO.Directory]::CreateDirectory($AssetsDirectory) | Out-Null
    $executable = Join-Path $InstallRoot ($Name+'.exe')
    $localSource = Join-Path $InstallRoot 'Launcher.cs'
    Copy-Item -LiteralPath $Source -Destination $localSource -Force
    $output = Join-Path $AssetsDirectory ('launcher-'+[Guid]::NewGuid().ToString('N')+'.exe')
    $arguments = '/nologo /target:winexe /platform:x64 /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /win32icon:"{0}" /resource:"{0}",ShellLauncher.Icon /out:"{1}" "{2}"' -f $IconPath,$output,$localSource
    if ($Define) { $arguments = '/define:'+$Define+' '+$arguments }
    $build = Start-Process -FilePath $Compiler -ArgumentList $arguments -Wait -PassThru -RedirectStandardOutput (Join-Path $AssetsDirectory 'compiler.log') -RedirectStandardError (Join-Path $AssetsDirectory 'compiler-errors.log')
    if ($build.ExitCode -ne 0) { Get-Content (Join-Path $AssetsDirectory 'compiler.log'); throw ('Compilation failed: '+$Name) }
    $check = Start-Process -FilePath $output -ArgumentList '--self-check' -Wait -PassThru
    if ($check.ExitCode -ne 0) { throw ('Embedded icon check failed: '+$Name) }
    foreach ($helper in @(Get-Process -Name $Name -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $executable})) {
        Stop-Process -Id $helper.Id -Force
        $helper.WaitForExit()
    }
    Move-Item -LiteralPath $output -Destination $executable -Force
    return $executable
}
function New-PrivateSettings($Seed,$TerminalProfile,$Scheme,$Actions,$Bindings,[bool]$Wsl) {
    $settings = $Seed | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    Set-Field $settings profiles ([pscustomobject]@{defaults=[pscustomobject]@{};list=@()})
    Set-Field $settings disabledProfileSources @('Windows.Terminal.Wsl','Microsoft.WSL','Windows.Terminal.Azure','Windows.Terminal.PowershellCore','Windows.Terminal.VisualStudio','Windows.Terminal.SSH')
    # Do not inherit a launch command or restored mixed-shell window from the old app.
    if ($settings.PSObject.Properties['startupActions']) { $settings.PSObject.Properties.Remove('startupActions') }
    Set-Field $settings firstWindowPreference 'defaultProfile'
    Set-Field $settings windowingBehavior 'useNew'
    $settings = Merge-TerminalSettings $settings $TerminalProfile $Scheme $Actions $Bindings
    if ($Wsl) {
        $settings.profiles.list += @(
            [pscustomobject]@{guid='{61c54bbd-c2c6-5271-96e7-009a87ff44bf}';hidden=$true},
            [pscustomobject]@{guid='{0caa0dad-35be-5f56-a8ff-afceeeaa6101}';hidden=$true})
    } else {
        $settings.profiles.list += @([pscustomobject]@{guid='{0caa0dad-35be-5f56-a8ff-afceeeaa6101}';name='Command Prompt';commandline='%SystemRoot%\System32\cmd.exe';hidden=$false})
    }
    return $settings
}
