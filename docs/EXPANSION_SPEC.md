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

## Hull geometry language (canon, 2026-09-18)

**Amended 2026-09-20:** M13 replaces the outer shell with a lathed modular stack (see the M13
section) — the canon below still governs the interior partitions and every surface that is not
part of the M13 shell rewrite.

The primitive look is a bug. The hull is a **faceted polygonal form** and nothing may
protrude or overlap:

- **No visible box slabs, no protruding edges, no coincident surfaces.** Every structural
  join is mitered and flush; walls are closed solids (inner face, outer face, jambs and
  lintels at doorways), not stacked boxes.
- **Interior spaces are prismatic:** a plan polygon (chamfered corners) extruded through a
  vertical profile of rings (floor, lower cant band, vertical band, upper cove, ceiling).
- **The spine corridor is a regular hexagon**: 60-degree cants throughout, no vertical band,
  3.5 m waist at 1.5 m height, 1.75 m flat floor and ceiling. The ship plan is sized around
  it (x -8.05..6.15), and the side rooms, hull plan, catwalk, railings and EVA anchors all
  follow the widened spine.
- **Door leaves are real geometry**: each door slab is the `door` leaf node of Kenney's
  `gate-door.glb` (CC0, `docs/ASSET_CREDITS.md`), yawed a quarter turn and fitted to the
  doorway box, with the repo scratched-panel material over its flat colormap material —
  the box slab survives only as the fallback when the prefab is missing. The gate *frame*
  and proper door recesses are a later pass (the leaf is chunky in the source asset, so a
  frame needs a wider opening than the current wall band has).
- **Shared boundaries are built once** (ownership table in the generator); the corridor
  owns its spine walls and rooms omit the edges that face it.
- **Collision is generated from the same surfaces** (ConcavePolygonShape3D), not separate
  box shapes, so what you see is what you collide with.
- **Winding:** Godot treats clockwise-wound triangles as front faces. The builder orients a
  triangle's CCW normal to the normal hint (so the normal attribute points at the visible
  side) and then reverses the winding for both the mesh and collision. Forgetting the mesh
  reversal makes every interior face back-facing — the ship then renders as its outer
  shells only (fixed 2026-09-20; the bug dates to M7.3).
- **Interior surfaces are mitered:** wall bands are swept between `HullProfile` inset rings,
  not per-edge offsets, so chamfered corners keep true mitre joints at every height.
- **Exterior follows the same language**: plan polygons offset outward, the airlock as a
  protruding vestibule, hardpoints on flat facets.

### Generator design (build_ship_geometry.gd rewrite)

1. `HullProfile` (pure 2D math, unit-tested): chamfered rectangle outlines, CCW
   enforcement, mitered polygon offsets/insets, profile rings.
2. Per space: plan outline -> profile rings -> wall band solids (with doorway cuts and
   jamb/lintel faces) + floor and ceiling caps; all quads emitted from one builder so
   joins share exact vertices.
3. Ownership: a boundary edge (or sub-span) is generated by exactly one space; spans next
   to a doorway are owned by the adjacent room while the doorway span is owned by the
   corridor.
4. Tests: ray sweeps across the corridor profile at several heights, doorway clearance
   rays, overlap sampling between adjacent spaces, `HullProfile` unit tests, plus
   windowed captures for the visual verdict.

## Milestones

