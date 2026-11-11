Set-StrictMode -Version 2

# Terminal accepts JSON with comments and trailing commas. Remove syntax sugar
# outside strings before using Windows PowerShell 5's JSON parser.
if (-not ('WslTerminalJson' -as [type])) {
    Add-Type @'
using System.Text;
public static class WslTerminalJson {
 public static string Clean(string input) {
  var b=new StringBuilder(); bool text=false,escape=false,line=false,block=false;
  for(int i=0;i<input.Length;i++) {
   char c=input[i],n=i+1<input.Length?input[i+1]:'\0';
   if(line){if(c=='\n'){line=false;b.Append(c);}else b.Append(' ');continue;}
   if(block){if(c=='*'&&n=='/'){block=false;b.Append("  ");i++;}else b.Append(c=='\n'?'\n':' ');continue;}
   if(text){b.Append(c);if(escape)escape=false;else if(c=='\\')escape=true;else if(c=='"')text=false;continue;}
   if(c=='"'){text=true;b.Append(c);continue;}
   if(c=='/'&&n=='/'){line=true;b.Append("  ");i++;continue;}
   if(c=='/'&&n=='*'){block=true;b.Append("  ");i++;continue;}
   b.Append(c);
  }
  string s=b.ToString();b.Clear();text=false;escape=false;
  for(int i=0;i<s.Length;i++) {
   char c=s[i];
   if(text){b.Append(c);if(escape)escape=false;else if(c=='\\')escape=true;else if(c=='"')text=false;continue;}
   if(c=='"')text=true;
   if(c==','){int j=i+1;while(j<s.Length&&char.IsWhiteSpace(s[j]))j++;if(j<s.Length&&(s[j]=='}'||s[j]==']'))continue;}
   b.Append(c);
  }
  return b.ToString();
 }
}
'@
}

function Read-JsonFile([string]$Path) {
    $parsed = [WslTerminalJson]::Clean([IO.File]::ReadAllText($Path)) | ConvertFrom-Json
    foreach ($item in $parsed) { Write-Output $item }
}
function Set-Field($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}
function Merge-KeyedItems($Existing, $Desired, [string]$Key) {
    $result = @($Existing | Where-Object { $null -ne $_ })
    foreach ($item in @($Desired)) {
        $value = $item.$Key
        $result = @($result | Where-Object { (-not $_.PSObject.Properties[$Key]) -or $_.$Key -ne $value }) + @($item)
    }
    $result
}
function Merge-TerminalSettings($Settings, $TerminalProfile, $Scheme, $Actions, $Bindings) {
    if (-not $Settings.PSObject.Properties['profiles']) { Set-Field $Settings profiles ([pscustomobject]@{list=@()}) }
    if (-not $Settings.profiles.PSObject.Properties['list']) { Set-Field $Settings.profiles list @() }
    $current = @($Settings.profiles.list | Where-Object {$_.guid -eq $TerminalProfile.guid})
    if ($current.Count -eq 0) {
        $Settings.profiles.list = @($Settings.profiles.list) + @($TerminalProfile)
    } else {
        foreach ($property in $TerminalProfile.PSObject.Properties) { Set-Field $current[0] $property.Name $property.Value }
    }
    Set-Field $Settings defaultProfile $TerminalProfile.guid
    $oldSchemes = if ($Settings.PSObject.Properties['schemes']) { @($Settings.schemes) } else { @() }
    Set-Field $Settings schemes @(Merge-KeyedItems $oldSchemes @($Scheme) name)
    $oldActions = if ($Settings.PSObject.Properties['actions']) { @($Settings.actions) } else { @() }
    Set-Field $Settings actions @(Merge-KeyedItems $oldActions $Actions id)
    $wanted = @($Bindings | ForEach-Object {$_.keys} | ForEach-Object {$_.ToLowerInvariant()})
    $retained = @()
    if ($Settings.PSObject.Properties['keybindings']) {
        foreach ($binding in @($Settings.keybindings)) {
            $keys = @($binding.keys | Where-Object {$_.ToLowerInvariant() -notin $wanted})
            if ($keys.Count) {
                $binding.keys = if ($keys.Count -eq 1) { $keys[0] } else { $keys }
                $retained += $binding
            }
        }
    }
    Set-Field $Settings keybindings @($retained + @($Bindings))
    return $Settings
}
function Merge-PowerToysKeyboard($Existing, $Desired) {
    foreach ($group in $Desired.PSObject.Properties) {
        if (-not $Existing.PSObject.Properties[$group.Name]) { Set-Field $Existing $group.Name ([pscustomobject]@{}) }
        foreach ($scope in $group.Value.PSObject.Properties) {
            if (@($scope.Value).Count -eq 0) { continue }
            $old = @()
            if ($Existing.($group.Name).PSObject.Properties[$scope.Name]) { $old = @($Existing.($group.Name).($scope.Name)) }
            Set-Field $Existing.($group.Name) $scope.Name @(Merge-KeyedItems $old $scope.Value originalKeys)
        }
    }
    return $Existing
}
function Save-BackedUpFile([string]$Path, [string]$Content, [string]$BackupDirectory, [switch]$Bom) {
    if ((Test-Path -LiteralPath $Path) -and [IO.File]::ReadAllText($Path) -eq $Content) { return }
    if (Test-Path -LiteralPath $Path) {
        [IO.Directory]::CreateDirectory($BackupDirectory) | Out-Null
        Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupDirectory ([IO.Path]::GetFileName($Path) + '.' + [Guid]::NewGuid().ToString('N') + '.bak'))
    }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding ([bool]$Bom)))
}

