#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew is required. Install it from https://brew.sh, then rerun this script.\n' >&2
  exit 1
fi

formulas=(
  starship neovim yazi tmux zoxide fzf fzf-tab eza bat
  zsh-autosuggestions zsh-history-substring-search zsh-autopair
  zsh-syntax-highlighting
)

missing=()
for formula in "${formulas[@]}"; do
  brew list --formula "$formula" >/dev/null 2>&1 || missing+=("$formula")
done

if ((${#missing[@]})); then
  brew install "${missing[@]}"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  casks=(wezterm visual-studio-code font-jetbrains-mono-nerd-font)
  for cask in "${casks[@]}"; do
    brew list --cask "$cask" >/dev/null 2>&1 || brew install --cask "$cask"
  done
fi

# Install the tmux plugins referenced by .tmux.conf without requiring TPM at runtime.
tmux_plugins="${TMUX_PLUGIN_MANAGER_PATH:-$HOME/.tmux/plugins}"
mkdir -p "$tmux_plugins"
for plugin in tmux-resurrect tmux-continuum; do
  target="$tmux_plugins/$plugin"
  if [[ ! -d "$target/.git" ]]; then
    git clone --depth 1 "https://github.com/tmux-plugins/$plugin.git" "$target"
  fi
done

printf 'Dependencies and tmux plugins are ready.\n'
