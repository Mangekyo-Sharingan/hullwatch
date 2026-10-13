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

## Delivered build

Published prerelease [v0.12.0-playtest.20261013.1](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261013.1)
contains source **e59500c5685d8e9a5b35b5dccae77409922af2b3**, confirmed on remote main.
Windows EXE metadata identifies 0.12.0; global saves are v7.

Linux Godot4.7.2 cross-export with the matching Windows release template passed.
This is the equivalent import/release export used by build.ps1; PowerShell and
native Windows execution are unavailable here. The actual EXE's embedded pack
passes **9/9** checks in an empty project: startup, cabin lights, computer terminal,
v7 migration, whole interior gate, power, player traversal, salvage and session.
Compiled scripts and the packed class cache are used; no source scripts supplied.

Independently downloaded EXE, ZIP and VALIDATION.json match all SHA256 hashes.
The ZIP contains the same EXE and exact SOURCE_COMMIT. Four assets are attached:
Hullwatch.exe, Hullwatch-Windows.zip, SHA256SUMS and VALIDATION.json. The EXE is
190,069,472 bytes. [Validation and identity](validation.json) records exact hashes.
Native Windows gameplay, operator brightness and rendered FPS remain pending.

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
