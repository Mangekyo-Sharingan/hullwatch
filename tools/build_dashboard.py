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
GRAPH_HTML = ROOT / "graphify-out/graph.html"
GRAPH_JSON = ROOT / "graphify-out/graph.json"
VIS_NETWORK = DASHBOARD / "vendor/vis-network-9.1.6.min.js"
VIS_NETWORK_TAG = re.compile(
    r'<script src="https://unpkg\.com/vis-network@9\.1\.6/standalone/umd/vis-network\.min\.js"[^>]*></script>')


def git(*args: str) -> str:
    result = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, suffix=".tmp", delete=False) as file:
        file.write(text)
        temporary = file.name
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


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


MILESTONE_ID = re.compile(r"(?!GATE_|STAGE_)[A-Z][A-Z0-9_]*")
GATE_ID = re.compile(r"GATE_[A-Z0-9_]+")
STAGE_ID = re.compile(r"STAGE_[A-Z0-9_]+")


def validate_ids(roadmap: dict) -> None:
    """Every roadmap entity carries a permanent, globally unique ID that agents can grep for."""
    seen: set[str] = set()

    def claim(identifier: object, pattern: re.Pattern[str], kind: str) -> None:
        if not isinstance(identifier, str) or not pattern.fullmatch(identifier):
            raise ValueError(f"Invalid {kind} id: {identifier!r}")
        if identifier in seen:
            raise ValueError(f"Duplicate roadmap id: {identifier}")
        seen.add(identifier)

    for stage in roadmap.get("release_path", {}).get("stages", []):
        claim(stage.get("id"), STAGE_ID, "stage")
    for gate in roadmap["gates"]:
        claim(gate.get("id"), GATE_ID, "gate")
    for milestone in roadmap["milestones"]:
        claim(milestone.get("id"), MILESTONE_ID, "milestone")
        task_id = re.compile(re.escape(milestone["id"]) + r"\.[1-9][0-9]*")
        for task in milestone.get("tasks", []):
            claim(task.get("id"), task_id, f"{milestone['id']} task")


PROOF_TYPES = {".png", ".jpg", ".jpeg", ".webp", ".mp4", ".webm"}
ACTIVE = {"in_progress", "needs_review"}


def validate_plan(roadmap: dict) -> None:
    """Enforce the operator's EA plan: ordered slices, bounded WIP, player-visible proof, no orphan work."""
    plan = roadmap["ea_plan"]
    milestones = {item["id"]: item for item in roadmap["milestones"]}
    gate_ids = {item["id"] for item in roadmap["gates"]}
    slices, later = plan["slices"], plan["later"]
    if len(set(slices)) != len(slices) or not set(slices) <= milestones.keys() or later not in milestones:
        raise ValueError("Invalid EA plan slice references")
    active = [sid for sid in slices if milestones[sid]["status"] in ACTIVE]
    if len(active) > plan["wip_limit"]:
        raise ValueError(f"More than {plan['wip_limit']} active EA slice: {', '.join(active)}")
    unfinished = None
    for sid in slices:
        item = milestones[sid]
        if not item.get("player_outcome") or not item.get("proof"):
            raise ValueError(f"EA slice {sid} needs a player_outcome and proof")
        if unfinished and item["status"] not in ("planned", "blocked"):
            raise ValueError(f"EA slice {sid} started before {unfinished} was accepted")
        if item["status"] not in ("complete", "blocked"):
            unfinished = unfinished or sid
        if item["status"] == "complete" and not any(
                Path(e["path"]).suffix.lower() in PROOF_TYPES or e["path"].startswith("docs/playtests/")
                for e in item.get("evidence", [])):
            raise ValueError(f"EA slice {sid} is complete without image, video or play-note proof")
    for item in roadmap["milestones"]:
        if item["status"] != "complete" and item["id"] not in (*slices, later) \
                and item.get("absorbed_into") not in (*slices, later):
            raise ValueError(f"Open milestone {item['id']} is not on the EA plan")
    claimed = [gate for sid in slices for gate in milestones[sid].get("gates", [])]
    if not set(claimed) <= gate_ids:
        raise ValueError("EA slice claims an unknown gate")
    for gate in roadmap["gates"]:
        if gate["status"] != "complete" and claimed.count(gate["id"]) != 1:
            raise ValueError(f"Open gate {gate['id']} must belong to exactly one EA slice")



