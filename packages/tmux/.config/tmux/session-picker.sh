#!/bin/sh
set -eu

state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/tmux
order_file=$state_dir/session-picker-order
tab=$(printf '\t')

# Sessions in picker order as: id<TAB>name<TAB>window count.
ordered_sessions() {
  order=$(tmux show-options -gqv @session-picker-order)
  sessions=$(tmux list-sessions -F "#{session_id}$tab#{session_name}$tab#{session_windows}")
  if [ -z "$order" ] && [ -f "$order_file" ]; then
    order=$(printf '%s\n' "$sessions" | awk -F '\t' '
      FILENAME != "-" { saved[++count] = $0; next }
      { ids[$2] = $1 }
      END {
        for (i = 1; i <= count; i++)
          if (saved[i] in ids) printf "%s ", ids[saved[i]]
      }' "$order_file" -)
  fi
  printf '%s\n' "$sessions" | awk -F '\t' -v order="$order" '
    BEGIN { count = split(order, saved, " ") }
    { rows[$1] = $0; ids[++total] = $1 }
    END {
      for (i = 1; i <= count; i++) {
        if (saved[i] in rows) {
          print rows[saved[i]]
          delete rows[saved[i]]
        }
      }
      for (i = 1; i <= total; i++)
        if (ids[i] in rows) print rows[ids[i]]
    }'
}

# Rows as id<TAB>display, with names padded so window counts form one column.
list_sessions() {
  ordered_sessions | awk -F '\t' -v current="${SESSION_PICKER_CURRENT:-}" \
    -v width="${SESSION_PICKER_NAME_WIDTH:-0}" '
    { ids[NR] = $1; names[NR] = $2; windows[NR] = $3
      if (width == 0 && length($2) > longest) longest = length($2) }
    END {
      if (width == 0) width = longest
      for (i = 1; i <= NR; i++) {
        name = names[i]
        if (length(name) > width) name = substr(name, 1, width - 2) ".."
        count = sprintf("%2d %s", windows[i], windows[i] == 1 ? "window" : "windows")
        printf "%s\t%s %-" width "s  %-10s\n", ids[i], (ids[i] == current ? "*" : " "), name, count
      }
    }'
}

save_order() {
  umask 077
  mkdir -p "$state_dir"
  temporary=$(mktemp "$state_dir/session-picker-order.XXXXXX")
  trap 'rm -f "$temporary"' EXIT
  trap 'exit 1' HUP INT TERM
  ordered_sessions | cut -f 2 > "$temporary"
  mv -f "$temporary" "$order_file"
}

preview_session() {
  tmux list-windows -t "$1" -F '#{?window_active,>, } #I: #W (#{window_panes} panes)'
  printf '\n--- Active pane (current screen) ---\n'
  viewport=$(tmux display-message -p -t "$1:" '#{?scroll_position,#{scroll_position},0} #{pane_height}')
  start=$((0 - ${viewport% *}))
  height=${viewport#* }
  tmux capture-pane -e -p -S "$start" -E "$((start + height - 1))" -t "$1:"
}

# Record what the preview shows so the watcher refreshes only after changes.
show_preview() {
  screen=$(preview_session "$1")
  printf '%s\n' "$screen"
  if [ -n "${SESSION_PICKER_RUN:-}" ]; then
    printf '%s\n%s\n' "$1" "$(printf '%s' "$screen" | cksum)" > "$SESSION_PICKER_RUN/shown.tmp"
    mv -f "$SESSION_PICKER_RUN/shown.tmp" "$SESSION_PICKER_RUN/shown"
  fi
}

watch_preview() {
  parent=$1
  while kill -0 "$parent" 2>/dev/null; do
    sleep 1
    [ -S "$SESSION_PICKER_RUN/fzf.sock" ] && [ -f "$SESSION_PICKER_RUN/shown" ] || continue
    { IFS= read -r shown_id && IFS= read -r shown_sum; } < "$SESSION_PICKER_RUN/shown" || continue
    screen=$(preview_session "$shown_id" 2>/dev/null) || continue
    current_sum=$(printf '%s' "$screen" | cksum)
    if [ "$current_sum" != "$shown_sum" ]; then
      curl -s --max-time 2 --unix-socket "$SESSION_PICKER_RUN/fzf.sock" \
        -X POST http://localhost -d refresh-preview || :
    fi
  done
}

move_session() {
  direction=$1
  selected=$2
  case "$direction" in
    up) step=-1 ;;
    down) step=1 ;;
    *) printf 'Unknown direction: %s\n' "$direction" >&2; exit 1 ;;
  esac
  order=$(ordered_sessions | awk -F '\t' -v selected="$selected" -v step="$step" '
    { ids[NR] = $1; if ($1 == selected) position = NR }
    END {
      neighbor = position + step
      if (position && neighbor >= 1 && neighbor <= NR) {
        ids[position] = ids[neighbor]
        ids[neighbor] = selected
      }
      for (i = 1; i <= NR; i++) printf "%s%s", (i == 1 ? "" : " "), ids[i]
      print ""
    }')
  tmux set-option -g @session-picker-order "$order"
  list_sessions
}

