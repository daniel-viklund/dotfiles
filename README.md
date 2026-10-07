# Dotfiles

Zsh/Powerlevel10k, Git, Neovim (`nvim-scratch`), WezTerm, tmux, and Hammerspoon.
GNU Stow links `packages/` into your home directory. Edit configs at their usual
paths and commit changes in this repo.

## Setup

Install Homebrew, then clone to `~/Documents/Github/daniel-viklund/dotfiles`.
From the repo:

```sh
brew install stow
stow -n -v -d packages -t "$HOME" zsh git neovim tmux wezterm hammerspoon
stow -d packages -t "$HOME" zsh git neovim tmux wezterm hammerspoon
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
- SSH keys and login sessions stay outside this repo. Git's identity files
  contain personal/work email addresses and refer to your existing SSH keys.

Downloaded tmux plugins, Hammerspoon Spoons, and local settings are ignored by
Git. Git ignores control commits; Stow manages links to the package contents.

## Fresh-machine extras

- Install TPM with `git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm`,
  then press `Ctrl-a`, followed by capital `I`, inside tmux to install plugins.
- Launch Hammerspoon and grant macOS Accessibility permission.
- See [Neovim's README](packages/neovim/.config/nvim-scratch/readme.md) for its
  language tools and existing macOS/Windows bootstrap scripts.
- Transfer required private settings and SSH keys separately.

The original configs and Git histories are preserved on this Mac under
`~/.local/state/dotfiles/backups/20261007-134101-3bc4e68a/`, along with the
original recovery script and migration notes. Keep this backup private.
Kitty and the older `~/.config/nvim` remain separate.
