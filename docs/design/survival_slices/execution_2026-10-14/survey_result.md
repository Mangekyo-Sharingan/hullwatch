# Investigation notebook — October 14

The first investigation packet is implemented locally, following the approved
slice 03 order: instrument-led observations before a new probe. The physical
SENSOR CONTACTS terminal now includes SURVEY NOTEBOOK. The command station keeps
its existing program list.

Carrying the real scanner and using its primary action records a reachable
contact. Composition and remaining supply stay unknown until an actual sample
or anomaly study produces evidence. Diagnosing recovered equipment records its
measured condition and original field. Entries survive travel, streaming,
revisits and repeated saves without generating cargo or resetting deposits.
Archived entries show dated observations; current entries add live range,
approach xenon cost, hold room and suit oxygen for preparation. Approach uses
the existing fuel-gated maneuver.

Sector state v3 owns the notebook. Global saves advance from v9 to v10; older
watches start with no fabricated observations and retain their existing
depletion. One shared validator checks complete records, canonical string seed
identities, finite quantities, confidence and evidence consistency before any
load applies. Invalid notebook data leaves both owners and the clock untouched.

Focused survey, sector, detection, mining, anomaly salvage, approach, computer
terminal and manual suites passed with exit 0 and exact suite PASS. Parent
migration and nested-save boundary checks also passed. These are scoped runs;
the later integrated receipt will record the final source tree separately.

Two native Linux 1280×800 captures at UI scales 1.0 and 1.4 passed panel bounds
and the enlarged notebook was visually reviewed (`survey_captures/`,
`survey_ui.log`). Its longer report uses the existing scrollable computer page.
The existing orientation heading overflow was separately corrected with native
word wrapping: guide and four supply-menu bounds pass at the same scales
(`scaled_guide_captures/`, `scaled_guide_ui.log`).

## Integrated validation and local candidate

The final stable source at `ef8aab9` plus the recorded local file hashes passes
all 99 script suites (including smoke) and startup: **100/100 checks**.
`survey_suite_results.json` records exact PASS markers, zero script/parse errors,
isolated user data and unchanged input hashes during the run. Earlier sweeps are
retained as `survey_suite_attempt1.json` and `survey_suite_attempt2.json`; their
version-assertion and pod lifecycle findings were corrected and rechecked.
Pod wiring now precedes `_ready`, retired-zone callbacks cannot write removed
compartments, and teardown fixtures read positions before nodes detach.

The isolated local Windows cross-export is
`build/windows-candidate-2026-10-14/Hullwatch.exe`. Its actual embedded content
passes 12 scoped checks using the Linux editor engine from an empty project;
the artifact hash and exact scope are in `candidate_checks.json`. One source-only
CSV invariant was unsuitable for the export and its failed attempt is retained;
the replacement check verifies all 89 English keys in the actual compiled
translation resource. Snapshot import changed only generated translation/UID
metadata. No public tag, native Windows execution or new updater-channel delivery
is claimed. Candidate README and source snapshot accompany the executable.

The generated-instance correction also passes its source regression and a copied
addon-enabled import with zero popup errors. Seventeen native Linux exterior
frames were captured after regeneration, with the burning-drive and exterior
pod views reviewed; selected frames are in `geometry_captures/` and the full
capture log is `geometry_render.log`. See
`../../import_warnings_2026-10-14.md` for root cause and deterministic hashes.

This packet does not complete the whole investigation slice. A paid, physical
probe mission, opportunity differentiation and human preparation/route
acceptance remain. EVA load policy, zero-xenon recovery and mixed-gas supply are
still unresolved. No new lore, public release or native Windows validation is
claimed.
