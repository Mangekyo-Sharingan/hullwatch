# Starpath-inspired ship art pass — implementation handoff

**Operator authorization:** the operator resumed this work and authorized completion of every art-pass step. Source work, validation and review artifacts are complete locally; the final verification report lists remaining limits. Exporting or publishing a new release still requires a separate explicit request.

## What is published and what is frozen

- Published gameplay source: `6c472eb65e4e795467512feec15d2562f02f4eb3`.
- Published Windows package/checkpoint: `5303882f04a33bf4a50bf4a5a6ec9cecf8cda11f`, on `feat/playtest-menu-save-settings-2026-09-30`.
- [Windows package](https://github.com/Mangekyo-Sharingan/hullwatch/blob/feat/playtest-menu-save-settings-2026-09-30/releases/windows/2026-10-01/Hullwatch-Windows.zip) is Git LFS content. Extract and run `Hullwatch.exe`; do not download the text LFS pointer. Source passed 88/88 suites; the exported executable's embedded project passed player/menu tests and startup with the matching Linux engine. Native Windows execution is unverified.
- Art worktree: `/home/uru/Projekt/OperationSpacer`, branch `feat/starpath-art-pass-2026-10-01`, HEAD still `5303882`. Art modifications and new assets are **uncommitted and unpushed**. A checkout of the remote gameplay branch alone does not include this work.
- [FROZEN_STATE.json](FROZEN_STATE.json) records the art files and hashes at the original handoff checkpoint. Preserve that historical manifest; the authorized implementation and generated review artifacts were added afterward.
- Unrelated local files must stay untouched: `--help`, `.claude/`, `.codex/`, `.opencode/`, `.wolf/` bookkeeping outside the agreed handoff update, `CLAUDE.md`, `GEMINI.md`. Never blanket-stage or clean the worktree.

### Frozen implementation

`game/tools/build_ship_geometry.gd` contains `HERO_SECTIONS` and `_build_hero_cabins()`. Cupola, cockpit drum and quarters each have two shallow upper faceted rib frames plus ceiling-edge cable trays and clips. Four utility models sit in the second cockpit drum. Hero cabin lamps use warmer, shorter-range settings. Their existing lighting breaker script is retained.

`art/blender/build_hero_utilities.py` generates `hero_utilities.blend` and `game/assets/models/hullwatch/interior/hw_utility_spine.glb`. The model has a centered backplane origin, glTF +Y up and +Z front, dimensions x ±0.25 m, y ±0.55 m, z 0..0.16 m. The author's export assertions reported 8,784 triangles and four palette materials. The exporter joins geometry; mesh-node count does not measure the amount of detail.

`game/tools/capture_screenshots.gd -- --hero-art-only` records cockpit, utilities and quarters using the scene's real lighting. The earlier screenshot helper adds a temporary work light; do not use that helper as evidence of the art pass's actual lighting.

`game/tests/test_hero_cabins.gd` was repaired during Step 09; its mesh-bound checks now use transformed scene instances and the suite is included in the final 89-suite run. See [Step 12 final validation](steps/12-final-validation-result.md) for current evidence and outstanding limits.

### Existing visual evidence — unfinished

- [Cockpit](review/shot_hero_cockpit.png)
- [Utility wall](review/shot_hero_utility.png)
- [Quarters](review/shot_hero_quarters.png)

Diagnostic evidence: [hero test log at stop](review/hero_test_at_stop.txt) and [partial, interrupted suite results](review/partial_suite_at_stop.json). Neither is a final art validation result.

These are starting-state captures, not accepted final art. Equipment density, material depth and lighting still need work. They include normal HUD/orientation overlays.

## Approved visual direction

The operator explicitly wants the feeling of the [official Starpath trailer](https://store.steampowered.com/app/1779540/Starpath/): layered pressure structure, deep hatch frames, recessed equipment, purposeful pipes/cables and physical retro instruments, warm practical lights against dark machinery, and clear travel passages. Use the trailer as a visual reference and author original assets. Do not redistribute trailer frames as game assets or copy its exact ship/branding.

Preserve these established choices:

- Original mottled xenon-metal walls and the stronger analogue filter defaults.
- Slim, single-deck, 2.5 m tube cabins. Use `SectionHull` helpers for actual wall reach; the section's nominal radius is not its usable half-width.
- Central animated pilot chair, shallow ordered wall console banks, fold-out blade terminal and a clear aisle. Avoid introducing projecting desktop consoles.
- Existing live station names, simulator-backed screens, menus, save/load and movement controls. Density must come from physical detail, not invented usable-looking buttons or fake readouts.
- Grounded maintenance horror; no combat, supernatural agency or jumpscares. Xenonite's origin and inner operation remain sealed. Dressing must not resolve open lore questions.
- The hull and interior are generated. Edit generators/data and regenerate; never hand-edit `ship_geometry.tscn`, `world_layout.tscn` or `dock_pod.tscn`.

## How to give a step to Luna

Select the model/reasoning setting yourself. The packets do not require special model capabilities or an expensive coordinator. Open a fresh task with this prompt and the chosen step:

> Work in `/home/uru/Projekt/OperationSpacer`. Implement only `docs/design/art_pass/steps/NN-name.md`. First read `AGENTS.md`, `.wolf/OPENWOLF.md`, `.wolf/STATUS.md`, `.wolf/cerebrum.md`, `docs/PRODUCTION_SPEC.md`, and `docs/design/art_pass/README.md`. Respect the packet's dependencies and owned paths. Inspect the current diff before editing; preserve frozen and unrelated work. Use Ponytail to reuse native Godot/Blender patterns. Complete the packet's deliverables and validation, report exact results and artifact paths, then stop. Do not begin the next packet, push, upload or build a release unless this packet and the operator authorize it. If a dependency is absent, identify the missing artifact/interface rather than inventing a replacement.

### Common implementation contract

1. Start with `git status --short`, current branch/HEAD and targeted diffs. Check the frozen manifest on the first packet. Read only files needed by the packet after mandatory project instructions; use `rg` and the OpenWolf index.
2. Typed GDScript; state in simulators; fixed simulation ticks; typed EventBus signals; deterministic saves. Art must not migrate gameplay state or alter mechanics.
3. Every asset has an authoring source, documented bounds/origin/axes and a deterministic export command. Do not hand-edit `.import` files. Credit original assets in `docs/ASSET_CREDITS.md`.
4. One writer per file. These packets are mostly sequential because they share generators. If parallel work is required by AGENTS and useful, isolate asset authoring from read-only verification and pin model paths/bounds first. Never let two workers edit a generator or regenerate its scene concurrently.
5. Keep fittings inside the real cabin profile and clear of hatches, dock bores, moving panels, chair swing/boarding and the operator's capsule. Do not shrink collisions or disable guards to make art pass.
6. Match the approved silhouette, layering and light composition before adding tiny details. Do not meet a visual target by increasing polygon counts or adding dependencies.
7. A successful headless exit is insufficient. Require the exact suite PASS marker, no SCRIPT ERROR, and review unexpected native errors. Expected corrupt-save fixture errors and existing shutdown warnings need to be distinguished from new faults.
8. Record validation against the actual final diff. A prior model's summary or stale log is not current proof. Capture real rendering for visual acceptance; headless profilers do not measure rendered FPS.
9. Finish each packet with changed paths, commands/exit codes/PASS markers, screenshots, unresolved findings and the next packet's concrete prerequisites. Update `.wolf/STATUS.md`; stop after the assigned step.

## Sequence and dependencies

| Step | Deliverable | Requires |
|---|---|---|
| [01](steps/01-stabilize-checkpoint.md) | Trustworthy frozen checkpoint and repaired art validation | Existing worktree |
| [02](steps/02-reference-and-layout-target.md) | Measured hero layout and visual rubric | 01 |
| [03](steps/03-pressure-frames-and-routing.md) | Layered, flush structural framing and cable routing | 02 |
| [04](steps/04-utility-kit.md) | Refined original modular utility hardware | 02; integrate after 03 |
| [05](steps/05-cockpit-integration.md) | Dense cockpit composition with working instruments | 03, 04 |
| [06](steps/06-materials-and-wear.md) | Restrained authored material/wear treatment | 05 |
| [07](steps/07-practical-lighting.md) | Readable practical lighting with real breaker behavior | 06 |
| [08](steps/08-adjoining-cabin.md) | Matching quarters hero cabin | 03–07 |
| [09](steps/09-hero-acceptance.md) | Verified and reviewable two-space style baseline | 08 |
| [10](steps/10-interior-rollout.md) | Remaining rooms, one room per invocation | Accepted 09 |
| [11](steps/11-exterior-pass.md) | Coherent exterior language and preserved EVA access | Accepted hero; 10 as needed |
| [12](steps/12-final-validation-and-release.md) | Complete proof; optional authorized art build/publication | 10, 11 |

03 and 04 can overlap only with their write scopes kept separate and the utility interface pinned. All other dependencies should land before the next step consumes them. Do not scale the style through the ship before the hero has visual review.

## Shared commands

Run from repo root. Isolate test user data so the operator's saves/settings are not overwritten:

```bash
export XDG_DATA_HOME=/tmp/hullwatch-art-handoff-userdata
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --import
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --quit
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/smoke_test.gd
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_hero_cabins.gd
```

For generator changes, run the affected generator; these outputs are deterministic:

```bash
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tools/build_ship_geometry.gd
./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tools/build_world_layout.gd
```

For a rendered review, use the normal display session, not `--headless`:

```bash
./Engine/Godot_v4.7.2-stable_linux.x86_64 --path game --resolution 1600x900 --script res://tools/capture_screenshots.gd -- --hero-art-only
```

Captures live beneath `ProjectSettings.globalize_path("user://captures")`; its filesystem location changes with `XDG_DATA_HOME`. Copy only actual final captures into the packet's review folder. On Windows use the local console engine with the same Godot arguments. Native Windows release export uses `build.ps1`; Linux cross-export uses the equivalent import/export operations and an absolute output path, as the published checkpoint did.

For final complete suites, use a simple sequential runner that saves each log and checks all results. The existing `/tmp/hullwatch_art_suite.py` is temporary and may be absent on another machine. Recreate a stdlib runner if needed; do not add a framework. Enumerate every `game/tests/test_*.gd` plus `smoke_test.gd`, require exit 0 and `PASS: <filename without .gd>`, reject SCRIPT ERROR, and separately inspect new native errors. Do not rely on the old hardcoded suite count.

## Review rubric

For each final hero angle, write one observation for each row; retain the capture when something needs another pass.

| Criterion | Acceptance |
|---|---|
| Structural depth | Pressure ribs, hatch framing and equipment mounting read as separate purposeful layers; joins are flush |
| Equipment density | Detail surrounds a clear aisle; pipes/cables terminate plausibly; no empty-looking expanse is filled with arbitrary boxes |
| Retro instruments | Existing working screens/controls are legible and physical; no duplicate fake functions |
| Practical lighting | Visible fixtures explain bright areas; the route and maintenance targets can be found; shadows preserve depth |
| Material identity | Mottled structure remains recognizable; paint, metal, rubber and glass have distinct restrained responses |
| Movement/access | Walking, roll recovery, seating, panels, hatches and EVA remain usable with their real collisions |

This rubric is a design target, not a claim that the current captures satisfy it. Record disagreements for the operator. The unfinished full-ship pass must not be described as complete after a hero-only packet.
