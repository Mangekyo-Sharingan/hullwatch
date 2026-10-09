# 07 — Shape the hero with practical light

## Objective

Create warm pools of usable light, darker structural recesses and readable instruments. Requires 06. The player's work and route must remain discoverable.

## Owned files

`game/tools/build_ship_geometry.gd`; generated scene; `game/src/world/cabin_light.gd` only if a documented fixture behavior change requires it; `game/tests/test_cabin_light.gd`; `game/tests/test_hero_cabins.gd`; authored lighting-kit source/export only if the existing fixture cannot fit; capture tool for specific review shots; result document.

## Procedure

1. Evaluate the actual scene without temporary capture work lights. Mark visible fixture sources, falloff, shadows, screen contrast and dark route/maintenance targets. The WIP's warmer 1.65-energy/4.2-range Omni settings are a starting point, not accepted tuning.
2. Tune existing fixtures first: position, color, range and shadow behavior. Bright regions should be explained by visible lamps. Do not crank global ambient light, screen emission or exposure until every surface looks equally lit.
3. Avoid lighting the operator with a hidden permanent camera lamp. Preserve the flashlight's actual gameplay role. Inspect beams hitting conduits/upper frames for excessive shadow clutter.
4. Retain the existing breaker/EventBus integration. If a SpotLight is genuinely required, account for `cabin_light.gd` currently extending `OmniLight3D`; do not attach it to an incompatible node. Prefer a small correct adaptation over a new lighting framework. Do not add simulation-owned load/state without corresponding data and a real requirement.
5. Check light-off behavior: fixtures and physical readouts must behave consistently with their existing circuits. Review save restoration and brownout/shedding behavior using the established event paths.
6. Capture identical wide/close/seated angles with lights on/off and torch on/off. Keep resolution, camera pose, filter, settings and scene state fixed. Record all light changes as actual scene parameters.
7. Measure headless scene delta for regressions and render performance on available hardware; clearly identify which is measured. Do not report dummy-renderer timing as actual FPS.

## Acceptance

The aisle, hatch edges, seat and maintenance targets are usable. Instruments remain readable; layered structure has depth; warm light sources are diegetic. No new white-out, permanent unexplained illumination or light that ignores the breaker. Differences between on/off states are captured honestly.

## Validation

Startup smoke, `smoke_test`, `test_cabin_light`, `test_hero_cabins`, `test_scene_loop`, `test_pilot_seat_flow`; relevant CRT/filter checks if affected. Run `tools/profile_scene.gd` and document hardware/settings for any rendered timing. Report the controls/event path tested, not just screenshots.
