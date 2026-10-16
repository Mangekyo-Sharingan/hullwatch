# Generated ship instances: import-warning diagnosis and fix

Date: 2026-10-14. Godot 4.7.2 stable Linux x86_64, `ed1daf0bf`.
Status: source fix and generated scenes landed locally; focused checks pass. No release/build publication or native Windows/editor acceptance in this pass.

## Cause and resulting behavior

The repeated `Attempting to parent and popup a dialog that already has a parent` errors were a secondary editor symptom of duplicate authored-model children in `ship_geometry.tscn`.

`build_ship_geometry.gd::_assign_owners()` assigned the generated root as owner of every imported GLB descendant. Packing then saved both an external scene instance and new typed children already supplied by that instance. For example, the ceiling-lamp Model instanced `hw_ceiling_lamp.glb` and also declared its lamp/plate/mesh hierarchy again. The world-layout generator already stopped ownership recursion at imported scene boundaries; its scene imported cleanly.

In the exact engine revision, [SceneState instantiation](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/resources/packed_scene.cpp#L519) detects the name collision and requests an editor warning. [EditorNode's warning handler](https://github.com/godotengine/godot/blob/ed1daf0bf/editor/editor_node.cpp#L5536) repeatedly opens the same dialog, and [Window's exclusive-popup guard](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/main/window.cpp#L2295) rejects its existing parent. This explains why errors clustered under scene reopening after asset import had completed.

The generator now keeps each GLB's internal ownership, instances authored models with editor state for serialization, and marks only the ion-drive Model instances editable. Their plume visibility and translucent material override save as inherited properties, without duplicating their geometry. Existing normalization also removes per-run parent-ID metadata; stable node paths remain the ancestry reference.

This is a generator correction. MCP stays enabled. Engine binaries, asset import files, original art and user settings/saves were untouched.

## Reproduction and controls

All experiments used disposable projects and isolated XDG data/config/cache directories. The real-project copy excluded root test/tool development directories; model assets and imported cache were retained. The first copy accidentally also excluded the hand-tool asset directory because the ignore rule was recursive. Its zero-warning result had missing-resource errors and was discarded; corrected controls below have no script errors or unrelated errors.

| Experiment | Exit | Popup-parent errors | Result |
| --- | --- | --- | --- |
| Minimal Node3D scene: 0 / 1 / 25 BoxMesh nodes | 0 each | 0 each | Ordinary 3D reopening is clean |
| Corrected copied project, Main reopened, isolated editor defaults | 0 | 875 | Original bug reproduced |
| Same copy with copied operator editor settings | 0 | 875 | User editor preferences do not explain it |
| Clear only copied editor's open-scene list | 0 | 0 | Scene reopening is the trigger |
| Disable MCP only in the copy | 0 | 875 | Addon is not the cause |
| Fresh editor metadata, same Main reopened | 0 | 875 | Old editor metadata is not the cause |
| Reopen only player / world_layout | 0 each | 0 each | Those scene trees are clean |
| Reopen only ship_geometry | 0 | 875 | Generated ship tree isolates the trigger |
| Minimal nested scene with three duplicate children | 0 | 2 | Same exact native popup error without addons, assets or gameplay |
| Same nested scene with instance reference only | 0 | 0 | Eliminating duplicate children removes it |
| Editor-state instantiation alone, old recursive ownership | 0 | 875 | Ownership correction is essential |
| Corrected ownership and inherited ion overrides | 0 | 0 | Candidate fixes the actual trigger |
| Final main-generated scenes, MCP enabled, Main reopened | 0 | 0 | Original configuration is clean |

The reproducible command is the existing engine import invocation against the isolated copy:

```bash
XDG_DATA_HOME=/tmp/hullwatch-import-replay-t3m86ej0/data \
XDG_CONFIG_HOME=/tmp/hullwatch-import-replay-t3m86ej0/config \
XDG_CACHE_HOME=/tmp/hullwatch-import-replay-t3m86ej0/cache \
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --path /tmp/hullwatch-import-replay-t3m86ej0/project --import
```

Retained experiment counts/log paths: `/tmp/hullwatch-import-replay-t3m86ej0/results.json`; minimal scene controls `/tmp/hullwatch-import-minimal-pb6ppf7v/results.json`; minimal name-clash fixture `/tmp/hullwatch-import-clash-kulwbdfb/results.json`. Final clean import log: `/tmp/hullwatch-import-replay-t3m86ej0/final_addon_enabled_import.log`.

## Source regression and validation

`test_hull_exterior.gd` now compares each authored Model's loaded subtree size against its source GLB, and checks both ion plumes retain their translucent unshaded override. Against the original scene, the guard failed 43 checks: 41 duplicate subtrees and two lost overrides on the canonical plume nodes. Against the regenerated scene, all checks pass. Existing hull closure, fittings, physics passages, lights/groups and propulsion behavior remain covered by their existing suites.

Main generator ran twice using isolated user data. Both runs exited 0, printed `PASS: build_ship_geometry`, and had no script errors. Final SHA256 values match across both runs:

| Generated scene | SHA256 |
| --- | --- |
| ship_geometry.tscn | d44bc9b3d5e4dfa08a5ab44c1cebe96d48ca24e91cdfbed6cff2a0683af0396f |
| dock_pod.tscn | 7fdc9c8c0d9ce1b52a01ad0cb5755f03f4479e4e0bcc567fc47ab13e2087a82b |

Focused main checks: `test_hull_exterior`, `test_propulsion`, `test_cabin_light`, `test_module_geometry`, `test_module_scene` — each exit 0, exact suite PASS, zero script errors. Logs and generator receipts are in `/tmp/hullwatch-import-main-20261014/`. Existing headless dummy-renderer shutdown leaks are separate from the import symptom; they are not declared resolved by this correction.

An intermediate test incorrectly required the emission flag on an unshaded material; serialization omits that redundant setting. The final check tests the persisted override, transparency, unshaded mode and alpha. An intermediate candidate also exposed random parent-ID metadata; extending the existing ID normalization fixed deterministic output while retaining reloaded plume properties.

The parent owns the subsequent full-suite run, dashboard gate evidence, native rendering review and any delivered build. This report records this pass's exact focused and import checks; historical 843/875-error receipts remain historical evidence.
