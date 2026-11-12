# Windows Shell and WSL Terminal

Two separate executables and Start-menu apps use independent portable Windows
Terminal runtimes and settings:

| App | Shell | New tabs | Icon |
| --- | --- | --- | --- |
| **Windows Shell.exe** | Windows PowerShell | Windows PowerShell | PowerShell |
| **WSL Terminal.exe** | WSL Zsh with tmux | New independent tmux sessions | macOS Terminal |

The WSL app includes the Mac-position keyboard remaps and shared prompt/editor/
file-manager setup. Its tmux bindings do not affect Windows Shell. WezTerm is
not required. Both apps can run at the same time and be pinned separately.

## Install on another Windows machine

Start with an installed Ubuntu WSL distro and a normal Linux user. Run inside
that distro (not PowerShell):

```sh
git clone https://github.com/kkomitski/dotfiles.git "$HOME/.local/share/dotfiles"
cd "$HOME/.local/share/dotfiles"
./windows/install.sh --install-dependencies
```

The installer downloads a checksum-verified Microsoft portable terminal runtime
(pinned in `terminal/runtime.json`, currently x64). The dependency option also
installs missing standard Windows Terminal, PowerToys and AutoHotkey
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
- Private WSL Terminal settings, matching WezTerm color palette, font registration,
  actions, and WSL as the default profile inside that app. Windows Shell has its
  own settings and defaults to PowerShell.
- PowerToys keyboard maps and the existing AHK navigation, deletion, screenshot,
  Chrome-tab and UK punctuation bindings. Both run at login as the current user.
- `%LOCALAPPDATA%\Programs\WSL Terminal\WSL Terminal.exe`, compiled locally from
  the included C# source, with the embedded macOS Terminal icon. A second build
  lives at `%LOCALAPPDATA%\Programs\Windows Shell\Windows Shell.exe` with the
  embedded PowerShell icon. Each app has its own `runtime\settings\settings.json`.
- Start-menu **WSL Terminal** and **Windows Shell** shortcuts, each with its own
  app identity. Pin or launch them by name. Windows search/Raycast may need a
  refresh to index new entries. The standard Store Terminal remains installed;
  migration removes the old WSL overrides from it and restores its native default.

The WSL launcher opens a new WSL tab in its own named window. Each WSL tab
creates a **new tmux session**, rather than attaching every terminal to `main`.
Closing a tab detaches its tmux client; use `tmux ls` and `tmux attach -t NAME`
to recover a session. Exit the shell or kill a session when finished with it.
Each app has a small identity helper that runs while its windows exist; these
are not services. The Windows Shell launcher opens its own named PowerShell
window. Its plus button and new-tab shortcuts stay in Windows. Cmd+T opens a
new native tab there; WSL keeps Cmd+T as the tmux prefix.

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

## VS Code shortcuts

When VS Code's Windows user directory exists, the installer merges
`vscode/keybindings.json` into its default keyboard shortcuts. Profiles that
inherit default shortcuts (including the Java profile on this machine) use these
rules. Custom shortcuts are preserved, with backups before changes. The rules
are guarded by `isWindows`, so syncing them does not change macOS/Linux behavior.

VSCodeVim remains enabled. User rules give standard editor/workbench actions
priority over Vim's Ctrl bindings: Cmd-position+W closes the editor tab, Cmd+B
toggles the sidebar, Cmd+P opens files, Cmd+Shift+P opens commands, and the usual
find/save/select/copy/cut/paste/undo/redo shortcuts work. Existing custom split
and numbered-editor shortcuts are retained. As elsewhere, the remapped Cmd key
and physical Ctrl both reach VS Code as Ctrl and cannot be distinguished there.
Changes normally reload automatically; use **Developer: Reload Window** if needed.

## Scope, backups and recovery

Actions and defaults belong to each app's private configuration. Changing WSL
Terminal no longer changes Windows Shell or the standard Store Terminal.
PowerToys/AHK remaps still apply across Windows. The dedicated AHK shell-deletion
behavior checks the WSL Terminal window title. WSL-specific shell/editor changes are guarded;
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
folders for both apps. Stop their helpers/AHK instance first. Do not uninstall
shared Windows Terminal, PowerToys, or fonts if other workflows use them. Existing terminals,
repositories and tmux sessions are not deleted by installation.

Application logs, compiler output, icon assets and the machine-specific install
manifest live under `%LOCALAPPDATA%\WSL Terminal`; Windows Shell keeps its
launcher logs/icon assets under `%LOCALAPPDATA%\Windows Shell`. No credentials
or personal app settings are exported. VS Code, Java/SDKMAN and other project-specific tools
remain separately managed; Yazi uses `code --wait` when available.

Portable runtimes do not receive Store auto-updates. To update, change the pinned
version/URL/checksum in `terminal/runtime.json`, close these app windows, and rerun
the installer. An update refuses to overwrite a runtime that is in use. Normal
repeat installation does not close any terminal or tmux session. Existing windows
from the former shared setup keep their sessions; open the two named apps for
the new separation.

Microsoft documents the settings isolation in
[Windows Terminal portable mode](https://learn.microsoft.com/en-us/windows/terminal/distributions#windows-terminal-portable).

## Verification

```sh
python3 -m unittest discover -s windows/tests -v
```

Tests use disposable PTYs and an isolated tmux server; they do not attach to your
sessions. Local Unix-socket access is required. In Windows PowerShell, run
`windows/tests/Test-Configuration.ps1` for merge/backup tests and
`windows/tests/Test-Installation.ps1` after installation for installed-state checks,
including a real WSL connection probe. `windows/tests/Test-ShellWindows.ps1`
checks live native/WSL shell processes plus window identities/icons. Open both apps
first, or pass `-Launch` to open them as part of that check.
See [AUDIT.md](AUDIT.md) for the resolved parity gaps and remaining platform limits.
