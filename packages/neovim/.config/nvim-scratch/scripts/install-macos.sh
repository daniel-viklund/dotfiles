#!/bin/bash
set -euo pipefail

app_name=nvim
dry_run=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --appname)
      [ "$#" -ge 2 ] || { echo '--appname needs a value' >&2; exit 1; }
      app_name=$2
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help)
      echo 'Usage: bash scripts/install-macos.sh [--appname nvim-scratch] [--dry-run]'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
case "$app_name" in
  ''|.|..|*[!a-zA-Z0-9_.-]*) echo 'Invalid app name' >&2; exit 1 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_source=$(cd -- "$script_dir/.." && pwd -P)

if "$dry_run"; then
  cat <<EOF
Source: $config_source
Destination: ${XDG_CONFIG_HOME:-$HOME/.config}/$app_name
Use/install Homebrew and Apple Command Line Tools.
Ensure Neovim >= 0.12, Git, tree-sitter-cli >= 0.26.1,
ripgrep, lazygit, and GNU tar; reuse macOS curl, unzip, and gzip.
Back up any existing destination, then copy the config.
Install locked plugins, compile configured parsers, and install
Lua/Rust language servers through Mason. Install stable Rust with rustup,
including rustfmt and Clippy, for development and Blink's matcher.
EOF
  exit 0
fi

[ "$(uname -s)" = Darwin ] || { echo 'This installer requires macOS.' >&2; exit 1; }

if ! command -v brew >/dev/null 2>&1; then
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_bin" ]; then eval "$("$brew_bin" shellenv)"; break; fi
  done
fi
if ! command -v brew >/dev/null 2>&1; then
  installer=$(mktemp -t nvim-homebrew)
  trap 'rm -f "$installer"' EXIT
  curl --fail --show-error --silent --location \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
  /bin/bash "$installer"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if ! xcrun --find clang >/dev/null 2>&1; then
  xcode-select --install || true
  echo 'Finish installing Apple Command Line Tools, then rerun this script.' >&2
  exit 1
fi

version_at_least() {
  awk -v actual="$1" -v minimum="$2" 'BEGIN {
    split(actual, a, "."); split(minimum, b, ".");
    for (i = 1; i <= 3; i++) {
      if (a[i]+0 > b[i]+0) exit 0;
      if (a[i]+0 < b[i]+0) exit 1;
    }
  }'
}

ensure_tool() {
  local executable=$1 formula=$2 minimum=${3:-} current=
  if command -v "$executable" >/dev/null 2>&1; then
    if [ -z "$minimum" ]; then return; fi
    current=$("$executable" --version | sed -nE '1s/[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    if [ -n "$current" ] && version_at_least "$current" "$minimum"; then return; fi
  fi
  if brew list --versions "$formula" >/dev/null 2>&1; then
    brew upgrade "$formula"
  else
    brew install "$formula"
  fi
  hash -r
}

ensure_tool nvim neovim 0.12.0
ensure_tool git git
ensure_tool tree-sitter tree-sitter-cli 0.26.1
ensure_tool rg ripgrep
ensure_tool lazygit lazygit
ensure_tool gtar gnu-tar

export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
if ! command -v rustup >/dev/null 2>&1; then
  rust_installer=$(mktemp -t nvim-rustup)
  curl --proto '=https' --tlsv1.2 --fail --show-error --silent --location \
    https://sh.rustup.rs -o "$rust_installer"
  sh "$rust_installer" -y --profile minimal --default-toolchain stable
  rm -f "$rust_installer"
fi
rustup toolchain install stable --profile minimal --component rustfmt --component clippy
if ! rustup default >/dev/null 2>&1; then rustup default stable; fi

export NVIM_APPNAME="$app_name"
export NVIM_CONFIG_SOURCE="$config_source"
nvim --headless -u NONE -S "$script_dir/bootstrap.lua"
printf '\nInstalled. Launch with: NVIM_APPNAME=%s nvim\n' "$app_name"
