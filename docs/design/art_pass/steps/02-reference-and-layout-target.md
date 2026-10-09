# 02 — Turn the reference into a measured hero target

## Objective

Create a buildable visual brief for the cockpit suite and quarters. This is a design/documentation packet, not another implementation pass. Requires trustworthy measurements from 01.

## Owned files

`docs/design/art_pass/hero_target.md`; `docs/design/art_pass/review/reference_notes.md`; optional original diagrams in that directory. All game and Blender files are read-only.

## Inputs

Official Starpath trailer/store page linked in ../README.md; existing local `Reference/` images if available; archived unfinished captures; `docs/PRODUCTION_SPEC.md` §6; `.wolf/cerebrum.md`; `TubeLayout` and `SectionHull`; the cockpit tables in `build_world_layout.gd`; the frozen hero builder.

## Procedure

1. Inspect public reference footage and the actual local captures. Write what is observable: pressure section rhythm, rib shape/depth, fixture locations, mounting layers, hardware spacing and color/light relationships. Separate observations from proposed Hullwatch interpretations. Record trailer timestamps where available; do not invent them or imply access to the unreleased game.
2. Create a compact comparison sheet using the user's own captures and original diagrams. Keep copyrighted reference imagery local/reference-only; do not add it to exported game assets. Link the official source.
3. Measure each hero span with `TubeLayout.span()`. Derive width at equipment heights through `SectionHull.tube_half_width()`. Record floor, wall, bevel and ceiling limits. Do not treat nominal section radius as a usable radial room.
4. Map live station, chair/animation, door, hatch throat, dock opening and existing prop bounds. Mark exclusion volumes for the standing capsule, chair swing/boarding, readout cameras and moving blade/hatch leaves. Preserve current functional station names.
5. Draw one top view and one wall elevation with locations for frame bands, utility fittings and cable routes. Explain each addition's physical purpose. Bound projection depths from measured free space; do not allocate panels by guessing from a screenshot.
6. Specify three fixed final review angles: approach into cupola, seated forward/each bank, and quarters aisle/bunk. Add utility close-up and lights-off diagnostic angles. Define which captures keep HUD and which hide it.
7. List desired changes in priority order: large structural layers first, cabinet mounting depth second, useful utility density third, material wear and practical light composition last. Explicitly retain the mottled walls and strong filter.

## Acceptance

The brief contains measured tables and diagrams, original-asset requirements, expected silhouette/spacing and a checklist using the shared rubric. It identifies current unfinished areas without declaring them accepted. All proposed fittings can be placed without changing cabin height, pressure shell, hatch dimensions or the central console/seat arrangement.

## Handoff

Provide `hero_target.md` and exact interfaces for 03/04: model names, bounds, origin, axes and proposed mounts. If the operator requests a different composition, amend the brief before implementation. Stop after the brief.
