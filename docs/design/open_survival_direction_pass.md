# Open survival direction — Starpath comparison and Alpha plan

Date: 2026-10-09. Status: operator approved the six activity directions and requested plans plus first-slice implementation; detailed balance and follow-on scope remain open.

## Operator correction

The operator does not want a hardcoded campaign loop. The October 8 four-arrival
voyage is superseded. Hullwatch should support open-ended isolated survival,
with substantially more player possibilities. No mandatory destination sequence,
finite campaign duration, or fourth-arrival victory is required. Waypoint travel
remains a transport model, not a campaign structure. Final narrative answers are
not requirements for Alpha. Death/recovery policy is still a separate decision.

## Reference review and limits

Reviewed the official [Starpath announcement trailer on Steam](https://store.steampowered.com/app/1779540/Starpath/)
through Steam's current trailer manifest, sampling frames every six seconds, and
checked the [developer site](https://starpathgame.com/). The temporary contact
sheet is `/tmp/starpath-trailer-review.jpg`; no reference frames are game assets.
FFmpeg produced the sheet with several NAL warnings; sampled images establish
visual observations, not a complete continuous playback or verified gameplay.

Observable: planted interior spaces, physical terminals, modular ship forms,
exterior installations, varied planetary views and small craft/objects outside.
The footage gives ship activities and destinations physical presence. It does
not prove system depth, economy balance, or the interactions between them.

Official advertised features include derelict salvage, instrument-led exploration,
probes, configurable ship systems, greenhouse care and on-board terminal games.
Landing/vehicles are listed as future features. These are advertised plans for an
unreleased game, not demonstrated released functionality. Hullwatch proposals
below are our design interpretation, not claims that the trailer proves them.

## Proposed player loop

Observe a need or interesting contact → assess cost and risk → choose an
expedition or ship project → prepare tools, stores and systems → perform the
work → bring back resources/equipment/information → refit or improve the ship
→ choose what to attempt next. Maintenance continues throughout.

Ship improvements should increase capability and create new operating costs.
Survival needs must not force an inevitable decline or a perpetual sequence of
identical filter swaps. Renewable systems can buy stability; expeditions,
wear and specialization keep choices meaningful. Calm periods are earned.

## Proposed Alpha activity passes, in priority order

| Pass | What the player physically does | What changes mechanically | Existing foundation | Missing content/connection |
| --- | --- | --- | --- | --- |
| 1. Recover a useful machine | Identify a wreck contact, prepare EVA, isolate an exposed unit, detach it, transport it home, diagnose and fit it | Recovered equipment has condition, utility and upkeep; choose repair, install or material recovery | Contacts, EVA, tools, cargo, machine sockets, wear, fabrication | First small explorable wreck, safe salvage procedure, recovered-equipment cargo and condition transfer |
| 2. Refit for an expedition | Choose machinery, route power, configure supplies and tool storage, install/replace fittings | Different loadouts favor surveying, salvage or endurance; mass, power and heat impose costs | Bare pods, interchangeable sockets, circuits, stores and thermal simulation | Useful specialization choices, transparent budgets, manual fallback and clear equipment feedback |
| 3. Survey and investigate | Interpret contact readings, choose a route, scan at stand-off, launch/recover a sample probe | Information exposes opportunities before risking ship/suit; finite samples can unlock a specific practical capability | Sector contacts, scanner, destination travel, sample cargo | Distinct contact evidence, survey records, bounded probe equipment and recovery; discoveries preserve Xenonite secrecy |
| 4. Tend a living ship | Plant/tend one crop, inspect reclamation, service batteries/arrays, route a scarce resource | Renewable food/water/power give the player stability to fund exploration; expansion increases demand | Greenhouse machine output, water reclamation, solar/battery and compartment systems | Tactile care, visible growth/health, meaningful production inputs and storage limits; avoid adding meters without decisions |
| 5. Build and repair beyond the cabin | Fit an exterior utility, prepare access, repair a damaged connection, verify circuit operation | New installations enable expeditions while changing power/heat/service-access requirements | EVA construction, fixed hardpoints, exterior geometry, breaker and module effects | Functional exterior fitting choices and service procedures; maintain generated collision and readable access |
| 6. Make the ship your home | Arrange carried equipment and work areas, label a storage location, log findings, use a small terminal pastime | Layout improves access and preparation; records preserve discoveries; leisure adds contrast to danger | Carried props, storage, shared computer, ship log and lighting | Saved personal arrangement, useful organization and one compact leisure activity after the first expedition works |

### Prerequisite: make continued survival possible

Read-only source review identifies connections to resolve before claiming an
indefinite loop: processing ice must replenish potable water (a filter only
treats contamination); sealant production must refill a physical usable cartridge;
xenon replenishment needs a source and validated transfer, separate from sealed
DRIVE FEED regeneration. `sector.gd` clears extracted-object history on arrival;
revisit depletion must be designed and saved rather than accidentally reset.

Sources: `game/src/systems/{fabricator,water,nav,sector}.gd`,
`game/src/interactables/hull_patch.gd`, and `game/src/data/fabrication/`.
These are inspection findings, not newly run test results. A focused resource
continuity pass is the first technical recommendation, supporting the first
salvage expedition. Persistence fixes alone do not solve the content shortage.

All six activity passes and the resource continuity pass are proposals. Their exact interfaces, balance and scope need
bounded design packets before code; the operator has selected direction, not
approved every proposed feature. First priority recommendation is **one useful
machine salvage expedition**, connected to ship fitting and maintenance.

## First playable target — proposed

A contact promises an auxiliary power unit. Player considers EVA stores and
cargo space, prepares the ship, approaches, surveys the wreck, and makes it safe
to work on. The recovered unit comes home damaged. Player can repair and fit it,
or recover materials instead. Its benefits and servicing costs are visible.
Player then chooses another goal freely. Names/rewards and wreck layout are
provisional; no campaign lock or narrative revelation is introduced.

Start with one compact derelict and one salvageable equipment class. The value
comes from the complete interaction chain, not a large collection of empty
wrecks. A second opportunity must require a different decision, not merely a
new mesh or a longer task timer.

## Open-ended Alpha acceptance — proposed

- Player can choose at least three materially different goals from live needs
  and discovered opportunities, with understandable preparation/costs.
- At least one complete explore → recover → diagnose/refit → renewed expedition
  chain works through the actual ship and tools.
- Multiple viable ship configurations change what the player can attempt.
- Resource supply, finite first-visit caches, renewable production and depletion
  are defined; revisiting/reloading cannot accidentally reset harvested stock.
- Survey and resource opportunities persist deterministically without compulsory
  route progression. Space can remain mostly empty while discoveries are useful.
- Player progress is capability, knowledge and sustained ship condition. It is
  saved without a mandatory campaign completion flag.
- Maintenance remains traceable and skillful; improvements can reduce repetitive
  chores without eliminating the cost of operating the ship.
- A human play session demonstrates meaningful choices, clear procedures and
  periods of calm; existing automated tests are separate evidence.

These are proposed acceptance criteria awaiting refinement, not new validation.
Current Alpha stays in progress. No simulator tests or game changes in this pass.

## Decisions needed before the first activity implementation

1. First wreck type and recovered unit, plus detach/transport/fit procedure.
2. Persistence/depletion across revisits and availability of basic survival inputs.
3. Loss/recovery rules: permadeath, recoverable saves, or a costly rescue mechanism.
4. Extent of initial ship customization: current sockets/hardpoints first, versus
   expanding construction scope. Freeform hull construction is a separate decision.

## Longer-term candidates

A maneuvering/handling pass, freely designed hulls, orbital physics, rotating
habitats, station networks, landing, rovers and co-op require separate scope
approval. They are not required to make the first salvage/refit loop meaningful.
Continue grounded dread: no combat, agents hunting the player, supernatural
answers or jump scares. Retro controls should operate real systems; keep dense
ship detail, functional work lights and legible service paths.

## October 9 execution handoff

The operator approved the six additions and requested prioritized slice packets,
their interactions, then work on the first slice. Plans are in
`docs/design/survival_slices/README.md`. Parallel replenishment and full-state
persistence preparation are complete. Common salvage mechanics now have a
provisional battery fixture; the first technology choice remains pending.
