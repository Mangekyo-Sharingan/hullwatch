# Alpha campaign scope — review pass

Date: 2026-10-08. Status: historical October 8 decision, superseded October 9 by open-ended survival.

## Superseding direction — October 9, 2026

The operator rejects a hardcoded campaign and chooses open-ended isolated
survival with substantially richer activities. Four required arrival waypoints,
a finite campaign and a mandatory voyage finish no longer define Alpha.
This document retains the previous review as history. Current direction and
proposed activity passes: `docs/design/open_survival_direction_pass.md`.

## Question

Does the current campaign satisfy M4's original 3–5-waypoint content-complete
target, and should that target remain the Alpha contract?

## Established scope

Production spec §8.2 explicitly requires 3–5 waypoints for Alpha. §§3 and 4.7
also require a multi-leg voyage, finite caches and a concluding voyage state.
§9 question 4 leaves 30–40 days and 3–5 legs as leanings, not approved balance.
Waypoints and legs are different counts: the starting location can be a waypoint
without being a completed travel leg. The approved contract must define its count.

The expansion spec's player vision adds chosen planet/star travel and sustained
mining/fabrication survival. M11's exit criterion is tested travel to a planet and
a star. Its completion establishes travel infrastructure, not fulfillment of the
original campaign's destination count, progression, duration or ending.

## Current source inventory (read-only)

| Destination | Nominal transit | Finite first-visit value |
| --- | --- | --- |
| Arden II (planet) | 2 days, 1 hour plotting | 4 ice units, 3 rations, CO₂ filter, survey report |
| Kestrel System (star) | 4 days, 2 hours plotting | 3 metal units, 3 rations, gasket, cache report |

Resources: `game/src/data/destinations/destination_arden_ii.tres` and
`destination_kestrel_system.tres`, both wired into `game/scenes/main.tscn`.
The unnamed starting sector is not a third authored destination.

`game/src/systems/nav.gd` permits visiting either non-current destination and
returning. First-visit caches do not replenish on revisits. `current_leg` counts
unique visited destinations; `arrived` means being at any destination outside
transit. There is no saved whole-voyage completion condition in this flow.
Two unique visits provide six nominal transit days plus three plotting hours,
before maintenance, stops or degraded-drive delays. This does not establish a
30–40-day campaign. Existing travel and arrival tests cover the two routes;
`test_m4_extras.gd` calls the second arrival “final” but checks ordinary arrival,
not a distinct campaign victory. The shipping checklist's checked “final
waypoint” item therefore does not evidence the current full-campaign ending.

Missing: approved campaign structure, at least one more authored arrival to
reach the minimum (two more for the approved four-arrival scope), waypoint progression,
a saved voyage finish, associated content and complete-route acceptance evidence.
Day-scheduled comms are not waypoint-linked campaign progression.

This review inspected source and tests; no game tests or builds were run.

## Approved Alpha scope

Keep a finite voyage as the Alpha content contract, with **four arrival waypoints**
after the starting sector (four main legs), within the original range. Allow
optional mining/salvage detours to support the same repair economy. Reuse existing
destination infrastructure and content where it fits the approved route.

Four is a bounded planning target, not a claim that four entries are implemented.
Do not expand to five merely to fill the upper limit. Destination names, route
order, total days, narrative beats and grounded conclusion remain separate
operator decisions. Xenonite internals and origins stay sealed.

| Choice | Alpha obligation | Consequence |
| --- | --- | --- |
| Four-arrival voyage with optional detours (recommended) | Complete bounded route, differentiated arrivals, finite caches, progression and a clear finish | Preserves the production voyage while using expansion systems |
| Open-ended survival | Explicitly supersede M4's finite campaign criterion; define a sustainable-session acceptance target | Campaign and authored finish move to a later milestone |
| Two-destination playtest Alpha | Explicitly name this a smaller playtest scope; keep 3–5 waypoint campaign unfinished | Tests existing content without claiming original Alpha content completion |

## Content-complete acceptance

1. Approved destination/leg count, starting location and permitted route choices.
2. Complete route catalog and distinct arrival value: supplies, maintenance
   decisions or grounded context; differences extend beyond sky color.
3. First-visit rewards stay finite; detours cost resources/time and do not reset
   rewards. Players can understand travel requirements and remaining progress.
4. Voyage progress and conclusion are authoritative saved simulator state;
   reload cannot duplicate rewards or erase completion. Existing saves migrate.
5. Failure/recovery and damaged-drive travel remain compatible with the route.
6. Every required leg and the complete voyage are playable without missing
   content. An uninterrupted human playthrough is separate evidence from tests.
7. All content/procedures are present before balance begins; counts alone do not
   prove the core maintenance loop or Alpha readiness.

## Operator decision — October 8, 2026

The operator accepted this scope for now and noted that the gameplay loop feels
empty in content. Broader gameplay/content planning is explicitly deferred.
The scope-confirmation task is complete; Alpha remains in progress. Four arrival
waypoints and optional mining/salvage detours are the current planning baseline,
not a final decision about the game's ultimate scope. Names, order, duration,
beats and ending remain open. No campaign implementation or game validation
was performed in this decision pass.
