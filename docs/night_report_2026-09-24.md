# Night report — 2026-09-24 (overnight session)

Session: GitHub auth set up on the Linux night-worker, then project work per
`docs/EXPANSION_SPEC.md` (M13) with five original Blender kits authored and wired in.
Everything is committed and pushed to `origin/main`; the full suite is green.

## Review pointers

- **Playtest build:** `build/windows/Hullwatch.exe` (single file, rebuilt from the final
  source; the export verified as a PE32+ GUI executable with the kits embedded). Built on
  Linux — not run on Windows here, so it is untested by hand.
- **Captures:** `docs/design/shot_tube_*.png` (refreshed) — of note:
  `shot_tube_walkway.png`, `shot_tube_eva.png` (the authored outer hatch),
  `shot_tube_airlock_inner.png`, `shot_tube_terminal.png`, `shot_tube_galley.png`,
  `shot_tube_filter_rack.png`, `shot_tube_tool_cart.png`,
  `shot_tube_quarters_locker.png`, and `shot_pod_machines.png` (machines in a pod).
- **Kit previews:** `docs/design/asset_cockpit_kit.png`, `asset_machine_kit.png`,
  `asset_machinery_kit.png`, `asset_hatch_kit.png`, `asset_dressing_kit.png`.
- **Blender sources:** `art/blender/*.blend` (cockpit, machines, machinery, hatch, dressing).

## What landed

- **M13.2 closed:** the carried props settle against the real section wall (a transform-walk
  bug made the settle pass a no-op; eight props were embedded) and `test_world_layout` now
  measures the true wall line and the lane to the opposite wall.
- **M13.3 radial docks & exterior fittings:** the dock bore is 1.2 m (Q6); a truss walkway
  with rails and posts runs from the EVA platform toward the life support dock (stopping
  clear of a standing pod's bay, its end within reach of the mount plate); the bow/stern
  tether anchors are mounted on the drum walls; `test_module_scene` asserts the
  build -> enter-a-pod-on-foot walk from the room; the door fit is normalized so bulkhead
  leaves keep their detailing axis.
- **Five original kits, in the game:** cockpit hero kit (consoles, switch bank, gauges,
  seven-segment), pod machine kit (six machines in the sockets), life-support machinery
  (scrubber, reclaimer, fabricator, breaker cabinet), the airlock pressure hatch (outer and
  inner hatches), and the interior dressing kit (locker, mess table, filter rack, tool cart).
- **Docs:** AGENTS/EXPANSION status, asset credits, README, the EVA manual page (flat-era
  catwalk text replaced), and a new open question.

## Open questions for you

1. **Q8 in `docs/OPEN_QUESTIONS.md` — ring decks (blocks M13.4).** The tube interior is
   2.5 m tall, so a mezzanine splits it into two crawl levels unless the big sections grow.
   Options: crawl loft (no hull change), double-height sections (a section-table pass), or
   engine bay only. My pick: engine bay first, then the same treatment elsewhere.
2. **Interactive CRT placement.** The seven interactive props are wall-mounted boards and now
   render the authored consoles. The authored *desktop* console is a floor unit with a
   keyboard shelf; if you would rather have floor consoles in the rooms (a layout change),
   say so and it is a small pass.

## Environment notes

- GitHub: SSH key added; `git fetch/push` and LFS verified.
- `game/addons/godot_mcp/icon.png` shows as modified in the working tree (pre-existing, left
  alone). `game/tests/tmp_*.gd` are untracked leftovers from an earlier session (left alone).
- Export templates for Godot 4.7.2 are installed at `~/.local/share/godot/export_templates/`.
