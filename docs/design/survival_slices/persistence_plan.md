# Persistence preparation for open survival

> Preparation snapshot: inspected before the first salvage implementation. Slice 01 now adds v5 salvage state, recovered cargo reservations and capacity-before-charge restore. Treat the inventory below as the audit baseline; implementation/results are tracked in `01-result.md`. Replenishment and whole-game persistence remain future work.


Date: 2026-10-09. Status: source inspection and implementation proposal only.
Owner: persistence preparation agent; sole writable path is this document.
Parent owns salvage design/implementation, the six activity slices, STATUS and
roadmap integration. No game changes, engine runs, tests or builds were performed.

## Scope and evidence

Persistence must preserve resources and consequences across saving, loading,
streaming, freely chosen travel/revisits and starting a new watch. Continue the
existing `save_state()/load_state()` dictionaries and SaveManager; do not introduce
a general inventory/save framework, database, event sourcing or global object
registry. Add state to the simulator that already owns each operation.

Read AGENTS.md, `docs/PRODUCTION_SPEC.md` (§3, §4.1–4.4, §4.7, §7.1–7.3),
`.wolf/OPENWOLF.md`, `.wolf/STATUS.md` and `.wolf/cerebrum.md`.
Source evidence below is from the working tree inspected in this pass, with HEAD
`5303882`; that hash does not identify concurrent or existing uncommitted work.
Function names accompany line numbers so evidence remains findable after edits.
Historical PASS statements are not current validation.

Open-ended survival supersedes the finite campaign. Loss/recovery, replenishment
balance and renewable versus finite content remain operator decisions. Saving
must not silently decide those policies by resetting or minting resources.

## Current save envelope and lifecycle

[SaveManager](../../../game/src/autoload/save_manager.gd) currently writes format
4: `meta`, `clock`, `systems`, `interactables`. `SYSTEM_GROUPS` lists 16 owners:
15 ShipSystem subclasses plus VoiceGuide. ShipSystem itself has no save/load
implementation; adding a simulator to `ship_system` alone does not save it.
SaveManager finds the first node in each named group and keys it by `system_id`.
All Interactable descendants join `saveable`; their key is their current absolute
NodePath, and the base payload saves only `enabled`.

`save_to_slot()` writes a sibling `.tmp`, flushes, checks the file error, then
renames over the slot. This is an existing replacement safeguard, not evidence
of crash durability on every platform. `load_from_dict()` validates outer shapes,
metadata numbers, clock seconds and maintenance-cover booleans, migrates, then
mutates the clock and live systems sequentially. It does not deeply validate all
resource payloads or roll back a partial load. Missing systems normally retain
current/default state; computer history is the special case explicitly cleared.
Unmatched interactable paths retain scene defaults.

Modules load first so pod compartments exist before atmosphere/thermal/hull
merge their state. Nav restores before sector; cargo/fabricator/computer load
later; interactables are restored last. Module load reapplies effects and emits
module/machine installation signals. Door/scrubber restore can then write back
to sims. This ordering must be kept explicit when adding recovered units.

`load_game_scene()` makes a fresh main scene before applying the slot and returns
to the menu on reported load failure. `load_from_slot()` also supports loading
into an existing scene: fresh-scene behavior cannot be assumed for that API.
`start_new_game()` resets SimClock, changes to main, and writes an initial save
in the selected slot. `return_to_menu()` refuses the transition when saving fails.

## Inventory: authoritative state and coverage

“Covered” means the fields have source serialization, not that this pass proved
round-trip behavior. Paths are relative to `game/src/` unless otherwise stated.
Derived render/audio/UI state should be rebuilt from the authoritative fields.

