# Asset Credits — Hullwatch

Third-party art assets bundled under `game/assets/`. Acquired **2026-09-18** for the M3 art pass
(one module: walls/floor of a 12×8 m room, industrial props).

**License policy:** everything listed here is **CC0 1.0 Universal** (public domain dedication) —
no attribution required, commercial use permitted. Licenses were verified at download time against
the source asset pages (Poly Haven) and the license file bundled in the pack (Kenney). No CC-BY or
more restrictive assets were downloaded or included; nothing was excluded for licensing reasons.

## Textures — Poly Haven (CC0 1.0)

Source: https://polyhaven.com/textures · Downloaded at 2K JPG (diffuse, OpenGL normal, roughness,
metalness where published; displacement/AO intentionally omitted).

| Asset | Source URL | License | Used for | Local path | Size |
|---|---|---|---|---|---|
| Metal Plate | https://polyhaven.com/a/metal_plate | CC0 1.0 | Scratched/worn painted metal panels (`mat_panel_scratched.tres`) | `game/assets/textures/metal_plate/` | 11.6 MB |
| Metal Grate Rusty | https://polyhaven.com/a/metal_grate_rusty | CC0 1.0 | Retired from the ship 2026-09-20 (floors are `mat_deck_plate.tres` now); kept for derelict/wreckage use | `game/assets/textures/metal_grate_rusty/` | 14.3 MB |
| Rusty Metal | https://polyhaven.com/a/rusty_metal | CC0 1.0 | Retired from the ship 2026-09-20 (the vessel is advanced, not a wreck); kept in the repo in case derelict wreckage needs it (`mat_metal_rusted.tres`) | `game/assets/textures/rusty_metal/` | 4.9 MB |
| Painted Metal Shutter | https://polyhaven.com/a/painted_metal_shutter | CC0 1.0 | Painted, scratched wall panels (`mat_wall_painted.tres`) | `game/assets/textures/painted_metal_shutter/` | 7.9 MB |
| Container Side | https://polyhaven.com/a/container_side | CC0 1.0 | Chipped-paint corrugated wall panels (`mat_wall_container.tres`) | `game/assets/textures/container_side/` | 5.6 MB |

License text: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/

## 3D models — Kenney (CC0 1.0)

| Asset | Source URL | License | Used for | Local path | Size |
|---|---|---|---|---|---|
| Space Station Kit (1.0) | https://kenney.nl/assets/space-station-kit | CC0 1.0 | Modular sci-fi interior props (containers/crates, consoles, pipes, wall modules, doors) | `game/assets/models/kenney_space_station_kit/` | 1.1 MB |
| Modular Space Kit (1.0) | https://kenney.nl/assets/modular-space-kit | CC0 1.0 | Door leaf geometry (`gate-door.glb` leaf node) fitted to every doorway as the door slab, with the repo panel material over it; `gate.glb` kept for a future frame pass | `game/assets/models/kenney_modular_space_kit/` | 0.2 MB |

License text: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
The pack's own `License.txt` (confirming CC0, distributed by Kenney / www.kenney.nl, 2024-04-10)
is retained at `game/assets/models/kenney_space_station_kit/License.txt`.
Only the **GLB format** models and the `Textures/colormap.png` atlas were kept; OBJ/FBX exports,
previews, and the preview HTML from the archive were discarded.

## 3D models — original work (project-authored, 2026-09-24)

Authored in Blender for this project (no third-party license applies; no attribution needed).
Sources: `art/blender/*.blend` (Git LFS) · Exports: `game/assets/models/hullwatch/` ·
Previews: `docs/design/asset_*.png`. Style rules in `docs/ASSET_SOURCES.md` / spec §6.1.

| Kit | Pieces | Local path |
|---|---|---|
| Cockpit hero kit | CRT console, portrait status board, switch bank, gauge cluster, seven-segment module | `game/assets/models/hullwatch/cockpit/` |
| Pod machine kit | Grow rack, work bench, battery cabinet, med cot, cargo rack, spare scrubber | `game/assets/models/hullwatch/machines/` |
| Life-support machinery kit | Scrubber unit, water reclaimer, fabricator, breaker cabinet | `game/assets/models/hullwatch/machinery/` |
| Pressure hatch | Airlock outer hatch leaf (fitted through `DOOR_STYLES["hullwatch"]`) | `game/assets/models/hullwatch/machinery/` |
| Interior dressing kit | Crew locker, mess table, filter rack, tool cart | `game/assets/models/hullwatch/props/` |
| Storage & galley kit | Crate stack, shelf unit, galley counter, pod service panel | `game/assets/models/hullwatch/props/` |
| Exterior fittings kit | Antenna dish, thruster cluster, hull vent, floodlight, handrail | `game/assets/models/hullwatch/exterior/` |

## Notes

- Materials generated from the texture sets live in `game/src/data/materials/` and are rebuilt by
  `game/tools/build_materials.gd`.
- No ambientCG assets were needed: Poly Haven covered all four required surface categories
  (scratched painted metal, grate/plate floor, rust, painted wall panel) at CC0 with 1K/2K JPG.
- Kenney's Space Station Kit is stylized (cartoon proportions) and will need a retexture pass to
  match the "Analog Industrial" palette, per `docs/ASSET_SOURCES.md`.
