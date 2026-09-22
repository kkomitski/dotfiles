# Homebrew is the source for Starship and the Zsh integrations below.
if (( $+commands[brew] )); then
  HOMEBREW_PREFIX="$(brew --prefix)"
  fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fi

# Environment and tool paths.
export GO_HOME="/usr/local/go"
export POPCORN_HOME="/usr/local/popcorn"
export ASPROF_HOME="/usr/local/asprof"
export PYTHON_USER_BIN="$HOME/Library/Python/3.9/bin"

export PATH="$HOME/.jenv/bin:$PATH"
if (( $+commands[jenv] )); then
  eval "$(jenv init -)"
fi
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
  export NVM_DIR="$HOME/.nvm"
  source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
fi
export PATH="$PATH:$GO_HOME/bin:$POPCORN_HOME/bin:$ASPROF_HOME/bin:$PYTHON_USER_BIN"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

export WINEPREFIX="$HOME/Games/gw2-prefix"
export WINEARCH=win64

export PNPM_HOME="$HOME/Library/pnpm"
typeset -U path PATH
path=("$PNPM_HOME/bin" "$HOME/Code/butler" $path)

export OLLAMA_API_KEY=ollama-local

# Persistent, shared history with substring search and fuzzy Ctrl-R search.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt append_history
setopt inc_append_history
setopt share_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_all_dups
setopt hist_reduce_blanks

bindkey -e

if [[ -o interactive ]]; then
# Native completion, extra completion definitions, and fuzzy completion UI.
autoload -Uz compinit
compinit

if [[ -n "$HOMEBREW_PREFIX" ]]; then
  [[ -r "$HOMEBREW_PREFIX/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] &&
    source "$HOMEBREW_PREFIX/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -r "$HOMEBREW_PREFIX/opt/zsh-history-substring-search/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] &&
    source "$HOMEBREW_PREFIX/opt/zsh-history-substring-search/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
  [[ -r "$HOMEBREW_PREFIX/opt/zsh-autopair/share/zsh-autopair/autopair.zsh" ]] &&
    source "$HOMEBREW_PREFIX/opt/zsh-autopair/share/zsh-autopair/autopair.zsh"

  if [[ -r "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
    source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
    source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
  fi

  [[ -r "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh" ]] &&
    source "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Up opens the fuzzy history search; down keeps prefix/substr history navigation.
bindkey '^[[A' fzf-history-widget
bindkey '^[OA' fzf-history-widget
bindkey '^[[B' history-substring-search-down
bindkey '^[OB' history-substring-search-down
bindkey -r '^R'

ZSH_AUTOSUGGEST_STRATEGY=(history)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# fzf-tab defaults: reverse list, grouped completion sources, and directory previews.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*'
zstyle ':fzf-tab:*' fzf-flags --height=50% --layout=reverse --border=rounded
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=2 --color=always --icons=auto $realpath 2>/dev/null'

# Prompt and syntax highlighting. Syntax highlighting must remain last.
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
if [[ -n "$HOMEBREW_PREFIX" ]] && [[ -r "$HOMEBREW_PREFIX/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
fi

# Return to the directory selected in Yazi when it exits.
yazi() {
  local cwd_file cwd status
  cwd_file="$(mktemp -t yazi-cwd.XXXXXX)" || return
  command yazi "$@" --cwd-file="$cwd_file"
  status=$?
  if [[ -s "$cwd_file" ]]; then
    IFS= read -r cwd < "$cwd_file"
    [[ -d "$cwd" ]] && builtin cd -- "$cwd"
  fi
  rm -f -- "$cwd_file"
  return "$status"
}

# Shift+F opens the same fuzzy directory picker from an interactive shell.
fuzzy-directory-widget() {
  local selected
  selected="$(fd --type d --hidden --exclude .git . | fzf --height=80% --layout=reverse --border=rounded --prompt='Directory> ')" || return
  [[ -n "$selected" ]] && builtin cd -- "$selected"
  zle reset-prompt
}
zle -N fuzzy-directory-widget
bindkey -M emacs 'F' fuzzy-directory-widget
bindkey -M viins 'F' fuzzy-directory-widget

echo_path() {
  echo "$PATH" | tr ':' '\n'
}

# Personal aliases.
alias get-movie="$HOME/scripts/get-movie.sh"
alias get-series="$HOME/scripts/get-series.sh"
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias deploy-run='mvn package -DskipTests && rsync -avz target/*.jar kkomitski@192.168.1.169:/home/kkomitski/Code/java/opal/ && ssh kkomitski@192.168.1.169 "cd /home/kkomitski/Code/java/opal && java -jar *.jar"'

# Small, commonly used command-line conveniences.
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto'
alias la='eza -la --group-directories-first --icons=auto'
alias tree='eza --tree --icons=auto'
alias cat='bat --paging=never'
alias g='git'

# Bun and OpenClaw completions.
[[ -r "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
[[ -r "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

rehash

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section

