#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    printf 'Installing Homebrew...\n'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew installation failed.\n' >&2
  exit 1
fi

formulas=(
  bun nvm starship neovim yazi tmux zoxide fzf fzf-tab eza bat
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
casks=(aerospace wezterm font-jetbrains-mono-nerd-font)
for cask in "${casks[@]}"; do
  brew list --cask "$cask" >/dev/null 2>&1 || brew install --cask "$cask"
done
export NVM_DIR="$HOME/.nvm"
source "$(brew --prefix nvm)/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'
if ! command -v omp >/dev/null 2>&1; then
  bun add --global @oh-my-pi/pi-coding-agent
fi

if command -v code >/dev/null 2>&1 || [[ -d "/Applications/Visual Studio Code.app" ]]; then
  printf 'VS Code is available.\n'
else
  brew list --cask visual-studio-code >/dev/null 2>&1 || brew install --cask visual-studio-code
fi

if command -v code >/dev/null 2>&1 && [[ -f "$repo_root/vscode/extensions.txt" ]]; then
  while IFS= read -r extension; do
    if [[ -n "$extension" ]] && ! code --install-extension "$extension" --force >/dev/null; then
      printf 'Warning: could not install VS Code extension %s\n' "$extension" >&2
    fi
  done < "$repo_root/vscode/extensions.txt"
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

link_config() {
  local source="$1"
  local destination="$2"

  [[ "$source" == "$destination" ]] && return
  if [[ -e "$destination" || -L "$destination" ]]; then
    local backup="${destination}.backup.$(date +%Y%m%d%H%M%S)"
    mv "$destination" "$backup"
    printf 'Moved existing %s to %s\n' "$destination" "$backup"
  fi
  mkdir -p "$(dirname "$destination")"
  ln -s "$source" "$destination"
}

link_config "$repo_root/.zshrc" "$HOME/.zshrc"
link_config "$repo_root/.tmux.conf" "$HOME/.tmux.conf"
link_config "$repo_root/.wezterm.lua" "$HOME/.wezterm.lua"
link_config "$repo_root/.config/starship.toml" "$HOME/.config/starship.toml"
link_config "$repo_root/.config/nvim" "$HOME/.config/nvim"
link_config "$repo_root/.config/yazi" "$HOME/.config/yazi"
link_config "$repo_root/.aerospace.toml" "$HOME/.aerospace.toml"

printf 'Dependencies installed and dotfiles linked from %s.\n' "$repo_root"
