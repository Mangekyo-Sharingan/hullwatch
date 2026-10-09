# 03 — Refine structural framing and cable routing

## Objective

Give the hero spaces readable structural depth and credible cable routing while preserving circulation. Requires 02. Refine the existing WIP rather than adding a second dressing system.

## Owned files

`game/tools/build_ship_geometry.gd`; its generated `game/scenes/ship_geometry.tscn` and, only if regenerated output actually changes, `dock_pod.tscn`; `game/tests/test_hero_cabins.gd`; `docs/design/art_pass/steps/03-result.md`. `TubeLayout`/`SectionHull` dimensional tables are read-only in this packet.

## Procedure

1. Review `_build_hero_cabins`, `_add_dressing`, `_build_tube_fittings` and the repaired assertions. Keep the hero section list limited to cupola/cockpit/quarters.
2. Use the measured cross-section and planned longitudinal positions. Construct mounting ribs/covers with flush joins; inspect current box-beam ends for visible overlaps/gaps and refine them with existing polygon/surface helpers where needed. Avoid creating a speculative general kit framework.
3. Layer structure intentionally: dark substrate or recess, worn off-white frame, occasional metal fasteners. A rib may project modestly from the signature wall, but must not look like a new pressure wall pasted on top of it.
4. Keep floor/deck and hatch throats unobstructed. Check corners against the sloped wall, not just a single center point or an axis-aligned nominal radius.
5. Refine existing ceiling-edge cable trays and clips. Routes must have coherent starts/ends and pass behind/around brackets. Avoid pipes through door leaves or unsupported floating cable ends. Decorative covered runs should not imply new controls or simulator state.
6. Reuse material resources and generator helpers. Add a new resource only when a visual layer needs a distinct material response; coordinate that with 06 rather than editing a shared global material opportunistically.
7. Regenerate the scene, inspect rendered wide/close views and rerun geometric checks. Measure aisle/passage clearance with actual capsules and moving door/chair states, not screenshots alone.

## Validation and acceptance

Startup smoke and `smoke_test`, `test_hero_cabins`, `test_hull_profile`, `test_hull_exterior`, `test_world_layout`, `test_player_traversal`, `test_pilot_seat_flow`. Rerun the generator and compare scene hashes for determinism. No exterior leak, outboard fitting, hatch obstruction, floating trim or new player collision. Frame layering is visible in a wide view; joins hold up close.

## Handoff

Record material/model interfaces and any changed mounting bounds for 04/05. Include final render paths and generator hash comparison. Stop; do not extend framing to the remaining rooms yet.
