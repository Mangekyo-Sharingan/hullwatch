# Open Questions — awaiting the operator

Answers to these are needed before the work they block can be called done. Each entry says
what is already in the repo, what the options are, and what I would pick if left alone.

## Answer log, 2026-09-20 (decisions taken)

- **Q2 — build hours: real, as nanite jobs.** Materials commit up front, the pod assembles over
  `ShipModule.build_hours` (longer the more difficult the machine), the job survives save/load,
  and the mount can cancel it. Implemented.
- **Q3 — pods are fully modular inside.** The player places whichever machines they want in a
  pod; pre-installed machines can be moved; the ship's **vital life-support machinery is fixed**
  in place. M10.4 must give machines a placement model.
- **Q4 — teardown refunds everything.** Implemented (cancellation and teardown both return the
  full material cost).
- **Q5 — option 1: keep the two placeholder entries** as the "bare pod" tier.
- **Q6 — dock doorways: 1.0 m for now, 1.2 m at M13.** Widening now would regenerate all four
  docks and their tests only to move them again when they become radial ports in M13, where the
  bore matches interior doors at no extra cost.
- **Q7 — hull form:** reference is the player's ship; visitable stations deferred; interior stays
  as it is for now (tubes later); grim palette, and **the rust is removed** (advanced vessel, not
  a wreck) — see the M13 section of the expansion spec.

---

## Q1 — Which door leaf ships? (blocked the door pass; DECIDED)

**Decided 2026-09-20: Kenney stays.** The gate leaf is the committed default (`DOOR_STYLE =
"kenney"`), the Quaternius leaf stays wired as the alternative so it can be shot or flipped any
time, and the frame/recess pass is deferred — it returns if the chunky leaf starts reading
wrong in playtests. Everything below is the comparison that fed the decision.

Both candidates are wired through the same code path: `build_world_layout.gd` fits the leaf of
the active style to every doorway and puts the repo scratched-panel material over it. Flip the
style with `DOOR_STYLE` (or `--door-style=<name>`); the box slab remains the fallback.

Photos (same two viewpoints, both variants):
`docs/door_style/kenney_door_close.png`, `docs/door_style/kenney_corridor.png`,
`docs/door_style/quaternius_door_close.png`, `docs/door_style/quaternius_corridor.png`

| | Kenney `gate-door` leaf | Quaternius `Door_Simple` leaf |
|---|---|---|
| Source size | 2.4 × 3.72 × 0.70 m | 2.11 × 4.05 × 0.14 m |
| Look in game | three horizontal ribs, chunky edge | flat tread-plate panel, thin edge |
| Fit to our doorways | thickness squashed 2.5× to fit the 0.16 m slab box | nearly uniform; the 10 cm leaf sits naturally in the wall band |
| Frame | `gate.glb` frame exists but is 4.2 × 4.62 × 1.4 m — needs a wider, recessed doorway | `Door_Frame_SquareTall` is 4.85 × 5.0 × 0.51 m — same problem, slightly worse |
| Repo footprint | 0.2 MB | 15.5 MB (PBR trim sheets we override anyway) |
| Extras | `gate-door-window` variant (window in the leaf) | 3 leaf variants (Simple/Metal/DarkMetal) |

