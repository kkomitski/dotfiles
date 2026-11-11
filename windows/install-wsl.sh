#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
[[ -n ${WSL_DISTRO_NAME:-} ]] || { printf 'This installer is WSL-only.\n' >&2; exit 1; }
if [[ ${1:-} == --install-dependencies ]]; then
  if ! command -v tmux >/dev/null || ! command -v zsh >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y zsh tmux git curl unzip build-essential procps file
  fi
  missing=()
  for tool in starship nvim yazi zoxide fzf fd eza bat rg bun node; do
    command -v "$tool" >/dev/null || missing+=("$tool")
  done
  plugin_root="$HOME/.local"
  if command -v brew >/dev/null; then plugin_root="$(brew --prefix)"; fi
  for plugin in zsh-autosuggestions zsh-history-substring-search zsh-autopair zsh-syntax-highlighting fzf-tab; do
    [[ -d "$plugin_root/opt/$plugin" ]] || missing+=("$plugin")
  done
  if ((${#missing[@]})); then
    if ! command -v brew >/dev/null; then
      if [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    brew install zsh tmux starship neovim yazi zoxide fzf fd eza bat ripgrep oven-sh/bun/bun nvm \
      zsh-autosuggestions zsh-history-substring-search zsh-autopair zsh-syntax-highlighting fzf-tab
    export NVM_DIR="$HOME/.nvm"
    mkdir -p "$NVM_DIR"
    source "$(brew --prefix nvm)/nvm.sh"
    nvm install --lts
    nvm alias default 'lts/*'
  fi
  if command -v bun >/dev/null && ! command -v omp >/dev/null; then
    bun add --global @oh-my-pi/pi-coding-agent
  fi
  mkdir -p "$HOME/.tmux/plugins"
  for plugin in tmux-resurrect tmux-continuum; do
    [[ -d "$HOME/.tmux/plugins/$plugin" ]] || git clone --depth 1 "https://github.com/tmux-plugins/$plugin.git" "$HOME/.tmux/plugins/$plugin"
  done
fi
for tool in tmux zsh; do
  command -v "$tool" >/dev/null || { printf 'Missing %s. Run windows/install.sh --install-dependencies.\n' "$tool" >&2; exit 1; }
done
backup_dir="$HOME/.local/state/wsl-terminal/backups/$(date +%Y%m%d-%H%M%S)-$$"
link_file() {
  local source="$1" destination="$2"
  if [[ -L "$destination" && $(readlink -f "$destination") == "$source" ]]; then return; fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    mkdir -p "$backup_dir"
    mv -- "$destination" "$backup_dir/$(printf '%s' "$destination" | tr / _)"
  fi
  mkdir -p "$(dirname "$destination")"
  ln -s "$source" "$destination"
}
for file in .zshrc .tmux.conf; do link_file "$repo_root/$file" "$HOME/$file"; done
for file in starship.toml nvim yazi; do link_file "$repo_root/.config/$file" "$HOME/.config/$file"; done
link_file "$script_dir/zsh/WSL Terminal.zsh" "$HOME/.config/zsh/WSL Terminal.zsh"
link_file "$script_dir/zsh/wsl-env.zsh" "$HOME/.config/zsh/wsl-env.zsh"
for file in 'WSL Terminal' pbcopy pbpaste; do
  link_file "$script_dir/bin/$file" "$HOME/.local/bin/$file"
done
env_line='[[ -n ${WSL_DISTRO_NAME:-} && -r "$HOME/.config/zsh/wsl-env.zsh" ]] && source "$HOME/.config/zsh/wsl-env.zsh"'
if ! grep -Fqx "$env_line" "$HOME/.zshenv" 2>/dev/null; then
  if [[ -f "$HOME/.zshenv" ]]; then
    mkdir -p "$backup_dir"
    cp -p "$HOME/.zshenv" "$backup_dir/zshenv"
  fi
  printf '\n%s\n' "$env_line" >> "$HOME/.zshenv"
fi
printf 'WSL dotfiles linked. Every new Terminal tab starts an independent tmux session.\n'
