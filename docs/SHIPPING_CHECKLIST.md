# Shipping and playtest checklist

Updated 2026-10-09. This checklist separates a private playtest package from
Early Access readiness. A green source suite is not evidence of a tested
Windows build or a completed human playthrough.

## Scope and evidence checkpoint

- **Approved direction:** open-ended isolated survival. There is no mandatory
  final waypoint, fixed voyage length, or campaign victory. The old v0.10.0
  checklist item for a “final waypoint” win state is superseded by
  `docs/PRODUCTION_SPEC.md` §§3, 4.7, 8.2 and 9 (2026-10-09).
- **October 1 package:** `releases/windows/2026-10-01/Hullwatch-Windows.zip`
  is from source checkpoint `5303882`; it predates the October 9 art/salvage
  pass and must not be described as containing that work.
- **Latest recorded package:** `releases/windows/2026-10-09/Hullwatch-Windows.zip`
  and `Hullwatch.exe` are from source checkpoint `c982415`. Their embedded
  project and source suites were checked with the matching Linux engine. Native
  Windows runtime was not verified. This package predates the current local
  Delete Watch and encounter-setting changes below.
- **October 9 source evidence:** `docs/design/survival_slices/01-result.md`
  records 90/90 headless suites and a successful headless startup on Linux at
  checkpoint `c982415`. Its `profile_sim` result is 201.0 µs/tick against a
  200 µs budget (FAIL). These checks cover the October 9 package source, not
  the newer uncommitted menu/settings changes or native Windows execution.
- **Current working-tree validation (2026-10-09):** headless startup and all
  90 suites pass, including the updated Delete Watch and encounter-preference
  assertions. `profile_sim` measured 198.6 µs/tick across 144,000 ticks, just
  under the 200 µs budget. This is Linux source validation; it does not validate
  an export, native Windows execution or rendered frame rate.
- **Ending:** no story/campaign ending is required by the approved scope.
  Death/recovery policy, session pacing, activity content and resource
  availability still need decisions or acceptance evidence.

## Private playtest package

### Required before sending an executable

- [x] Main/pause flow, Continue, new/load, three slots, confirmed overwrite,
  confirmed Delete Watch, save-and-quit, and settings controls are implemented.
- [x] Mouse sensitivity, inversion, volume, UI scale, analogue filter, field
  object rate, anomaly frequency and planet occurrence persist in user settings.
  Field object rate controls overall field content; anomaly frequency adjusts
  its anomaly share.
- [x] Run the menu, settings, sector, navigation, voyage and save migration
  suites after the latest changes; all 90 headless suites pass on the current
  working tree.
- [ ] Build a fresh Windows package from the exact reviewed source checkpoint;
  the October 9 package at `c982415` predates the current local changes.
- [ ] Check the fresh package's embedded content, checksum and archive integrity;
  include controls, source commit, build date and known limitations.
- [ ] Run the actual executable on Windows: startup, new watch, save/load across
  all three slots, overwrite/corrupt-slot behavior, settings, movement and one
  representative maintenance/travel/EVA route. Cross-export and Linux pack
  checks do not close this item.
- [ ] State the intended test scope clearly: private playtest candidate, not an
  Early Access-complete build.

### Playtest evidence to collect

- [ ] Run the Production Spec's manual-only three-day survival success test:
  can a new player survive and explain what failed and why, without external help?
- [ ] Record one uninterrupted work cycle from inspection/diagnosis through
  repair, travel, airlock/EVA, return, and save/load. Scripted slices are useful
  regression evidence but are not a human route test.
- [ ] Record current-content balance and player feedback on clarity, maintenance
  workload, encounter pacing, salvage value, and save/recovery expectations.

**Current state:** the Oct 1 live-input attempt stopped at the main menu after
the X11 render stalled and the KDE input-control approval expired. The October 9
salvage pass separately reports a 90/90 source suite, but still lists the human
EVA route, equipment balance and art review as pending. See
`docs/design/art_pass/steps/12-final-validation-result.md` and
`docs/design/survival_slices/01-result.md`.