new_session() { tmux new-session -d -P -F '#{session_id}' -s "$1"; }
rename_session() { tmux rename-session -t "$1" "$2"; }
kill_session() { tmux kill-session -t "$1"; }

# Emits fzf actions for keys whose meaning depends on the picker's mode. Mode is
# derived from the input line: hidden is normal mode, and the prompt names the
# prompt-driven modes (new, rename, kill confirmation, or a notice).
key_action() {
  key=$1
  selected=${2:-}
  keys='j,k,g,G,q,/,x,r,n'
  normal="change-prompt(/)+hide-input+enable-search+clear-query+search()+rebind($keys)"
  input="show-input+disable-search+unbind($keys)+change-query()"
  # fzf ignores query edits made from change events, so after a confirmation
  # the typed key stays in the hidden query; search stays off until / clears it.
  dismiss="change-prompt(/)+hide-input+disable-search+rebind($keys)"
  reload='reload-sync(sh "$TMUX_SESSION_PICKER_SCRIPT" list)'
  target_file=$SESSION_PICKER_RUN/target
  query=${FZF_QUERY:-}
  if [ "${FZF_INPUT_STATE:-}" = hidden ]; then
    mode=normal
  else
    case "${FZF_PROMPT:-/}" in
      /) mode=search ;;
      'new › ') mode=new ;;
      'rename › ') mode=rename ;;
      'kill '*) mode=kill ;;
      *) mode=notice ;;
    esac
  fi
  notice() { printf '%s\n' "$input+change-prompt:$1 "; }
  target=
  [ ! -f "$target_file" ] || target=$(cat "$target_file")

  # Clearing the query also fires a change event; only typed input counts.
  if [ "$key" = change ] && [ -z "$query" ]; then return 0; fi

  case "$key:$mode" in
    esc:normal) echo abort ;;
    backspace:normal) ;;
    esc:*|backspace:*|enter:kill|enter:notice) echo "$normal" ;;
    change:notice) echo "$dismiss" ;;
    enter:normal|enter:search) echo accept-non-empty ;;
    enter:new|enter:rename)
      [ -n "$query" ] || { echo "$normal"; return; }
      if [ "$mode" = new ]; then
        error=$(new_session "$query" 2>&1) && target=$error
      else
        error=$(rename_session "$target" "$query" 2>&1)
      fi || { notice "$error"; return; }
      position=$(list_sessions | awk -F '\t' -v id="$target" '$1 == id { print NR; exit }')
      echo "$normal+$reload+wait+pos(${position:-1})" ;;
    change:kill)
      case "$query" in
        y|Y)
          error=$(kill_session "$target" 2>&1) || { notice "$error"; return; }
          echo "$dismiss+$reload" ;;
        *) echo "$dismiss" ;;
      esac ;;
    x:normal|x:search)
      [ -n "$selected" ] || return 0
      if [ "$selected" = "${SESSION_PICKER_CURRENT:-}" ]; then
        notice "can't kill the current session"
        return
      fi
      printf '%s' "$selected" > "$target_file"
      echo "$input+change-prompt:kill › $(tmux display-message -p -t "$selected" '#{session_name}') " ;;
    ctrl-r:normal|ctrl-r:search)
      [ -n "$selected" ] || return 0
      printf '%s' "$selected" > "$target_file"
      echo "$input+change-prompt(rename › )+change-query:$(tmux display-message -p -t "$selected" '#{session_name}')" ;;
    ctrl-n:normal|ctrl-n:search) echo "$input+change-prompt(new › )" ;;
  esac
}

case "${1:-pick}" in
  popup)
    tmux display-popup -E -c "$2" -w 85% -h 80% -d "$4" \
      -s 'bg=#0d1117,fg=#e6edf3' -S 'fg=#6e7681' \
      -e "SESSION_PICKER_CLIENT=$2" -e "SESSION_PICKER_CURRENT=$3" \
      'sh "$HOME/.config/tmux/session-picker.sh"'
    exit ;;
  list) list_sessions; exit ;;
  save) save_order; exit ;;
  move) move_session "$2" "$3"; exit ;;
  preview) show_preview "$2"; exit ;;
  new) new_session "$2" >/dev/null; exit ;;
  rename) rename_session "$2" "$3"; exit ;;
  kill) kill_session "$2"; exit ;;
  key) key_action "$2" "${3:-}"; exit ;;
  pick) ;;
  *) printf 'Unknown action: %s\n' "$1" >&2; exit 1 ;;
