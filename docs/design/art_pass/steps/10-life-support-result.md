# Step 10 — Life-support room

## Room pass

The accepted shallow ribs, dark backers, enamel frames, cable trays and metal clips now continue through the life-support section. Its existing cabin light uses the accepted warm setting and still follows the lighting breaker. The scrubber, O₂ candle rack, atmosphere probe and replaceable-filter rack retain their original models, scripts and simulation links.

The tube layout had placed all four service fittings on the port side beside the radial dock. A standing capsule could not reach the dock mouth. The fittings now sit on the starboard service side in tube mode; the flat-layout positions remain unchanged. Their actual target rays and a 0.48 m standing-capsule route to the dock are covered in `test_module_scene.gd`.

`capture_screenshots.gd -- --life-support-only` sets the existing lighting breaker on, captures the entry, filter rack and radial dock from standing height, then powers down the real scrubber and opens its actual housing for the maintenance view. The existing general filter-rack view was also moved from above the cabin to an in-room standing position.

## Rendered evidence

- [Entry and equipment](../review/step10_life_support_entry.png)
- [Filter service view](../review/step10_life_support_filter_service.png)
- [Radial dock mouth](../review/step10_life_support_dock_mouth.png)
- [Scrubber housing open](../review/step10_life_support_scrubber_open.png)

Godot 4.7.2 Forward+ rendered the images at 1600×900 on the Linux host. They retain the analogue filter and use the live scene, with HUD layers hidden. The open view is an actual scrubber animation; it does not alter saved game data.

## Validation

All checks below exited 0 and reached the exact suite `PASS` marker. Full logs are under `/tmp/hullwatch-art-step10-life/suites/`.

| Check | Result |
|---|---|
| `smoke_test.gd` | PASS |
| `test_world_layout.gd` | PASS |
| `test_hull_exterior.gd` | PASS |
| `test_player_traversal.gd` | PASS |
| `test_atmosphere.gd` | PASS |
| `test_diagnostics.gd` | PASS |
| `test_diagnostics_api.gd` | PASS |
| `test_operator_maintenance.gd` | PASS |
| `test_module_geometry.gd` | PASS |
| `test_module_scene.gd` | PASS; capsule dock route and rays to the atmosphere probe, O₂ rack and filter rack pass |
| `test_cabin_light.gd` | PASS; breaker, shed and load restoration verified |
| `test_scene_save_load.gd` | PASS |
| `test_interactables.gd` | PASS; scrubber's real service sequence and authored animation pass |

Both generators were rerun; output hashes matched the values before the rerun:

- `ship_geometry.tscn`: `93835bb23a40c895c0a6769b3b3256d43bf3cfb69b222498d64cf355c55082cb`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`
- `world_layout.tscn`: `f590fa82a9485d37892735cecc32f67f59f43c72c6c6eef63fdfd2298a32d9ce`

`git diff --check` and `.wolf/buglog.json` JSON validation pass. The invalid-input atmosphere suite emits its expected validation errors. Godot's existing dummy-renderer and scene-teardown resource-leak messages also appear after passing headless suites; no `SCRIPT ERROR` occurred.

## Changed implementation

- `game/tools/build_ship_geometry.gd` — adds life support to the accepted hero frame/tray/light treatment.
- `game/tools/build_world_layout.gd` — relocates the four tube-mode fittings, mirrors the filter-rack mount, and adds the room-specific `tube_rotation` override. Flat mode remains on the original positions.
- `game/tests/test_module_scene.gd` — adds the capsule route and clear target-ray checks.
- `game/tools/capture_screenshots.gd` — adds the room capture path and fixes the stale filter-rack camera.

No simulator behavior, repair action, fake readout, or Xenonite lore was added. Step 10 proceeds to the engine bay.
