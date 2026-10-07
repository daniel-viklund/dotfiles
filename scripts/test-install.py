#!/usr/bin/env python3
"""Exercise migration and restore against a temporary fake home and repo."""
from pathlib import Path
import json
import runpy
import shutil
import subprocess
import sys
import tempfile

original = Path(__file__).resolve().parent / "install.py"
links = runpy.run_path(str(original))["LINKS"]

with tempfile.TemporaryDirectory(prefix="dotfiles-test-") as temp:
    root = Path(temp).resolve()
    repo, home = root / "repo", root / "home"
    (repo / "scripts").mkdir(parents=True)
    home.mkdir()
    shutil.copy2(original, repo / "scripts/install.py")
    directories = {".config/nvim-scratch", ".config/tmux", ".config/wezterm", ".hammerspoon"}
    for target, package in links.items():
        source = repo / "packages" / package
        destination = home / target
        source.parent.mkdir(parents=True, exist_ok=True)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if target in directories:
            source.mkdir()
            (source / "config").write_text("new")
            destination.mkdir()
            (destination / "config").write_text("old")
            (destination / ".git").mkdir()
            (destination / ".git/HEAD").write_text("original history")
        else:
            source.write_text("new")
            destination.write_text("old")
    plugin = home / ".config/tmux/plugins/tpm"
    plugin.mkdir(parents=True)
    (plugin / "tpm").write_text("plugin")
    (home / ".hammerspoon/local.lua").write_text("return {}")
    # An existing symlink must be restored as a symlink, not its dereferenced file.
    old_profile = root / "original-profile"
    old_profile.write_text("profile")
    (home / ".zprofile").unlink()
    (home / ".zprofile").symlink_to(old_profile)

    def run(*args, success=True):
        result = subprocess.run([sys.executable, str(repo / "scripts/install.py"),
                                 "--target", str(home), *args], capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stderr
        return result.stdout

    run("--dry-run")
    assert not (home / ".local").exists()
    run()
    manifests = list((home / ".local/state/dotfiles/backups").glob("*/manifest.json"))
    assert len(manifests) == 1
    manifest = manifests[0]
    assert manifest.parent.stat().st_mode & 0o777 == 0o700
    assert len(json.loads(manifest.read_text())["links"]) == len(links)
    for target, package in links.items():
        assert (home / target).is_symlink()
        assert (home / target).resolve() == repo / "packages" / package
    assert (home / ".config/tmux/plugins/tpm/tpm").read_text() == "plugin"
    assert (home / ".hammerspoon/local.lua").read_text() == "return {}"
    assert "already linked" in run()
    assert len(list(manifest.parent.parent.iterdir())) == 1

    # Restoration is all-or-nothing when a destination has been replaced by hand.
    changed = home / ".zshrc"
    changed.unlink()
    changed.write_text("user edit")
    run("--restore", str(manifest), success=False)
    assert (home / ".hammerspoon").is_symlink()
    assert changed.read_text() == "user edit"
    changed.unlink()
    changed.symlink_to(repo / "packages" / links[".zshrc"])
    run("--restore", str(manifest), "--dry-run")
    assert changed.is_symlink()
    run("--restore", str(manifest))
    for target in links:
        path = home / target
        if target in directories:
            assert (path / "config").read_text() == "old"
            assert (path / ".git/HEAD").read_text() == "original history"
        elif target == ".zprofile":
            assert path.is_symlink() and path.resolve() == old_profile
        else:
            assert not path.is_symlink() and path.read_text() == "old"
    assert (home / ".config/tmux/plugins/tpm/tpm").read_text() == "plugin"
    assert (home / ".hammerspoon/local.lua").read_text() == "return {}"

print("PASS: dry run, migration, private backup, local settings, idempotency, restore protection, restoration")
