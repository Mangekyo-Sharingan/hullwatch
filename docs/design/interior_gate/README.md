# Interior geometry and visual gate

Run from the repository root:

```bash
# Full gate on this Linux host (native rendering required)
python3 tools/run_interior_gate.py --display-driver wayland

# Windows: engine binary is selected automatically
python tools/run_interior_gate.py

# CI / geometry checks only; leaves visual acceptance open
python3 tools/run_interior_gate.py --checks-only
```

Use `--engine /path/to/Godot` to override the engine and `--output /empty/folder`
to choose the evidence directory. The default is a new timestamped directory
under `build/interior_gate/`. Existing evidence is never overwritten.

## What runs

The runner imports first, records source identity, then runs isolated startup
and nine focused suites. The new `test_interior_gate.gd` uses the real Player
capsule and scene. It covers:

- Floor/headroom samples and pressure ray fans in all ten walkable sections
  and both permanent service bays. Furnishings cannot mask missing pressure skin.
- All nine connecting hatches, opened through their normal API: forward and
  return movements at the center and two offsets.
- All seven shared throats: shoulder-height profile probes and positive controls.
- Both service bays, all four installed dock approaches, fixed doorway crossings
  and recorded approach paths. A detour cannot substitute for a clear throat.
- The outer airlock hatch after a fixture vent through the real interlock.
- Six catalog machine types, each occupying all three sockets, with real capsule
  movement through the entry and service apron. Bolted machinery leaves through
  pod teardown, preserving its normal removal policy.

Existing suites cover bulkhead depth, actual furnishing bounds, EVA mount access,
door motion/collision, hero cabin fittings and continuous controller traversal.
Fixtures run in isolated user data; they use temporary materials/capacity and
build jobs in a disposable scene. They do not write player saves.

## Visual review is a separate gate

The capture script renders six directions in every cabin, both sides of every
joint with its door open and closed, service bays, dock mouths, all seven pod
variants and six fully fitted machine loadouts. It uses normal lighting and the
analogue filter; pod inspections use the existing player flashlight. Camera
poses and flashlight state are recorded in `captures/manifest.json`.

Open the generated `index.html`. Inspect every area and its full-resolution
images for flat projecting sheets, exposed/unfinished edges, clipping, incorrect
joins, obstructed approaches and machinery fit. Record a reviewer name and a
`pass` or `fail` decision with a concrete note for **every area** in `review.json`.
Capture success alone does not mark visual acceptance.

```bash
python3 tools/run_interior_gate.py --check-review --output build/interior_gate/YOUR_RUN
```

The receipt is tied to the exact source/assets, runner, manifest and image hashes.
Source changes require a fresh run. Changed/missing images, stale/incomplete
reviews, resource/script failures and timeouts fail the gate. A rejected receipt
clears an earlier recorded PASS. The receipt records a review; it cannot prove
that a person or agent actually inspected an image.

| Exit | Meaning |
|---|---|
| 0 | Checks-only success, or full gate plus a valid completed visual receipt |
| 1 | Execution, geometry, asset, or evidence error |
| 2 | Visual review pending, stale or failed |

## Limits

This is sampled physics coverage plus visual inspection, not a mathematical
proof that every mesh is perfect. Capsule fixtures move at a fixed standing
height; the existing traversal suite separately exercises controller walking.
The seven-throat profile probes target structural intrusions, not every decorative
triangle. Lighting brightness/balance is a separate follow-up. A source run does
not validate a published EXE; native Windows and operator gameplay acceptance
remain distinct EA gates.

Current run and findings are recorded in `results.json` after review.

## October 12 result

The full gate passed automated checks and Codex visual review: **139 views across
38 areas**, 4,096 pressure rays and 78 bidirectional passages. Fresh full
regression: **92/92 suites**. Both generators reproduce all three scene files.
The runner self-check passes; independent review exercised 37 rejection/acceptance
probes. Run the retained runner check with:

```bash
python3 tools/test_interior_gate_runner.py
```

The gate found and fixed engine-bay repair fixtures obstructing the dock and pod
service panels buried behind the inset wall. Positive regression checks retain
both failure cases. Panel visibility/reach was corrected; its existing decorative
role and the pod room's teardown interaction are unchanged.

[Results](results.json), [full suite](full_suite_results.json) and
[visual receipt](review.json) preserve this run. The local complete gallery is
`build/interior_gate/2026-10-12-final-reviewed/index.html`. Source/image hashes bind
the receipt; future game changes need a fresh run. Human gameplay acceptance and
native Windows execution remain pending. No new EXE was delivered in this pass.

## Next goal: lighting and electrical optimization

Requested after this gate and now queued. Audit actual cabin/fixture brightness,
existing switch/breaker controls and electrical load accounting first. Tune
illumination for readable maintenance with darker unused spaces. Keep all lights
on feasible with healthy generation, while turning selected lights off saves
a useful amount of energy. Reuse current controls and simulator hooks; account
for actual enabled lights, power availability and installed pods without double
counting. Preserve deterministic fixed-tick simulation and save/load continuity.
Record all-on versus selective-off draw, deterministic regression results and
matched rendered before/after views. No lighting implementation in this gate pass.
