# Door Asset Candidates — CC0 Door Prefabs for Hullwatch

Researched 2026-09-20 for the beta door pass. The current doors are procedural rusted-metal
slabs (`game/tools/build_world_layout.gd`, `DOORS` table — 2.2 m tall, 1.2–1.75 m wide, 0.16 m
thick) driven by `src/interactables/door.gd`. This doc surveys real prefabs to replace them:
pressure hatches, sliding bulkheads, hinged service doors, airlock doors.

**License policy applied:** CC0 1.0 only, per `docs/ASSET_SOURCES.md` / `docs/ASSET_CREDITS.md`.
CC-BY is recorded as a fallback because the policy already allows it with in-game credit.
License claims below were verified by reading the source pages and/or the license file bundled
in the downloaded pack — not search snippets. Format, poly count and texture facts were read
from the actual `.glb`/`.gltf` files where downloads were possible.

---

## Comparison table

| # | Candidate | Author | License | Format / Godot-ready | Poly & texturing | Scope | Fit & work needed | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | [Modular Space Kit — `gate-door`, `gate-door-window`](https://kenney.nl/assets/modular-space-kit) | Kenney | CC0 1.0 ([license](https://creativecommons.org/publicdomain/zero/1.0/), bundled `License.txt`) | `.glb` — **drop-in** | `gate-door` 1,752 tris; 2 meshes (frame 4.20×4.62×1.40 m, leaf 2.40×3.72×0.70 m); animations `open`/`close`/`open-close`; single 512² colormap atlas, baseColor only, metallic 0, no emissive | Door + frame, plus a full corridor/room kit (860–10,880 tris/module) | Sliding bulkhead, correct industrial read, but ~2× ship scale → scale leaf ×0.6 (→1.42×2.20 m); retexture mandatory (flat Kenney colormap; PBR maps absent) | **Drop-in (rescale + retexture)** |
| 2 | [Modular Sci-Fi MegaKit (Standard) — `Door_Simple`, `Door_Metal`, `Door_DarkMetal` + `Door_Frame_*`](https://quaternius.com/packs/modularscifimegakit.html) | Quaternius | CC0 1.0 ([license](https://creativecommons.org/publicdomain/zero/1.0/), bundled `License_Standard.txt`, OGA mirror) | `.gltf`+`.bin`+`.fbx`+`.obj` — **drop-in after URI fix** | Leaves 16/24/38 tris; frames 196/272/280/48 tris (`Frame_A`, `Square`, `SquareTall`, `Square_Blocked`); shared PBR trim sheets (BaseColor/Normal/ORM PNG) | Door leaves + frames + full modular interior kit (190 models, free tier) | Correct retro-industrial grid language; grid is ~4–5 m → scale ×0.5; glTF images point at bare filenames while textures live in sibling `Textures/` → move or patch URIs before Godot import | **Drop-in (URI fix + rescale)** |
| 3 | [vault door](https://opengameart.org/content/vault-door) | tbbk | CC0 ([OGA page](https://opengameart.org/content/vault-door)); textures from [3dtextures.me](https://3dtextures.me) (CC0) | `.obj`/`.fbx`/`.blend` — needs Blender | Small zip (1.5 MB); heavy hinged vault door + concrete wall block | Single door + wall | Best geometry match for a pressure hatch (hinged, round handle, heavy plate); discard the wall block, scale to 2.2 m, replace textures with repo materials, export glTF | **Blender prep** |
| 4 | [Rusted Gate](https://opengameart.org/content/rusted-gate) | knittel | Dual **CC-BY 3.0 _and_ CC0** (choose CC0; "attribution appreciated but not necessary") | `.blend` + 1024² PNG — needs Blender | 116 faces; UV unwrapped; one 1024² texture | Single gate/panel | Genuinely rusted, factory-deserted read; treated as a grated/service door panel rather than a hatch; export glTF + material swap | **Blender prep** |
| 5 | [Low Poly Doors Asset](https://opengameart.org/content/low-poly-doors-asset) | loafbrr_1 | CC0 ([OGA page](https://opengameart.org/content/low-poly-doors-asset)) | `.fbx`/`.gltf` + Godot project + `.blend` — **drop-in** | 17 doors, 1,340 tris total; 1K textures; materials set up | 17 doors (+5 window sizes) | Format and poly budget are ideal, but the set reads as generic/domestic doors in previews — inspect before use; likely useful as hinged service doors, not hatches | **Drop-in (style check)** |
| 6 | [asset jam spaceship hallways](https://marin1234.itch.io/asset-jam-space-hallways) | marin1234 | CC0 (author statement on page: "free under a CC0 license"); "No generative AI was used" tag | `.blend` + renders in a 114 MB zip — needs Blender | Not verified (contents not downloaded); 4 hallways + animated sci-fi door + barrels | Interior kit incl. one animated door | Hallway kit could dress the corridor, door is a bonus; verify format/quality on acquisition | **Blender prep / inspect** |
| 7 | [Space Station Kit — `door-single`, `door-double`, `door-single-half`](https://kenney.nl/assets/space-station-kit) | Kenney | CC0 1.0 (already in `docs/ASSET_CREDITS.md`; pack `License.txt` retained in repo) | `.glb` — **already in repo** (`game/assets/models/kenney_space_station_kit/`) | 40–52 tris; 0.4×0.7×0.10 m; shared 512² colormap atlas | Single/double leaves + wall-door variants | Already licensed and integrated; too small (0.7 m) and too cartoon for hero doors — baseline only | **Drop-in (already owned)** |
| 8 | [LowPoly Modular Sci-Fi Environments](https://opengameart.org/content/lowpoly-modular-sci-fi-environments) | Quaternius | CC0 ([OGA page](https://opengameart.org/content/lowpoly-modular-sci-fi-environments)) | `.fbx`/`.obj`/`.blend`, **no glTF** — needs Blender | Not verified; 10.5 MB | 2021 interior kit incl. doors | Superseded by the MegaKit above; only worth opening if the MegaKit free tier feels thin | **Blender prep (superseded)** |

---

## Drop-in candidates (detail)

### 1. Kenney — Modular Space Kit (2026-02-15, CC0)

- Verified: product page license field `Creative Commons CC0`, and the bundled `License.txt`
  ("Creative Commons Zero, CC0", creation date 15-02-2026). Downloaded and inspected.
- Door assets: `gate-door.glb` (1,752 tris, meshes `gate-door` + `door`, animations `open`,
  `close`, `open-close`), `gate-door-window.glb` (1,872 tris, same anims), `gate.glb` (frame
  only, 764 tris). Avoid `gate-lasers.glb` (2,156 tris, 14 meshes) — glowing lasers are exactly
  the neon look the art direction bans.
- Material: one material per model, single 512² `colormap.png` baseColor atlas, `metallicFactor`
  0, no normal/roughness/emissive. Two extra 512² colour variants ship in `Models/Textures/`.
- Fit: sliding bulkhead proportions, chunky industrial silhouette, animated. The leaf is
  2.40×3.72 m (ship doorways are 1.2–1.75×2.2 m) → scale ≈0.59 for a 1.42×2.20 m leaf. The
  frame is far larger than the doorway and would need a non-uniform scale or replacement by the
  ship's own generated jambs/lintels.
- To make it "Hullwatch": swap the flat colormap for a PBR set built from the repo's existing
  Poly Haven maps (`mat_metal_rusted`, `mat_panel_scratched`) or repaint the colormap to the
  analog palette; add a normal map so flat-shaded Kenney panels survive first-person proximity.

### 2. Quaternius — Modular Sci-Fi MegaKit, Standard tier (CC0)

- Verified: quaternius.com packs page license field `CC0` (linked to
  creativecommons.org/publicdomain/zero/1.0/); OGA mirror page carries the CC0 badge and hosts
  the free Standard archive (48.6 MB, 190 of 270+ models); the pack's own `License_Standard.txt`
  reads "CC0 1.0 Universal". Downloaded and inspected.
- Door assets (all under `glTF/Platforms/`, mirrored in `FBX/` and `OBJ/`):
  `Door_Metal.gltf` 16 tris, `Door_DarkMetal.gltf` 24 tris, `Door_Simple.gltf` 38 tris;
  frames `Door_Frame_A.gltf` 196, `Door_Frame_Square.gltf` 280,
  `Door_Frame_SquareTall.gltf` 272, `Door_Frame_Square_Blocked.gltf` 48.
- Texturing: PBR trim sheets (`Textures/T_Trim_*_BaseColor/Normal/ORM.png`, decals), materials
  `MI_Trim_01/02/03` — a genuinely textured retro-industrial look, not flat colour.
- **Pipeline gotcha:** the glTF `images[].uri` are bare filenames (`T_Trim_01_Normal.png`) while
  the textures ship one directory over in `Textures/` — the URIs do not resolve as shipped. Move
  the textures beside the `.gltf` files (or rewrite the URIs) before Godot import. The glTF also
  uses `KHR_materials_specular` / `KHR_materials_ior`.
- Fit: grid modules are ~4–5 m, so ×0.5 gets them into ship scale. Door leaves are essentially
  slabs with a few details; frames carry most of the read. Retexture = replace the trim sheets
  with the repo's existing materials for palette consistency.

### 5. OpenGameArt — Low Poly Doors Asset (CC0)

- Verified: OGA page license field CC0, download bundle contains FBX, glTF, `.blend` and a Godot
  project with materials set up; 17 doors, 1,340 tris total, 1K textures.
- Fit unknown (previews read as generic doors rather than spacecraft). Keep on the shortlist as
  a source of hinged service-door geometry because the formats and budget are exactly right.

### 7. Kenney — Space Station Kit doors (already owned)

- Already licensed and in-repo (see `docs/ASSET_CREDITS.md`). 40–52 tris, 0.4×0.70×0.10 m,
  shared 512² colormap. Useful as a fallback and for small lockers/utility doors; not hero
  geometry.

---

## Blender-prep candidates (detail)

### 3. OpenGameArt — vault door (tbbk, CC0)

A heavy hinged vault door plus a concrete wall block with a matching hole, shipped as separate
OBJ/FBX files and Blender sources (1.5 MB zip); textures sourced from 3dtextures.me (CC0).
The door origin was fixed by the author so it rotates correctly — useful for a hinged airlock
outer door. Work: discard the wall block, scale to the 2.2 m doorway, replace the textures with
repo materials, export glTF.

### 4. OpenGameArt — Rusted Gate (knittel, CC0)

116 faces, UV-unwrapped, one 1024² texture mixed from Yughues (CC0) maps. Listed under both
CC-BY 3.0 and CC0 — take CC0 and no attribution obligation applies (the page says attribution
"appreciated but not necessary"). Work: export glTF, rebuild the material for Godot's ORM
convention.

### 6. itch.io — asset jam spaceship hallways (marin1234, CC0)

The page states CC0 in the author's own words and tags "No generative AI was used". The zip
(114 MB) contains four sci-fi hallways, an animated sci-fi door, barrels and screens, and the
`.blend` scene used for the renders. Formats inside were not verified (download not taken), so
treat as a Blender-prep interior kit with a bonus animated door. Quality/style must be checked
against the "no glowing sci-fi neon" rule before use.

---

## Rejected (and why)

| Source | Finding |
|---|---|
| **Sketchfab CC0 filter** | No CC0 sci-fi doors exist there. Verified via the Sketchfab API with `license=cc0&downloadable=true`: "sci-fi door" → **0**, "spaceship door" → **0**, "airlock" → **0**, "sci-fi interior door" → **0**, "bulkhead" → 1 (a shark scan), "hatch" → museum/paleontology scans. The CC0 door results on Sketchfab are photogrammetry of real historic doorways — unusable here. |
| **Sketchfab (CC-BY fallback)** | Several clean, downloadable, low-poly sci-fi doors exist, all **CC Attribution**, e.g. [SciFi Doors Pack Vol2 – Door 01](https://sketchfab.com/3d-models/scifi-doors-pack-vol2-door-01-6ec8e701144d4d3aaabe3110087a8c20) (2,164 tris, PBR), [SciFi Door — Jen S Abbott](https://sketchfab.com/3d-models/scifi-door-game-asset-e446c4c5512d4f38b905a6c8c8899289) (2,104 tris), [Sci Fi – Door – animated — kevin.fbx](https://sketchfab.com/3d-models/sci-fi-door-animated-d60312a7dd504ff38459c7fbce119548) (1,474 tris, 1 anim), [chrisjones179](https://sketchfab.com/3d-models/sci-fi-door-fc800411abed4328a2ebf1f8ff6e29f8) (7,590 tris), [Stas_SayHallo](https://sketchfab.com/3d-models/sci-fi-door-ccb2c125b06f4c9097ea708cb82ca967) (14,922 tris — a CGCookie-course result, derivative-work question mark), [Anaïs3Dcraft](https://sketchfab.com/3d-models/low-poly-sci-fi-door-4fe380a99b0e4a8b90e007689a1b6999) (74 tris). All require a free Sketchfab account, in-game credit, and manual download. |
| **Fab** | No CC0 sci-fi door verified. Fab's listing API returns 403 without auth and the site is JS-rendered, so licenses cannot be verified programmatically; observed listings ("Sci-Fi Doors" by Apoc, "Sci-Fi Door [Spaceship Indweller]") are paid or under Fab's own EULA. **Do not ship from Fab without a manual license read in-browser.** |
| **Meshy / AI generators** | "Organic sci-fi door", "Weathered Bulkhead Door", "Futuristic Airlock Door" etc. are marked CC0 but are AI-generated — rejected per the no-AI-licensing-ambiguity rule. |
| **Paid itch packs** | [OZEA Studio Low Poly Sci-Fi Doors A-002](https://ozea-studio.itch.io/low-poly-sci-fi-doors-pack-a-002) ($4), [Sci-Fi Door Pack 01](https://sebastianm40.itch.io/sci-fi-door-pack-01) ($7.99), [Red's Corridor Asset Pack](https://redvampire.itch.io/corridor-asset-pack) ($4.50) — not free/CC0. |
| **EmaceArt Sci-Fi Corridors (LITE)** | The itch listing is now **404** (author's catalogue has pivoted to medieval/nature/retro packs). The reference in `docs/ASSET_SOURCES.md` is stale and should be dropped at the next edit. |
| **3dmodelscc0** | Site offline; the itch mirror carries props only (control panel, locker, generator, etc.) — no doors. |
| **KayKit Space Base Bits** | CC0 confirmed (repo `LICENSE.txt`), but the pack is a base-building/outdoor kit — no doors in the contents list. |
| **ambientCG** | No door models: the only "door" assets (`Door001`, `Door002`) are surface materials. All assets are CC0 ([license](https://docs.ambientcg.com/license)) — use for retexture maps, not prefabs. |
| **Poly Haven** | Site search for door models returns **0 results**. Textures only (CC0) — already the repo's material source. |
| **Godot Asset Library** | Searched via API (`filter=door`, `filter=sci-fi`): no door packs; only "Sci-Fi Exit Portal" and sound packs. |
| **2D-only packs** | [CoSeph Sci-Fi dungeon doors](https://cosephgames.itch.io/asset-sci-fi-doors) (pixel tileset), [Sr.Natzu Doors Scifi](https://srnatzu.itch.io/doors) (64×64 sprites) — not 3D. |
| **CGTrader / renderhub / Open3dModel free models** | CGTrader free downloads are "Royalty Free" (not CC0); Open3dModel is a conversion aggregator with unclear provenance (repo-ripping risk). |
| **OGA "Industrial Metal Door"** | CC-BY-SA 3.0 — share-alike is outside policy. |
| **OGA "Gear Door Study"** | CC-BY 4.0 — only a fallback with credit, and it is a fantasy-mechanism door. |
| **OGA "Sci-fi environment pack" (Irondust)** | CC0, 185 MB, but comments report broken `.blend`/FBX imports and contents are unverified — not recommended. |
| **Polygonal Mind CC0 registry** (via ToxSam's CC0 3D asset registry) | Doors exist (`Aero_Door_01.glb`, 316 tris, collection-level CC0 per `projects.json`) but the style is flat-shaded stylized, not analogue-industrial, and the registry carries no per-asset license metadata. |

---

## Top 3 (ranked shortlist)

1. **Kenney — Modular Space Kit `gate-door` / `gate-door-window`** (CC0,
   https://kenney.nl/assets/modular-space-kit) — the only CC0 door asset that is a GLB with
   baked open/close animations and an industrial sliding-bulkhead silhouette; **drop-in** after
   a ~0.6 rescale and a mandatory retexture from the flat Kenney atlas.
2. **Quaternius — Modular Sci-Fi MegaKit `Door_Simple/Metal/DarkMetal` + `Door_Frame_*`** (CC0,
   https://quaternius.com/packs/modularscifimegakit.html) — a real door + frame kit with PBR
   trim sheets and glTF exports; **drop-in** after fixing the texture URIs in the glTF and
   scaling ~0.5.
3. **OpenGameArt — vault door by tbbk** (CC0, https://opengameart.org/content/vault-door) —
   the closest geometry to a pressure hatch (hinged, heavy, round handle); **Blender prep**
   (glTF export + material swap) but the best candidate for the airlock outer door.

---

## Verdict for the beta pass

No CC0 asset exists that is simultaneously (a) glTF/GLB, (b) weathered-industrial with no neon,
and (c) high-fidelity enough to be a first-person hero door. The drop-in options are all stylized
low-poly kits (Kenney, Quaternius), so **a retexture/scale pass is unavoidable**, but it is
small: the repo already has the PBR maps and `.tres` materials that pass needs
(`game/src/data/materials/`, built by `game/tools/build_materials.gd`). The genuinely weathered
CC0 doors (vault door, rusted gate) are Blender-prep and are the best route for the two airlock
doors. If the team wants a bespoke hero hatch, kitbash the Quaternius frame with the Kenney
leaf animation and reuse the Poly Haven rust/painted-metal sets — cheaper than chasing a
pre-made door that does not exist under CC0.

Suggested acquisition order for beta: 1 → 2 → 3, with 4 (Rusted Gate) as an optional dressing
piece. Do not pull from Fab or Sketchfab without accepting attribution and a manual license
read; do not use AI-generated door models.

---

## Appendix — searches and verification runs

Web searches:

- `CC0 sci-fi door model glTF GLB free asset pack 2026`
- `OpenGameArt CC0 sci-fi door sci-fi interior doors 3D model`
- `site:opengameart.org sci-fi door 3D CC0`
- `itch.io free CC0 sci-fi doors asset pack bulkhead pressure door game ready`
- `poly.pizza sci-fi door CC0 model`
- `KayKit Space Base Bits CC0 doors pack contents`
- `Sketchfab CC0 downloadable sci-fi door model "CC0" bulkhead hatch`
- `"Sci-Fi Space Station Interior Pack" noahm1216 sketchfab license CC0`
- `fab.com sci-fi door asset CC0 creative commons free listing`
- `fab.com listing "CC BY" OR "Creative Commons" sci-fi door free download game asset 2026`
- `opengameart 3dmodelscc0 door airlock sci-fi CC0 model`

Direct verification (pages read / APIs called / archives inspected):

- License pages read: quaternius.com pack page, kenney.nl product pages, OGA asset pages,
  itch.io asset pages, `docs.ambientcg.com/license`, polyhaven.com model search.
- Packs downloaded and inspected (`glTF` JSON parsed for meshes, accessors, materials, images,
  animations, bounding boxes): Kenney Modular Space Kit 1.0 zip; Quaternius Modular Sci-Fi
  MegaKit Standard zip (incl. bundled `License_Standard.txt`).
- Sketchfab public API (`api.sketchfab.com/v3/search`, `license=cc0`, plus per-model
  `/v3/models/{uid}` license fields) for door, sci-fi door, spaceship door, airlock, bulkhead,
  hatch.
- Godot Asset Library API (`filter=door`, `filter=sci-fi`).
- ambientCG API v3 (`q=door`) and asset page for `Door001`.
- ToxSam CC0 registry (`projects.json` + all 17 asset JSONs) grepped for door/hatch/bulkhead.
- EmaceArt itch listing checked and found 404.
