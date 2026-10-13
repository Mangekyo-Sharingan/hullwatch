"""Small stdlib regression for the gate's failure and stale-review rules."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

import run_interior_gate as gate


def main():
    with tempfile.TemporaryDirectory() as folder:
        output = Path(folder)
        (output / "captures").mkdir()
        image = output / "captures" / "view.png"
        image.write_bytes(b"synthetic validator fixture")
        manifest = {"views": [{"area": "cabin", "file": "view.png", "sha256": gate.digest(image)}]}
        packet = hashlib.sha256(("source" + json.dumps(manifest, sort_keys=True)).encode()).hexdigest()
        report = {"checks_passed": True, "source_sha256": "source", "packet_sha256": packet, "gate_passed": True}
        review = {"packet_sha256": packet, "reviewer": "Validator fixture", "areas": [{"id": "cabin", "decision": "pass", "notes": "Synthetic acceptance tests receipt mechanics only"}]}

        def reset():
            gate.write_json(output / "results.json", report)
            gate.write_json(output / "review.json", review)
            gate.write_json(output / "captures" / "manifest.json", manifest)

        with patch.object(gate, "source_digest", return_value="source"):
            reset()
            assert gate.check_review(output) == 0
            for field in ["reviewer", "notes"]:
                for value in [None, "", "   ", 42]:
                    reset()
                    changed = json.loads(json.dumps(review))
                    if field == "reviewer":
                        changed[field] = value
                    else:
                        changed["areas"][0][field] = value
                    gate.write_json(output / "review.json", changed)
                    assert gate.check_review(output) == 2
                    assert not json.loads((output / "results.json").read_text())["gate_passed"]
            reset()
            with patch.object(gate, "source_digest", return_value="changed"):
                assert gate.check_review(output) == 2
            reset()
            image.write_bytes(b"changed screenshot")
            assert gate.check_review(output) == 2
            reset()
            (output / "review.json").write_text("{")
            try:
                gate.check_review(output)
                raise AssertionError("Malformed review accepted")
            except ValueError:
                assert not json.loads((output / "results.json").read_text())["gate_passed"]

        for log in ["PASS: suite_extra\n", "PASS: suite\nERROR: Failed loading resource: missing.glb\n", "PASS: suite\nSCRIPT ERROR: broken\n", "PASS: suite\nFAIL: obstruction\n"]:
            with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, log, "")):
                assert not gate.run_command(Path("engine"), [], output, "suite", "suite")["passed"]
        with patch.object(subprocess, "run", side_effect=subprocess.TimeoutExpired([], 1)):
            assert not gate.run_command(Path("engine"), [], output, "suite", "suite")["passed"]
    print("PASS: test_interior_gate_runner")


if __name__ == "__main__":
    main()
