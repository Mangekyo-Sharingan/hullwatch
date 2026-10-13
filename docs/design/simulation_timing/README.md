# Simulation timing — October 12

The fixed-tick timing gate is passing again. The limit remains **200 µs/tick**.
No balance values, save formats, tick cadence or signal ordering changed.

## Measured result

| Run set | µs/tick | Median | Result |
|---|---|---:|---|
| Same workload, before optimization | 216.1 / 217.8 / 219.4 | 217.8 | FAIL |
| Same workload, optimized | 177.9 / 189.6 / 188.1 | 188.1 | PASS |
| Repository profiler after optimization | 178.7 / 187.8 / 184.9 | 184.9 | PASS |

The matched-workload median cost is **13.64% lower**. Each run starts a fresh
process with isolated user data and advances 144,000 six-second ticks over ten
simulated days. Workload, generation, battery, source loads and seeds match.
Godot benchmarks ran sequentially, without concurrent Godot tests.

CPU: AMD Ryzen 5 2600; Godot 4.7.2 stable Linux, headless. This is the existing
eight-system/two-compartment fixture, with twelve 25 W lighting sources. These
measurements do not establish rendered FPS or native Windows performance.

## Cause and fix

Power constructed a full atmosphere report every tick just to read maximum
humidity. Thermal constructed a full report for each room just to read its
occupant count. Every atmosphere report also summed the same gas quantities
three times for pressure, oxygen and CO₂.

The fix adds live scalar getters for occupancy and maximum humidity, uses them
in the real simulator paths, and reuses one gas total within each report. Generic
Node report fallbacks remain available. No state is cached across ticks or
signals; synchronous pressure callbacks still affect subsequent atmosphere
events. The optimization touches three runtime scripts.

Temporary per-system timing pointed to Power (~49 µs), Vitals (~44 µs), Thermal
(~37 µs) and Water (~29 µs). Those instrumented figures include nested calls and
timer overhead; they locate costs rather than proving pass/fail. The temporary
instrumentation is outside the game source.

## Distinguishing workload from code changes

A single probe replacing only PowerSystem with HEAD's older implementation
took 215.6 µs under the same 300 W lighting workload. A separate pre-optimization
probe with 200 W lighting took 211.3 µs and generated fewer events. Both exceeded
the limit on this host. These probes show that reverting lighting power code or
reducing lighting demand alone would not resolve the current timing failure.
They do not reproduce an entire older build or isolate machine-condition changes.

## Correctness and retained evidence

Three optimized ten-day runs match the pre-optimization run **exactly**: all
eight saved system states, clock state and **189,827 ordered events**. Save/RNG
states are included. [Equivalence hashes](equivalence.json) preserve the result;
raw state/event packets remain in isolated `/tmp/hullwatch-timing-*` data roots.

Fresh full suite: **92/92**, exit 0, exact suite PASS, no script errors. Extended
tests cover live/removed/readded/restored occupancy and humidity, vacuum and gas
arithmetic/clamps, report-allocation spies, generic fallbacks, and a pressure
listener that changes gas before the following atmosphere event. Startup and
diff checks pass. Existing invalid-input diagnostics and shutdown leak warnings
remain distinct from script errors.

[Results](results.json), [full suite](full_suite_results.json), and the retained
logs record current validation. [Optimization-only patch](optimization.patch)
separates this fix from the existing uncommitted gate/lighting work. For a fair
rerun, apply/reverse that patch only in isolated copies of the same working tree;
keep resource data and profiler source loads identical. The experimental
profiler used the shared source-load hook supported by both old and new power
code. Its output snapshots occur after the measured interval.

```bash
XDG_DATA_HOME=/tmp/hullwatch-sim-profile ./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tools/profile_sim.gd
```

Historical 209.3 µs lighting-pass evidence remains historical; this pass supplies
the new timing acceptance. Source changes are local. No commit/push, Windows
EXE export, release or rendered gameplay capture was performed in this task.
