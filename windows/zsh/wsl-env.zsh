# Loaded from the user's .zshenv only on WSL. No machine-specific home paths.
[[ -n ${WSL_DISTRO_NAME:-} ]] || return 0
export PATH="$HOME/.local/bin:$PATH"
if [[ -d /home/linuxbrew/.linuxbrew/bin ]]; then
  export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
fi
if [[ -d "$HOME/.local/opt/zsh-root" ]]; then
  module_path=("$HOME/.local/opt/zsh-root"/usr/lib/*/zsh/*(N/) $module_path)
  fpath=("$HOME/.local/opt/zsh-root"/usr/share/zsh/functions/**/*(N/) $fpath)
fi
if [[ -d "$HOME/.local/opt/zsh-autosuggestions" ]] && ! (( $+commands[brew] )); then
  HOMEBREW_PREFIX="$HOME/.local"
fi
if [[ -x "$HOME/.local/bin/zsh" ]]; then
  export SHELL="$HOME/.local/bin/zsh"
elif [[ -x /usr/bin/zsh ]]; then
  export SHELL=/usr/bin/zsh
fi