| # | Week | Deliverable | Exit criteria |
|---|---|---|---|
| **M7 — EVA & open hull** | 1 | Generated exterior hull + airlock module, space backdrop (starfield, distant bodies), suit + vacuum exposure, tether, exterior walkable with boots | Suit up → cycle airlock → walk the hull tethered → re-enter; airlock/vacuum/tether headless tests; save/load clean |
| **M8 — Deep field** | 2 | Chunked procedural field around the drifting ship, ~98% empty; asteroids/anomalies/debris; contacts detection (console + scanner ping); manual close-approach thrusters (hybrid traversal) | 7 headless sim days → deterministic density + seeds; contacts appear; stream in/out leak-free; one contact reachable by EVA |
| **M9 — Materials & fabrication** | 3 | Mineable asteroids (ice/ore/metal/exotic), handheld cutter + sample hauling, cargo hold, anomaly salvage, Fabricator recipes (filter, sealant, O2 candle, water filter, ration, spares) | Month-long scenario sustained on mined inputs alone; fabrication gated by power; cargo mass persists in save |
| **M10 — Ship expansion** | 4 | Exterior hardpoints + module catalog: greenhouse (renewable food), workshop, expanded storage, aux battery, med bay; EVA construction flow; new compartments auto-register in atmosphere/thermal/power | Build greenhouse → renewable food in scenario; module save/load; geometry regenerates deterministically |
| **M11 — Destinations** | 5 | Star chart (planets/stars), course-setting, multi-day transit with events + fuel, arrival content (sector swap, sky, special resources, comms beats) | Voyage to a planet and a star in scenario; fuel consumption; arrival content differs per destination; save/load |
| **M12 — Feel & polish** | 6+ | EVA feel (tether tension, suit audio/HUD, hull lighting), exterior art pass, encounter pacing, space ambience, performance + rebalance | External playtest round on a build with the full loop; profiler budgets hold |

### M13 — Modular hull in the reference language (user-requested 2026-09-20)

The ship becomes a stack of pressurised sections in the language of `Reference/station_design.jpg`:
lathed drums with panel frames, ribbed tanks, flanges between sections, a cupola bow, and solar
arrays on booms — grim palette, xenon hull material, no clean-white ISS finish. Confirmed by the
operator: this is the **player's ship**, the **interiors go tubular** (ring decks later as a
second-deck pass), and the material language stays Hullwatch's.

One finding drives the order of work: the current interior is a wide flat layout (14 m beam,
3.6 m tall) that no slim stack can hold, so the shell rewrite and the tube interior are **one
job** — a shell built first at slim diameters would either swallow the rooms or be a fat barrel.
The layout is settled in `docs/design/study_hull_*.png` (built by `game/tools/build_hull_study.gd`):
11 sections, one room per section, bulkhead hatches at the flanges, pods on radial ports,
cupola forward, tanks and arrays aft. Span ≈ 32 m, section diameters 3.2–5.2 m.

**Operator's 2026-09-20 answers:** the reference is for the **player's ship**; visitable
stations keep their own future design; **keep the interior as is for now** (the tube interior
stays planned, later); palette stays Hullwatch grey and dim, and **the rust is gone** — the
ship is advanced, not a wreck (fittings and decks now use `mat_machined_metal` /
`mat_deck_plate`; the rusty metal and rusty grate materials are retired from the ship).
Consequence while the interior stays flat: the shell's section diameters must enclose the 14 m
beam, so the stack reads as a wide multi-section hull rather than a slim ISS column. The section
table is the single dial that slims when the interior converts — the generator work is not
wasted either way.

| Sub-step | Deliverable | Exit criteria |
|---|---|---|
| **M13.1 — Section hull generator** | `SectionHull` helpers in `src/world/` (lathe rings, drums, domes, ribs, flanges, radial ports) + the section table + collision generated from the same table; replaces the offset-polygon shell in `build_ship_geometry.gd` | Tool output deterministic; hull collides exactly where it renders; no room interior clips the shell; `test_hull_profile`/`test_hull_exterior` re-baselined and green |
| **M13.2 — Tube interior** | Each room becomes a section: circular deck plate, curved wall, bulkhead doorway at the flange, ladderway or crawl to the next section; corridor retires into the section chain (train layout) | Every room reachable on foot; doors at bulkheads; atmosphere/thermal/hull compartment defs follow the section volumes; layout suites green |
| **M13.3 — Radial docks & exterior fittings** | Four docks as radial ports on their sections (pods hang perpendicular to the hull axis); airlock outer hatch, EVA platform, truss walkway with railings, tether anchors, cargo port re-mounted on the curved shell | Build → EVA → enter a pod on foot; tether clips; hull-exterior rays green |
| **M13.4 — Ring decks** | Second deck inside the larger sections (mezzanine ring, ladder between decks) for the rooms that need the area (engine bay, storage, quarters) | Decks walkable, no headroom clash, compartments re-measured |
| **M13.5 — Verification** | Captures, `test_scene_loop` with the new geometry, manual/manual-binder text, docs | Full loop headless; captures reviewed; docs consistent |

