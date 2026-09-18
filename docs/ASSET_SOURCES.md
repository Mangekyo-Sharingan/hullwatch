# Asset Sources — Free / Commercial-Clean Shortlist

Curated 2026-09-18 for the M3 art pass (one module: cockpit + corridor + life-support closet + engine bay).
**Acquire at M3** — per spec §8.2/§8.4, no art until M2 logic is fun. Everything here is free to download
now but nothing should be integrated before M3.

License policy: CC0 preferred; CC-BY acceptable (credit list kept in-game); never ship raw source files
where the license forbids redistribution; verify each license on the official page at download time.

---

## 3D models / prefabs

| Source | License | Use | Notes |
|---|---|---|---|
| [Quaternius Modular Sci-Fi MegaKit](https://quaternius.com/packs/modularscifimegakit.html) | CC0 (free Standard tier) | Corridor/room shells, 190+ grid modules | Source/Pro tiers are paid; free tier is models only |
| [Kenney Space Station Kit](https://kenney.nl/assets/space-station-kit) + [Modular Space Kit](https://kenney.nl/assets/modular-space-kit) | CC0 | Interior modules, doors, props | glTF-native, tiny, cartoon proportions — retexture pass needed |
| [Kenney Factory Kit](https://kenney.nl/assets/factory-kit) + [Conveyor Kit](https://kenney.nl/assets/conveyor-kit) | CC0 | Engine bay machinery, pipes, crates | Same retexture caveat |
| [3dmodelscc0 packs](https://3dmodelscc0.itch.io/) | CC0 | Lockers, generators, electrical boxes, radio/console props | `.rar` archives; inspect one pack before pipeline commitment |
| [Poly Haven models](https://polyhaven.com/models) | CC0 | Barrels, tools, signage — photoreal props | Metres; pack separate roughness/metalness maps into ORM in Blender |
| [EmaceArt Sci-Fi Corridors (LITE)](https://emaceart.itch.io/sci-fi-corridors-modular-kit) | Custom: commercial use OK, **no source redistribution** | Closest style match (Alien-'79 retro-industrial) | WIP v0.1 — re-verify license each release |
| [Moltenbolt SciFi Pack](https://moltenmaps.itch.io/molten-maps-scifi-pack) | CC0 | Consoles, monitors, generators | Single small atlas — soft at first-person distance |
| [KayKit Space Base Bits](https://kaylousberg.itch.io/space-base-bits) | CC0 | Utility-room dressing | Free tier is models only |
| [Sketchfab CC0 filter](https://sketchfab.com/search) | **Per model** (default is CC-BY) | Hero retro-tech props: CRTs, gauges, valve wheels | Verify license field on every model page |

## Textures / materials

| Source | License | Use |
|---|---|---|
| [ambientCG](https://ambientcg.com) | CC0 | Painted metal, grate, diamond plate, scratches, rust, leak/sticker decals |
| [Poly Haven textures](https://polyhaven.com/textures) | CC0 | Hero surfaces (metal plate, rusty grate, corrugated iron) + CC0 HDRIs |
| [3DTextures.me](https://3dtextures.me) | CC0 | Secondary metal/rubber/sci-fi sets |
| [cgbookcase](https://www.cgbookcase.com/textures) | CC0 | Grunge overlays, fingerprints, dirt |

Hazard stripes: no verified CC0 PBR set found — author a two-color material + ambientCG imperfections.
Godot 4 wants ORM-packed maps (`StandardMaterial3D` ORM texture) — budget a packing pass.

## Audio

| Source | License | Use |
|---|---|---|
| [Sonniss #GameAudioGDC bundles](https://sonniss.com/gameaudiogdc) | Free "Unlimited User License" (no attribution, **no AI training**, no raw redistribution) | Machine rooms, room tones, HVAC, metal foley, relays, alarms — best free pro library |
| [Kenney audio packs](https://kenney.nl/assets/category:Audio) | CC0 | Relay/switch clicks, retro beeps, alarms, impacts |
| [freesound.org CC0 filter](https://freesound.org) | **Per sound** — use the CC0 filter | Fan/hum/leak/footstep loops; curate carefully |
| [BigSoundBank](https://bigsoundbank.com) | CC0/WTFPL | Industrial machines, hums, doors, tools |
| [OpenGameArt CC0 collection](https://opengameart.org/content/cc0-resources) | Per asset, CC0 collection | Computer-room ambience beds, drones |

Custom work required: paired healthy/unhealthy machine loops with shared spectral DNA (the
"sound is information" pillar) — layer/process sources or synthesize with `AudioStreamGenerator`.

## Fonts (all OFL)

| Font | Use |
|---|---|
| [DSEG](https://www.keshikan.net/fonts-e.html) | 7/14-segment diegetic readouts |
| [VT323](https://fonts.google.com/specimen/VT323) | CRT terminal body text |
| [Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono) / [B612 Mono](https://fonts.google.com/specimen/B612+Mono) | Panel labels, instrument data |
| [Departure Mono](https://departuremono.com) | Lo-fi pixel terminal/menu type |

## Godot 4 addons (evaluate at M2/M3, not adopted yet)

| Addon | License | Godot | Purpose |
|---|---|---|---|
| [tkCRTshader](https://github.com/TSUISHI/CRTshader) | MIT | 4.6 (active) | NTSC/RF CRT emulation for diegetic screens |
| [Cyclops Level Builder](https://github.com/blackears/cyclopsLevelBuilder) | MIT | 4.7+ (active) | In-editor brush blockout for compartments |
| [SaveState Lite](https://github.com/youssof20/savestate) | MIT | 4.3–4.6 (verify 4.7) | Atomic versioned dictionary saves |
| [godot-debug-draw](https://github.com/hardalex/godot-debug-draw) | MIT | 4.7 (active) | Sim-state debug visualization |
| [LimboConsole](https://github.com/limbonaut/limbo_console) | MIT | 4.3 (verify 4.7) | In-game command console for playtests |

Not adopted: interaction addons (none maintained for 4.7; our ray-based interaction stays),
sound managers (our AudioDirector + `AudioStreamRandomizer` covers it).

## Custom Blender work required (no good free source)

- Cockpit hero geometry: CRT screens with live emissive readouts, 7-segment displays, chunky
  switch/knob panels, valve/gauge clusters — the player's hands-on surfaces.
- Taped-label / hand-written docket decal set.
- Life-support closet bespoke machinery (matches the scrubber unit's procedure).
