# LATER.10 — hands-on model revamp

2026-10-15. Requested by the operator in-session; it is **not** one of EA01–EA12 and does not change the slice list. Agent verification only: **operator review is pending**, and no Windows build contains these models yet.

## What changed

Twelve models were rebuilt as original, scripted geometry in the faceted hull-canon style (flat shading, chamfers, low-sided cylinders), keeping each model's concept, origin, orientation and footprint. Detail was added where the player looks: controls, fasteners, grips, hinges, vents, labels and hazard marking as real geometry.

|Model|Triangles before → after|Notes|
|---|---:|---|
|Multimeter|368 → 2168|Rubber boot, bezelled LCD showing digits, ticked fluted dial, jack row, kickstand|
|Wear scanner|248 → 2044|Two-piece shell, ribbed grip, trigger, recessed lens, bar-graph display, hinged antenna|
|Wrench|300 → 2308|Captured sliding jaw with worm wheel and rack, ribbed grip, lanyard lug|
|Sealant cartridge|280 → 2336|Ribbed barrel, threaded collar, cut-tip nozzle, label with barcode, plunger|
|Hull cutter|344 → 2856|Strapped gas cylinder, regulator and gauge, hose, banded nozzle, trigger guard|
|Sample canister|372 → 3076|Pressure gauge, label plate, hazard band, bail handle on shoulder brackets|
|Diagnostic probe|248 → 1639|Bar-graph display, armoured jacks on tethers, guarded toggle, cable gland|
|Manual lectern|308 → 2510|Weighted base, tilt bracket, rail-lipped deck holding an open ring binder|
|Bunk|484 → 3054|Welded frame, quilted mattress, restraint strap, reading light|
|Galley counter|3532 → 7000|Real sink basin, framed doors and drawers, induction hobs with controls|
|Breaker cabinet|2770 → 6504|Isolator scale with ON/OFF legends, padlock hasp, trip-module banks, hazard header|
|Wall computer|192 → 4928|Rail-guided blade with barrel hinge, bolted bezel, vents, status lamps|

Larger counts cost some GPU time. `profile_scene` passed (7.21 ms against a 6.90 ms baseline, so 0.31 ms for the scene), but it runs headless and its own output says the loop is throttled, so it says nothing about GPU frame time on real hardware.

## Contracts kept (verified)

- **Footprints:** each model's bounds match the old one within 2 mm (`hw_kit.check_bounds` fails the build otherwise). The layout was regenerated; colliders changed by fractions of a millimetre and nothing else in the scene changed.
- **Animations, read back in Godot:** tools keep a 1.0 s `use_*` one-shot with its moving parts as before. The breaker keeps `toggle_on` (0° → 54°) and `toggle_off` (54° → 0°) on `breaker_main_lever`. The wall computer keeps `unfold` on `module` with identical keyframes, and `Screen` is still a mesh child of `module` with its origin at the display centre. Every animation track resolves to a real node.
- **Materials:** the existing palette, plus `hw_steel` and `hw_rubber` as non-emissive additions.

## Checks run

- Full sweep: startup, smoke and 97 existing suites, **99/99 passed** on the new assets.
- In-game captures of all twelve at 1280×800 in the game's own lighting ([after](in_game_after.png), [before](in_game_before.png), [tools side by side](in_game_tools_before_after.png)), with a small fill light added to the camera so detail is visible. Blender renders of old and new under the same lights: [sheet 1](models_before_after_1.png), [2](models_before_after_2.png), [3](models_before_after_3.png).
- Tools taken into the player's hand, with the use animation playing ([held and mid-use](in_game_held_and_use.png)); wall computer stowed, [sliding](wall_computer_sliding.png) and [deployed](wall_computer_deployed.png).

## Found and fixed on the way

- The Godot import cache kept the previous multimeter, scanner, wrench and sealant after a first reimport; those four showed old geometry in game until their cache entries were cleared. The cache is gitignored, so a fresh checkout is unaffected, but anyone rebuilding models locally should check import timestamps.
- The first agent scripts reached into `hw_kit` private helpers; they now use public `add_mesh`, `chamfer` and `AXIS_TILT`.

## Limits and open questions

- **No operator judgement yet** on style, density or colour. The Blender renders wash out the pale materials; judge from the in-game captures.
- **Not checked:** play on Windows, the flashlight view of each model, GPU frame time on real hardware, and every model from every angle in the ship.
- **Small intentional deviations:** the wrench jaw slides across its gap (Z), not along the handle. The manual lectern's binder is teal with a steel spine, not the old emissive red. The wall computer's two lamps share the green phosphor material, and the game only re-tints the `Screen` mesh.
- **Details are small at hold distance.** Fine print, ticks and bolts read when a tool is inspected on a rack, not at arm's length.
- **Sources are scripts.** The older `art/blender/*_kit.blend` files still hold the previous twelve models; see `docs/ASSET_CREDITS.md`.

## Rebuild

`blender --background --factory-startup --python art/blender/build_hands_on_<group>.py` (multimeter, scanner_cutter, wrench_sealant_canister, probe_stand_bunk, galley_breaker) and `build_wall_computer.py`, then `godot --headless --path game --import` and `build_world_layout.gd`. `art/blender/hw_kit.py` holds the shared builder and the footprint table.
