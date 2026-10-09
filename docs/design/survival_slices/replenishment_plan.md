# Replenishment paths for open survival

> Preparation snapshot: inspected before the first salvage implementation. Slice 01 now adds v5 salvage state, recovered cargo reservations and capacity-before-charge restore. Treat the inventory below as the audit baseline; implementation/results are tracked in `01-result.md`. Replenishment and whole-game persistence remain future work.


Date: 2026-10-09. Status: preparation by source inspection; no implementation or validation run.

## Scope and handoff

The operator authorizes six open-survival activity slices and the first salvage implementation. This document prepares resource continuity supporting those slices. The parent owns their plans, salvage implementation, persistence integration, result/status documents and roadmap. This sidecar owns only this file; existing art, generated scenes and other WIP remain untouched. No game edits, tests, builds, narrative decisions or dashboard refresh belong to this pass.

Production spec §§3–4, 7 and 9 govern the work, with the October 9 open-survival correction superseding the finite campaign. Expansion M8–M11 supply the existing extraction, fabrication, fitting and travel surfaces. Closed propulsion decisions remain binding: expelled xenon reaction mass and sealed DRIVE FEED are separate reserves. This developer plan does not introduce player explanations of sealed technology.

Names below are current APIs unless marked **proposed**. Balancing numbers quoted as current describe source defaults, not approved future tuning. Acceptance items are future checks, not PASS claims.

## Resource inventory: current sources, sinks and gaps

Paths in the tables are relative to `game/`.

