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

Larger counts cost some GPU time, so this was measured on 2026-10-16 rather than assumed.

### Measured on a GTX 1070 Ti, Linux Vulkan, 1280×800, vsync off

Old and new models were run in identical views, twice each in opposite order (240 frames per view after warm-up). GPU render time is the median per frame.

|View|GPU ms old → new|Triangles on screen old → new|
|---|---:|---:|
|Galley counter|1.58 → 1.59|13.2k → 16.7k|
|Breaker cabinet|1.79 → 1.80|10.5k → 17.1k|
|Wall computer|1.16 → 1.19|7.4k → 12.1k|
|Bunk|1.61 → 1.65|38.6k → 41.7k|
|Manual lectern|1.86 → 1.89|21.0k → 25.0k–29.7k|
|Tools on the rack|1.67 → 1.69|18.4k → 30.1k|
|Corridor from spawn|2.55 → 2.43–2.57|97k–102k → 109k–113k|

The GPU time differs by 0.03 ms or less in every close-up view, which is inside run-to-run noise. The spawn view moves by more than the difference between old and new, so it cannot show a cost. Whole-frame time stayed between 1.5 and 3.4 ms. Draw calls rose slightly in some close-ups (tools rack 115 → 136, breaker 76 → 84, galley 79 → 83) and are noisy at spawn, which suggests small per-model overhead rather than a triangle cost. On this card the extra triangles are not a measurable cost.

This is one mid-range desktop GPU on Linux. It says nothing about Windows drivers, integrated graphics, or the Steam Deck (same 1280×800, but a much weaker GPU). Treat the Deck as untested.

### Geometry-bound check and shadows (same machine, 2026-10-16)

To expose geometry cost, old and new models were rerun at 320×200 so pixel work nearly vanishes (four runs per version, interleaved).

- **Close-ups:** GPU time is identical for the galley, breaker, bunk, wall computer and lectern. The tools rack is about 0.02 ms higher with the new models (0.23–0.24 → 0.25–0.26 ms), consistently. That is the real geometry cost.
- **Spawn view:** the same build ranged from 0.55 to 0.98 ms between runs, so differences there are noise. An earlier apparent +0.3 ms did not reproduce.
- **The game is CPU-bound at spawn:** about 2.7–3.0 ms per frame against roughly 0.9 ms of GPU time at this resolution, with about 850 draw calls.
- **Shadows are the lever that matters:** 12 of the scene's 17 lights cast shadows. With shadows off at 1280×800, the spawn frame fell from 3.06 to 2.23 ms (GPU 2.55 → 1.85 ms) and the galley view's GPU time from 1.57 to 1.29 ms. The model upgrade costs about 0.02 ms in comparison. Single runs, one GPU.
- **Unexplained:** a shadows-off run at 320×200 hung twice and was abandoned. The 1280×800 runs above completed.

Conclusion for low-end support: model triangle density is not the thing to make configurable. Shadow quality, render resolution and CPU-side draw-call count are.

### Tomorrow on Windows

Compare `build/windows-candidate-2026-10-15-ea0102-…` (old models) with `build/windows-candidate-2026-10-16-models-…` (new models). The game has no FPS readout, and none was added. Use the Steam overlay's FPS counter, the GPU vendor overlay, or Xbox Game Bar (Win+G, Performance) and look at the galley, breaker cabinet and wall computer in both builds.

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
- **Not checked:** play on Windows, any Steam Deck or integrated GPU, the flashlight view of each model, and every model from every angle in the ship.
- **Small intentional deviations:** the wrench jaw slides across its gap (Z), not along the handle. The manual lectern's binder is teal with a steel spine, not the old emissive red. The wall computer's two lamps share the green phosphor material, and the game only re-tints the `Screen` mesh.
- **Details are small at hold distance.** Fine print, ticks and bolts read when a tool is inspected on a rack, not at arm's length.
- **Sources are scripts.** The older `art/blender/*_kit.blend` files still hold the previous twelve models; see `docs/ASSET_CREDITS.md`.

## Rebuild

`blender --background --factory-startup --python art/blender/build_hands_on_<group>.py` (multimeter, scanner_cutter, wrench_sealant_canister, probe_stand_bunk, galley_breaker) and `build_wall_computer.py`, then `godot --headless --path game --import` and `build_world_layout.gd`. `art/blender/hw_kit.py` holds the shared builder and the footprint table.
