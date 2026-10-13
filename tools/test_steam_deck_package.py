#!/usr/bin/env python3
"""Check package identity, executable permissions, checksums, and launcher forwarding."""
import hashlib
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile


def check(archive):
    with tarfile.open(archive) as tar:
        members = tar.getmembers()
        assert all(m.isfile() or m.isdir() for m in members), "Unexpected links/devices"
        assert all(Path(m.name).parts[0] == "Hullwatch-SteamDeck" and ".." not in Path(m.name).parts for m in members), "Unsafe archive paths"
        files = {m.name.split("/", 1)[1]: tar.extractfile(m).read() for m in members if m.isfile()}
        modes = {m.name.split("/", 1)[1]: m.mode for m in members if m.isfile()}
        required = {"Hullwatch.x86_64", "Hullwatch.sh", "README.md", "SOURCE_COMMIT", "BUILD_INFO.json", "SHA256SUMS"}
        assert required <= files.keys(), "Missing required package file"
        assert files["Hullwatch.x86_64"][:5] == b"\x7fELF\x02", "Not ELF64"
        assert files["Hullwatch.x86_64"][18:20] == b"\x3e\x00", "Not x86_64"
        assert all(modes[name] & 0o111 == 0o111 for name in ("Hullwatch.x86_64", "Hullwatch.sh")), "Execute bits lost"
        listed = set()
        for line in files["SHA256SUMS"].decode().splitlines():
            digest, name = line.split("  ", 1)
            assert hashlib.sha256(files[name]).hexdigest() == digest, name
            listed.add(name)
        assert listed == files.keys() - {"SHA256SUMS"}, "Incomplete manifest"
    with tempfile.TemporaryDirectory(prefix="hullwatch launcher ") as directory:
        folder = Path(directory)
        launcher = folder / "Hullwatch.sh"
        launcher.write_bytes(files["Hullwatch.sh"])
        binary = folder / "Hullwatch.x86_64"
        binary.write_text('#!/bin/sh\npwd\nprintf "%s\\n" "$@"\n')
        binary.chmod(0o755)
        result = subprocess.check_output(["sh", str(launcher), "--windowed", "argument with spaces"], cwd="/", text=True).splitlines()
        assert result == [str(folder), "--resolution", "1280x800", "--fullscreen", "--rendering-method", "mobile", "--max-fps", "30", "--windowed", "argument with spaces"], result
    print("PASS: steam_deck_package (ELF64 x86_64, modes, hashes, launcher relocation/arguments)")


if __name__ == "__main__":
    check(Path(sys.argv[1]))
