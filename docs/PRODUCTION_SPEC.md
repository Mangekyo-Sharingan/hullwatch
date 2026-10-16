# HULLWATCH — Production Specification

| | |
|---|---|
| **Title** | Hullwatch |
| **Repo** | `E:\Projekt\Misc\OperationSpacer` |
| **Version** | 0.1 — Draft |
| **Date** | 2026-09-18 |
| **Status** | Pre-production |
| **Engine** | Godot 4.7.2 stable (local binary at `Engine/`) |
| **Language** | GDScript (typed) |
| **Platform** | Windows, Linux and Steam Deck at Early Access (operator decision 2026-10-15); macOS later |
| **Team** | Solo developer + AI-assisted pipeline |

---

## 1. High Concept

You are the lone operator of a long-haul maintenance vessel crawling between waypoints on a decades-long voyage. Every day you inspect, repair, and triage the decaying systems that keep you alive — power, heat, air, water, hull. Nobody is coming. The ship is the only home you have left.

**Hullwatch is a first-person ship-maintenance sim where the horror is entropy itself.** No monsters, no jumpscares, no combat. The dread comes from resource math you can't win outright, systems that degrade faster than you can fix them, and the silence of a ship designed for a crew that is no longer there.

### Design Pillars

1. **The ship is a character.** It breathes, creaks, fails, and recovers. Players learn its sounds and habits the way a sailor learns a hull.
2. **Grounded dread.** All tension is mechanical, systemic, and situational. Nothing supernatural. Fear is earned through understanding — the better you understand the systems, the more precisely you know how bad it can get.
3. **Work is the gameplay.** Maintenance is tactile, diegetic, and skilled. No abstract progress bars — you physically open panels, trace faults, swap parts, and read analog gauges.
4. **Alone, not empty.** Isolation is the horror instrument: delayed comms, prior-crew traces, and a universe that does not respond.

### Comparable Titles & Positioning

| Reference | What we take |
|---|---|
| **Starpath** (Smårs, upcoming) | Retro-futuristic lived-in ship, life-support management, weightless contemplative travel, no combat/dogfights/fake gravity |
| **Hardspace: Shipbreaker** | First-person mechanical labor, tool-based interaction, the ship as a puzzle of systems |
| **Iron Lung** | Solitary confinement in a machine, dread through instrumentation and darkness |
| **Barotrauma** (systems only) | Interlocking ship subsystems and cascading failure chains |
| **The Long Dark** (tone only) | Attrition against indifferent nature; death is a math error accumulated over days |

**Positioning:** Starpath's cozy-hard-sci-fi ship as home, inverted into attrition horror. Slower than survival games, more mechanical than walking sims.

---

## 2. Player Experience Goals

- **Competence fantasy:** "I know this machine. I can hear a failing pump before the panel tells me."
- **Attrition tension:** The repair list never goes to zero. You end each day having chosen what *not* to fix.
- **Earned calm:** Safe stretches are genuinely restful — until a gauge drifts.
- **Moral weight of triage:** Cutting power to the greenhouse to feed the CO2 scrubbers should hurt.

**Emotional arc per session (a "day"):** routine comfort → noticing something off → diagnosis under uncertainty → repair satisfaction → triage anxiety → quiet night → escalation.

**Operator decision, 2026-10-15 — open-survival tension:** a well-run ship can reach real
stability. Dread comes from expeditions, events, isolation and the cost of mistakes, not
from an inevitable whole-game decline. "Attrition tension" above applies within a watch
or an expedition, not as a guarantee that the repair list can never be cleared.

---

## 3. Core Loop

### Moment-to-Moment (seconds–minutes)
Walk the decks with a handheld torch and diagnostic scanner. Read physical panels. Interact with tools (wrench, sealant, multimeter, filter keys). Listen for faults. Check the day's maintenance board.