esac

if ! command -v fzf >/dev/null 2>&1; then
  printf 'Session picker requires fzf. Install it with your package manager.\n' >&2
  exit 1
fi

TMUX_SESSION_PICKER_SCRIPT=$0
SESSION_PICKER_RUN=$(mktemp -d "${TMPDIR:-/tmp}/tmux-session-picker.XXXXXX")
export TMUX_SESSION_PICKER_SCRIPT SESSION_PICKER_RUN
watcher=
cleanup() {
  if [ -n "$watcher" ]; then kill "$watcher" 2>/dev/null || :; fi
  rm -rf "$SESSION_PICKER_RUN"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Ignore global fzf options so sorting and key bindings stay predictable.
FZF_DEFAULT_OPTS=
FZF_DEFAULT_OPTS_FILE=/dev/null
export FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE

# Size the list to its content so window counts sit beside the preview border.
columns=$(stty size < /dev/tty 2>/dev/null | cut -d ' ' -f 2) || columns=
case "$columns" in ''|*[!0-9]*) columns=120 ;; esac
longest=$(ordered_sessions | awk -F '\t' 'length($2) > n { n = length($2) } END { print n + 0 }')
limit=$((columns * 45 / 100 - 18))
[ "$limit" -ge 8 ] || limit=8
SESSION_PICKER_NAME_WIDTH=$longest
[ "$SESSION_PICKER_NAME_WIDTH" -le "$limit" ] || SESSION_PICKER_NAME_WIDTH=$limit
[ "$SESSION_PICKER_NAME_WIDTH" -ge 8 ] || SESSION_PICKER_NAME_WIDTH=8
export SESSION_PICKER_NAME_WIDTH
# Row: marker and spaces (3), name, gap (2), count (10); fzf adds a 2-column
# pointer, and the preview size excludes its 2-column border.
preview_columns=$((columns - SESSION_PICKER_NAME_WIDTH - 19))
side="right:$preview_columns:border-left:nowrap:follow:noinfo"
stacked='up:85%:border-bottom:nowrap:follow:noinfo'

if command -v curl >/dev/null 2>&1; then
  watch_preview "$$" >/dev/null 2>&1 &
  watcher=$!
fi

normal_keys='j,k,g,G,q,/,x,r,n'
rows=$(list_sessions)
position=$(printf '%s\n' "$rows" | awk -F '\t' -v current="${SESSION_PICKER_CURRENT:-}" '
  $1 == current { print NR; found = 1; exit }
  END { if (!found) print 1 }')
if selection=$(printf '%s\n' "$rows" | fzf \
  --no-sort --track --layout=reverse-list --info=inline-right --no-input \
  --delimiter="$tab" --with-nth=2 --id-nth=1 --no-scrollbar \
  --prompt='/' --listen="$SESSION_PICKER_RUN/fzf.sock" \
  --color='bg:#0d1117,fg:#6e7681,bg+:#21262d,fg+:#e6edf3,hl:#e6edf3,hl+:#e6edf3,info:#6e7681,pointer:#e6edf3,gutter:#0d1117,border:#6e7681,prompt:#e6edf3,preview-bg:#0d1117,preview-fg:#e6edf3' \
  --preview='sh "$TMUX_SESSION_PICKER_SCRIPT" preview {1}' \
  --preview-window="$side" \
  --bind="load:pos($position)+unbind(load)" \
  --bind='j:down,k:up,g:first,G:last,q:abort' \
  --bind="/:show-input+enable-search+clear-query+unbind($normal_keys)" \
  --bind='esc:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key esc' \
  --bind='backward-eof:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key backspace' \
  --bind='enter:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key enter {1}' \
  --bind='change:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key change' \
  --bind='x,ctrl-x:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key x {1}' \
  --bind='r,ctrl-r:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key ctrl-r {1}' \
  --bind='n,ctrl-n:transform:sh "$TMUX_SESSION_PICKER_SCRIPT" key ctrl-n' \
  --bind='alt-up:reload(sh "$TMUX_SESSION_PICKER_SCRIPT" move up {1})' \
  --bind='alt-down:reload(sh "$TMUX_SESSION_PICKER_SCRIPT" move down {1})' \
  --bind='shift-up:preview-up,shift-down:preview-down' \
  --bind="ctrl-f:change-preview-window($stacked|$side)"); then
  selected=${selection%%"$tab"*}
  tmux switch-client -c "$SESSION_PICKER_CLIENT" -t "$selected"
else
  status=$?
  case "$status" in
    1|130) exit 0 ;;
    *) printf 'Session picker failed (fzf exit %s).\n' "$status" >&2; exit "$status" ;;
  esac
fi
