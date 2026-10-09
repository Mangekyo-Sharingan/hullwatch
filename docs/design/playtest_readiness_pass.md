# Playtest readiness pass — 2026-10-09

## Verdict

The current feature branch has a main/pause/menu flow, three save slots,
persistent player settings, confirmed Delete Watch, and deterministic optional
planetary route discoveries. A Windows package from the October 9 source
checkpoint exists, but it predates this branch's menu, settings and planet
route changes. Native Windows execution remains unverified. Keep this as a
playtest candidate, not an Early Access-complete game.

Early Access readiness is a larger content and economy gap. The approved
direction is open-ended survival without a required campaign ending. Six
activity directions are planned, but the current implementation checkpoint is
the first, still-provisional salvage/refit loop. Sustainability, broad save
recovery, balance and real-hardware performance remain open.

## Evidence checkpoint

| Evidence | What it establishes | What it does not establish |
|---|---|---|
| `5303882` and `releases/windows/2026-10-01/Hullwatch-Windows.zip` | October 1 Windows cross-export/package | October 9 art/salvage source and native Windows runtime |
| `c982415` and `releases/windows/2026-10-09/` | October 9 Windows cross-export, README/checksums, embedded project checks and 90/90 source suites using the matching Linux engine | The later local Delete Watch/frequency changes, native Windows runtime, human playthrough, or rendered FPS |
| `docs/design/survival_slices/01-result.md` (2026-10-09) | Linux import/startup, 90/90 headless suites, focused salvage/migration/conservation checks at `c982415` | Validation of the newer working-tree changes, a human playthrough, or rendered FPS |
| Same October 9 result | `profile_sim` measured 201.0 µs/tick against a 200 µs limit at `c982415` | The current menu/route source revision |
| `docs/design/art_pass/steps/12-final-validation-result.md` (2026-10-01) | Scripted linked work-cycle coverage and a recorded menu render | Uninterrupted manual route; the input-control request expired before gameplay |
| Current feature branch (2026-10-09) | Headless startup and 90/90 suites pass on Linux; focused menu/settings/nav/migration checks pass; `profile_sim` is 198.6 µs/tick over 144,000 ticks | A packaged build, native Windows behavior, a human playthrough or rendered FPS |
| `game/tests/test_session_menu.gd`, `test_session_flow.gd`, `test_save_load.gd` | Three-slot menu, overwrite/corrupt-slot handling, pause/save/load, transitions and confirmed Delete Watch with cancellation | Native Windows behavior or all world-state persistence cases |
| `game/tests/test_settings.gd`, `test_sector.gd`, `test_nav.gd`, `test_save_migration.gd` | Persistent asteroid/anomaly/planet rates; zero/max planet behavior; charted routes, seeds and plotted courses survive save/load; v5 saves migrate | Planet rate balance and human playtest feedback |

The feature branch `feat/complete-playtest-menu-2026-10-09` is based on
`d51c233`, the pushed source/publication checkpoint, and contains the menu,
settings and route work described here. The current branch validation covers
these source changes, while the `c982415` package does not. The CPU profile
passes narrowly; rendered FPS remains unmeasured. Package the exact reviewed
commit before distribution. Neither cross-export establishes native Windows
runtime behavior.

## Private playtest gate

### Before distribution

1. Export a fresh Windows build from the exact reviewed source and identify it
   by source commit and build date. The October 9 package is at `c982415`; it
   does not include the later local menu/settings changes.
2. Verify the embedded pack, archive/hash, and native Windows startup. Exercise
   new watch, Continue, each of the three slots, save/load, overwrite
   confirmation, invalid/corrupt slots, pause/resume, settings, movement and a
   representative maintenance/travel/EVA path.
3. Include controls, tested build identity and known limitations. Describe it as
   a private playtest candidate rather than an Early Access-complete game.

