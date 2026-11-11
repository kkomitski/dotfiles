# WSL Terminal

Windows Terminal launches the Linux toolchain inside WSL, with Mac-position
keyboard remaps, the shared prompt/editor/file manager, and a separate
**WSL Terminal** application shortcut. WezTerm is not required on Windows.

## Install on another Windows machine

Start with an installed Ubuntu WSL distro and a normal Linux user. Run inside
that distro (not PowerShell):

```sh
git clone https://github.com/kkomitski/dotfiles.git "$HOME/.local/share/dotfiles"
cd "$HOME/.local/share/dotfiles"
./windows/install.sh --install-dependencies
```

The dependency option installs missing Windows Terminal, PowerToys and AutoHotkey
v2 through winget. It installs the WSL shell/tmux prerequisites through apt,
then current Zsh/tmux, ripgrep, the command-line tools and Zsh integrations
through Linuxbrew as needed.
Ubuntu package installation may require sudo. Windows app installation follows
winget's normal permissions and corporate policies. Internet access is required
for missing dependencies, Nerd Fonts, and Neovim's first plugin installation.

On an existing configured machine, omit `--install-dependencies`. Use
`./windows/install.sh --check` to validate templates and Windows prerequisites
without changing files; it does not run the interactive integration tests.
Rerunning the installer updates this setup without duplicating managed bindings
or replacing unrelated profiles/remaps. Close and reopen terminal tabs afterward;
restart PowerToys if its active mappings have not reloaded.

The installer discovers the Windows user folders, including redirected Documents,
and captures the current WSL distro, user and home. No machine username or home
path is stored in the repository. A preinstalled JetBrains Mono NL Nerd Font is
reused; otherwise Nerd Fonts v3.4.0 is downloaded. For offline font provisioning,
pass `-FontDirectory` to `Install.ps1` with a directory containing its TTF files.

## What gets installed

- WSL links for the shared Zsh, tmux, Starship, Neovim and Yazi configuration,
  plus the WSL editing module, environment setup and clipboard helpers.
- Windows Terminal profile, matching WezTerm color palette, font registration,
  actions, and WSL as the default profile for new tabs.
- PowerToys keyboard maps and the existing AHK navigation, deletion, screenshot,
  Chrome-tab and UK punctuation bindings. Both run at login as the current user.
- `%LOCALAPPDATA%\Programs\WSL Terminal\WSL Terminal.exe`, compiled locally from
  the included C# source, with the embedded macOS Terminal icon.
- Start-menu **WSL Terminal** shortcut with its own app identity. Pin this entry
  to Start/taskbar or launch it by name; the standard Windows Terminal remains
  installed. Windows search/Raycast may need a refresh to index the new entry.

The launcher opens a new WSL tab in its named Windows Terminal window. Each tab
creates a **new tmux session**, rather than attaching every terminal to `main`.
Closing a tab detaches its tmux client; use `tmux ls` and `tmux attach -t NAME`
to recover a session. Exit the shell or kill a session when finished with it.
The small identity helper runs while its windows exist; it is not a service.

## Keyboard behavior

Here **Cmd** means physical left Alt; **Option** means physical left Win.
PowerToys translates these to Ctrl and Alt respectively. Physical Ctrl remains
Ctrl, so applications cannot distinguish it from the Cmd-position key.

| Keys | Action |
| --- | --- |
| Cmd+T, then H / V | tmux split top/bottom / side by side |
| Cmd+B | Yazi; Neovim retains its own explorer action |
| Cmd+1 … Cmd+5 | Select tmux pane |
| Option+T or Cmd+Shift+T | New WSL tab and independent tmux session |
| Cmd+W | Close Terminal pane/tab |
| Cmd+arrows | Line/document boundaries |
| Option+Left/Right | Word movement |
| Add Shift to movement | Extend/shrink selection in Zsh and supported editor modes |
| Cmd+A / C / X | Select all / copy selection / cut selection in Zsh and Neovim |
| Cmd+V | Windows clipboard paste |
| Cmd+Backspace / Option+Backspace | Delete to line start / previous word |
| Cmd+Shift+5 | Windows screenshot toolbar |

Without a selection, Ctrl/Cmd+C still cancels shell input or interrupts a running
program. Zsh selections use the Windows clipboard helpers, including Unicode and
multiline text. Ctrl+S cannot pause Zsh output. Neovim uses the same helpers for
its clipboard; Ctrl+Q enters visual block mode because Terminal owns Ctrl+V.

Terminal's palette/find shortcuts are Ctrl+Alt+Shift+P/F (logical modifiers), so
Ctrl+Shift+P/F can reach editor shortcuts. Other applications, Yazi and fzf retain
their own selection/editing conventions. This does not turn every TUI into a
macOS text field. Secure/UAC screens and apps running as another user may retain
Windows' original keyboard behavior.

## Scope, backups and recovery

Windows Terminal actions/default profile are application-wide; PowerToys/AHK
remaps apply across Windows. The dedicated AHK shell-deletion behavior checks
the WSL Terminal window title. WSL-specific shell/editor changes are guarded;
shared `.wezterm.lua` is unchanged, and native Linux/macOS keep existing behavior.
The current Windows Terminal appearance is retained, including platform tab UI,
padding and rendering differences from WezTerm.

Changed Windows configuration/AHK files are backed up under
`%LOCALAPPDATA%\WSL Terminal\backups`. WSL files replaced by links and the previous
`.zshenv` are backed up under `~/.local/state/wsl-terminal/backups`. The installer
preserves unrelated JSON fields/profiles/remaps, but normalizes JSON formatting;
original comments are retained in the backup rather than the rewritten settings.
Existing AHK script contents are backed up before installing the packaged script;
merge any additional personal AHK changes into the repository before reinstalling.

To undo, restore the relevant backed-up settings/files, remove these WSL links,
and remove the WSL Terminal Start/startup shortcuts and its local Programs/assets
folders. Stop its helper/AHK instance first. Do not uninstall shared Windows
Terminal, PowerToys, or fonts if other workflows use them. Existing terminals,
repositories and tmux sessions are not deleted by installation.

Application logs, compiler output, icon assets and the machine-specific install
manifest live under `%LOCALAPPDATA%\WSL Terminal`. No credentials or personal
app settings are exported. VS Code, Java/SDKMAN and other project-specific tools
remain separately managed; Yazi uses `code --wait` when available.

## Verification

```sh
python3 -m unittest discover -s windows/tests -v
```

Tests use disposable PTYs and an isolated tmux server; they do not attach to your
sessions. Local Unix-socket access is required. In Windows PowerShell, run
`windows/tests/Test-Configuration.ps1` for merge/backup tests and
`windows/tests/Test-Installation.ps1` after installation for installed-state checks.
See [AUDIT.md](AUDIT.md) for the resolved parity gaps and remaining platform limits.
