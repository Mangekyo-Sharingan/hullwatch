# Step 06 — Materials and restrained wear

## Changes

- Added `game/src/data/materials/mat_hero_frame_paint.tres`: warm off-white enamel, metallic `0.18`, base roughness `0.78`, and a 128×128 seamless low-frequency noise map that varies roughness subtly. The ship generator binds it only to the hero rib frames; the existing graphite wall material is unchanged.
- Retuned the utility fitting's existing four Blender material slots in `art/blender/build_hero_utilities.py`: matte beige paint (`roughness 0.82`), dark matte inset/rubber (`0.90`), steel/copper conduit (`metallic 0.52`, `roughness 0.48`), and restrained amber (`0.72`). Geometry, bounds, axes, topology and slot count are preserved.
- Extended `test_hero_cabins.gd` to require the hero ribs' rough material and roughness map, alongside its existing profile, live-mesh, orientation and collision checks.
- No new textures from third parties or new asset credits. The existing utility-kit credit in `docs/ASSET_CREDITS.md` covers the original model.

## Visual review

- [Neutral utility material preview](../review/step06_utility_neutral.png) shows the authored palette and surface response without game lighting.
- [Cockpit operator-distance capture](../review/step06_hero_cockpit.png), [utility close view](../review/step06_hero_utility.png), and [quarters context view](../review/step06_hero_quarters.png) were captured at 1600×900 through the game's Forward+ renderer, normal cabin fixtures, original analogue filter, and no capture work light.
- In the scene, the ribs read as warm, dull painted framing; the utility panel and copper/steel runs remain distinct against the original mottled Xenonite. The utility wall is still too dim for confident fine-material judgment. Step 07 owns practical-light evaluation. Startup traffic/orientation cards remain in these WIP captures; Step 09 owns clean review and seated views.

## Validation

Commands run from the repository root with isolated `XDG_DATA_HOME=/tmp/hullwatch-art-handoff-userdata`:

```text
Godot 4.7.2 --headless --path game --import                           exit 0; GLB import completed
Godot 4.7.2 --headless --path game --quit                             exit 0
Godot 4.7.2 --headless --path game --script res://tools/build_ship_geometry.gd  exit 0 (twice)
Godot 4.7.2 --headless --path game --script res://tests/smoke_test.gd           PASS: smoke_test
Godot 4.7.2 --headless --path game --script res://tests/test_hero_cabins.gd     PASS: test_hero_cabins
Godot 4.7.2 --headless --path game --script res://tests/test_analogue_filter.gd PASS: test_analogue_filter
Godot 4.7.2 --headless --path game --script res://tests/test_crt_panels.gd      PASS: test_crt_panels
Godot 4.7.2 --headless --path game --script res://tests/test_cockpit_instrument_panel.gd PASS: test_cockpit_instrument_panel
Godot 4.7.2 --path game --resolution 1600x900 --script res://tools/capture_screenshots.gd -- --hero-art-only  exit 0; PASS: hero art captures
```

The two generated ship scenes were byte-identical: SHA-256 `4e2e9c027a8df17268a3ba04a691160f42f1957aa34d67dcbb3605166ae0a9b8`. The final utility GLB hash is `cee7d7568cb8a03af40252d691f03402e5a180fa204c6eaa4a0ef77723a9770d`; its mesh geometry hash is `20b512ee8c27e93b41919339a59556155e05f790d36d77d29e81d15011899ceb` (8,784 triangles, unchanged from the frozen geometry). Blender 5.2.2 was available; Blender 5.1 was not.

`mat_xenon_metal.tres`, `analogue_filter.gd`, and `analogue_filter.gdshader` have no diff. Their hashes are recorded in the Step 06 session log. Scene-loading headless scripts still emit the RendererDummy shutdown leak family recorded against the frozen baseline. The editor-backed `--import` completed the GLB import but printed 843 repeated native `Attempting to parent and popup a dialog that already has a parent` errors, even with clean XDG editor configuration; there was no `SCRIPT ERROR` or GLB import error. This editor-startup issue is unresolved and should be distinguished from game startup/test results.

Logs: `/tmp/hullwatch-art-step06/`. The utility exporter/neutral preview validation was performed by the Step 06 asset-authoring sub-agent; its exact commands and hashes are summarized above.

## Handoff to Step 07

Tune the existing hero fixtures against the saved scene captures. Start with the utility wall and aisle visibility; keep the localized warm pools, true breaker path, flashlight role and existing filter. Capture matched fixture/flashlight states before accepting a new setting.