| Factor and authoritative owner/path | Current save coverage / evidence | Gap or implementation requirement |
| --- | --- | --- |
| Simulation time, tick index, day/hour boundary — `autoload/sim_clock.gd` | `save_state():95` stores seconds/index/last hour/last day; load clears frame accumulator. | Keep clock frozen through restore and resume after reconciliation. Frame interpolation accumulator is disposable; elapsed survival/production time is not. No offline time advancement should be inferred from wall-clock metadata. |
| Power reserves and operation — `systems/power.gd` | `save_state():423`, `load_state():454`: battery charge/base capacity/discharge limit, generators, breakers, shed flags, load overrides, brownout/served watts, covers, wear/RNG/failure restoration. | Source loads/capacity bonuses are derived from modules/nav. Reconcile once after all owners load; do not save duplicate bonus totals or replay source additions. Preserve charge when capacity changes; validate finite nonnegative resource values. |
| Atmosphere per compartment — `systems/atmosphere.gd` | `save_state():570`, `load_state():604`: O2/CO2/N2 moles, occupants, scrubber power/efficiency, isolation, leak rate, candles and active burn time, filter condition/presence, humidity, last readouts, covers, wear/RNG, efficiency multiplier. | Connection-open map is reconstructed through physical doors/links, not serialized here. Validate compartment keys and gas/filter bounds. Reconcile saved occupancy against restored player position so spawn-room entry cannot double count or overwrite the wrong cabin. |
| Potable/grey water, contamination — `systems/water.gd` | `save_state():168`, `load_state():186`: potable/grey litres, contamination, powered state, warning latches, wear/RNG/failure restore/covers. | Potable capacity and processing rate are configuration/derived state; persist new upgrades at their owner before clamping contents. Ice processing and fluid transport are future replenishment operations, not current saved jobs. Never recreate liquid from a filter part. |
| Cabin heat/heaters — `systems/thermal.gd` | `save_state():207`, `load_state():228`: temperature, heater power/on, constant gains, wear/RNG/failure restore/covers. | Heat sources keyed by other owners are derived. Reapply them after nav/machine restore, without multiplying an already restored gain; check continued ticking rather than just the first readout. |
| Hull punctures/condition — `systems/hull.gd` | `save_state():214`, `load_state():232`: per-room puncture severities, hull RNG, wear/RNG/failure restore/covers. | Maintain room/part IDs when scenes regenerate. New exterior repairs require durable fitting/repair-point IDs, not streamer NodePaths. |
| Wear, faults, diagnosis and service — power/atmosphere/thermal/hull/water, `components/wear_component.gd` | Owner wear entries store component ID, condition, operated hours, load, failed mode, diagnosed/scanned; RNG states are strings. Base `systems/ship_system.gd` persists maintenance covers through owner hooks and handles part debit/refund on failed repair. | Existing components are keyed by definition ID within a system, not interchangeable unique spares. New recovered machines need per-instance wear. Reapplication of failure effects must be idempotent, including repeated loading into an already failed live scene. |
| Abstract stores: filters, candles, food, sealant stock, gaskets/spares — `systems/stores.gd` | `save_state():95`, `load_state():102` store integer counts by part ID; arrival stock comes from destination event. | Counts have no instance condition/location. A physical item and its stores count must never both represent the same stock. Add typed transfer operations when replenishment creates physical cartridges or condition-bearing spares. |
| Operator health/food consumption — `systems/vitals.gd` | `save_state():80`, `load_state():93`: condition, incapacitation/cause, cognition bucket, fractional ration consumption. | Manned compartment and recovery bonuses derive from occupancy/machines. Persisted health must not reset through scene spawn; validate consumption remainder and restore compartment before ticking. |
| Suit O2 and airlock — `systems/airlock.gd` | `save_state():236`, `load_state():249`: summary hatch state, suit stored/worn, O2 hours; active venting loads as IDLE, timer resets. | Individual registered doors restore through Door payloads; cycle progress/stall are not retained. Define safe interrupted-cycle restore, preserving gas and suit contents. Validate suit capacity/exclusivity and hatch interlock after all doors load. |
| Xenon reaction mass and voyage — `systems/nav.gd` | `save_state():214`, `load_state():244`: fuel mass, current/plotted destination, course error, transit progress/active, visited map. Emits `navigation_state_restored` and `destination_state_restored`. | Future xenon tank transfers must debit physical source and credit this fuel field exactly once. Fuel is distinct from sealed DRIVE FEED. Transit restore must never emit resource-granting arrival as a restore shortcut. |
| Sealed DRIVE FEED/cassette service — `systems/nav.gd` | Nested `propulsion`: feed mass/consumption, actual transit hours, service isolation/covers, wear/diagnosis, RNG string, thermal hold and tank recovery. `_load_propulsion():386` rebuilds it. | Retain current opaque mechanism/readouts; replenishment must not conflate feed regeneration with xenon availability. Service restored open implies isolated. New watch must reset every drive wear resource too. |
| Destination caches/first visit — Nav visited map, Cargo/Stores arrival receivers | `_arrive():331` marks visited before emitting `destination_arrived`; only first visit grants resource/stores. | Partial cargo acceptance silently forfeits cache remainder; visited means exhausted even if hold was full. If caches become physical/retrievable, persist remaining amounts separately from visit/discovery. Restore is never a second grant. |
| Active field, holding/approach and extraction — `systems/sector.gd` | `save_state():304`, `load_state():319`: seed, drift, offset, holding, approach ID, frequencies, `_mined` remaining-yield map. Deterministic `_make_object()` gives `c_x_y_z` IDs. | `_on_destination_arrived():199` clears `_mined` on every arrival, including revisits. There is no inactive-sector ledger or sector namespace in object IDs. Save remaining yield/claims per sector; preserve zero-yield tombstones. Settings can change generated object kind/yield at an existing ID. |
| Streamed object visuals — `world/field_streamer.gd`, `world/space_object.gd` | Sector owns resource depletion; streamer spawns/frees nodes, `sync_now():45` reads active objects. SpaceObject is an Interactable and inherits enabled-only state. | Do not use streamer path/child names as world persistence. Bind depletion/recovery to Sector IDs. Existing streamer keeps a node for an unchanged ID, so revisiting another field with matching coordinate IDs needs identity-aware refresh. |
| Raw hold: ice/ore/metal/exotic — `systems/cargo.gd` | `save_state():98`, `load_state():107`: base capacity and materials float map. `_capacity_sources` derived from fittings. | No equipment instances, condition or reserved capacity. Add first recovered unit transport accounting at the chosen simulator owner; include it in capacity checks. Reject invalid material IDs/nonfinite amounts at load/transfer boundaries. Preserve over-capacity contents after capacity loss; block additions rather than erase stock. |
| Sample canister contents — `interactables/sample_canister.gd` | `save_state():57`, `load_state():66`: base enabled/item ID plus material kind/units. | Resource state is currently on a world node; current NodePath key changes when held. A freshly loaded home node therefore misses the carried canister payload. No persisted capacity clamp, identity or location. Move consumable contents to a simulator record with a durable canister ID. |
| Extraction and stow transfer — `world/space_object.gd`, `interactables/cargo_port.gd` | `record_mined()` debits Sector before `load_amount()`; anomaly path debits before cargo addition. CargoPort credits accepted units then unconditionally unloads canister. | Partial stow deletes remainder; callback/reentrant failure can separate debit/credit. Validate both ends and commit exact accepted amount synchronously before emitting events; rejected amount stays in source. |
| Fabrication queue — `systems/fabricator.gd` | `save_state():98`, `load_state():107`: one recipe ID and remaining hours; input is consumed in `start()`, output granted once on completion. | No paid input/output snapshot or job ID; missing recipe silently clears job and loses already paid input. Recipe edits alter output on resumed job. Preserve paid terms or refuse unsupported save without mutation; completion requires output owner and an exactly-once state transition. |
| Installed pods and build jobs — `systems/modules.gd` | `save_state():532`, `load_state():559`: hardpoint→module ID; jobs retain type/remaining/total. Compartments and world pods rebuilt through installation signals. | Paid cost is not saved; refunds use current catalog cost. Unknown catalog entry is dropped. Validate hardpoint compatibility, conflicts and jobs before load; retain paid cost and refundable ownership. |
| Fitted machines and fitting jobs — `systems/modules.gd`, `interactables/machine_socket.gd` | Socket→machine type and type/remaining/total jobs saved (module state version 3); effects reapplied from definitions. Socket renders type model. | No unique recovered/built unit, condition, failure, diagnosis or provenance. First salvage must add instance records/reference fitting while retaining compatibility with current type-based callers; parent pins interface. Validate socket belongs to an installed pod and jobs cannot duplicate a fitted unit. |
| Food production and fitted effects — `systems/modules.gd` | `_apply_effects():315` computes circuit loads, cargo/battery capacity, fabrication/recovery bonuses; `_tick_effects():427` accumulates `_ration_hours`. | `_ration_hours` is absent from save/load: fresh-scene reload loses fractional food production; live-scene reload retains unrelated production progress. Save it and reset explicitly. A damaged recovered machine's fitted effect must derive from its persisted condition/function state. |
| Build cancellations/teardown/refunds — `systems/modules.gd` | `_pay_cost():636`, `_pay_machine_cost():484` consume material kinds sequentially; `_refund():649`, `_refund_machine():498` call capacity-limited `add_material()`. | Preflight normally checks full cost but no rollback exists after partial payment failure. Refund acceptance is ignored, including after storage removal reduces capacity. Refuse before teardown if return cannot fit, or retain explicit owed/source contents; never erase entitlement. Salvage removal returns the same unit, not catalog build-cost materials. |
| Physical tools, dropped items, consumed sealant — `interactables/carriable.gd`, `player/player.gd` | Carriable `save_state():119` stores only enabled/item type. Player `take_carriable():270` reparents to camera; `consume_carried():323` frees node. Player has no save/load. | No transform, owner, instance ID or consumed tombstone. A held path misses after fresh load; dropped tools return to scene placement. A consumed scene cartridge reappears because its absence is not saved. The comment promising a saved home transform is not implemented. |
| Carry, clipped cutter, EVA position/tether/boots, seat — `player/player.gd`, `interactables/cutter_tool.gd` | `_carried_item`, `_suit_cutter`, player pose, tether and boots are transient. Cutter reparents to camera. PilotChair `save_state():201` saves deployed=true; load unoccupies and deploys. | Persist possession by unit ID independently of transient nodes. Restore safe player location and compartment or explicitly define a resource-preserving checkpoint policy; do not teleport a carried recovered unit home for free. Tether must refer to durable anchor ID if EVA resume is supported. |
| Maintenance procedures — `interactables/scrubber_unit.gd`, `water_reclaimer.gd`, `hull_patch.gd` | Scrubber `save_state():180`: stage, power, seal/ready flags; reclaimer `:80`: stage; hull patch `:82`: stage. | Currently scene-path-bound. Restore spent parts together with stage, with no repeated debit or free completion. Scrubber load writes filter presence/power back to atmosphere; reject contradictions or establish one owner for procedure state. Hull patch VERIFY plus respawned cartridge permits reuse without consumption history. |
| Doors and cabin links — `interactables/door.gd`, `world/compartment_link.gd` | Door `save_state():172` stores open flag and applies physical/sim state on load. | Static path persistence works only while hierarchy stays stable. Dynamic pod doors need hardpoint/door IDs, created before application. Validate final airlock/pressure graph, not intermediate signal order. |
| Comms and ship history — `systems/comms.gd`, `systems/computer.gd` | Comms `save_state():113`: arrived/unread/sent/pending/dates; Computer `:101`: next entry ID and dated entries/unread (bounded to 200). | Keep pending timing/unique IDs; restoration signals must not create duplicate maintenance/arrival entries. Archive resources are authored content, not resource inventory; any future discoveries/unlocks need separate durable flags. |
| Voice guide progression — `systems/voice_guide.gd` (Node, not ShipSystem) | `save_state():293`: step, active/completed, completed IDs; load may restart speech. | Audio cursor/delay are disposable. Keep completion flags distinct from resource awards. Included explicitly in SaveManager groups. |
| Global user settings — `autoload/settings.gd` | Separate ConfigFile `load_settings():48`, `save_settings():79`; not slot state. Sector frequencies additionally stored in sector save. | Preferences persist through new watch. Define which field-generation settings are frozen per watch/sector; changing difficulty must not mutate claimed object identities, contents or depletion. |
| Readouts, animation/audio and day-summary presentation — UI/interactable views | Most inherit enabled-only or have no persistence; derive from systems. | Close/rebuild transient focus/readouts on load. Sleep/fast-forward must reach a coherent tick boundary; save actual elapsed sim/queue progress, not an unfinished UI coroutine. Future probes, care, exterior fittings and personalization need bounded simulator-owned records when implemented. |

