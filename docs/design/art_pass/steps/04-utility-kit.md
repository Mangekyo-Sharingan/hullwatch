# 04 — Refine the original utility hardware kit

## Objective

Produce one useful, bounded family of utility fittings with the reference's layered industrial construction. Requires 02's interfaces. Can run alongside 03 only with separate file ownership; integration follows 03.

## Owned files

`art/blender/build_hero_utilities.py`, `hero_utilities.blend`, `game/assets/models/hullwatch/interior/hw_utility_spine.glb`, importer-generated metadata, and the original-asset entry in `docs/ASSET_CREDITS.md`. Any extra model must be explicitly justified in the packet result and use the same folder/source pipeline. Do not edit generators or generated scenes.

## Existing interface

Root `hw_utility_spine`; glTF +Y up, +Z front; origin centered on mounting backplane. Bounds x ±0.25 m, y ±0.55 m, z 0..0.16 m. Blender uses Z up and -Y front. Preserve this contract unless 02 supplied a measured replacement and the integrating worker has that replacement in writing.

## Procedure

1. Inspect the current source/export and bounds assertions. Reuse its Blender primitives/materials and deterministic headless exporter.
2. Refine large construction layers: backplate, inset cases/service covers, frame rails and credible fastener placement. Pipes/cables require continuous bends, couplings and clamps with plausible termination.
3. Add restrained manufacturing/wear detail: bevels, edge highlights, painted labels or one safety strip, controlled roughness differences. Do not add arbitrary vents or wires merely to make the object busier.
4. Keep passive utility hardware passive. No fake glowing status screens, unusable interactive-looking control bank, invented subsystem or explanation of sealed Xenonite.
5. Repeated fittings must not look like a pasted identical screenshot. First vary placement or a small authored cover/route variant; avoid random runtime geometry, many nearly identical assets or a new dependency.
6. Join meshes by material where useful. A low node count is compatible with detailed geometry. Optimize hidden faces and inspect silhouette before choosing triangle counts; polygon count is a report, not an art target.
7. Export with `blender --background --factory-startup --python art/blender/build_hero_utilities.py`. Verify root, axes, bounds, no unwanted cameras/lights/collision/animation, material slots and reproducibility. Render a neutral preview and inspect the actual Godot import after the integration owner schedules it.

## Acceptance

The fittings read as mounted industrial hardware at both operator distance and close-up; bends/fasteners survive export; the documented envelope is respected. No downloaded/copied trailer asset. Supply exact bounds, topology count, source/export hashes and preview paths. A second export must not change the meaningful geometry unexpectedly.

## Handoff

Send model paths and unchanged/updated interface to 05. Do not regenerate scenes concurrently with 03, and do not modify the published Windows package.
