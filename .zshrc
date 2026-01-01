
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export GO_HOME="/usr/local/go"
export POPCORN_HOME="/usr/local/popcorn"
export JAVA_HOME="/usr/local/java/Contents/Home"
export PYTHON_USER_BIN="$HOME/Library/Python/3.9/bin"

export PATH="$PATH:$GO_HOME/bin:$POPCORN_HOME/bin:$JAVA_HOME/bin:$PYTHON_USER_BIN"

path_cleanup() {
  export PATH="$(echo "$PATH" | tr ':' '\n' | awk '!seen[$0]++' | paste -sd: -)"
  echo "PATH cleaned up.."
}
path_cleanup

if [[ $- == *i* ]] && [[ -z "$ZELLIJ" ]] && command -v zellij >/dev/null; then
  exec zellij
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git web-search zsh-autosuggestions zsh-syntax-highlighting zsh-nvm fzf-zsh-plugin docker docker-compose)

source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

echo_path () {
  echo "$PATH" | tr ':' '\n'
}

# Aliases
alias get-movie="$HOME/scripts/get-movie.sh"
alias get-series="$HOME/scripts/get-series.sh"
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'