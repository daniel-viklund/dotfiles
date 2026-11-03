# Keyhac

Keyhac 2 replaces the Hammerspoon shortcuts on macOS and Windows using the
same `~/.keyhac/config.py`. Install Keyhac on the host OS, including Windows
when your terminal runs in WSL. The Hammerspoon config is kept as a fallback;
run only one of the two apps at a time to avoid overlapping shortcuts.

| Shortcut | Action |
| --- | --- |
| `Ctrl+Alt+H` / `Ctrl+Alt+L` | Left / right half of the current monitor |
| `Ctrl+Alt+K` | Fill the current monitor's work area |
| `Ctrl+Alt+J` | Cycle standard windows of the focused app, restoring minimized windows |
| `Ctrl+Cmd+letter` (Mac), `Ctrl+Win+letter` (Windows) | Launch or focus an app |
| `Ctrl+Cmd+Alt+R` (Mac), `Ctrl+Win+Alt+R` (Windows) | Reload config and local overrides |

`F` opens Finder / File Explorer, and `S` opens Spotify. Other letters and
digits display an unbound-key alert. `Q` is left alone to preserve the Mac's
lock shortcut. Windows can reserve some combinations before Keyhac sees them.
Window cycling uses stable discovery order, reset on config reload, rather
than Hammerspoon's numeric window-ID order. It distinguishes same-title
windows and stays stable when window titles or focus change.

## macOS

```sh
brew install --cask crftwr/tap/keyhac
stow -n -v --no-folding -d packages -t "$HOME" keyhac
stow --no-folding -d packages -t "$HOME" keyhac
cp packages/keyhac/.keyhac/local.example.py ~/.keyhac/local.py
chmod 600 ~/.keyhac/local.py
open -a Keyhac
```

Grant Keyhac access in **System Settings > Privacy & Security > Accessibility**,
then reopen it. Quit Hammerspoon when switching over. Add Keyhac under
**System Settings > General > Login Items & Extensions** to start it at login,
and disable Hammerspoon's launch-at-login option.

The app bundle currently requires Apple Silicon and macOS 12+.
On first launch the loaded message is in Keyhac's console; on reload it also
appears as a popup. Unbound-key alerts use Keyhac's popup style.
Keyhac 2.7.0 logs `Unsupported keyboard layout: iso` on this Mac and falls
back to its common key map. The letter shortcuts above were checked through
the live keyboard hook; this config does not bind ISO-specific punctuation.

## Windows 10/11 x64

Run in PowerShell from this repo:

```powershell
winget install --id 9P8H1PG6PRHH --source msstore
$keyhacDir = Join-Path $HOME '.keyhac'
New-Item -ItemType Directory -Force $keyhacDir | Out-Null
Copy-Item .\packages\keyhac\.keyhac\config.py $keyhacDir
Copy-Item .\packages\keyhac\.keyhac\local.example.py (Join-Path $keyhacDir 'local.py')
```

Back up existing Keyhac files before copying. Open Keyhac after installation.
The Windows commands copy files; rerun the config copy after pulling updates.
Windows paths can differ by installer; edit `local.py` with explicit
`{"app": "process-name", "launch": "executable-path"}` targets when needed.
The supplied mappings cover the app names in the Hammerspoon local example.
Apps must be installed separately. No Windows installation or live Windows
shortcut validation is performed by setting this up on the Mac.

## Local overrides

`~/.keyhac/local.py` stays outside Git. It defines an `APPS` dictionary merged
over `F` and `S`; see `local.example.py`. `PLATFORM` is available for OS-specific
app targets. Changes take effect with the reload shortcut or **Reload Config**
in Keyhac's menu. Disabled launchers get the same unbound-key alert as any
other unused letter. Invalid Python keeps Keyhac's previous config active and
reports the error in its console.

To return to Hammerspoon, quit Keyhac and open Hammerspoon.

References: [Keyhac](https://crftwr.github.io/keyhac/),
[configuration](https://crftwr.github.io/keyhac/doc/configuration.html).
