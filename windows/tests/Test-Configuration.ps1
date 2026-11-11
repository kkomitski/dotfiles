$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\Configuration.ps1')
$root = Join-Path $PSScriptRoot '..'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('wsl-terminal-test-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporary) | Out-Null
try {
    $fixture = Join-Path $temporary 'settings.json'
    [IO.File]::WriteAllText($fixture, @'
{
 // comment outside a string
 "path":"https://example.invalid/a//b",
 "defaultProfile":"other",
 "profiles":{"list":[{"guid":"other","name":"Keep me"}]},
 "schemes":[{"name":"Other"}],
 "actions":[{"id":"Other.Action","command":"paste"}],
 "keybindings":[{"id":"Other.Action","keys":["ctrl+t","ctrl+alt+9"]}],
}
'@)
    $command = New-WslCommandLine 'Ubuntu' 'linux-user' '/home/linux-user'
    if ($command -notlike '*-d Ubuntu -u linux-user --cd ~ -- "/home/linux-user/.local/bin/WSL Terminal"') { throw 'WSL distro/user argument quoting regressed' }
    $settings = Read-JsonFile $fixture
    $terminalProfile = Read-JsonFile (Join-Path $root 'terminal\profile.json')
    $scheme = Read-JsonFile (Join-Path $root 'terminal\scheme.json')
    $actions = @(Read-JsonFile (Join-Path $root 'terminal\actions.json'))
    $bindings = @(Read-JsonFile (Join-Path $root 'terminal\keybindings.json'))
    $first = Merge-TerminalSettings $settings $terminalProfile $scheme $actions $bindings
    $json = $first | ConvertTo-Json -Depth 100
    $second = Merge-TerminalSettings ($json|ConvertFrom-Json) $terminalProfile $scheme $actions $bindings
    if (($second|ConvertTo-Json -Depth 100) -ne $json) { throw 'Terminal merge is not idempotent' }
    if ($second.path -ne 'https://example.invalid/a//b') { throw 'Comment stripping changed a string' }
    if (-not ($second.profiles.list|Where-Object {$_.guid -eq 'other'})) { throw 'Unrelated profile was removed' }
    if (-not ($second.keybindings|Where-Object {$_.keys -eq 'ctrl+alt+9'})) { throw 'Unrelated shortcut alias was removed' }
    if (@($second.keybindings|Where-Object {$_.keys -eq 'ctrl+t'}).Count -ne 1) { throw 'Duplicate managed keybinding' }
    if ($second.defaultProfile -ne $terminalProfile.guid) { throw 'New tabs do not default to WSL' }
    $migrated = Remove-LegacyWslSettings ($json|ConvertFrom-Json) $terminalProfile $actions
    if ($migrated.defaultProfile -eq $terminalProfile.guid) { throw 'Legacy Terminal still defaults to WSL' }
    if (@($migrated.profiles.list|Where-Object {$_.guid -eq $terminalProfile.guid}).Count) { throw 'Legacy WSL profile was not migrated' }
    if (-not ($migrated.profiles.list|Where-Object {$_.guid -eq 'other'})) { throw 'Migration removed unrelated profile' }
    if (-not ($migrated.keybindings|Where-Object {$_.keys -eq 'ctrl+alt+9'})) { throw 'Migration removed unrelated shortcut' }
    if (@($migrated.actions|Where-Object {$_.id -eq 'User.TmuxPrefix'}).Count) { throw 'WSL actions remain in native app' }
    $once=$migrated|ConvertTo-Json -Depth 100
    if (((Remove-LegacyWslSettings ($once|ConvertFrom-Json) $terminalProfile $actions)|ConvertTo-Json -Depth 100) -ne $once) { throw 'Legacy migration is not idempotent' }
    $keyboard = Read-JsonFile (Join-Path $root 'powertoys\keyboard.json')
    $old = '{"remapKeys":{"inProcess":[{"originalKeys":"999","newRemapKeys":"998"}]}}'|ConvertFrom-Json
    $merged = Merge-PowerToysKeyboard $old $keyboard
    if (-not ($merged.remapKeys.inProcess|Where-Object {$_.originalKeys -eq '999'})) { throw 'Unrelated PowerToys remap was lost' }
    $before=$merged|ConvertTo-Json -Depth 100
    if (((Merge-PowerToysKeyboard ($before|ConvertFrom-Json) $keyboard)|ConvertTo-Json -Depth 100) -ne $before) { throw 'PowerToys merge is not idempotent' }
    $backup = Join-Path $temporary 'backups'
    Save-BackedUpFile $fixture $json $backup
    $count = @(Get-ChildItem $backup -File).Count
    Save-BackedUpFile $fixture $json $backup
    if (@(Get-ChildItem $backup -File).Count -ne $count) { throw 'Unchanged settings created unnecessary backups' }
    Write-Output 'PASS: JSONC parsing, unrelated-profile preservation, shortcut alias preservation, WSL default, idempotent Terminal/PowerToys merges, backup behavior, and legacy-app migration.'
} finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
