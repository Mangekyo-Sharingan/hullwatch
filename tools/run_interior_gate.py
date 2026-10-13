#!/usr/bin/env python3
"""Run geometry checks, capture the entire interior, then require a current visual review."""
import argparse
import datetime
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SUITES = (
    "test_interior_gate", "test_walkway_clearance", "test_world_layout",
    "test_hull_exterior", "test_player_traversal", "test_module_scene",
    "test_door", "test_hero_cabins", "test_machine_fitting",
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_digest():
    checksum = hashlib.sha256()
    for path in sorted((ROOT / "game").rglob("*")):
        if path.is_file() and ".godot" not in path.parts:
            checksum.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
            checksum.update(path.read_bytes())
    checksum.update(Path(__file__).read_bytes())
    return checksum.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def check_review(output):
    report = json.loads((output / "results.json").read_text())
    report["gate_passed"] = False
    report["visual_review"] = "pending_or_failed"
    write_json(output / "results.json", report)
    review = json.loads((output / "review.json").read_text())
    manifest = json.loads((output / "captures" / "manifest.json").read_text())
    errors = []
    if not report["checks_passed"] or report["source_sha256"] != source_digest():
        errors.append("Failed checks or source changed since capture")
    if review.get("packet_sha256") != report["packet_sha256"]:
        errors.append("Review refers to a different capture packet")
    current_packet = hashlib.sha256((report["source_sha256"] + json.dumps(manifest, sort_keys=True)).encode()).hexdigest()
    if current_packet != report["packet_sha256"]:
        errors.append("Capture manifest changed since the recorded run")
    for view in manifest["views"]:
        path = output / "captures" / view["file"]
        if not path.is_file() or digest(path) != view["sha256"]:
            errors.append("Missing or changed capture: " + view["file"])
    areas = {view["area"] for view in manifest["views"]}
    reviewed = review.get("areas", [])
    if len(reviewed) != len(areas) or {area.get("id") for area in reviewed} != areas:
        errors.append("Visual review must cover every captured area exactly once")
    reviewer = review.get("reviewer")
    if not isinstance(reviewer, str) or not reviewer.strip() or any(area.get("decision") != "pass" or not isinstance(area.get("notes"), str) or not area["notes"].strip() for area in reviewed):
        errors.append("Visual review is incomplete or contains failures")
    report["visual_review"] = "pass" if not errors else "pending_or_failed"
    report["gate_passed"] = not errors
    report["review_errors"] = errors
    write_json(output / "results.json", report)
    print("PASS: interior_gate (automated checks + recorded visual review)" if not errors else "REVIEW REQUIRED: " + "; ".join(errors))
    return 0 if not errors else 2


def run_command(engine, arguments, output, name, expected, timeout=180):
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = str(output / "userdata" / name)
    if os.name == "nt":
        env["APPDATA"] = str(output / "userdata" / name)
    try:
        completed = subprocess.run(
            [str(engine), "--path", str(ROOT / "game"), *arguments],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout,
        )
        log = completed.stdout + completed.stderr
        resource_errors = ("Failed loading resource", "Error loading", "Cannot open file", "Failed to load", "referenced non-existent resource")
        ok = completed.returncode == 0 and "SCRIPT ERROR" not in log and "Parse Error" not in log and not any(message in log for message in resource_errors)
        if expected:
            ending = r" \(\d+ views\)\s*$" if expected == "capture_interior_gate" else r"\s*$"
            ok = ok and bool(re.search(r"^PASS: " + re.escape(expected) + ending, log, re.M))
        ok = ok and not re.search(r"^(?:ERROR: )?FAIL:", log, re.M)
        result = {"check": name, "exit": completed.returncode, "passed": ok}
    except subprocess.TimeoutExpired as error:
        log = str(error.stdout or "") + str(error.stderr or "")
        result = {"check": name, "exit": "timeout", "passed": False}
    (output / (name + ".log")).write_text(log, encoding="utf-8")
    print(name + (": PASS" if result["passed"] else ": FAIL"), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--checks-only", action="store_true", help="Headless checks only; does not close the visual gate")
    parser.add_argument("--check-review", action="store_true", help="Validate an existing packet and its completed review.json")
    parser.add_argument("--display-driver", help="Use wayland on this Linux host; omit on Windows")
    args = parser.parse_args()
    if args.check_review and not args.output:
        parser.error("--check-review requires --output")
    output = (args.output or ROOT / "build" / "interior_gate" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S")).resolve()
    if args.check_review:
        return check_review(output)
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        parser.error("Use an empty output directory to preserve previous evidence")
    output.mkdir(parents=True, exist_ok=True)
    engine = (args.engine or ROOT / "Engine" / ("Godot_v4.7.2-stable_win64_console.exe" if os.name == "nt" else "Godot_v4.7.2-stable_linux.x86_64")).resolve()
    results = [run_command(engine, ["--headless", "--import"], output, "import", None)]
    source = source_digest()
    if results[0]["passed"]:
        results.append(run_command(engine, ["--headless", "--quit"], output, "startup", None))
        for suite in SUITES:
            results.append(run_command(engine, ["--headless", "--script", "res://tests/" + suite + ".gd"], output, suite, suite))
    report = {
        "recorded_at": datetime.datetime.now().astimezone().isoformat(),
        "source_sha256": source, "checks": results, "checks_passed": all(r["passed"] for r in results),
        "visual_review": "not_run", "gate_passed": False,
        "scope": "Physical/visual interior only; does not replace native Windows or human gameplay acceptance",
    }
    if not args.checks_only and report["checks_passed"]:
        captures = output / "captures"
        command = ["--resolution", "1600x900", "--script", "res://tools/capture_interior_gate.gd", "--", "--output=" + str(captures)]
        if args.display_driver:
            command[0:0] = ["--display-driver", args.display_driver]
        capture = run_command(engine, command, output, "capture", "capture_interior_gate", 180)
        results.append(capture)
        report["checks_passed"] = report["checks_passed"] and capture["passed"]
        if capture["passed"]:
            manifest = json.loads((captures / "manifest.json").read_text())
            for view in manifest["views"]:
                view["sha256"] = digest(captures / view["file"])
            write_json(captures / "manifest.json", manifest)
            report["packet_sha256"] = hashlib.sha256((source + json.dumps(manifest, sort_keys=True)).encode()).hexdigest()
            areas = sorted({view["area"] for view in manifest["views"]})
            report["areas"] = areas
            report["captures"] = len(manifest["views"])
            report["visual_review"] = "pending"
            write_json(output / "review.json", {"packet_sha256": report["packet_sha256"], "reviewer": "", "areas": [{"id": area, "decision": "pending", "notes": ""} for area in areas]})
            gallery = "<!doctype html><meta charset=utf-8><title>Hullwatch interior gate</title><style>body{background:#171a1d;color:#eee;font:16px system-ui;margin:24px}section{break-after:page}figure{display:inline-block;width:46%;margin:1%}img{width:100%}a{color:#9de}</style><h1>Interior gate — visual review</h1><p>Inspect every area for projecting sheets, exposed edges, clipping, blocked approaches and mismatched wall/collision geometry. Record findings in review.json.</p>"
            for area in areas:
                gallery += "<section id='" + html.escape(area) + "'><h2>" + html.escape(area) + "</h2>"
                for view in manifest["views"]:
                    if view["area"] == area:
                        name = html.escape(view["file"])
                        gallery += f"<figure><a href='captures/{name}'><img loading='lazy' src='captures/{name}'></a><figcaption>{html.escape(view['view'])}</figcaption></figure>"
                gallery += "</section>"
            (output / "index.html").write_text(gallery, encoding="utf-8")
    if source != source_digest():
        report["checks_passed"] = False
        report["source_changed_during_run"] = True
    write_json(output / "results.json", report)
    print("Evidence: " + str(output), flush=True)
    if not report["checks_passed"]:
        return 1
    if args.checks_only:
        print("PASS: interior_gate_checks (visual gate remains open)")
        return 0
    print("REVIEW REQUIRED: inspect index.html, complete review.json, then use --check-review")
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        print("Interior gate error: " + str(error), file=sys.stderr)
        sys.exit(1)
