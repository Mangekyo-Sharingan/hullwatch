# Slice 04 — Sustainable survival and living ship care

Date: 2026-10-09. Status: planned. Operator approved the six activity directions and requested implementation to begin with slice 01; detailed values below are design choices to refine, not measured balance.

## Player sequence

Gather ice and feedstock, replenish actual reserves, refill usable tools, tend production equipment and preserve supplies for the next excursion.

## Implementation steps

1. Use replenishment_plan.md to close water, usable sealant and xenon transfer paths before promising indefinite travel.
2. Define finite harvests versus continuing sources; regeneration is explicit, never an accidental reload/revisit reset.
3. Connect greenhouse output to appropriate water, thermal and power inputs, with visible care/readings and one meaningful manual procedure.
4. Make fabrication outputs reachable as stock and physical items; consumption and transfer use one authoritative owner.
5. Balance enough stability for optional projects while equipment maintenance and expedition costs still matter.

## Connections

Supplies enable all excursions; salvaged processors/batteries increase resilience; specialization allocates scarce space/power; surveys locate shortages.

## Acceptance

- Mined inputs replenish actual potable water and usable repair supplies.
- Reaction mass has a physically legible acquisition/transfer path distinct from DRIVE FEED.
- Production pauses/recovers correctly with environment, power and supply changes; conserved stock persists.

## Ownership and verification

State belongs in existing simulators or a small domain simulator where needed; data-driven definitions, typed events, fixed-tick behavior and save migration are required. Pin exact file/API ownership before delegated edits. Use deterministic scenarios and actual scene interactions; report exact commands/PASS markers when run. Do not treat historical tests, screenshots or a generated dashboard as current verification.
