# 10 — Roll the accepted language through the remaining interior

## Invocation boundary

Run this packet **once for one named room or room group**, selected by the operator. Suggested order: life support, engine bay, storage, galley, water closet, airlock. Requires accepted 09. Do not redesign the whole ship in one cheaper-model context.

## Owned files

Only the selected room's entries/helpers in `build_world_layout.gd` / `build_ship_geometry.gd`, their generated scenes, the specific authored kit source/exports needed, targeted regression tests and one room result document. Reserve shared generators to one writer. Do not change hero resources globally.

## Procedure

1. Read the accepted hero kit list and measure the named room's profile, machine footprints, controls, hatches, dock sleeve and player route. Record its function-specific visual needs.
2. Reuse approved frames/trays/fitting materials. Give each room a purposeful identity: air routing and replaceable filters in life support; protected external-service interfaces around engines; orderly stowage in storage; practical food/water surfaces in galley; sealed plumbing in the water closet; suit/pressure sequencing in the airlock.
3. Keep details attached to actual systems or passive utility routes. Do not add a new simulated component/repair action, fake screen or lore reveal as 'art'. Keep tool/scanner/probe access and all readout close behavior.
4. Apply asymmetry where functional layout warrants it. Avoid cloning the cockpit's monitor density into every room. Preserve clean central circulation and space to carry tools/sample canisters.
5. Check open cabinet/hatch/pod states and real bounds. Keep existing bolted machines, sockets and portable-machine placement/refund behavior unchanged. Do not conceal or remove critical service targets.
6. Regenerate, run room-specific scenarios, render wide/maintenance/doorway views and compare with the hero style. Do not rely on texture/noise alone to create density.
7. Document exactly which approved kit pieces were reused and any measured new interfaces. Update the room completion table; stop after this room.

## Validation and acceptance

Common smoke, `test_world_layout`, `test_hull_exterior`, `test_player_traversal`; relevant system/interaction scenarios. For life support run diagnostics/operator maintenance and atmosphere; for engine bay propulsion/thermal/maintenance; for airlock EVA/airlock/tether; for ports run module geometry/scene. Include save-load where an affected animated prop already stores a pose. Full suites run after integration milestones and before claiming the interior complete.

Every room must look part of the same vessel while retaining its distinct purpose. All maintenance targets and passages remain usable. Rendered photos and exact test output are mandatory handoff evidence. The next room is a new invocation, not an automatic continuation.
