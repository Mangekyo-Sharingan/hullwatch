# Step 01 result — stabilize the art checkpoint

## Starting point

- Branch: `feat/starpath-art-pass-2026-10-01`
- HEAD: `5303882f04a33bf4a50bf4a5a6ec9cecf8cda11f`
- Every file listed in `FROZEN_STATE.json` matched its recorded SHA-256 before editing. The generators, generated scene, Blender source, and utility GLB remain unchanged.
- The manifest itself is unchanged; its only listed file intentionally updated by this packet is the provisional test, whose new hash is recorded below.
- The validation test is now `game/tests/test_hero_cabins.gd`, SHA-256 `5aa4f3ac31821426ce42efedd36d2f1405bf998754a9ccdfc55fb94edc528a9a`.

## Diagnosis

Each generated utility model exposed two children named `hw_utility_spine`: one detached child owned by the imported `Model` scene and one live child owned by `ShipGeometry`. `find_children("*", "MeshInstance3D", true, false)` returned both. Reading `global_transform` from the detached child logged `!is_inside_tree()` and returned an identity transform, so the old bounds test could print PASS using incorrect coordinates.

The test now addresses `Model/hw_utility_spine` directly, confirms that it is the live mesh, and measures its bounds in ship space. It checks nonempty exported geometry, inward facing, cockpit placement, and containment within the actual tube profile. The obsolete mesh-node and triangle-count thresholds are gone.

Each hero section now validates the bounds of its ten ribs, two cable trays, and six clips against the real profile. Collision checks are limited to the decorative fittings themselves; existing shell and cupola window colliders belong to the section and remain intact. The hull exterior and player traversal suites cover shell collision and physical access.

## Validation

All commands ran with isolated `XDG_DATA_HOME=/tmp/hullwatch-art-step01-userdata`; each exited 0. Script suites emitted their exact PASS marker, with no `FAIL:`, `SCRIPT ERROR`, parse error, or out-of-tree transform error.

| Check | Result |
|---|---|
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --quit` | PASS, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/smoke_test.gd` | `PASS: smoke_test`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_hero_cabins.gd` | `PASS: test_hero_cabins`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_hull_exterior.gd` | `PASS: test_hull_exterior`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_world_layout.gd` | `PASS: test_world_layout`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_player_traversal.gd` | `PASS: test_player_traversal`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_cabin_light.gd` | `PASS: test_cabin_light`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_pilot_seat_flow.gd` | `PASS: test_pilot_seat_flow`, exit 0 |
| `./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_wall_computer.gd` | `PASS: test_wall_computer`, exit 0 |

Scene-loading suites also print Godot `RendererDummy`/resource shutdown leak diagnostics. A control run of `test_player_traversal` at the frozen HEAD prints the same diagnostic family (570 resources and 795 renderer instances, versus 578 and 799 on the art worktree). There are no remaining mesh-transform errors in the repaired hero test. Full-suite validation remains for Step 09.

No new render was captured because this packet changes validation only. The archived hero images remain starting-state references, not art acceptance evidence.

## Handoff

Step 01 is complete. Step 02 can now measure the hero layout and establish its review rubric. Stop here and invoke the next packet separately.
