#!/usr/bin/env python3
"""Idempotently attach dashboard refreshes to existing project end hooks."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess


def hook_command(prior: str | None = None) -> str:
    # Bootstrap from the payload so spaces and a nested agent cwd remain safe.
    extra = repr(["--after", prior] if prior else [])
    code = (
        "import io,json,pathlib,runpy,sys; "
        "raw=sys.stdin.read(); data=json.loads(raw or '{}'); "
        "cwd=pathlib.Path(data.get('cwd') or pathlib.Path.cwd()).resolve(); "
        "root=next(p for p in (cwd,*cwd.parents) if (p/'tools/dashboard_hook.py').is_file()); "
        "script=str(root/'tools/dashboard_hook.py'); sys.stdin=io.StringIO(raw); "
        f"sys.argv=[script]+{extra}; "
        "runpy.run_path(script,run_name='__main__')"
    )
    return "python3 -c " + shlex.quote(code)


def install_agent_hooks(root: Path) -> None:
    for relative in (".claude/settings.json", ".codex/hooks.json"):
        file = root / relative
        data = json.loads(file.read_text()) if file.exists() else {}
        hooks = data.setdefault("hooks", {})
        for event in ("Stop", "SessionEnd"):
            entries = hooks.setdefault(event, [])
            wrapped = False
            for entry in entries:
                for hook in entry.get("hooks", []):
                    command = hook.get("command", "")
                    if "tools/dashboard_hook.py" in command:
                        wrapped = True
                    elif hook.get("type") == "command" and ".wolf/hooks/" in command:
                        hook["command"] = hook_command(command)
                        hook["timeout"] = max(hook.get("timeout", 0), 30)
                        wrapped = True
            if not wrapped:
                entries.append({"matcher": "", "hooks": [{"type": "command", "command": hook_command(), "timeout": 30}]})
        content = json.dumps(data, indent=2) + "\n"
        file.parent.mkdir(parents=True, exist_ok=True)
        if not file.exists() or file.read_text() != content:
            file.write_text(content)


def install_git_hooks(root: Path) -> None:
    hooks = Path(subprocess.check_output(["git", "rev-parse", "--git-path", "hooks"], cwd=root, text=True).strip())
    if not hooks.is_absolute():
        hooks = root / hooks
    hooks.mkdir(parents=True, exist_ok=True)
    for name in ("post-commit", "post-merge", "post-checkout"):
        file = hooks / name
        if file.is_symlink():
            raise ValueError(f"refusing to replace symlink: {file}")
        if file.exists() and "# Hullwatch dashboard hook" in file.read_text():
            continue
        original = file.with_name(name + ".hullwatch-original")
        if original.exists():
            raise ValueError(f"backup already exists: {original}")
        if file.exists():
            file.rename(original)
        prior = f'{shlex.quote(str(original.resolve()))} "$@"\nprior=$?\n' if original.exists() and os.access(original, os.X_OK) else "prior=0\n"
        file.write_text(
            "#!/bin/sh\n# Hullwatch dashboard hook\n" + prior
            + 'root=$(git rev-parse --show-toplevel) || exit $?\n'
            + 'python3 "$root/tools/dashboard_hook.py" --git\nrefresh=$?\n'
            + 'if [ "$prior" -ne 0 ]; then exit "$prior"; fi\nexit "$refresh"\n'
        )
        file.chmod(0o755)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git", action="store_true", help="also wrap local Git hooks; preserves originals")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    install_agent_hooks(root)
    if args.git:
        install_git_hooks(root)
