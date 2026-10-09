# Step 10 — Engine bay

## Room pass

Both engine-bay drums now carry the accepted shallow ribs, dark backers, pale enamel, clipped ceiling trays and warm practical light. This adds the same structural rhythm as the hero rooms while keeping the central hatch lane open. Existing fabricator, tool cart, thermal and hull probes, hull patch point, bulkhead hatches and exterior drive service remain in place. No Xenonite mechanism or new simulation content is exposed.

The engine bay’s east radial mount now has explicit capsule-access coverage. The existing module scene check confirms the room-to-mouth route, points from the standing lane to the thermal probe, hull probe and fabricator, builds the catalog’s actual auxiliary-battery pod at `hp_engine_bay`, enters it with a standing capsule, removes it and verifies the material refund. The utility pod belongs to `hp_quarters`; the test and capture use the correct battery pod and its configured 14-hour build.

`capture_screenshots.gd -- --engine-bay-only` uses the live lighting breaker and scene fixtures, hides HUD layers, retains the analogue filter, and frames the hatch, fabricator, tool cart and battery-pod dock at standing height. No temporary interior work light is added.

## Rendered evidence

- [Engine-bay entry and clear hatch lane](../review/step10_engine_bay_entry.png)
- [Fabricator service face](../review/step10_engine_bay_fabricator.png)
- [Tool cart and work area](../review/step10_engine_bay_tool_station.png)
- [Closed engine-bay dock](../review/step10_engine_bay_service_dock.png)
- [Installed battery pod through the open dock](../review/step10_engine_bay_pod_open.png)

Rendered at 1600×900 with Godot 4.7.2 Forward+ on Linux. The dark idle dock is the sealed mount; the final view shows the real pod after construction. Images were reviewed for structural framing, passage clearance and live service props. The actual external cassette maintenance views remain part of the exterior pass.

## Validation

Each suite exited 0, printed its exact `PASS` marker and contained no `SCRIPT ERROR`. Logs and a result manifest are under `/tmp/hullwatch-art-step10-engine/suites/`.

| Suite | Result |
|---|---|
| `test_propulsion.gd` | PASS |
| `test_thermal.gd` | PASS |
| `test_fabricator.gd` | PASS |
| `test_operator_maintenance.gd` | PASS |
| `test_module_geometry.gd` | PASS |
| `test_module_scene.gd` | PASS; mouth and installed-pod capsule routes, probe/fabricator target rays, construction and teardown |
| `test_cabin_light.gd` | PASS; breaker behavior and save restoration |
| `test_player_traversal.gd` | PASS |

Both generated-scene builders were rerun. A second generation produced matching hashes:

- `ship_geometry.tscn`: `2ab4357b4db789fd50632ab40dd7f65f8d44e4416dba95e75dd8366fea0c6593`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`
- `world_layout.tscn`: `f590fa82a9485d37892735cecc32f67f59f43c72c6c6eef63fdfd2298a32d9ce`

Headless scene suites emit the known `RendererDummy` shutdown allocation warnings after their exact PASS markers; the Forward+ capture also exits with renderer resource cleanup warnings after `PASS: engine-bay captures`. No script errors occurred. Initial test iterations exposed an invalid quarters-only pod choice and a duplicated stock addition in the new test; both were corrected and documented in `.wolf/buglog.json`.

## Changed implementation

- `game/tools/build_ship_geometry.gd` — extends accepted ribs, trays and warm lights through the two engine-bay sections.
- `game/tests/test_module_scene.gd` — checks the eastward capsule approach, target rays, and the installed auxiliary-battery pod route and teardown.
- `game/tools/capture_screenshots.gd` — adds standing-height room captures with the valid engine-bay pod.
- `game/scenes/ship_geometry.tscn` — regenerated deterministically.

No power, propulsion, thermal, Xenonite, or module behavior was changed. Step 10 proceeds to storage.
