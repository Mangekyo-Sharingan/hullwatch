# AGENTS.md — Hullwatch

Guide for AI coding agents working in this repository. Read this first, then `docs/PRODUCTION_SPEC.md` before any design or implementation work.

## Project

**Hullwatch** — first-person ship-maintenance sim with grounded dread horror. You are the lone operator of a decaying long-haul vessel; the gameplay is daily inspection, diagnosis, repair, and triage of interlocking ship systems. **No combat, no supernatural entity, no jumpscares.**

- Repo root: `E:\Projekt\Misc\OperationSpacer`
- Godot project root: `game/`
- Production spec: `docs/PRODUCTION_SPEC.md` (authoritative for design intent)
- Status: **feature-frozen for Early Access** (operator decision 2026-10-15). The only work queue is the active EA slice in `docs/dashboard/roadmap.json` (`ea_plan`); delivered builds are listed under `checkpoint.delivered` there. What was built through M14 is in `docs/PROJECT_HISTORY.md`.
- Platforms: **Windows, Linux and Steam Deck** at Early Access. This machine is the Linux development host; the operator playtests on Windows. `main` has only Windows export presets so far; the Deck build lives on branch `playtest/steamdeck` (`EA10.6` brings Linux/Deck onto `main`).
- **Hull form canon:** the ship is a faceted polygonal form — plan polygons extruded through profile rings, flat-bottom hexagonal corridor, mitered flush joins, no overlapping slabs or protruding edges; collision is generated from the same surfaces (`HullProfile` + `build_ship_geometry.gd`); generated geometry is never hand-edited.

## EA build rules (binding — operator decision 2026-10-15)

The game is feature-frozen for Early Access (*freeze & finish*: no new systems). The
only work queue is the ordered slice list `ea_plan.slices` (`EA01`–`EA12`) in
`docs/dashboard/roadmap.json`; the dashboard shows the active slice and the "not now" list.

1. **One slice at a time.** Work only on the active slice: the first slice that is not
   `complete` or `blocked`. Never start the next slice while one is `in_progress` or
   `needs_review`.
2. **The operator owns the plan.** Never add, remove, reorder or re-scope slices, and never
   add milestones. Work outside the active slice happens only when the operator asks for it
   in the session; otherwise record the idea as a task under `LATER`.
3. **Done means a player can see it.** The slice's `player_outcome` must be reachable from
   NEW WATCH in a windowed or exported build without debug commands. Proof is captures or
   video of exactly that behaviour, or a play note, under `docs/playtests/<slice id>/`. The
   agent sets `needs_review`; only the operator sets `complete`. The builder rejects
   `complete` without image, video or play-note proof.
4. **Build the game, not scaffolding.** Every change must be visible or audible to the
   player, or directly unblock the active slice's outcome. No new tools, libraries,
   frameworks, generators, profilers, dashboards, updater features or refactors unless a
   task of the active slice names them.
5. **Test budget.** Add a test only for (a) a bug that reached play, or (b) a simulation
   invariant or save shape the slice changes. Extend an existing suite before creating one.
   Never test wiring, text, scene node counts or captures. Per change, run the smoke test and
   the suites of the systems you touched; run the full sweep at slice close and before a build.
6. **Document budget.** Per slice: task statuses and evidence in `roadmap.json`, the in-game
   manual when a procedure changes, and one play note. No per-pass result reports,
   manifest/receipt JSON, AGENTS.md status notes or mid-slice STATUS rewrites.
7. **Ask, don't fork.** On a design question, stop and ask the operator; do not build both
   options or a configurable abstraction to defer the choice.

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

# Headless script tests: each must exit 0 and print `PASS: <suite>`.
# Per change: smoke test + the suites of the systems you touched. Full sweep: at slice close and before a build.
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/smoke_test.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_<suite>.gd
Get-ChildItem game/tests/test_*.gd | ForEach-Object { & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script "res://tests/$($_.Name)"; if ($LASTEXITCODE) { "FAIL $($_.Name)" } }
# Linux full sweep:
# for t in game/tests/test_*.gd; do ./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script "res://tests/${t##*/}" || echo "FAIL $t"; done

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
- **After changes:** run the headless smoke test and the suites of the systems you touched; tests follow the EA test budget above.
- **Art assets:** only CC0 (or similarly clean) assets, recorded in `docs/ASSET_CREDITS.md`; imported materials are `.tres` in `src/data/materials/`; never hand-edit imported `.import` files.
- **Ship geometry is generated:** edit the room table in `tools/build_ship_geometry.gd`, then rerun it to regenerate `scenes/ship_geometry.tscn` (deterministic output); never hand-edit the generated scene.
- **Slice discipline:** work only on the active EA slice (see *EA build rules*); finish and prove it before anything else.
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

## Documentation dashboard — after every pass

Before returning work, update the active EA slice's task statuses and evidence in
`docs/dashboard/roadmap.json`. Never add milestones or slices; only the operator does.
Keep implementation, operator review, current validation and delivered builds distinct;
a historical PASS is not a new run. Update `.wolf/STATUS.md` at session end, not per
change. The dashboard collector includes the complete docs, curated project context,
and game data automatically.

The EA plan is mirrored to GitHub: each slice is a milestone (`EA03 — …`) and each task an
issue (`[EA03.2] …`, label `ea-plan`, status labels, closed when complete). The mirror is
one way — edit `roadmap.json`, never the issues — and is refreshed with
`python3 tools/sync_github_issues.py` (`--dry-run` first) after slice or task statuses
change. Reference the task ID in commit messages (`feat(EA03.2): …`).

Project Stop/SessionEnd hooks and the OpenCode idle plugin refresh
`docs/dashboard/index.html` after OpenWolf's final writes. If the running agent
has not loaded them, run `python3 tools/build_dashboard.py` after the final
documentation writes. Use `python3 tools/build_dashboard.py --check` to detect
a stale snapshot. See `docs/dashboard/README.md` and `HOOKS.md`. Dashboard-only
work does not require Godot regeneration or simulator tests. Never auto-publish
the full internal dashboard or auto-stage unrelated changes.

### Roadmap IDs — resolve what the operator is pointing at

Every roadmap entity in `docs/dashboard/roadmap.json` has a permanent, globally
unique `id`, shown as a copyable badge on the dashboard. When the operator cites
one, look it up before doing anything else:

| Kind | Format | Example |
|---|---|---|
| Stage | `STAGE_<NAME>` | `STAGE_EA_FINISH` |
| Milestone / EA slice | `[A-Z][A-Z0-9_]*` | `EA03`, `SURVIVAL_SAVE`, `M7` |
| Task | `<milestone>.<n>` | `EA03.2`, `M7.3` (same as the `M7.3` used in docs) |
| Gate | `GATE_<NAME>` | `GATE_NARRATIVE` |

```sh
jq --arg id SURVIVAL_SAVE.4 '.. | objects | select(.id? == $id)' docs/dashboard/roadmap.json
```

Deep link: `docs/dashboard/index.html#view=roadmap&id=<ID>`. IDs never change and
are never reused: a new task takes the milestone's highest number + 1, a removed
task's number stays retired, and a new milestone needs an ID not used before.
`tools/build_dashboard.py` rejects missing, duplicate, mis-parented or wrongly
prefixed IDs.

<!-- openwolf:begin -->
# OpenWolf

This project uses OpenWolf for context management. Read and follow .wolf/OPENWOLF.md at session start. Check .wolf/cerebrum.md before generating code. Grep .wolf/anatomy.md for a file's path before reading it (never read the whole index).
<!-- openwolf:end -->

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.
