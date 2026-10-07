#!/usr/bin/env python3
"""Link configs, back up existing destinations, and support explicit restoration."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import sys
import uuid

REPO = Path(__file__).resolve().parents[1]
LINKS = {
    ".zshrc": "zsh/.zshrc",
    ".zprofile": "zsh/.zprofile",
    ".zshenv": "zsh/.zshenv",
    ".p10k.zsh": "zsh/.p10k.zsh",
    ".gitconfig": "git/.gitconfig",
    ".gitconfig-daniel-viklund": "git/.gitconfig-daniel-viklund",
    ".gitconfig-gdmdavi": "git/.gitconfig-gdmdavi",
    ".config/git/ignore": "git/.config/git/ignore",
    ".config/nvim-scratch": "neovim/.config/nvim-scratch",
    ".config/tmux": "tmux/.config/tmux",
    ".config/wezterm": "wezterm/.config/wezterm",
    ".hammerspoon": "hammerspoon/.hammerspoon",
}
# Keep installed plugins and local overrides when replacing whole directories.
LOCAL_ITEMS = {
    ".config/tmux": ["plugins"],
    ".hammerspoon": ["local.lua", "Spoons"],
    ".config/nvim-scratch": ["windows-path.txt"],
}


def exists(path):
    return os.path.lexists(path)


def linked_to(path, source):
    return path.is_symlink() and path.resolve() == source.resolve()


def restore(manifest_path, dry_run):
    data = json.loads(manifest_path.read_text())
    home = Path(data["home"])
    backup = manifest_path.parent
    # Check every destination before changing anything.
    for record in data["links"]:
        destination = home / record["path"]
        if not linked_to(destination, Path(record["source"])):
            raise RuntimeError(f"Refusing to replace a changed destination: {destination}")
        if record["backed_up"] and not exists(backup / record["path"]):
            raise RuntimeError(f"Backup is missing: {record['path']}")
    for record in reversed(data["links"]):
        destination = home / record["path"]
        print(f"Restore {destination}")
        if not dry_run:
            destination.unlink()
            if record["backed_up"]:
                (backup / record["path"]).rename(destination)
    if not dry_run:
        data["restored"] = True
        manifest_path.write_text(json.dumps(data, indent=2) + "\n")


def install(home, dry_run):
    pending = []
    for relative, package in LINKS.items():
        source = REPO / "packages" / package
        if not source.exists():
            raise RuntimeError(f"Missing source: {source}")
        destination = home / relative
        if not linked_to(destination, source):
            pending.append((relative, source, destination))
    if not pending:
        print("All configs are already linked.")
        return
    for relative, source, destination in pending:
        action = "Back up and link" if exists(destination) else "Link"
        print(f"{action}: {destination} -> {source}")
    if dry_run:
        return

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    backup = home / ".local/state/dotfiles/backups" / stamp
    backup.mkdir(parents=True, mode=0o700)
    backup.chmod(0o700)
    manifest = backup / "manifest.json"
    data = {"home": str(home), "repo": str(REPO), "links": []}
    manifest.write_text(json.dumps(data, indent=2) + "\n")
    try:
        for relative, source, destination in pending:
            # These paths are ignored by Git; installed plugins need no download.
            for local in LOCAL_ITEMS.get(relative, []):
                old, new = destination / local, source / local
                if exists(old) and not exists(new):
                    if old.is_dir():
                        shutil.copytree(old, new, symlinks=True)
                    else:
                        shutil.copy2(old, new)
                        if local == "local.lua":
                            new.chmod(0o600)
            destination.parent.mkdir(parents=True, exist_ok=True)
            had_original = exists(destination)
            saved = backup / relative
            if had_original:
                saved.parent.mkdir(parents=True, exist_ok=True)
                destination.rename(saved)
            try:
                destination.symlink_to(source, target_is_directory=source.is_dir())
            except BaseException:
                if had_original:
                    saved.rename(destination)
                raise
            data["links"].append({"path": relative, "source": str(source), "backed_up": had_original})
            manifest.write_text(json.dumps(data, indent=2) + "\n")
    except BaseException:
        # Roll back completed links if installation fails midway.
        restore(manifest, False)
        raise
    print(f"Backup and restore manifest: {manifest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--target", type=Path, default=Path.home(), help="Target home directory")
    parser.add_argument("--restore", type=Path, metavar="MANIFEST", help="Restore a previous installation")
    args = parser.parse_args()
    if args.restore:
        restore(args.restore.expanduser().resolve(), args.dry_run)
    else:
        install(args.target.expanduser().resolve(), args.dry_run)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
