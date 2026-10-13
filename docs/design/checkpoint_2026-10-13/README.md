# October 13 checkpoint and Windows playtest

## Source checkpoint

The operator authorized pushing the interior gate, lighting/power and simulation
timing passes, followed by a Windows build, verification, then power tuning and
survival work. Fresh October 13 source validation: **92/92 suites**, exit 0,
exact PASS markers and no script errors; isolated headless startup also exits 0.
Existing shutdown object/resource warnings are retained separately. The fresh
sequential profiler passes at **182.1 microseconds/tick**, unchanged 200 limit.
The retained optimization.patch is evidence in unified diff format; its context
lines naturally trigger whitespace checks. Source/docs pass diff checks with
that immutable patch artifact excluded.

Windows export metadata now identifies 0.12.0 and this dated playtest. Export
uses the local Linux Godot 4.7.2 engine and the matching Windows release template,
with the same import/export options as build.ps1. PowerShell and native Windows
execution are unavailable here. Actual EXE embedded-project checks and release
asset hashes will be recorded after export; this document does not imply they
have already passed.

## Previous evidence

- [Interior gate](../interior_gate/README.md): historical reviewed 139 views;
  current source full suite repeats physics coverage.
- [Lighting](../lighting_power/README.md): darker native captures, independent
  saved switches and measured hourly savings. Operator brightness remains open.
- [Timing](../simulation_timing/README.md): exact state/event equivalence and
  unchanged 200 microsecond simulation budget.

[Current source suites](full_suite_results.json). Native Windows gameplay and
rendered performance remain separate open checks. This checkpoint precedes the
follow-up tuning and survival changes; a later source commit is not silently
included in its EXE.
