# October13 follow-up: survival foundations and stable power

## Exact delivered project

Recommended playtest: [v0.12.0-playtest.20261013.2](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261013.2).
Source **2ed3aed32b2c54c1e31737a0adde2a4d72a58caf** is pushed to main.
It includes the first checkpoint plus stable automatic power restoration,
lighting budget readouts, safe equipment returns, partial deposits, per-field
mining depletion and saved pending food production. Global saves are **v8**.
Windows PE version strings identify0.12.0 and the survival foundations playtest.

[Build identity and validation](survival_validation.json) records exact EXE/PCK,
release asset and capture hashes. Independently downloaded EXE, ZIP and
VALIDATION.json match every SHA256 hash; the ZIP contains the identical EXE and
exact SOURCE_COMMIT. The first checkpoint20261013.1 remains historicalv7;
use20261013.2 to exercise the follow-up mechanics.

## Current verification

- Fresh corrected source: **92/92**, exit0/exactPASS/no script errors; startup
  and string extraction PASS.
- Sequential simulation fixture: **174.7 microseconds/tick**, unchanged200 limit.
  The later two test-loader changes do not alter runtime or balance.
- Actual EXE extracted PCK in an empty project: **14/14** PASS—startup, cabin
  lights, computer terminal, v8 migration, interior gate, power, player traversal,
  salvage, session, mining, field depletion, modules, fitting and production.
- Same final exported project renders **60 captures** on Linux Wayland/Forward+,
  exit0 with exact capture PASS. Six original representative frames inspected.
  Normal analogue filter and fixtures, torch off; module construction advances
  only for the pod fixture. No power ticks/save writes during capture.
- Native Windows gameplay, operator brightness, full current visual acceptance
  and rendered Windows performance remain open. Existing shutdown object/RID
  warnings are separate from script/resource load failures.

The earlier exported candidate's catalog test-loader timeout is preserved in
local validation logs and corrected by stripping `.remap` before ResourceLoader
loads `.tres`. Its captures are superseded by this final exported-project packet.
No source scripts or development class caches were supplied to the empty project.

## Representative exported views

| Galley fixture on | Selected fixture off |
|---|---|
| ![Galley on](survival_capture/after_all_on_cabin_galley_starboard.png) | ![Galley off](survival_capture/after_selective_off_cabin_galley_starboard.png) |

| Installed pod on | Installed pod off |
|---|---|
| ![Pod on](survival_capture/after_pod_on_entry.png) | ![Pod off](survival_capture/after_pod_off_entry.png) |

[Cockpit](survival_capture/after_all_on_cabin_cockpit_bow.png),
[life-support service bay](survival_capture/after_all_on_bay_life_support_service_entry.png).
The60-view manifest is retained alongside these six images; complete originals
remain in build/validation/2026-10-13-survival/native-final/captures.

## Remaining development

[First survival packet](../survival_slices/execution_2026-10-13/README.md) starts02A
and resource/persistence foundations. Three specialized configurations, investigation,
physically reachable water/repair/fuel replenishment, exterior projects and personal
ownership remain scheduled. No indefinite-survival or whole-game persistence claim.
The first recovered technology choice is pending; common mechanics remain usable.