One milestone per commit series; each milestone ships with its tests and a playable build
when the user wants one. Polish is explicitly M12 — do not pull it forward.

### M7 sub-steps (EVA & open hull)

Working agreement from M7 on: every sub-step is **one commit** containing implementation,
tests and doc updates together; the full suite runs before push; visual steps are verified
with windowed captures. A sub-step starts only after the previous sub-step's exit criteria
are met. No feature lands without a test that fails without it.

| Sub-step | Deliverable | Exit criteria |
|---|---|---|
| **M7.1 — Airlock room** | Generated `Airlock` space west of Storage (inner + outer doorway gaps), `compartment_airlock.tres`, layout tests updated | Rays pass both doorway gaps; floor collision + chamfers present; layout suites green |
| **M7.2 — In-world wiring** | Atmosphere/thermal/hull defs + `AirlockSystem` node + `circuit_airlock` in `main.tscn`; inner/outer doors wired with airlock ids; airlock zone + compartment link; control panel (ScrollMenu) + suit locker interactables; new `test_airlock_scene.gd` | Player can cycle the lock and suit up in-game; interlock observable; counts and scene tests updated |
| **M7.3 — Polygonal hull form (interior)** | `HullProfile` utilities; `build_ship_geometry.gd` rewritten into the faceted prism language: plan polygons, mitered flush wall bands (no overlapping slabs or protruding edges), flat-bottom hexagonal corridor profile, doorways with jambs and lintels, trimesh collision from the same surfaces | No two structural solids overlap; corridor cross-section matches the hexagon profile at all heights; doorway rays still pass; `test_hull_profile` green; captures reviewed |
| **M7.4 — Exterior hull** | Polygonal hull shell offset from the plan (opening at the outer door); perimeter catwalk + railings; ramp to the roof; EVA platform; hardpoint markers | Walk ray from outer door across platform/catwalk/ramp; no shell collision inside rooms; hardpoint markers exist |
| **M7.5 — Space backdrop** | Sky shader (stars + distant star/planet), sun light, environment swap; windowed captures | Captures read as space; interiors stay lit; scene profiler unchanged |
| **M7.6 — Tether & HUD** | `toggle_tether` action; `TetherAnchor`/`TetherZone` auto-clip; player constraint + release/re-clip; HUD EVA readout (suit O2, tether distance, airlock state); toast reasons; manual EVA page | Tether clamp/release/auto-clip tested; HUD states tested; EVA round trip playable |
| **M7.7 — Verification** | `test_eva_flow.gd` end-to-end; scene save/load incl. airlock + suit; captures 11–13 for docs; AGENTS/brain updates | Full loop passes headless; save/load round-trips; captures reviewed |

**Status:** all M7 sub-steps landed (M7.1–M7.7). The exterior is reachable, the lock cycles,
the suit and tether protect the walker, and the deep field / destinations start at M8.

### M8 sub-steps (deep field)

| Sub-step | Deliverable | Exit criteria |
|---|---|---|
| **M8.1 — Sector field sim** | `SectorSystem`: seeded chunk corridor along the drift axis (~2% content), asteroid/debris/anomaly data objects, active stream list, contacts with enter/leave events, save/load | Same seed → identical field; density within 1–3% over 7 days; active set bounded; save/load reproduces it; `test_sector` green |
| **M8.2 — Scene streaming** | `FieldStreamer` binds visuals + collision to active objects (faceted asteroid meshes, anomaly placeholders), spawn/despawn leak-free, profiler budget | Objects appear/leave as the ship drifts; node count bounded; scene profiler holds |
| **M8.3 — Detection** | Nav console `CONTACTS` list (range/bearing/kind), handheld scanner ping (HUD toast + nearest contact) | Contacts listed sorted by range; ping works from EVA; tests |
| **M8.4 — Close approach** | Hybrid traversal: manual approach burn in the nav console toward a contact (fuel + time), hold at standoff distance | Approach closes range, costs fuel, clamps at standoff, refuses without fuel; tests |
| **M8.5 — Verification** | 7-day end-to-end scenario, EVA reachability from standoff, captures, docs | Loop passes headless; docs/captures updated |

