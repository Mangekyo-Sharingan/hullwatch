# 11 — Refine the exterior to match the same vessel

## Objective

Apply the reference's layered section/hardware language outside while retaining the approved faceted pressure hull and working EVA ship. Requires accepted hero styling. Interior work can inform kit reuse, but do not consume another worker's uncommitted shared generator edits.

## Owned files

Exterior dressing in `build_ship_geometry.gd`; generated ship scene; original exterior-kit authoring sources/exports; `test_hull_exterior.gd`; asset credits and exterior review artifacts. `SectionHull` / `HullProfile` may be changed only if an explicitly approved measured hull change is required; do not silently revise dimensions or physics.

## Procedure

1. Inspect official trailer exterior views and local `Reference/station_design.jpg` if present. Separate observed industrial/section rhythm from a proposal. Retain original Hullwatch identity and do not recreate the exact Starpath vessel.
2. Inventory actual shell, collars/ribs, cupola/window, dock plates/pod envelopes, arrays/booms, cassettes, feed tank, floodlights, tether anchors and catwalk/ramp. Mark access/no-build volumes in a side/top diagram.
3. Improve silhouette with original layered fittings: sensible attachment plates, protected conduit runs, collar detail and restrained maintenance markings. Scale mounts from actual drum reach, not flat-layout coordinates. Prefer refining existing authored kits before adding many assets.
4. Preserve shell watertightness and collision generated from the same surfaces. Decorative fits may not hide holes, cover the viewport, penetrate interiors, intersect arrays or obscure stern plumes/service cameras.
5. Check all EVA maintenance sequences with real carried tools, suit/tether and cassette covers. Preserve sealed Xenonite presentation, independent cassettes, single-cassette visuals and loaded-save FX restoration.
6. Inspect both sides and several lighting angles. A mirrored fitting can look asymmetric because of directional illumination; distinguish a lighting problem from bad geometry before duplicating/rebuilding it.
7. Render bow/stern/port/starboard/three-quarter views and service/operator views. Include installed pods and open maintenance covers. Record silhouette before small wear/decals.

## Validation and acceptance

Smoke plus `test_hull_profile`, `test_hull_exterior`, `test_module_geometry`, `test_module_scene`, `test_eva_flow`, `test_airlock_scene`, `test_tether`, `test_propulsion`, `test_player_traversal`. Existing containment ray fans and no-outboard guards stay enabled. Scene regeneration deterministic. Every mount/access path works; no fake radiator/drive mechanic is added. No Windows-native performance claim without execution.

## Handoff

Return original source/export interfaces, clearance evidence and final rendered views. Technical completion and stylistic acceptance are separate facts. Release work is handled only by 12 when authorized.