# Undo only the previous installer's WSL entries in the Store Terminal settings.
function Remove-LegacyWslSettings($Settings,$TerminalProfile,$Actions) {
    $managedIds = @($Actions | ForEach-Object {$_.id})
    if ($Settings.PSObject.Properties['profiles'] -and $Settings.profiles.PSObject.Properties['list']) {
        $Settings.profiles.list = @($Settings.profiles.list | Where-Object {$_.guid -ne $TerminalProfile.guid})
    }
    if ($Settings.PSObject.Properties['defaultProfile'] -and $Settings.defaultProfile -eq $TerminalProfile.guid) {
        $Settings.defaultProfile = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'
    }
    if ($Settings.PSObject.Properties['actions']) {
        $Settings.actions = @($Settings.actions | Where-Object {(-not $_.PSObject.Properties['id']) -or $_.id -notin $managedIds})
    }
    if ($Settings.PSObject.Properties['keybindings']) {
        $kept = @()
        foreach ($binding in @($Settings.keybindings)) {
            if ($binding.PSObject.Properties['id'] -and $binding.id -in $managedIds) { continue }
            $keys = @($binding.keys | Where-Object {
                -not (($binding.PSObject.Properties['id'] -and $null -eq $binding.id -and $_ -in @('ctrl+shift+p','ctrl+shift+f')) -or
                    ($binding.PSObject.Properties['id'] -and $binding.id -eq 'Terminal.ClosePane' -and $_ -eq 'ctrl+w'))
            })
            if ($keys.Count) { $binding.keys = if ($keys.Count -eq 1) {$keys[0]} else {$keys}; $kept += $binding }
        }
        $Settings.keybindings = @($kept)
    }
    return $Settings
}

function Get-WslConnectionArguments([string]$Distro,[string]$WslUser) {
    # This WSL build treats unnecessary quotes around simple distro/user names
    # literally. Keep those tokens plain; quote only a name containing whitespace.
    $distroToken = if ($Distro -match '\s') {'"'+$Distro+'"'} else {$Distro}
    $userToken = if ($WslUser -match '\s') {'"'+$WslUser+'"'} else {$WslUser}
    return ('-d '+$distroToken+' -u '+$userToken)
}
function New-WslCommandLine([string]$Distro,[string]$WslUser,[string]$WslHome) {
    return ((Join-Path $env:WINDIR 'System32\wsl.exe')+' '+(Get-WslConnectionArguments $Distro $WslUser)+' --cd ~ -- "'+$WslHome+'/.local/bin/WSL Terminal"')
}