### Daily Loop (15–30 min of play)
1. **Wake** — ship alarm or artificial dawn cycle; read overnight log and warning board.
2. **Inspect** — walk rounds: power plant, life support closet, greenhouse (if fitted), hull access, cockpit. Note drifts and wear.
3. **Diagnose** — correlate readings against the manual; verify with tools. Faults are rarely where the symptom shows.
4. **Repair** — swap/clean/rebuild components with worn parts from stores; every action has a cost in parts, power, heat, or time.
5. **Navigate** — adjust course, plan burns, manage the power the drive consumes while it runs.
6. **Triage** — the day is finite. Choose what stays broken.
7. **Sleep** — time advances; degradation and events resolve; resource ledgers close.
8. **Escalate** — over days, wear outpaces repair capacity; the margin narrows.

### Voyage Loop (whole game)
**Operator direction, 2026-10-09: open-ended isolated survival.** The player chooses
travel, salvage, surveying and ship projects according to needs and curiosity.
Waypoint legs are transport, not a compulsory campaign sequence. Finite caches,
resource extraction, renewable production and ship capability support continued
survival. There is no required final waypoint or authored campaign victory.
Expanded activity content is planned in `docs/design/open_survival_direction_pass.md`;
its proposed features and acceptance targets still need bounded design approval.

---

## 4. Systems Design

### 4.1 Ship Simulation Model

Fixed-timestep simulation (10 Hz) decoupled from render. All systems publish state on a signal bus; UI, audio, and VFX react to state, never own it.

| System | State Variables | Player Levers |
|---|---|---|
| **Power** | Generation (solar/RTG), battery charge, bus load, breaker states, brownout | Breaker panel, load shedding, array cleaning/orientation |
| **Thermal** | Core heat, radiator efficiency, cabin temp, pipe freeze risk | Radiator deployment, heater priority, insulation patches |
| **Atmosphere** | O₂ %, CO₂ ppm, pressure, humidity, leak rate per compartment | Scrubber filters, O₂ candles, sealant, compartment isolation valves |
| **Water** | Potable reserve, greywater, reclamation efficiency, coolant loop quality | Filter/contaminate handling, loop purges |
| **Hull** | Micro-puncture count, panel integrity, sensor skin health | Sealant gun, patch kits, external inspection (EVA later) |
| **Drive/Nav** | Fuel mass, delta-v budget, course error, burn window | Course plotting, throttle burns, trim |
| **Comms** | Signal strength, window timing, message queue (latency: weeks) | Antenna alignment, power budget to comms |
| **Stores** | Parts inventory (by wear class), consumables, food | Consumption, repair choices, salvage |

### 4.2 Component Wear Model

Every repairable component is a data-driven `Resource`:

- `condition` (0–1), `hours_operated`, `failure_modes[]`
- Failure modes have probability curves over hours + environmental modifiers (heat accelerates wear; vibration from incorrect balance accelerates pumps)
- **Circular fault propagation:** scrubber clog → CO₂ up → player cognition effects (input latency, UI ghosting, audio muffle) → mistakes → improper repairs → faster wear

No scripted faults in normal play. The system *generates* drama; the narrative layer only places the occasional authored beat.

### 4.3 Maintenance Interaction Design

Rules:
- **Diegetic only.** No floating HUD markers. Interaction prompts are diegetic labels, hand-written notes, or scanner readouts.
- **Skill, not dice.** Minigame interactions encode real procedure: correct valve sequence, correct wire pairing, correct torque order, calibration to spec values from the manual.
- **The manual matters.** In-game binder (physicalizable in the cockpit) contains procedures players must actually read once; later they know them.
- **Tools gate capability:** multimeter finds faults, wrench loosens fittings, sealant gun patches pressure leaks, scanner logs wear. Tool condition is also simulated.

Example task — *Replace CO₂ Scrubber Filter*: isolate compartment → power down unit → open housing (fasteners) → remove filter (wear check) → install from stores → reseat seal → power up → verify ppm curve on panel → log it. ~3 minutes when skilled, 8 when learning. Skipping steps causes leaks/wear.

### 4.4 Navigation & Travel

