# Dotfiles

Zsh/Powerlevel10k, Neovim (`nvim-scratch`), WezTerm, tmux, Keyhac, and Hammerspoon.
GNU Stow links `packages/` into your home directory. Edit configs at their usual
paths and commit changes in this repo.

## Setup

Install Homebrew, then clone to `~/Documents/Github/daniel-viklund/dotfiles`.
From the repo:

```sh
brew install stow
stow -n -v -d packages -t "$HOME" zsh neovim tmux wezterm keyhac hammerspoon
stow -d packages -t "$HOME" zsh neovim tmux wezterm keyhac hammerspoon
```

The first Stow command previews changes. If existing configs conflict, move
them to a backup first; Stow does not back them up. Start a new terminal after
setup. Re-run the last command when adding configs. To remove links, use the
same command with `-D`; files in this repo remain intact.

On a fresh Mac, `brew bundle --file=Brewfile` installs the tools and apps too.
It is unnecessary on the current Mac, where WezTerm and the Meslo font were
installed outside Homebrew and could conflict with a bundle installation.

## Private settings

- `~/.config/zsh/local.zsh`: credentials, work helpers, and machine overrides.
  Keep it outside Git with permissions `600`; an example is in `examples/`.
- `~/.hammerspoon/local.lua`: local app shortcuts, ignored by Git. Start from
  `local.example.lua` in that directory.
- `~/.keyhac/local.py`: private app shortcuts for Keyhac, ignored by Git.
  Start from `packages/keyhac/.keyhac/local.example.py`.
- Git settings, SSH keys, and login sessions are managed locally, outside this repo.

Downloaded tmux plugins, Hammerspoon Spoons, and local settings are ignored by
Git. Git ignores control commits; Stow manages links to the package contents.

## Fresh-machine extras

- Install TPM with `git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm`,
  then press `Ctrl-a`, followed by capital `I`, inside tmux to install plugins.
- Launch Keyhac and grant macOS Accessibility permission. See the
  [Keyhac setup](packages/keyhac/README.md) for matching Mac/Windows shortcuts.
  Hammerspoon remains available as a fallback; run only one at a time.
- See [Neovim's README](packages/neovim/.config/nvim-scratch/readme.md) for its
  language tools and existing macOS/Windows bootstrap scripts.
- Transfer required private settings and SSH keys separately.

The original configs and Git histories are preserved on this Mac under
`~/.local/state/dotfiles/backups/20261007-134101-3bc4e68a/`, along with the
original recovery script and migration notes. Keep this backup private.
Kitty and the older `~/.config/nvim` remain separate.

## Windows with Ubuntu on WSL

This machine uses `Ubuntu-24.04`, with Linux user `daniel` and zsh as the login
shell. The working repository is `~/Documents/Github/daniel-viklund/dotfiles`
inside Ubuntu. Stow links the `zsh`, `neovim`, and `tmux` packages into Linux home.
Hammerspoon is only used on macOS.

Windows WezTerm loads this repository's WezTerm config through
`//wsl.localhost/Ubuntu-24.04/home/daniel/Documents/Github/daniel-viklund/dotfiles/`.
The Windows wrapper at `C:\Users\Daniel\.config\wezterm\wezterm.lua` launches
Ubuntu and attaches to (or creates) tmux session `main`. The previous Windows
config is saved alongside it as `wezterm.lua.backup-*`.

- Launch WezTerm from Start, or run `wsl` in PowerShell for a plain zsh shell.
- Run `nvim` in Ubuntu; `.zshrc` selects the `nvim-scratch` configuration.
- tmux uses `Ctrl-a` as its prefix: then `c` for a window, `d` to detach,
  or `[` for copy mode. `Alt-1` through `Alt-9` select tmux windows in WezTerm.
- The WSL tmux copy binding uses `clip.exe` for the Windows clipboard.
- Powerlevel10k is installed under `~/.local/share/powerlevel10k`.
- Windows has the MesloLGS NF font installed for the current user.
- Linux Git uses Windows GitHub CLI as its GitHub credential helper.
  The `gh` command is also a wrapper around the Windows CLI.

Set your Linux password privately from PowerShell before using `sudo`:

```powershell
wsl -d Ubuntu-24.04 -u root -- passwd daniel
```

The installed tools include Neovim 0.12.6, tmux 3.8, tree-sitter 0.27.1,
LazyGit 0.66.2, Node 24, Rust stable, Go, and .NET LTS. Neovim and Node live
under `/opt` and tmux under `/usr/local`; update these installations separately
from Ubuntu packages. Language tools are managed by Mason.
