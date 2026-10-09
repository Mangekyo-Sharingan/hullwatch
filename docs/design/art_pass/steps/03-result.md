# Step 03 result — pressure frames and cable routing

## Changes

- The three hero sections retain their ten shallow upper-arc ribs and clear lower deck. Each beige frame now sits over a recessed dark backer, separating its mount from the mottled pressure skin and giving the frame a visible shadow edge.
- Each of the two ceiling-edge cable trays per section now has a metal end cap at both ends. The cap closes the covered run 0.42 m inside the section boundary, away from the hatch leaf in the bulkhead gap. Existing three support clips remain.
- The hero regression checks actual mesh bounds against each section profile and verifies no colliders on ribs, backers, trays, caps or clips. The generator remains the source of `ship_geometry.tscn`; the dock-pod output remains deterministic.

## Validation

| Check | Result |
|---|---|
| `build_ship_geometry.gd` | `PASS: build_ship_geometry (tube preview)` and `PASS: build_ship_geometry` |
| Second generator run | `ship_geometry.tscn` and `dock_pod.tscn` hashes unchanged |
| `--headless --path game --quit` | exit 0, no `SCRIPT ERROR` |
| `smoke_test.gd` | `PASS: smoke_test` |
| `test_hero_cabins.gd` | `PASS: test_hero_cabins` |
| `test_hull_profile.gd` | `PASS: test_hull_profile` |
| `test_hull_exterior.gd` | `PASS: test_hull_exterior` |
| `test_world_layout.gd` | `PASS: test_world_layout` |
| `test_player_traversal.gd` | `PASS: test_player_traversal` |
| `test_pilot_seat_flow.gd` | `PASS: test_pilot_seat_flow` |
| `test_cabin_light.gd` | `PASS: test_cabin_light` |
| `git diff --check` | clean |

All checks ran with `XDG_DATA_HOME=/tmp/hullwatch-art-pass-userdata`. Logs are in `/tmp/hullwatch-art-step03/`. As with the existing art checkpoint, Godot exits with RendererDummy/headless resource-leak diagnostics after script runs; there are no script errors. Rendered scene capture ran with the NVIDIA Forward+ renderer and emitted `PASS: hero art captures`.

## Visual review

- [Cockpit wide view](../review/step03_hero_cockpit.png): the raised frame/backer layers now separate the cabin bays. The chair and side CRTs remain in place.
- [Utility wall](../review/step03_hero_utility.png): the rib layer and capped runs give the open wall a service structure. The close framing reads dark under current defaults; materials and practical-light tuning remain Steps 06–07.
- [Quarters aisle](../review/step03_hero_quarters.png): bunk, locker and through-route remain visible with the frame rhythm carried into the room.

These captures retain normal HUD/orientation overlays because this packet does not own the capture tool. They are geometry review evidence, not final composition captures; Step 09 owns the paired HUD-free/gameplay review views.

## Generated state

- Generator SHA-256: `133dcfe09f3189ab14757348775a29a951efcd4bc1bf772e67e4b0cdcc4d14da`
- `ship_geometry.tscn`: `a8a0b087cc1052f58e2f057c3017010981f601009f2c32362d2f810b215c3f8f`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`

## Handoff

The backer and cap meshes add no collider and fit the measured section profiles. Step 04 is authoring the utility model against the unchanged measured bounds. Integrate that export only after its result is reviewed, then proceed to Step 05 cockpit integration.
