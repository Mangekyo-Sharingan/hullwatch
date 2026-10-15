# EA01 — autonomous preparation and operator handoff

2026-10-15. The operator requested all work possible without their intervention in EA01–EA02. This note separates agent verification and candidate preparation from native Windows execution, human play and acceptance. No operator verdict is inferred from automation.

## Normal-input EVA, return and save/load

A native Wayland Forward+ window at 1280×800 started at the actual main menu. The temporary driver used keyboard events and mouse-look events only for gameplay: normal Player physics/collision, interaction ray, tool/suit/airlock menus and pause/save/load menus. No player transform assignment, collision disabling, injected equipment, forced failure, simulation tick/repair shortcut or debug command was used.

Observed route:

1. NEW WATCH → SLOT 1; spawn in storage at approximately `(0, 0, -3.2)`.
2. Target and open the storage/airlock hatch; walk into the airlock.
3. Open the suit locker through the ray; refill the tank through its menu, then equip the suit.
4. Close both inner hatches; start pump-down from the physical airlock panel and wait for the normal running clock to reach vacuum.
5. Open the radial outer hatch; walk through it onto the exterior platform at approximately `(-3.73, 0, -0.65)`. Exterior occupancy, automatic tether clipping and suit-oxygen consumption were observed.
6. Walk back inside; close the outer hatch, repressurize, release the tether, stow the suit, reopen the inner hatch and walk home to storage.
7. Escape → SAVE AND MAIN MENU → CONTINUE. A new main-scene instance restored ship state and the stowed suit. The operator resumed at the normal storage spawn.

Result: `PASS: EA01 input-only EVA return and save-load`. The final run had no GDScript errors. This proves the sampled route and input path, not human discoverability, movement feel, Windows behavior or the separate EA03 EVA-save-checkpoint decision.

**Save-continuity limit found on a second route:** a watch saved at the quarters bunk reloaded at the storage spawn, empty-handed. Exact operator pose and hand state are not serialized (the explicit carriable restore policy). The first near-spawn round trip did not establish pose persistence, and is not claimed as such. The existing EA03.3 checkpoint/carry task covers it; nothing was changed in EA01–EA02.

## Concrete baseline finding

Normal Enter input on an empty NEW WATCH slot produced:

`ScrollMenu._unhandled_input: Cannot call method 'set_input_as_handled' on a null value.`

The selection callback synchronously replaced the scene, detaching its menu before the handler called `get_viewport()`. Fixed by retaining the viewport before dispatching the callback. Existing menu coverage was extended with real viewport Enter input and a scene-detaching selection: the consumer-visible input-consumption assertion failed before the fix and passed afterward. The input-only game route then crossed NEW WATCH and save/menu/continue transitions without the error. This is a technical correction, not an operator acceptance verdict.

### Two more defects found by the same route

- **EA02.6** — healthy scanned equipment was reported as `DIAGNOSIS REQUIRED`. Fixed (requires an actual failure).
- **EA02.7** — a tool dropped close to shelving could land inside or behind the shelf, unreachable by any interaction ray; the multimeter is required for every diagnosis. Fixed in `Player` so the drop stops short of the first obstacle; regression added to the existing `test_carry` suite (red before, green after).

Details, captures and the days-two/three normal-input repairs are in [the EA02 play note](../EA02/play_note.md).

## Candidate build (unpublished, Linux-cross-exported)

|Item|Value|
|---|---|
|Source commit|`690982112d053e424ee35542b7f3d4bdceab60c4` (local, not pushed)|
|Location|`build/windows-candidate-2026-10-15-ea0102-690982112d053e424ee35542b7f3d4bdceab60c4/` (gitignored)|
|ZIP|`Hullwatch-Windows-EA01-EA02-candidate.zip`, SHA-256 `8e8ddd4ccf9e1915a99574f4bf54492484bed727d4ca2502971b67bd65f782b3`|
|`Hullwatch.exe`|SHA-256 `ad4a3b5b3a87efdd021ba47327dee7a40c879277f56d5794c1a7ec03d3979577`|
|Contents|`Hullwatch.exe`, `Hullwatch-Updater.ps1`, `SOURCE.txt`|
|Identity|Embedded `source_commit` above, empty release tag (DEVELOPMENT), channel `windows`. No release URL, tag or update manifest was created.|

