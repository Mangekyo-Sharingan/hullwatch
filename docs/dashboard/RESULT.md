# Documentation dashboard — October 8, 2026

> Current reconciliation, October 14: local v9 supply/persistence/specialization
> evidence now records 97 scenario suites + smoke + startup (99 checks) and a
> bounded 30-day conservation watch. Later focused compatibility checks and
> ongoing notebook/save work remain separate. Published October 13 Windows/Deck
> artifacts are unchanged. The dated sections below preserve earlier checkpoints.

## Outcome

Complete local developer dashboard at `docs/dashboard/index.html`. Game work
remained paused. No game scripts, scenes, assets, saves, or releases were changed
by this pass; previously existing art changes remain in the working tree.

Local hosting is the recommendation for the complete internal archive. The same
builder exports a portable static site suitable for GitHub Pages, without
publishing it or changing hosting settings.

## Coverage

- Complete source documents under `docs/`, root guides, release notes, curated
  OpenWolf context, and game `.tres` data: 151 documents at this checkpoint.
- 201 existing reference images, rendered captures, diagrams, and store images.
- 24 milestones including the dashboard, 153 tracked tasks, and 12 acceptance
  gates. Original production milestones, M7–M14, computer/watch/menu/movement
  passes, all 12 art steps, narrative decisions, and release work are included.
- Full-text search, complete Markdown reader, source downloads, contents links,
  visual inspection, status filters, per-task evidence, Git history and inventory.

Older documents retain their full contents and conflicting historical statuses.
Recorded October 1 game validation remains historical evidence. Manual continuous
play, the simulation tick budget, art review, and native Windows execution remain
open as documented by the art-pass report. This pass did not run game tests.

## Refresh after each pass

Claude/Codex Stop and SessionEnd hooks preserve the existing OpenWolf finalizer,
then rebuild. OpenCode's idle handler waits for OpenWolf's completed flush.
Local Git post-commit, post-merge, and post-checkout hooks are installed and
preserve existing originals. None stage, commit, push, or publish anything.

Restart running agents/servers to load configuration; live delivery from the
already-running session is not asserted. Direct refresh works immediately.
Authors update their result, `.wolf/STATUS.md`, and relevant roadmap task statuses;
new source documents and images are discovered automatically. A report alone
never marks work complete. See [HOOKS.md](HOOKS.md).

## Observed checks

- `python3 tools/build_dashboard.py --check`: complete payload, valid roadmap
  statuses and existing evidence paths, fresh local output.
- `tools/check_dashboard.cjs` with the installed Playwright core and Chromium:
  every embedded source matches its repository file exactly; navigation, ART
  tasks, tables, source view, search, images, Escape dismissal, and safe Markdown
  pass. All five views fit both 1440 px and 390 px widths. No browser errors or
  remote requests. Desktop and mobile captures inspected.
- Portable export to `/tmp/hullwatch-dashboard-export`, followed by the same
  browser check: passes offline with copied local assets.
- Temporary hook/installer checks: JSON preservation, installation idempotence,
  finalizer ordering, stdin and spaced paths, recursion, unchanged output,
  failure propagation, missing builder, preserved Git hooks and arguments pass.
- Temporary OpenCode check: delayed OpenWolf flush and explicit generator failure
  reporting both pass. The printed simulated build failure is expected evidence.

The permanent browser check is optional development tooling. Rebuilding needs
only Python 3.10+; reading needs only a browser. The generated HTML is ignored
by Git and rebuilt atomically. Unchanged sources leave its timestamp unchanged.

---

## Knowledge graph view — October 13, 2026

The dashboard gained an interactive **Knowledge graph** view fed by the
repository's graphify build (`graphify-out/`). `tools/build_dashboard.py`
reads the graph's counts into the page payload and writes a rewritten
`knowledge-graph.html` with the vendored **vis-network 9.1.6** inlined in
place of the upstream CDN script, so the view stays offline like the rest of
the page. The view shows node/edge/community counts and the build date, and
falls back to a clear empty state when no graph exists. Auto-refresh pauses
while the view is open so an explored layout is not reset; **Refresh
snapshot** reloads it.

Observed checks at this checkpoint: the graph held 1,381 nodes, 2,552 edges,
and 108 labeled communities, built from 451 detected files (tree-sitter AST
for code plus a host-agent semantic pass over documents and captures;
GDScript sources are not a graphify-supported language and are absent from
the graph). The integrity diagnostic flagged 117 dangling-endpoint edges
(about 4.5%, mostly minified-vendor and re-export artifacts) with the graph
still fully usable. The full browser check passes; the graph view renders
with no console errors and no remote requests. A pre-existing 390 px
overflow in the checkpoint panel (unbroken STATUS.md tokens) was fixed with
`overflow-wrap:anywhere` on `.current-status`.

