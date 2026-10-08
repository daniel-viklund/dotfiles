# Neovim config

Requires Neovim **0.12 or newer**. Plugins are managed by `vim.pack` and pinned
in `nvim-pack-lock.json`. Language servers, debug adapters, formatters, and
linters are managed by Mason.

## Home screen

Starting without a file shows centered Neovim artwork. Press `-` to open Oil;
pressing `q` in Oil returns to the artwork if no file buffers are open.
Deleting the last file buffer with `:bd` also brings the artwork back.
Hidden file buffers and unsaved drafts count as open buffers. Press `q` on
the home screen to quit. Customize the artwork in `lua/config/start.lua`.

## Plugins

Each plugin has one file in `lua/config/plugins/` containing its install
declaration and configuration. `init.lua` automatically loads every other
`.lua` file in that directory, alphabetically.

To add a plugin, create a file such as `lua/config/plugins/comment.lua`:

```lua
vim.pack.add({ "https://github.com/numToStr/Comment.nvim" })

require("Comment").setup()
```

Restart Neovim to install and load it. No edits to `plugins/init.lua` are needed.
List dependencies before the plugin in the same `vim.pack.add` call; shared
dependencies can appear in multiple files because `vim.pack` loads them once.
Use a spec table for a custom name or branch, as shown in `colorscheme.lua` and
`harpoon.lua`.

To disable a plugin, rename its file from `.lua` to `.lua.disabled` and restart.
Snacks is already disabled this way. To enable it, rename `snacks.lua.disabled`
back to `snacks.lua`. Disabled plugins stay installed and in the lockfile.

## Diagnostics

`Space sd` searches diagnostics for the current file; `Space sD` searches all
reported diagnostics, with code previews. Type to filter and press `Enter` to
jump to a result. `Space le` shows diagnostics on the current line.

Workspace diagnostics are configured in `lua/config/plugins/lsp.lua`:

- Python: basedpyright checks the workspace and pushes results for unopened files,
  respecting project include/exclude settings. Pull diagnostics are disabled in
  its initialization options so the picker does not need to request a scan.
- TypeScript/JavaScript: vtsls enables experimental project-wide error reporting.
- Rust: rust-analyzer runs `cargo check --workspace` on save.
- Go: gopls diagnoses workspace packages, expanding to the containing module.
- C/C++: clangd reports source diagnostics for open files. Its background index
  does not provide a whole-project diagnostic scan; CMake builds can publish
  compiler errors and warnings using the commands below.

Open a source file to start its language server and allow analysis to finish
before searching. Project-wide checking can use more CPU and memory on large
projects. The picker displays reported results; opening it does not start a scan.

### CMake project diagnostics

`Space sc` prompts for an already configured CMake build directory, runs
`cmake --build` asynchronously, and publishes compiler diagnostics for
`Space sd` / `Space sD`. It defaults to `build/` under the working directory
(or the working directory itself if it contains `CMakeCache.txt`) and remembers
the last selected directory for the session. Save your files before building.

- `:CMakeDiagnostics [build-directory]` runs an incremental build.
- `:CMakeDiagnostics! [build-directory]` cleans build outputs first, then rebuilds
  the default targets so unchanged sources are checked too.
- `:CMakeDiagnosticsLog` shows the latest build output, including linker or
  configuration errors that cannot be attached to a source location.

Each run replaces the previous CMake diagnostics for that build directory;
incremental builds report only what was rebuilt. Clangd diagnostics are retained
separately. Builds use the configured toolchain and default targets and can stop
on compiler errors; targets excluded from the default build are not checked.
This compiles the project and does not run its tests.

Your `compile_commands.json` supplies clangd with compilation flags; it does not
trigger diagnostics for unopened files. Continue generating it as usual. The
CMake diagnostic command uses the existing build configuration and does not
reconfigure the project or change compiler warning flags.

## File managers

Press `Space e` to try Neo-tree in the current editor window. It fills the screen
when there are no splits. `Enter` expands or collapses folders; on a file, it
opens the file in place of the tree. `q` closes the tree, `Backspace` goes up a
directory, and `?` shows its keybindings. The tree uses the editor background.

