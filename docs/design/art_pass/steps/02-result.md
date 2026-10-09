# Step 02 result — measured hero target

## Deliverables

- `docs/design/art_pass/hero_target.md`: design direction, actual section and profile measurements, live station/prop/clearance constraints, build priorities, fixed review views, and implementation interfaces for Steps 03–08.
- `docs/design/art_pass/review/reference_notes.md`: visible observations separated from Hullwatch proposals; source and timestamp limits recorded.
- `docs/design/art_pass/hero_layout.svg`: original top-down and cross-section drawing. The cross-section uses the measured octagonal profile; the top view places chair, CRTs, fittings, bunk, locker, trays, hatch thresholds and dock throat from their scene coordinates.

## Validation

- Rendered the SVG with `rsvg-convert` and visually checked `/tmp/hullwatch-hero-layout.png`.
- `git diff --check -- docs/design/art_pass/hero_target.md docs/design/art_pass/review/reference_notes.md docs/design/art_pass/hero_layout.svg`: passed.
- Checked the local reference files directly. They contain no capture-time metadata, so no trailer timestamps are asserted.
- Cross-checked dimensions and placements against `TubeLayout`, `SectionHull`, `build_world_layout.gd`, and `_build_hero_cabins`.

## Handoff

Step 03 owns the hull geometry generator, generated scene, and hero-cabin test. Step 04 owns only the Blender utility kit/export/credit files and may author against the pinned interface in `hero_target.md`; scene integration waits for Step 03. Step 05 can then integrate the utility kit and build the denser live cockpit composition.
