# Slice 01 — Useful salvage

Date: 2026-10-09. Status: prototype implemented; first technology choice and manual gameplay review pending. Operator approved the six activity directions and requested implementation to begin with slice 01; detailed values below are design choices to refine, not measured balance.

## Player sequence

Contact → inspect the wreck → isolate exposed equipment → detach with the wrench → physically carry a recovered unit home → diagnose with the multimeter → repair → fit in an existing socket, or dismantle for materials.

## Implementation steps

1. Author one compact open wreck with safe collision, a legible isolation control and exposed recovery mount. Use contacts/approach/EVA instead of a special mission launch.
2. Data resource defines recovered machine, initial condition, repair inputs, carried envelope, hold occupancy and scrap yield. First-tech recommendation: existing battery cabinet.
3. Simulator owns unique unit identity, isolation, release, condition, diagnosis, carried/world location, stowage and installation. World nodes render that state.
4. Use existing single carry slot and cargo port for transport; no remote extraction into ship inventory. Refuse transfer safely when hold/hand/socket is unavailable.
5. Multimeter reveals external fault; wrench plus actual stock repairs it. Verify before installation. Preserve salvage identity when removing or tearing down its pod; no full new-machine material refund.
6. Install through existing pod sockets, expose actual machine benefit and restore it after save/load. Dismantling is terminal and returns only configured recoverable material.

## Connections

Surveying identifies opportunities; specialization consumes the recovered equipment; living systems supply expeditions; exterior work provides access and power; personal storage organizes the result.

## Acceptance

- An ordinary contact leads to a complete recovery/refit or scrap loop with existing tools.
- Release, diagnosis, repair and fitting refuse out-of-order actions without consuming stock.
- Save/load/streaming/revisits cannot duplicate a unit, reward or fitted effect.
- Physical transport, socket effect, removal and pod teardown work; loss/refusal never silently destroys equipment.
- Manual procedure and full scene capture exist. Live subjective play remains separate from automated checks.

## Ownership and verification

State belongs in existing simulators or a small domain simulator where needed; data-driven definitions, typed events, fixed-tick behavior and save migration are required. Pin exact file/API ownership before delegated edits. Use deterministic scenarios and actual scene interactions; report exact commands/PASS markers when run. Do not treat historical tests, screenshots or a generated dashboard as current verification.

## Implementation checkpoint

Common recovery, transport, commissioning, fitting, scrapping and v5 persistence
are implemented, with an auxiliary battery as the provisional test fixture.
The operator choice is still pending; this is not approval of final battery
content/balance. Implementation evidence is in [01-result.md](01-result.md).
