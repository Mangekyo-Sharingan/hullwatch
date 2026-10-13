# Survival development — October 13 execution packet

Status: first packet implemented after verified checkpoint delivery and lighting
tuning. Integration source validation:92/92 suites PASS, exit0/exact markers/no script
errors. Focused transfer, equipment, sector, migration and HUD checks also pass. This packet starts the larger approved survival
pass; it does not claim all six activity slices are complete.

## First implementation: conserve the expedition's work

| Workstream | Owner and files | Pinned contract |
|---|---|---|
| 02A safe specialization | Equipment worker: systems/modules.gd, systems/salvage.gd; test_modules, test_machine_fitting, test_salvage, test_module_effects | Existing fitting/removal/cancellation APIs. Full crafted refunds; same recovered instance. Refusal leaves inventory, jobs, effects and charge unchanged. Check final cargo and battery capacity before mutation. |
| Lossless mining transport | Transport worker: interactables/sample_canister.gd, cargo_port.gd; test_mining | `SampleCanister.remove_amount(units: float) -> float`; stow removes exactly accepted cargo, leaving same-kind remainder. Existing unload stays compatible. No save shape change. |
| Finite field persistence | Parent: systems/sector.gd, autoload/save_manager.gd; test_sector, test_save_migration and version expectations | Keep public get_remaining_yield/record_mined APIs. Sparse `mined_fields` map keyed by string field seed, containing contact IDs and remaining units, including zero. Sector statev2/global savev8. Old mined map becomes the old current field, never a global coordinate claim. |
| Fractional production persistence | Equipment worker in its already-owned modules.gd/test_module_effects | Module statev4 adds finite nonnegative `ration_hours`; load replaces accumulator. Parent supplies globalv7→v8 default0 migration. Existing powered growth rates and output remain. |

Each path has one writer. No agent owns roadmap, result documents, STATUS or
other workers' tests. Parent imports changed scripts before integration and runs
all suites after agents finish; generation is not concurrent with verification.

## Proof required

- Overflowed cancellations/refunds and capacity shrink refuse atomically; freeing
  room or spending stored charge permits exactly one successful retry.
- A partially accepted deposit conserves hold + canister material; full hold,
  invalid amount, repeat action and JSON remainder restoration cannot discard it.
- A→B→A and same coordinate ID across fields preserve independent depletion.
  Stream-out, settings regeneration, reload and explicit zero cannot refill it.
- Fractional production resumes from the same remainder on fresh/same scene load,
  with identical next outputs and no duplicate food. Legacy defaults are explicit.
- All source suites, startup, simulation timing and actual exported-project checks
  remain distinct from operator gameplay and native Windows acceptance.

## Following packets and pending content choices

After conservation, continue Slice02's survey/salvage/endurance capabilities,
then investigation and physically reachable replenishment: ice→water, refillable
repair supplies and a distinct reaction-mass path. Each needs configured costs,
real simulator effects and save/load evidence. Cross-cutting preparation remains
in ../replenishment_plan.md and ../persistence_plan.md; their October9 inventory
snapshot is historical, not a current missing-feature list.

The first recovered technology choice was asked again on October13. Until the
operator answers, common mechanics proceed and the battery remains a provisional
fixture. Do not resolve fuel source, loss/recovery, gas funding, exact EVA resume
or opaque DRIVE FEED technology lore as an incidental implementation choice.
No mandatory campaign or resource regeneration on revisit is introduced.

## Implemented behavior

- Cancelling paid construction/fitting and removing crafted hardware preflight
  the full refund and final hold capacity. A refusal keeps the paid job/hardware.
- Pod teardown includes all crafted refunds, recovered cases and removed storage
  and battery capacity before changing any ownership. Stored charge cannot be
  silently dropped; the HUD identifies that refusal separately from a full hold.
- Recovered equipment returns its original instance. Compound returns change
  ownership together before notifications, preventing partial release failures.
- Partial mining deposits keep their exact remainder; full/repeat/invalid
  operations do not change stock. The old unload return contract is retained.
- Sparse per-field depletion survives stream-out, settings rebuilds, travel and
  JSON. Equal contact-coordinate IDs in different fields remain independent.
  Seeds serialize as strings, protecting64-bit identity.
- Fractional and whole pending food output survive reload, with legacy missing
  values explicitlyzero. Existing production costs/rates are unchanged.
- Global saves8 migrate7. Invalid new nested resource payloads refuse before
  restoring clock/simulator state. The prior current field is preserved; already
  erased older destination histories cannot be recovered.

Operator traversal, native Windows and complete survival/refill continuity remain
open. This is02A plus cross-cutting conservation/persistence, not all three
specialized loadouts or the completion of all six activity slices.

[Current full suite](full_suite_results.json). Follow-up Windows build identity and
embedded-project checks will be recorded separately after export.

Final sequential profiler:174.7 microseconds/tick, PASS at unchanged200 limit;
isolated startup and string extraction PASS. This is the existing eight-system
headless timing fixture, not rendered FPS or a multi-week survival guarantee.
[Profiler output](profile.txt). No narrative, scarcity or refill policy resolved.