def validate_roadmap(roadmap: dict) -> None:
    validate_ids(roadmap)
    validate_plan(roadmap)
    valid_status = {"complete", "in_progress", "needs_review", "planned", "blocked"}
    milestones = {item["id"] for item in roadmap["milestones"]}
    gates = {item["id"] for item in roadmap["gates"]}
    path = roadmap.get("release_path", {})
    stages = path.get("stages", [])
    stage_ids = {stage["id"] for stage in stages}
    if len(stage_ids) != len(stages) or (stages and path.get("current_stage") not in stage_ids):
        raise ValueError("Invalid release-path stage identity")
    for stage in stages:
        if not set(stage["milestones"]).issubset(milestones) or not set(stage["gates"]).issubset(gates):
            raise ValueError(f"Unknown release-path reference: {stage['id']}")
    checkpoint = roadmap.get("checkpoint", {})
    items = roadmap["milestones"] + roadmap["gates"] + stages
    evidence_items = [checkpoint.get("source", {}), *checkpoint.get("delivered", []), roadmap["ea_plan"]]
    for item in items:
        for child in [item, *item.get("tasks", [])]:
            if child["status"] not in valid_status:
                raise ValueError(f"Invalid roadmap status: {child.get('id', child.get('title'))}")
            evidence_items.append(child)
    for item in evidence_items:
        for evidence in item.get("evidence", []):
            source = (ROOT / evidence["path"]).resolve()
            if not source.is_relative_to(ROOT) or not source.is_file():
                raise ValueError(f"Missing roadmap evidence: {evidence['path']}")


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
    validate_roadmap(roadmap)
    commits = []
    for line in git("log", "-12", "--format=%h%x09%cI%x09%s").splitlines():
        fields = line.split("\t", 2)
        if len(fields) == 3:
            commits.append(dict(zip(("hash", "date", "subject"), fields)))
    changes = [line for line in git("status", "--short").splitlines() if not line.endswith("docs/dashboard/index.html")]
    tests = sorted(p.name for p in (ROOT / "game/tests").glob("*.gd"))
    systems = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "game/src/systems").glob("*.gd"))
    knowledge_graph = {"available": False}
    if GRAPH_HTML.is_file() and GRAPH_JSON.is_file():
        try:
            graph = json.loads(GRAPH_JSON.read_text(encoding="utf-8"))
            nodes = graph.get("nodes", [])
            links = graph.get("links", graph.get("edges", []))
            communities = {n.get("community") for n in nodes if isinstance(n, dict) and n.get("community") is not None}
            knowledge_graph = {"available": True, "url": "knowledge-graph.html",
                               "nodes": len(nodes), "edges": len(links), "communities": len(communities),
                               "built": datetime.fromtimestamp(GRAPH_HTML.stat().st_mtime, timezone.utc).isoformat()}
        except (OSError, json.JSONDecodeError):
            pass
    return {"documents": documents, "media": media, "roadmap": roadmap,
            "repository": {"branch": git("branch", "--show-current"), "head": git("rev-parse", "--short", "HEAD"),
                           "commits": commits, "changes": changes},
            "inventory": {"tests": tests, "systems": systems,
                          "resources": sum(d["category"] == "Game data" for d in documents)},
            "knowledge_graph": knowledge_graph,
            "mode": "export" if site_dir else "local"}


def prepare_graph_page(site_dir: Path | None = None) -> None:
    """Copy graphify's interactive graph into the dashboard with its CDN script inlined."""
    if not GRAPH_HTML.is_file() or not VIS_NETWORK.is_file():
        return
    page = GRAPH_HTML.read_text(encoding="utf-8")
    inlined = VIS_NETWORK_TAG.sub(lambda _: "<script>" + VIS_NETWORK.read_text(encoding="utf-8") + "</script>",
                                  page, count=1)
    if inlined == page:
        print("Dashboard warning: graphify's vis-network tag was not found; knowledge-graph.html left unchanged")
        return
    target = (site_dir / "knowledge-graph.html") if site_dir else (DASHBOARD / "knowledge-graph.html")
    previous = target.read_text(encoding="utf-8") if target.exists() else ""
    if previous != inlined:
        write_atomic(target, inlined)


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
        write_atomic(output, html)
    if not check:
        prepare_graph_page(site_dir)
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
