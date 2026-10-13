import struct
import tempfile
from pathlib import Path
from write_update_manifest import manifest

with tempfile.TemporaryDirectory() as directory:
    binary = Path(directory) / "Hullwatch.exe"
    binary.write_bytes(b"MZ" + b"\0" * 64 + b"GDPC" + struct.pack("<Q4s", 4, b"GDPC"))
    result = manifest(binary, "v0.12.0-playtest.20261013.4", "windows", "a" * 40)
    assert result["payload"]["size"] == binary.stat().st_size
    assert result["payload"]["url"].endswith("/v0.12.0-playtest.20261013.4/Hullwatch.exe")
    for tag, channel in [("vnext", "windows"), ("v0.12.0-steamdeck-playtest.20261013.4", "windows"), ("v0.12.0-playtest.20261013.4", "steamdeck")]:
        try:
            manifest(binary, tag, channel, "a" * 40)
        except ValueError:
            pass
        else:
            raise AssertionError("Accepted invalid channel/tag")
    binary.write_bytes(b"MZbad")
    try:
        manifest(binary, "v0.12.0", "windows", "a" * 40)
    except ValueError:
        pass
    else:
        raise AssertionError("Accepted missing embedded pack")
print("PASS: update_manifest")
