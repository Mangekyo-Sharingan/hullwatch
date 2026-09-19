# Hullwatch v0.9.0 — deep field test build

Playable Windows test build with the deep-space half of the expansion so far: the ship
wanders a nearly empty sector, contacts drift past, and you can fly to them. Plus the
first proper period hardware on the desks.

## What's new since v0.8.0
- **The deep field.** The ship drifts through a near-infinite seeded sector that is ~98%
  empty. Asteroids, debris clusters and anomalies stream past; anything that leaves the
  window is culled.
- **Detection.** The status panel lists contacts (count, nearest range, the three closest
  by kind and distance). Carry the wear scanner and **left-click** for a ping — a beep and
  a HUD line tell you the nearest contact, or that there is nothing in range.
- **Close approach.** A new contact board in the cockpit lists what is nearby:
  `APPROACH <contact>` costs 25 kg of fuel and slides the ship to a 30 m standoff, then
  **matches velocity** so the object holds still while you work — `RESUME DRIFT` lets it go.
- **90s CRT workstations.** The glowing box screens are gone. Every display is now a beige
  CRT with a recessed phosphor screen (amber readouts, green terminals), chin knobs, a
  power LED and — on the cockpit terminals — a keyboard shelf with chunky keycaps.
- Includes the two earlier v0.8.0 hotfixes: corrected collision winding (movement) and
  sensor frames so open doors can be closed again.

## How to play
Run `Hullwatch.exe` (Windows x64, single file, PCK embedded). Start a fresh save.
Drift is automatic; watch the status panel for contacts, ping with the scanner, then use
the cockpit contact board to approach one and cycle out through the airlock (T tether,
Q boots, F flashlight).

## Known gaps (honest list)
- Field objects are resources waiting to be mined — extraction, cargo and fabrication are
  the next milestone (M9). For now you can fly to an asteroid and look at it.
- Exterior lighting is still dark and flat; the look pass (nebula, sun corona, key art)
  comes in M12.
- Scene captures of field objects are pending; they need game-hours of drift to appear.
- Sleep fast-forward still hitches briefly behind the fade; carried-item position is not
  persisted across loads.
