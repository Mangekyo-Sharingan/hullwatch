# Reachable resource-budget audit — October 14, 2026

**A practical continuing multi-week route has not been proved.** The current
raw-stock/approach arithmetic permits an early bounded haul, subject to the
limitations measured below. Raw ice/ore/metal are plentiful
in the three audited fields; finite xenon and the loss of buffer gas constrain
repeat expeditions. An optimistic gas calculation loses normal suit-refill
pressure around day 15 even when candles preserve the oxygen fraction. The
controlled 30-day conservation suite establishes transaction fidelity, not this
reachability or survival balance.

This is a read-only audit of the local source at execution. No game, dashboard,
destination, policy, balance value, build, commit or release was changed. The
only authored output is this document. EVA restore, zero-xenon recovery and
death/recovery choices remain with the operator.

## Actual fresh-watch bootstrap

An isolated headless instantiation of the current generated tube scene, with
SimClock paused before any simulation tick, reports the following. Two frames
were allowed for room zones; one actual operator occupied storage. Runtime
definitions exclude the retired corridor. [Main scene](../../../../game/scenes/main.tscn),
[ship initialization](../../../../game/src/world/ship_scene.gd),
[compartment definitions](../../../../game/src/data/atmosphere/compartment_main.tres)
and [gas initialization](../../../../game/src/systems/atmosphere.gd) own these values.

| Resource | Actual initial stock/capacity | Supply boundary |
| --- | --- | --- |
| Potable water | 120 L of 150 L | Plus 40 L greywater; reclamation is lossy |
| Food | 6 rations | One operator uses one per day; no grow hardware initially fitted |
| Raw hold | Empty, 120 abstract-unit capacity | No initial metal/ore/ice construction stock |
| CO2 filter packages | 2 | Installed main filter begins at condition 0.15 |
| Gaskets | 1 | Repairs require current tool/isolation/diagnosis procedure |
| Sealant | Three physical shells, one charge each | Further charges require 2 metal per refill |
| Oxygen candles | 2 installed in main, none in Stores | Each produces 1 kg O2 over 2 hours |
| Cabin gas | 331.57476 m³ at initial 101.325 kPa | 2,894.63152 mol O2 = 92.62821 kg; 10,883.81453 mol N2 = 304.74681 kg |
| Xenon | 1,200 kg | No replenishment source/transfer is currently implemented |
| Electrical supply | 500 W ongoing healthy RTG, 4,000 Wh initial battery | Baseline all-on demand 760 W, a 260 W deficit |
| EVA suit | 4-hour capacity, initially empty | A full refill debits 4.375 mol = 0.14 kg O2 from storage; powered intake requires storage pressure >30 kPa |

Gas volume by actual room is main 28, storage 24.26684, cockpit 116,
engine bay 63.62944, water closet 17, quarters 30.67848, galley 40 and airlock 12 m³.
The existing 1,000 m³ sealed/healthy continuity fixture and funded starter pod
are therefore substantially different from the real empty-hold bootstrap.

## Daily demand and conversion limits

For one operator, the production rates below follow the actual simulators and
registered recipes, not external physiology assumptions.
[Water](../../../../game/src/systems/water.gd),
[atmosphere](../../../../game/src/systems/atmosphere.gd),
[vitals](../../../../game/src/systems/vitals.gd),
[airlock](../../../../game/src/systems/airlock.gd),
[recipe data](../../../../game/src/data/fabrication/recipe_water_charge.tres).

| Flow | Quantity | Implication |
| --- | --- | --- |
| Potable draw | 1.44 L/day | Even zero reclamation leaves 76.8 L after 30 days from 120 L; water reserve is not the first baseline bottleneck |
| Greywater return | 80% of actual draw | Clean 65% reclamation returns 52% of draw; minimum steady net potable loss is 0.6912 L/day, before contamination/interruptions |
| Oxygen breathing | 0.84 kg/day | Suit use replaces cabin breathing during exterior occupancy; it does not add a second operator |
| CO2 production | 1.008 kg/day | Fresh main scrubber capacity 0.055 kg/hour initially exceeds 0.042 kg/hour production |
| Filter wear | 0.004 condition/hour while powered/installed | With healthy blower, output falls below one operator's production at condition 0.763636, after 59.09 hours/2.462 days from new; a weekly swap is not a steady CO2-throughput guarantee |
| Food | 1 ration/day | Bare ship lasts 6 days without resupply/production; the two authored first-visit caches add 6 total rations once |
| Grow rack | 2 rations/day when powered; 90 W | One attainable rack can exceed one operator's food demand; no current water/nutrient input is charged |
| Suit | At most 4 simulated hours per filled outing | Station keeping, return, refill/pressure cycling and emergency reserve need real route acceptance |