## Early Access readiness

- [ ] Turn the approved open-survival direction into a bounded, content-complete
  acceptance target. Six activity directions are documented; only the first
  salvage/refit loop has an implementation checkpoint, with a provisional
  battery fixture. Surveying, ship specialization, tending a living ship,
  exterior work and ship personalization remain planned. See
  `docs/design/open_survival_direction_pass.md` and
  `docs/design/survival_slices/`.
- [ ] Define and validate a sustainable resource economy. The current plan still
  leaves potable-water production from ice, physical sealant refill, xenon
  resupply, atmosphere recovery, and viable resource access unresolved. Prove
  long-session continuity and that depleted/revisited sites do not accidentally
  reset or strand the player. See
  `docs/design/survival_slices/replenishment_plan.md`.
- [ ] Finish the needed persistence/recovery policy and tests for player/EVA
  location, carried/dropped/consumed tools and resources, procedures, production
  fractions, construction/fabrication jobs, and refunds. Salvage identity is
  persisted; this does not establish whole-game persistence. See
  `docs/design/survival_slices/persistence_plan.md` and its acceptance plan.
- [ ] Resolve death frequency, loss and recovery consequences before balancing
  the long-term loop (`docs/PRODUCTION_SPEC.md` §9).
- [x] Current Linux `profile_sim` pass: 198.6 µs/tick over 144,000 ticks against
  the 200 µs budget. The margin is narrow and should be rechecked after major
  simulation changes.
- [ ] Validate rendered performance on representative mid-range hardware
  against the Production Spec's 60 fps target. Headless scene timing is not
  rendered FPS.
- [ ] Complete a current-content external playtest and balance pass; record
  whether the loop supports meaningful goals and earned calm over a sustained
  session. Earlier v0.6.0 feedback predates current diagnostics, travel, EVA,
  salvage and art.
- [ ] Complete accessibility review beyond the current settings. Subtitles and
  real-hardware readability/usability remain unchecked in the prior shipping
  record.
- [ ] Verify save migration and fresh-watch isolation on the actual release
  candidate, including the affected live systems and all three slots.

### Player-facing encounter settings

- [x] Field object rate and anomaly frequency are implemented and persisted.
  Field object rate scales total chunk content, including asteroids, debris and
  anomalies. Anomaly frequency adjusts the anomaly share.
- [x] Planet occurrence generates optional, deterministic survey-orbit routes
  after arrivals using the existing waypoint travel and finite-cache systems.
  `x1.00` is a 35% discovery chance, `x2.00` is 70%, and `x3.00` guarantees one
  route per arrival. Turning the rate down does not remove already charted
  routes; only later arrivals use the changed preference. It does not imply a
  local planet landing or probe loop.
- [x] `test_settings.gd`, `test_sector.gd`, `test_nav.gd`, and
  `test_save_migration.gd` cover persistence, rate extremes, deterministic route
  discovery, chart selection, generated-route save/load and migration.
- [x] Encounter rates are global `GameSettings` preferences. New sector saves
  do not store them; legacy per-sector frequency fields are ignored so current
  preferences win on load.
- [x] `test_sector.gd` confirms legacy frequency fields are ignored and new
  sector saves omit them; `test_settings.gd` confirms preferences persist.
- [ ] Ask playtesters whether encounter-rate changes should keep rebuilding the
  active streamed field immediately or apply only after a sector transition.
  Current behavior is live and should be treated as a tuning choice.

## Public store release (after Early Access readiness)

- [ ] Select the distribution platform and configure the store account/depot.
- [ ] Replace generated capsules with final key art; prepare a trailer and
  complete the platform age-rating questionnaire.
- [ ] Confirm final title and applicable EULA/privacy and third-party notices.
- [ ] Complete signing/installer work if required by the chosen platform.
- [x] Asset credits are recorded in `docs/ASSET_CREDITS.md`; the existing store
  copy and in-game screenshots are drafts/evidence, not a finished store page.