Options:
1. **Kenney, leaf only** (today's committed default) — most sculpted surface, but the leaf is a
   thick slab in a thin wall.
2. **Quaternius, leaf only** — reads as flat tread plate; the only candidate whose proportions
   fit the existing doorway without any geometry change.
3. **Kenney, leaf + frame** — best industrial read, but needs interior doorways widened to
   ~1.45 m and a real recess through the wall band (touches `build_ship_geometry.gd`, all
   doorway gaps, prop positions, and several layout tests).
4. Keep both, decide per door type later (e.g. Quaternius for room doors, Kenney frame for the
   airlock hatch + junction doors).

My pick: **4 as the eventual shape, 2 for now** — thin leaves fit the ship's language; the one
place a heavy framed hatch belongs is the airlock, where the OpenGameArt vault door (candidate 3
in `docs/DOOR_ASSET_CANDIDATES.md`, needs Blender prep) is the better geometry. That is a
Blender session, not a code change.

---

## Q2 — How should a dock pod appear? (blocks M10.3's "build hours")

Today the mount is instant: paying the cost stands the pod up immediately, and the operator is
standing exactly where the pod materializes (EVA, at the plate, which is *inside* the new pod's
mating flange). Physics will shove them somewhere; it may be into space.

Options:
1. **Real build hours** — `ShipModule.build_hours` already exists and is shown in the mount menu.
   Turn the install into a job: pay up front, pod appears after N sim hours, HUD line shows
   "dock construction: 4.2 h left". Needs: a job record in `ModuleSystem` (save/load), a SimClock
   tick hook, a HUD line, and an uninstall-during-build path. This is also what makes the
   fiction honest ("week-long refit", spec §4).
2. **Instant, but safe** — keep the spawn immediate and place the operator back inside the
   airlock when they confirm (a "return to lock during the build" fade, i.e. a scripted beat).
   Cheapest, but every builder has to re-EVA to see their pod.
3. **Remote build** — only buildable from a console inside the ship (a construction station),
   never from the mount itself. Removes the whole problem, costs the EVA-side build fiction the
   spec calls for.

My pick: **1**, with 2 as the interim if you want to play with pods before M10.4.

---

## Q3 — What is inside a pod? (blocks M10.4 dressing)

Right now a pod is a bare prism room: floor, walls, ceiling, a doorway, a compartment zone and a
teardown panel. No props, no light, no function.

Options:
1. Add, per module kind, one task light + one functional prop (greenhouse bed, workshop bench,
   storage rack, battery cabinet) in `dock_pod.tscn` via a per-module prop list. Fits M10.4
   ("each module's effect observable") but means the generic pod scene grows variants.
2. Keep pods bare through M10 and dress them in the M12 art pass.
3. Make each module kind its own pod scene variant instead of one generic pod (more assets, more
   tooling).

My pick: **1** — a pod with a light and one machine is enough for the loop to read, and the
function needs somewhere to point at.

---

## Q4 — Does teardown refund anything? (blocks nothing, sets player expectations)

Today teardown returns no material at all; the readout says so plainly.

1. No refund (current) — building is a commitment; salvage is a future mechanic.
2. Partial refund (e.g. 50% of metal) — softer, but needs a refund accounting path.
3. Refund everything — makes the docks a free trial; the menu becomes a shopping list.

My pick: **1**, and revisit if playtests show hoarding.

---

## Q5 — Two placeholder modules in the catalog (M10.3 artifact)

`src/data/modules/module_utility_pod.tres` (dock `hp_quarters`) and `module_storage_pod.tres`
(`hp_galley`) exist so the mount menu has entries to test. They have no function yet — their
only real effect is a compartment with its own atmosphere/thermal/hull state.

1. Keep them as the "bare pod" tier (a pod that just adds space) and let M10.4 add the function
   modules alongside.
2. Delete them in M10.4 once the greenhouse/workshop/battery modules exist.

My pick: **1** — "a pod with nothing in it" is a legitimate early build, and it gives the
catalog a cheap first rung.

---

## Q6 — Pod doorway width (no work yet, just confirming canon)

Docks are 1.0 m doorways (narrower than the 1.2 m room doors) because the dock doorway lives on
the hull band, where the aperture also has to clear the throat profile. Carrying a crate through
a 1.0 m doorway is fine; a *suit-wearing* operator at 0.6 m wide is fine.

Confirm we keep 1.0 m for docks, or widen to 1.2 m to match interior doors (costs a geometry
regeneration, all four docks move).

---

## Q7 — Adopting the reference station design (blocks the hull-form rewrite)

The reference is `Reference/station_design.jpg`: a stack of cylindrical pressurised modules —
plain drums with rounded panel frames, two ribbed propellant tanks, flanges between sections, a
forward docking node with cupola windows and a dish, and large dark solar arrays on booms.
A grey-block of that language at Hullwatch's scale is in `docs/design/proto_station_*.png`
(built by `game/tools/build_prototype_station.gd`, shot by `capture_prototype.gd`; both are
design tools, not part of the game).

**What it costs, honestly:** the ship's hull is currently generated as a faceted polygonal
prism (`HullProfile` + `build_ship_geometry.gd`), and the expansion spec makes that canon.
The reference needs lathed shells — cylinders, cones, domes, ribbed tanks — joined by flanges.
That is a rewrite of the hull-shell half of the generator plus re-baselined exterior tests and
captures; the interior plan (rooms, corridor, props, doorways) can stay.

The three questions that decide how big this is:

1. **What is it for — the player's ship, or a station the ship visits?** My read: the player's
   vessel (the reference is one vessel-like stack and its proportions match our 27 m hull). If so,
   the same language also gives us derelict stations and waypoint outposts later for free.
2. **Interior: keep it or make it tubular?** Real stations are cylinders *outside* with squared
   rack interiors, so keeping our rooms and skinning them in a lathed pressure shell is both
   authentic and far cheaper. Tube interiors with ring decks are a bigger, later job.
   My pick: keep the interiors, new shell outside, revisit tubes at M12.
3. **Palette: keep the grim Hullwatch look?** The reference is clean white ISS; our game is
   stained, rusted, work-lit. My pick: painted shells gone grey-brown with age, rusted flanges,
   the arrays as the only cool-blue element — the reference's *shapes*, our *materials*.

With answers (ship / keep interiors / grim palette): one sitting for the lathe-shell generator
and a section table, one for re-mounting the catwalk, railings, EVA anchors, tether and cargo
port onto the new shell, then re-baselined exterior tests and captures. Say go and I start with
that.

---

## Q7 answer log — hull form (CLOSED 2026-09-20)

Answered by the operator: this is the **player's ship**; the **interiors go tubular, ring
decks later**; the palette stays grim with the xenon hull material. Recorded as **M13** in
docs/EXPANSION_SPEC.md, with the plan and the dependency spelled out there.

The finding that shaped the plan: the current interior is a wide flat layout (14 m beam, 3.6 m
tall) and no slim stack can contain it, so the shell rewrite and the tube interior are one job.

Layout study: `docs/design/study_hull_three_quarter.png`, `study_hull_broadside.png`,
`study_hull_bow.png` — 11 sections, one room per section, bulkhead hatches at the flanges, pods
on radial ports, cupola forward, tanks and arrays aft, span 32 m.

Open sub-questions for the next sitting (answer while reviewing the study):

1. **Train layout vs hub.** Rooms in a chain (walk through each section to reach the next, the
   way ISS modules connect) is what the study shows and the cheapest to build. The alternative
   is a central hub section with rooms hanging off it radially - closer to the current
   corridor-hub fiction, more geometry. My pick: train.
2. **Section order.** Bow to stern in the study: cupola/cockpit head, cockpit, quarters, life
   support, galley, water closet, storage, airlock, engine bay A, engine bay B, propellant tank.
   Anything you want reordered (e.g. airlock next to the engine bay for machinery work) is a
   one-line change to the table in `game/tools/build_hull_study.gd`.
3. **Section sizes.** Deck areas are 8–21 m² per section against today's room areas (cockpit
   31 m², engine bay 45 m², corridor 54 m²). The corridor's 54 m² disappears into the chain,
   and the engine bay needs both sections. The double-height trial was reverted after review;
   the current cabin plan uses one slim deck per section.

