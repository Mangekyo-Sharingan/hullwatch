# 06 — Give the hero materials physical character

## Objective

Distinguish paint, metal, cable insulation, glass and upholstery using restrained authored wear. Requires 05's stable composition. Preserve the existing signature wall texture and analogue filter.

## Owned files

Hero-specific material resources under `game/src/data/materials/`; `build_hero_utilities.py` and its generated exports only where its material authoring needs changes; `docs/ASSET_CREDITS.md`; `docs/design/art_pass/steps/06-result.md`. A generator may be changed only to bind a specific new hero material. Existing `mat_xenon_metal.tres` and filter defaults are read-only.

## Procedure

1. Inspect current material sources and neutral previews. Identify which material responses are missing in actual captures; do not retexture everything by default.
2. Keep off-white framing worn but serviceable, graphite structure mottled, copper/steel conduits distinct and rubber darker/rougher. Make paint/metal differences read under real lighting rather than relying on a strong color tint alone.
3. Place wear where use/manufacturing explains it: fastener seats, panel edges, handles and supported cable bends. Avoid uniformly smeared dirt or high-frequency noise that worsens the strong analogue post effect.
4. Prefer vertex colors and original procedural material work when they suffice. Bake textures only where the viewing distance and mesh shape require them. Keep clean licensing and authoring provenance; no trailer-derived textures or fetched asset whose license was not checked.
5. Avoid changing a shared material in a way that silently affects every cabin, tool or cockpit console. Use an intentionally bound hero resource or a controlled authored variation.
6. Keep emissive signals functional: do not paint fake warnings/status lamps onto passive fitting covers. Any fixture emission must have a defensible powered appearance and coordinate with 07.
7. Export/import and capture close plus operator-distance views. Check clipping, texture scale, normal orientation and specular shimmer in motion. Retain the user's original material/filter settings during comparisons.

## Validation and acceptance

Run startup smoke and `smoke_test`, `test_hero_cabins`, `test_analogue_filter`, `test_crt_panels`, `test_cockpit_instrument_panel`. Verify original xenon/filter resources unchanged in the diff. Palette and roughness differences are visible without obliterating the existing mottling; no distracting shimmer or copied textures. Record texture sizes/material slot counts if introduced.

## Handoff

Provide material bindings, provenance, neutral/scene comparison captures and exact remaining light issues for 07. Do not compensate by flattening walls or weakening postprocessing.
