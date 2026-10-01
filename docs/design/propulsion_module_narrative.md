# Propulsion module narrative

**Status (2026-10-01):** five operator decisions closed; M14.3 engine integration verified
by the final 88/88 headless suites. Nine M14.4 captures
are present; operator review remains pending. Broader style and gameplay-loop work is authorized
to continue independently.

## Developer-only premise

The main drive remains electric xenon ion propulsion with expelled xenon reaction mass,
paired aft-facing cassettes and restrained blue wakes. A separate Xenonite tank supplies
propulsion energy: its hidden biological material replicates by perfect cell division under
UV illumination. This mechanism is fictional and belongs exclusively in developer docs.
Xenonite origin, use and internal technology remain secret from the player. The earlier
public-facing accelerator-lattice explanation is superseded by this strict knowledge boundary.

The visual contrast is precise sealed hardware surrounded by human service housings,
fasteners, feed regulators, wiring and brackets. Neither cassette nor tank art may reveal
biological contents or explanatory core internals. External access exposes service hardware only.

## Operational contract

`NavSystem` is authoritative for Xenonite reserve/output, cassette functionality and firing,
route progress, ETA, holds and external maintenance. Xenon remains independent route fuel.
Two working cassettes retain nominal time and xenon cost. One working cassette proceeds at
half route speed, consumes more Xenonite and retains the route's xenon cost. No working
cassette holds the route for repair. Low feed holds for tank recovery; engine-bay heat holds
for cooling through the existing `ThermalSystem` compartment model.

The tank output is dedicated to propulsion. UV service draws 30 W from the existing shared
bus on priority-3 `xenonite_uv`; it cannot make propulsion output available to cabin equipment.
With existing loads, demand is 640 W. Lighting sheds first, leaving 440 W of life support,
scrubber, airlock, fabricator and UV service against the 500 W RTG. The manual tells operators
they can switch lighting and the fabricator off proactively for battery charge margin.

Developer tuning is a 40 kg tank, 30 kg initial feed and 1 kg protected seed; hidden replication
is 0.05 kg/h with a 1000 Wh/kg energy budget. Pair output is 200 W; single output is 150 W
at half progress speed (1.5 times gross Xenonite per route and greater net drain). Half the
output becomes engine-bay heat; transit pauses at 45 C and resumes at 38 C. External repairs
take 0.25 h at quality 0.8 without requiring irreplaceable stocks. Config resources owned by
the simulation pass hold these values; UI text does not duplicate balance numbers.

`transit_elapsed_hours` measures nominal route progress, not time aboard. Readouts use
`transit_remaining_hours` for ETA (infinite while held) and `transit_actual_hours` for elapsed
time; cassette firing follows actual available output, not merely an active transit flag.

## Service and player knowledge

All external hardware is operator-maintained. Port cassette, starboard cassette and tank
have separate EVA service targets: isolate, open with wrench, scan with scanner, diagnose
with multimeter, service the chosen external component with wrench, close with wrench,
restore with multimeter. Diagnosis and repair require isolation and an open housing.
The operator services fittings around the sealed core and never opens or understands it.
Automatic computer knowledge is whether the cassettes function; component condition needs
a scan and fault identity needs diagnosis, using existing WearComponent status conventions.

Player labels use **DRIVE FEED** or **RESTRICTED FEED**, never the technology name.
Manuals, readouts, logs, labels and service screens show only operational feed reserve/usage,
output, heat, UV service, functional/firing states, ETA/holds and tool-revealed external faults.
**Never disclose biology, division, energy density, conversion, lattice principles, or Xenonite
origin/use/internals to the player.** Operational feed and UV labels do not explain the mechanism.

## Visual and reference notes

- `Reference/station_design.jpg`: segmented pressure housings, ribs, collars, restrained labels
  and brackets; adapt the geometry language while retaining Hullwatch's mottled grim palette.
