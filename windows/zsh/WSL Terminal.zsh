# WSL Terminal command-line editing for the Windows Mac-position remaps.
unsetopt FLOW_CONTROL
bindkey '^S' redisplay
# PowerToys sends Home/End for Cmd+arrows and Ctrl+arrows for Option+arrows.
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' emacs-forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' emacs-forward-word
bindkey '^[b' backward-word
bindkey '^[f' emacs-forward-word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
# AHK sends Ctrl+U/Meta+Backspace for Cmd/Option+Backspace in this tab.
bindkey '^U' backward-kill-line
bindkey '^W' backward-kill-word
bindkey '^[^?' backward-kill-word
bindkey '^H' backward-kill-word

# Keep the selection anchor while Shift extends or shrinks the region.
_wsl_select() {
  (( REGION_ACTIVE )) || MARK=$CURSOR
  zle ".$1"
  REGION_ACTIVE=1
}
_wsl_select_home() { _wsl_select beginning-of-line }
_wsl_select_end() { _wsl_select end-of-line }
_wsl_select_word_left() { _wsl_select backward-word }
_wsl_select_word_right() { _wsl_select emacs-forward-word }
_wsl_select_left() { _wsl_select backward-char }
_wsl_select_right() { _wsl_select forward-char }
_wsl_select_buffer_home() { (( REGION_ACTIVE )) || MARK=$CURSOR; CURSOR=0; REGION_ACTIVE=1 }
_wsl_select_buffer_end() { (( REGION_ACTIVE )) || MARK=$CURSOR; CURSOR=${#BUFFER}; REGION_ACTIVE=1 }
_wsl_select_up() { _wsl_select up-line }
_wsl_select_down() { _wsl_select down-line }
for widget in home end word_left word_right left right buffer_home buffer_end up down; do
  zle -N "_wsl_select_$widget"
done
unset widget

bindkey '^[[1;2H' _wsl_select_home
bindkey '^[[1;2F' _wsl_select_end
bindkey '^[[1;6H' _wsl_select_buffer_home
bindkey '^[[1;6F' _wsl_select_buffer_end
bindkey '^[[1;6D' _wsl_select_word_left
bindkey '^[[1;6C' _wsl_select_word_right
bindkey '^[[1;4D' _wsl_select_word_left
bindkey '^[[1;4C' _wsl_select_word_right
bindkey '^[[1;2D' _wsl_select_left
bindkey '^[[1;2C' _wsl_select_right
bindkey '^[[1;2A' _wsl_select_up
bindkey '^[[1;2B' _wsl_select_down
zle_highlight=(${zle_highlight:#region:*} 'region:standout')

# Normal movement ends selection. Editing replaces or deletes selected text.
_wsl_move() {
  REGION_ACTIVE=0
  zle ".$1"
}
_wsl_move_home() { _wsl_move beginning-of-line }
_wsl_move_end() { _wsl_move end-of-line }
_wsl_move_word_left() { _wsl_move backward-word }
_wsl_move_word_right() { _wsl_move emacs-forward-word }
_wsl_move_buffer_home() { REGION_ACTIVE=0; CURSOR=0 }
_wsl_move_buffer_end() { REGION_ACTIVE=0; CURSOR=${#BUFFER} }
_wsl_move_left() {
  if (( REGION_ACTIVE && MARK != CURSOR )); then
    (( CURSOR = MARK < CURSOR ? MARK : CURSOR ))
    REGION_ACTIVE=0
  else
    _wsl_move backward-char
  fi
}
_wsl_move_right() {
  if (( REGION_ACTIVE && MARK != CURSOR )); then
    (( CURSOR = MARK > CURSOR ? MARK : CURSOR ))
    REGION_ACTIVE=0
  else
    _wsl_move forward-char
  fi
}
for widget in home end word_left word_right left right buffer_home buffer_end; do
  zle -N "_wsl_move_$widget"
done
unset widget
bindkey '^[[D' _wsl_move_left
bindkey '^[OD' _wsl_move_left
bindkey '^[[C' _wsl_move_right
bindkey '^[OC' _wsl_move_right
bindkey '^[[1;5H' _wsl_move_buffer_home
bindkey '^[[1;5F' _wsl_move_buffer_end
bindkey '^[[H' _wsl_move_home
bindkey '^[OH' _wsl_move_home
bindkey '^[[1~' _wsl_move_home
bindkey '^[[F' _wsl_move_end
bindkey '^[OF' _wsl_move_end
bindkey '^[[4~' _wsl_move_end
bindkey '^[[1;5D' _wsl_move_word_left
bindkey '^[[1;3D' _wsl_move_word_left
bindkey '^[b' _wsl_move_word_left
bindkey '^[[1;5C' _wsl_move_word_right
bindkey '^[[1;3C' _wsl_move_word_right
bindkey '^[f' _wsl_move_word_right

_wsl_edit() {
  if (( REGION_ACTIVE && MARK != CURSOR )); then
    zle .kill-region
    REGION_ACTIVE=0
    if [[ $1 == self-insert ]]; then zle .self-insert; fi
  else
    REGION_ACTIVE=0
    zle ".$1"
  fi
}
_wsl_insert() { _wsl_edit self-insert }
_wsl_backspace() { _wsl_edit backward-delete-char }
_wsl_delete() { _wsl_edit delete-char }
_wsl_delete_line() { _wsl_edit backward-kill-line }
_wsl_delete_word() { _wsl_edit backward-kill-word }
zle -N self-insert _wsl_insert
zle -N _wsl_backspace
zle -N _wsl_delete
zle -N _wsl_delete_line
zle -N _wsl_delete_word
bindkey '^?' _wsl_backspace
bindkey '^[[3~' _wsl_delete
bindkey '^U' _wsl_delete_line
bindkey '^W' _wsl_delete_word
bindkey '^[^?' _wsl_delete_word
bindkey '^H' _wsl_delete_word

_wsl_copy_region() {
  local first=$(( MARK < CURSOR ? MARK : CURSOR ))
  local last=$(( MARK > CURSOR ? MARK : CURSOR ))
  print -rn -- "${BUFFER[$((first+1)),$last]}" | command pbcopy
}
_wsl_copy() {
  if (( REGION_ACTIVE && MARK != CURSOR )); then
    _wsl_copy_region || { zle -M 'Windows clipboard copy failed'; return 1; }
    REGION_ACTIVE=1
  else
    zle .send-break
  fi
}
_wsl_cut() {
  if (( REGION_ACTIVE && MARK != CURSOR )); then
    _wsl_copy_region || { zle -M 'Windows clipboard copy failed'; return 1; }
    zle .kill-region
    REGION_ACTIVE=0
  fi
  return 0
}
_wsl_select_all() { MARK=0; CURSOR=${#BUFFER}; REGION_ACTIVE=1 }
zle -N _wsl_copy
zle -N _wsl_cut
zle -N _wsl_select_all
bindkey -rp '^X'
bindkey '^C' _wsl_copy
bindkey '^X' _wsl_cut
bindkey '^A' _wsl_select_all

# Let ZLE handle Ctrl+C while editing a selection. Restore the tty before an
# external command runs, so Ctrl+C continues to interrupt running programs.
_wsl_line_init() {
  _wsl_saved_tty=$(stty -g < /dev/tty 2>/dev/null) || return 0
  stty -ixon -ixoff intr undef < /dev/tty
}
_wsl_line_finish() {
  if [[ -n ${_wsl_saved_tty:-} ]]; then
    stty "$_wsl_saved_tty" < /dev/tty
    unset _wsl_saved_tty
  fi
}
autoload -Uz add-zle-hook-widget
add-zle-hook-widget -d line-init _wsl_line_init 2>/dev/null
add-zle-hook-widget -d line-finish _wsl_line_finish 2>/dev/null
add-zle-hook-widget line-init _wsl_line_init
add-zle-hook-widget line-finish _wsl_line_finish