---

## Q8 — Ring deck profile (REVISED 2026-09-29)

The earlier double-height choice for quarters, storage and the engine bay was superseded after
review. Keep the standard **2.5 m single-height cabin profile** in every room, with no
mezzanines or ladders. This is the current operator-approved layout and is verified under
M13.4 in `docs/EXPANSION_SPEC.md`.

The earlier study renders remain design-history references only: `docs/design/study_deck_section.png`
and `docs/design/study_deck_three_quarter.png`.

## Propulsion modules — decisions CLOSED (2026-09-30)

These are the operator's exact answers to the five simulation questions. This is a
**developer decision record**, not material for the player manual or computer.

1. **Energy source:** “The propulsion should draw power from a bio-replicating xenonite tank that by blasting it with UV-light forces the xenonite cells to replicate by perfect cell division.”
2. **Thermal model:** “Use the existing one”
3. **Single-cassette travel:** “Yes, it should take longer and consume more xenonite”
4. **Maintenance and diagnosis:** “Let the operator perform all maintenance and diagnostics. The system can however detect if the cassettes are functional or not”
5. **Knowledge boundary:** “Dont let the operator understand the inner working at all, keep the xenonite origin, usage and technology under a tight lid.”

The existing electric ion-drive direction, expelled xenon reaction mass and paired stern
mount remain. Xenon route fuel and Xenonite feed are independent reserves. A single working
cassette extends travel and consumes more Xenonite; it does not increase route xenon cost.
Dedicated tank output supplies propulsion and cannot supply the hotel bus or recharge its battery.

### M14.3 implementation contract — provisional until parent validation

