# Slice 06 — Personal ownership

Date: 2026-10-09. Status: planned. Operator approved the six activity directions and requested implementation to begin with slice 01; detailed values below are design choices to refine, not measured balance.

## Player sequence

Arrange tools and supplies for work, label storage, keep discovery records and spend an earned quiet period in the ship.

## Implementation steps

1. Persist a bounded set of carried-prop placements and named storage locations; respect access and collision.
2. Show stored quantities and equipment condition where the player organizes them; avoid duplicating simulator inventory in decorations.
3. Integrate survey and maintenance records into the shared computer/log.
4. Add one compact terminal pastime after the expedition loop is useful; pause/time rules remain explicit.
5. Keep purposeful visual detail, strong analogue style and calm ship audio; leisure is optional and does not gate survival.

## Connections

Organization improves preparation for every slice; logs make exploration cumulative; stable life support earns time to inhabit the ship.

## Acceptance

- Arrangement/names survive reload and retain usable walk/service paths.
- Storage labels refer to authoritative inventory; no duplicate items from moving containers.
- One optional calm activity works without interrupting safety readouts or becoming required upkeep.

## Ownership and verification

State belongs in existing simulators or a small domain simulator where needed; data-driven definitions, typed events, fixed-tick behavior and save migration are required. Pin exact file/API ownership before delegated edits. Use deterministic scenarios and actual scene interactions; report exact commands/PASS markers when run. Do not treat historical tests, screenshots or a generated dashboard as current verification.
