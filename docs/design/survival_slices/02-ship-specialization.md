# Slice 02 — Ship specialization

Date: 2026-10-09. Status: planned. Operator approved the six activity directions and requested implementation to begin with slice 01; detailed values below are design choices to refine, not measured balance.

## Player sequence

Choose an expedition goal, inspect load budgets, exchange equipment in pods, prepare supply/tool stock and operate a materially different ship configuration.

## Implementation steps

1. Define survey, salvage and endurance configurations using present sockets and fixed docks; no hull-builder rewrite.
2. Ensure every selectable machine has a real effect; expose power/heat/cargo/supply consequences in physical terminal readouts.
3. Integrate salvaged units and newly built units without mixing ownership, refunds or condition.
4. Add only missing fitting procedures and commissioning feedback; keep physical access clear.
5. Record chosen configuration and derived effects; reload reconstructs the same capability without extra energy/stock.

## Connections

Recovered machines provide choices, resource production funds endurance, exterior installations support loadouts, surveying changes which loadout is useful.

## Acceptance

- Three configurations lead to different capabilities/costs, not cosmetic presets.
- Swaps require actual equipment/materials and preserve unique ownership.
- Power shedding, removal, cancel, teardown and reload update actual effects consistently.

## Ownership and verification

State belongs in existing simulators or a small domain simulator where needed; data-driven definitions, typed events, fixed-tick behavior and save migration are required. Pin exact file/API ownership before delegated edits. Use deterministic scenarios and actual scene interactions; report exact commands/PASS markers when run. Do not treat historical tests, screenshots or a generated dashboard as current verification.
