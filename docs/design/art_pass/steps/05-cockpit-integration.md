# 05 — Compose the working cockpit

## Objective

Integrate approved framing/hardware with existing working stations to create the first coherent hero cockpit. Requires 03 and 04. This packet changes composition, not terminal programs or gameplay.

## Owned files

`game/tools/build_world_layout.gd`; `game/tools/build_ship_geometry.gd` only for hero fitting placement; generated scenes; `game/tests/test_world_layout.gd`; `game/tests/test_hero_cabins.gd`; `docs/design/art_pass/steps/05-result.md`. Console/player/UI/simulator scripts are read-only unless a specific defect is reported for separate repair.

## Procedure

1. Record actual imported bounds for the live console banks, blade, forward instruments and seat. Preserve `NavConsole`, `ContactConsole`, `CommsTerminal`, `LogTerminal`, `ArchiveTerminal`, `WallComputer`, instrument ids and HUD target lookup names.
2. Follow the 02 elevations: shallow wall mounting with real frame/recess layers, controlled spacing and a central seat/aisle. Avoid returning to projecting desktop consoles, hiding instruments behind decorative plates or adding duplicate nonfunctional CRTs.
3. Mount utility fittings using their whole-height wall envelope. The WIP uses wall width at the highest point, y=1.95, rather than the center y=1.4; retain actual bevel clearance. Inspect all four copies and avoid accidental mirror winding/lighting errors.
4. Route cable/tray exits toward the mounted equipment or a covered chase. Allow access to existing hardware and its interaction ray. Refine repeated hardware variation only if the four copies visibly compete with the main stations.
5. Add panels/backplates to the owning wrapper, not inside an imported glTF subtree whose added children might not serialize. Verify PackedScene save/reload reproduces the result.
6. Test seat fold/swivel/deploy, boarding and exit, seated freelook, projected station labels, extended interaction reach and blade opening/stowing. Dress around real movement envelopes.
7. Regenerate both affected scenes. Capture approach, seated forward, port and starboard views with actual lighting and unchanged filter settings. Compare them against the rubric and initial captures.

## Validation and acceptance

Run startup smoke, `smoke_test`, `test_world_layout`, `test_hero_cabins`, `test_player_traversal`, `test_pilot_chair`, `test_pilot_seat_flow`, `test_seated_hud`, `test_wall_computer`, `test_computer_terminal`. All terminals remain useful from their normal positions. No prop overlap, blocked aisle, unreadable label or changed simulator state. Packed/reloaded composition is identical and both generators are deterministic.

## Handoff

Supply exact final mount transforms/bounds and wide/close render evidence. 06 consumes the composition; do not change shared materials here just to compensate for lighting.
