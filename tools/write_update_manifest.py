"""Generate the platform manifest after exporting the final embedded executable."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

REPOSITORY = "https://github.com/Mangekyo-Sharingan/hullwatch/releases/download/"


def manifest(binary, tag, channel, commit):
    suffix = "steamdeck-playtest" if channel == "steamdeck" else "playtest"
    if channel not in ("windows", "steamdeck") or not re.fullmatch(r"v\d{1,6}\.\d{1,6}\.\d{1,6}(?:-" + suffix + r"\.\d{8}\.\d{1,6})?", tag):
        raise ValueError("Release tag/channel mismatch")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected full source commit")
    data = binary.read_bytes()
    if not 12 < len(data) <= 1024 ** 3:
        raise ValueError("Payload outside supported size")
    if channel == "windows" and data[:2] != b"MZ":
        raise ValueError("Not a Windows executable")
    if channel == "steamdeck" and (data[:5] != b"\x7fELF\x02" or data[18:20] != b"\x3e\x00"):
        raise ValueError("Not an ELF64 x86_64 executable")
    pack_size, magic = struct.unpack("<Q4s", data[-12:])
    if magic != b"GDPC" or pack_size > len(data) - 12 or data[len(data) - 12 - pack_size:][:4] != b"GDPC":
        raise ValueError("Missing embedded Godot pack")
    name = "Hullwatch.x86_64" if channel == "steamdeck" else "Hullwatch.exe"
    return {"schema_version": 1, "minimum_updater": 1, "release_tag": tag,
            "channel": channel, "source_commit": commit,
            "payload": {"name": name, "url": REPOSITORY + tag + "/" + name,
                        "size": len(data), "sha256": hashlib.sha256(data).hexdigest()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--release-tag", required=True)
    parser.add_argument("--channel", choices=("windows", "steamdeck"), required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = manifest(args.binary, args.release_tag, args.channel, args.source_commit)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("Generated:", args.output)


if __name__ == "__main__":
    main()