- Waypoint-to-waypoint legs; plotting costs time and fuel; burn windows have real consequences (heat, power draw, minor G-loading handled abstractly).
- **No fake gravity, no dogfights.** Flight is deliberate: orient, burn, coast, trim, brake.
- **Drift risk:** an uncorrected course error compounds; arriving wrong wastes fuel on corrections.
- Docking/salvage at caches: slow, precision flying with the same systems (power to thrusters vs life support).

### 4.5 Dread Systems (Grounded)

| Instrument | Implementation |
|---|---|
| **Diegetic audio** | Continuous machine bed with per-component loops; sound carries diagnostic information; silence is used as punctuation |
| **Isolation** | Comms latency weeks-to-months; replies may never come; logs from the previous operator degrade across dates |
| **Cognition effects** | CO₂, fatigue, cold: subtle input lag, UI ghosting, heartbeat, vignette — tied to actual sim state, never scripted |
| **The void outside** | Windows work. Exterior is dark, slow, indifferent; lighting reflects mood through cabin systems (brownout = darkness) |
| **Attrition math** | The warning board accumulates; stores deplete; the player's own repair quality becomes a variable |
| **Prior crew traces** | Notes, tool placement, an unfinished repair, a name on a locker — environmental storytelling only |

### 4.6 Failure Cascades (authored first, emergent after)

MVP cascade example:
> Micro-puncture (hull) → pressure drop → O₂ candle burn raises humidity → condensation in breaker panel → intermittent short → greenhouse heater offline overnight → food reserve down next day.

Design rule: every cascade is *traceable* by an attentive player. No randomness without a readable chain.

### 4.7 Win / Loss / End Conditions

- **Loss:** asphyxiation, hypothermia, hull breach, power death (battery = 0 with no generation), or unrecoverable cascade (soft-lock guard: mercy event rather than hard brick wall — e.g., emergency beacon burns your last fuel to reset the leg).
- **Win (leg):** reach waypoint with ship intact; cache access.
- **Long-term progress (supersedes campaign win, 2026-10-09):** sustain and improve the ship, discover opportunities, and choose new expeditions. No compulsory whole-voyage victory. Optional grounded narrative discoveries may exist without gating survival.
- **Recovery during Early Access (operator decision 2026-10-15):** keep the lenient mercy recovery. Permadeath is planned after Early Access (`LATER.6`).

---

## 5. Narrative Framework

**Premise:** The *Hullwatch*-class hauler **Conatus Finitus** ("finite striving"; named 2026-10-15) was dispatched on a multi-decade haul with rotating operators in cryo-cycle. You woke on schedule. The rotation didn't. The ship's log insists everything is nominal. The systems disagree.

