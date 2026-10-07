for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_bin" ]]; then eval "$("$brew_bin" shellenv zsh)"; break; fi
done
unset brew_bin
