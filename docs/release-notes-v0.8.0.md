# Hullwatch v0.8.0 — EVA test build

Playable Windows test build with the first half of the early-access expansion: the ship is
open, you can leave it, and space is out there. Still a **pre-playtest build of current
content** — expect rough edges.

## What's new since v0.7.0
- **The ship left the box factory.** The interior is now a faceted polygonal hull: chamfered
  corners, canted walls, a flat-bottom hexagonal corridor, mitered flush joins — no more
  stacked slabs or protruding edges. Collision is generated from the exact same surfaces.
- **Airlock.** A real pressure vessel west of the storage hold: interlocked inner and outer
  hatches (the outer opens only on vacuum, the inner only on pressure), a control panel that
  pumps air back to storage or vents it to space, and a suit locker with an O2 tank you can
  refill from ship air.
- **EVA.** Suit up, cycle out, and walk the hull with magnetic boots: an outside platform,
  a catwalk ring around the ship, an aft deck and a ramp up to the roof.
- **Tether.** Stepping onto the hull auto-clips you to the nearest anchor. **T** releases and
  re-clips; past the anchor's length the line goes taut and holds you. The HUD shows tether
  length and suit O2 while worn. The suit feeds your breathing line in vacuum — watch the tank.
- **Space.** A procedural starfield sky with a sun and a banded planet, and a star light
  on the hull. It is dark out there on purpose; polish comes later.
- Manual gained an **EVA page** (nine pages).
- Fixed: readout panes (comms, manual, airlock panel, suit locker) now fully disappear when
  closed instead of leaving their content pane on screen.

## How to play
Run `Hullwatch.exe` (Windows x64, single file, PCK embedded).
Start a **fresh save** — the hull changed a lot.
The airlock is through the storage hold (west wall). Suit locker inside; the control panel
cycles the lock. Outside: tether (T), boots (Q), flashlight (F), look before you leap.

## Hotfix (same day)
- Fixed: open doors could not be closed again. A door's only collision slid away with the
  slab, so the interaction ray had nothing to aim at. Every doorway now keeps a thin
  **sensor frame** that the crosshair targets (while the body walks straight through and
  never collides with it), forwarding to the door.
- Fixed: the generated hull's collision triangles were wound the wrong way for Godot's
  physics, so the operator stood on the **underside** of floor slabs and movement was
  blocked. Collision now uses the corrected winding, and the layout test asserts the
  position and facing of floor, ceiling and wall surfaces instead of just "something
  was hit". Re-download the exe if you grabbed the first upload.

## Known gaps (honest list)
- Exterior lighting is dark and flat; the look pass is scheduled after the feature milestones.
- The roof ramp is steeper than it should be, and the aft deck's support is a plain block.
- Deep space is only a backdrop for now: asteroids, anomalies and materials arrive with M8/M9.
- Sleep fast-forward still causes a brief (~0.6 s) hitch behind the fade.
- Carried-item position is not persisted (items return to spawn after load).
- Comms content is still the v0.7 mission-control traffic; the voyage destinations are later.
