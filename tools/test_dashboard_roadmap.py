#!/usr/bin/env python3
"""Check authored roadmap IDs, release-path references and EA plan rules before generating the dashboard."""

from copy import deepcopy
import json

from build_dashboard import DASHBOARD, ROOT, validate_roadmap


def main() -> None:
    roadmap = json.loads((DASHBOARD / "roadmap.json").read_text())
    validate_roadmap(roadmap)
    broken = deepcopy(roadmap)
    broken["release_path"]["current_stage"] = "missing"
    rejects(broken)
    for field in ("milestones", "gates"):
        broken = deepcopy(roadmap)
        broken["release_path"]["stages"][0][field] = ["missing"]
        rejects(broken)
    broken = deepcopy(roadmap)
    broken["release_path"]["stages"][0]["status"] = "ready"
    rejects(broken)
    broken = deepcopy(roadmap)
    broken["checkpoint"]["source"]["evidence"] = [{"path": "../outside.md", "label": "Invalid"}]
    rejects(broken)
    milestone = roadmap["milestones"][0]
    for mutate in (
        lambda r: r["milestones"][0]["tasks"][0].pop("id"),
        lambda r: r["milestones"][0]["tasks"][0].update(id=r["milestones"][1]["id"] + ".1"),
        lambda r: r["milestones"][0]["tasks"].append(dict(r["milestones"][0]["tasks"][0])),
        lambda r: r["gates"][0].update(id=milestone["id"]),
        lambda r: r["milestones"][1].update(id="GATE_" + milestone["id"]),
        lambda r: r["release_path"]["stages"][0].update(id="alpha"),
    ):
        broken = deepcopy(roadmap)
        mutate(broken)
        rejects(broken)
    capture = next((ROOT / "docs/store").glob("*.png")).relative_to(ROOT).as_posix()
    accepted = deepcopy(roadmap)
    piece(accepted, "EA01").update(status="complete", evidence=[{"path": capture, "label": "Capture"}])
    piece(accepted, "EA02")["status"] = "in_progress"
    validate_roadmap(accepted)
    skipped = deepcopy(roadmap)
    piece(skipped, "EA01")["status"] = "blocked"
    piece(skipped, "EA02")["status"] = "needs_review"
    validate_roadmap(skipped)
    for message, mutate in (
        ("More than 0 active", lambda r: (r["ea_plan"].update(wip_limit=0), piece(r, "EA01").update(status="in_progress"))),
        ("started before EA01", lambda r: piece(r, "EA02").update(status="in_progress")),
        ("without image, video or play-note proof", lambda r: piece(r, "EA01").update(
            status="complete", evidence=[{"path": "docs/PRODUCTION_SPEC.md", "label": "Document"}])),
        ("needs a player_outcome", lambda r: piece(r, "EA05").pop("player_outcome")),
        ("M4 is not on the EA plan", lambda r: piece(r, "M4").pop("absorbed_into")),
        ("GATE_MANUAL must belong", lambda r: piece(r, "EA03").update(gates=[])),
    ):
        broken = deepcopy(roadmap)
        mutate(broken)
        rejects(broken, message)
    print("PASS: dashboard roadmap ids, references, EA plan order/WIP/proof, stage statuses and evidence")


def piece(roadmap: dict, identifier: str) -> dict:
    return next(item for item in roadmap["milestones"] if item["id"] == identifier)


def rejects(roadmap: dict, message: str = "") -> None:
    try:
        validate_roadmap(roadmap)
    except ValueError as error:
        if message not in str(error):
            raise AssertionError(f"Rejected for {error!r}, expected {message!r}") from error
        return
    raise AssertionError("Invalid roadmap was accepted")


if __name__ == "__main__":
    main()
