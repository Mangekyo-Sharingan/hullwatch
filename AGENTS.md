# AGENTS.md — Hullwatch

Guide for AI coding agents working in this repository. Read this first, then `docs/PRODUCTION_SPEC.md` before any design or implementation work.

## Project

**Hullwatch** — first-person ship-maintenance sim with grounded dread horror. You are the lone operator of a decaying long-haul vessel; the gameplay is daily inspection, diagnosis, repair, and triage of interlocking ship systems. **No combat, no supernatural entity, no jumpscares.**

- Repo root: `E:\Projekt\Misc\OperationSpacer`
- Godot project root: `game/`
- Production spec: `docs/PRODUCTION_SPEC.md` (authoritative for design intent)
- Status: **M0 — Setup** (see Milestones in spec §8.2)

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
# Run the game
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game

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
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_player.gd

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
  project.godot          # project config (autoloads: SimClock, EventBus; Forward+)
  scenes/                # .tscn scene files
  tools/                 # dev-only scripts (input map regeneration)
  src/
    autoload/            # singletons: SimClock, EventBus, ShipState, SaveManager, AudioDirector
    systems/             # simulators: power, thermal, atmosphere, hull, nav, comms, stores
    components/          # wear model + failure-mode resources
    interactables/       # panels, valves, filters, tools
    player/              # controller, interact, carry, scanner
    ui/                  # diegetic UI, manual binder, log reader
    data/                # .tres content (components, items, procedures)
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
7. **Save/load from day one** once state exists: versioned saves + round-trip tests.

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
- **After changes:** run the headless smoke test; if sim state changed, add/extend a deterministic scenario test.
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
