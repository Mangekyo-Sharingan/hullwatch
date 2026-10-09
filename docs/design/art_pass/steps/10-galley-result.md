# Step 10 — Galley

## Room pass

The galley section now carries the accepted shallow pressure ribs, dark backers, enamel frames, clipped trays and warm breaker-driven practical light. Its authored prep unit and mess table remain the room’s real physical anchors. The `ComputerProp` remains passive authored set dressing: it has no script or `ComputerTerminal` node. The daily ration simulator and stock flow were left alone.

The tube layout had placed the galley prep unit on the starboard wall beside the galley’s starboard radial dock. Its long footprint blocked the operator’s capsule path. The tube-only mount now puts the prep unit on the port food-preparation wall and turns its working face toward the aisle; the flat-layout position and rotation remain unchanged. The test builds the real catalog storage pod at `hp_galley`, confirms the standing capsule can enter, then removes it and checks the material refund.

`capture_screenshots.gd -- --galley-only` uses the real cabin lights and breaker, hides HUD layers, retains the analogue filter and shows the food surfaces, room chain and installed pod.

## Rendered evidence

- [Galley aisle and room chain](../review/step10_galley_hatch_lane.png)
- [Mess table and passive computer prop](../review/step10_galley_table.png)
- [Preparation unit](../review/step10_galley_preparation_unit.png)
- [Storage pod through the open dock](../review/step10_galley_storage_pod_open.png)

Godot 4.7.2 Forward+ rendered these at 1600×900 on Linux. They use actual scene lighting, HUD-free capture and the live analogue filter. The installed pod is built through `ModuleMount` and `ModuleSystem` for this capture; the pictured computer remains visual-only.

## Validation

Every suite exited 0, printed the exact `PASS` marker and contained no `SCRIPT ERROR`. Logs and result manifests are under `/tmp/hullwatch-art-step10-engine/suites/`.

| Suite | Result |
|---|---|
| `test_world_layout.gd` | PASS; galley prep unit clears the dock and passive computer remains visual-only |
| `test_rations.gd` | PASS; existing ration loop |
| `test_module_geometry.gd` | PASS |
| `test_module_scene.gd` | PASS; open and installed galley dock capsule paths, storage-pod construction and teardown/refund |
| `test_player_traversal.gd` | PASS |
| `test_carry.gd` | PASS |

Both geometry builders were rerun and reproduced identical scenes:

- `ship_geometry.tscn`: `9ff0b8366dc60ba0582a45abc3296822a0b10ff42d76df773d8b8e8cae79194d`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`
- `world_layout.tscn`: `4c5356cf3f854076d9bbb50148cf74c914c7d73ee761c312567c993fa3cef4e0`

Headless and Forward+ scene shutdown print the inherited Godot renderer/resource cleanup warnings after successful checks; no script errors occurred. The first dock sweep exposed the blocked starboard approach; moving the existing prep unit to port resolved the collision and is recorded in `.wolf/buglog.json`.

## Changed implementation

- `game/tools/build_ship_geometry.gd` — extends the accepted frame/tray/light treatment to the galley.
- `game/tools/build_world_layout.gd` — moves and reorients the prep unit only in tube mode to clear the radial dock.
- `game/tests/test_module_scene.gd` — tests the galley dock route and installed storage pod.
- `game/tests/test_world_layout.gd` — guards the passive computer prop against gaining terminal behavior.
- `game/tools/capture_screenshots.gd` — adds galley and installed-pod captures.
- `game/scenes/ship_geometry.tscn` and `game/scenes/world_layout.tscn` — regenerated deterministically.

No ration, stock, display-program, module-effect or gameplay behavior changed. Step 10 proceeds to the water closet.
