[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Distro,
    [Parameter(Mandatory=$true)][string]$WslUser,
    [Parameter(Mandatory=$true)][string]$WslHome,
    [string]$FontDirectory,
    [switch]$InstallDependencies,
    [switch]$Check,
    [switch]$NoStart
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Configuration.ps1')
. (Join-Path $PSScriptRoot 'Icon.ps1')
. (Join-Path $PSScriptRoot 'ShellApps.ps1')
foreach ($value in @($Distro,$WslUser,$WslHome)) {
    if ($value -match '["\r\n]') { throw 'Distro, user and home must not contain quotes or newlines.' }
}
if (-not $WslHome.StartsWith('/')) { throw 'WslHome must be an absolute Linux path.' }
$localPath = [Environment]::GetFolderPath('LocalApplicationData')
$programsPath = [Environment]::GetFolderPath('Programs')
$startupPath = [Environment]::GetFolderPath('Startup')
$documentsPath = [Environment]::GetFolderPath('MyDocuments')
$assets = Join-Path $localPath 'WSL Terminal'
$install = Join-Path $localPath 'Programs\WSL Terminal'
$backups = Join-Path $assets 'backups'
$exe = Join-Path $install 'WSL Terminal.exe'
$ico = Join-Path $assets 'WSL Terminal.ico'
$png = Join-Path $assets 'WSL Terminal.png'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$terminalAlias = Join-Path $localPath 'Microsoft\WindowsApps\wt.exe'
$terminalProfile = Read-JsonFile (Join-Path $PSScriptRoot 'terminal\profile.json')
$scheme = Read-JsonFile (Join-Path $PSScriptRoot 'terminal\scheme.json')
$actions = @(Read-JsonFile (Join-Path $PSScriptRoot 'terminal\actions.json'))
$bindings = @(Read-JsonFile (Join-Path $PSScriptRoot 'terminal\keybindings.json'))
$keyboard = Read-JsonFile (Join-Path $PSScriptRoot 'powertoys\keyboard.json')
$runtimeSpec = Read-JsonFile (Join-Path $PSScriptRoot 'terminal\runtime.json')
function Find-InstalledFile($Candidates) {
    foreach ($candidate in $Candidates) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    return $null
}
$ahkCandidates = @((Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),(Join-Path $localPath 'Programs\AutoHotkey\v2\AutoHotkey64.exe'))
$ptCandidates = @((Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe'),(Join-Path $localPath 'PowerToys\PowerToys.exe'),(Join-Path $localPath 'Programs\PowerToys\PowerToys.exe'))
$ahkExe = Find-InstalledFile $ahkCandidates
$powerToysExe = Find-InstalledFile $ptCandidates
if (-not $Check -and $InstallDependencies) {
    $packages = @()
    if (-not (Test-Path -LiteralPath $terminalAlias)) { $packages += 'Microsoft.WindowsTerminal' }
    if (-not $ahkExe) { $packages += 'AutoHotkey.AutoHotkey' }
    if (-not $powerToysExe) { $packages += 'Microsoft.PowerToys' }
    foreach ($package in $packages) {
        $winget = Get-Command winget.exe -ErrorAction Stop
        $result = Start-Process -FilePath $winget.Source -ArgumentList @('install','--id',$package,'--exact','--source','winget','--accept-package-agreements','--accept-source-agreements') -Wait -PassThru
        if ($result.ExitCode -ne 0) { throw ('Dependency installation failed: '+$package) }
    }
    $ahkExe = Find-InstalledFile $ahkCandidates
    $powerToysExe = Find-InstalledFile $ptCandidates
}
if (-not (Test-Path -LiteralPath $terminalAlias)) { throw 'Windows Terminal is missing. Use --install-dependencies or enable its wt.exe execution alias.' }
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The Windows .NET Framework C# compiler is missing.' }
if (-not $ahkExe -or -not $powerToysExe) { throw 'AutoHotkey v2 and PowerToys are required. Use --install-dependencies to install them.' }
if ($Check) {
    Write-Output ('Validated templates and Windows prerequisites for '+$Distro+' / '+$WslUser+' / '+$WslHome)
    return
}
[IO.Directory]::CreateDirectory($assets) | Out-Null
[IO.Directory]::CreateDirectory($install) | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WslTerminalFonts {
 [DllImport("gdi32.dll",CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string path,uint flags,IntPtr reserved);
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hwnd,uint msg,UIntPtr w,IntPtr l,uint flags,uint timeout,out UIntPtr result);
}
'@
$fontTarget = Join-Path $localPath 'Microsoft\Windows\Fonts'
[IO.Directory]::CreateDirectory($fontTarget) | Out-Null
$fontSources = @()
if ($FontDirectory) {
    $fontSources = @(Get-ChildItem -LiteralPath $FontDirectory -Recurse -File -Filter 'JetBrainsMonoNLNerdFont-*.ttf')
} else {
    $fontSources = @(Get-ChildItem -LiteralPath $fontTarget -File -Filter 'JetBrainsMonoNLNerdFont-*.ttf')
}
if ($fontSources.Count -eq 0) {
    $cache = Join-Path $assets 'cache'
    [IO.Directory]::CreateDirectory($cache) | Out-Null
    $zip = Join-Path $cache 'JetBrainsMono-v3.4.0.zip'
    if (-not (Test-Path -LiteralPath $zip)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip' -OutFile $zip -UseBasicParsing
    }
    $expanded = Join-Path $cache 'JetBrainsMono'
    Expand-Archive -LiteralPath $zip -DestinationPath $expanded -Force
    $fontSources = @(Get-ChildItem -LiteralPath $expanded -Recurse -File -Filter 'JetBrainsMonoNLNerdFont-*.ttf')
}
if ($fontSources.Count -eq 0) { throw 'JetBrains Mono NL Nerd Font files were not found.' }
$fontRegistry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -Path $fontRegistry -Force | Out-Null
$installedFonts = New-Object Drawing.Text.InstalledFontCollection
$fontVisible = @($installedFonts.Families | Select-Object -ExpandProperty Name) -contains 'JetBrainsMonoNL NF'
$installedFonts.Dispose()
foreach ($font in $fontSources) {
    $target = Join-Path $fontTarget $font.Name
    if ($font.FullName -ne $target) { Copy-Item -LiteralPath $font.FullName -Destination $target -Force }
    New-ItemProperty -Path $fontRegistry -Name ('JetBrainsMonoNL NF '+$font.BaseName.Replace('JetBrainsMonoNLNerdFont-','')+' (TrueType)') -Value $target -PropertyType String -Force | Out-Null
    if (-not $fontVisible) {
        if ([WslTerminalFonts]::AddFontResourceEx($target,0,[IntPtr]::Zero) -eq 0) { throw ('Font loading failed: '+$target) }
    }
}
[UIntPtr]$fontResult = [UIntPtr]::Zero
[WslTerminalFonts]::SendMessageTimeout([IntPtr]0xffff,0x1d,[UIntPtr]::Zero,[IntPtr]::Zero,2,3000,[ref]$fontResult) | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'assets\terminal.png') -Destination $png -Force
New-TerminalIcon $png $ico

# Give each app an independent portable runtime and settings directory.
$cache = Join-Path $assets 'cache'
$runtime = Install-PortableRuntime $install $runtimeSpec $cache
$windowsInstall = Join-Path $localPath 'Programs\Windows Shell'
$windowsAssets = Join-Path $localPath 'Windows Shell'
$windowsRuntime = Install-PortableRuntime $windowsInstall $runtimeSpec $cache
[IO.Directory]::CreateDirectory($windowsAssets) | Out-Null
$windowsPng = Join-Path $windowsAssets 'Windows Shell.png'
$windowsIco = Join-Path $windowsAssets 'Windows Shell.ico'
$powerShellIcon = [Drawing.Icon]::ExtractAssociatedIcon((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'))
$powerShellBitmap = $powerShellIcon.ToBitmap()
$powerShellBitmap.Save($windowsPng,[Drawing.Imaging.ImageFormat]::Png)
$powerShellBitmap.Dispose(); $powerShellIcon.Dispose()
New-TerminalIcon $windowsPng $windowsIco
$launcherSource = Join-Path $PSScriptRoot 'launcher\Launcher.cs'
$exe = Build-ShellLauncher 'WSL Terminal' $install $assets $ico $compiler $launcherSource ''
$windowsExe = Build-ShellLauncher 'Windows Shell' $windowsInstall $windowsAssets $windowsIco $compiler $launcherSource 'WINDOWS_SHELL'

# Migrate the former shared configuration without stopping any open terminal.
$legacySettingsPath = Join-Path $localPath 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$unpackagedSettings = Join-Path $localPath 'Microsoft\Windows Terminal\settings.json'
if (-not (Test-Path $legacySettingsPath) -and (Test-Path $unpackagedSettings)) { $legacySettingsPath = $unpackagedSettings }
$legacy = if (Test-Path $legacySettingsPath) { Read-JsonFile $legacySettingsPath } else { [pscustomobject]@{} }
$seed = $legacy | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$native = Remove-LegacyWslSettings $legacy $terminalProfile $actions
Set-Field $terminalProfile commandline (New-WslCommandLine $Distro $WslUser $WslHome)
Set-Field $terminalProfile startingDirectory ('//wsl.localhost/'+$Distro+$WslHome)
Set-Field $terminalProfile icon $png
$settingsPath = Join-Path $runtime 'settings\settings.json'
$settings = if (Test-Path $settingsPath) {
    Merge-TerminalSettings (Read-JsonFile $settingsPath) $terminalProfile $scheme $actions $bindings
} else { New-PrivateSettings $seed $terminalProfile $scheme $actions $bindings $true }
Save-BackedUpFile $settingsPath ($settings | ConvertTo-Json -Depth 100) $backups

$windowsProfile = [pscustomobject]@{
    guid='{61c54bbd-c2c6-5271-96e7-009a87ff44bf}';name='Windows Shell';hidden=$false
    commandline='%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo'
    startingDirectory='%USERPROFILE%';tabTitle='Windows Shell';suppressApplicationTitle=$true
    icon=$windowsPng;font=[pscustomobject]@{face='JetBrainsMonoNL NF';size=13};colorScheme='Campbell'
}
$windowsActions = @([pscustomobject]@{id='User.WindowsNewTab';name='New Windows shell tab';command=[pscustomobject]@{action='newTab';profile=$windowsProfile.guid}})
$windowsBindings = @('ctrl+t','alt+t','ctrl+shift+t' | ForEach-Object {[pscustomobject]@{keys=$_;id='User.WindowsNewTab'}}) + @([pscustomobject]@{keys='ctrl+w';id='Terminal.ClosePane'})
$windowsSettingsPath = Join-Path $windowsRuntime 'settings\settings.json'
$windowsSettings = if (Test-Path $windowsSettingsPath) {
    Merge-TerminalSettings (Read-JsonFile $windowsSettingsPath) $windowsProfile $scheme $windowsActions $windowsBindings
} else { New-PrivateSettings $native $windowsProfile $scheme $windowsActions $windowsBindings $false }
Save-BackedUpFile $windowsSettingsPath ($windowsSettings | ConvertTo-Json -Depth 100) $backups
if (Test-Path $legacySettingsPath) { Save-BackedUpFile $legacySettingsPath ($native | ConvertTo-Json -Depth 100) $backups }

$keyboardRoot = Join-Path $localPath 'Microsoft\PowerToys\Keyboard Manager'
$keyboardSettingsPath = Join-Path $keyboardRoot 'settings.json'
$keyboardSettings = if (Test-Path -LiteralPath $keyboardSettingsPath) { Read-JsonFile $keyboardSettingsPath } else {
    [pscustomobject]@{name='Keyboard Manager';version='1';properties=[pscustomobject]@{activeConfiguration=[pscustomobject]@{value='default'};keyboardConfigurations=[pscustomobject]@{value=@('default')}}}
}
$active = $keyboardSettings.properties.activeConfiguration.value
if ($active -notmatch '^[a-zA-Z0-9 _-]+$') { throw 'Unexpected PowerToys keyboard profile name.' }
$keyboardPath = Join-Path $keyboardRoot ($active+'.json')
$oldKeyboard = if (Test-Path -LiteralPath $keyboardPath) { Read-JsonFile $keyboardPath } else { [pscustomobject]@{} }
$mergedKeyboard = Merge-PowerToysKeyboard $oldKeyboard $keyboard
Save-BackedUpFile $keyboardPath ($mergedKeyboard | ConvertTo-Json -Depth 100) $backups
Save-BackedUpFile $keyboardSettingsPath ($keyboardSettings | ConvertTo-Json -Depth 100) $backups
$generalPath = Join-Path $localPath 'Microsoft\PowerToys\settings.json'
$general = if (Test-Path -LiteralPath $generalPath) { Read-JsonFile $generalPath } else { [pscustomobject]@{} }
if (-not $general.PSObject.Properties['enabled']) { Set-Field $general enabled ([pscustomobject]@{}) }
Set-Field $general.enabled 'Keyboard Manager' $true
Save-BackedUpFile $generalPath ($general | ConvertTo-Json -Depth 100) $backups

$ahkPath = Join-Path $documentsPath 'MacDeleteToLineStart.ahk'
Save-BackedUpFile $ahkPath ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'autohotkey\MacDeleteToLineStart.ahk'))) $backups -Bom
$shell = New-Object -ComObject WScript.Shell
function Save-Shortcut([string]$Path,[string]$Target,[string]$Arguments,[string]$Icon) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $link = $shell.CreateShortcut($Path)
    $link.TargetPath = $Target
    $link.Arguments = $Arguments
    $link.WorkingDirectory = $env:WINDIR
    if ($Icon) { $link.IconLocation = $Icon }
    $link.Save()
}
$shortcutPath = Join-Path $programsPath 'WSL Terminal.lnk'
Save-Shortcut $shortcutPath $exe '' ($exe+',0')
$registration = Start-Process -FilePath $exe -ArgumentList ('--register-shortcut "'+$shortcutPath+'"') -Wait -PassThru
if ($registration.ExitCode -ne 0) { throw 'Start menu app identity registration failed.' }
$windowsShortcut = Join-Path $programsPath 'Windows Shell.lnk'
Save-Shortcut $windowsShortcut $windowsExe '' ($windowsExe+',0')
$windowsRegistration = Start-Process -FilePath $windowsExe -ArgumentList ('--register-shortcut "'+$windowsShortcut+'"') -Wait -PassThru
if ($windowsRegistration.ExitCode -ne 0) { throw 'Windows Shell app identity registration failed.' }
$windowsAppPaths = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Windows Shell.exe'
New-Item -Path $windowsAppPaths -Force | Out-Null
Set-Item -Path $windowsAppPaths -Value $windowsExe
$appPaths = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\WSL Terminal.exe'
New-Item -Path $appPaths -Force | Out-Null
Set-Item -Path $appPaths -Value $exe
Save-Shortcut (Join-Path $startupPath 'Mac keyboard shortcuts.lnk') $ahkExe ('"'+$ahkPath+'"') ''
Save-Shortcut (Join-Path $startupPath 'WSL Terminal - PowerToys.lnk') $powerToysExe '' ''
if (-not $NoStart) {
    Start-Process -FilePath $ahkExe -ArgumentList ('"'+$ahkPath+'"')
    if (-not (Get-Process PowerToys -ErrorAction SilentlyContinue)) { Start-Process -FilePath $powerToysExe }
    foreach ($app in @(
        [pscustomobject]@{launcher=$exe;backend=(Join-Path $runtime 'WindowsTerminal.exe')},
        [pscustomobject]@{launcher=$windowsExe;backend=(Join-Path $windowsRuntime 'WindowsTerminal.exe')})) {
        if (Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $app.backend}) {
            Start-Process -FilePath $app.launcher -ArgumentList '--adopt'
        }
    }
}
$manifest = [pscustomobject]@{layoutVersion=2;windowsLauncher=$windowsExe;windowsSettings=$windowsSettingsPath;legacySettings=$legacySettingsPath;distro=$Distro;wslUser=$WslUser;wslHome=$WslHome;settings=$settingsPath;launcher=$exe;ahk=$ahkPath;shortcuts=@($shortcutPath,$windowsShortcut);backups=$backups}
[IO.File]::WriteAllText((Join-Path $assets 'installation.json'),($manifest | ConvertTo-Json -Depth 10))
Write-Output ('Installed WSL Terminal for '+$Distro+' / '+$WslUser)
Write-Output ('Start menu: '+$shortcutPath+' and '+$windowsShortcut)
Write-Output ('Backups: '+$backups)
Write-Output 'Open WSL Terminal or Windows Shell from Start. Existing windows keep their running sessions.'
