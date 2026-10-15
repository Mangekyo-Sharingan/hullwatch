# EA02 — text orientation and early watches

2026-10-15. Agent-operated Linux validation; **operator acceptance is pending** (`EA02.4`). The initial implementation pass below used source only. Subsequent autonomous preparation is recorded separately at the end; published builds are unchanged.

## Scope and review state

The operator requested `EA02.1`–`EA02.3` explicitly while `EA01` still had no recorded acceptance. Those three tasks are implemented and ready for review. `EA01` is blocked on the native Windows/operator baseline and review verdicts; it has not been accepted, bypassed as complete, or re-scoped. No later slice was started.

## Fresh NEW WATCH and orientation

Launched the real main menu, selected **NEW WATCH → SLOT 1**, and reached the game with isolated userdata. Opened the existing world board, terminal and binder through their interaction/menu APIs. Captures use the native Wayland Forward+ window at **1280×800**. The clock was paused for readable captures; the automation did not test walking between props or an unaided human learning the ship.

- [Fresh watch](new_watch.png): no voice system or floating orientation overlay.
- [Quarters warning board](warning_board.png): persistent standing orders point to status, tools, the galley manual, service verification and the bunk.
- [Terminal status notice](terminal_notice.png): directs the operator to the board/manual and SHIP LOG handover.
- [Operator handover](operator_handover.png): standing orders are an archived text notice available through SHIP LOG, not a tracked objective. [Scrolled notice](operator_handover_end.png).
- [Manual controls and operations](manual_operations.png), [lower operations text](manual_operations_end.png), [diagnostics with 140% text](manual_large_text.png).
- Early service pages: [POWER](manual_power.png), [LIFE SUPPORT / WATER](manual_life_support.png), [THERMAL](manual_thermal.png), [DAMAGE CONTROL](manual_damage_control.png), [DIAGNOSTICS](manual_diagnostics.png).

The old binder overflow reproduced at **2771×633** in a 1280×800 viewport. Wrapped, bounded scrolling now renders at **922×560** at both 100% and 140% text. Actual PgDn input scrolled manual/terminal/board text; manual page selection stayed unchanged, and choosing a new page reset its text scroll. The rendered surfaces were visually inspected. Voice clips, generator, guide system/overlay, procedural speech helpers, retired suite and AGENTS voice-generation command were removed.

## First three days: real faults and procedures

Baseline occupied main-scene simulation produced **no wear faults over 72 ship hours**. Tuned data uses preworn components and existing condition/MTBF gates, with no authored day trigger or new scheduler. Unchanged wear rates; severe counterparts remain gated below 35% condition. Proactive servicing can legitimately prevent a fault.

The integrated follow-up loaded the real main scene, settled compartment occupancy, and advanced the normal six-second simulation ticks through 72 hours. It physically carried the scene's scanner, multimeter and wrench; used the real probes and their OPEN → REFIT → CLOSE menus; isolated/restored breakers through SHIP CONTROL; and interacted with the actual bunk for eight-hour sleeps beginning at hours 16, 40 and 64. Tools/stores were not injected, failures were not forced, and no simulator repair shortcut was used in this follow-up.

|Ship day|Fault|First failure, elapsed ship hours|Probe / isolation|Repair cost|
|---|---|---:|---|---|
|1|Lighting ballast: `ballast_open`|6.0233|POWER, storage / LIGHTING off|1 gasket, 15 minutes|
|2|Water pump: `pump_impeller_wear`|28.0550|WATER, water closet / LIFE SUPPORT off|1 gasket, 15 minutes|
|3|Heater: `sensor_drift`|52.3633|THERMAL, engine bay / LIFE SUPPORT off|1 gasket, 15 minutes|

Each scanner interaction logged wear without diagnosing the fault. Multimeter interaction revealed the mode, the board displayed it, and the corresponding manual sequence successfully repaired it. Three starting gaskets paid for all three refits; each restored condition above 92%, with **no repeat failures through hour 72**. The operator remained conscious and undamaged (`condition=0`, `incapacitated=false`); cognition reached level 1, so this is not a claim that longer-term atmosphere balance is accepted. The repaired watch survived a JSON save/load round trip with every component still healthy.

## Verification observed

- Windowed temporary NEW WATCH driver: `PASS: EA02 rendered NEW WATCH orientation`.
- Temporary real-procedure driver: `PASS: EA02 physical three-day procedures`.
- Headless startup (`--headless --path game --quit`) and `smoke_test` passed.
- Affected suites passed: `test_wear_model`, `test_new_watch_wear`, `test_component_breadth`, `test_power`, `test_water`, `test_thermal`, `test_operator_maintenance`, `test_maintenance_isolation`, `test_manual`, `test_ui_scale`, `test_computer_terminal`, `test_wall_computer`, `test_crt_panels`, `test_save_load`, `test_save_migration`, `test_scene_save_load`, `test_persistence_foundations`, `test_session_flow`, `test_m11_voyage`, `test_salvage`.
- Initial scoped batch: **21/22 checks passed**. Voyage had one assertion pinned to the former starting gasket total. Deleted that incidental assertion rather than re-pinning the new balance; the focused voyage rerun printed `PASS: test_m11_voyage`. Arrival/cache ownership and save/load behavior remain covered. This was not a full-suite sweep.
- Save version **11** removes retired guide state from both save collections while preserving watch time, stocks and in-progress maintenance. Extended existing migration coverage passed; earlier save formats still load.
- Localization extraction: `PASS: extract_strings (82 strings)`; AST graph refreshed.
- Existing negative-input suites emit their deliberate engine errors. ObjectDB shutdown-leak warnings remain (also observed in the pre-change occupied baseline); no GDScript errors occurred in the successful final runs. The first capture attempt exposed a duplicate inherited scroll field; that declaration was removed before final successful captures and suites.