It was exported from an isolated copy of the committed tree (not the working directory, which holds unrelated untracked agent files), with the identity stamped only in that copy. It replaces nothing: the October 13 playtests and the earlier unreleased `build/windows-candidate-2026-10-14` are untouched.

**Observed checks.** Final source sweep on the same commit: startup, smoke and 97 existing suites, **99/99 passed**. Packaged contents, with the matching Linux editor mounting the embedded pack from an empty project: **18/18 passed** — identity, every `src/data` resource loads (`.remap`-aware), no retired voice resources are packaged, and 16 existing suites including save/load, migration and the session flow. A packaged NEW WATCH → SLOT 1 render passed on Linux Forward+ ([capture](packaged_new_watch.png)).

**Not established:** native Windows PE startup, graphics/input/audio, file locking and the PowerShell updater helper. No Windows host or VM is configured; Wine would not count as native Windows either. Test with disposable saves: this candidate writes save version 11 (older builds cannot load it).

## Pending operator review inventory

All entries remain pending. This checklist consolidates the existing roadmap IDs; it adds no milestone, slice, scope decision or acceptance. Repeated historical Windows reviews remain distinct records, not newly accepted runs.

|Review IDs|Operator decision or observation still required|
|---|---|
|EA02, EA02.1–EA02.4, WATCH / WATCH.8|Fresh-day-one orientation, actual maintenance/watch loop and acceptance|
|M3 / M3.2, RELEASE.3, GATE_PLAYTEST|External manual-only three-day success test|
|MOVEMENT / MOVEMENT.7, M12.4|Recovery, drift, seated interaction and encounter pacing feel|
|MENUS / MENUS.9, ART.24, RELEASE.17, WINDOWS_20261009.4, WINDOWS_MAIN_20261009.4, GATE_WINDOWS|Native Windows startup, menus, continuous gameplay and platform-specific coverage|
|M5.2, M5.4, M12.3, M12.6, RELEASE.4, RELEASE.5, GATE_PERFORMANCE|Real-hardware performance, full-session balance and current-build external review|
|M14 / M14.4, ART / ART.12 / ART.19 / ART.20 / ART.21, GATE_OPERATOR_ART|Propulsion/visual acceptance, localized detail, torch visibility and CRT readability|
|LAYOUT_CLEARANCE_20261009 / .5, BULKHEAD_THICKNESS_20261010 / .5, INTERIOR_GATE / .4, LIGHTING_POWER / .5|Walkway, bulkhead, interior and lighting acceptance in actual play|
|NARRATIVE / NARRATIVE.5, RELEASE.13, GATE_NARRATIVE|Recorded narrative/title decisions and review reconciliation; not silently decided here|
|SURVIVAL_SALVAGE.5, SURVIVAL_REFIT.4, SURVIVAL_SURVEY.5|Expedition, loadout and sample-return acceptance in EA03; not started here|
|CHECKPOINT_20261013 / .5, UPDATE_CHECKER / .5, MANIFEST_UPDATER / .6|Native Windows/Deck delivery, brightness, updater/input and interruption review|
|M0.2, ART.25, GATE_DOCS|Historical bridge/import/documentation review entries; no operator verdict fabricated|

## Remaining operator-only gates

- Native Windows execution is not available on this Linux host. Matching-editor execution of a Windows embedded pack, if performed, is explicitly **not** native PE execution.
- EA01.2 and EA02.4 require the operator's play; EA01.3 requires their accept/reject/later verdicts.
- EA01.4 can record agent-found technical findings now, but cannot incorporate operator findings that have not been supplied.
- Nothing in this preparation accepts an EA slice or starts EA03.
