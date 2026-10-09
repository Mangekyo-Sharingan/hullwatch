#!/usr/bin/env python3
"""Refresh after a configured finalizer; also usable directly or from Git."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def project_root(payload: dict) -> Path:
    if payload.get("cwd"):
        cwd = Path(payload["cwd"]).resolve()
        for candidate in (cwd, *cwd.parents):
            if (candidate / "tools/dashboard_hook.py").is_file():
                return candidate
    return Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--after", help="existing trusted hook command, run with original stdin")
    parser.add_argument("--git", action="store_true", help="Git invocation: do not read stdin")
    args = parser.parse_args()
    if os.environ.get("HULLWATCH_DASHBOARD_ACTIVE") == "1":
        return 0
    raw = "" if args.git or sys.stdin.isatty() else sys.stdin.read()
    payload = json.loads(raw or "{}")
    if not isinstance(payload, dict):
        raise ValueError("hook input must be a JSON object")
    root = project_root(payload)
    prior = 0
    if args.after:
        # Keep the original shell command intact, including its quoting and stdin.
        prior = subprocess.run(args.after, shell=True, input=raw, text=True, cwd=root).returncode
        if prior:
            print(f"Hullwatch dashboard: finalizer failed (exit {prior})", file=sys.stderr)
    if payload.get("stop_hook_active"):
        return prior
    builder = root / "tools/build_dashboard.py"
    if not builder.is_file():
        print(f"Hullwatch dashboard: missing generator: {builder}", file=sys.stderr)
        return prior or 1
    env = dict(os.environ, HULLWATCH_DASHBOARD_ACTIVE="1")
    result = subprocess.run([sys.executable, str(builder), "--quiet"], cwd=root, env=env).returncode
    if result:
        print(f"Hullwatch dashboard: generator failed (exit {result})", file=sys.stderr)
    return prior or result


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Hullwatch dashboard: {error}", file=sys.stderr)
        sys.exit(1)
