# Windows Terminal parity audit

The functional gaps found against the shared macOS WezTerm setup are resolved
and packaged. The existing Windows Terminal appearance is retained as requested.
Native Linux/macOS use their existing bindings; `.wezterm.lua` is unchanged.

## Resolved gaps

| Finding | Result |
| --- | --- |
| Ctrl+S could freeze shell output | WSL Zsh disables software flow control; PTY test verifies continued output. This was reproduced, but does not establish the cause of every earlier WezTerm hang. |
| Shell apps were sharing defaults and bindings | Windows Shell and WSL Terminal have separate executables, portable runtimes, settings, defaults, app identities and icons. Native tabs remain PowerShell; WSL tabs remain WSL/tmux. The old Store Terminal overrides are migrated out. |
| Every terminal attached to `main` | Launcher creates independent tmux sessions. Two real PTY clients against an isolated server verify session and pane independence. |
| Cmd+W conflicted with Option+Backspace | Terminal closes its pane/tab; AHK sends Meta+Backspace for word deletion instead of Ctrl+W. |
| Zsh selection lacked clipboard integration | Cmd+A/C/X select/copy/cut ZLE regions. Unicode/multiline clipboard round trip verified against Windows. |
| Ctrl+C needed to retain interrupt behavior | ZLE temporarily owns Ctrl+C while editing; tty interrupt is restored for running commands. Both paths pass PTY tests. |
| Pane selection shortcuts missing | Cmd+1 through Cmd+5 send the existing tmux pane bindings. |
| Host palette/find intercepted editor chords | Host shortcuts moved to logical Ctrl+Alt+Shift+P/F; Ctrl+Shift+P/F are unbound at the host. |
| Selection deletion returned failure | Successful deletion now returns success; widget status is tested. |
| Multiline boundary navigation incomplete | Separate line/document boundary widgets and Shift-selection are included. |
| Neovim clipboard/modifier differences | WSL-only clipboard provider, editing aliases, Shift-selection, and Ctrl+Q block-selection alternative. Configuration/mappings load in headless Neovim. |
| Machine paths and missing install steps | Installer discovers Windows folders and current WSL identity, links shell setup, installs optional dependencies, registers fonts, compiles launcher and creates login/Start links. |
| Windows metadata/truecolor omitted from tmux | Update environment includes Windows Terminal/WSL markers; Windows Terminal enables xterm truecolor features. |

## Validation performed

- 18 automated PTY/tmux tests passed, covering selection, replacement, paste,
  Unicode copy/cut, deletion status, Ctrl+C, Ctrl+S, independent sessions and panes.
- Native PowerShell configuration tests passed: JSONC parsing, unrelated profile
  and shortcut-alias preservation, repeat merges, PowerToys remap preservation,
  and backup behavior.
- The installer completed twice on this configured machine. Installed-state checks
  passed for independent profiles/settings, unique shortcuts, fonts, both embedded
  icons, both Start-menu identities and the running AHK instance. Both private
  terminal processes/windows were opened together; distinct paths, window AppIDs
  and nonzero window icons were verified. Live PowerShell/WSL child processes and
  a connected tmux client were verified after correcting distro/user quoting.
- Native PowerShell syntax checks and headless Neovim WSL configuration checks
  passed. Windows clipboard Unicode/multiline round trip passed while restoring
  the previous text clipboard.
- Existing font/palette matching and launcher running-window identity were checked
  during the earlier setup. No user tmux sessions were used by the automated tests.

A completely empty replacement laptop and interactive key behavior in every
Neovim/Yazi/fzf mode have not been tested. The optional dependency-bootstrap path
is provided, but the repeat-install checks reused this machine's installed apps
and tools. Windows search/Raycast indexing and corporate installation policies
remain machine-dependent.

## Intentional differences and limits

- Windows Terminal keeps its current padding, line height, mouse-copy preferences,
  bell, selection rendering and tab chrome. Font/emoji rendering follows Windows;
  it is not a pixel-identical macOS emulator. Font size and core palette match.
- PowerToys maps physical Cmd-position and physical Ctrl to the same logical Ctrl;
  app bindings cannot distinguish them. Host Ctrl+V paste owns that chord.
- Zsh editing parity does not replace application-specific controls in every TUI.
  Neovim's provided aliases are WSL-only; Yazi and fzf retain their own conventions.
- Each named app has its own bindings/default profile and runtime. PowerToys/AHK
  remaps still apply across Windows. AHK shell-deletion transport is
  restricted to the dedicated WSL Terminal window title.
- Backups precede configuration/AHK replacement. JSON merges preserve unrelated
  settings but normalize formatting; original comments remain in backups.

See [README.md](README.md) for installation, shortcuts, scope and recovery.
