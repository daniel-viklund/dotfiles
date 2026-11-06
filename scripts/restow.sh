#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v stow >/dev/null 2>&1; then
  printf '%s\n' 'dotfiles: install GNU Stow, then run scripts/restow.sh.' >&2
  exit 1
fi

# Refresh only packages already linked on this machine (Mac or WSL).
set --
for entry in \
  'zsh:.zshrc' \
  'neovim:.config/nvim-scratch/init.lua' \
  'tmux:.config/tmux/tmux.conf' \
  'wezterm:.config/wezterm/wezterm.lua' \
  'keyhac:.keyhac/config.py' \
  'hammerspoon:.hammerspoon/init.lua'
do
  package=${entry%%:*}
  anchor=${entry#*:}
  if [ "$HOME/$anchor" -ef "$repo/packages/$package/$anchor" ]; then
    set -- "$@" "$package"
  fi
done

[ "$#" -gt 0 ] || exit 0
# Check conflicts before changing links; never adopt or overwrite local files.
stow --simulate --restow --dir="$repo/packages" --target="$HOME" "$@"
stow --restow --dir="$repo/packages" --target="$HOME" "$@"
printf '%s\n' "dotfiles: refreshed Stow links for $*."
