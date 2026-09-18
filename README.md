# Hullwatch

A first-person ship-maintenance simulation about keeping a decaying long-haul vessel — and yourself — alive in the cold vacuum of space. Grounded dread, no monsters, no combat. The horror is entropy.

- **Engine:** Godot 4.7.2 (local binary in `Engine/`)
- **Language:** GDScript (typed)
- **Spec:** [`docs/PRODUCTION_SPEC.md`](docs/PRODUCTION_SPEC.md)
- **Status:** Pre-production (M0)

## Quick Start

```powershell
# Run the game project (once game/project.godot exists)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game

# Open the editor
& ".\Engine\Godot_v4.7.2-stable_win64.exe" --editor --path game

# Headless smoke test (once project exists)
& ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --quit
```

## Layout

| Path | Purpose |
|---|---|
| `docs/` | Production spec and design docs |
| `game/` | Godot project root |
| `Engine/` | Local Godot binaries (gitignored) |
| `tools/` | Dev utilities, MCP configs |