| Resource / owner | Current sources | Current sinks / transfers | Missing connection or limit |
| --- | --- | --- | --- |
| Potable water / `src/systems/water.gd`, `WaterSystem` | Initial 120 L; greywater processed by `_tick_reclaimer()` into potable, capped at 150 L | `_tick_consumption()` draws 0.06 L/occupant/hour; only 80% reaches greywater. Reclamation default efficiency is 0.65 × (1 − contamination); rejected volume disappears. Overflow output also disappears | No external water intake or ice-to-water conversion. Clean steady consumption returns at most 52% of the drawn water; reserve inevitably declines without a new source |
| Greywater / `WaterSystem` | Consumed potable × 0.8; initial 40 L | Up to 2 L/hour processing, pump capacity/fault and life-support power gates; no greywater capacity | `install_cartridge()` reduces contamination, `purge()` clears it. `interactables/water_reclaimer.gd` consumes a `water_filter` and invokes both. Drain/prime currently cost no liquid. No condensate return or explicit waste accounting |
| Water cartridges / `src/systems/stores.gd`, `Stores` | Fabricator: 4 ice → 1 `water_filter`, 1.5 h | Reclaimer service consumes one | Filters treat contamination; they do not add water. No initial store of these in `scenes/main.tscn` |
| Cabin O2 / `src/systems/atmosphere.gd`, `AtmosphereSystem` | Initial compartment gas; lit O2 candles; `add_gas_moles()`; new compartment initialization | Breathing 0.035 kg/occupant/hour, leaks/venting; suit refill removes O2; gas mixing/airlock transfer conserves species | Candles are the implemented production path. No electrolysis machine; no claim that greenhouse makes O2. Initial gas on repeated pod construction must not become a free supply |
| O2 candles / `Stores` plus atmosphere rack/burn state | Fabricator: 3 ice → 1 `o2_candle`, 2 h; compartment config can stock rack candles (`compartment_main.tres` stocks 2) | `interactables/o2_candle.gd` draws a stores candle only when the rack is empty; `add_o2_candle()` then `light_o2_candle()` moves stock into burn hours. Output follows compartment `o2_candle_kg` and `o2_candle_burn_hours` | Count stores, rack and an active burn separately. Keep actual tube startup config in acceptance; retired flat-room stocks are not proof of live availability |
| CO2 / `AtmosphereSystem` | Breathing 0.042 kg/occupant/hour | Powered scrubbers delete CO2 according to configured capacity/efficiency; leaks and vents remove it | CO2 currently leaves the modeled economy; it is not a crop input, retained cartridge mass or recoverable carbon |
| CO2 filters / `Stores` and per-room atmosphere filter condition | Initial stores: 2 `filter_co2`; initial installed filter condition; fabricator: 5 ore → 1 `filter_co2`, 2.5 h; Arden first visit adds 1 | Filter wear uses `CompartmentConfig.filter_wear_rate_per_hour` (default 0.004); `interactables/scrubber_unit.gd` removes a filter without salvage and consumes a stores replacement | Wrench/power-off/open/remove/install/seat/close/power-on procedure exists. `seat_seal` does not consume a gasket. No filter regeneration path |
| Humidity / `AtmosphereSystem` | Breathing, candle operation, initial humidity | Scrubbing/dehumidification, venting and leaks | Dehumidification deletes water mass; it does not credit `WaterSystem.greywater_l`. Decide whether to retain this abstraction or recover condensate |
| Buffer gas / `AtmosphereSystem.n_n2` | Initial compartment gas and new pod initialization; generic `add_gas_moles()` API | Leak/vent loss; conserved compartment/airlock transfers | No N2 replenishment item or source. O2 alone cannot restore a normal mixed atmosphere after repeated venting; missing from the existing resource shortlist |
| Food / `Stores`, consumption in `src/systems/vitals.gd` | Initial 6 `food_ration`; first visit to each current destination adds 3; powered greenhouse module and grow racks | `_tick_rations()` spends 1 ration/occupant/day through `consume_part()`; no stock causes starvation | Food is renewable already. No ration recipe; no water/nutrient/temperature/crop-care input, spoilage or stores capacity. Module `_ration_hours` fractional production is not serialized; vitals consumption accumulator is |
| Physical sealant / generated `Carriable` props | Three authored cartridge props in `tools/build_world_layout.gd` | `interactables/hull_patch.gd` consumes the carried `sealant` with `Player.consume_carried()`; player frees the node, then verification calls `HullSystem.patch_puncture()` | No recipe, checkout, refill or durable consumed-instance record. `Stores.add_part("sealant")` alone cannot repair a leak. Fresh scene load can recreate a freed cartridge because missing saveable nodes leave no tombstone |
| Gaskets / `Stores` | Initial 1; metal recipe: 3 → 2 `gasket`, 1 h; Kestrel first visit adds 1 | `ShipSystem.maintenance_action()` consumes one for repair, refunds it on repair failure | All seven existing wear assets name `gasket` as their service part: RTG, battery, lighting ballast, heater, hull plating, scrubber blower and water pump. There is no separate worn-spare inventory |
| Components and tools / owning simulators and physical tool props | Initial wear resources and tools; `WearComponent.apply_repair()` restores condition and clears failure | Deterministic wear/faults; standard repair takes tool, isolation, scan/diagnosis, gasket and service time. `NavSystem.service_action()` repairs drive exterior hardware for time/tool without mandatory parts | Machine catalog entries have no per-instance wear fields. Tool use animation is not tool degradation: no implemented tool charge/wear sink. Do not invent replacement consumption for every prop |
| Xenon reaction mass / `src/systems/nav.gd`, `NavSystem.fuel_mass_kg` | Initial 1200 kg | Plot fuel/time, route consumption and `spend_fuel()` for contact approach (default 25 kg). Arden is 180 + 5 kg plot; Kestrel 340 + 8 kg plot. Transit reserves remaining route fuel from discretionary spending | No refill API, capacity or external xenon source. `CargoSystem` raw units are not kg. More DRIVE FEED does not replenish xenon; cargo mass does not currently modify route costs despite expansion intent |
| Sealed DRIVE FEED / `NavSystem` propulsion state | Existing UV-gated recovery; protected seed and capacity from `src/data/propulsion/drive_pair.tres` | Dedicated propulsion output consumes feed, adds engine-bay heat; unavailable cassettes/feed/cooling hold transit. One cassette slows progress and increases total feed use, with the same xenon route cost | Renewable under existing service/power rules. No cargo conversion or external refill is needed for this plan. Hotel bus cannot receive propulsion output |
| Suit O2 / `src/systems/airlock.gd`, `AirlockSystem` | `refill_suit()` draws only actual O2 removed from the interior compartment; 4 h capacity, at most 6 mol drawn per call | `consume_suit_o2(hours)` is invoked by vitals for vacuum exposure, at 0.035/0.032 mol/hour equivalent | Suit begins empty; equip/stow do not refill. Existing refill conserves O2. Suit survival does not create cabin gas. Review occupancy: vitals returns early without a manned compartment, so food/water and suit demand during exterior absence need explicit acceptance |
| Airlock gas | Pump transfers interior ↔ lock through `AtmosphereSystem.transfer_gas()` | Forced vent dumps gas/humidity; normal powered depressurize recovers gas to interior | Keep recovery useful; power/stall/interlock and interior pressure floor already exist. Do not charge for normal transfer twice |
| Hotel electricity / `src/systems/power.gd`, `PowerSystem` | Current scene has 500 W RTG; `set_generation()` supports generator entries; battery begins full (4000 Wh) and charges from net surplus | Served circuit load discharges battery; charge/discharge rate caps, capacity limits and shedding; wear can reduce generation/capacity. Base circuits: life support, scrubber, lighting, airlock, fabricator, xenonite UV | Solar arrays are authored geometry, with no `set_generation()` driver found in current gameplay. Batteries add capacity, not generation or free charge. Thermal heaters use availability/thermal models; do not assert every heater's nominal watts is separately billed on the bus |
| Raw materials / `src/systems/cargo.gd`, `CargoSystem` | `SectorSystem` seeded asteroids: ice 40%, ore next 40%, otherwise metal, 8–20 units; debris metal 2–5; anomalies exotic 4–8. Canister mining or scanner anomaly study; first-arrival ice/metal; build refunds | Fabricator up-front materials; module/machine construction; abstraction: all material units share hold capacity, default 120 units | No exotic recipe is registered. No sealant/ration/spare recipe beyond gasket. Each object is finite; untouched new chunks provide continuing supply, subject to density/settings and access. This is new stock, not a renewable harvested object |
| Machine/module stock / `src/systems/modules.gd`, `ModuleSystem` | Pay raw material cost then finish a build/fitting job; catalog-based effects | Remove/cancel refunds full recipe cost; pod teardown releases installed machines/jobs and returns their costs. `remove_machine()` refuses nonportable machines, but `_release_machines()` refunds them during pod teardown | Jobs advance with elapsed sim time, without a construction power gate. Full refunds ignore cargo's accepted amount. Per-instance recovered equipment/provenance is missing; salvage cannot safely be treated as free catalog construction |
| Capacity and ship condition | Cargo/power modules and machines add capacity sources; med equipment increases recovery; workshop reduces recipe time | Teardown removes capacity/effects and compartments; hull punctures cause leaks; gasket repair and physical patches restore function | Removing storage may overfill the remaining hold; removing battery capacity has no explicit clamp in `set_capacity_source()`. New rooms initialize gas/filter condition, and removed rooms lose their gas. These are transfer/policy boundaries, not new replenishment sources |