**Delivery:** No cutscenes at launch. Narrative arrives through:
- Prior operator logs (text + audio, dated, increasingly sparse)
- Ship computer scheduler entries and maintenance history
- Physical environment (an unmade bunk, a coffee ring on a manual, a tool where it shouldn't be)
- Comms: archives, automated pings, one-sided conversations with a mission control that may no longer exist

**Tone rules:** Understated, technical, never explaining more than the player needs. The scariest line should be a maintenance log entry.

---

## 6. Art & Audio Direction

### 6.1 Art Direction — "Analog Industrial"

- **Palette:** worn off-white, hazard amber, muted teal, warning red used sparingly; warm interior light vs. absolute black exterior.
- **Materials:** scratched panels, chipped paint, taped labels, hand-written dockets, retro-futuristic tech (CRT displays, 7-segment readouts, toggle switches, chunky knobs) — *no* sleek holograms.
- **Spaces:** cramped, purposeful decks. Every object has a job. Cleanliness tells story (a freshly tidied module means something).
- **The ship is the set:** one continuous interior for the whole game (MVP: one module), density over quantity.
- **Post:** film grain, subtle chromatic aberration, CRT shader on screens, heavy vignette only when simulation state justifies it.
- **Xenon-metal (signature material):** the ship's structure is a *grown*, seamless xenon-metal lattice — an alloy no yard can manufacture or duplicate. It reads as dense, faintly mottled graphite with a cold sheen at grazing angles. The fiction's deliberate split: miraculous structural materials, 1980s-era computers, toggles and 5-inch disks bolted on top of them. Repairs improvise; the frame itself is untouchable.

### 6.2 Asset Pipeline

- **Blender 5.1** for all hard-surface work; modular kitbash kit (panel types, fittings, consoles) with consistent texel density; export via glTF 2.0.
- **Style guide first:** one hero module fully art-passed before content scales.
- **AI-assist:** Blender MCP connection to be set up when modeling begins (not required for M1 grey-box).

### 6.3 Audio Direction

- **Music:** almost none; low drones and hums only, or brief authored stingers at narrative beats.
- **Sound is information:** each pump, fan, and relay has a healthy and unhealthy loop; the player learns diagnostics by ear before instruments.
- **Silence engineering:** the ship's hum drops when power sheds; the void outside is truly silent; the player's own breath and footsteps carry the mix.
- **Priority:** audio direction is a *first-class* system, prototyped in M1, not deferred to polish.

---

## 7. Technical Architecture

### 7.1 Stack

| Layer | Choice | Notes |
|---|---|---|
| Engine | Godot 4.7.2 stable | Local binary in `Engine/`; Forward+ renderer |
| Language | GDScript (typed) | Static typing enforced (`gdlint`/editor warnings as errors) |
| Simulation | Fixed-tick (10 Hz) autoload simulators | Decoupled from `_process`; signals out |
| Data | Custom `Resource` classes (`.tres`) | Components, failure modes, items, procedures |
| Save | Versioned dict → JSON (or `ResourceSaver`) | Must serialize full sim state; migration path from day one |
| VCS | Git + Git LFS (for art/audio binaries) | `Engine/` binaries gitignored |

### 7.2 Project Layout

```
OperationSpacer/
├── Engine/                  # local Godot binary (gitignored)
├── docs/                    # specs, design docs
├── game/                    # Godot project root
│   ├── project.godot
│   ├── scenes/              # scene files (.tscn)
│   ├── src/
│   │   ├── autoload/        # singletons: SimClock, EventBus, ShipState, SaveManager, AudioDirector
│   │   ├── systems/         # power.gd, thermal.gd, atmosphere.gd, hull.gd, nav.gd, comms.gd, stores.gd
│   │   ├── components/      # wear model, failure mode resources
│   │   ├── interactables/   # panels, valves, filters, tools
│   │   ├── player/          # controller, carry/interact, scanner
│   │   ├── ui/              # diegetic UI, manual binder, log reader
│   │   └── data/            # .tres content
│   └── assets/              # art, audio, fonts
├── tools/                   # dev utilities, MCP configs
├── AGENTS.md                # AI agent guide (generated by /init)
└── README.md
```

### 7.3 Architecture Rules

1. **State lives in simulators.** Nodes render and interact; they never hold authoritative state.
2. **Signals, not polling.** `EventBus` publishes typed events (`power_brownout`, `component_failed`, `compartment_pressure_changed`).
3. **Data over code.** Adding a component, fault, or item must not require new code paths.
4. **Deterministic sim.** Same seed + same inputs = same failures. Enables testing and save/load fidelity.
5. **Headless-testable.** Core sim must run in `--headless` with scripted scenarios for regression tests.

### 7.4 AI-Assisted Pipeline (MCP)

| Tool | Purpose | Status |
|---|---|---|
| Godot MCP (`hybridindie/godot-mcp`, 180 tools, WebSocket bridge; `godot-editor-mcp` on PyPI) | Scene manipulation, runtime control, inspection from AI agent | To set up at M0 |
| Blender MCP | Modeling assist, scene queries, material ops | To set up at M3 |

Fallback: direct file authoring (`.tscn`/`.gd` are version-controllable text; Godot headless CLI is scriptable).

---

## 8. Production Plan

### 8.1 MVP / Vertical Slice (target: first playable)

**Scope:** One ship module: cockpit + corridor + life support closet + engine bay (grey-box or rough art).

Must-haves:
- First-person movement, interaction, carry
- Day cycle with sleep transition
- Complete, interlinked sims: power, thermal, atmosphere (hull as simplified pressure model)
- 6–8 component types with wear and 2+ failure modes each
- 3 repair procedures (filter swap, breaker reset/rewire, sealant patch)
- Diegetic panels + manual binder + maintenance board
- Failure cascade: one authored chain, emergent behavior beyond it
- Save/load, loss states, leg-win state
- Audio bed with diagnostic loops

**Success test:** A new player, given only the in-game manual, survives 3 in-game days and can explain what went wrong and why.

### 8.2 Milestones

| Milestone | Deliverable | Exit Criteria |
|---|---|---|
| **M0 — Setup** | Godot project, conventions, git/LFS, MCP server, input + interaction scaffold | Editor runs project; MCP agent can create/inspect a scene; `--headless` smoke test passes |
| **M1 — Grey-box prototype** | Walkable module, interactables, power sim, one repair task, day cycle, placeholder audio | 10-minute day loop playable with no placeholder logic holes |
| **M2 — Systems prototype** | Power/thermal/atmosphere interlinked, wear + failures, cascade, save/load, headless tests | Deterministic scenario tests pass; failures traceable in a test harness |
| **M3 — Vertical slice** | Art pass on one module, audio direction, diegetic UI, nav/travel stub, one narrative beat | Vertical slice demo: 20–30 min, external playtester completes success test |
| **M4 — Alpha** | Full small ship (5–6 modules), all systems, full procedure set, stores/economy, open survival activities and freely chosen destinations | Agreed survival activity set content-complete; balance pass begins |
| **M5 — Beta** | Balance, performance, accessibility, save migration, localization prep | 60 fps target on mid hardware; no P1 bugs; playtest metrics stable |
| **M6 — Release prep** | Steam page, build pipeline, store assets, demo build | Shipping checklist complete |

Post-v1 expansion milestones **M7–M12** (open hull + EVA, deep field, materials/fabrication, ship modularity, destinations, polish) are tracked in `docs/EXPANSION_SPEC.md`.

**M4 scope correction — operator-requested 2026-10-09:** open-ended survival
supersedes the October 8 four-arrival campaign baseline and original 3–5-waypoint
campaign target. Existing two destinations remain travel content, not required
campaign stages. Expand meaningful player activities and ship capabilities.
The proposed activity set, resource continuity and acceptance plan are in
`docs/design/open_survival_direction_pass.md`; implementation is still planned.

**EA build plan — operator decision 2026-10-15:** *freeze & finish*. No new systems
before Early Access; the twelve ordered slices `EA01`–`EA12` in
`docs/dashboard/roadmap.json` (`ea_plan`) replace M4–M6 and the remaining open-survival
activity passes as the EA scope. Unbuilt activities (exterior projects, personal
ownership) move to `LATER`. Agent rules are in `AGENTS.md` › *EA build rules*.

**EA slice decisions — operator, 2026-10-15:**

| Slice | Decision |
|---|---|
| `EA03` | First recovered technology is the **battery cabinet** (more storage, not generation; revised the same day from the grow rack, which moves to `LATER`). Machine sockets exist only in built pods, so the expedition route includes building a pod at a dock plate. |
| `EA03` | **Airlock checkpoint:** a save made during EVA loads inside the airlock, suited, with carried items and suit O₂ as they were at cycle-out. |
| `EA04` | **Xenon and buffer gas:** finite sealed bottles in wrecks and caches, plus volatile ice from existing ice contacts processed in the existing fabricator (renewable through expeditions; no new contact system). |
| `EA04` | **Nanites** are a limited stock from the start of a game and are produced only slowly; nanite builds stay the expensive shortcut (operator-approved exception to the no-new-resource rule). |
| `EA08`/`EA09` | **Major visual refinement** of the ship, pods and machines toward a refined Starpath-inspired look; the art-development method is agreed before `EA08` starts. |
| `EA05` | **Operator identity:** a name on a locker, no backstory; the surname is still to be chosen. **Vessel:** *Conatus Finitus*. |
| `EA10` | **Performance target:** Steam Deck at its native 1280×800 holding 60 fps, with reduced visual settings allowed; the desktop mid-range tier is taken from the Steam Hardware Survey when `EA10` starts. |
| `EA10` | **Platforms:** Windows, Linux and Steam Deck. Development happens on Linux; the operator playtests on Windows. |

### 8.3 Scope Guardrails (Non-Goals)

- **No combat, no weapons, no threats with agency**
- **No supernatural entity, no jumpscares** (pillar: grounded dread)
- **No multiplayer at launch** (single-player only; co-op is a post-launch "maybe", architecture must not preclude it)
- **Superseded for early access by `docs/EXPANSION_SPEC.md` (M7+):** seamless procedural space, EVA, ship expansion and planet/star travel were v1 non-goals and are now EA scope.
- **No full Newtonian flight sim** (weighty but simplified) — still applies; travel is course-setting, not piloting (see `docs/EXPANSION_SPEC.md`).
- **No voice acting** (text + diegetic audio only). Reaffirmed 2026-10-15: the synthesized voice orientation is replaced by diegetic text in `EA02`.

### 8.4 Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Sim complexity runaway | Missing all milestones | Data-driven components; MVP is "systems that interact," not "systems that are many"; freeze sim scope at M2 |
| Maintenance = tedium | Core loop fails | Task time tuning; skill expression through speed; automation upgrades as progression; playtest at M1 not M4 |
| Grounded horror not scary enough | Fails creative goal | Audio first-class from M1; cognition effects bound to sim state; lean on isolation/latency mechanics |
| Solo-dev burnout / scope | Project dies | Milestones with hard cuts pre-agreed; vertical slice before content scale; no art until M2 logic is fun |
| GDScript performance | Sim jank at scale | Tick-based sim (10 Hz), small datasets, no per-frame alloc in `_process`, headless profiling at M2 |
| Save/load corruption | Player trust loss | Versioned saves, sim determinism, automated save/load round-trip tests from M2 |

### 8.5 Success Metrics (Vertical Slice)

- Playtester completes 3-day survival with manual only (no external help)
- ≥ 70% of testers describe low-power night as "tense" unprompted
- Repair satisfaction: testers report wanting to fix *one more thing*
- No tester describes the loop as "chores" before day 3

---

## 9. Open Questions (to resolve before M3)

1. Protagonist: silently-named operator with limited backstory, or blank slate? — **Resolved 2026-10-15: a name on a locker, no backstory; surname chosen in `EA05`.**
2. EVA (exterior hull work) in v1? — **Resolved 2026-09-18: yes, expansion milestone M7** (airlock, tethered exterior work).
3. Food/greenhouse fully simulated in v1 or abstracted as stores? — **Resolved: abstracted stores in v1; greenhouse becomes a buildable ship module in expansion M10.**
4. **Resolved direction 2026-10-09:** open-ended survival, with no fixed campaign length or required number/order of arrivals. This supersedes October 8's four-leg Alpha baseline. Session pacing, activity content and resource availability remain to be designed.
5. Death frequency target: how punishing? — **Resolved 2026-10-15: lenient mercy recovery during Early Access; permadeath after EA.**
6. Comms content: does a reply ever come? (Lean: yes, once, late, and it isn't what the player hoped — grounded, not cruel.)

---

## Appendix A — Style Rules Quick Reference

- **Code:** typed GDScript; systems never reference UI; content via `.tres`; no hardcoded balance numbers in scripts
- **Naming:** `snake_case` files, `PascalCase` classes, `SCREAMING_SNAKE` constants
- **Commits:** conventional-ish (`feat:`, `fix:`, `sim:`, `art:`, `docs:`)
- **Design docs:** every mechanic must answer "what does the player *do* with their hands?"

## Appendix B — Glossary

| Term | Meaning |
|---|---|
| Leg | One waypoint-to-waypoint stretch of the voyage |
| Day | One full wake→sleep cycle (target 15–30 min real time, tuneable) |
| Cascade | A chain of failures propagated through interdependent systems |
| Stores | Consumable inventory: parts, filters, sealant, food, O₂ candles |
| Condition | 0–1 health value on any component, drives failure probability |
