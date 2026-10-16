# Modular construction — post-EA concept (`LATER.2`)

Status: concept, decisions 2026-10-15. **Not scheduled; outside the EA freeze**, except the
limited nanite stock (decision 2), which the operator moved into EA (`EA04`).

## Goal

Build pods piece by piece anywhere on the hull: weld beams into a frame, fit plates that
were cut from wrecks or fabricated, weld and seal the seams, cut through into the ship and
pressurize. The work is **tedious but manageable**: every step is physical and skilled
(spec §4.3, no progress bars), and the quality of the work matters later. Finishing a first
pod should feel like a **monumental achievement**.

Terminology: **xenon-metal** is the ship's grown structural alloy (spec §6.1).
**Xenonite** is the separate sealed drive feed. This document only ever means xenon-metal.

## Operator decisions (2026-10-15)

| # | Decision |
|---|---|
| 1 | Start with **template frames**; shape the data so a **free grid** can follow when it works. |
| 2 | **Nanites are limited from the start of a game** and can be produced only at a slow rate; nanite builds stay the expensive shortcut. Moved into EA as `EA04.8`. |
| 3 | Build **anywhere on the hull**, not only on the four dock plates. |
| 4 | A first pod takes about **15–30 real minutes in total, including gathering plates on EVA**. |
| 5 | Weld skill is **both** a step sequence (tack, bead, inspect) and a steady-hand action along the seam. |
| 6 | Plates come from **salvage or the fabricator** (from metal). **Xenon-metal plates are salvage only**: cut from wrecks of the same class and reshaped, never manufactured (keeps spec §6.1). |
| 7 | Seams wear **only slightly**: some corrosion from the inside of the ship over time. |
| 8 | **Every part looks like its material.** Regular metal has its own art style; only xenon-metal parts use the mottled xenon look. A pod built from mixed materials looks patchwork, never uniform. |
| 9 | **Four templates from the start:** one small pod, one medium pod and two corridors. None comes prebuilt; every one is assembled part by part. |
| 10 | **Deconstruction returns materials in their current condition at a high rate**, except materials that should not be recoverable (see *Deconstruction*). |

## What already exists to build on

| Existing piece | Path | Use here |
|---|---|---|
| Nanite pod build at dock plates (materials + build hours; no nanite stock yet) | `src/interactables/module_mount.gd`, `src/systems/modules.gd`, `scenes/dock_pod.tscn` | Remains the shortcut, drawing on the limited stock (decision 2) |
| Runtime compartments | `atmosphere.gd`, `hull.gd`, `thermal.gd` › `add_compartment` / `remove_compartment` | A commissioned pod or corridor registers as a compartment |
| Per-compartment humidity | `atmosphere.gd` (`humidity_g`, saved) | Drives the slow inside corrosion of seams (decision 7) |
| Hull patch procedure (clean → fit → sealant → verify) | `src/interactables/hull_patch.gd` | Template for seam steps |
| Hull micro-puncture / leak model | `hull.gd` | Leaks from poor or corroded seams |
| Hull cutter, recovery mounts, wrecks, cargo metal, fabricator | `cutter_tool.gd`, `salvage_mount.gd`, `src/world/salvage_wreck.gd`, `cargo.gd`, `src/systems/fabricator.gd` | Plate salvage and fabrication |
| Machine sockets | `machine_socket.gd` | Fit-out of a built pod |

Constraint: the ship's hull is generated at build time (`HullProfile`,
`build_ship_geometry.gd`) and never hand-edited. Built structures are a separate runtime
layer with their own mesh and collision, owned by a construction simulator and restored from
saves. The generated-hull canon (no protruding edges) applies to the generated hull only;
built parts may protrude.

## Templates (decision 9)

| Template | Role | Indicative parts |
|---|---|---|
| Small pod | First project; one machine bay | ~12 beams, ~8 plates, 1 hatch |
| Medium pod | Two to three machine bays | ~20 beams, ~14 plates, 1–2 hatches |
| Straight corridor | Joins hull to pod or pod to pod | ~8 beams, ~6 plates, 2 hatches |
| Corner corridor | Changes direction between structures | ~10 beams, ~7 plates, 2 hatches |

Templates are stored as sets of grid cells, so a free grid later reuses the same slots,
parts and saves instead of replacing them (decision 1).

## Player loop (one pod)

1. **Survey the site** — pick a hull facet; the terminal shows which templates fit (flat
   enough, clear of thrusters, arrays, dish, handrails and the drive, and with an interior
   wall behind it that is free of machinery).
2. **Gather** — fabricate beams and plates (they queue while the player works) or cut
   plates from wreck panels on EVA, carrying a small stack per trip on a tow line.
