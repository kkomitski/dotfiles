$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Configuration.ps1')
$local = [Environment]::GetFolderPath('LocalApplicationData')
$manifest = Read-JsonFile (Join-Path $local 'WSL Terminal\installation.json')
$settings = Read-JsonFile $manifest.settings
$guid = '{954a9562-64a0-44fa-9044-f18c1ad1725c}'
if ($settings.defaultProfile -ne $guid) { throw 'Default profile is not WSL' }
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
$apps = @(Get-StartApps | Where-Object {$_.Name -eq 'WSL Terminal' -and $_.AppID -eq 'Local.WSLTerminal'})
if ($apps.Count -ne 1) { throw 'Separate Start menu app identity is missing' }
$ahk = @(Get-CimInstance Win32_Process -Filter "name='AutoHotkey64.exe'" | Where-Object {$_.CommandLine -like '*MacDeleteToLineStart.ahk*'})
if ($ahk.Count -ne 1) { throw 'Expected one running keyboard remap script' }
Write-Output 'PASS: WSL default profile, unique shortcut bindings, Nerd Font configuration, launcher embedded icon, separate Start menu app identity, and active AHK script.'