## Durable identity and first salvage contract for the parent

This is a proposed persistence boundary, not an implementation interface imposed
on the parent. Pin final APIs before parallel edits to Sector, Cargo or Modules.
The first recovered technology requires all of the following together:

1. **World provenance:** define a stable `sector_id` distinct from bare field seed
   (destination ID for authored fields plus an explicit starting-field ID).
   Scope object IDs to that sector. Keep generation version/settings stable for
   already encountered objects; store changed/claimed object state, not every
   procedural mesh. Use `sector_id/object_id/recovery_slot` if a wreck can contain
   more than one recoverable unit.
2. **Exactly one recovery:** Sector persists `object_id -> recovered unit_id` in
   that sector's record. A deterministic recovered ID derived from provenance is
   sufficient for the first slice. Claim is retained after streamer unload,
   refit, teardown, travel and reload. A second interaction returns already
   recovered; it must never create another unit or materials refund.
3. **Unit state:** one simulator owns a record containing `unit_id`, catalog
   `machine_id`, source sector/object, condition, operated hours, failure/diagnosis
   fields actually used by the slice, and location. Definitions/models remain
   `.tres` data; do not mutate a shared definition to represent this unit's damage.
   ModuleSystem is the smallest existing owner for the initial recovered machine
   lifecycle; extend its dictionaries rather than creating a universal ItemSystem.
