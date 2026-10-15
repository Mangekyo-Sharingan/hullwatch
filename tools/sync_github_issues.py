#!/usr/bin/env python3
"""Mirror the EA build plan in docs/dashboard/roadmap.json to GitHub, one way.

Each EA slice becomes a milestone titled "<ID> — <title>" and each of its tasks an issue
titled "[<task ID>] <title>". The roadmap stays the source of truth: re-running updates
titles, bodies, labels and open/closed state to match it and never edits roadmap.json.
"""

import argparse
import json
import re
import subprocess
import time

from build_dashboard import DASHBOARD, validate_roadmap

PLAN_LABEL = "ea-plan"
STATUS_LABELS = {"in_progress": "status: in progress", "needs_review": "status: needs review",
                 "blocked": "status: blocked"}
LABEL_COLORS = {PLAN_LABEL: "bb592d", "status: in progress": "3b6577",
                "status: needs review": "a27520", "status: blocked": "a34138"}
TASK_TITLE = re.compile(r"^\[([A-Z][A-Z0-9_]*\.[1-9][0-9]*)\] ")
SLICE_TITLE = re.compile(r"^([A-Z][A-Z0-9_]*) — ")
FOOTER = ("Source of truth: `docs/dashboard/roadmap.json` (dashboard: `#view=roadmap&id={id}`). "
          "Mirrored one way by `tools/sync_github_issues.py`; change the roadmap, then re-run the sync.")


class GitHub:
    def __init__(self, dry_run: bool):
        self.dry_run = dry_run
        self.repo = self._run(["gh", "repo", "view", "--json", "nameWithOwner"])["nameWithOwner"]

    @staticmethod
    def _run(command: list[str], payload: dict | None = None):
        result = subprocess.run(command, input=None if payload is None else json.dumps(payload),
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout) if result.stdout.strip() else None

    def read(self, path: str) -> list[dict]:
        items, page = [], 1
        while True:
            batch = self._run(["gh", "api", f"repos/{self.repo}/{path}{'&' if '?' in path else '?'}per_page=100&page={page}"])
            items += batch
            if len(batch) < 100:
                return items
            page += 1

    def write(self, method: str, path: str, payload: dict, summary: str) -> dict:
        print(("DRY " if self.dry_run else "") + summary)
        if self.dry_run:
            return {"number": 0}
        response = self._run(["gh", "api", "-X", method, f"repos/{self.repo}/{path}", "--input", "-"], payload)
        if method == "POST":
            time.sleep(1.0)  # GitHub's secondary limit on content creation
        return response


def slice_body(item: dict) -> str:
    lines = [f"**Player outcome:** {item['player_outcome']}", "", f"**Proof required:** {item['proof']}"]
    if item.get("out_of_scope"):
        lines += ["", "**Out of scope:**", *[f"- {x}" for x in item["out_of_scope"]]]
    if item.get("gates"):
        lines += ["", "**Closes gates:** " + ", ".join(f"`{g}`" for g in item["gates"])]
    return "\n".join(lines + ["", f"Status: {item['status']}", "", FOOTER.format(id=item["id"])])


def task_body(item: dict, task: dict) -> str:
    lines = [f"Slice: **{item['id']} — {item['title']}** ({item['status']})", f"Task: `{task['id']}` ({task['status']})",
             "", task["title"], "", f"**Slice player outcome:** {item['player_outcome']}"]
    if task.get("evidence"):
        lines += ["", "**Evidence:**", *[f"- {e['label']} (`{e['path']}`)" for e in task["evidence"]]]
    return "\n".join(lines + ["", FOOTER.format(id=task["id"])])


def sync(dry_run: bool) -> None:
    roadmap = json.loads((DASHBOARD / "roadmap.json").read_text(encoding="utf-8"))
    validate_roadmap(roadmap)
    by_id = {item["id"]: item for item in roadmap["milestones"]}
    slices = [by_id[sid] for sid in roadmap["ea_plan"]["slices"]]
    github = GitHub(dry_run)

    existing_labels = {label["name"] for label in github.read("labels")}
    for name, color in LABEL_COLORS.items():
        if name not in existing_labels:
            github.write("POST", "labels", {"name": name, "color": color}, f"create label {name}")

    milestones = {}
    for milestone in github.read("milestones?state=all"):
        match = SLICE_TITLE.match(milestone["title"])
        if match:
            milestones[match.group(1)] = milestone
    numbers = {}
    for item in slices:
        wanted = {"title": f"{item['id']} — {item['title']}", "description": slice_body(item),
                  "state": "closed" if item["status"] == "complete" else "open"}
        current = milestones.get(item["id"])
        if current is None:
            numbers[item["id"]] = github.write("POST", "milestones", wanted, f"create milestone {item['id']}")["number"]
            continue
        numbers[item["id"]] = current["number"]
        if any(current.get(key) != value for key, value in wanted.items()):
            github.write("PATCH", f"milestones/{current['number']}", wanted, f"update milestone {item['id']}")

    issues = {}
    # The label-filtered listing can lag behind fresh issues; filter locally instead.
    for issue in github.read("issues?state=all"):
        match = TASK_TITLE.match(issue["title"])
        if match and "pull_request" not in issue and any(l["name"] == PLAN_LABEL for l in issue["labels"]):
            issues[match.group(1)] = issue
    wanted_ids = set()
    for item in slices:
        for task in item["tasks"]:
            wanted_ids.add(task["id"])
            labels = sorted({PLAN_LABEL} | ({STATUS_LABELS[task["status"]]} if task["status"] in STATUS_LABELS else set()))
            wanted = {"title": f"[{task['id']}] {task['title']}"[:256], "body": task_body(item, task),
                      "milestone": numbers[item["id"]], "labels": labels,
                      "state": "closed" if task["status"] == "complete" else "open"}
            current = issues.get(task["id"])
            if current is None:
                created = github.write("POST", "issues", {k: v for k, v in wanted.items() if k != "state"},
                                       f"create issue {task['id']}")
                if wanted["state"] == "closed":
                    github.write("PATCH", f"issues/{created['number']}", {"state": "closed", "state_reason": "completed"},
                                 f"close issue {task['id']}")
                continue
            have = {"title": current["title"], "body": current.get("body") or "", "labels": sorted(l["name"] for l in current["labels"]),
                    "milestone": (current.get("milestone") or {}).get("number"), "state": current["state"]}
            changed = {key: value for key, value in wanted.items() if have[key] != value}
            if changed:
                if changed.get("state") == "closed":
                    changed["state_reason"] = "completed"
                github.write("PATCH", f"issues/{current['number']}", changed, f"update issue {task['id']} ({', '.join(changed)})")
    for task_id, issue in issues.items():
        if task_id not in wanted_ids and issue["state"] == "open":
            github.write("PATCH", f"issues/{issue['number']}", {"state": "closed", "state_reason": "not_planned"},
                         f"close retired issue {task_id}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="print the changes without writing to GitHub")
    sync(parser.parse_args().dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
