# Step 04 — Utility fitting result

## Output

Authored the original passive wall fitting `hw_utility_spine` in Blender. It has a recessed backpan, perimeter rails, three covered junction housings, four-point cover fasteners, two continuous bent conduit runs, three coupled branch runs, retaining clamps, and one restrained amber safety strip. The copper and return runs follow distinct routes; the center cover alone carries the strip, breaking up the repeated cover rhythm. It has no screens, controls, indicators, collision, animation, Xenonite imagery, or third-party geometry.

The source and export retain the pinned interface: origin centered on the mounting backplane; Blender Z-up / -Y front; glTF +Y up / +Z front; glTF bounds `(-0.25, -0.55, 0.00)` to `(0.25, 0.55, 0.16)` m. Blender-space imported bounds are `(-0.25, -0.16, -0.55)` to `(0.25, 0.00, 0.55)` m.

## Inspection

- Exported scene: one root named `hw_utility_spine`, one static mesh, no extra nodes, cameras, lights, images, textures, or animations.
- Mesh: 16,598 vertices, 21,375 edges, 8,784 triangles after glTF triangulation.
- Material slots: `hw_beige`, `hw_dark`, `hw_metal`, `hw_hazard_amber`.
- Face details, continuous bends, clamps, and fasteners are present in the imported GLB and visible in the preview.
- Neutral render of the exported GLB: [preview](../review/hero_utility_kit_preview.png) (1200×1200; SHA-256 `356bca3c91ccdcd7260de178952f123314d112a2cb8074620c53bf2a3e281226`). The temporary render camera/lights were not saved into the source or export.
- Existing Godot sidecar `hw_utility_spine.glb.import` remains valid and points at the model source. The integration owner imported the GLB and `test_hero_cabins.gd` passed against the live scene mesh, including bounds, nonempty geometry, facing, section placement and no-collider checks.

## Commands and reproducibility

Required export command, run repeatedly from the repository root:

```sh
blender --background --factory-startup --python art/blender/build_hero_utilities.py
```

Blender reported `PASS: hw_utility_spine glTF bounds ...; 8784 triangles` on each run. Source inspection and the neutral preview used a temporary script outside the repository:

```sh
blender --background art/blender/hero_utilities.blend --python-expr 'import bpy; result={"objects":[(o.name,o.type) for o in bpy.context.scene.objects],"materials":sorted(m.name for m in bpy.data.materials),"actions":[a.name for a in bpy.data.actions]}; print("SOURCE_INSPECT="+str(result))'
blender --background --factory-startup --python /tmp/hw_utility_inspect.py
```

Blender `5.2.2 LTS` was the only installed version (`docs/PRODUCTION_SPEC.md` names 5.1). The two consecutive final exports had identical glTF JSON, node/material/accessor/index layout, and identical positions, normals, vertex colors, and triangle indices. The only binary changes were in 177 `TEXCOORD_0` records, with maximum float32 deviation `5.96e-8`; the model has no images or textures, and this did not change rendered appearance or geometry.

## SHA-256

| File | SHA-256 |
|---|---|
| `art/blender/build_hero_utilities.py` | `83013350734219c80c20836ada0b7c4e7c5ae3c111862efafaa13bd66d11f00a` |
| `art/blender/hero_utilities.blend` | `52c6d446867a40a99de284d81c0624bf02a24c11145344affb5b9bcf27e8ee1b` |
| `game/assets/models/hullwatch/interior/hw_utility_spine.glb` (final export) | `5ac4524d7be94983c859c6137cc6f3812fc595ebd4cb629f07faae0cec70fe2f` |
| `game/assets/models/hullwatch/interior/hw_utility_spine.glb` (immediately preceding export) | `3169f07916728dfd19ba171850b61059fc7f51daaa770a67bde19dee1f5ed34e` |
| `game/assets/models/hullwatch/interior/hw_utility_spine.glb.import` | `b89d5df64fb5683ec0a7ead24928863b372e5fbb9a018c387b59dff58fa82369` |

## Environment notes

Blender's ordinary GLB export succeeded. The installed exporter logged that its optional MeshOptimizer library is unavailable; compression was not requested. Its `Material.use_nodes` deprecation warning is harmless in Blender 5.2.2. The `.blend` was authored with 5.2.2; opening that source in the project's documented Blender 5.1 was not verified. The GLB export, bounds, topology, materials, and passive/static content all passed inspection.
