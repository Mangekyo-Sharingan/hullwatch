# Documentation dashboard — October 8, 2026

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
