# Hullwatch — Early-Access Expansion Spec

Planned several weeks of work, features first, **looks-and-feel polish deferred** until
the feature set lands. This document is authoritative for expansion scope and supersedes
the related v1 non-goals in `PRODUCTION_SPEC.md` §8.3.

## Player vision (as requested)

- A fully open ship: leave it through an airlock and **walk the exterior** (secured — tether).
- The ship **grows**: new modules attached outside, plus new functions inside.
- The ship slowly **traverses near-infinite space** that is ~98% empty; asteroids and
  anomalies drift past and provide **materials for continued survival**.
- **Planets and stars** sit in the distance; the player may choose to **travel to them**.

## Expansion design rules

- Grounded dread stays: no combat, no entity, no jumpscares. Vacuum, tether discipline,
  consumables and distance are the threats.
- Every new system follows the house rules: typed sim in an autoload/group, EventBus
  signals, data-driven `.tres`, headless-deterministic, saved through `SaveManager`.
- **The ship stays at the world origin; space streams around it.** No floating-origin math:
  field objects move relative to the ship, and "travel" swaps sector parameters +
  fast-forwards sim time — it does not translate the world.
- Determinism: sector content is seeded from (run seed, sector id, day). Tests can replay
  a sector byte-identically.
- EVA is safe by default (tether + magnetic boots) but risk stays available.
- Placeholder-generated geometry is acceptable until the polish phase (M12).

## Architecture notes (append to the existing stack)

- `SpaceLayer` (inside `main.tscn`): sky/starfield + distant bodies, `FieldStreamer`
  (chunked content around the ship), generated `ShipExterior` (hull shell, airlock,
  hardpoints — produced by `build_ship_geometry.gd` alongside the interior), and
  `SectorController` (drift, contacts, sector state).
- **Airlock** is a real compartment: inner + outer doors, cycle state machine, atmosphere
  integration (opening the outer door with air inside vents it — loud, fast, expensive).
  Suit required for vacuum; suit carries an O2 supply feeding the existing vitals causes.
- **Tether**: `TetherAnchor` + a player constraint (spring/rope), HUD status, release/reel.
- **Field**: `SpaceObject` catalog (asteroids, anomalies, debris) with deterministic spawn
  cadence; long-range contacts list on the nav console and a handheld scanner ping.
- **Cargo**: mass-limited hold; mass affects travel fuel (keeps gathering a choice).
- **Modules**: exterior hardpoints + `ShipModule` resources (cost, geometry recipe,
  compartment/zone wiring, function script). Building happens EVA-side.
- **Fabrication**: `Fabricator` recipes (`.tres` in → out + time + power); a workshop
  module improves it. This closes the survival loop: gather → fabricate → repair.
- **Destinations**: `Destination` resources (planet/star, distance in days, fuel, sector
  seed, arrival content hooks). Course-setting reworks `NavSystem`; transit runs the sim
  and can raise events; arrival swaps the sector and sky.

## Milestones

| # | Week | Deliverable | Exit criteria |
|---|---|---|---|
| **M7 — EVA & open hull** | 1 | Generated exterior hull + airlock module, space backdrop (starfield, distant bodies), suit + vacuum exposure, tether, exterior walkable with boots | Suit up → cycle airlock → walk the hull tethered → re-enter; airlock/vacuum/tether headless tests; save/load clean |
| **M8 — Deep field** | 2 | Chunked procedural field around the drifting ship, ~98% empty; asteroids/anomalies/debris; contacts detection (console + scanner ping); manual close-approach thrusters (hybrid traversal) | 7 headless sim days → deterministic density + seeds; contacts appear; stream in/out leak-free; one contact reachable by EVA |
| **M9 — Materials & fabrication** | 3 | Mineable asteroids (ice/ore/metal/exotic), handheld cutter + sample hauling, cargo hold, anomaly salvage, Fabricator recipes (filter, sealant, O2 candle, water filter, ration, spares) | Month-long scenario sustained on mined inputs alone; fabrication gated by power; cargo mass persists in save |
| **M10 — Ship expansion** | 4 | Exterior hardpoints + module catalog: greenhouse (renewable food), workshop, expanded storage, aux battery, med bay; EVA construction flow; new compartments auto-register in atmosphere/thermal/power | Build greenhouse → renewable food in scenario; module save/load; geometry regenerates deterministically |
| **M11 — Destinations** | 5 | Star chart (planets/stars), course-setting, multi-day transit with events + fuel, arrival content (sector swap, sky, special resources, comms beats) | Voyage to a planet and a star in scenario; fuel consumption; arrival content differs per destination; save/load |
| **M12 — Feel & polish** | 6+ | EVA feel (tether tension, suit audio/HUD, hull lighting), exterior art pass, encounter pacing, space ambience, performance + rebalance | External playtest round on a build with the full loop; profiler budgets hold |

One milestone per commit series; each milestone ships with its tests and a playable build
when the user wants one. Polish is explicitly M12 — do not pull it forward.

## Test strategy

- M7: airlock cycle state machine, vacuum exposure → vitals, tether constraint, exterior
  geometry presence (hull collision raycast, airlock doors, hardpoints).
- M8: sector determinism, density within 98%±1 empty, stream lifetime, contact cadence.
- M9: mining extraction, cargo capacity/mass, recipe gating, 30-day sustenance scenario.
- M10: module install/uninstall, compartment registration, greenhouse food production.
- M11: course/transit/arrival state machine, destination data validation, fuel math.
- Every milestone: save/load round trip + full suite stays green (currently 44 suites).

## Save format

Bump to **v3** when the first new state lands (M7: airlock/suit; M8: sector + contacts;
M9: cargo; M10: modules; M11: destination). v2 saves keep loading where feasible;
migration tests cover the gap.

## Risks

| Risk | Mitigation |
|---|---|
| Expansion scope overruns | Milestone table is the contract; per-milestone commits; user sees builds between |
| EVA disorienting/unfun | Magnetic-boots-first, thrusters minimal, tether always available |
| Empty space = boring | Encounter pacing curve tuned in M8; authored anomalies, not pure noise |
| Field performance | Chunk budget + far-object simplification; profilers exist (`profile_scene.gd`) |
| Save growth | New systems fold into existing versioned groups; migration tests from v2 |

## Resolved decisions (2026-09-18, user-confirmed)

1. **Traversal — hybrid:** the ship auto-drifts by default (content streams past); the player
   sets course to destinations and rides multi-day transits. **Manual thrusters exist for
   close approach/docking maneuvers only** (introduced with the M8 field work, used for M11
   arrivals) — no full piloting layer.
2. **Extraction — handheld first, ship arm later:** M9 ships EVA tools + sample canisters
   hauled through the airlock; a ship-mounted manipulator arm becomes a later module/upgrade.
3. **Expansion — hardpoints now, freeform later:** EA uses fixed exterior hardpoints + an
   authored module catalog; freeform hull building is post-EA.
4. **Space tone — environmental only:** vacuum, fuel, distance, silence, strange sensor
   readings. No entity, no scripted supernatural beats.