Temporary automation from the initial implementation pass was removed after verification. Captures and this note are the retained slice evidence; no task or slice was accepted by the agent.

## Autonomous preparation — normal-input maintenance route

The operator subsequently authorized all remaining agent work in EA01–EA02. A visible Wayland Forward+ run used normal input events, live Player collision and the actual interaction ray—not direct `interact`, carry, repair, clock, transform or menu-selection API calls.

- Traversed spawn → quarters board/handover/bunk → galley binder/status bay → storage tools → POWER, WATER and THERMAL probes → quarters. Hatches were operated normally. A dropped-tool obstruction was negotiated by ordinary sidestepping.
- Picked up/retrieved all three scene tools. Scanner inspection, multimeter checks and wrench service menus were physically reached at all three probes.
- A [real eight-hour bunk sleep](32-real-bunk-sleep-summary.png) allowed the ballast fault to occur naturally. [Multimeter diagnosis](37-natural-ballast-diagnosed.png), actual LIGHTING isolation, [cover opening](41-ballast-cover-open.png), refit/closure and restoration succeeded. [Live STATUS](46-repaired-status-air-water.png) showed ballast 92% OK and lights restored; gaskets fell from three to two.
- The source-corrected replay reached the quarters bunk and used the real pause menu to [SAVE WATCH](saved-08-real-pause-watch-saved.png).
- The board previously demanded diagnosis for healthy scanned equipment because `diagnosed=false` was mistaken for an actual fault. Corrected to require `failed=true`; [the replayed board](saved-06-fixed-healthy-board.png) and a separate main-scene scan smoke showed no false diagnosis demand.
- Real Enter input also exposed NEW WATCH menu detachment before input consumption. The existing ScrollMenu suite now pushes actual viewport input: failed before the lifetime fix, passed afterward. The normal-input replay no longer emitted that error.

### Days two and three on normal input

Resuming the saved watch, the driver slept through real eight-hour bunk sleeps. Day two's **water pump (`pump_impeller_wear`)** and day three's **heater (`sensor_drift`)** failed naturally. For each, using only keyboard/mouse events and the live controller:

1. walked to the multimeter, picked it up, walked through the hatches (the airlock and engine-bay hatches are opened by the ray), and diagnosed at the WATER probe or the THERMAL probe;
2. went to the cockpit, sat in the pilot seat (E), aimed at the wall terminal, opened SHIP CONTROL and switched LIFE_SUPPORT off, then left the seat (X);
3. fetched the wrench, used the probe's OPEN → REFIT → CLOSE menu (one gasket each), and restored the breaker the same way.

Both faults cleared. [Repaired pump](normal_repaired_water_pump_main.png), [repaired heater](normal_repaired_heater_main.png), and a final real pause-menu [SAVE WATCH](normal_three_day_saved.png). Gaskets were consumed 3 → 2 → 1 → 0 across the three repairs (day one's was done in the earlier route). [Updated DIAGNOSTICS page](manual_diagnostics.png), [refit steps](manual_diagnostics_refit.png) and [breaker notes](manual_diagnostics_breakers.png).

### Agent-found findings (pending operator review)

|ID|Finding|Disposition|
|---|---|---|
|EA02.5|Real Enter on an empty NEW WATCH slot raised a null-viewport script error as the menu detached.|Fixed; existing ScrollMenu suite now pushes real viewport input (failed before, passed after).|
|EA02.6|WATCH REPORT said DIAGNOSIS REQUIRED for healthy scanned hardware.|Fixed; requires an actual failure. Main-scene scan smoke confirms.|
|EA02.7|A tool dropped while standing close to shelving was placed beyond or inside the shelf's collision, out of reach of any interaction ray. The multimeter is required for every diagnosis, so this was a soft-lock.|Fixed in `Player` (drop stops short of the first obstacle); regression added to `test_carry`, red before and green after.|

### Observations left for the operator (not changed)

- **The cupola is a seated station.** The pilot chair turns toward and deploys at the approaching operator (radius 1.8 m), growing its footprint in a tight cupola. Walking round it wedges the capsule between the chair and the bulkhead; leaving the seat with X places the operator clear and stows the chair. The only SHIP CONTROL stations (wall terminal, nav console) are in the cupola, so every LIFE_SUPPORT isolation on days two and three uses this. The manual now says so. Whether that is the intended feel is an operator call.
- **Faults land overnight.** At the default seed the days-two and three faults arrive at about 04:00, while a nightly sleeper is asleep, so the first the player sees is the cold or dark morning. Day one's lands at 06:00.
- **Day three is the coldest.** Sleeping through the heater's `sensor_drift` plus two LIFE_SUPPORT outages left every room near 8 °C and the operator at 5% hypothermia damage (cognition level 2) at the end of the run. After the repair the cabin returned to about 20 °C and vitals to zero within two hours. This was not lethal and is within the lenient-recovery rule, but it is the harshest moment of the first three days. It is a balance question for `EA02.4`, not tuned here. The airlock stays cold regardless (existing behaviour).
- The saved-watch CONTINUE places the operator at the storage spawn with empty hands (pose and carried item are not serialised). The EA03.3 checkpoint task covers it; nothing was changed here.

These corrections are recorded as `EA02.5`–`EA02.7`, pending review. The route demonstrates reachability and procedure operation with a scripted steering driver, not blind human comprehension or acceptance. EVA, return and save/load proof and candidate details are in [the EA01 play note](../EA01/play_note.md).

Final source sweep and the Windows candidate are recorded in the EA01 note; gameplay commit hashes are listed there.