- Two matching aft cassettes on the centered stern drum; retain clearances to arrays, tether,
  RCS and catwalk. External tank housing is opaque and sealed with an accessible UV assembly.
- Idle apertures are dark; firing creates narrow blue wakes, without chemical bells or
  permanent flames. Keep the silhouette recognizable as maintenance hardware and propulsion.
- `art/blender/build_ion_drive.py` authors the cassette/tank kit; assets are
  `game/assets/models/hullwatch/exterior/hw_ion_drive.glb` and `hw_xenonite_tank.glb`.
- Existing electric-propulsion background references: NASA's
  [ion-propulsion fact sheet](https://www.nasa.gov/wp-content/uploads/2015/08/ionpropfact_sheet_ps-01628.pdf)
  and [Dawn propulsion overview](https://science.nasa.gov/mission/dawn/technology/ion-propulsion/).
  These are references for conventional external hardware, not evidence for the fictional tank.

### In-game captures

![Paired ion cassettes at rest, aft view](shot_ion_drive_stern_idle.png)

![Paired ion cassettes during transit, aft three-quarter view](shot_ion_drive_stern_burning.png)

![Close view of the cassette service hardware](shot_ion_drive_service.png)

![EVA-side view of the cassette pair and stern fit](shot_ion_drive_eva.png)

The current M14.4 set contains nine rendered captures (all present under `docs/design/`):

| Capture | Subject |
|---|---|
| [Idle stern](shot_ion_drive_stern_idle.png) | Paired cassette fit at rest |
| [Burning stern](shot_ion_drive_stern_burning.png) | Paired firing wakes |
| [Service close-up](shot_ion_drive_service.png) | External service hardware |
| [EVA fit](shot_ion_drive_eva.png) | Stern fit from the EVA side |
| [Port service](shot_ion_drive_port_service.png) | Port housing access |
| [Starboard service](shot_ion_drive_starboard_service.png) | Starboard housing access |
| [Tank service](shot_ion_drive_tank_service.png) | Opaque tank and UV service assembly |
| [Single cassette](shot_ion_drive_single.png) | Reduced firing presentation |
| [Diagnostics](shot_ion_drive_diagnostics.png) | Operator inspection presentation |

Capture existence is not operator approval. M14.4 silhouette, access, reference fit and failure
presentation review remains pending, including the darker port housing. The operator has
separately authorized broader style and gameplay-loop work to continue independently.

## Verification status

The five exact user answers are recorded in
[OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md#propulsion-modules--decisions-closed-2026-09-30).
**M14.3's engine integration is verified by the affected suites**, including deterministic
wear/fault/repair, protected feed recovery, power shedding, thermal holds, reduced travel and
save/load. **The final integration run passes 88/88 headless suites**, including the repaired
settings, real menu/save/load flow, fabricated oxygen usage and new-watch wear isolation. `test_operator_maintenance`
also passes for the subsequent external-hardware bridge. These test results are reported by the
parent integration pass; operator capture review remains a separate M14.4 gate.

The warning board now defaults to WATCH REPORT, derived from live simulator readings and
recent history. It points to unlogged inspections and tool-diagnosed service without introducing
quest state. Existing equipment test points bridge scanner/multimeter inspection to wrench
cover/refit/close actions with resource-defined isolation, gasket, time and repair quality.
Generic hardware refits use 0.25 h and quality 0.75; the propulsion service tuning remains
separate. Housing state is simulator-owned and saved; live-circuit isolation is enforced at
operator breaker activation. Integration review must cover nested cover-state validation and
fresh-session ownership of mutable wear resources as well as the final full suite.

M14.3 uses global **save v4** and **NavSystem state v3**, with migration for older saves. Ship history records cassette function loss (or unavailable tank UV),
external service actions and drive hold transitions. It never records automatic grid/cathode
fault identities: external component rows appear only after scanning or diagnosis, with failure
modes exposed only after diagnosis.
