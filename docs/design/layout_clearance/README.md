# Walkway clearance and outward service bays — 2026-10-09

## Playtester feedback addressed

The M13 tube conversion deliberately arranged the cabins as a train on one
central spine. This pass adds two permanent, opposite-side service bays:
life support to starboard and the galley to port. They extend the exterior hull
and are enclosed, lit parts of their existing compartments. The existing
constructible pod hardpoints remain available.

The scrubber, water reclaimer and O2 rack now occupy the life-support bay.
The galley counter, status terminal and mess table occupy the galley bay.
Cabin furnishings settle against the real imported model and collision bounds,
including movement toward the wall when previously left too far inward.
Interactive box colliders match their visible furnishings. The trunk clearance
guard requires an unobstructed 0.8 m central lane for the checked furnishings;
bay entry and service access use the actual player capsule.

## Cockpit snag root cause

The joint bore used twice the real neck length. Its jamb planes extended
17.5 cm into each adjoining cabin; the jamb normals also faced away from the
opening. They are now bounded by the actual joint endpoints, with inward-facing
normals. This fixes every generated tube joint through the shared builder.
The door leaf itself was correctly stowed when open.

Correcting the jambs exposed a thermal probe mounted inside an engine-room
neck. Automatic placement now selects a real section span rather than a gap
inside a multi-section room's bounding interval. The probe is also at service
height. The exterior walkway routes around the galley extension while retaining
normal 2.5 m reach to the life-support mount and clearance from a standing pod.

## Validation and evidence

Fresh results are recorded in [results.json](results.json). The focused suites
cover real capsule movement at both cockpit joints, bay access and machine
service rays, closed pressure surfaces, single-owner compartment occupancy,
matching visible/collision bounds, and EVA mount access. Both scene builders
reproduce identical ship, world and dock-pod scene hashes.

Seven native Wayland Forward+ captures use the real scene, normal lighting and
analogue filter. The capture script pauses simulation and hides HUD layers for
review; these pictures do not constitute a continuous human playthrough.

![Opposite-side service bays](review/branched_hull.png)

![Life-support machines against the wall](review/life_support_service_apron.png)

![Galley work area](review/galley_service_apron.png)

![Corrected cockpit joint](review/cockpit_hatch.png)

Save format remains v6; simulator ownership and existing node paths are retained.
This pass adds physical space without granting machines, stock or build refunds.
Native Windows execution and tester acceptance of the revised layout remain
separate review gates. Export and delivery evidence will be recorded below when
available. Existing renderer/resource shutdown warnings are tracked separately
from script errors and test failures.
