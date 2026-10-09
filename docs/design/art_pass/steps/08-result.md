# Step 08 result — quarters hero

## Changes

- Moved the bunk to the starboard side and shifted the existing locker to the aft port side of the quarters in `build_world_layout.gd`. This preserves their collision dimensions and sleep interaction while clearing the port-side utility-pod route.
- Added a standing-player capsule path check to `test_module_scene.gd`. The previous center ray at y=1.0 passed above the bunk and falsely treated the pod as walkable.
- Regenerated `world_layout.tscn`. No new prop, mesh, material, sleep, rations or module behavior was added.

## Visual review

Captured with Godot 4.7.2 Forward+, the normal scene lighting and analogue filter, with UI presentation layers hidden and no capture work light. The utility pod was installed using its real 8 metal / 4 ore recipe. The bunk, locker, terminal, rib frames, cable trays and open central passage are visible in the room views. A separate view from inside the pod looks back through the actual doorway into quarters.

- [Wide aisle and installed pod state](../review/step08_quarters_wide_pod_installed.png)
- [Bunk-facing view](../review/step08_quarters_bunk_facing_pod_installed.png)
- [Port-side service opening](../review/step08_quarters_port_and_pod_pod_installed.png)
- [Aft hatch approach](../review/step08_quarters_hatch_approach_pod_installed.png)
- [From the installed pod into quarters](../review/step08_quarters_pod_looking_in_pod_installed.png)

The five captures reflect the generated layout after the bunk/locker adjustment. The capture process exits 0 and prints its PASS marker; Forward+ emits its existing renderer-resource leak diagnostics at shutdown after saving the images. No GDScript error occurred.

## Validation

Isolated Godot user data: `/tmp/hullwatch-art-step08-userdata`.

| Command | Result |
|---|---|
| `--headless --path game --script res://tools/build_world_layout.gd` | exit 0; generated scene |
| `--headless --path game --script res://tests/smoke_test.gd` | exit 0; `PASS: smoke_test` |
| `--headless --path game --script res://tests/test_world_layout.gd` | exit 0; `PASS: test_world_layout` |
| `--headless --path game --script res://tests/test_hero_cabins.gd` | exit 0; `PASS: test_hero_cabins` |
| `--headless --path game --script res://tests/test_player_traversal.gd` | exit 0; `PASS: test_player_traversal` |
| `--headless --path game --script res://tests/test_day_loop.gd` | exit 0; `PASS: test_day_loop` |
| `--headless --path game --script res://tests/test_scene_loop.gd` | exit 0; `PASS: test_scene_loop` |
| `--headless --path game --script res://tests/test_module_scene.gd` | exit 0; `PASS: test_module_scene`, including capsule reachability, teardown and save restoration |
| `--headless --path game --script res://tests/test_scene_save_load.gd` | exit 0; `PASS: test_scene_save_load` |

## Reuse notes

Safe to reuse: the quarters rib frames, dark backers, hero enamel ribs, ceiling trays/clips, warm cabin fixtures, `hw_bunk.glb`, `hw_locker.glb`, and the existing authored wall terminal. The new placement leaves the aft locker away from the pod bore and the bunk on the opposite side of the port approach.

Step 09 can now review the cockpit/quarters pair. The 16-view Step 07 breaker/flashlight matrix remains the evidence for powered and lights-off states.
