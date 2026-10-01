# Movement feel pass — 2026-10-01

The operator asked for movement recovery, easier deck attachment and a smaller menu pass before Early Access.

## Movement

- Free-flight W/S previously thrust in the opposite direction to the camera. Forward now follows the same view direction as walking.
- Space pushes from reachable surfaces around the entire capsule, including walls and ceilings. It cancels incoming normal momentum before applying the outgoing impulse. Reach is deliberately finite; distant geometry cannot supply a push.
- Q prefers the deck below the operator over cached wall contacts. View direction does not control deck attachment. Nearby surfaces remain available for EVA attachment; if center rotation is obstructed, a checked feet-pivot turn can orient the operator away from a close hull.
- Space/Ctrl provide up/down thrust, Shift cancels drift, Z/C roll. WASD follows the camera. Released controls preserve drift with the existing small damping.
- Walking acceleration/braking respond faster. Crouch height and boot view position/orientation ease rather than snapping. Roll and reattachment rotate around the capsule center, preventing head lift into a low cabin ceiling. Boarding levels prior drift roll. A proposed boot orientation is checked against physical geometry before accepting it.
- The HUD names the boot mode, drift speed and recovery controls. The EVA manual describes the bindings.
- Main menu has a larger green wordmark, quiet subtitle, clearer CRT frame and larger click targets; existing save/load/settings flows remain intact.

## Reference

Reviewed sampled frames from the official [Starpath announcement trailer and store page](https://store.steampowered.com/app/1779540/Starpath/). Observable cues include rotated cabin views, warm practical lamps, grouped retro instruments and clear travel passages. Its store page describes momentum and six degrees of freedom. These inform the camera roll, restrained menu typography and drift handling; the unreleased game's exact input tuning cannot be established from footage. Hullwatch retains its own assets, slim tube layout, wall texture and analogue filter.

## Review

- [Drift and recovery controls](shot_movement_drift.png)
- [Deck recovery after rolling](shot_movement_landed.png)
- [Main menu](shot_movement_main_menu.png)

## Verification

Movement regression checks cover actual physics frames, forward direction, brake, vertical thrust, side/overhead pushes before collision, incoming momentum, roll, deck recovery, low ceilings, close-hull attachment, boarding orientation and sensor masks. Independent review found and verified fixes for low-ceiling recovery, close-hull attachment and rolled pilot boarding. The headless scene profiler passes at 0.32 ms added scene cost; this is not a rendered FPS measurement. The full regression run passed 88/88 suites (exit 0, exact suite PASS markers, no SCRIPT ERROR). Final player and smoke checks also pass after the outgoing-momentum refinement. Logs: /tmp/hullwatch-movement-suite/ and /tmp/hullwatch-movement-player.out. Shutdown resource warnings remain as in the prior pass. Source updated; Windows runtime and subjective human movement feel remain unverified.