The menu implementation covers Continue, new/load, three slots, confirmed
replacement, main-menu Delete Watch, pause save, save-and-menu, save-and-quit,
settings and quit. Delete requires a second confirmation and returns to the
updated slot list. The settings menu persists mouse controls, audio, UI scale,
analogue filter, field object rate, anomaly frequency and planet occurrence.
The save manager validates slots and replaces through a flushed temporary
file. Automated assertions cover deletion, setting persistence, route
generation and migration.

Two settings details need clear expectations during testing:

- “Field object rate” scales total chunk content, including asteroids, debris
  and anomalies; it is not an asteroid-only count. Anomaly frequency separately
  changes the anomaly share.
- Planet occurrence controls optional survey-orbit destinations discovered on
  waypoint arrival. At x1 the deterministic roll is 35%, x2 is 70%, and x3
  guarantees one route; the current setting affects future arrivals only.
  Each route uses the existing travel/caching model and persists after
  discovery. It does not add local planet approach or landing. Tune baseline
  probability and the smaller first-visit cache with playtester feedback.

Field and anomaly preferences are global `GameSettings` values. New sector
saves omit asteroid/anomaly frequencies, and loading legacy frequency keys
leaves the current player preferences in force. Changing either rate rebuilds
the active field immediately; Q10 tracks whether this live behavior should
remain. Planet frequency is global too, but only affects future arrivals;
known planetary routes stay charted. Save v6/NavSystem state v4 retain
generated routes and arrival ordinal through load.

### Evidence to gather from the playtest

- The Production Spec's success test remains a new player surviving three
  in-game days with only the manual and explaining what went wrong and why.
- Record an uninterrupted route through inspection, diagnosis/refit, travel,
  airlock/EVA, return and save/load. Existing linked automated tests do not
  replace this observation.
- Measure maintenance workload, encounter pacing, salvage value, failure
  readability and player understanding of save/recovery behavior.

This is a test objective, not a reason to wait for a playtester before making a
candidate package. The first private playtest should produce this missing human
evidence.

## Early Access gate

1. **Content scope and acceptance.** Open survival intentionally has no fixed
   voyage length or final waypoint. The six activity directions in
   `docs/design/open_survival_direction_pass.md` are proposals with acceptance
   criteria still to be bounded. Only salvage/refit has an implementation
   checkpoint, and its first recovered technology is provisional. Complete the
   accepted activity set before calling the loop content-complete.
2. **Resource continuity.** `docs/design/survival_slices/replenishment_plan.md`
   still flags potable water from ice, physical sealant refill, xenon sources,
   atmosphere recovery and resource reachability. Test sustained survival and
   revisits so finite caches and depleted sites cannot accidentally reset or
   strand a watch.
3. **Persistence and loss policy.** The salvage unit has durable identity, but
   `docs/design/survival_slices/persistence_plan.md` still identifies broader
   carried/dropped/consumed item state, player/EVA/tether recovery, job progress,
   fractional production and refund edge cases. Define the checkpoint/loss
   policy and test these cases through fresh-scene load and migrations.
4. **Balance and performance.** The current CPU sim profile passes narrowly at
   198.6 µs/tick; measure rendered performance on representative hardware
   against the Production Spec's 60 fps target. Complete current-content
   external balance tests; headless timing does not measure GPU frame rate.
5. **Accessibility and release polish.** Review subtitles, controls and
   readability on target hardware. For public store release, additionally
   finish the selected platform/depot, final key art, trailer, age-rating
   questionnaire, final title and applicable legal notices/privacy documents.

Death frequency and recovery consequences remain open in `docs/PRODUCTION_SPEC.md`
§9. Resolve them before final balance because they change the stakes of long
survival and save recovery.

## Scope correction

The October 9 production-spec correction supersedes the October 8 four-arrival
campaign proposal. There is no required final waypoint, campaign victory, or
fixed route count under the approved open-survival direction. The prior
shipping-checklist entry “Win state (final waypoint)” therefore cannot remain a
current completed requirement. The checklist now records this correction and
keeps store-release obligations separate from the private playtest package.
