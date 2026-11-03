"""Hammerspoon shortcuts, shared by Keyhac 2 on macOS and Windows."""

import os
from pathlib import Path
import runpy
import string

from keyhac import ActivateApplication, SnapWindow, getLogger


logger = getLogger("Dotfiles")


def _windows_launch(name):
    """Prefer installed desktop apps; ShellExecute resolves the fallback."""
    candidates = {
        "Bitwarden": [r"%LOCALAPPDATA%\Programs\Bitwarden\Bitwarden.exe"],
        "Firefox": [r"%ProgramFiles%\Mozilla Firefox\firefox.exe"],
        "WezTerm": [r"%ProgramFiles%\WezTerm\wezterm-gui.exe"],
        "Davinci Resolve": [r"%ProgramFiles%\Blackmagic Design\DaVinci Resolve\Resolve.exe"],
    }
    for candidate in candidates.get(name, []):
        path = os.path.expandvars(candidate)
        if Path(path).is_file():
            return path
    return {
        "Finder": "explorer.exe",
        "Spotify": "spotify:",
        "Bitwarden": "Bitwarden.exe",
        "Firefox": "firefox.exe",
        "WezTerm": "wezterm-gui.exe",
        "Discord": "discord:",
        "Davinci Resolve": "Resolve.exe",
    }.get(name, name)


def _launcher(spec, mac):
    # A dict allows custom process names and executable paths in local.py.
    if isinstance(spec, dict):
        return ActivateApplication(app=spec["app"], launch=spec["launch"], cycle=False)
    app = spec
    if not mac:
        app = {
            "Finder": "explorer",
            "Firefox": "firefox",
            "WezTerm": "wezterm-gui",
            "Davinci Resolve": "Resolve",
        }.get(spec, spec)
    launch = spec + ".app" if mac else _windows_launch(spec)
    return ActivateApplication(app=app, launch=launch, cycle=False)


def _identity(window, mac):
    # Window equality on macOS uses titles, so it cannot distinguish two
    # untitled windows. AX element identity / HWND survives title changes.
    native = window.native
    return native.identity_key() if mac else int(native.hwnd)


def configure(keymap):
    mac = keymap.platform == "mac"
    app_mod = "Ctrl-Cmd" if mac else "Ctrl-Win"
    label = "⌃⌘" if mac else "Ctrl+Win+"
    keys = keymap.define_keytable(focus_path_pattern="*")

    def alert(message):
        logger.info(message)
        pop = getattr(keymap, "pop_balloon", None)
        if pop:
            pop("dotfiles", message, 2.0)

    keys["Ctrl-Alt-H"] = SnapWindow("left")
    keys["Ctrl-Alt-L"] = SnapWindow("right")
    # Fill the usable screen, without entering macOS full-screen mode.
    keys["Ctrl-Alt-K"] = SnapWindow("full")

    # Remember discovery order rather than z-order: activating a window must
    # not reorder the cycle and leave it bouncing between just two windows.
    window_orders = {}

    def cycle_app_windows():
        active = keymap.get_active_window()
        if active is None:
            return
        windows = [window for window in keymap.list_windows()
                   if window.pid == active.pid]
        if mac:
            windows = [window for window in windows
                       if window.native.get_attribute_value("AXSubrole") == "AXStandardWindow"]
        if len(windows) < 2:
            return
        by_id = {_identity(window, mac): window for window in windows}
        order = [identity for identity in window_orders.get(active.pid, [])
                 if identity in by_id]
        order.extend(identity for identity in by_id if identity not in order)
        window_orders[active.pid] = order
        current = _identity(active, mac)
        if current not in order:
            return
        target = by_id[order[(order.index(current) + 1) % len(order)]]
        if target.is_minimized():
            target.restore()
        target.activate()

    keys["Ctrl-Alt-J"] = cycle_app_windows

    # Match Hammerspoon's shared defaults and optional private overrides.
    apps = {"F": "Finder", "S": "Spotify"}
    local_path = Path(keymap.config_path).with_name("local.py")
    local_loaded = local_path.is_file()
    if local_loaded:
        extra = runpy.run_path(str(local_path), init_globals={"PLATFORM": keymap.platform})
        apps.update(extra.get("APPS", {}))

    for key, spec in apps.items():
        if spec:
            keys[f"{app_mod}-{key}"] = _launcher(spec, mac)

    for key in string.digits + string.ascii_uppercase:
        # Preserve Ctrl+Cmd+Q (Mac lock screen), and leave Ctrl+Win+Q alone.
        if key != "Q" and not apps.get(key):
            keys[f"{app_mod}-{key}"] = lambda key=key: alert(
                f"{label}{key} is not bound to an app")

    keys[f"{app_mod}-Alt-R"] = keymap.reload_config
    alert("Config loaded" + (" (+local)" if local_loaded else ""))