`NavSystem` owns the tank, cassette availability/firing, holds, route progress and external
service state. UI nodes only render simulator status and submit tool-gated actions. Pair operation
preserves nominal route time and xenon cost. One cassette advances the route at half speed.
`transit_elapsed_hours` remains nominal route-progress hours; displays use
`transit_actual_hours` for elapsed clock time and `transit_remaining_hours` for ETA (infinite
while held). The hold reasons are cassette unavailable, feed reserve recovering and engine-bay cooling.

Initial tuning, subject to deterministic scenario validation:

| Item | Value |
|---|---|
| Tank capacity / initial feed / protected seed | 40 / 30 / 1 kg |
| UV service load | 30 W, `xenonite_uv`, priority 3 |
| Hidden replication / energy budget | 0.05 kg/h / 1000 Wh/kg |
| Pair / single tank output | 200 / 150 W |
| Single route progress | Half speed; 1.5 times gross Xenonite per route, greater net drain |
| Engine-bay heat | Existing thermal input; heat fraction 0.5 |
| Thermal hold / resume | 45 / 38 C |
| External repair | 0.25 h, quality 0.8; no mandatory irreplaceable stocks |

The 500 W RTG and 4 kWh battery remain. Existing demand plus UV is 640 W; shedding the
200 W lighting circuit leaves 440 W served: life support 120, scrubber 150, airlock 60,
fabricator 80 and UV 30 W. The operator can switch lighting and the fabricator off proactively
for charge margin. Do not treat propulsion output as extra bus generation.

Port, starboard and tank each expose `isolate`, `open`, `scan`, `diagnose`,
`service:<component_id>`, `close`, `restore`. Wrench opens, repairs and closes; scanner logs
wear; multimeter diagnoses and verifies restoration. Diagnosis and repair require isolation
and an open external housing. These are serviceable external parts, not an invitation to open
the sealed core. Automatic knowledge is cassette functionality only; wear and fault details
use the same scan/diagnosis gates as existing systems.

### Player knowledge boundary

Player manuals, readouts, logs and visible labels may show operational feed reserve/usage,
output, heat, UV service, cassette availability/firing, ETA/holds and diagnosed external hardware.
They must never expose biology, cell division, energy density, conversion or lattice principles,
or explain Xenonite origin, use or internals. Sealed opaque art must preserve this boundary.
The external UV assembly is service hardware; its presence does not explain the hidden mechanism.

### Reference notes and review

The operator also asked: “Also, look over the reference pictures and work on making the ship a bit more like it. Get back to me for more details when the engine pass is done”.
`Reference/station_design.jpg` supplies the segmented pressure-hardware, rib/collar and bracket
language. Existing aft/service/EVA captures and propulsion reference notes are in
[the propulsion design document](design/propulsion_module_narrative.md).

The five simulation decisions are closed. **M14.3 implementation remains provisional until the
parent validates the integrated simulation, service, save/load and UI/manual tests. M14.4 updated
captures and review await the operator after that pass.** The darker port-side housing remains
an art-review item; do not add a powered engine light without a gameplay reason.

M14.3 save integration targets global **save v4** and **NavSystem state v3**, with older saves
migrated by the parent. Ship history records cassette function loss (or unavailable tank UV),
external service actions and drive hold transitions. It never records automatic grid/cathode
fault identities: external component rows appear only after scanning or diagnosis, with failure
modes exposed only after diagnosis.

## Q9 — Planet occurrence setting (RESOLVED 2026-10-09)

Planet occurrence controls optional, resource-bearing survey-orbit waypoints. On each waypoint
arrival, the nav simulator makes a deterministic discovery roll from the origin's sector seed and
arrival ordinal. At `x1.00` the chance is 35%; `x2.00` gives 70%; `x3.00` guarantees one offer.
At most one route appears per arrival. Generated routes use the existing waypoint/travel model,
provide a smaller finite first-visit cache, and persist in nav state v4 / save v6. Changing the
global preference affects later arrivals only; already charted routes stay available. This keeps
planets out of the local asteroid stream, where the game has no planetary approach or landing loop.

The settings row is a player preference, not watch state. Route discoveries are stable through
save/load and generated route IDs/seeds derive from the saved arrival history. Playtest feedback
should tune the 35% baseline/cache values; the mechanic does not add landing or probe gameplay.

## Q10 — When do encounter-rate changes take effect? (OPEN)

Field-object and anomaly rates are global player preferences. Changing either
currently rebuilds the active streamed field immediately, and the chosen values
also apply when loading a watch. Should players be able to reshape the current
field at any time, or should new rates apply only after entering a new sector?
Keep the current live behavior until playtest feedback gives a reason to change it.
