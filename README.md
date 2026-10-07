# Dotfiles

Daniel's Zsh/Powerlevel10k, Git, Neovim (`nvim-scratch`), WezTerm, tmux, and
Hammerspoon setup. Edit the files in `packages/`, or through their usual paths
in your home directory; the installed paths are symlinks into this repository.
Commit changes here. Kitty and the older `~/.config/nvim` stay separate.

## Install on this Mac

```sh
./install.sh --dry-run
./install.sh
```

Requires Python 3. The installer backs up existing destinations before linking
them, including the complete original configuration repositories and their Git
histories. Re-running it leaves correct links alone. It preserves existing tmux
plugins and Hammerspoon local settings in ignored paths. It does not install
packages, launch apps, or fetch plugins.

Backups are under `~/.local/state/dotfiles/backups/`, in a private directory per
installation. The installer prints the exact `manifest.json` path. To undo:

```sh
./install.sh --restore /path/to/backup/manifest.json --dry-run
./install.sh --restore /path/to/backup/manifest.json
```

Restoration refuses to overwrite destinations that no longer point to this
repo. Changes made in the dotfiles repository remain there after restoration.
Backups may contain the original shell credentials; keep them private.

## Fresh Mac

1. Install Apple's command line tools and Homebrew. Clone this repository under
   `~/Documents/Github/daniel-viklund/dotfiles` so the existing personal Git
   identity rule applies.
2. Run `brew bundle --file=Brewfile` to install the listed tools. The file records
   desired dependencies rather than exact installed versions. WezTerm and the
   Meslo font on the original Mac were installed outside Homebrew; a bundle run
   there may encounter existing app/font files. No bundle install is needed
   merely to activate these dotfiles on the original Mac.
3. Run `./install.sh`. Start a new terminal afterward.
4. Install Rust using rustup if needed. For the editor's complete language-tool
   setup, read `packages/neovim/.config/nvim-scratch/readme.md` and its existing
   macOS/Windows bootstrap scripts. Those scripts can install or upgrade tools.
5. On a fresh machine, install TPM:

   ```sh
   git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
   ```

   Start tmux, then press `Ctrl-a`, followed by capital `I` to install plugins.
6. Launch Hammerspoon and grant its macOS Accessibility permission. Copy
   `.hammerspoon/local.example.lua` to `.hammerspoon/local.lua` if you want local
   app shortcuts.
7. Supply local secrets and SSH keys separately, and sign into GitHub/Azure as
   needed. Keys and login sessions are not part of this repo.

## Local settings and credentials

`~/.config/zsh/local.zsh` holds the original work API credentials, helper
functions, and internal SSH alias on this Mac. It is outside this repository
and is loaded by `.zshrc`. For another machine, start with
`examples/zsh.local.example` and transfer required private settings securely.
Use permissions `600` on the file. The work API helpers require `jq`.

Hammerspoon's `local.lua`, its downloaded Spoons, tmux plugins, logs, and backups
are ignored. Neovim's `windows-path.txt` is machine-generated and ignored.
Neovim's plugin lockfile is tracked; sessions and installed editor plugins live
outside the repo. `.p10k.zsh` is tracked because it is the prompt configuration.

Git retains the original personal/work identities and folder-based rules, with
an explicit personal rule for this repository through its clone location.
The identity files contain email addresses and refer to `~/.ssh/id_personal`
and `~/.ssh/id_work`; the keys themselves are not included. Review identities
and machine paths before sharing the repo or using it on another machine.

## Migration

`migration-sources.json` records original remotes, revision IDs, and working
tree status. This repo starts with a snapshot of the current files, including
uncommitted Neovim work. Old histories are retained in the local backups rather
than imported into this repository. No remote is created automatically.
