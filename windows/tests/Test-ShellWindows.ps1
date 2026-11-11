[CmdletBinding()]
param([switch]$Launch)
$ErrorActionPreference='Stop'
$local=[Environment]::GetFolderPath('LocalApplicationData')
$names=@('Windows Shell','WSL Terminal')
if ($Launch) {
    foreach ($name in $names) { Start-Process (Join-Path $local ('Programs\'+$name+'\'+$name+'.exe')) }
}
$deadline=[DateTime]::Now.AddSeconds(25)
do {
    $found=@(Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -in @((Join-Path $local 'Programs\Windows Shell\runtime\WindowsTerminal.exe'),(Join-Path $local 'Programs\WSL Terminal\runtime\WindowsTerminal.exe')) -and $_.MainWindowHandle -ne 0
    })
    if ($found.Count -lt 2) { Start-Sleep -Milliseconds 500 }
} while ($found.Count -lt 2 -and [DateTime]::Now -lt $deadline)
if ($found.Count -lt 2) { throw 'Open both apps first, or run this check with -Launch.' }
# Query names/parent IDs only; do not read unrelated process command lines.
$processes=@(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name)
foreach ($name in $names) {
    $root=@($found | Where-Object {$_.Path -eq (Join-Path $local ('Programs\'+$name+'\runtime\WindowsTerminal.exe'))})[0]
    $ids=@($root.Id)
    do {
        $children=@($processes|Where-Object {$_.ParentProcessId -in $ids -and $_.ProcessId -notin $ids})
        $ids+=@($children|ForEach-Object {$_.ProcessId})
    } while ($children.Count)
    $descendants=@($processes|Where-Object {$_.ProcessId -in $ids}|ForEach-Object {$_.Name})
    $expected=if ($name -eq 'WSL Terminal') {'wsl.exe'} else {'powershell.exe'}
    if ($expected -notin $descendants) { throw ($name+' has no live '+$expected+' process; a title/icon alone does not prove a working shell.') }
    if ($name -eq 'Windows Shell' -and 'wsl.exe' -in $descendants) { throw 'Native shell app launched WSL' }
    $report=Join-Path $local ($name+'\window-verification.txt')
    $check=Start-Process (Join-Path $local ('Programs\'+$name+'\'+$name+'.exe')) -ArgumentList ('--verify "'+$report+'"') -Wait -PassThru
    if ($check.ExitCode -ne 0) { throw ('Window identity/icon check failed: '+$name) }
    Write-Output ('PASS: '+$name+' has its own runtime, live '+$expected+', app identity and window icon.')
}