Stores accepts arbitrary positive part ids and has no weight/slot limit. Cargo accepts material ids without enforcing `KNOWN_KINDS`; adding a key alone does not establish a supported material. Guard new ids, finite positive quantities and conversions at public intake APIs, including save loading. Existing `consume_material()` lacks the finite/positive checks present in `add_material()`; malformed inputs must not increase stock or corrupt it.

### Current recipe and equipment economics

The four recipes above are the complete registered recipe set in `scenes/main.tscn`; expansion prose promising sealant, ration and exotic spares is not implementation evidence. `FabricatorRecipe` in `src/components/fabricator_recipe.gd` currently allows one material input and one integer stores output, with time. Reuse this for packaged replenishment before considering multi-input recipes.

| Machine resource (`src/data/machines/`) | Cost, units | Build hours | Contribution / ongoing load |
| --- | --- | --- | --- |
| `machine_grow_rack.tres` | ice 1, metal 3 | 5 | 2 rations/day; 90 W life support |
| `machine_work_bench.tres` | metal 3, ore 1 | 4 | 0.2 fabrication time reduction; 120 W fabricator |
| `machine_cargo_rack.tres` | metal 2 | 3 | +25 hold units; no listed power load |
| `machine_battery_cabinet.tres` | metal 4, ore 2 | 6 | +900 Wh capacity; no generator effect |
| `machine_med_bed.tres` | metal 3, ore 1 | 5 | +0.2 recovery/hour; 60 W life support |
| `machine_scrubber_spare.tres` | metal 5, ore 2 | 8 | Nonportable; 40 W scrubber; no functional `effect` specified |

| Module resource (`src/data/modules/`) | Cost, units | Contribution |
| --- | --- | --- |
| `module_utility_pod.tres` | metal 8, ore 4 | Room/sockets |
| `module_storage_pod.tres` | ice 2, metal 6 | Room/sockets |
| `module_greenhouse.tres` | ice 4, metal 10, ore 6 | 3 rations/day; 220 W life support |
| `module_workshop.tres` | metal 8, ore 4 | 0.35 fabrication time reduction; 400 W fabricator |
| `module_expanded_storage.tres` | metal 6, ore 2 | +60 hold units |
| `module_aux_battery.tres` | metal 8, ore 6 | +2400 Wh capacity |
| `module_med_bay.tres` | metal 7, ore 3 | +0.35 recovery/hour; 150 W life support |

Room and machine effects stack. A grow rack in a greenhouse receives both food outputs; a bare greenhouse is not currently only a room. Baseline bus demand with UV is 640 W; shedding 200 W lighting leaves 440 W. One grow rack brings that to 530 W unless another load is shed (e.g. 80 W fabricator while idle). A greenhouse adds 220 W. Renewable food therefore needs a feasible operating schedule or additional generation, not just another battery.

## Ownership and conservation contract

Keep the existing simulators as authorities. World nodes submit a physical action and render the result; they do not mint stock or mutate another simulator's fields directly. Use EventBus for committed transfer/status changes. Do not introduce a universal economy manager.

