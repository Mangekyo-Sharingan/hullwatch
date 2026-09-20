# Open Questions — awaiting the operator

Answers to these are needed before the work they block can be called done. Each entry says
what is already in the repo, what the options are, and what I would pick if left alone.

---

## Q1 — Which door leaf ships? (blocks the door pass, not M10.4)

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