3. **Frame** — set each beam into its slot (snaps), tack both ends, run the bead, inspect.
4. **Plate** — offer a plate to a face (snaps), clamp, weld every seam, inspect.
5. **Seal and test** — sealant on seams; pressure-test with the scanner; bad seams show as
   leaks.
6. **Breach** — with the new pod sealed and pressurized, cut the access opening through the
   ship's hull and frame it with a hatch. Cutting into an unsealed pod vents the room behind
   it: the tense, irreversible step.
7. **Fit-out** — power and data conduit, light, machine sockets.
8. **Commission** — first pressurization and lights on: a ship-log entry, the pod appears on
   the status board, and the pod's name can be painted at its hatch. This moment, not the
   duration alone, carries the "monumental" feeling.

## Time budget: first small pod, 15–30 minutes including gathering (decision 4)

Indicative counts to tune in play, not commitments:

| Work | Count | Per item | Subtotal |
|---|---|---|---|
| Gathering: one EVA salvage trip for a plate stack; the rest fabricated meanwhile | 1 trip | ~6–8 min | ~6–8 min |
| Beams: place, two tacks, bead, inspect | 12 | ~15 s | ~3 min |
| Plates: offer, clamp, 4 seams, inspect | 8 | ~40 s | ~5–6 min |
| Seal and pressure test | 1 | ~2–3 min | ~2–3 min |
| Breach and hatch | 1 | ~2–3 min | ~2–3 min |
| Fit-out and commissioning | 1 | ~2–3 min | ~2–3 min |
| **Total** | | | **~21–26 min** |

What keeps gathering inside the budget: the fabricator works in parallel, a tow line
carries several plates per trip, and salvage-quality plates are an upgrade, not a
requirement. Medium pods and corridors are later, larger projects with their own budgets.

## "Tedious but manageable" — design rules

- Actions are short (about 2–10 s); skill shows in quality, not in longer holds.
- Parts snap to slots; no fiddly freeform alignment.
- Weld quality = correct step order + steady speed along the seam; stored per seam.
- Helpers reduce repetition without skipping steps: a jig that holds four beams, a better
  welder, pre-cut plate stacks.
- Partial structures persist in saves; the player can stop at any step.
- Seam wear is slow and driven by the structure's own humidity: a dry, ventilated pod
  barely ages; a damp one slowly develops seam leaks to re-weld.

## Materials and look (decisions 6 and 8)

Each beam and plate carries a material id that sets its stats and its render material:

| Material | Source | Look |
|---|---|---|
| Fabricated steel | Fabricator from metal | New, plain industrial metal (new art style) |
| Salvaged plate | Cut from a wreck | Keeps the wreck's paint, scorching and wear |
| Xenon-metal | Salvage only, from same-class wrecks; reshaped, never made | The ship's mottled graphite xenon look |

Rendering merges parts per material, so a patchwork pod costs a few draw batches, not one
per part; this matters for the Steam Deck 60 fps target.

## Deconstruction (decision 10)

Unbolting and cutting apart a structure is a reverse procedure, part by part. Each
recoverable part returns as itself, at its current condition, at a high rate (proposed
default 85% of its material; corroded or badly welded parts return less).

Not recoverable (proposed list, to confirm):

| Material | Why |
|---|---|
| Sealant on seams | Cured in place |
| Weld filler | Fused into the seam |
| Spent nanites | Consumed by the build |
| Gas inside the structure | Vented unless pumped back first |

## New work, and why it is large

| Piece | New or extended | Relative size |
|---|---|---|
| `ConstructionSystem`: grid-addressed slots, per-part material and condition, per-seam quality, save/load, determinism | New simulator | Large |
| Runtime mesh and collision, merged per material | New | Large |
| Site validation on arbitrary hull facets and the breach into the interior | New | Large |
| Enclosure → compartment registration (template completeness first, grid cells later) | New | Medium now, large for the grid |
| Welding tool: steps, held seam action, bead visual, quality, tool wear | New | Medium |
| Plate cutting from wreck panels (EA09 wrecks need separable panels) | Extends salvage | Medium |
| Tow line for plate stacks on EVA | Extends player/tether | Medium |
| Deconstruction with condition-based returns | Extends construction/cargo | Medium |
| Per-seam leaks and humidity-driven corrosion | Extends hull/atmosphere | Small–medium |
| New art: steel parts, welder, hatch frames, salvaged-plate variants | Art | Medium |
| Blueprint pages, save migration | Extends computer, SaveManager | Small |

## Remaining questions

- Confirm the 85% default return rate and the non-recoverable list.
- Nanite production in `EA04.8`: which existing machine produces them slowly (fabricator
  recipe or a dedicated socket machine), and how large is a new watch's stock?
