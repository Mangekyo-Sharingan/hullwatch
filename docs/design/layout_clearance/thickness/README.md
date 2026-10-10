# Remaining thin bulkheads — 2026-10-10

The operator spotted further flat wall projections in the galley comparison.
The large right-hand sheet was the galley service entrance's aft jamb. Its
straight diagonal edge skipped the cabin's 0.3 m and 1.9 m profile breakpoints,
projecting 45.7 cm into the cabin at shoulder height. Opposite faces occupied
the same plane. The shared throat helper also served the docks and airlock.

The preceding pass corrected the overlong jambs but left the bulkhead's two
visible faces on the same center plane. Its opening lining extended toward the
neck endpoints, leaving the wall wings with no depth. The new side-bay entrance
faces also occupied the same plane.

## Correction

Each tube bulkhead now has front and rear faces separated by the existing
`TubeLayout.WALL` (12 cm), centered on its original door position. The opening's
floor, ceiling and jambs join those faces once. Both side-bay entrance walls use
the same thickness, extending into the bay. Widths, heights, door centers and
compartment links are unchanged. Geometry and collision use the same triangles.

The shared entrance helper now follows the real cabin profile through every
breakpoint. Its jambs are closed 12 cm volumes extending away from the opening,
keeping the existing 1.2 m bay/dock passage. Empty profile bands emit no sheet.
The new shoulder-height regression failed on all four bay entrance edges before
the correction and passes afterwards.

This fixes a missing volume; real pressure bulkheads still frame the doorway.
It does not remove those structural partitions or widen the hatches.

## Matching views

These use the same cameras as the previous screenshot comparison, with normal
lighting and the analogue filter. The before images are the `.2` playtest layout;
the after images show this follow-up correction.

| Galley before | Galley after |
|---|---|
| ![Before](../comparison/after/galley_walkway.png) | ![After](review/galley_walkway.png) |

| Cockpit before | Cockpit after |
|---|---|
| ![Before](../comparison/after/cockpit_joint.png) | ![After](review/cockpit_joint.png) |

## Validation

The new regression failed on the old geometry at every tube joint. It measures
both bulkhead faces using real physics rays and checks bay entrance face/bore
depth from their generated collision triangles. Existing capsule access,
machine service, pressure enclosure and EVA walkway checks are retained.
Fresh commands/results are recorded in `results.json`; historical October 9
checks remain in the parent result. Native Windows gameplay and operator
acceptance remain pending. The published `.2` build predates this correction.

Fresh final validation: **91/91 source suites**, isolated startup, **6/6 actual
Windows EXE embedded-project checks**, deterministic geometry and six native
rendered views pass. Independent mesh review: seven throats, 38 closed jamb
solids, zero inboard profile violations or winding errors. Both service-bay
render/collision meshes match.

## Delivered build

[Download the corrected Windows playtest](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261010.1).
Published from `fcacf28` at 2026-10-10T14:26:57Z; EXE/ZIP/validation downloads
match their hashes and the published tag resolves to the source. Native Windows
gameplay remains an operator gate. Dashboard snapshot and browser checks pass.
