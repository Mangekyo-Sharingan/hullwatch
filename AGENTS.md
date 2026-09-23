# AGENTS.md — Hullwatch

Guide for AI coding agents working in this repository. Read this first, then `docs/PRODUCTION_SPEC.md` before any design or implementation work.

## Project

**Hullwatch** — first-person ship-maintenance sim with grounded dread horror. You are the lone operator of a decaying long-haul vessel; the gameplay is daily inspection, diagnosis, repair, and triage of interlocking ship systems. **No combat, no supernatural entity, no jumpscares.**

- Repo root: `E:\Projekt\Misc\OperationSpacer`
- Godot project root: `game/`
- Production spec: `docs/PRODUCTION_SPEC.md` (authoritative for design intent)
- Status: **v0.11.0 released for playtest** (GitHub release, exe attached) — dock pods, nanite builds and machines on top of the v0.10.0 mining/fabrication loop; v0.10.0 predates the modular ship and the door/material passes. Earlier: cramped faceted 8-space station, xenon-metal material, analogue-horror filter, CRT screens, practical lighting, hidden faults diagnosed with tools (spec §4.3), a comms system with weeks of latency and the one late reply (spec §4.1/§5), and the v0.6.0 playtest fixes (every readout closes with E or Esc from anywhere, tool results print a HUD line with a beep, the probe prompt names the carried tool). Real captures in `docs/store/` (10). The cockpit look pass landed too: a wraparound dash console bank and a solid forward window drawn by a procedural space shader (`game/src/shaders/space_window.gdshader`). Expansion **M7 complete** (M7.1–M7.7): airlock room + wiring (interlock, panel, suit locker), faceted polygonal hull (`HullProfile` + rewritten `build_ship_geometry.gd`: plan outlines, profile rings, mitered wall bands, flat-bottom hexagonal corridor, trimesh collision from the same surfaces), exterior hull + catwalk + aft deck + roof ramp + hardpoints, starfield sky + star light, tether with auto-clip and taut clamp, EVA HUD line, 9-page manual. Tests: `test_hull_profile`, `test_hull_exterior`, `test_tether`, `test_eva_flow`, `test_airlock`, `test_airlock_scene`. **M8 deep field complete (M8.1–M8.5)**: seeded `SectorSystem` chunk corridor (~2% content), `FieldStreamer` geometry binding (faceted asteroids, debris, anomalies), detection (status-panel CONTACTS list, scanner ping on primary mouse while carrying the scanner), close approach via the cockpit `ContactConsole` (fuel-gated, 30 m standoff with station-keeping, resume drift), save/load throughout. Tests: `test_sector`, `test_field_streamer`, `test_detection`, `test_approach`. **M9 materials & fabrication complete (M9.1–M9.5)**: `CargoSystem` hold, cutter + sample canisters + hull cargo port, power-gated `FabricatorSystem` with `.tres` recipes (water filter, O2 candle, CO2 filter, gasket), scanner anomaly salvage into exotic cargo, and a month-long mine -> fabricate -> replace loop proven headless, and a FIELD WORK manual page (10 pages). Tests: `test_cargo`, `test_mining`, `test_fabricator`, `test_anomaly_salvage`, `test_m9_loop`. **M10 modular ship complete (M10.1-M10.5)**: M10.1 module framework (`ShipModule`, `ModuleSystem`, `test_modules`); M10.2 dock geometry landed — four side-wall docks (`hp_quarters`, `hp_life_support`, `hp_galley`, `hp_engine_bay`) with 1 m doorways, throats to the hull band, flush mount plates (group `dock_plate`) + hardpoint markers (group `hardpoint`), and the generated generic `scenes/dock_pod.tscn` (`test_module_geometry`); roof hardpoints retired; M10.3 construction scene landed — the dock plate is the EVA mount (build menu with cost/stock/build hours), installing stands the pod up with its compartment + link wired, the pod carries its own teardown panel, and a loaded save rebuilds standing pods (`test_module_scene`). M10.4 catalog & function landed — seven pod kinds in `src/data/modules/` with effects wired into the sims (greenhouse rations, workshop bench speed, expanded storage, aux battery capacity, med bay recovery) and a machine-placement model: pods are bare rooms with three sockets each, any machine fits any socket, machines stack, portable ones come back out for a full refund, and the ship's vital machinery is bolted down (`test_module_catalog`, `test_module_effects`, `test_machine_fitting`). Open questions awaiting the operator: `docs/OPEN_QUESTIONS.md`. Plan and exit criteria in `docs/EXPANSION_SPEC.md`. **M13.1 section hull landed (2026-09-20):** `SectionHull` (`src/world/section_hull.gd`) owns the section table (the single dial that slims when the interior converts, M13.2) plus the prow/flange/rib/tank/array tables; `build_ship_geometry.gd` now sweeps a lathed chamfered-rectangle shell (framed prow cowl over the cockpit window, flange collars at the interior joints, rib rings, stern tank cluster, solar arrays on booms) — the hull's top facet is the roof walk, dock plates sit proud of the shell with sill slabs, the catwalk/ramp/anchors keep their positions, and `test_hull_profile`/`test_hull_exterior`/`test_module_geometry` were re-baselined (63 of 64 suites pass; the outlier is the known `test_failures` grep false positive). M13.2 groundwork landed: `TubeLayout` (`src/world/tube_layout.gd`) holds the room-to-section chain (train layout, 11 sections, bow cupola to stern tank) with deck-area parity against the flat rooms, hatch rules and radial dock ports, validated by `test_tube_layout`. **M13.2 tube interior flipped (2026-09-21):** both generators build tube mode (`INTERIOR_STYLE = "tube"`; `-- --interior-style=flat` still works) — the interior is one swept tunnel per section joined by necks with bulkhead hatches, every prop/door/zone/link carried onto the chain, section doors ship open (airlock hatches shut), ceiling pipe runs, throat sleeves from each port to its plate/hatch leaf, the drum belly dropped below the deck plane (`TUBE_DRUM_DECK_DROP`) so the deck stops z-fighting, and the solar arrays re-anchored to the stern tank. Two generator faults found in play are fixed with permanent guards in `test_hull_exterior`: `_test_no_sightlines_out` (a 64-ray fan from eye height in every room must hit geometry — the bug that left port walls open to space) and `_test_no_outboard_geometry` (no fitting may sit outside the hull's reach — the flat-coordinate arrays/throats). `test_ship_layout` is re-baselined for the chain and the flat `OmniLight3D`s moved out of `main.tscn` into the tube's cabin lights. **M13.2 closed (2026-09-24):** the carried props now settle against the real wall (`_prop_bounds` walks to the layout root), and `test_world_layout` measures the true wall line and the lane to the opposite wall — 66/66 suites green. **M13.3 landed (2026-09-24):** the tube dock bore is 1.2 m to match the interior doors (Q6), a truss walkway with rails and posts runs from the EVA platform toward the life support dock (stopping clear of a standing pod's bay, its end within reach of the mount plate), the bow/stern tether anchors are mounted on the drum walls, and `test_module_scene` asserts the build -> enter-a-pod-on-foot walk from the room. **Original Blender kits landed:** the cockpit hero kit (CRT console, status board, switch bank, gauge cluster, seven-segment), the pod machine kit (six machines) and the life-support machinery kit (scrubber, reclaimer, fabricator, breaker cabinet) are authored in `art/blender/`, exported to `game/assets/models/hullwatch/`; machines render their authored glTF in the sockets (`ShipMachine.model_path`, box fallback), the machinery replaces its procedural props, the seven interactive CRT props render the authored consoles (phosphor tint on load via `crt_screen.gd`), and four cockpit pieces dress the chain as carried props.
- **Hull form canon:** the ship is a faceted polygonal form — plan polygons extruded through profile rings, flat-bottom hexagonal corridor, mitered flush joins, no overlapping slabs or protruding edges; collision is generated from the same surfaces (`HullProfile` + `build_ship_geometry.gd`); generated geometry is never hand-edited.
- **Builds vs. source:** `v0.10.0` is the current playtest build (GitHub release, exe attached); `v0.9.0` predates mining, fabrication and anomaly salvage, and `v0.7.0` predates the polygonal hull, EVA, airlock and tether. Always `.\build.ps1` and verify the feature is present in the exe before handing a build to a tester.
- **Early-access expansion (weeks, features first):** open hull + EVA, streaming deep field (~98% empty), materials/fabrication, modular ship, planets/stars to travel to — milestones **M7–M12** and design rules in `docs/EXPANSION_SPEC.md`; polish is M12, do not pull it forward.
- Asset shortlist for the M3 art pass: `docs/ASSET_SOURCES.md` — acquire at M3, not before

## Tech Stack

| Item | Value |
|---|---|
| Engine | Godot 4.7.2 stable, Forward+ — local binary in `Engine/` (gitignored); on the Linux night-worker use `./Engine/Godot_v4.7.2-stable_linux.x86_64` with the same arguments |
| Language | GDScript (static typing required) |
| Art pipeline | Blender 5.1 → glTF 2.0 |
| VCS | Git + Git LFS (`.gitattributes` tracks art/audio binaries) |
| AI tooling | Godot MCP installed (`godot-editor-mcp` 2026.9.17, hybridindie); Blender MCP (M3) |

## Commands

Run from repo root. The engine binary is local, so no PATH setup is needed.

```powershell
# Run the game (or just double-click play.bat)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game

# Build the single-file Windows test build (release; -Debug for debug build)
.\build.ps1
.\build.ps1 -Debug

# Open editor (GUI)
& ".\Engine\Godot_v4.7.2-stable_win64.exe" --editor --path game

# Headless smoke test — run after every change that touches scripts/scenes
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --quit

# Headless script tests (exit code 0 = pass) — run all before considering work done
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/smoke_test.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_stores.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_wear_model.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_power.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_atmosphere.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_thermal.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_player.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_interactables.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_occupancy.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_audio.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_footsteps.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_carry.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_rations.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_day_loop.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_ui.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_ui_scale.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scroll_menu.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_survival_3day.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_save_load.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scene_save_load.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_failures.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scenario_power_night.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scenario_cascade.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scenario_humidity.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_hull.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_vitals.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_manual.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_nav.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_component_breadth.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_water.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_humidity.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_ship_layout.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_world_layout.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_door.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_m4_extras.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_settings.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_save_migration.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_localization.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_analogue_filter.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_crt_panels.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_diagnostics.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_diagnostics_api.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_comms.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_airlock.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_airlock_scene.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_hull_profile.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_hull_exterior.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_tether.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_eva_flow.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_sector.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_field_streamer.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_detection.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_approach.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_cargo.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_mining.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_fabricator.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_anomaly_salvage.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_m9_loop.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_modules.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_module_geometry.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_module_scene.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_module_catalog.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_module_effects.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_machine_fitting.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_tube_layout.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scene_loop.gd

# Regenerate the localization string table after changing user-facing UI strings
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/extract_strings.gd

# Regenerate the generated scenes after editing their tables (ship_geometry + dock_pod, and world_layout)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_world_layout.gd

# Capture in-game screenshots for review/store (WINDOWED — rendering required; writes to user://captures)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game --resolution 1600x900 --script res://tools/capture_screenshots.gd

# Performance regression guards (sim tick cost / scene frame cost)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/profile_sim.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/profile_scene.gd

# Refresh the global class cache after adding new `class_name` scripts (needed before --script test runs)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --import

# Regenerate Input Map actions after editing the tables in game/tools/setup_input_map.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/setup_input_map.gd
```

There is no linter configured yet; typed GDScript analyzer warnings in the editor are treated as must-fix. If a linter is added, update this file.

## Repository Layout

```
Engine/                  # local Godot binaries — NEVER commit, NEVER edit
docs/                    # production spec, design docs
game/                    # Godot project root
  project.godot          # project config (autoloads: SimClock, EventBus, AudioDirector, SaveManager, GameSettings)
  scenes/                # .tscn scene files
  tests/                 # headless suites; tests/support/harness.gd = SimHarness scenario scaffolding
  tools/                 # dev-only scripts (input map, geometry/layout builders, captures, profilers, string extraction)
  assets/                # textures/, models/ (CC0 only; credits in docs/ASSET_CREDITS.md), audio/, fonts/ (procedural placeholder audio needs no files)
  src/
    autoload/            # singletons: SimClock, EventBus, AudioDirector, SaveManager, GameSettings
    audio/               # procedural placeholder PCM factories (ProcAudio)
    systems/             # simulators: power, thermal, atmosphere, hull, nav, comms, stores
    components/          # wear model + failure-mode + config resources
    interactables/       # panels, valves, filters, tools
    world/               # world-side drivers into sims (CompartmentZone occupancy)
    player/              # controller, interact, carry
    ui/                  # HUD, CRT panels, status panel, scroll menu, settings, overlays (diegetic UI, ui_scale)
    data/                # .tres content (components, items, procedures, wear)
  assets/                # art/, audio/, fonts/
tools/                   # dev utilities, MCP configs
```

## Architecture Rules (binding)

1. **State lives in simulators** (`src/systems/`). Nodes render and interact; they never hold authoritative state.
2. **Signals, not polling.** Publish typed events on `EventBus` (`power_brownout`, `component_failed`, `compartment_pressure_changed`). Systems never reference UI.
3. **Data over code.** New components, faults, and items are `.tres` resources. Never hardcode balance numbers in scripts.
4. **Fixed-tick simulation (10 Hz)** decoupled from `_process`. Never run sim logic per-frame.
5. **Deterministic.** Same seed + same inputs = same failures. Required for save/load fidelity and tests.
6. **Headless-testable.** Core sim must run with `--headless` under scripted scenarios.
7. **Save/load from day one** once state exists: versioned saves + round-trip tests. Systems implement `save_state()/load_state(dict)`; `SaveManager` (autoload) collects them by group + interactables by node path into `user://saves/slot_N.json`; bump `SAVE_VERSION` and add a `_migrate` step for shape changes; never store 64-bit ints as JSON numbers (stringify RNG states).

## Code Conventions

- **Typed GDScript everywhere** (`var x: float = 0.0`, `func f(a: int) -> void:`) — no untyped vars.
- Files `snake_case.gd`; classes `PascalCase`; constants `SCREAMING_SNAKE_CASE`; signals past tense (`component_failed`).
- One class per file, `class_name` only when the type is used elsewhere.
- No comments explaining *what* — only non-obvious *why*. Design rationale belongs in docs.
- Commit style: `feat:`, `fix:`, `sim:`, `art:`, `docs:`, `chore:` (conventional-ish, imperative mood).

## Design Guardrails (do not violate)

- No combat, weapons, or threats with agency.
- No supernatural entities, no jumpscares, no scripted "gotcha" moments.
- No multiplayer code at launch; don't architect in a way that precludes post-launch co-op.
- No seamless procedural galaxy; travel is waypoint legs.
- Maintenance interactions are diegetic and skill-based (procedures), never abstract progress bars.
- Audio and diegetic UI are first-class systems, not polish.

## Working With This Repo

- **Before implementing a mechanic:** check the spec for its intended system (§4), then check whether a data resource for it already exists in `game/src/data/`.
- **When adding content:** add data first (`.tres` + a simulator hook), UI last. A feature without sim support is a mock.
- **Before any playtest:** rebuild the exe (`.\build.ps1`) and confirm the feature is present in it. v0.6.0 predates diagnostics/comms and confused a tester; a stale build wastes a playtest round.
- **After changes:** run the headless smoke test; if sim state changed, add/extend a deterministic scenario test.
- **Art assets:** only CC0 (or similarly clean) assets, recorded in `docs/ASSET_CREDITS.md`; imported materials are `.tres` in `src/data/materials/`; never hand-edit imported `.import` files.
- **Ship geometry is generated:** edit the room table in `tools/build_ship_geometry.gd`, then rerun it to regenerate `scenes/ship_geometry.tscn` (deterministic output); never hand-edit the generated scene.
- **Milestone discipline:** do not build ahead of the current milestone (spec §8.2) — vertical slice logic before content scale, ever.
- **Open questions** (spec §9) are unresolved by design; ask the user before deciding narrative or scope items listed there.

## Sub-Agent Parallelization (required practice)

Maximize time efficiency by spinning up sub-agents (task tool) whenever workstreams are parallelizable:

- **Parallelize:** independent workstreams with disjoint file ownership; research/exploration; independent verification of another agent's output.
- **Never parallelize:** edits to the same file; work where one stream consumes another's not-yet-written interface (pin the interface in both prompts first, then parallelize).
- **Rule of one writer:** every file has exactly one owner per workstream. List the owned paths explicitly in each sub-agent prompt.
- **Pin interfaces before fan-out:** exact signatures, file paths, autoload names, and data formats go in the prompt — not discovered mid-task.
- **Verify per agent:** each sub-agent runs the relevant headless command and reports exact output; the parent re-runs the full smoke test after all agents land.
- **Return format:** sub-agents report — files created/modified, commands run, observed results, blockers. No summaries of code.

## MCP Tooling

- **Godot MCP is installed** (hybridindie `godot-editor-mcp` 2026.9.17, Python user-site). Server binary: `C:\Users\adamh\AppData\Roaming\Python\Python314\Scripts\godot-editor-mcp.exe` (stdio transport; editor bridge listens on `ws://127.0.0.1:9080`). Registered in the global opencode config as MCP server name `godot`.
- The editor addon lives at `game/addons/godot_mcp/` (plugin name `godot_mcp`) and is enabled in `project.godot`. If the MCP dock does not connect, restart the Godot editor — the addon auto-reconnects to the bridge.
- Runtime/game-side MCP tools additionally require the `godot_runtime_probe.gd` autoload from the addon docs; editor tools (scene authoring, inspection) work without it.
- Prefer MCP tools for scene inspection/manipulation when the Godot editor is open; fall back to direct `.tscn`/`.gd` file editing (both are text formats) when it is not.
- Blender MCP is an M3 task. Do not block modeling work on it.
