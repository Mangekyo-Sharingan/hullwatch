# Step 10 — Water closet

## Room pass

The water-closet drum now carries the accepted shallow pressure ribs, dark backers, enamel frames, clipped ceiling trays and warm breaker-driven light. Its existing reclaimer remains the room's visual anchor: the exposed vessels, manifold, gauges and sealed lines read as water machinery. The existing water diagnostic probe remains interactive and visible; no new readout or repair action was added.

The tube-mapped probe sat directly behind the reclaimer from the standing service lane. It now mounts 0.45 m toward the storage hatch in tube mode; its flat-layout position is unchanged. `test_module_scene.gd` checks capsule clearance to both adjacent hatches and rays from the service lane to the real reclaimer and probe. The center lane remains clear.

`capture_screenshots.gd -- --water-closet-only` uses the actual cabin light and breaker, hides HUD layers, retains the analogue filter, and captures the room chain, reclaimer service face and storage-side hatch.

## Rendered evidence

- [Water-closet hatch lane](../review/step10_water_closet_hatch_lane.png)
- [Reclaimer and probe service wall](../review/step10_water_closet_service_wall.png)
- [Storage-side hatch](../review/step10_water_closet_storage_hatch.png)

Godot 4.7.2 Forward+ rendered these at 1600×900 on Linux using the actual scene lighting and analogue filter. Captures were reviewed for hatch circulation and the two service targets.

## Validation

Startup smoke and all focused suites exited 0, printed their expected success markers and contained no `SCRIPT ERROR`. Full logs and `results.json` are under `/tmp/hullwatch-art-step10-engine/suites/water-closet/`.

| Check | Result |
|---|---|
| `--headless --path game --quit` | PASS |
| `test_water.gd` | PASS |
| `test_atmosphere.gd` | PASS |
| `test_world_layout.gd` | PASS |
| `test_hull_exterior.gd` | PASS |
| `test_player_traversal.gd` | PASS |
| `test_module_geometry.gd` | PASS |
| `test_module_scene.gd` | PASS; both hatch approaches and reclaimer/probe access rays clear |
| `test_scene_save_load.gd` | PASS |

Both geometry builders were run twice and reproduced identical scenes:

- `ship_geometry.tscn`: `5d594cae5a3621d30a000d89fc00b010ec3b8cead55fc1466752bf309d55f087`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`
- `world_layout.tscn`: `f36b001bab3f878b3c2c42fc44e824c08b570b74fae38b305e2fc896f2453f0f`

The normal Godot renderer/resource shutdown warnings remain after successful scene checks; no script errors occurred. The first service-ray check exposed the probe's occlusion behind the reclaimer, which the tube-only move resolved.

## Changed implementation

- `game/tools/build_ship_geometry.gd` — includes the water closet in the accepted frame, tray and warm-light treatment.
- `game/tools/build_world_layout.gd` — moves only the water probe's tube-mode position.
- `game/tests/test_module_scene.gd` — covers both hatch lanes and target rays.
- `game/tools/capture_screenshots.gd` — adds water-closet review captures.
- `game/scenes/ship_geometry.tscn` and `game/scenes/world_layout.tscn` — regenerated deterministically.

No water simulation, save state, component behavior or flat-layout geometry changed. Step 10 proceeds to the airlock.