Registered conversions are **4 ice→10 L water,1 h**; **3 ice→1 kg O2 candle,2 h**;
**4 ice→water filter,1.5 h**; **5 ore→CO2 filter,2.5 h**;
**2 metal→sealant charge,1 h**; **3 metal→2 gaskets,1 h**.
Water/sealant values are provisional balance data. The fabricator circuit draws
80 W while enabled; recipes do not provide independent molecular unit conversions
or a mixed-gas/xenon output.
[All recipes](../../../../game/src/systems/fabricator.gd),
[water output configuration](../../../../game/scenes/main.tscn).

A low-total-raw-unit existing food installation is a utility pod (8 metal+4 ore,8 h)
and one grow rack (3 metal+1 ice,5 h): **11 metal+4 ore+1 ice**, approximately
13 construction hours after gathering. Native sockets and paid terms are used;
these are not an invented preset. The first six food days give a plausible
bootstrap window in the audited default seed, subject to actual collection and
power management. [Utility pod](../../../../game/src/data/modules/module_utility_pod.tres),
[grow rack](../../../../game/src/data/machines/machine_grow_rack.tres).

A healthy steady powered rack, life support, scrubber and UV bus total 390 W.
Enabling an 80 W fabricator brings that to 470 W before lighting/airlock. This
fits 500 W with small margin; the original all-on 760 W and an added 90 W rack do
not. At a fixed 760 W, 4,000 Wh bridges only 15.38 hours. Battery expansion changes
capacity, not generation. Explicit breaker/lighting scheduling is necessary;
this audit did not execute the sustained thermal/power watch.
[Power](../../../../game/src/systems/power.gd),
[circuit data](../../../../game/src/data/power/circuit_fabricator.tres),
[propulsion hotel load](../../../../game/src/systems/nav.gd).

## Field opportunities and finite approach budget

The scanner used the existing SectorSystem: 200 m chunks, 1500 m/hour drift,
900 m base detection, default asteroid/anomaly multipliers 1, and seeds
20260918 (start),73019 (Arden) and158407 (Kestrel). Sampling cadence was
30 simulated seconds for 720 hours. Every object id was counted once; totals
are **detected unharvested opportunity**, not delivered stock. [Sector](../../../../game/src/systems/sector.gd).

| Field seed | Unique detected contacts in 30 days | Ice yield seen | Ore yield seen | Metal yield seen | Earliest ice/ore/metal detection |
| --- | ---: | ---: | ---: | ---: | --- |
| 20260918 | 2,688 | 10,335.58 | 10,317.74 | 7,469.00 | 0.0083h /0.4000h /0.0083h |
| 73019 | 2,637 | 10,278.32 | 10,481.24 | 7,279.53 | 0.0083h /0.4000h /0.0083h |
| 158407 | 2,724 | 10,858.58 | 10,349.51 | 7,137.75 | 1.0667h /0.0083h /0.0083h |

This density produces roughly 3.7 detected contacts/hour, despite 98% empty
individual chunks. It does not prove supplies under zero/lower encounter settings,
other seeds, missed contacts, operator work schedules or unusable geometry.
The first initial-seed metal contact is debris yielding only 4.50766 units;
it alone cannot build the11-metal food installation.

The paid scan selected only among the first five actual contact-menu rows,
called `ApproachProgram.select_action()` (which debits Nav), waited for actual
Sector station keeping, then debited finite source yield once. Its example goals
were 140 ice/64 ore/14 metal. One hour of work was allowed per site.

| Field | Approaches | Observed time including 1 h/site | Finite yield collected in upper-bound model: ice/ore/metal | Approach xenon | Fuel after applicable authored travel |
| --- | ---: | ---: | --- | ---: | ---: |
| Initial | 17 | 27.5083h | 148.1782 /80.0717 /23.9969 | 425 kg | 775 kg |
| Arden | 18 | 29.0750h | 149.9509 /76.7255 /20.1915 | 450 kg | 565 kg after185 kg Arden leg |
| Kestrel | 17 | 25.2083h | 153.4606 /76.2882 /29.1469 | 425 kg | 242 kg after both authored legs totaling533 kg |

