# Step 05 result — composed working cockpit

## Composition

The five CRT terminals retain their existing positions, scripts, live programs, screens and interaction colliders. Each visual AABB is `0.31645 × 1.0025 × 0.699204 m`; the three stations in each side bank are spaced 0.75 m apart, leaving about 50.8 mm between housings. They sit at `x=±1.95`, `y=1.25`, with the existing cupola `z` grid at `-20.65`, `-19.90`, and `-19.15`. Their tops remain below the upper bevel.

Four terminals now have a shallow dark plinth built on the owning prop wrapper. It fills the measured 72 mm between their backs and the vertical cabin wall and extends 40 mm above/below the console. It adds no collision and does not enlarge the console interaction shape. `CommsTerminal` remains unbacked because the cockpit hull-service plate occupies the adjacent wall footprint; `WallComputer` keeps its authored stowed slot and foldout. The layout test asserts this service clearance.

| Element | Root position | Visual bounds or clearance |
|---|---|---|
| Log / Contact / Nav terminals | `(1.95, 1.25, -20.65 / -19.90 / -19.15)` | Each `0.31645 × 1.0025 × 0.699204 m`; back plane x reaches 2.040 m |
| Archive / Comms terminals | `(-1.95, 1.25, -19.90 / -19.15)` | Same CRT bounds; Comms remains clear of `HullPatch_cockpit` |
| Wall computer, stowed | `(-1.95, 1.25, -20.65)` | `0.16 × 0.74 × 0.64 m`; authored wall-slot mount |
| Wall computer, deployed | Existing animation | `0.45 × 0.50 × 0.60 m`; the folded blade and service panel remain clear |
| Switch bank | `(-0.62, 0.95, -20.82)` | `0.35 × 0.25 × 0.091041 m` |
| Gauge cluster | `(0, 0.95, -20.82)` | `0.45 × 0.30 × 0.128 m` |
| Seven segment | `(0.62, 0.95, -20.82)` | `0.25 × 0.10 × 0.06725 m` |
| Pilot chair | `(0, 0, -19.80)`, yaw 180° | Mesh `0.78 × 1.445 × 0.78 m`; deployed/stowed collision and seat path unchanged |

The detailed AABBs and transforms are measured from the instantiated GLB meshes in WorldLayout-local coordinates. The original CRT station names and the instrument ids `switch_bank`, `gauge_cluster`, and `seven_segment` remain unchanged.

## Validation

- Both geometry builders pass on two consecutive runs; `ship_geometry.tscn`, `world_layout.tscn`, and `dock_pod.tscn` reproduce byte-for-byte.
- Startup (`--headless --path game --quit`) exits 0 without `SCRIPT ERROR`; `smoke_test` prints `PASS: smoke_test`.
- `test_world_layout`, `test_hero_cabins`, `test_player_traversal`, `test_pilot_chair`, `test_pilot_seat_flow`, `test_seated_hud`, `test_wall_computer`, and `test_computer_terminal` each print their exact `PASS: <suite>` marker with exit 0 and no `SCRIPT ERROR`.
- `git diff --check` is clean. Test logs and deterministic builder logs are in `/tmp/hullwatch-art-step05/`.
- One first layout run found a bounds overlap between the Comms backplate and `HullPatch_cockpit`. The Comms backing was removed and a direct regression assertion added; the final full targeted set above passes. The finding is recorded in `.wolf/buglog.json`.

## Render review

- [Approach](../review/step05_approach.png): repeated upper framing, central chair and both live side banks read together; center aisle remains clear.
- [Forward instruments](../review/step05_forward_instruments.png): the switch bank, gauge cluster and live CO₂ digits remain visible below the window. This is a fixed review-camera view, not a capture of the operator already seated.
- [Port bank](../review/step05_port_bank.png) and [starboard bank](../review/step05_starboard_bank.png): physical CRT housings are seated against the dark wall plinths; screens display current console programs. The Comms end leaves the adjoining hull-service plate exposed.

Captured at 1600×900 with the scene's Forward+ lighting, original filter and no temporary work lights. The startup traffic/guide cards remain in these screenshots, so they are gameplay evidence rather than clean presentation images. Step 09 owns actual seated-camera captures and presentation-only views. The current cool dark plinth remains subject to Steps 06–07 material/light review.

## Handoff

The cockpit layout is ready for Step 06's material pass. Keep the xenon-metal material and analogue filter unchanged; tune only hero-owned surfaces and the utility model palette.
