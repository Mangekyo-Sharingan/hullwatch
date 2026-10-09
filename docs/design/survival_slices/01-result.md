# Slice 01 — useful salvage implementation checkpoint

Date: 2026-10-09. Common salvage prototype implemented. First-technology choice,
manual continuous EVA playthrough and final art/balance review remain pending.

## What works

Debris contacts stream a compact open recovery frame using original generated
geometry. A physical supply control isolates the mount; a carried wrench releases
a transport case. The case uses the normal carry slot, can be dropped/recovered,
and is stowed through the existing hull cargo port. It reserves six hold units
in the provisional data. A pod socket lists recovered stock and uses the actual
carried multimeter/wrench for diagnosis and repair. Repair pays configured cargo
material; fitting uses the recovered unit without new fabrication stock.

The provisional fixture is the existing auxiliary battery cabinet: +900 Wh
capacity after repair, no generation or free charge. This is a reversible test
choice, not an inferred operator answer. Water processor, survey instrument and
workshop unit remain first-tech alternatives in the pending question.

Removal returns the same equipment instance. Scrapping is a terminal alternative
with configured material yield. Pod teardown preflights returned equipment,
material refunds and final hold capacity before mutation. Full-hold refusals
preserve equipment and paid material. Built-machine refund behavior stays
separate from recovered-instance returns.

## Persistence and ownership

`SalvageSystem` owns identity, isolation, release, diagnosis, condition, world /
carried / stowed / fitted / scrapped location and fitted socket. Provenance IDs
combine field seed, chunk object and recovery definition. Claim survives streaming
and sector revisits independently of the existing raw-material mining ledger.
Current destination seeds are distinct; a general sector identity/generation
policy remains in the broader persistence plan.

`CargoSystem` derives equipment reservations; `ModuleSystem` merges recovered
socket effects while saving only its built machinery. Save v5 migrates v1–v4,
restores recovered capacity before power clamps charge, and registers new
salvage state empty for prior saves. A saved held unit returns as a world case
at its recorded sector position, keeping one instance. Player pose/EVA state
is not generally persisted yet; the player may need to retrieve that case.
This explicit limitation belongs to the broader persistence workstream.

HUD refusal/result messages, tool use animations, procedural audio cues, ship log,
manual FIELD WORK procedure and cargo-status reservation display are wired.

## Files

- New definition/data: `src/components/salvage_definition.gd`,
  `src/data/salvage/salvage_battery.tres`.
- New simulator/world: `src/systems/salvage.gd`, `src/world/salvage_wreck.gd`,
  `src/interactables/salvage_mount.gd`, `salvage_case.gd`.
- Integration: field streamer, cargo port/system, module system, machine socket,
  SaveManager/EventBus, main scene, HUD/status/computer/audio, tool animations.
- Procedure/localization: existing FIELD WORK manual and regenerated string table.
- Checks: `tests/test_salvage.gd`, updated current-version assertions in save,
  session and M11 tests; `tools/capture_salvage.gd` for visual review.

Paths above are relative to `game/`. Generated ship scenes and preexisting art
WIP were preserved. No Windows export, commit, push or publication occurred.

## Observed validation

Engine: local Godot 4.7.2 Linux binary. Current run records are in
`review/01-suite-results.json`; logs under `/tmp/hullwatch-salvage-validation/`.

- Headless import: exit 0, no script/parse error.
- Startup `--headless --path game --quit`: exit 0 in an isolated XDG data directory.
  The earlier default-user startup encountered the preexisting malformed save;
  it was not edited or deleted.
- Full current suite: 90/90, exact suite PASS marker and exit 0, no SCRIPT ERROR
  or assertion failure. Per-suite isolated data directories prevent test save
  collisions. The M11 scenario needed more than the initial 90-second runner
  timeout; the full runner allowance was increased, with no clock/test logic cut.
- Additional salvage scenario covers actual scene contacts, authored tools, cargo
  port and pod socket; energy preservation through fresh-scene load, v4 migration,
  duplicate/refund refusals, full-hold recovery and sector provenance pass.
- Localization extraction: exit 0 with its PASS marker.
- `profile_sim`: 201.0 µs/tick versus 200 µs budget, FAIL. The prior art checkpoint
  also exceeded this budget (201.8 µs); the performance gate remains open. This
  fresh measurement is not a rendering FPS result.
- Native Wayland capture: exit 0, actual scene geometry saved in
  `review/01-wreck-overview.png` and `01-released-case.png`, inspected visually.
  A preview lamp was added for visibility; these are presentation checks, not
  gameplay lighting or a continuous human playthrough. Geometry is a prototype.
- Existing dummy/native renderer shutdown allocator/resource warnings remain
  in scene-test/capture logs; no clean-shutdown or platform-runtime claim.

## Remaining work

Choose the first technology; review the normal approach / EVA / tether return
route and salvage feel in live play. Finalize equipment envelope, repair balance,
visual identity and service access from that feedback. Continued fitted wear /
individual battery charge storage, whole-game pose/item persistence and all
replenishment paths are future bounded work, not silently claimed complete.
The first domain loop has automated evidence; slice acceptance remains in review.
