# Step 10 — Storage

## Room pass

The accepted shallow ribs, dark backing, enamel and clipped ceiling trays now continue through storage, with the same warm light tied to the existing lighting breaker. The authored shelf, crate stack, container and carried tool set remain the functional storage language; no labels, fake control panel or new item interaction was added.

The room keeps its existing staggered stowage and walk lane. `test_module_scene.gd` sweeps the standing capsule from the storage center toward both axial ends: it clears the open quarters-side hatch and reaches the storage-side approach to the intentionally closed airlock inner hatch. The airlock door remains shut and its interlock is unchanged. `test_world_layout.gd` checks that all carried props stay within their tube sections and leave the required lane; `test_carry.gd` preserves pickup/drop behavior.

The capture path sets the real lighting breaker, pitches the camera toward the stored equipment and hides HUD layers while leaving the analogue filter active.

## Rendered evidence

- [Storage aisle and room chain](../review/step10_storage_hatch_lane.png)
- [Closed inner airlock hatch](../review/step10_storage_inner_airlock_hatch.png)
- [Tools and shelf](../review/step10_storage_tools_and_shelf.png)
- [Crate stack and stowage](../review/step10_storage_crate_stack.png)

Godot 4.7.2 Forward+ rendered these at 1600×900 with the live fixtures and no temporary interior light. The screenshots were reviewed for equipment visibility, section framing and the closed pressure hatch.

## Validation

Each suite exited 0, printed its exact `PASS` marker and contained no `SCRIPT ERROR`. Logs and a result manifest are under `/tmp/hullwatch-art-step10-engine/suites/`.

| Suite | Result |
|---|---|
| `test_world_layout.gd` | PASS; carried storage and tool props remain in bounds and leave circulation |
| `test_carry.gd` | PASS |
| `test_player_traversal.gd` | PASS |
| `test_module_scene.gd` | PASS; storage capsule sweeps and dock/module routes |

Both geometry builders were rerun and reproduced identical scenes:

- `ship_geometry.tscn`: `14174c2b179cde5b74e699c22855bbae2e6f0766a7dd4daf2034af7fd5bd7960`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`
- `world_layout.tscn`: `f590fa82a9485d37892735cecc32f67f59f43c72c6c6eef63fdfd2298a32d9ce`

Headless and Forward+ scene shutdown still emit the previously observed Godot renderer/resource cleanup warnings after successful checks; there were no script errors. One early capsule sweep extended through the intentionally shut airlock hatch. The assertion now ends at the correct approach point; the hatch behavior did not change and the correction is in `.wolf/buglog.json`.

## Changed implementation

- `game/tools/build_ship_geometry.gd` — applies the accepted frame/tray/light treatment to storage.
- `game/tests/test_module_scene.gd` — sweeps a standing capsule to both storage hatch approaches.
- `game/tools/capture_screenshots.gd` — adds storage lighting, aisle, stowage and hatch captures.
- `game/scenes/ship_geometry.tscn` — regenerated deterministically.

No storage inventory, item behavior, pressure-door logic or collision sizes changed. Step 10 proceeds to the galley.
