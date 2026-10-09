# Step 09 result — hero acceptance

## Review set

The six-row visual review is in [`hero_review.md`](../hero_review.md). It accepts the hero pair for the requested room-by-room rollout, while preserving three bounded questions for the operator's eventual visual review. The user's earlier approval was of the style direction; these captures are evidence for the final art handoff and are not presented as having been individually reviewed by the user.

Rendered evidence uses Godot 4.7.2 Forward+ at 1600×900 on the Linux host (NVIDIA GeForce GTX 1070 Ti). The 24-image matrix covers four combinations of real breaker/flashlight state across cockpit, utility, seated front/port/starboard and quarters. UI presentation layers are hidden except the analogue filter. The additional paired wall-terminal captures retain the gameplay HUD and show the existing folding interaction after its animation. Quarters captures show the generated layout with a real utility pod installed.

## Source and generated artifacts

- Branch: `feat/starpath-art-pass-2026-10-01`
- Base commit: `5303882f04a33bf4a50bf4a5a6ec9cecf8cda11f`
- Current changes remain local and uncommitted.
- `ship_geometry.tscn`: `57e90110baa6b109f85b5d6209dd25ed455c6694c5ed04fc761666c4dbaf0a14`
- `world_layout.tscn`: `4083fd627db7d0c5c76c4af177cc9d4d7634725bfa43b3c571d077df39b165d0`
- `mat_hero_frame_paint.tres`: `9b7c0619d811a6e6a11a0579710fe954c489804797d4898f66fdf29a3285d578`
- `hw_utility_spine.glb`: `cee7d7568cb8a03af40252d691f03402e5a180fa204c6eaa4a0ef77723a9770d`
- `build_world_layout.gd`: `44f9eb470a473535c8244e64d9fb2beeb31cd14e28e753459142ae30142525ed`
- Final `capture_screenshots.gd`: `694a8411baf386fd33d96bd78f64e01bfba430105684b0ed2ff1f4e5ad7d4f00`
- `test_module_scene.gd`: `63d298d1c218b9e67dab0955f2514d49a2e3d3dfb67dbc57b0d13f280dc7951c`

The generated ship and layout scenes were each built twice and matched byte-for-byte. Capture coordinates for the quarters locker and wall terminal were corrected to their tube-layout positions before the final capture run.

## Validation

The final source validation enumerates all `test_*.gd` files plus `smoke_test.gd`; the exact per-suite results are in [`step09_suite_results.json`](../review/step09_suite_results.json), with raw logs under `/tmp/hullwatch-art-step09/full-suite/`.

| Check | Result |
|---|---|
| `--headless --path game --import` | exit 0; no GDScript errors |
| `--headless --path game --quit` | exit 0 |
| `build_ship_geometry.gd`, twice | exit 0 both times; identical SHA-256 above |
| `build_world_layout.gd`, twice | exit 0 both times; identical SHA-256 above |
| Current complete headless suite | **89/89** exit 0, exact `PASS: <suite>` marker, no `SCRIPT ERROR` |
| `capture_screenshots.gd -- --hero-light-matrix` | exit 0; 24 images and `PASS: hero light matrix captures` |
| `capture_screenshots.gd` full tube capture | exit 0; `PASS: capture_screenshots`; final terminal/quarters camera positions visually reviewed |
| `profile_scene.gd` | exit 0; `PASS: profile_scene`; 6.90 ms baseline / 7.13 ms with scene / 0.23 ms difference in a throttled headless loop |
| `git diff --check` | pass |

The test log contains the known Godot `RendererDummy` shutdown resource-leak family after scene teardown. Input-validation suites intentionally emit errors for invalid IDs/types, and `test_session_flow` intentionally parses malformed JSON for its corrupt-save case. All affected suites reached their expected PASS markers; no unexpected `SCRIPT ERROR` or application error remained. Headless timing is not rendered FPS. No Windows-native runtime was exercised.

No art build, export or publication was performed. Step 10 begins with life support and proceeds one room at a time under the user's full-pass authorization.
