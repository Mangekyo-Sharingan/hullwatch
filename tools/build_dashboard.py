#!/usr/bin/env python3
"""Build Hullwatch's offline documentation dashboard from repository sources."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "docs/dashboard"
OUTPUT = DASHBOARD / "index.html"
TEXT_TYPES = {".md", ".txt", ".json"}
IMAGE_TYPES = {".png", ".jpg", ".jpeg", ".webp", ".svg"}


def git(*args: str) -> str:
    result = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def category(path: str) -> str:
    if path.startswith(".wolf/"):
        return "Project context"
    if path.startswith("game/src/data/"):
        return "Game data"
    if "art_pass/steps/" in path:
        return "Art pass"
    if "art_pass/" in path:
        return "Art direction"
    if path.startswith("docs/design/"):
        return "Design passes"
    if "release" in path:
        return "Releases"
    if "dashboard/" in path:
        return "Dashboard"
    if path in {"README.md", "docs/PRODUCTION_SPEC.md", "docs/EXPANSION_SPEC.md"}:
        return "Specifications"
    return "Production"


def collect(site_dir: Path | None = None) -> dict:
    sources = {p for p in (ROOT / "docs").rglob("*") if p.is_file() and p.suffix in TEXT_TYPES
               and "vendor" not in p.parts and p.name != "index.html"}
    sources.update(p for p in ROOT.glob("*.md"))
    sources.update(p for p in (ROOT / "releases").rglob("*.md"))
    sources.update(p for p in (ROOT / "game/src/data").rglob("*.tres"))
    for name in ("STATUS.md", "cerebrum.md", "memory.md", "anatomy.md", "OPENWOLF.md", "buglog.json"):
        path = ROOT / ".wolf" / name
        if path.exists():
            sources.add(path)
    documents = []
    for path in sorted(sources):
        if path.is_symlink():
            continue
        rel = path.relative_to(ROOT).as_posix()
        content = path.read_text(encoding="utf-8")
        title = re.search(r"^#\s+(.+)$", content, re.M)
        documents.append({"path": rel, "title": title.group(1).strip() if title else path.stem.replace("_", " "),
                          "category": category(rel), "content": content, "format": path.suffix[1:],
                          "modified": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
                          "bytes": path.stat().st_size})
    media = []
    for path in sorted((ROOT / "docs").rglob("*")):
        if not path.is_file() or path.is_symlink() or path.suffix.lower() not in IMAGE_TYPES:
            continue
        rel = path.relative_to(ROOT).as_posix()
        url = "assets/" + rel if site_dir else os.path.relpath(path, DASHBOARD).replace(os.sep, "/")
        media.append({"path": rel, "url": url, "title": path.stem.replace("_", " "),
                      "group": path.parent.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size,
                      "modified": path.stat().st_mtime_ns})
    roadmap = json.loads((DASHBOARD / "roadmap.json").read_text(encoding="utf-8"))
    valid_status = {"complete", "in_progress", "needs_review", "planned", "blocked"}
    for item in roadmap["milestones"] + roadmap["gates"]:
        if item["status"] not in valid_status:
            raise ValueError(f"Invalid roadmap status: {item['id']}")
        for child in [item, *item.get("tasks", [])]:
            if child["status"] not in valid_status:
                raise ValueError(f"Invalid task status: {child['title']}")
            for evidence in child.get("evidence", []):
                source = (ROOT / evidence["path"]).resolve()
                if not source.is_relative_to(ROOT) or not source.is_file():
                    raise ValueError(f"Missing roadmap evidence: {evidence['path']}")
    commits = []
    for line in git("log", "-12", "--format=%h%x09%cI%x09%s").splitlines():
        fields = line.split("\t", 2)
        if len(fields) == 3:
            commits.append(dict(zip(("hash", "date", "subject"), fields)))
    changes = [line for line in git("status", "--short").splitlines() if not line.endswith("docs/dashboard/index.html")]
    tests = sorted(p.name for p in (ROOT / "game/tests").glob("*.gd"))
    systems = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "game/src/systems").glob("*.gd"))
    return {"documents": documents, "media": media, "roadmap": roadmap,
            "repository": {"branch": git("branch", "--show-current"), "head": git("rev-parse", "--short", "HEAD"),
                           "commits": commits, "changes": changes},
            "inventory": {"tests": tests, "systems": systems,
                          "resources": sum(d["category"] == "Game data" for d in documents)},
            "mode": "export" if site_dir else "local"}


def build(quiet: bool = False, check: bool = False, site_dir: Path | None = None) -> bool:
    template = (DASHBOARD / "template.html").read_text(encoding="utf-8")
    vendor = (DASHBOARD / "vendor/marked.umd.js").read_text(encoding="utf-8")
    vendor = re.sub(r"//# sourceMappingURL=.*", "", vendor)
    data = collect(site_dir)
    payload = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    fingerprint = hashlib.sha256((template + vendor + payload).encode()).hexdigest()
    output = site_dir / "index.html" if site_dir else OUTPUT
    old = output.read_text(encoding="utf-8") if output.exists() else ""
    old_match = re.search(r'<script id="dashboard-data" type="application/json">(.*?)</script>', old, re.S)
    try:
        previous = json.loads(old_match.group(1)) if old_match else {}
    except (json.JSONDecodeError, AttributeError):
        previous = {}
    data["source_hash"] = fingerprint
    data["generated_at"] = (previous["generated_at"] if previous.get("source_hash") == fingerprint
                            else datetime.now(timezone.utc).isoformat(timespec="seconds"))
    embedded = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")
    html = template.replace("__MARKED_JS__", vendor).replace("__DASHBOARD_DATA__", embedded)
    changed = old != html
    if check:
        if changed:
            raise ValueError("Dashboard is stale or missing. Run python3 tools/build_dashboard.py")
    elif changed:
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent, suffix=".tmp", delete=False) as file:
            file.write(html)
            temporary = file.name
        os.chmod(temporary, 0o644)
        os.replace(temporary, output)
    if site_dir and not check:
        for asset in data["media"]:
            destination = site_dir / asset["url"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            source = ROOT / asset["path"]
            if not destination.exists() or destination.stat().st_mtime_ns != source.stat().st_mtime_ns:
                shutil.copy2(source, destination)
    if not quiet:
        state = "verified" if check else "updated" if changed else "unchanged"
        print(f"Dashboard {state}: {len(data['documents'])} documents, {len(data['media'])} images, "
              f"{len(data['roadmap']['milestones'])} milestones → {output}")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--check", action="store_true", help="Fail if the generated dashboard is stale")
    parser.add_argument("--watch", action="store_true", help="Refresh when documentation or roadmap sources change")
    parser.add_argument("--site-dir", type=Path, help="Export a portable site with its screenshot/diagram assets")
    args = parser.parse_args()
    if args.check and args.watch:
        parser.error("--check and --watch cannot be combined")
    if args.site_dir:
        args.site_dir = args.site_dir.resolve()
        if args.site_dir in {ROOT, ROOT / "docs", DASHBOARD}:
            parser.error("Choose a separate export directory, for example build/dashboard")
    try:
        while True:
            build(args.quiet, args.check, args.site_dir)
            if not args.watch:
                return 0
            time.sleep(2)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError, KeyError) as error:
        print(f"Dashboard error: {error}", file=__import__("sys").stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
