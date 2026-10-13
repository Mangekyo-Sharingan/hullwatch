# Native lighting captures — 2026-10-12

Owned capture files: `game/tools/capture_lighting_pass.gd`, its UID, and this note.
The script inherits the existing interior-gate capture helper. It loads real
`main.tscn`, pauses SimClock before scene creation and again after initialization,
disables player movement, hides UI except the existing analogue filter, opens
interior doors, and captures native Forward+ frames without lighting overrides.
Camera near 0.05 m, FOV 80°, resolution 1600×900, flashlight off. Cabin poses
match the gate's six cardinal views; permanent bay poses match its entry views.

## BEFORE evidence

Complete packet: `build/lighting_power/2026-10-12-retry/before_manifest.json`
with 26 PNGs: cockpit, galley, life_support and engine_bay_b (six each), plus
permanent life-support and galley bay entries. Native Wayland, Vulkan Forward+,
NVIDIA GeForce GTX 1070 Ti. Filter enabled, intensity 1.0. Lighting registry API
was absent; only genuine fresh-scene all-on state was captured. Parent was sent
the completion signal before being released to edit lighting/generation values.

Observed baseline: generation **500 W**, total demand **640 W**, lighting
**200 W**, battery **4000/4000 Wh**. Every circuit breaker is on, none shed,
no brownout. `load_w` is **0 W** because this fresh simulation is paused before
any power tick; it is not a measured steady-state served draw. Demand exceeds
generation by 140 W. The manifest records power status, generator/breaker/wear
save-state data, source loads, registry availability, camera poses and filter.

Command (repository root):

```bash
XDG_DATA_HOME=/tmp/hullwatch-lighting-before-20261012 ./Engine/Godot_v4.7.2-stable_linux.x86_64 --display-driver wayland --path game --resolution 1600x900 --script res://tools/capture_lighting_pass.gd -- --output=/home/uru/Projekt/OperationSpacer/build/lighting_power/2026-10-12-retry --label=before
```

Exit **0**; exact success line:
`PASS: capture_lighting_pass (before, 26 views)`.
Independent manifest/file check printed `PASS: baseline manifest and 26 PNGs`.
Galley bay entry PNG visually inspected: real rendered geometry and analogue
filter visible, not a black image. Full visual acceptance remains a parent/
operator review task.

The first attempt used `build/lighting_power/2026-10-12/`: all 26 PNGs rendered,
then metadata failed with `Nonexistent function 'save_state (via call)' in base
'Node (settings.gd)'`. That run was terminated and its empty manifest is invalid.
The script now reads the two actual filter properties. Use only the retry packet.
The successful retry printed renderer/RID/resource shutdown leak diagnostics
after PASS, including `Pages in use exist at exit in PagedAllocator` and
`576 resources still in use at exit`; these do not invalidate the saved PNGs.

## AFTER invocation

```bash
XDG_DATA_HOME=/tmp/hullwatch-lighting-after-20261012 ./Engine/Godot_v4.7.2-stable_linux.x86_64 --display-driver wayland --path game --resolution 1600x900 --script res://tools/capture_lighting_pass.gd -- --output=/home/uru/Projekt/OperationSpacer/build/lighting_power/2026-10-12-retry --label=after
```

Requires `get_lighting_status() -> Dictionary` and
`set_light_enabled(StringName, bool) -> bool`. It captures all-on, then leaves
only registry IDs containing `cockpit` or `life_support` enabled and captures
selective-off (52 views total). Each state records actual demand, generation,
battery and source/fixture state. No generator, circuit-load or light-energy
override is performed. A missing/empty registry or refused fixture switch fails
the run. Existing labeled evidence is protected from overwrite.

AFTER has not run. The parent reports the fixture registry, generator and pod
lighting implemented, with generation underway. At the parent's request, AFTER
capture is deferred until its visual tuning is ready. Ownership of this capture
tool and note now returns to the parent, including AFTER execution, full-suite
validation, result/status/roadmap and dashboard writes. The worker has validated
only the BEFORE path and startup smoke; the AFTER path remains unexecuted.

Fresh startup smoke:
`XDG_DATA_HOME=/tmp/hullwatch-lighting-smoke-20261012 ./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --quit`.
Exit 0, engine banner and `WARNING: 8 ObjectDB instances were leaked at exit`;
no script/parse errors. No systems, generators, game scenes or tests edited.

## Parent final result

Current validated packet: build/lighting_power/2026-10-12-verified. Native AFTER
exit0, exact PASS60 views; original BEFORE26 views copied byte-for-byte. Final
AFTER adds on/off pod and exterior inspection. All86 frames reviewed. Two
intermediate after packets were superseded as emitter and restore bugs were
fixed; complete packet stalled in native shutdown and was terminated after
verified futex wait. Final script frees the main scene and drains two frames
before quitting; final native process exits0. No script/resource-load failures.
Existing shutdown resource/RID warnings persist. A capture metadata erratum
records module-only construction ticks; source/PNG brightness is not edited.
See README.md/results.json for source validation and operator/build boundaries.
