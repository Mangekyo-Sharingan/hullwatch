# Step 12 — Final validation report

## Scope and checkpoint

- Branch: `feat/starpath-art-pass-2026-10-01`
- Source checkpoint: `5303882f04a33bf4a50bf4a5a6ec9cecf8cda11f`
- Art changes and review assets remain local and uncommitted. The original frozen manifest remains untouched.
- All twelve art-pass packets have implementation/report artifacts. This report separates passed automated evidence from work that could not be verified on this host.

## Automated verification

Godot 4.7.2 stable Linux x86_64 was used with per-suite `XDG_DATA_HOME` directories under `/tmp/hullwatch-art-step12-final`, keeping normal user saves and settings separate.

| Check | Result |
|---|---|
| Resource import | Exit 0; see native editor message below |
| Ship and world builders, run twice | Exit 0 with exact `PASS: build_ship_geometry` / `PASS: build_world_layout` markers; all three scene SHA256 values match across both generations |
| Startup smoke | Exit 0 |
| Full scripted suite | **89/89** current suites passed, including `smoke_test.gd`, with exact `PASS: <suite>` markers, exit 0, and no `SCRIPT ERROR` or parse error |
| `profile_scene.gd` | PASS: 0.41 ms scene delta under the headless dummy renderer; this does not measure rendered FPS |
| `profile_sim.gd` | **Over budget:** 201.8 µs/tick against 200 µs. The miss is 1.8 µs/tick (0.9%); no simulation tuning was made as part of the art pass |
| Diff whitespace check | `git diff --check` clean |

Full logs, the per-suite result JSON, and [`builder_determinism.json`](/tmp/hullwatch-art-step12-final/builder_determinism.json) are under `/tmp/hullwatch-art-step12-final/`. The generated hashes are `ship_geometry` `b1db6f53e9ed5039`, `dock_pod` `29cede89743908e1`, and `world_layout` `4c0c1328a688ce18`; each matches across both generations. The logs contain 7,117 native `ERROR`/`WARNING` lines, mostly repeated dummy-renderer shutdown leaks. Test-fixture errors include the deliberate corrupt-save path in `test_session_flow`, invalid puncture inputs in `test_hull`, and invalid-input guards exercised by the power, stores and settings suites.

The headless `--import` process also emits 843 repetitions of Godot's `Attempting to parent and popup a dialog that already has a parent` from `window.cpp:2297`, while exiting 0. The isolated import has no GDScript or parse errors. This editor message is unresolved and is recorded separately from the passing game suites.

## Work-cycle coverage

The system and scene suites cover the requested tasks in linked slices: diagnosis and physical refit (`test_operator_maintenance`), menu/pause/save/load (`test_session_flow`), transit and in-flight save restoration (`test_m11_voyage`), movement/seat transitions (`test_player_traversal`, `test_pilot_seat_flow`), airlock and EVA (`test_airlock_scene`, `test_eva_flow`, `test_tether`), and propulsion service/travel (`test_propulsion`). They all pass in the full run.

A single continuous manual play session was not completed. On the 2026-10-01 retry, X11 captures remained black under both Forward+ and compatibility and the Godot process waited on the NVIDIA DRM fence (`drm_syncobj_array_wait_timeout`). A direct Wayland Forward+ launch did render the main menu and identify the saved watch in slot 1 (day 0001, Drift Corridor). The menu also logged a JSON parse error for the existing 9-byte `slot_2.json`; no save file was changed. Sending keyboard input through KDE's Remote Desktop portal opened a PolicyKit prompt requesting “Control input devices” for Konsole. It was not approved and expired after 120 seconds, so the live run stopped at the menu. The Godot MCP editor bridge remained disconnected.

The nine work-cycle suites listed above were rerun sequentially with isolated user data under `/tmp/hullwatch-retry-2026-10-01/data`; each exited 0 with its `PASS` marker. This repeats scripted slice coverage but does not complete the continuous manual route. The rendered capture tool also produced and reviewed the real in-game stills listed in Step 11.

## Visual acceptance

The final interiors retain the original mottled Xenonite material, analogue filter strength, functional CRT stations, single-deck route, and practical-light behavior. Step 11 reviewed 17 real-render exterior/service captures under ordinary scene lighting and clearly labelled diagnostic lighting. The broad exterior is dark at a distance by design; close inspection uses the operator's actual flashlight.

The access map exposed a 0.75 m shell overlap between adjacent Quarters and Life Support pods. Construction now refuses the second build until the neighboring pod is removed; `test_module_scene` verifies the refusal and recovery. A legacy save already containing both pods is left intact.

## Remaining verification

- Re-run the continuous manual work cycle after the operator approves a suitable input-control path, including readout, diagnosis/refit, navigation, airlock/EVA, return and save/load.
- Investigate the `profile_sim` overrun before making a release performance claim; the CPU-timed headless measurement is close to the 200 µs limit.
- Verify on native Windows. No Windows build was exported or run, and no package was published.

The user authorized source work and validation. Release export and publication remain outside this authorization and were not performed.