1. **One owner per quantity.** Cargo owns raw units; Stores owns packaged counts and proposed cartridge contents; Water owns liquid; Atmosphere owns species/rack/burn state; Airlock owns suit reserve; Nav owns xenon and sealed feed; Power owns stored energy; Module owns installed machine instances and build reservations. Sector owns unextracted source stock. Physical position and carried state are presentation/interaction state; the resource quantity must survive node replacement.
2. **Transfers debit only acceptance.** `source_before − source_after = destination_after − destination_before`, in one unit. For conversion, debit input = accepted output / configured yield plus named loss. Quantity rejected by capacity remains at source. Refuse invalid destination/state before paying; refund on later failure. Commit synchronously without time advancement or outward events between debit and credit, so no tick/save observes a half-transfer.
3. **Conversions are data.** Define ice units → water liters, sealed xenon cargo units → kg, sealant charge → patch count and any deconstruction yield in `.tres` resources. No implicit equivalence of raw units, liters, kg, Wh and machine count. Keep named processing losses; no requirement for a molecular chemistry simulator.
4. **Time costs remain real.** Preparation/service fast-forward uses `SimClock.fast_forward()` so every simulator advances. Powered processing uses fixed ticks; power loss pauses paid jobs without paying again or losing output. A job retains pending output if its destination is absent/full. Current Fabricator clears its job before checking Stores exists; this needs correction before expanding output types.
5. **Finite sites remain finite.** Extraction and equipment ownership persist through streaming, save/load and destination revisits. New opportunities come from unvisited chunks or explicitly authored renewal, never a cleared depletion dictionary or a consumed node respawning.
6. **Effects are not stock.** Capacity changes do not add water, charge or gas. Recompute installed contributions idempotently after load. Removal must check the capacity after removal, including its refund; block or preserve physical overflow until a policy is chosen. Do not silently discard it.
7. **Construction has provenance.** Build reservations record what was actually paid. A recovered machine is the same item moved through wreck → carried → ship cargo → socket; cancellation/unfitting returns that instance. Material recovery consumes it once. It cannot also receive a refund of catalog materials never paid.

Current shared transfer hazards to fix once in their owning paths:

- `CargoPort._handle_interact()` credits partial acceptance then `SampleCanister.unload()` empties all contents. Add **proposed** `SampleCanister.remove_amount(units: float) -> float`, then remove precisely accepted units; keep residual kind/quantity. Full-hold deposit must leave the canister unchanged.
- `_refund_machine()` and `_refund()` ignore the return from `CargoSystem.add_material()`. Preflight total capacity after removal before cancelling/removing, then return complete paid stock; refuse the action otherwise. Do not erase jobs/installed rows first. If later policy permits overflow, store it explicitly instead.
- `_pay_machine_cost()` / `_pay_cost()` debit a dictionary in sequence. Validate every material and all stock first, then commit or restore earlier debits if a later debit fails. There must be no partial payment with no job.
- `CargoSystem._on_destination_arrived()` can lose a partial cache reward while Nav already marks the destination visited. Retain unclaimed cache stock in a persisted source record and claim accepted units. Keep visited and cache remainder distinct; repeating arrival must not recreate the cache.
- `Carriable.save_state()` records identity only; `Interactable.save_state()` records enabled only. They do not persist placement or deleted identity. Use durable resource records and stable ids for new cartridges/equipment; coordinate placement restoration with the parent's persistence slice.
- `ModuleSystem._ration_hours` needs serialization. Removal/reinstallation must not reset fractional production or repeatedly credit a whole ration.
- New pod gas/filter initialization must be charged or sourced; teardown gas must be recovered or explicitly vented. Repeated construction cannot be an oxygen/filter factory. Existing saves reconstruct compartments before Atmosphere loads saved gas: keep that ordering.

## Staged implementation packets

These packets are a proposed order for the parent to schedule alongside the six authorized activity slices. Shared interfaces must be pinned with the persistence owner before parallel edits to Cargo, Sector, Module or SaveManager. Each file has one writer. The first salvage content can proceed before every replenishment packet lands, but it must not be presented as an indefinite survival economy.

### R0 — Transfer and identity foundation

**Files:** `src/systems/{cargo,sector,modules,fabricator}.gd`, `src/interactables/{sample_canister,cargo_port}.gd`, `src/autoload/save_manager.gd`; parent's equipment/placement persistence surface.

Implement the shared hazards above first, limited to paths exercised by salvage/refit. Agree a stable sector key and stable object/item ids. Sector currently makes ids `c_<x>_<y>_<z>` and serializes one `mined` dictionary; `_on_destination_arrived()` clears it. Proposed depletion shape is `depletion_by_sector[sector_key][object_id] = remaining_units`; migrate legacy `mined` under the saved current field key. Use destination identity plus seed when seeds can collide, preserving the starting sector key; never use day as a depletion reset. An untouched sector has generated initial yield, a depleted object has an explicit zero.

Pin equipment identity with the salvage owner: at minimum instance id, machine kind, source sector/object, condition, failed/diagnosed/scanned state, location/owner and any paid build reservation. Cargo handles transported equipment, Module installed instances; the parent chooses the exact record representation. The first object should have one recovery claim that consumes stock once. Loading a destroyed/consumed item must not create it again.

