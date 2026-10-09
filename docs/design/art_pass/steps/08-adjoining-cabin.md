# 08 — Complete the quarters hero cabin

## Objective

Carry the accepted cockpit language into its adjoining quarters without making the cabin a duplicate control room. Requires 03–07. Use the existing quarters function, bunk, locker and dock port.

## Owned files

Quarter-specific tables in `build_world_layout.gd` and hero dressing in `build_ship_geometry.gd`; generated scenes; `test_world_layout.gd` and `test_hero_cabins.gd`; existing dressing-kit Blender sources/exports only where a bounded refinement is necessary; credits; result document. Do not modify sleep, rations, vitals, module installation or other mechanics.

## Procedure

1. Measure quarters span and every current prop/port/hatch footprint. Preserve bed interaction/camera, manual/watch access elsewhere, side-dock entry and the travel aisle. Recheck the real sloped wall at each prop's complete height.
2. Apply the same frame/tray/material/light language at the appropriate density. Give this room a maintenance-and-rest purpose: restrained personal storage, serviceable cable routes and a small useful equipment arrangement. Avoid stuffing in arbitrary crates or desktop CRTs.
3. Reuse the original locker/bunk/dressing models before authoring additional pieces. If one new fitting is needed, define its axes/backplane/bounds before generating it. Stay with the existing 2.5 m single-deck profile.
4. Add only grounded, functional-looking dressing. Do not invent crew names, mission answers, slogans or narrative documents that resolve open questions. Do not present an unusable prop as a new maintenance interaction.
5. Inspect overlaps from more than one angle, including bunk, standing aisle, open compartment hatch and installed dock pod. Use real glTF bounds; collision dimensions alone are not proof of visual fit.
6. Verify sleeping/overnight flow and save/load do not inherit visual/transient states across a fresh watch. The art pass should not change wear resources or game balance.
7. Regenerate and record wide, bunk-facing, port-facing and hatch approach views with the same honest capture settings used for the cockpit.

## Validation and acceptance

Run startup smoke, `smoke_test`, `test_world_layout`, `test_hero_cabins`, `test_player_traversal`, `test_day_loop`, `test_scene_loop`, `test_module_scene`, `test_scene_save_load`. The cabin feels inhabited and purposeful, all existing interactions remain reachable, and a built pod can still be entered on foot. No floor-standing dressing narrows hatch approach or violates containment.

## Handoff

Provide cockpit and quarters paired captures and a list of kit parts/materials safe to reuse. 09 reviews the pair; do not expand to other rooms before that review.
