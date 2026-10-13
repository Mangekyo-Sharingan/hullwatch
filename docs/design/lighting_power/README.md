# Lighting and electrical optimization — October 12

Implementation and assistant validation complete. Operator brightness review and
native Windows gameplay remain pending. Source changes are local; no new EXE.

## Operator controls

Open **SHIP CONTROL → LIGHTING** at an existing control-capable terminal.
Each cabin, service bay, installed pod and exterior work light has a switch.
Rows show selected state and rated watts; the circuit header shows requested
draw. OFF choices survive breaker resets, shedding, JSON saves and pod rebuilds.
The master LIGHTING breaker still isolates all fixtures.

## Visual changes

Tube cabin energy drops from 2.0 to 0.9 and range from 4.8 to 4.2 m. Warm task
pools, the original mottled structure, CRTs and analogue filter remain. A pod now
has an authored ceiling fixture and a modest 0.7-energy beam. Switching off a
fixture also disables its per-instance emissive lens; it cannot change another
lamp's imported material.

[Interactive before/after comparison](comparison/index.html) contains 22 original
native frames. The complete local gallery is under
`build/lighting_power/2026-10-12-verified/index.html`: 26 BEFORE + 60 AFTER views.
All 26 matched cameras have identical poses, FOV, resolution and filter settings.
Images were reviewed without the handheld torch or brightness edits. Pod shots
advance only the module construction fixture. The retained AFTER manifest
blanket no-manual-ticks text is corrected by the erratum in results.json; its
original bytes and all images are preserved.

## Power balance

| State on the bare ship | Lighting | Total demand | Battery change/hour |
|---|---:|---:|---:|
| Prior fixed accounting | 200 W | 640 W | −140 Wh |
| All fourteen fixtures on | 320 W | 760 W | −260 Wh |
| Two unused cabin lights off | 270 W | 710 W | −210 Wh |
| Capture example: cockpit + life support + its service bay | 75 W | 515 W | −15 Wh |

Generation remains 500 W and the battery 4,000 Wh. All-on is available using
battery support; it is not indefinitely sustainable. With unchanged loads and
no failures, a full battery covers about 15.4 hours. Two cabin lights off save
50 W, or 1,200 Wh over 24 hours if kept off. These endurance calculations are
arithmetic; the real simulator test verifies an hour and exact 50 Wh savings.

The twelve interior fixtures cost 25 W each and two exterior beams 10 W each;
each installed pod adds 25 W. Rating data lives in `cabin_fixture.tres` and
`work_fixture.tres`. The circuit's former 200 W lump is zero so hardware is not
double counted. Ballast open/short faults cut/scale selected live hardware.
Handheld torch and celestial lights retain their existing behavior.

## Persistence and verification

Global save v7 / PowerSystem state v2 adds simulator-owned light preferences.
v6 saves migrate with missing preferences on and preserve their ballast faults.
Module restore now reconciles absent docks and physically replaces standing
pods; removed fixtures leave the bus before replacement registration. Rejected
duplicates cannot unregister the original. Open terminal menus refresh from
fixture events rather than retaining stale controls.

Fresh full regression: **92/92 suites**, exact PASS and exit 0, no script errors.
Coverage includes actual battery math, independent switches, breaker/shedding,
isolated emitters, faults/repair, v6 migration, same-scene and genuine fresh-scene
pod restores, no-pod restore, back-to-back restore and teardown. All three
generated scenes reproduce byte-for-byte. Headless startup, localization
extraction and diff checks pass. Native final capture exits 0 with exact PASS;
existing shutdown resource/RID warnings remain separate from script errors.

**Performance remains an open EA gate:** the fresh simulation profile is
209.3 µs/tick against 200 µs, FAIL. No rendered FPS claim. The profiler now
registers twelve real cabin loads; earlier nominal-only timings are not a
directly identical workload. Source totals are recomputed on hardware changes
and cached for bus queries, without incremental rounding or saved cache state.

[Results and image hashes](results.json), [full suite](full_suite_results.json),
[before manifest](before_manifest.json), [after manifest](after_manifest.json).
The earlier interior gate receipt remains evidence for its pre-lighting source;
this pass's full suite reruns physical coverage, and these captures review
lighting rather than claiming a new whole-ship visual receipt.

```bash
XDG_DATA_HOME=/tmp/hullwatch-lighting-check ./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/test_cabin_light.gd
XDG_DATA_HOME=/tmp/hullwatch-lighting-capture ./Engine/Godot_v4.7.2-stable_linux.x86_64 --display-driver wayland --path game --resolution 1600x900 --script res://tools/capture_lighting_pass.gd -- --output=/absolute/empty/folder --label=after
```

`--label=before` records the source currently being run; it does not reconstruct
an older lighting baseline. Preserve the actual baseline packet before editing.
