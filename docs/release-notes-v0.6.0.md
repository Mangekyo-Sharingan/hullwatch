# Hullwatch v0.6.0 — early test build

Playable Windows test build from the M6 milestone plus the post-M6 roadmap sprints.
This is a **pre-playtest build** — expect rough edges and placeholder content.

## What's in it
- First-person maintenance on a five-module freighter: walk, inspect, repair, sleep, keep the ship alive.
- Interlinked sims: power (RTG + battery, priority shedding), thermal, atmosphere (6 compartments, doors, hull leaks), water reclamation, nav legs, stores with rations.
- Five procedures: scrubber filter swap, breaker work, sealant patch (carry the cartridge), water reclaimer service, O2 candles.
- Component wear and failures with an authored cascade; versioned save/load with migration.
- Diegetic UI: status panel, operator manual (read it — the success test depends on it), maintenance board, prior-operator log; persisted settings.
- Procedural audio with no audio assets: machine loops carry diagnostics, footsteps and breath react to your state.

## How to play
Run `Hullwatch.exe` (Windows x64, single file, PCK embedded).
Esc opens settings. Controls are on the first page of the in-game manual (E on the binder).
Saves live in `%APPDATA%\Godot\app_userdata\Hullwatch\saves\`.

## Known gaps (honest list)
- No external playtest yet (spec §8.5 success test is still pending).
- Art is CC0 textures + kit props on greybox geometry; the cockpit is still placeholder.
- Store screenshots are placeholder cards (`docs/store/`).
- Sleep fast-forward causes a brief (~0.6 s) hitch behind the fade.
- Carried-item position is not persisted (items return to spawn after load).