**Status:** **M8 complete (M8.1–M8.5).** Verification lives in `test_approach` (seven days of drift → contact → fuel-gated approach → standoff hold with drift stopped → resume → refusal without fuel → mid-hold save/load) plus `test_sector`, `test_field_streamer` and `test_detection`. Scene captures of field objects are deferred to the next playtest build (objects need game-hours of drift to come into view). **Status: M9 complete (M9.1–M9.5).** Verification lives in `test_cargo`, `test_mining`, `test_fabricator`, `test_anomaly_salvage` (the field scanner reads anomalies into exotic cargo, refusing without the scanner or a full hold) and `test_m9_loop` (a month of ship days: the field supplies ice/ore/metal, a worn-out CO2 filter is replaced from freshly mined ore, the stock is restored). Scene captures of field objects remain deferred (game-hours of drift are needed for them to come into view). M10 modular ship is next.

### M9 sub-steps (materials & fabrication)

| Sub-step | Deliverable | Exit criteria |
|---|---|---|
| **M9.1 — Cargo hold & materials** | `CargoSystem`: ice/ore/metal/exotic units with a mass budget, add/consume API, events, save/load; status-panel CARGO section | Capacity enforced, units conserved, save/load round trip; `test_cargo` green |
| **M9.2 — Mining runs** | Cutter + sample canisters as carriables; streamed asteroids become mineable (`SpaceObject` interactable, finite seeded yields by kind); hull cargo port deposits canisters | EVA: mine an asteroid into a canister and stow it; yields finite; tests |
| **M9.3 — Fabricator** | Workshop device (power-gated) with `.tres` recipes: ice → water filter / O2 candle, ore → CO2 filter, metal → sealant / gasket, exotic → parts; menu UI; consumes cargo, feeds stores | Recipes gated by materials + power; fabricate repairs the loop; tests |
| **M9.4 — Anomaly salvage** | Scanner interaction on anomalies yields exotic material and a logged event | Salvage works from EVA; exotic reaches cargo; tests |
| **M9.5 — Verification** | Long-run scenario: mine → fabricate → repair across days; captures; docs | Loop passes headless; docs updated |

### M10 sub-steps (modular ship)

Modules are **walk-in dock pods**: each dock is a mount on a hull side-wall facet. A pod is a
prismatic room in the same faceted language (plan polygon through profile rings) with a real
doorway cut through the hull band, so the operator enters from inside the ship. Unbuilt docks
keep a flush closed mount plate; building happens EVA-side at the mount. Pod dimensions are
shared placeholders until M12 — only the interior function differs per module kind.

| Sub-step | Deliverable | Exit criteria |
|---|---|---|
| **M10.1 — Module framework** | `ShipModule` resource (cost, hardpoint, pod recipe, compartment config) + `ModuleSystem` sim: install/uninstall per hardpoint, material cost out of `CargoSystem`, compartment register/unregister in atmosphere/thermal/hull, save/load; `remove_compartment` on the three sims; `module_installed`/`module_uninstalled` signals | Install gating (unknown/duplicate/occupied/missing materials) tested; compartments appear and leave with install/uninstall; save/load restores installed set; `test_modules` green |
| **M10.2 — Dock geometry** | Four side-wall docks (quarter, life-support, galley, engine-bay walls), flush mount plates, generic `dock_pod` scene generated by the geometry tool (prism room, doorway through the hull band, caps, trimesh collision, compartment zone + link node); hardpoint markers relocate from the roof deck; deterministic regeneration + `test_module_geometry` | Pod doorway is walkable from the parent room; plate seals the dock when unbuilt; tool output byte-stable; layout suites green |
| **M10.3 — Construction scene** | Dock mount interactable (EVA): build menu with cost + build hours, install spawns the pod scene and swaps the plate for the open dock; uninstall reverses; scene save/load with a module standing; `test_module_scene` | Full build → walk in → tear down loop passes; save/load round trip with a module |
| **M10.4 — Catalog & function** | `.tres` catalog in `src/data/modules/`: greenhouse (renewable rations into stores), workshop (fabricator throughput), expanded storage (cargo capacity), aux battery (power capacity, new circuit), med bay (operator recovery); power/link wiring | Each module's effect observable in its sim; catalog validation (unique ids/hardpoints, cost kinds exist) |
| **M10.5 — Verification** | Scenario: build greenhouse → rations appear over days; full-loop save/load; captures; manual page; docs | Loop passes headless; docs/captures updated |