Oil remains on `-` and still handles opening directories directly. Configure the
trial in `lua/config/plugins/neo-tree.lua`; rename that file to
`neo-tree.lua.disabled` and restart to disable it.

## Sessions

[AutoSession](https://github.com/rmagatti/auto-session) automatically saves your
open files (including hidden buffers), editor splits and their sizes, tabs,
folds, and cursor positions when you quit Neovim. Launch `nvim` or `nvim .` in
the same directory to restore that session. Each working directory has its own
session; the home directory and filesystem root are excluded.

| Mapping | Action |
| --- | --- |
| `Space ss` | Find and switch sessions with Telescope (saves the current session first) |
| `Space ws` | Save the current layout now |
| `Space wr` | Restore the session for the current directory |

Terminal panes, their output, and running processes are not restored. Sessions
remember file locations and layout, not unsaved file contents; save edits with
`:w` or `:wa` as usual. Opening another file adds it to the current workspace;
use `Space ws` for an immediate checkpoint. Launching `nvim filename` skips
automatic session restore and saving, so a quick edit leaves the saved workspace
intact. Use `:AutoSession disable` to skip saving for the rest of a run.

## Multiple cursors

`lua/config/plugins/multicursor.lua` configures
[multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim) with gold
secondary cursors. The highlights are reapplied when the colorscheme changes.

Select a block with `Ctrl-v`, then press `I` to insert or `A` to append at each
selected line. These mappings also work with linewise and characterwise visual
selections. The extra insertion points stay highlighted while you type; the
text is repeated on the other lines when you leave Insert mode. Press `Esc`
(or your existing `jk` mapping) to leave Insert mode, then `Esc` again to clear
the extra cursors and search highlighting.

| Mapping | Action (Normal or Visual mode) |
| --- | --- |
| `Space mj` / `Space mk` | Add a cursor below / above |
| `Space mn` / `Space mN` | Add the next / previous matching word or selection |
| `Space ma` | Add cursors at all matching words or selections |

## Window splits

Use `Space w h/j/k/l` to carry the current file into a new split to the
left/below/above/right. The original window shows its previous file (Neovim's
alternate buffer), and focus stays on the current file in the new split. For
example, open file A, then file B in the same window, and press `Space w l`:
A stays on the left and B moves to the right. Unsaved edits are preserved.
If there is no previous ordinary file buffer, the shortcut shows a message
without opening a split.

Use `Ctrl-h/j/k/l` to navigate windows. Native `Ctrl-w v` and `Ctrl-w s` show
the same buffer in two windows, useful for viewing different parts of one file.
Native `Ctrl-w H/J/K/L` moves an existing window to the corresponding edge.
Use `Ctrl-w c` to close a window and `Ctrl-w =` to equalize window sizes.

## Build and run

Use `Space pc` to set any shell **build command**, **run commands**, and
**working directory** for the current project. These can invoke any tool or
script; no language-specific runner or extra plugin is required. The first
build/run also prompts if its command is missing. Leave build blank for projects
that only need a run command, or the first run command blank for build-only
projects. Enter each run command separately; leave the next command blank to
finish. Each command launches concurrently in its own output terminal.

For a CMake client/server project, enter `cmake --build build` as the build
command, `./build/server` as run command 1, and `./build/client` as run command 2.
Leave run command 3 blank and use `.` as the working directory. Keep each
executable in the foreground; no `&` or `wait` is needed. Commands start in order
but do not wait for server readiness, so the client may need connection retries.
Shell operators inside a single command keep their usual meaning: `&&` waits
for success and does not create separate terminals.

| Mapping (Normal mode) | Action |
| --- | --- |
| `Space pb` | Build |
| `Space pr` | Run, or stop and restart all current run commands |
| `Space pR` | Stop all commands, build, then run only if the build succeeds; skip an empty build command |
| `Space px` | Stop all commands, including any pending restart or build/run sequence |
| `Space pc` | Configure this project's commands |
| `Space t4` | Show/hide all latest build/run outputs |

Terminal **4** is reserved for this runner. Additional run commands use free
terminal numbers above 4, leaving existing shells alone. Terminals 1–3 remain
ordinary shells; `Space tn` skips all runner outputs, including finished ones.
A new build/run replaces the current set after every process exits. Output
stays visible when a command finishes or fails, until the next build/run starts.
One run command exiting does not stop the others. Launching shows the
output and returns focus to your source window. Navigate to the terminal with
your window mappings and press `i` for interactive input; `jk` returns to Normal
mode. Opening hidden output with `Space t4` also focuses the terminal.

Commands run through Neovim's `shell` using files on disk, so save your changes
first. Build and run are separate processes: put shared environment setup in
both commands or in a script. Commands should stay in the foreground so the
runner can stop them. It also stops all active commands when Neovim exits.

Projects are identified by the directory where Neovim was launched, even when
you edit files elsewhere or change Neovim's current directory. Working
directories can be absolute or relative to the project root, such as `src/api`.
Settings are stored locally in `stdpath("data")/project-runner/`, separately for
each project, and survive Neovim restarts. They do not add files to your repos.

The implementation lives in `lua/config/runner.lua`, loaded by the ToggleTerm
configuration. On macOS/Linux, with ToggleTerm installed and Python 3 available,
run the process integration checks using
`nvim --headless -u NONE -l scripts/test-runner.lua`.

## Python tests

[Neotest](https://github.com/nvim-neotest/neotest) provides a test tree, colored
pass/fail signs beside tests, failure diagnostics, and output windows. Its
Python adapter detects the project's virtualenv (including `.venv`) and uses
pytest if installed, otherwise Python's built-in unittest. An activated
`VIRTUAL_ENV` takes precedence. The Python Tree-sitter parser is already installed
by this config. Save your changes before running tests.

Open Neovim from the Python project directory, then open a test file and press
`Space pt` to run the project and show the test tree on the right.
Test shortcuts share `Space p` with the build/run commands.

| Mapping (Normal mode) | Action |
| --- | --- |
| `Space pn` | Run the test under/nearest the cursor |
| `Space pf` | Run the current test file |
| `Space pt` | Run all project tests and open the summary |
| `Space pl` | Repeat the last test run |
| `Space ps` | Toggle the test tree |
| `Space pX` | Stop the nearest test run (uppercase X; `Space px` stops the project runner) |
| `Space pd` | Debug the nearest test with the existing Python DAP adapter |
| `]T` / `[T` | Jump to the next / previous failed test |

Inside the test tree: `Enter` expands, `r` runs the selected test/file/directory,
`o` shows output, `i` jumps to source, `d` debugs, and `?` shows help.
Debugging requires Mason's `debugpy` adapter to be installed (`:Mason`).
No pytest installation is needed for unittest projects. For pytest projects,
install pytest into that project's environment using its package manager.

## Install

Download or clone this entire config, then run the installer from its directory.
Both installers default to the standard `nvim` app name and support a dry run.
They reuse available tools, install missing dependencies, copy the config,
install the locked plugins, wait for Tree-sitter parsers to compile, and install
`lua-language-server` and `rust-analyzer` through Mason. Lua and Rust LSP support
are enabled in the config. Stable Rust, rustfmt, and Clippy are installed through
rustup for development and Blink's native matcher.

An existing destination config is renamed to a sibling
`nvim.backup-<timestamp>-<pid>` directory before the new copy is activated.
Data, caches, and Mason packages are retained. If the source is already the
destination, files stay in place. Rerunning is supported; it does not update
locked plugin revisions. Changes to the source require rerunning the installer
because the destination is a copy, not a symlink.

### macOS

```sh
bash scripts/install-macos.sh --dry-run
bash scripts/install-macos.sh
```

Uses Homebrew, installing it through its official installer if needed. Homebrew
may ask for your password. A C compiler comes from Apple's Command Line Tools;
if the system installation dialog opens, finish it and rerun the script.
Follow Homebrew's shell setup instructions if it was newly installed. Rustup
uses its official installer if absent; open a new shell afterward so Cargo is
on PATH. Existing default Rust toolchains are preserved.

To keep the `nvim-scratch` app name and its separate plugins/Mason packages:

```sh
bash scripts/install-macos.sh --appname nvim-scratch
NVIM_APPNAME=nvim-scratch nvim
```

The default destination is `~/.config/nvim` (or `$XDG_CONFIG_HOME/nvim`).

### Windows 10/11, x64

Run in PowerShell 5.1 or newer. Requires [WinGet/App Installer](https://aka.ms/getwinget).
Individual installers may request administrator elevation.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

The execution policy applies only to that invocation. The script refreshes its
PATH after package installation. If an older executable still shadows the new
one, correct PATH and rerun in a new terminal.

For the separate `nvim-scratch` installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -AppName nvim-scratch
$env:NVIM_APPNAME = 'nvim-scratch'
nvim
```

The default destination is `%LOCALAPPDATA%\nvim` (or `$env:XDG_CONFIG_HOME\nvim`).
The script reuses GCC or installs WinLibs GCC. It installs the stable
`x86_64-pc-windows-gnu` Rust toolchain, sharing GCC between Rust and Tree-sitter.
Blink explicitly builds with that toolchain. Existing default Rust toolchains
are preserved; a new rustup installation defaults to GNU Rust. Neovim selects
GCC for Tree-sitter if `CC` is unset.

This avoids installing Visual Studio Build Tools for this config. Rust projects
that interoperate with MSVC libraries can still require the MSVC toolchain and
Windows SDK; see [Rust's Windows toolchain guidance](https://rust-lang.github.io/rustup/installation/windows.html).

Archive-tool directories are recorded in `windows-path.txt` in the installed
config and added only to Neovim's PATH. This file contains machine-specific
paths and should not be copied between computers.

## Dependency audit

| Tool | Why it is needed | macOS | Windows |
| --- | --- | --- | --- |
| Neovim >= 0.12 | `vim.pack`, Blink v2, current Tree-sitter API | `neovim` | `Neovim.Neovim` |
| Git | Plugin downloads, LazyGit, statusline Git information | Apple's Git, or Homebrew `git` | `Git.Git` |
| Tree-sitter CLI >= 0.26.1 | Compile the configured language parsers | `tree-sitter-cli` | `tree-sitter.tree-sitter-cli` |
| C compiler | Tree-sitter parsers, Rust native dependencies | Apple Command Line Tools | Existing GCC, or `BrechtSanders.WinLibs.POSIX.UCRT` |
| Rust/Cargo, rustfmt, Clippy | Rust development and Blink's native matcher | Official rustup installer; stable toolchain | `Rustlang.Rustup`; stable GNU toolchain |
| ripgrep (`rg`) | Telescope live grep and file search | `ripgrep` | `BurntSushi.ripgrep.MSVC` |
| LazyGit | Terminal Git interface | `lazygit` | `JesseDuffield.lazygit` |
| curl and tar | Download/extract parser sources | Included with macOS | Included with current Windows |
| GNU tar, unzip, gzip | Mason archive handling | `gnu-tar`; system unzip/gzip | Git's GNU tar; PowerShell handles ZIP files |
| 7-Zip | Mason compressed archives on Windows | Not needed | `7zip.7zip` |
| Lua/Rust language servers | The enabled `lua_ls` and `rust_analyzer` LSPs | Mason | Mason |

Minimum versions come from the locked plugins' installation code and docs:
[Tree-sitter requirements](https://github.com/nvim-treesitter/nvim-treesitter/tree/728e031f6b11d03d1f0708b7dc4fb0f1d9c8a137#requirements),
[Blink installation](https://github.com/saghen/blink.cmp/blob/8219b58f1c11a2fb1644d3c7116c509fa8348ec0/doc/installation.md),
[Mason requirements](https://github.com/mason-org/mason.nvim#requirements), and
[Telescope dependencies](https://github.com/nvim-telescope/telescope.nvim#suggested-dependencies).

The remaining active plugins (Plenary, Harpoon, Oil, ToggleTerm, Lualine/Navic,
LSPConfig/mason-lspconfig, WhichKey, Noice/NUI, autopairs, Everforest, and blink.lib) use Neovim
and the tools above for the configured features. They do not add a separate
build system or language runtime. Snacks is disabled in the config but is still
present in the lockfile; `vim.pack` downloads that locked plugin too.

These tools are deliberately not installed:

- **Node.js/npm, Python, Go, Java, .NET:** only needed if a Mason package or a
  project specifically requires them. Mason manages tools, but does not supply
  every language runtime those tools depend on.
- **fd:** optional; Telescope can list files with ripgrep.
- **make/CMake:** not required to build this config's parsers or plugins.
- **neovim-remote/pynvim:** LazyGit works without them.
- **Nerd Font:** optional for decorative glyphs; choose one in your terminal if desired.

## Language servers

The automatic installation list lives in `lua/config/plugins/mason.lua`:

```lua
ensure_installed = { "lua_ls", "rust_analyzer" },
automatic_enable = true,
```

Use **LSPConfig names** in this list, such as `lua_ls`, `rust_analyzer`, or `ts_ls`.
`mason-lspconfig` translates them to Mason package names and installs missing
servers during interactive startup. Both installers use this same list and wait
for installation to finish in their headless sessions.

All mapped LSPs installed through Mason are enabled automatically, including
servers installed through `:Mason` that are not in `ensure_installed`. A newly
installed server is enabled in the current session; already-installed servers
are enabled on startup. Your server settings and LSP keymaps remain in
`lua/config/plugins/lsp.lua`.

Packages without an LSP mapping need separate configuration. Debug adapters
are configured below; standalone formatters still need their own setup. See
[mason-lspconfig's documentation](https://github.com/mason-org/mason-lspconfig.nvim#configuration).

## Debugging

`lua/config/plugins/nvim-dap.lua` contains the DAP plugins, UI, keymaps, and
adapter setup. Its filename makes it load after `mason.lua`.

- **Rust:** Mason installs `codelldb` and supplies launch configurations. Build
  your program with `cargo build`, press `F5`, and select the executable under
  `target/debug/` (with `.exe` on Windows).
- **Go:** Mason installs `delve`; `nvim-dap-go` supplies launch and test
  configurations. Install Go separately to build Delve and debug Go projects.
- **C# on Apple Silicon macOS:** uses the bundled native adapter from
  [netcoredbg-macOS-arm64.nvim](https://github.com/Cliffback/netcoredbg-macOS-arm64.nvim),
  including the existing DLL prompt and environment handling.
- **C# on Windows:** Mason installs standard `netcoredbg` through the `coreclr`
  adapter. The Mac adapter is not loaded. Install the .NET SDK separately and
  run `dotnet build` before launching a DLL from `bin/Debug/`.

Adapter selection follows the operating system and CPU architecture automatically.
Mason installs missing adapters during startup; let installation finish before
starting a debug session. Plugin revisions are pinned in `nvim-pack-lock.json`.

`F5` starts/continues, `F9` toggles a breakpoint, `F10` steps over, `F11` steps
into, and `F12` steps out. The existing `Space d` mappings are preserved:
`dc` continue, `db` breakpoint, `dB` conditional breakpoint, `dt` terminate,
`de` evaluate, and `du` toggle the UI. The UI opens when a session initializes
and closes when it ends.

## Verify and troubleshoot

```vim
:checkhealth vim.pack nvim-treesitter mason telescope blink.cmp dap
:LazyGit
```

`Space gg` opens LazyGit, `Space sf` finds files, and `Space sg` searches text.
Parser installation failures cause the installer to exit unsuccessfully; fix
the reported tool/compiler error and rerun. A config backup remains available
if setup fails after the files have been copied.

The configured parser list lives in `lua/config/plugins/treesitter.lua`; both
normal startup and the installers use that same list.

If LazyGit's `j` key waits about one second, restart Neovim to clear the former
global `jk` terminal mapping. Terminal escape/navigation mappings now apply
only to ToggleTerm. Inside ToggleTerm, `j` still waits for a possible `k` because
`jk` exits terminal mode; LazyGit opened with `Space gg` is unaffected.
