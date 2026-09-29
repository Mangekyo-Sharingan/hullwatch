# Propulsion module narrative

**Status:** electric xenon ion drive selected; paired cassette hardware and transit-linked wake implemented (2026-09-30). Power, heat and repair behavior remain open.

## Story premise

The ship's hull and drive cores use Xenonite: a material and technology far beyond the local repair economy. The main drive is an **electric xenon ion engine**. Xenonite forms the ion optics lattice that meters and accelerates xenon working gas with fictional, exceptionally low propellant use. It still needs electrical power, a propellant feed, heat rejection and expelled mass for thrust. The operator can read its power, temperatures, vibration and xenon reserve without being able to reproduce the lattice.

The contrast is the visual story: precise, almost seamless Xenonite at the heart of each drive, held in place by plainly human service hardware that has been patched, labeled and adapted over years. The ship is advanced; its maintenance life is not.

## Chosen drive: Xenonite ion lattice

Two replaceable **ion-drive cassettes** carry the Xenonite accelerator grids, neutralizer cathode and local xenon feed hardware. Their fictional advantage is propellant efficiency, not gravity manipulation: no artificial gravity, star-bending, or unexplained reactionless thrust. Keep the drive legible as a machine that consumes xenon and electricity, runs hot, and pushes the ship through long, gentle burns.

The broad behavior follows real electric propulsion: high exhaust velocity and low thrust trade against long acceleration periods. Ion engines use a power processor, metered propellant feed and neutralizer as well as the accelerator. The Xenonite lattice's performance is the science-fiction element. NASA's [ion-propulsion fact sheet](https://www.nasa.gov/wp-content/uploads/2015/08/ionpropfact_sheet_ps-01628.pdf) and [Dawn propulsion overview](https://science.nasa.gov/mission/dawn/technology/ion-propulsion/) are useful visual and systems references.

## Visual language and authored hardware

- Two matching aft-facing cassettes are mounted symmetrically on the centered stern drum; the old offset tank pair is omitted.
- Each cassette has an octagonal service shroud, accelerator-grid aperture, xenon feed/regulator, neutralizer, power-conditioning hardware, radiator fins and service fasteners. The Xenonite core is exact and clean; brackets and access hardware remain visibly human-made.
- At rest the aperture is dark. During a route burn a narrow blue ion wake appears; there is no chemical bell or permanent flame.
- The Blender source is `art/blender/build_ion_drive.py`; it regenerates `art/blender/ion_drive_kit.blend` and `game/assets/models/hullwatch/exterior/hw_ion_drive.glb`.
- Preserve the ship's grim, mottled material palette. Xenonite can be smoother and more geometrically exact than the surrounding hull, while still belonging to the same material family; human-made brackets and labels carry the roughness.
- Keep the silhouette functional and non-weapon-like. The drive points aft and reads as propulsion and heat management, not a cannon.

The generated pair is symmetric and clears the arrays, tether anchor, RCS hardware and catwalk. The remaining art review is side-angle service access during EVA.

### In-game captures

![Paired ion cassettes at rest, aft view](shot_ion_drive_stern_idle.png)

![Paired ion cassettes during transit, aft three-quarter view](shot_ion_drive_stern_burning.png)

![Close view of the cassette service hardware](shot_ion_drive_service.png)

![EVA-side view of the cassette pair and stern fit](shot_ion_drive_eva.png)

## Fit with the game

The current navigation simulator owns waypoint burns and the carried mass reserve; the UI labels this reserve as xenon propellant. The scene wake follows transit, including restored in-flight saves and fuel exhaustion. The next gameplay layer is power draw, grid/cathode wear, heat rejection and service; extend the existing PowerSystem, ThermalSystem and NavSystem rather than adding a second flight simulator.

## Decisions still open

1. Should transit draw a dedicated propulsion load from the current bus, and what circuits should shed first? The authored ship has a 500 W RTG and 4 kWh battery; its five nominal breaker loads total 610 W before any drive load.
2. Should drive waste heat warm the engine bay using the existing compartment model, or should M14 add a separate external radiator loop? The current `ThermalSystem` models cabin heat loss and heaters, not engine hardware.
3. Can one cassette sustain slower travel after its mate fails? If so, should the route take longer, consume more xenon, or both?
4. What repair loop should expose grid/cathode failures: scan/diagnose plus a replaceable cassette, or EVA service on individual parts?
5. How much can the operator understand from manuals and instruments? Leave the lattice's manufacture and origin unnamed until the story needs an answer.

The ion-drive mechanism, xenon working gas and paired stern mounting are selected. Degraded operation and the service loop remain provisional; record balance choices in `docs/OPEN_QUESTIONS.md` before expanding the simulation.