Travel-time demand is additional: Arden plotting 1 h+2 transit days;
Kestrel plotting 2 h+4 transit days. First-visit ice 4 /metal 3 and food 3+3 were
not credited into the scan; real cache remainder persists but is finite.
Arden costs5+180=185 kg and Kestrel8+340=348 kg; an optional unregistered
planet costs5+210=215 kg. Each approach costs25 kg, including selecting the
same target again; remaining plotted/transit fuel is reserved.
[Approach program](../../../../game/src/ui/computer/program_approach.gd),
[Nav](../../../../game/src/systems/nav.gd),
[Arden](../../../../game/src/data/destinations/destination_arden_ii.tres),
[Kestrel](../../../../game/src/data/destinations/destination_kestrel_system.tres),
[optional planet template](../../../../game/src/data/destinations/destination_unregistered_planet.tres).

Thus, the initial tank pays at most 48 approaches with no travel or reserve;
after both authored legs only 667 kg/26 whole approaches remain. Free drift
creates new opportunities but does not replenish the tank. The first scan's
140-ice example is **not sufficient evidence for the gas/pressure budget below**.

### Limits of the paid result

This is an availability/fuel **upper bound**, not a playable mining route:

- Source material is known to the fixture from simulator data. Players do not
  automatically receive that oracle knowledge at contact range.
- Whole deposits were debited after approach, bypassing actual 6-unit canister
  trips, 120-unit hold capacity, fabrication throughput and physical player reach.
  Sequential processing could clear hold space; it was not simulated here.
- Fourteen-meter anchors and 2.5 m interaction reach were measured from the real
  generated ship. Even a permissive spherical-surface bound was satisfied for
  only 7/17,4/18 and4/17 paid visits. Of all passive-drift contacts, only 10, 6 and 9
  ever satisfied that bound. Collision, line of sight, moving frames, tether path
  and airlock/suit gas costs were not validated. Untethered EVA is supported by
  the controller but its safe complete route is unperformed.
- The schema guard/conservation watch does not supply native input, operator
  observation or this integrated distance/time proof. No reachable xenon bottle
  or mixed-gas source exists to repeat the expedition budget indefinitely.

## Gas/pressure envelope: a specific remaining boundary

A second temporary fixture copied the actual room state, connections and door
open flags from main. It ran actual Atmosphere ticks at 1/600 hour for30 days.
One operator remained in storage. The blower had no failures and the main
filter was reset to healthy every hour **without charging supplies**, an explicit
optimistic assumption to isolate gas loss. There were no random punctures,
EVA vent losses, added pods, gas bottles or altered baseline leak rates.
This is not a complete stock/maintenance survival scenario.

Initial leak rates are 0.002/hour in main/quarters/galley, 0.004/hour in
storage/cockpit/engine bay/water closet, and 0.001/hour in airlock. At initial
pressure they remove approximately 7.32774 kg O2 and 24.10827 kg N2 per day,
compared with 0.84 kg/day breathing. Volume-weighted well-mixed leak is
0.003296216/hour. Actual N2 falls from 10,883.81 to 1,018.26 mol (28.5113 kg)
at day 30 under the copied connections. Candles add O2 and cannot replace N2.

| Optimistic gas rule | First O2 fraction<16% | First storage pressure≤30 kPa | Day30 pressure /O2 fraction | Candles lit; new ice cost |
| --- | --- | --- | --- | --- |
| No candles | 316.7083h /13.196 days | 355.0267h /14.793 days | 7.9221 kPa /approximately0% | 0 |
| Burn as needed to maintain 19% O2 fraction | None in 30 days | 371.3517h /15.473 days | 9.8416 kPa /19.5045% | 21 total,19 fabricated =57 ice;38 bench hours |
| Also force storage pressure near 31 kPa using O2 candles | None in 30 days | None in 30 days | 30.9881 kPa /74.4351% | 141 total,139 fabricated =417 ice;278 bench hours |

The second row leaves a positive oxygen **fraction** but loses the normal suit
intake condition after about 15.5 days. It is not evidence that a physically safe
breathable atmosphere or a returning EVA route remains available. Vitals reads
oxygen fraction and a vacuum threshold, rather than validating real oxygen
partial pressure; this audit applies game checks and makes no real-world safety
recommendation. Airlock pressurization/return requirements are additional.

The last row illustrates the missing buffer-gas funding problem by exploiting
what a fraction-only model permits; it is **not an accepted oxygen-rich life-support
policy or a recommended workaround**. A 417-ice candle bill plus an example 16 ice
for four weekly water-filter services and 1 ice for a grow rack totals 434 ice.
Adding the earlier 64-ore/14-metal budget requires at least 22 ice asteroids,
4 ore asteroids and1 metal asteroid even at each asteroid's20-unit upper bound:
**27 approaches/675 kg**, exceeding the 667 kg available after both authored legs.
Actual mixed yields/debris require more visits. A less conservative 59-ore/13-metal
budget barely fits a theoretical 26-visit minimum, with no reserve or practical
collection margin; it is not a route proof. Keeping only 19% O2 needs far less ice
but stops normal suit refills in the second half of the month.