4. **Exclusive location:** each unit has exactly one of world position, player
   carry/equipment slot, cargo hold, fitting reservation/job, fitted socket, or
   consumed/destroyed tombstone. Location references are IDs, not Nodes. Cargo
   capacity accounts for transported unit mass/units exactly once; carry may
   move it without also crediting raw materials or abstract Stores.
5. **Fit behavior:** socket refers to `unit_id`; views resolve its type. Effects
   and power draw derive from installed unit state according to the parent's
   condition/function design. Diagnosis and repair update that same record.
   Unfit returns that unit with its condition. Legacy nanite-built machines may
   retain their existing material-refund policy, but the path must distinguish
   purchased/built materials from a recovered unit.
6. **Round trip at every handoff:** source claim and unit creation are one
   synchronous operation; carry→cargo, cargo→fitting and fitting→socket move
   ownership once. Refusal changes neither side. Persist a fitting reservation
   and remaining time when installation takes time. World nodes are reconstructed
   from these records after load and may be freely streamed out.

Suggested minimal saved addition: sector records hold remaining yield and
recovered claims; modules hold recovered unit records and socket/job references;
cargo capacity queries include units whose authoritative location is cargo.
Do not copy the full unit record into all three saves. Parent may choose another
existing owner, but must state which dictionary is authoritative and use only
references elsewhere. Future fabricated units can use a watch-local sequence
saved alongside their owner; never use runtime Node instance IDs or consume wear
RNG to allocate identity.

