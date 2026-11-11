$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Configuration.ps1')
$local = [Environment]::GetFolderPath('LocalApplicationData')
$manifest = Read-JsonFile (Join-Path $local 'WSL Terminal\installation.json')
$probeOut=Join-Path $local 'WSL Terminal\wsl-probe.out'
$probeErr=Join-Path $local 'WSL Terminal\wsl-probe.err'
$probeArgs=(Get-WslConnectionArguments $manifest.distro $manifest.wslUser)+' --exec /usr/bin/true'
$probe=Start-Process (Join-Path $env:WINDIR 'System32\wsl.exe') -ArgumentList $probeArgs -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $probeOut -RedirectStandardError $probeErr
if ($probe.ExitCode -ne 0) { throw 'WSL distribution/user launch probe failed' }
$settings = Read-JsonFile $manifest.settings
$guid = '{954a9562-64a0-44fa-9044-f18c1ad1725c}'
if ($settings.defaultProfile -ne $guid) { throw 'Private WSL app default is not WSL' }
$native = Read-JsonFile $manifest.windowsSettings
if ($native.defaultProfile -eq $guid) { throw 'Windows Shell defaults to WSL' }
if (@($native.actions | Where-Object {$_.id -like 'User.Tmux*' -or $_.id -eq 'User.OpenYazi'}).Count) { throw 'Windows Shell inherited tmux actions' }
if (@($native.profiles.list | Where-Object {$_.guid -eq $guid}).Count) { throw 'Windows Shell contains the WSL profile' }
if ($manifest.settings -eq $manifest.windowsSettings) { throw 'Apps share one settings file' }
foreach ($path in @($manifest.settings,$manifest.windowsSettings)) {
    $runtime = Split-Path (Split-Path $path -Parent) -Parent
    if (-not (Test-Path (Join-Path $runtime '.portable'))) { throw 'Portable marker missing' }
    if (-not (Test-Path (Join-Path $runtime 'WindowsTerminal.exe'))) { throw 'Private runtime missing' }
}
$legacy=Read-JsonFile $manifest.legacySettings
if ($legacy.defaultProfile -eq $guid) { throw 'Store Terminal still defaults to WSL' }
$profiles = @($settings.profiles.list | Where-Object {$_.guid -eq $guid})
if ($profiles.Count -ne 1) { throw 'Expected exactly one WSL profile' }
if ($profiles[0].font.face -ne 'JetBrainsMonoNL NF') { throw 'Nerd Font is not configured' }
$wanted = @(Read-JsonFile (Join-Path $PSScriptRoot '..\terminal\keybindings.json'))
foreach ($binding in $wanted) {
    $actual = @($settings.keybindings | Where-Object {$_.keys -eq $binding.keys})
    if ($actual.Count -ne 1 -or $actual[0].id -ne $binding.id) { throw ('Incorrect or duplicated shortcut: '+$binding.keys) }
}
$self = Start-Process -FilePath $manifest.launcher -ArgumentList '--self-check' -Wait -PassThru
if ($self.ExitCode -ne 0) { throw 'Launcher embedded icon check failed' }
$nativeCheck = Start-Process -FilePath $manifest.windowsLauncher -ArgumentList '--self-check' -Wait -PassThru
if ($nativeCheck.ExitCode -ne 0) { throw 'Windows Shell icon check failed' }
$nativeApps = @(Get-StartApps | Where-Object {$_.Name -eq 'Windows Shell' -and $_.AppID -eq 'Local.WindowsShell'})
if ($nativeApps.Count -ne 1) { throw 'Separate Windows Shell Start identity is missing' }
$apps = @(Get-StartApps | Where-Object {$_.Name -eq 'WSL Terminal' -and $_.AppID -eq 'Local.WSLTerminal'})
if ($apps.Count -ne 1) { throw 'Separate Start menu app identity is missing' }
$ahk = @(Get-CimInstance Win32_Process -Filter "name='AutoHotkey64.exe'" | Where-Object {$_.CommandLine -like '*MacDeleteToLineStart.ahk*'})
if ($ahk.Count -ne 1) { throw 'Expected one running keyboard remap script' }
Write-Output 'PASS: independent native/WSL runtimes and settings, defaults, unique shortcuts, font, both embedded icons, two Start menu identities, and active AHK script.'
