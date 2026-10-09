# Hullwatch

**Project dashboard:** generate the local archive with `python3 tools/build_dashboard.py`,
then open `docs/dashboard/index.html` for the full documentation, roadmap, pass history,
and visual archive; [dashboard setup and automatic updates](docs/dashboard/README.md).

A first-person ship-maintenance simulation about keeping a decaying long-haul vessel — and yourself — alive in the cold vacuum of space. Grounded dread, no monsters, no combat. The horror is entropy.

- **Engine:** Godot 4.7.2 (local binary in `Engine/`)
- **Language:** GDScript (typed)
- **Spec:** [`docs/PRODUCTION_SPEC.md`](docs/PRODUCTION_SPEC.md) · expansion plan: [`docs/EXPANSION_SPEC.md`](docs/EXPANSION_SPEC.md)
- **Status:** [October 9 merged-main playtest prerelease](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261009.1); open survival slices in progress (prior stable release: v0.11.0)

## Play it

[Download the current Windows playtest](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261009.1).
Includes the ship art/salvage prototype and latest menu, settings and optional
survey-orbit routes. Download `Hullwatch.exe` directly or extract the ZIP.

```powershell
# From source (fastest)
.\play.bat

# Or a built single-file executable
.\build.ps1            # release build -> build\windows\Hullwatch.exe
.\build.ps1 -Debug     # debug build
```

Controls: WASD move/thrust, Space push-off/upward thrust, Ctrl crouch/downward thrust,
Shift brake drift, Z/C roll in zero-g, Q release boots/land, E interact,
F flashlight, T tether, X leave pilot seat, Esc pause.

## Test it

```powershell
# Headless suites (all should exit 0; see AGENTS.md for the full list)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/test_scene_loop.gd

# Regenerate generated content after changing its inputs
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/extract_strings.gd
```

## Docs

| Doc | Purpose |
|---|---|
| [`docs/PRODUCTION_SPEC.md`](docs/PRODUCTION_SPEC.md) | Authoritative design spec |
| [`docs/EXPANSION_SPEC.md`](docs/EXPANSION_SPEC.md) | Early-access milestones M7–M13 |
| [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) | Decisions awaiting the operator |
| [`docs/SHIPPING_CHECKLIST.md`](docs/SHIPPING_CHECKLIST.md) | M6 gap list |
| [`docs/STORE_PAGE.md`](docs/STORE_PAGE.md) | Draft store copy + capsule assets |
| [`docs/ASSET_CREDITS.md`](docs/ASSET_CREDITS.md) | CC0 asset provenance |
| [`docs/ASSET_SOURCES.md`](docs/ASSET_SOURCES.md) | Vetted asset source shortlist |
| [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md) | String extraction workflow |
| [`AGENTS.md`](AGENTS.md) | Guide for AI agents working in this repo |

## Layout

| Path | Purpose |
|---|---|
| `docs/` | Production spec, store copy, credits |
| `game/` | Godot project root (scenes, src, assets, tests, tools) |
| `art/` | Blender sources for the authored kits (`art/blender/`) |
| `build/` | Export output (gitignored) |
| `Engine/` | Local Godot binaries (gitignored) |
| `tools/` | Dev utilities, MCP configs |