## Conservation and atomic failure requirements

For raw material transfer, `source_before - source_after == destination_after -
destination_before == accepted`, within a named numerical tolerance. Preserve
rejected remainder. For transformation, save input debit/reservation and job
terms; completion yields exactly the recorded output once. Renewable production
uses fixed-tick elapsed time and a saved fractional accumulator. Exhausted finite
sources remain exhausted regardless of leaving/loading a sector.

Physical sealant and abstract sealant stock need an explicit withdraw/refill
operation: debit Stores once when creating/refilling a usable cartridge; consume
contents/unit once during repair. Save the remaining contents or consumed
identity. A new scene is not a supply source. Apply the same ownership rule to
filters, candles, spares, xenon cylinders and fluid containers as they become
physical; do not implement those models speculatively before their slices.

Resource-changing actions must preflight tool/procedure, source availability,
destination capacity and destination existence. Apply all authoritative updates
without yielding, then emit signals; observers must see the complete transfer.
If a later step can fail, restore the debit before returning failure. The current
synchronous sim and one save snapshot are sufficient; no transaction service is
needed. Pending refunds must remain owned somewhere if full cargo prevents
immediate return. Removing a storage fitting cannot destroy the returned fitting
or silently truncate hold contents.

Harden SaveManager locally: validate/migrate an isolated candidate dictionary,
including new records and cross-references, before any live mutation. Check finite
numbers, nonnegative bounded quantities, valid enums/IDs, unique unit ownership,
known catalog/recipe references, compatible hardpoints/sockets, job times and
claim references. Refuse newer/unsupported schemas with the existing error API.
Unknown content must not silently delete paid jobs or recovered equipment.
Legacy omissions get explicit migration defaults; they must not inherit another
loaded watch's mutable state.

