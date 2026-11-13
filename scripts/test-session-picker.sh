#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
picker=$repo/packages/tmux/.config/tmux/session-picker.sh
server=session-picker-test-$$
XDG_STATE_HOME=$(mktemp -d "${TMPDIR:-/tmp}/tmux-session-picker-test.XXXXXX")
export XDG_STATE_HOME
unset TMUX
alpha=$(tmux -L "$server" -f /dev/null new-session -d -P -F '#{session_id}' -s alpha 'sleep 300')
cleanup() {
  tmux -L "$server" kill-server
  rm -f "$XDG_STATE_HOME/tmux/session-picker-order"
  if [ -d "$XDG_STATE_HOME/tmux" ]; then rmdir "$XDG_STATE_HOME/tmux"; fi
  rmdir "$XDG_STATE_HOME"
}
trap cleanup EXIT
TMUX=$(tmux -L "$server" display-message -p '#{socket_path},#{pid},0')
export TMUX
beta=$(tmux new-session -d -P -F '#{session_id}' -s beta 'sleep 300')
gamma=$(tmux new-session -d -P -F '#{session_id}' -s gamma 'sleep 300')
SESSION_PICKER_CURRENT=$beta
export SESSION_PICKER_CURRENT

assert_order() {
  actual=$(sh "$picker" list | cut -f 1 | paste -sd ' ' -)
  if [ "$actual" != "$1" ]; then
    printf 'Expected order %s, got %s\n' "$1" "$actual" >&2
    exit 1
  fi
}

assert_order "$alpha $beta $gamma"
sh "$picker" list | grep -F '* beta' >/dev/null
sh "$picker" move up "$beta" >/dev/null
assert_order "$beta $alpha $gamma"
sh "$picker" move up "$beta" >/dev/null
assert_order "$beta $alpha $gamma"
sh "$picker" move down "$beta" >/dev/null
assert_order "$alpha $beta $gamma"
sh "$picker" move down "$gamma" >/dev/null
assert_order "$alpha $beta $gamma"

sh "$picker" move up "$beta" >/dev/null
sh "$picker" rename "$beta" "beta's work"
assert_order "$beta $alpha $gamma"
sh "$picker" list | grep -F "* beta's work" >/dev/null
# Window counts share one column, so every display row has the same width.
widths=$(sh "$picker" list | cut -f 2 | awk '{ print length($0) }' | sort -u | wc -l)
[ "$widths" -eq 1 ] || { echo "Display rows are not aligned" >&2; exit 1; }
if sh "$picker" list | grep -F attached >/dev/null; then
  echo "Rows should not label attached sessions" >&2
  exit 1
fi
sh "$picker" new delta
delta=$(tmux display-message -p -t '=delta:' '#{session_id}')
assert_order "$beta $alpha $gamma $delta"
if sh "$picker" preview "$beta" | grep -E 'Active pane|panes\)' >/dev/null; then
  echo "Preview should show only the pane screen" >&2
  exit 1
fi

# x asks before killing a session; any answer but y cancels, and the current
# session is protected.
SESSION_PICKER_RUN=$(mktemp -d "${TMPDIR:-/tmp}/tmux-session-picker-run.XXXXXX")
export SESSION_PICKER_RUN
FZF_INPUT_STATE=hidden sh "$picker" key x "$beta" | grep -F "can't kill the current session" >/dev/null
FZF_INPUT_STATE=hidden sh "$picker" key x "$delta" | grep -F 'change-prompt:kill › delta ' >/dev/null
FZF_PROMPT='kill › delta ' FZF_QUERY=n sh "$picker" key change >/dev/null
assert_order "$beta $alpha $gamma $delta"
FZF_PROMPT='kill › delta ' FZF_QUERY=y sh "$picker" key change | grep -F reload >/dev/null
assert_order "$beta $alpha $gamma"
FZF_PROMPT='new › ' FZF_QUERY=delta sh "$picker" key enter | grep -F 'pos(4)' >/dev/null
delta=$(tmux display-message -p -t '=delta:' '#{session_id}')
FZF_PROMPT='new › ' FZF_QUERY=delta sh "$picker" key enter | grep -F 'duplicate session' >/dev/null