**Physical path:** mine/carry → cargo port accepts what fits → remainder stays in hand. Wreck detach → carry recovered unit → stow → fit the same instance. Full destination storage refuses visibly. Build cancellation/refund respects space and retains its job on refusal.

**Acceptance:** partial/full deposit conservation; refusal/rollback for multi-material payment; repeated remove/cancel gives no extra stock; capacity-removing teardown conserves contents; revisit and reload preserve depletion and recovered identity; fabricated pending output survives a missing receiver. Parent coordinates global save version migration (currently v4) rather than competing version bumps.

### R1 — Turn mined ice into usable water

**Files:** `src/systems/water.gd`, `src/systems/stores.gd`, `src/systems/fabricator.gd`, `src/components/fabricator_recipe.gd` only if needed; proposed `src/data/fabrication/recipe_water_charge.tres`, existing `interactables/water_reclaimer.gd`, `scenes/main.tscn` recipe registration and generated prop table only if adding a receptacle.

Minimum path: a powered recipe produces a packaged `water_charge` in Stores using the current single-input/count-output recipe. New conversion data specifies liters per charge and ice input; the numbers await balance. Reuse the reclaimer as the physical fill point. Separate fill from cartridge servicing so players cannot confuse water with a filter.

**Proposed API:** `WaterSystem.refill_from_stores(part_id: StringName) -> float`, accepting only a configured water-charge id. It validates Stores, positive finite configured liters, power/service state and room for the entire package, consumes one, credits liters and emits the actual transfer. Full or insufficient room refuses without consuming. Reuse this single path for new recovered water packages; do not let UI assign `potable_l`. Fractional raw-to-liquid continuous processing is a later alternative, not required for the first connection.

**Physical path:** cutter + canister → cargo port → start ice processing on fabricator → take/select a water charge at reclaimer → connect/transfer → verify potable gauge. Existing maintenance drain/filter/prime remains a separate procedure. Port connection and verification are interactions, not a new abstract progress bar.

Correct reclamation overflow by limiting processed greywater to available potable headroom at actual efficiency; zero output efficiency must not drain greywater unless explicitly configured as waste disposal. Expose cumulative treatment loss if useful to acceptance. Decide condensate recovery separately; adding it must debit actual Atmosphere humidity before crediting greywater.

**Acceptance:** a filter service does not increase liters; a water charge does; full tank/refused transfer retains charge; powered production pauses/resumes; conversion never exceeds input yield; normal draw/reclamation follows losses and retains overflow; save at paid job, packaged output and after fill cannot duplicate charge. The resulting reserve sustains a new expedition without arrival supplies.

### R2 — Replenish the physical sealant cartridge and service stock

**Files:** `src/systems/stores.gd`, existing `interactables/{carriable,hull_patch}.gd`, `src/player/player.gd` only to support non-destructive tool use; proposed `src/data/fabrication/recipe_sealant_charge.tres`; `tools/build_world_layout.gd`, existing fabricator recipe registration. Reuse a storage/tool rack or service bench as refill point.

Keep the three original cartridge identities as reusable physical shells. Stores owns **proposed** `cartridge_charges[cartridge_id]`, seeded once for a new run; each `Carriable` carries a stable generated id and renders full/empty status. Do not initialize a full charge on every `_ready()` or load.

**Proposed APIs on Stores:** `get_cartridge_charges(cartridge_id: StringName) -> int`, `refill_cartridge(cartridge_id: StringName) -> bool`, `consume_cartridge_charge(cartridge_id: StringName) -> bool`. First packet uses one charge per cartridge/patch, matching current one-cartridge usage; `refill_cartridge` validates an empty known shell and consumes one fabricated `sealant_charge`. Additional capacity needs an explicit data decision later. A node never owns a second authoritative count.

HullPatch requires the actual carried sealant shell and calls the simulator charge debit. Keep the shell when empty rather than calling generic `consume_carried()`. Existing clean → fit → seal → verify stages persist; the debit occurs once at seal, not again at verify. A failed verification must not recreate charge. Preserve sealed-but-unverified procedure state across saves. The proposed metal → sealant-charge recipe reuses current fabrication, but its material/yield is an abstraction awaiting balance approval.

Gasket replenishment already works; retain the existing 3 metal → 2 gasket recipe and common service transaction. New recovered external hardware can use `WearComponent.service_part` and `ShipSystem.maintenance_action()` if it fits that service model. Do not fabricate sealed drive cores, introduce new narrative knowledge or add an entire spare catalog before a specific repaired machine needs it.

**Acceptance:** an empty carried shell cannot patch; a Stores charge alone cannot patch; refill consumes exactly one charge and keeps shell identity; patch depletes one and leaves a refillable tool; no respawn after reload; reloading each procedure stage preserves costs. Standard service keeps tool/isolation/diagnosis gates and returns gasket on failed repair.

### R3 — Replenish xenon and close the approach bootstrap