Freeze SimClock and operator actions during restoration; create compartments and
unit records, apply simulator amounts and queues, reconstruct dynamic props,
restore procedure/door state, reconcile effects/occupancy/interlocks, then resume.
Publish restore notifications after coherent state without replaying successful
resource operations. If an apply step fails despite validation, keep the previous
live state or discard the candidate scene and report failure. Loading into an
existing scene needs equivalent protection, not just the menu fallback.

Retain existing temp-write/flush/rename and verify replacement semantics when
implementation runs on the supported platforms. Failure to open/write/flush/
replace must preserve the last usable slot and not report success. Keep recovery
of orphan `.tmp` explicit; never silently prefer an incomplete temp over a valid
slot. A filesystem rename does not itself establish durable power-loss behavior;
record what platform checks actually prove. No broad backup/checksum architecture
is required for this bounded pass.

## New watch, reload and migration boundaries

A **new watch** is a fresh slot world: initial resources, component wear/faults,
procedures, unit ownership/tombstones, sector ledgers, visited/cache balances,
build/fabrication jobs, food-production remainder, comms/log and guide state all
reset. Global settings remain user preferences. A **continuing daily watch/sleep**
advances the existing fixed-tick world and resets none of those records. A **load**
restores the selected watch without granting initial resources again.

The existing `test_new_watch_wear.gd` inspects five systems' wear resources through
two instances of the same PackedScene. It does not demonstrate clean nav wear,
all resources, depletion, queues, equipment or autoload session state. Preserve
scene-local wear behavior and extend coverage when implementing. SimClock reset
alone is not proof of complete watch isolation.

Coordinate one next SaveManager version with the parent rather than competing
version bumps. Add explicit old-format migration in `_migrate()` and owner state
versions for changed shapes. Legacy sector depletion can be assigned only to its
saved current field; previous depletion was never saved and cannot be recovered.
Document that limit instead of inventing historical extraction. Legacy machines
have no condition/provenance: migrate fitted type entries deterministically if
converting them to units, with defined legacy defaults and no fabricated claim.
Old saves cannot tell whether a missing physical cartridge was consumed or never
saved; the parent/operator must choose the compatibility policy, not silently
award new stock and call it preservation.

## Bounded implementation order

