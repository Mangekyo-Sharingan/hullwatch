# Step 07 — Practical light and circuit behavior

## Changes

- Hero section ceiling fixtures now use warm `Color(1.0, 0.74, 0.49)`, energy `2.0`, and range `4.8` (previously 1.65 / 4.2). The light remains localized, shadowed, and attached to the existing visible ceiling-lamp fitting. Non-hero fixtures are unchanged; global ambient, exposure, filter, screen emission, and flashlight settings were not altered.
- Added a `--hero-light-matrix` mode to the existing screenshot tool. It captures four repeatable angles (cockpit wide, utility close, actual seated pilot view, quarters context) with cabin lights on/off and the real player flashlight on/off. It switches the breaker through `BreakerPanel.interact`, toggles the flashlight with its `InputEventAction`, boards/exits the real pilot chair, hides only presentation CanvasLayers, and adds no capture work lights at these interior positions.
- Fixed circuit-light visibility after save restoration. `PowerSystem.load_state()` now emits `power_state_restored`; `CabinLight` resynchronizes from simulator state on that event. This avoids synthesizing `breaker_toggled` and recording a false operator action. The test covers manual breaker toggles, automatic shedding/restoration, and a restored saved-off breaker state.

## Visual review

All 16 final images are under [`review/`](../review/) and use the `hero_light_{cockpit|utility|seated|quarters}_lights_{on|off}_torch_{on|off}.png` name pattern. Examples: [utility, fixtures on](../review/hero_light_utility_lights_on_torch_off.png), [utility, fixtures and torch off](../review/hero_light_utility_lights_off_torch_off.png), [utility, torch on](../review/hero_light_utility_lights_off_torch_on.png), [seated, fixtures on](../review/hero_light_seated_lights_on_torch_off.png), [seated, fixtures off](../review/hero_light_seated_lights_off_torch_off.png).

The on state gives a restrained warm pool around the hardware and leaves the wall mottling intact. The off/torch-on pair shows the flashlight's focused work pool, while the seated captures show the existing CRT and analog instruments remain legible when cabin lights are off. The dark ambience is intentional for the grounded horror tone; the aisle, hatch surrounds and major targets stay discernible under fixtures or flashlight. No hidden permanent camera light or fake warning lights were used.

Captures ran at 1600×900 with Godot 4.7.2 Forward+ on NVIDIA GeForce GTX 1070 Ti, ordinary project settings and the unchanged analogue filter. They are rendered views, but no frame-time/FPS measurement was taken. The presentation captures temporarily hide HUD CanvasLayers; gameplay and functional behavior were validated separately.

## Validation

Both ship-geometry builder runs exited 0 and produced the same scene SHA-256: `57e90110baa6b109f85b5d6209dd25ed455c6694c5ed04fc761666c4dbaf0a14`.

Exact markers, exit 0, no script errors or `FAIL:` lines:

- Startup `--quit`
- `smoke_test`
- `test_cabin_light`
- `test_hero_cabins`
- `test_scene_loop`
- `test_pilot_seat_flow`
- `test_crt_panels`
- `test_analogue_filter`
- `test_scene_save_load`
- `profile_scene`

`test_cabin_light` confirms lighting breaker open/close, circuit shedding during a real `PowerSystem.sim_tick`, restoration when generation returns, and lamp visibility after loading a saved breaker-off state. `test_scene_save_load` also passes its full SaveManager round trip. The headless scene profiler reports 6.90 ms baseline / 6.99 ms with scene, 0.09 ms additional scene cost; it explicitly reports a throttled headless loop, so this is not rendered FPS. The captured real renderer was Forward+ on the GPU listed above.

The existing RendererDummy shutdown leak family still appears in headless scene suites. The windowed capture also reports renderer resource leaks at process exit, after its successful `PASS: hero light matrix captures`; no script errors or capture failures occurred. Step 06 separately records the native popup-parent errors from editor-backed `--import`.

Logs: `/tmp/hullwatch-art-step07/`.

## Handoff to Step 08

Reuse the hero rib paint, dark backers, cable trays/clips and warm localized lamp settings in quarters. Keep the bunk/locker, clear aisle, sleep flow, service hatch, and dock access intact. Step 09 owns clean paired hero acceptance captures and the full suite.
