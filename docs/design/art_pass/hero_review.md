# Step 09 — cockpit and quarters review

The approved visual target is the Starpath trailer's layered industrial structure, warm practical lighting and dense but purposeful equipment. These captures establish the rollout baseline. The user had approved the visual direction and explicitly authorized completion of the full art pass; this report does not claim the user has reviewed these exact final captures.

| Criterion | Review |
|---|---|
| **Structural depth — accepted** | Shallow ribs, dark backers, nested hatch frames and wall-mounted hardware remain visually separate. See [cockpit approach](review/step05_approach.png), [lit cockpit](review/hero_light_cockpit_lights_on_torch_off.png) and [quarters hatch approach](review/step08_quarters_hatch_approach_pod_installed.png). |
| **Equipment density — accepted with bounded residual** | Ordered CRT banks and the utility fittings give the cockpit purpose. Quarters has its bunk, locker, wall terminal and service runs while keeping the aisle clear. A few broad wall areas remain open; keep future additions attached to an actual service route or mount. See [utility wall](review/hero_light_utility_lights_on_torch_off.png), [quarters wide](review/step08_quarters_wide_pod_installed.png). |
| **Retro instruments — accepted with legibility caveat** | The seated front/port/starboard views show physical gauges, digits, switches and simulator-backed CRTs. Text is readable in close views but small at normal seated distance under the analogue filter. See [front](review/hero_light_seated_lights_on_torch_off.png), [port](review/hero_light_seated_port_lights_on_torch_off.png), [starboard](review/hero_light_seated_starboard_lights_on_torch_off.png), and the [utility close view](review/step06_hero_utility.png). |
| **Practical lighting — accepted** | The 24-image matrix shows visibly warmer local pools with the lighting breaker on, darker rooms with it off, and a distinct task pool from the real flashlight in the forward and utility views. Side-console flashlight pairs are not strongly distinct from these fixed camera angles; the captures do not indicate a confirmed lighting fault. Preserve the existing lighting/filter balance and revisit if play reveals poor side-console task visibility. See [quarters lights on](review/hero_light_quarters_lights_on_torch_off.png), [quarters lights off](review/hero_light_quarters_lights_off_torch_off.png), [utility torch on](review/hero_light_utility_lights_off_torch_on.png). |
| **Material identity — accepted** | The mottled xenon-metal surfaces remain recognizable. Pale hero enamel, dark backers, metal fittings and CRT glass separate without changing the shared wall material or analogue-filter defaults. The filter obscures subtle roughness differences at this image scale. |
| **Movement/access — accepted by tests, not by still images alone** | Quarters retains its central passage and radial pod route; the installed-pod view looks back through the real doorway. `test_player_traversal` and the new standing-capsule route in `test_module_scene` provide collision evidence. Seating, panel use, door movement, EVA/tether and save restoration are covered by the full suite. See [quarters pod approach](review/step08_quarters_port_and_pod_pod_installed.png), [view from pod](review/step08_quarters_pod_looking_in_pod_installed.png). |

The paired [wall terminal stowed](review/step09_wall_terminal_stowed_gameplay.png) and [open](review/step09_wall_terminal_open_gameplay.png) gameplay captures show its real fold-out state; these retain the tutorial HUD. The hero presentation matrix hides non-filter UI layers. Both are real Godot captures.

## Rollout decision and remaining questions

Proceed with this as the approved working baseline for room-by-room art rollout. Keep the main aisle, service access and current live instruments unchanged. Use Step 10 to add only room-specific, serviceable detail; do not fill the remaining wall areas with arbitrary hardware.

Bounded follow-up questions for final operator review:

1. Whether any additional localized cable or mount detail is wanted on the hero rooms' open wall panels.
2. Whether the seated flashlight should read more clearly on side-console views, based on actual play rather than these fixed-angle comparisons.
3. Whether the small CRT text size at normal viewing distance feels right with the stronger analogue filter.

No unresolved collision, simulation or save/load defect blocks the rollout.