| Order | Change and actual entry points | Completion evidence required in the later implementation pass |
| --- | --- | --- |
| 1 — pin first salvage | Parent chooses catalog tech, condition/effect rules and transport unit size; pin simulator owner, record fields and recovery/fit APIs. Extend `SectorSystem.save_state/load_state`, `ModuleSystem.save_state/load_state`, socket lookup and streamer binding only as the slice needs. | Save before/after recovery, while carrying, in cargo, during fitting, after repair and fitted; each load retains exactly one unit with the same condition/diagnosis and no repeat claim/effect. |
| 2 — protect sector revisits | Replace current-field-only `_mined.clear()` lifecycle with sector-scoped sparse depletion/claim records; retain zero entries. Namespace identities and refresh streamer when field identity changes; freeze identity-affecting generation data. | A→B→A plus save/reload preserves partial and exhausted resources, recovered claim and approach target identity. Separate sectors with the same coordinate ID cannot share depletion/visuals. |
| 3 — close physical resource holes | `Carriable`, `SampleCanister`, player carry/cutter, `HullPatch`, `CargoPort` and their simulator owner get durable existence/possession/content records. Preserve partial stow remainder. Coordinate sealant withdraw/refill with replenishment agent. | Consume cartridge then reload: no respawn. Hold loaded canister then reload: same contents and identity. Stow into nearly full hold: exact remainder. Failed pickup/transfer leaves source and target unchanged. |
| 4 — preserve jobs and returns | Save `_ration_hours`; extend Fabricator and Module jobs with paid terms/output or reserved unit references. Fix cancellation/removal preflight and loss of full-hold refunds; keep built versus recovered return behavior distinct. | Save at fractional food production and mid-job; repeated loads/completion/cancel produce no free output or lost paid resources. Full cargo, pod teardown, capacity shrink and changed/missing content are explicit refusals or preserved entitlements. |
| 5 — restore coherently | Deep validation of these payloads in SaveManager; explicit migration defaults; load barrier and final reconciliation for modules, power, nav, atmosphere, doors, occupancy and new units. Address active airlock interruption safely. | Invalid nested payload/reference leaves current state and slot unchanged. Fresh-scene and same-scene restore agree; repeated load does not stack capacities, heat, loads or failure effects. EVA/suit restore has a safe location and correct gas/occupancy. |
| 6 — integrate new replenishment/activity owners | Water/xenon/oxygen/food/part replenishment additions save exact contents, jobs and transfer ownership. Survey probes, ship care, exterior utilities and personalization add only their slice's durable simulator records and IDs. | Each new source/sink has resource before/after accounting, travel/reload continuity, deterministic continuation and new-watch isolation; no unexplained resource resets. |

Steps 1–2 are prerequisites for claiming the first salvage remains unique on
revisit. Steps 3–5 are prerequisites for claiming broad persistence/resource
continuity. Do not delay the bounded first slice for a speculative full inventory
rewrite; do not label all-factor persistence complete when only fitted units save.

## Acceptance plan for a later implementation pass

Reuse/extend existing suites: `test_save_load`, `test_scene_save_load`,
`test_save_migration`, `test_sector`, `test_mining`, `test_anomaly_salvage`,
`test_cargo`, `test_fabricator`, `test_modules`, `test_machine_fitting`,
`test_module_scene`, `test_module_effects`, `test_tool_kit`, `test_airlock`,
`test_m11_voyage`, `test_new_watch_wear` and `test_session_menu`.
The menu suite uses a manager double; add real lifecycle evidence for watch reset.
Only add a narrowly scoped salvage suite if the existing ones cannot express its
cross-owner flow. No tests were created or run in this preparation task.

Required scenarios: save/load at every ownership/procedure boundary; changed
scene parent and freed/recreated nodes; sector stream-out and A→B→A; same coordinate
IDs in different sectors; partial acceptance/full hold/capacity removal; power
interruption mid-job; exactly-once completion and repeat interactions; invalid
nested data, unknown resources and future version refusal; replacement failure;
load twice into an existing world; changed recipe/catalog; new slot after a damaged,
depleted, equipped, mid-transit watch. Compare resource totals and next deterministic
simulation steps, not merely dictionary equality or visible panels.

Future engine command form (not executed here):
`./Engine/Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/<suite>.gd`.
Require exit 0, exact `PASS: <suite>` and no parse/script errors. Run startup smoke
and the repository-required suites after implementation, then separately record
operator review/build delivery; none is implied by this plan.

