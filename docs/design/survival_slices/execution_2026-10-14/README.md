# Supply, persistence and specialization foundations — October 14

Status: implementation complete and combined validation green at the date shown.
All changes are local (uncommitted). This pass follows the completed visual EA
roadmap and the operator's instruction to continue priorities 1–5. No public EA
readiness or new release is claimed.

## Implemented foundations

- Fabricator state v2 snapshots paid material, output and duration terms; missing
  Stores retains completed output. Module state v5 saves original job and installed
  costs for cancellation, removal and teardown. Changed content cannot change the
  refund; missing pending content retains its refundable entitlement.
- Ice fabricates a water charge, transferred through the reclaimer separately
  from filter maintenance. Full tanks and unavailable power/service refuse without
  consuming the package. Reclamation retains greywater when output cannot fit.
- Metal fabricates sealant charges; the carried reusable cartridge refills at the
  fabricator. Sealing debits one charge, keeps the shell and saves the procedure.
  Stores v2 owns shell charges; old consumed-prop tombstones grant no resource.
- Rejected arrival materials remain saved at their destination and can be received
  at the cargo port. Cargo validates known kinds and finite quantities; stowed
  recovered equipment alone reserves hold capacity. Salvage state v2 stringifies
  64-bit provenance and retains carried identity. Physical restore awaits policy.
- Exterior physiology consumes suit O2 and food; exterior water use remains active.
  Room zones now replace configured occupancy with actual presence, fixing an
  unvisited-room ghost occupant. Suit refill requires power and a safe ship-air
  intake. A real main-scene EVA regression passes.
- Global save v9 deep trust-boundary validation passed against malformed nested
  state, legacy mid-job/menu saves, dynamic pod compartments, paid terms and
  cross-owner placements before any live-state application (see full suite).

## Watch-level continuity

The new 30-day deterministic watch `test_resource_continuity` couples the whole
chain: mining feeds cargo, finite ice/metal/ore pay every craft, water/sealant
transfer only at the reclaimer or fabricator bench, four reusable patches hold,
weekly grow-rack rations run unpowered without losing fractional progress, and
field revisits retain partial and depleted deposits. The watch round-trips the
save envelope 57 times and closes with ledger-conservation assertions. Its
completion rounded out the earlier per-owner suites.

## Checks observed at the final state

Full tree at `ef8aab9` plus the local modifications listed by the sha256
manifest in the results JSON:

- Combined headless sweep: 97 of 97 test suites PASS, smoke test PASS and
  engine startup PASS (see `full_suite_results.json`; every run isolated via
  `XDG_DATA_HOME`).
- Fixed-tick budget: 3 profiler runs at 165.9 / 165.6 / 166.1 us against the
  200 us budget (`profile_results.json`, logs in this directory).
- Focused job suites: test_fabricator, test_modules, test_machine_fitting PASS.
  Focused supply suites: test_water, test_stores, test_replenishment PASS.
  Cargo/Nav/Salvage ownership suites PASS. Airlock and exterior EVA suites PASS.
- World layout was regenerated from its source table; generated scene was never
  hand-edited (byte-identical diff confidence). Manual field-work and patch
  instructions cover the supply paths.

## Supplemental checks after the recorded sweep

A later compatibility correction permits preexisting adjacent pods to load;
the new-build clearance rule still applies. The focused
`test_persistence_foundations` rerun exited 0 with its exact suite PASS and no
script errors (`legacy_pod_compatibility.log`). This correction postdates the
full-sweep hash manifest and does not revalidate that entire tree.

Native Linux 1280×800 menu captures at UI scales 1.0 and 1.4 passed panel bounds
for the water reclaimer and fabricator. The four frames and bounds receipt are
in `captures/`, with the successful run in `supply_ui.log`. The two enlarged
menus were visually reviewed. This checks these supply menus, without claiming
human route acceptance, rendered FPS or native Windows validation; the existing
voice-guide header was truncated at maximum scale in these earlier frames. The
later notebook packet corrects it with native wrapping and separate captures
(see `survey_result.md`).

## Remaining acceptance and policy

Exact EVA resume versus a safe interior checkpoint and zero-xenon recovery remain
unanswered operator questions. Xenon/mixed-gas resupply and reachable long-run
resource budgets remain open. First recovered technology is a provisional battery.
The new water/repair conversion values are provisional data, awaiting balance.
Human route success, hardware FPS, native Windows and store release gates remain
open. Historic discarded cache rewards/rounded seeds/paid catalog terms cannot
be reconstructed from old saves. No background real-time production is introduced.

## Next priority

Specialization landed with saved physical equipment and a powered survey sensor
using existing sockets. Survey, salvage and endurance each change distinct live
capabilities and costs; no saved preset system and no hull-builder rewrite. The
investigation notebook is the next independently authorized activity packet;
its v10 migration and validation are recorded separately in `survey_result.md`.
The unanswered recovery/resource policies and remaining multisession balance
questions stay open.
