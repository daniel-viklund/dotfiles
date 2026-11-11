`mkdir -p ~/.config && cd ~/.config && git clone https://github.com/daniel-viklund/tmux.git && git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm`

`C-a + I` to install plugins

## Session picker

Press `Ctrl-a`, then `s`. Requires a recent `fzf` with `--id-nth` support
(the current Homebrew version, included in the Brewfile, supports it).

| Key | Action |
|---|---|
| j / k, Up / Down | Select a session |
| g / G | Jump to the first / last session |
| / | Start fuzzy-searching sessions |
| Enter | Switch to the selected session |
| Option/Alt + Up / Down | Move the selected session up / down |
| n / Ctrl-N | Create a detached session, then select it in the picker |
| r / Ctrl-R | Rename the selected session |
| x / Ctrl-X | Kill the selected session; press `y` to confirm, any other key cancels |
| Ctrl-F | Toggle an expanded, full-width preview |
| Shift + Up / Down | Scroll the preview |
| Esc | Cancel search or a prompt; close when not searching |
| Backspace (empty input) | Cancel search or a prompt |
| q | Close without switching (when not searching) |

The picker opens in normal mode, so letters act as keys until you press `/`.
Plain-letter keys work in normal mode; their Ctrl versions also work while
searching.
Search, new, rename, and kill prompts all use the input line at the bottom: Enter
confirms (a blank name cancels), and for kills only `y` confirms. The current
session can't be killed from the picker.
`*` marks the current session,
and window counts are aligned beside the preview. Ordering is shared by all
clients.
`Ctrl-a`, then `Ctrl-s` saves it along with tmux-resurrect; automatic continuum
saves include it too. Session names are stored privately in
`${XDG_STATE_HOME:-~/.local/state}/tmux/session-picker-order` and matched when
you open the picker after restoring sessions, even if their IDs have changed.
New sessions appear after the saved order.
Reordering swaps neighboring sessions in the full list; clear the search to
see their positions. Session names and running processes are unchanged.

The preview is checked every second and redrawn only when the screen changes
(this needs `curl`; without it, the preview updates when the selection moves).
It shows the active pane's current screen
in color, including full-screen apps and the current copy-mode view, rather than
old scrollback. It starts at the bottom; use Shift-Up/Down to scroll. This is a
read-only text view, not an interactive or scaled image of the whole window:
wide screens are clipped horizontally, and other split panes are not shown.
