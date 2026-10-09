# Step 10 — Airlock

## Room pass

The airlock section now carries the approved shallow pressure ribs, dark backers, pale frames, clipped trays and warm cabin light. The short chamber keeps its center lane; the existing animated pressure hatches, airlock panel and suit locker remain the working fixtures.

The generated EVA deck already carries the cargo port beside the radial hatch. Its collider clipped the straight standing-capsule approach, and its old position also overlapped the sample canister. The tube-only cargo-port mount now sits 0.8 m farther along the same platform, leaving the hatch centerline and canister clear. The flat-layout coordinates remain unchanged. `test_eva_flow.gd` waits for the real outer-hatch slide, sweeps a standing capsule from the chamber to the EVA deck, then continues the existing tether cycle.

`capture_screenshots.gd -- --airlock-only` keeps the cabin lighting breaker and analogue filter active. It captures the closed inner hatch, panel and locker, the real animated open locker, and the outer hatch after the real depressurization cycle and door slide.

## Rendered evidence

- [Inner hatch and approach lane](../review/step10_airlock_entry_lane.png)
- [Airlock panel and suit locker](../review/step10_airlock_panel_locker.png)
- [Suit locker open](../review/step10_airlock_locker_open.png)
- [Outer hatch open to the EVA platform](../review/step10_airlock_outer_open_eva.png)

Rendered at 1600×900 with Godot 4.7.2 Forward+ on Linux. The views use actual scene lighting, HUD-free capture and the live analogue filter. The open exterior view shows the real cargo port after its clearance move.

## Validation

Startup smoke and all focused suites exited 0 with their expected success markers and no `SCRIPT ERROR` or `FAIL:` lines. Logs and `results.json` are under `/tmp/hullwatch-art-step10-engine/suites/airlock/`.

| Check | Result |
|---|---|
| `--headless --path game --quit` | PASS |
| `test_airlock.gd` | PASS |
| `test_airlock_scene.gd` | PASS; both inner hatches, pressure interlock, panel, and locker procedure |
| `test_eva_flow.gd` | PASS; capsule path through the open radial hatch, automatic tether, return and repressurization |
| `test_tether.gd` | PASS |
| `test_hull_profile.gd` | PASS |
| `test_hull_exterior.gd` | PASS |
| `test_world_layout.gd` | PASS; exterior prop bounds, including the cargo port and sample canister |
| `test_player_traversal.gd` | PASS |
| `test_hero_cabins.gd` | PASS |

Both builders were run twice and produced identical scenes:

- `ship_geometry.tscn`: `b1db6f53e9ed50391c0894cd4ad6c53c6ff29e9b5ba8d9801837f432b860a238`
- `dock_pod.tscn`: `29cede89743908e193f5ea0c080739c6ce71cf952e8aee98c6fbc0c7496d77c1`
- `world_layout.tscn`: `4c0c1328a688ce18dd309405e8ef6542eb1ac52a7831aaba53fae4378f275cdd`

Scene shutdown still emits the existing Godot resource-cleanup warnings after suite output. The first capsule regression sampled while the hatch was still moving; the test now waits for its actual slide duration. Once settled, it exposed the cargo-port clearance issue, fixed by the measured tube-only shift. Neither pressure-door behavior nor the airlock simulator changed.

## Changed implementation

- `game/tools/build_ship_geometry.gd` — extends the approved cabin frame, tray and light treatment to the airlock.
- `game/tools/build_world_layout.gd` — moves the tube-mode cargo port along the EVA deck.
- `game/tests/test_eva_flow.gd` — checks the open radial hatch capsule route after the door finishes sliding.
- `game/tools/capture_screenshots.gd` — adds actual airlock procedure and hatch-state captures.
- `game/scenes/ship_geometry.tscn` and `game/scenes/world_layout.tscn` — regenerated deterministically.

No airlock pressure, interlock, suit, tether or save behavior changed. Step 10 is complete; Step 11 proceeds to the exterior.