`graphify-out/` remains untracked working-tree output; the dashboard degrades
gracefully when the directory is absent.


## Visual EA roadmap and current-status reconciliation — October 14, 2026

The overview and roadmap now show five connected, selectable stages: foundation,
playable ship, survival Alpha (current), player/hardware Beta acceptance, and EA
release. Each stage exposes its exit criteria and linked milestones/gates. A
priority list names the next work. Stage selection and gate links are deep-linkable;
the cards stack on mobile. The existing detailed tasks and full archive remain.

All milestone/gate summaries were reviewed against the October 13 receipts.
Older no-art-export claims are superseded by verified playtest delivery; native
Windows, rendered FPS, human play, operator decisions and public shipping remain
open. The overview records local persistence packet 2 (historical 93/93) separately
from published Windows 20261013.5 / 756fd95 and separate Deck 20261013.4 / 9ac234b.
Refreshing this dashboard establishes no new game-test result.

Fresh checks:
- `python3 tools/test_dashboard_roadmap.py`: PASS for references, stage status,
  current-stage identity, required priorities and evidence boundaries.
- `tools/check_dashboard.cjs`: PASS, 221 exact source documents; all five stages,
  milestone/gate links, current checkpoint/delivery, reader/search/gallery, safe
  Markdown, 1440/390 px layouts and offline loading, zero browser errors/network.
- Same browser check on `/tmp/hullwatch-dashboard-ea-export/index.html`: PASS.
- Desktop/mobile viewport captures `/tmp/hullwatch-path-1440.png` and
  `/tmp/hullwatch-path-390.png` visually reviewed.

The interrupted agent had written priorities at the wrong nesting level; the
first browser check caught the empty view, and the builder/self-check now reject
that missing interface. Click checks wait for the actual hash-rendered stage.
Next authorized work is supply/persistence foundations, followed by the remaining
priorities. No game build/publication or game validation occurred in this phase.

## Local foundations evidence reconciliation — October 14, 2026 (later)

The roadmap now records usable water and reusable sealant, durable paid jobs,
physical equipment/specialization and the bounded 30-day resource watch as local
implemented work. Completed tasks identify their tested boundary; all-resource
SAVE/SUPPLY acceptance remains in progress because EVA resume/checkpoint,
xenon/mixed-gas acquisition, zero-fuel recovery and reachable expedition budgets
remain unresolved. Conversion balance is provisional, recovered battery selection
is provisional, and human/native-hardware acceptance is open.

Sustainable survival and personal ownership show their implemented foundations
separately from remaining care, organization and acceptance. Investigation/notebook
work is in progress; this reconciliation does not mark it complete. Priorities now
point to that activity, unresolved restore/supply policy, then human and hardware
acceptance instead of re-requesting completed water/charge/job work.

The authoritative recorded source checkpoint is the [October 14 v9 sweep](../design/survival_slices/execution_2026-10-14/full_suite_results.json):
97 scenario suites plus smoke (98 script tests), and engine startup, all passing
for 99 checks at the retained source SHA256 manifest. The [fixed-tick fixture](../design/survival_slices/execution_2026-10-14/profile_results.json)
passes three sequential runs, median 165.9 µs against 200 µs. The [bounded watch](../design/survival_slices/execution_2026-10-14/README.md)
includes 57 JSON restores; it establishes water/food/repair conservation in a
controlled fixture, not indefinite survival, xenon resupply, accepted balance or
a human route. This documentation pass did not repeat those game checks.

A subsequent adjacent-pod legacy-save validation correction has supplemental
focused PASS coverage after the full-sweep hashes. It is described separately,
as is ongoing notebook/global-save work; the dated sweep is not claimed for a
newer whole tree.

Published Windows **20261013.5 / 756fd95** and separate Deck
**20261013.4 / 9ac234b** remain unchanged. Local v9 work and subsequent changes
have no new EXE, commit, push or publication in this reconciliation. Current
candidate human acceptance uses the [unfilled playtest form](../design/survival_slices/execution_2026-10-14/playtest_form.md)
after a matching build is made and verified.

Validation for this documentation pass: `python3 tools/test_dashboard_roadmap.py`
exited 0 and printed `PASS: dashboard roadmap references, stage statuses and evidence`.
The check covers schema/references, valid stage status, required priorities and
evidence boundaries. `git diff --check` also passed. Dashboard snapshot generation and browser checks belong to the
parent's final pass after all authored documents are written.