**Files:** `src/systems/nav.gd`, `src/components/propulsion_config.gd` or a narrowly scoped supply resource for capacity/conversion; `src/systems/cargo.gd`; parent's Sector/salvage content/data; existing `interactables/cargo_port.gd` or drive service port; `src/ui/computer/program_approach.gd` for integrated refusal/feedback.

Proposed first source is finite recoverable xenon bottles/tanks on suitable debris, handled as sealed equipment/cargo. This uses salvage without suggesting ordinary water ice turns into xenon. If broader supply is required, explicitly author xenon-bearing contacts with an extraction rule; do not add xenon to generic ore outputs or convert sealed DRIVE FEED. Source identity and remaining mass persist.

**Proposed APIs:** `NavSystem.get_xenon_capacity_kg() -> float` and `NavSystem.refill_xenon_from_cargo(source_id: String) -> float`. The latter validates a compatible sealed source record, fill connection/service safety and tank headroom, transfers actual kg, and leaves a partly used source with residual kg. The parent pins the source record and Cargo debit API with salvage. Never directly assign `fuel_mass_kg` from a UI or arrival signal. Keep `spend_fuel()` transit reservation and pair/single route behavior intact.

**Physical path:** survey tank → isolate/verify seal → detach/carry/stow → connect to xenon fill hardware → open transfer → close/verify. Meter shows tank and source remainder. Sealed feed only receives its existing UV service; labels remain XENON and DRIVE FEED.

Supply must be reachable before xenon hits zero. Sector drift costs no xenon, but paid approach and four-hour suit/tether reach can still strand an operator. Specify a conservative expedition reserve and discoverability warning using actual approach cost, current suit O2 and current travel reservations. Prove at least one replenishment opportunity is reachable on an intended low-reserve path; stochastic density alone is not that proof. At zero xenon, guaranteed recovery, passive close drift or accepted terminal failure is an operator policy decision, not a silent free burn.

**Acceptance:** finite/positive input and capacity validation; partial bottle transfer conservation; repeat/reload/revisit never refill a bottle; xenon affects available plot/approach budget, does not increase DRIVE FEED or battery; full tank preserves source. An intended low-reserve expedition reaches, recovers and transfers a source before exhausting its own supplies.

### R4 — Keep air, suit supply and food supportable

**Files:** `src/systems/{atmosphere,airlock,vitals,modules}.gd`, existing `interactables/{o2_candle,scrubber_unit,suit_locker}.gd`, relevant `src/data/{atmosphere,machines,modules,fabrication}/` resources; parent's living-ship care slice.

Use existing ore → CO2 filter and ice → O2 candle paths first. Source inspection gives baseline O2 demand of 0.84 kg/day per occupant; configured candle yield must cover that plus measured leak/EVA loss. Scrubber renewal must cover filter wear and sustain CO2 removal under live power. Treat dehumidified moisture and scrubbed CO2 as explicit losses until a recovery mechanic debits them.

Preserve `AirlockSystem.refill_suit()` conservation and normal gas-recovery cycle. Add a clearly readable locker preflight: empty suit, O2 insufficient, interior pressure too low, or power unavailable. Normal suit refill should never create O2, reset suit hours on equip, or refill from a nonexistent room. Audit demand while no room reports an occupant: one operator still consumes food/water on a long EVA, with suit O2 replacing cabin breathing demand exactly once.

Mixed gas loss needs a separate policy: finite recovered air bottles can supply `AtmosphereSystem.add_gas_moles()` through a validated pressure-limited transfer. **Proposed** `AtmosphereSystem.refill_from_cargo(compartment_id: StringName, source_id: String) -> Dictionary` returns actual species accepted and debits a compatible air-source record. Pure O2 candles do not supply N2. New pods should receive gas through measured transfer or a paid gas package; their free initial filter must also be accounted for. Decide whether repeated intentional venting is recoverable before claiming indefinite air supply.

Food already renews through powered hardware. Keep its output behavior for the first salvage slice; add serialized fractional yield and transparent live load. Living-ship care may later require water/temperature/tending, with rates in data and a production pause on unavailable input. That change must coordinate with Water and Power rather than secretly adding demand. Do not force new finite seeds/nutrients onto every harvest without a replenishment path.

**Acceptance:** mine → fabricate → candle/filter → viable cabin → refill suit → EVA → recovered airlock gas works from actual stock. Prove food net production ≥ occupant demand in an attainable power schedule; save/load preserves fractional harvest; failed input/power gates add no food. Paid pod construction/teardown conserves species and installed filter stock, with explicit vent losses. No claim of unconditional immortality: resource loss remains possible.

### R5 — Energy, capacity and recovered machinery lifecycle

**Files:** `src/systems/{power,modules,thermal}.gd`, `src/components/ship_machine.gd`, parent's recovered-equipment state/data, `interactables/machine_socket.gd`; exterior utility owner supplies generated mounting/interaction code if solar generation is selected.

