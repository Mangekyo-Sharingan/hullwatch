#!/usr/bin/env python3
"""Build a native Linux playtest package with Godot and Python's standard library."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2.stable"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default=os.environ.get("GODOT_BIN", str(ROOT / "Engine/Godot_v4.7.2-stable_linux.x86_64")))
    args = parser.parse_args()
    engine = Path(args.engine).expanduser().resolve()
    if not engine.is_file() or not os.access(engine, os.X_OK):
        parser.error("Use --engine /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64")
    version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    if not version.startswith(VERSION + "."):
        parser.error(f"Expected {VERSION} editor and matching export templates; got {version}")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=normal", "--", "game", "tools/build_steam_deck.py", "tools/steam_deck_launcher.sh", "tools/test_steam_deck_package.py", "docs/STEAM_DECK_PLAYTEST.md"], cwd=ROOT, text=True)
    output = ROOT / "build/steamdeck"
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".export-", dir=output) as staging:
        userdata = Path(staging) / "userdata"
        (userdata / "godot").mkdir(parents=True)
        data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
        templates = data_home / "godot/export_templates"
        if not (templates / VERSION / "linux_release.x86_64").is_file():
            parser.error(f"Missing matching Linux export template beneath {templates}")
        (userdata / "godot/export_templates").symlink_to(templates.resolve(), target_is_directory=True)
        engine_env = dict(os.environ, XDG_DATA_HOME=str(userdata))
        package = Path(staging) / "Hullwatch-SteamDeck"
        package.mkdir()
        binary = package / "Hullwatch.x86_64"
        for options in (["--import"], ["--export-release", "Linux Steam Deck", str(binary)]):
            subprocess.run([str(engine), "--headless", "--path", str(ROOT / "game"), *options], cwd=ROOT, env=engine_env, check=True)
        if binary.read_bytes()[:5] != b"\x7fELF\x02":
            raise RuntimeError("Export is not a 64-bit Linux ELF")
        binary.chmod(0o755)
        launcher = package / "Hullwatch.sh"
        shutil.copyfile(ROOT / "tools/steam_deck_launcher.sh", launcher)
        launcher.chmod(0o755)
        shutil.copyfile(ROOT / "docs/STEAM_DECK_PLAYTEST.md", package / "README.md")
        (package / "SOURCE_COMMIT").write_text(commit + "\n")
        (package / "BUILD_INFO.json").write_text(json.dumps({"engine": version, "source_commit": commit, "source_status": dirty.splitlines(), "save_version": 8, "profile": "1280x800/mobile/30fps; Steam Input keyboard+mouse; hardware pending"}, indent=2) + "\n")
        for path in package.iterdir():
            if path not in (binary, launcher):
                path.chmod(0o644)
        sums = "".join(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n" for path in sorted(package.iterdir()))
        (package / "SHA256SUMS").write_text(sums)
        (package / "SHA256SUMS").chmod(0o644)
        archive = Path(staging) / "Hullwatch-SteamDeck.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname=package.name)
        subprocess.run(["python3", str(ROOT / "tools/test_steam_deck_package.py"), str(archive)], cwd=ROOT, check=True)
        destination = output / package.name
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(str(package), destination)
        os.replace(archive, output / archive.name)
        final_archive = output / archive.name
        (output / "SHA256SUMS").write_text(f"{hashlib.sha256(final_archive.read_bytes()).hexdigest()}  {archive.name}\n")
    print(f"Built: {final_archive}")
    if dirty:
        print("Working-tree build: SOURCE_COMMIT is the base; BUILD_INFO.json lists uncommitted paths. Rebuild after commit for delivery.")


if __name__ == "__main__":
    main()