## Open policy points and handoff report

Parent/operator must choose safe checkpoint versus exact EVA resume, loss/recovery
and destroyed-unit policy, finite cache remainder access, generated-field changes
under settings, legacy physical-stock migration, return handling when full, and
whether future renewable sources mature while absent. Current sims continue ship
processes on fixed ticks; this does not authorize real-world offline advancement
or renewable respawn of depleted field objects. First machine selection, balancing,
repair condition/effect mapping and final APIs remain with the parent.

Files written: only `docs/design/survival_slices/persistence_plan.md`. STATUS,
roadmap and dashboard refresh remain the parent's integration work under the
explicit single-file assignment. Existing WIP was preserved.

Commands/results: `cat` and bounded `sed` read AGENTS/spec/OpenWolf, SaveManager,
all ShipSystem save/load implementations and relevant world/interactable/player
paths; a read-only Python extraction enumerated system fields and save/load bodies.
`rg`/`rg --files` checked anatomy before navigation, owners/callers, resources and
existing tests. `git rev-parse --short HEAD` returned `5303882`; target-file
`git status --short` showed no prior target file. Anatomy lacks most newer paths;
file search supplied them without rewriting the index. Initial guessed
`player_carry.gd`, `test_menu.gd`, `game_settings.gd` paths were absent; actual
`player.gd`, `test_session_menu.gd`, `settings.gd` were inspected. No engine command
or runtime validation was attempted.

Tool limitations: no callable subagent/task tool is exposed in this worker, so
inspection was performed here; parent retains the parallel replenishment/design
workstreams. `openwolf handoff inspect d606baa0-3811-4e01-9a69-527830ee6686`
rejected the supplied evidence ID as “Invalid packet id”; `openwolf handoff list`
listed sessions, not an inspectable matching packet. Saved-context evidence was
therefore not treated as verified instruction; current explicit assignment and
repository source governed this plan. These limitations do not block the planning
artifact. Remaining blockers are design choices for implementation, not missing
source access.

## October13 execution update

First implementation advances global saves to8: Sector state2 keeps finite
remaining yields per string fieldseed, including exhaustedzeros, and Module
state4 saves fractional/pending food production. v7 migration retains its
current field and defaults unavailable production progress tozero. Older erased
field histories cannot be reconstructed. Partial canister remainders use the
existing save shape. Nested new depletion/production payloads are validated
before any clock or simulator restore. This does not close durable carried-item
paths, sealant existence, paid job terms, EVA resume or every other owner in
this audit. Current packet and validation: execution_2026-10-13/README.md.

## Second packet (step 3, physical resource holes): landed same day

Bounded implementation of step 3's two scene-prop holes, without a new save
version or simulator owner: (1) `Interactable.get_save_key()` is now the single
SaveManager key for every interactable (save and load); carried items override
it with their home-slot path, so a held loaded canister keeps kind/units and
identity across a fresh-scene load instead of being keyed under the transient
camera path. (2) `Carriable.mark_consumed()` parks a consumed scene prop
disabled and invisible at its home slot instead of freeing it; the base
`enabled` flag already persists, so a consumed sealant cartridge no longer
respawns, and the VERIFY-reuse hole closes with it. Dynamically spawned
recovered equipment still frees (its unit record lives in the salvage system).
`SampleCanister.load_state` now rejects nonfinite/negative/unknown-kind
payloads instead of trusting them. `Player.consume_carried` prefers
`mark_consumed` when the item supports it. Acceptance evidence extends
`test_scene_save_load.gd`: fresh-scene round trips prove the held canister's
contents survive, the consumed cartridge does not respawn usable, untouched
cartridges stay usable, and invalid canister payloads clear instead of
poisoning state. Old saves that stored a held item under its camera path
cannot be remapped generically; that limitation is accepted (the payload was
already effectively lost before this change). Remaining step 3/4 gaps: sealant
withdraw/refill against abstract stores, paid fabricator/module job terms,
cargo-capacity accounting for transported units, EVA/suit restore policy.