Pinned ids for M10.2–M10.5: docks `hp_quarters` (west of Quarters), `hp_life_support` (west of
Life Support), `hp_galley` (east of Galley), `hp_engine_bay` (east of Engine Bay); pod recipe
`dock_pod`. `module_system` loads **before** the life-support systems so a restored save finds
module compartments already registered.

**Status:** M10.1 landed — `ShipModule` + `ModuleSystem` (catalog, gating, cargo cost,
compartment register/unregister, save/load, typed signals) with `remove_compartment` added to
atmosphere/thermal/hull and `test_modules` green. M10.2 landed — four dock mounts
(`hp_quarters`, `hp_life_support`, `hp_galley`, `hp_engine_bay`): each is a 1 m doorway in the
parent room's outer wall, a throat across the void to the hull band (profile `throat`, zero
wall inset so the bore matches the aperture), a 1 m aperture cut in the hull band, and a
flush mount plate (`DockPlate_<id>`, group `dock_plate`, conduit material) spanning the band's
full height with the hardpoint marker (`Hardpoint_<id>`, group `hardpoint`) just outside it.
The roof-deck hardpoint markers are gone. `build_ship_geometry.gd` now also generates
`scenes/dock_pod.tscn`: the generic pod room (plan 0.2..4.4 x ±1.6, chamfer 0.8, profile
`room_l`, doorway through its local −X wall), with a `Zone` (`compartment_id` `module`) and a
`Link` node; origin sits on the hull's outer face at the doorway centre, floor at y=0, pod
extending toward +X — place west docks yawed 180°, east docks unrotated (M10.3). Node groups
are marked persistent (Godot only serializes persistent groups; the previous roof hardpoints
silently had none). `test_module_geometry` green. M10.3 landed — the dock plate *is* the mount:
it carries `module_mount.gd` with its `hp_`-prefixed hardpoint id, so EVA interaction opens the
dock's build list (catalog entries for that dock, with cost, stock and build hours). Installing
pays `CargoSystem` through `ModuleSystem`, hides the plate and disables its collider (which is
what opens the doorway), and stands `dock_pod.tscn` up on the hull face with its zone re-keyed to
the module's compartment and its `Link` bridged into the parent room. The pod's own room carries
the same mount with `spawns = false`: that is the teardown panel inside. `ModuleSystem.load_state`
re-announces restored modules, so a loaded save rebuilds standing pods from sim state alone. New
suite `test_module_scene` (build → walk-in doorway → teardown → save/load). Two placeholder
catalog entries (`utility_pod`, `storage_pod`) give the menu content; their functions arrive in
M10.4. Build hours are *displayed* but not yet simulated — see `docs/OPEN_QUESTIONS.md` Q2 (the
operator would otherwise stand inside the materializing pod). Next: M10.4 catalog & function.

**Operator answers, 2026-09-20 (post-M10.3):** build hours are real — a module's build is a
**nanite construction job**: materials are committed up front, the pod assembles over
`ShipModule.build_hours` of ship time (longer the more difficult the machine), the job survives
save/load, and the mount can cancel it. **Teardown and cancellation both return the full
material cost** to the hold. Pods are **fully modular inside**: the player places whichever
machines they want in a pod (M10.4 must give machines a placement model), pre-installed machines
can be moved, and the ship's vital life-support machinery is fixed in place. The two placeholder
catalog entries stay as the "bare pod" tier. Dock doorways stay 1.0 m for now; when M13 turns
the docks into radial ports the bore goes to 1.2 m to match interior doors, at no extra cost.

## Test strategy

- M7: airlock cycle state machine, vacuum exposure → vitals, tether constraint, exterior
  geometry presence (hull collision raycast, airlock doors, hardpoints).
- M8: sector determinism, density within 98%±1 empty, stream lifetime, contact cadence.
- M9: mining extraction, cargo capacity/mass, recipe gating, 30-day sustenance scenario.
- M10: module install/uninstall, compartment registration, greenhouse food production.
- M11: course/transit/arrival state machine, destination data validation, fuel math.
- Every milestone: save/load round trip + full suite stays green (currently 59 suites).

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
