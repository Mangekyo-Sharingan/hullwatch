# Step 11 — Exterior pass result

## Decision

The generated hull already carries the needed section rhythm: faceted pressure shell, collars and ribs, framed bow, stern tanks, arrays, the service truss, and the paired ion hardware. I kept that silhouette and its collision intact instead of adding another layer of fittings. The pass concentrated on proving service sightlines and correcting one real pod clearance conflict.

The shared dock pod shell is 3.6 m long along Z. The Quarters and Life Support port mounts are 2.85 m apart, so their visible shells overlap by 0.75 m if both are built. `ModuleSystem.can_install()` now refuses a second adjacent port pod while its neighbour is installed or under construction. The refusal appears on the operator HUD; removing the first pod makes the other mount buildable. Existing save state is not rewritten.

## Evidence

- [Exterior access map](../review/step11_exterior_access_map.svg) marks port and starboard pod envelopes, the exact overlap, truss/deck route, hatch lane, aft drive-service area, array keep-clear areas, and no-build volume.
- Seventeen 1600×900 real-render captures are in [`review/`](../review/): bow, stern, both sides, three-quarter with an installed Quarters utility pod, top plan, lighting-angle comparisons, idle/transit/single-cassette drive states, closed and open drive covers, tank access, and service diagnostics.
- The service close-ups use the actual carried flashlight. Two light-angle views are explicitly diagnostic; ordinary whole-ship views retain the scene's StarLight, settings, and analogue filter.
- `capture_screenshots.gd` now aims from the camera's eye position for closer exterior shots, so service targets sit in frame while the player remains on their real interaction point.

## Visual and access review

The stepped ribs, cowl, stern hardware, deck and attached pod read as one industrial vessel. `Reference/station_design.jpg` shows a clean, light cylindrical station with a spread of radial arrays. Hullwatch keeps its narrower faceted long-haul silhouette and existing aft array booms, carrying over the visible section rhythm and purposeful attached hardware instead of copying that finish or profile. The official Starpath trailer cue remains layered structure with deep equipment relief and practical light. Ordinary wide views are deliberately very dark under the current star lighting and filter; the outline remains visible, while service details need close approach and work light. No global exposure or horror-filter change was made to brighten inspection captures.

The port truss stops short of the Life Support berth, the airlock/EVA lane remains open, and the aft plume and array/boom volumes remain clear. Single-pod construction preserves the route; simultaneous Quarters and Life Support pods are refused because their shells intersect. A save that already contains both remains readable and unchanged, and the operator can remove either pod.

## Validation

The final Step 12 run rechecks the nine Step 11 acceptance suites: `test_hull_profile`, `test_hull_exterior`, `test_module_geometry`, `test_module_scene`, `test_eva_flow`, `test_airlock_scene`, `test_tether`, `test_propulsion`, and `test_player_traversal`. The integration test covers refusal, the HUD explanation, and successful construction after teardown. See [Step 12](12-final-validation-result.md) for the run logs, full-suite result and environment limits.

No hull dimensions, collision surfaces, Xenonite presentation, transit balance, or EVA procedure changed in this step. No release export or publication was made.