# h/l pick which window the preview shows, wrapping around; in prompts the
# arrow keys move the cursor instead.
tmux new-window -d -t "$delta:" -n second 'printf SECOND_WINDOW; sleep 300'
attempt=0
while ! tmux capture-pane -p -t "$delta:second" | grep -F 'SECOND_WINDOW' >/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 50 ] || { printf 'Window fixture timed out\n' >&2; exit 1; }
  sleep 0.1
done
shows_second() { sh "$picker" preview "$1" | grep -F 'SECOND_WINDOW' >/dev/null; }
if shows_second "$delta"; then echo "Unexpected window in $delta preview" >&2; exit 1; fi
FZF_INPUT_STATE=hidden sh "$picker" key next "$delta" | grep -Fx refresh-preview >/dev/null
shows_second "$delta"
FZF_INPUT_STATE=hidden sh "$picker" key next "$delta" >/dev/null
if shows_second "$delta"; then echo "Unexpected window in $delta preview" >&2; exit 1; fi
FZF_INPUT_STATE=hidden sh "$picker" key prev "$delta" >/dev/null
shows_second "$delta"
if shows_second "$beta"; then echo "Unexpected window in $beta preview" >&2; exit 1; fi
FZF_PROMPT=/ sh "$picker" key prev "$delta" | grep -Fx backward-char >/dev/null
tmux kill-window -t "$delta:second"
rm -rf "$SESSION_PICKER_RUN"
unset SESSION_PICKER_RUN
assert_order "$beta $alpha $gamma $delta"

# Closed sessions must not leave holes or block future moves.
tmux kill-session -t "$alpha"
assert_order "$beta $gamma $delta"
sh "$picker" move down "$beta" >/dev/null
assert_order "$gamma $beta $delta"

sh "$picker" save
tmux set-option -gu @session-picker-order
assert_order "$gamma $beta $delta"
tmux kill-server
unset TMUX
delta=$(tmux -L "$server" -f /dev/null new-session -d -P -F '#{session_id}' -s delta 'sleep 300')
TMUX=$(tmux -L "$server" display-message -p '#{socket_path},#{pid},0')
export TMUX
gamma=$(tmux new-session -d -P -F '#{session_id}' -s gamma 'sleep 300')
beta=$(tmux new-session -d -P -F '#{session_id}' -s "beta's work" 'sleep 300')
assert_order "$gamma $beta $delta"

# A preview is the visible screen, not scrollback before it or the saved main screen.
screen=$(tmux new-session -d -P -F '#{session_id}' -s screen \
  'i=0; while [ "$i" -lt 40 ]; do printf "OLD_SCROLLBACK\n"; i=$((i + 1)); done; printf "\033[2J\033[H\033[31mCURRENT_SCREEN\033[0m"; sleep 300')
attempt=0
while ! tmux capture-pane -p -t "$screen:" | grep -F 'CURRENT_SCREEN' >/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 50 ] || { printf 'Screen fixture timed out\n' >&2; exit 1; }
  sleep 0.1
done
preview=$(sh "$picker" preview "$screen")
printf '%s\n' "$preview" | grep -F 'CURRENT_SCREEN' >/dev/null
if printf '%s\n' "$preview" | grep -F 'OLD_SCROLLBACK' >/dev/null; then
  printf 'Preview included old scrollback\n' >&2
  exit 1
fi
printf '%s\n' "$preview" | grep -F "$(printf '\033[31m')" >/dev/null
tmux copy-mode -t "$screen:"
tmux send-keys -X -t "$screen:" history-top
sh "$picker" preview "$screen" | grep -F 'OLD_SCROLLBACK' >/dev/null

alternate=$(tmux new-session -d -P -F '#{session_id}' -s alternate \
  'printf "SAVED_MAIN_SCREEN\033[?1049h\033[2J\033[HALTERNATE_SCREEN"; sleep 300')
attempt=0
while ! tmux capture-pane -p -t "$alternate:" | grep -F 'ALTERNATE_SCREEN' >/dev/null; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 50 ] || { printf 'Alternate screen fixture timed out\n' >&2; exit 1; }
  sleep 0.1
done
preview=$(sh "$picker" preview "$alternate")
printf '%s\n' "$preview" | grep -F 'ALTERNATE_SCREEN' >/dev/null
if printf '%s\n' "$preview" | grep -F 'SAVED_MAIN_SCREEN' >/dev/null; then
  printf 'Preview showed the saved main screen instead of the full-screen app\n' >&2
  exit 1
fi

printf '%s\n' 'Session picker integration checks passed.'