For the first recovered machine, state what it actually contributes. A recovered battery cabinet only stores more Wh; it cannot solve a continuing generation deficit. A work bench spends more watts to reduce time, cargo rack adds space, grow rack supplies food with load, med bed accelerates recovery, and current scrubber spare needs a real effect before being called an air upgrade. Parent selects first technology and its condition/service contract; this plan makes no narrative/reward decision.

Recovered equipment must keep condition through transport/fit/unfit. Its usefulness, load and repair costs should follow the instance, not a fresh `ShipMachine` catalog record. Material recovery uses a configured yield and destroys that instance once. Crafted machines keep their paid-cost reservations; full refunds remain the existing behavior pending policy confirmation, with capacity-safe transactions. Pod teardown cannot bypass any new recovered ownership or portable restriction policy.

`PowerSystem.set_generation()` is enough to connect one functional solar installation when the exterior/living-ship slices schedule it. Feed it configured output and service state; if orientation/distance is not simulated yet, disclose the fixed-output approximation in the design, not as a fake solar meter. Recoverable RTG external faults already use gasket service; do not invent reactor fuel depletion. Production gear uses `set_circuit_source_load()` and heat contributions use `ThermalSystem.set_heat_source_gain()` where the selected mechanic requires them.

Battery fitting changes capacity without adding charge. Before battery removal require aggregate charge ≤ remaining capacity, or implement an explicit persisted charge transfer/loss policy. Save restoration recomputes sources before restoring/clamping charge. Cargo removal similarly checks remaining hold capacity plus returned materials/equipment. Avoid using build/unbuild or reload to reset fault condition, gas, filters or energy.

**Acceptance:** recovered unit is useful with its documented load and existing resources; power loss disables production/effects that require it; battery changes conserve Wh; generator output is measured and differs from storage; equipment repair/refit/scrap yields no duplicate unit/material; thermal and transit consequences advance through the shared clock.

## Interaction with the six activity slices

| Parent slice | Replenishment dependency | Result carried into other activities |
| --- | --- | --- |
| 1. Recover useful machinery | R0 identity/conservation; R2 service stocks; R3/R4 bounded expedition supplies | Equipment can be refitted or consumed by material recovery once; future finite tanks/packages use the same salvage chain |
| 2. Refit for expedition | R0 refund/capacity safeguards; R5 instance/load/charge accounting | Capability changes come with real resource budgets; no free trial produces gas, charge or material |
| 3. Survey/investigate | Persistent site/source records and R3 reachability | Survey locates useful remaining stock; revisited empty sites remain empty; measured supplies inform expedition choices |
| 4. Tend a living ship | R1 water, R4 air/food and R5 live generation | Recovery and production reduce supply frequency; costs and production stoppages remain visible |
| 5. Exterior utilities | R3 fill/service access; R5 functional power integration | New utility enables another expedition and creates a serviced external connection, not decoration-only capacity |
| 6. Make ship home | Stable cartridge/equipment ids and parent's saved placement | Arranged tools retain empty/full/condition state. Labeling/organization does not copy stock or reset consumables |

## Renewable versus finite policy proposals

| Category | Proposed treatment | Decision boundary |
| --- | --- | --- |
| Harvested objects, wreck equipment, bottles and first-visit caches | Finite and permanently depleted per identity | Never reset simply on arrival, streaming or reload |
| Unvisited deep-field chunks | New deterministic resource opportunities, continuing while drifting | Availability must fit viable expedition budgets; density/settings alone do not guarantee continuity |
| Water | Lossy reclamation plus new external ice/package intake | Perfect recycling, condensate capture and purge costs remain balance choices |
| Food | Existing powered production is renewable | Crop inputs/care/storage/spoilage belong to living-ship scope; avoid a new finite bottleneck without supply |
| CO2 filters, candles, sealant and service gaskets | Consumable products from finite local raw stock, replenishable from new sites | Optional reusable-filter/oxygen machinery needs its own input/load/service contract |
| Xenon | Expelled mass, finite per source, replenishable through explicit external sources | No UV recovery and no invented conversion from water/ore; scarcity/reachability still requires operator choice |
| DRIVE FEED | Existing recoverable sealed reserve | Preserve existing knowledge boundary and hotel/drive separation |
| Power | RTG output currently ongoing while serviceable; optional functional solar | Stored energy finite; neither batteries nor recovered condition resets manufacture Wh |
| N2/breathable gas | Conserved transfer, finite external air packages if adopted | Open survival after repeated venting needs an explicit supply/access policy |
| Wear | Repairable with existing stocks/procedures; recovered condition persists | Irreversible aging, parts cannibalization and replacement catalog are future decisions, not assumed sinks |

## Questions requiring operator or parent policy resolution

These questions do not block preparation or bounded first salvage. They gate claims of a balanced indefinite economy or the affected packet's content.

