# AGENTS.md — Hullwatch

Guide for AI coding agents working in this repository. Read this first, then `docs/PRODUCTION_SPEC.md` before any design or implementation work.

## Project

**Hullwatch** — first-person ship-maintenance sim with grounded dread horror. You are the lone operator of a decaying long-haul vessel; the gameplay is daily inspection, diagnosis, repair, and triage of interlocking ship systems. **No combat, no supernatural entity, no jumpscares.**

- Repo root: `E:\Projekt\Misc\OperationSpacer`
- Godot project root: `game/`
- Production spec: `docs/PRODUCTION_SPEC.md` (authoritative for design intent)
- Status: **v0.7.0 released for playtest** — cramped faceted 8-space station, xenon-metal material, analogue-horror filter, CRT screens, practical lighting, hidden faults diagnosed with tools (spec §4.3), a comms system with weeks of latency and the one late reply (spec §4.1/§5), and the v0.6.0 playtest fixes (every readout closes with E or Esc from anywhere, tool results print a HUD line with a beep, the probe prompt names the carried tool). Real captures in `docs/store/` (10). Next: the v0.7.0 playtest feedback round. Expansion **M7 in progress**: airlock pressure-cycle sim, vacuum exposure and EVA suit landed sim-side (`AirlockSystem`, `test_airlock`); geometry/airlock module, panel, tether next.
- **Builds vs. source:** `v0.7.0` is the current playtest build (GitHub release, exe attached); `v0.6.0` predates diagnostics/comms and produced the first feedback round only. Always `.\build.ps1` and verify the feature is present in the exe before handing a build to a tester.
- **Early-access expansion (weeks, features first):** open hull + EVA, streaming deep field (~98% empty), materials/fabrication, modular ship, planets/stars to travel to — milestones **M7–M12** and design rules in `docs/EXPANSION_SPEC.md`; polish is M12, do not pull it forward.
- Asset shortlist for the M3 art pass: `docs/ASSET_SOURCES.md` — acquire at M3, not before

## Tech Stack

| Item | Value |
|---|---|
| Engine | Godot 4.7.2 stable, Forward+ — local binary in `Engine/` (gitignored) |
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
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scene_loop.gd

# Regenerate the localization string table after changing user-facing UI strings
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/extract_strings.gd

# Regenerate the layout scenes after editing their tables (geometry / props+zones+links)
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