Module registration also creates each new compartment's configured initial gas
and filter; gas-package funding/construction/teardown accounting is not yet
accepted. This audit excludes new-pod gas from sustainable sources and does not
propose using refit/rebuild to manufacture air.
[Module registration](../../../../game/src/systems/modules.gd),
[atmosphere initialization and leaks](../../../../game/src/systems/atmosphere.gd),
[airlock intake floor](../../../../game/src/systems/airlock.gd),
[vitals gas checks](../../../../game/src/systems/vitals.gd).

## What the remaining priority needs

1. An operator-approved xenon source and access/recovery policy, with finite kg,
   actual 25 kg approach/travel reservations and a protected expedition reserve.
   Neither raw ice nor DRIVE FEED is an existing xenon source.
2. An explicit intended buffer-gas/leak budget and obtainable species-preserving
   refill path. The current baseline leaks dominate breathing; pure O2 packages
   do not establish intended mixed-gas continuity. Pod gas funding belongs here.
3. A bounded real expedition scenario: fresh empty hold, food/bootstrap limits,
   native approach, physical sample trips/cargo capacity, processing/power,
   suit draw/recovery, transfer, return, then repeat before reserves close.
   Test tethered and permitted untethered paths at the actual standoff geometry.
4. Balance confirmation for encounter settings, processing yields/hours, working
   load and crop costs. Known abundant simulator opportunities are not a guarantee
   under all settings or a human work schedule.

These findings do not select zero-xenon rescue/death, exact EVA resume/checkpoint,
new story/destination content, final recovered technology or a compulsory travel
route. A useful bounded 30-day stock-conservation pass can stay complete while
these all-resource/reachability gates stay open.

## Commands, observed results and provenance

Source discovery used the required existing graph first:

```sh
graphify query "What determines reachable resource supplies and approach xenon costs in Hullwatch?" --budget 1200
```

The graph returned prior plans and the 25 kg approach concept. Runtime GDScript/data
were then read directly with `rg`, `sed` and `cat`. No web source was required.
Temporary scripts were written outside the repository; all runs used fresh
`XDG_DATA_HOME` directories and the current local 4.7.2 engine. No class-cache
import, generator or source mutation was needed.

```sh
XDG_DATA_HOME=/tmp/hw-budget-scan-yq5l1603 ./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script /tmp/hw_resource_budget_scan.gd
XDG_DATA_HOME=/tmp/hw-gas-pressure-budget-zw24hna7 ./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script /tmp/hw_resource_gas_budget.gd -- intake_pressure_31kpa
```

- First command: exit 0 and `PASS: resource_budget_scan`; full log
  `/tmp/hw-resource-budget-scan.log`, including baseline and each field table.
- Initial all-three gas case command exceeded its 120-second limit after the
  first two completed cases emitted their 720-hour snapshots. Those completed
  case rows are retained in `/tmp/hw-resource-gas-budget.log`; the overall attempt
  was a timeout, not a PASS. The fixture was then parameterized to run one case.
- Single pressure case: exit 0 and `PASS: resource_gas_budget`; full log
  `/tmp/hw-resource-gas-pressure-budget.log` contains the final table row.
- No parse/script errors. Existing dummy-renderer/PagedAllocator dependency
  shutdown warnings occur after scene teardown; these are separate from results.
- All audit engine processes finished before the parent's subsequent CPU profiles.

Temporary fixture SHA256:

```text
hw_resource_budget_scan.gd 22221eb87044c18044f1587713c3a98036f9192c69664a5b068bc4f3f60fe83e
hw_resource_gas_budget.gd  c82a91372cbddafc31c77e52340c25a1f18598ce16885982a0bfe0589a0e9988
```

Runtime ownership sources at inspection:

```text
sector.gd      5e847fab163724db4146a6468db7c522bf7833c8ff1643cd1f3221d15027ded0
nav.gd         541ed62600a60b35441cda2cd6ec8ea5541a990db2a9c901594cb31b58122221
atmosphere.gd  81114442ab40390643cf11236e2de6645701ebbc3cc1abb546fa82e7cb504b02
main.tscn      5bac28bfcc44687cee5cbd5cdccc890d93ab01c85a62c9a75baee0086f9fb121
```

The tables and algorithm assumptions above retain the numerical results even
if temporary host logs disappear. Graph output is navigation context, not a
claim that its historical source assertions match the current game. These
headless numerical observations do not replace native Windows/hardware or the
uninterrupted operator playtest.
