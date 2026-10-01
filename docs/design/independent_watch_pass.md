# Independent watch pass — 2026-09-30

The operator authorized completing propulsion, then independently improving the playable loop and reference style.

## Changes

- Sealed drive tank and cassettes; functional detection, external diagnostics and maintenance, feed/thermal holds and slower single-cassette travel. Internal Xenonite technology stays out of player text.
- Each new watch receives its own wear resources, preventing damage or diagnosis from leaking between sessions.
- Main menu: continue, new/load slot selection, overwrite confirmation and persistent settings. Pause freezes movement and simulation, with save/resume/menu/quit actions. Slot replacement uses a flushed temporary file.
- WATCH REPORT at the warning board draws actionable inspection/service concerns and recent history from live simulators. STATUS and SHIP LOG remain available.
- Existing probes now provide external hardware refits. Diagnose failed components with a multimeter or scan wear, turn off the specified breakers, carry the wrench, open the cover, refit with one fabricated gasket, close and verify. Refits consume 15 simulation minutes; uncovered circuits cannot be re-energized. Service quality and costs live in wear resources.
- Fabricated oxygen candles can replenish the physical rack after its original stock runs out.
- Tube mode filters retired flat-layout compartments before simulator initialization, preventing unreachable corridor faults. Flat geometry retains its original compartment configuration.
- Automatic fault logs request diagnosis; exact modes appear after the operator traces the fault.
- A physical patch point serves each ship compartment. The engine-bay patch previously addressed the life-support compartment; it now serves the room containing it.
- Repeated warm off-white upper hatch surrounds and physical destination plaques borrow the equipment framing and ordered passage rhythm of the references. The mottled Xenon wall material, stronger analogue filter and slim single-deck layout are retained.

## Review captures

- [Hatch framing and destination plaques](shot_watch_hatch_fore.png)
- [Aft passage](shot_watch_hatch_aft.png)
- [Watch report](shot_watch_report.png)
- [Pause menu](shot_watch_pause.png)
- [Main menu](shot_watch_main_menu.png)

Generated ship, dock pod and world scenes reproduce byte-for-byte. All **88/88 headless suites pass**, including real new/save/menu/load flow and clean wear state across successive watches. Default main-menu startup exits 0. Localization contains 81 extracted strings. The expanded sim profiler passes at **199.7 us/tick** against the unchanged 200 us budget; its timing margin is narrow. Headless scene profiling passes (0.19 ms additional scene delta), which does not establish rendered FPS.

Godot still reports existing resource/renderer cleanup warnings during some script/capture shutdowns. No script errors were present in the final suite. This is source work; no Windows runtime verification is claimed.