1. **Continuity guarantee:** renewable stability with optional expeditions, or mandatory ongoing resupply? What discovery/approach budget should cover water, oxygen, filters, metal and xenon? What happens under zero encounter settings or zero xenon? Do not select a rescue/death rule; production §9 and current mercy policy remain unresolved.
2. **Xenon source:** salvaged sealed bottles only initially, or also dedicated resource contacts? Choose capacity, unit-to-kg conversion, minimum recoverable mass and supply cadence against 25 kg approach and 180/340 kg routes.
3. **Water balance:** ice yield, package size, processing hours/load/heat, greywater capacity, reclamation losses, condensate recovery and whether purge really discards water. Current zero-volume-loss maintenance should not silently acquire a new penalty.
4. **Cartridges and spares:** one reusable shell/charge per patch initially, or multiple doses? Metal-to-sealant is currently a proposed abstraction. Are gaskets sufficient for first recovered-unit service, or does a specific unit require a new obtainable spare?
5. **Atmosphere loss:** source for buffer gas, safe target pressure/species limits, gas handling on pod construction/teardown and filter stock funding. Is recovering from repeated deliberate venting intended?
6. **Food:** keep module-plus-rack production stacking? Add water, thermal/care and storage limits now or in living-ship packet? Food rate must remain viable after those costs; seed/nutrient renewal cannot be left undefined.
7. **Refit economics:** keep full crafted-cost refunds and blocked overflow, or adopt partial salvage? What happens to nonportable fitted hardware on whole-pod teardown? Recovered items must never refund unspent build costs regardless of the answer.
8. **Power and construction:** does first technology add energy production or storage? What actual loads/heat apply to processing, construction and crop care? Solar/serviceability must be functional before used in budget claims. Do not change sealed feed or thermal-hold balance incidentally.

## Integrated future acceptance

- A fresh run can prepare a real suit/tools expedition, approach a finite site, harvest or salvage, stow, process, physically refill/repair/refit, and prepare another expedition without relying on automatic repeat-arrival rewards.
- Daily budgets enumerate water loss, O2 breathing/venting/suit use, CO2/filter throughput, food, sealant/punctures, gasket maintenance, xenon burns, hotel Wh and processing/build inputs. Each has either a live replenish path or an explicitly accepted finite/failure policy. Show bootstrap cost before claiming supply continuity.
- One deterministic multi-week scenario uses the shared clock and genuine debit/transfer APIs. It includes maintenance, paid fabrication, food production, water replenishment, an EVA and fuel resupply; no direct assignment of reserves or infinite fixture inventory counts as replenishment.
- Test each added transaction at empty/full/partial capacity, wrong item/tool/state, invalid/nonfinite quantity and absent receiver. Save/load around source claim, transport, paid job, completion, fill, fitted state and teardown preserves total stock and condition. Destination revisits and out-of-stream restoration cannot mint resources.
- Existing suitable suites to extend later: `test_water`, `test_cargo`, `test_mining`, `test_fabricator`, `test_airlock`, `test_eva_flow`, `test_rations`, `test_module_effects`, `test_machine_fitting`, `test_modules`, `test_nav`, `test_m11_voyage`, `test_save_load`, `test_scene_save_load`, `test_save_migration`, `test_m9_loop` and the parent's new salvage coverage. Run smoke/full required checks only during the implementation pass, with current dated evidence.
- Human play verifies the manual/readouts distinguish filters from water, abstract stores from a usable carried cartridge, xenon from DRIVE FEED, and battery capacity from generation. Each transfer has physical access and refusal feedback; source depletion and new capability are understandable without narrative revelations.

## Preparation evidence and blockers

Read AGENTS, production/expansion/open-question specs, `.wolf/OPENWOLF.md`, `.wolf/STATUS.md`, `.wolf/cerebrum.md`; queried anatomy with `rg` before source navigation. Inspected current simulator public/mutation paths, their callers in interactables/player/world/UI, fabrication/machine/module/wear/destination/compartment data and scene/generator registration. Source inspection is the only evidence from this pass.

Commands used for reading: `cat`, bounded `sed -n`, `rg -n`, `rg --files`, `git status --short`, `command -v openwolf`, and `openwolf handoff inspect`/help. Some initial glob guesses (`data/items`, `data/compartments`, `systems/player_vitals.gd`) do not exist; actual surfaces are Stores, `data/atmosphere` and `systems/vitals.gd`. Supplied saved-context UUIDs were rejected by `openwolf handoff inspect` as `Invalid packet id`; their excerpts are not treated as inspected authorization. The live user instruction authorizes this scoped work.

No subagent/task tool is available in this sidecar session; independent read batches were executed in parallel. No game tests were run. There is no blocker to this document; unresolved supply/balance/policy choices above belong to the parent/operator. Parent incorporates findings into slice/result/status/roadmap documents and coordinates persistence, without this sidecar editing any of them.
