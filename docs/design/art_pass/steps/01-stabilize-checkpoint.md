# 01 — Stabilize the frozen art checkpoint

## Objective and scope

Make the existing work a reliable starting point. Diagnose the provisional bounds-test error and preserve the current visuals; do not add art or adjust lighting in this packet. Prerequisite: the frozen files in ../FROZEN_STATE.json are available locally, including untracked assets. Read the shared contract in ../README.md.

## Owned files

`game/tests/test_hero_cabins.gd`; its generated UID; `docs/design/art_pass/steps/01-result.md`; `.wolf/STATUS.md`. The generators and Blender assets are read-only. If the actual production code is wrong, report the exact correction needed and route it to the next appropriate packet rather than hiding it in this test-only patch.

## Procedure

1. Record branch/HEAD/status. Compare the listed frozen file hashes. If another agent changed them, inspect the diff and record the new starting point; do not reset someone else's edits.
2. Inspect `test_hero_cabins.gd` and `/tmp/hullwatch-art-hero-test.out` if present. Reproduce with isolated user data. Trace the utility node and mesh lifetime/parent chain around the `global_transform` access. Check `is_inside_tree()` and instance validity while diagnosing.
3. Establish whether the queried nodes are the live instances, imported/template resources, or deliberately detached instances. Use the correct live tree, or accumulate each ancestor's local transform into the tested coordinate space as existing `_local_bounds`/`_prop_bounds` helpers do. Do not blindly skip nodes or accept Godot's identity fallback.
4. Remove brittle assumptions that the utility must consist of many mesh nodes or at least a particular triangle count. The export deliberately joins geometry. Assert meaningful invariants: nonempty exported geometry, actual mounting orientation and bounds, four fittings in the intended drum, containment in the true wall profile, no intrusion into circulation and no added arbitrary collision.
5. Include the three existing hero frame/tray groups in actual-profile checks. Distinguish rendering bounds from traversable collision; both need evidence. Record any failure that needs geometry correction.
6. Run relevant existing suites and inspect all new native errors. Do not silence output or change error allowlists to pass.
7. Archive a baseline result with exact commands and source diff/hash. Do not call the art checkpoint verified until the repaired measurements are trustworthy.

## Validation and acceptance

Run import if metadata requires it, startup smoke, `smoke_test`, `test_hero_cabins`, `test_hull_exterior`, `test_world_layout`, `test_player_traversal`, `test_cabin_light`, `test_pilot_seat_flow`, `test_wall_computer`. Each must have its exact PASS marker and exit 0; no out-of-tree transform error is acceptable in the repaired hero test. Keep expected legacy shutdown warnings separate. A full-suite result may be deferred to 09, but never claim the stopped run passed.

## Handoff

Return the diagnosed root cause, changed test lines, exact results and any real geometry defect. 02 can start once coordinate measurements are trustworthy; no automatic continuation.
