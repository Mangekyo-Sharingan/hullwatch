# Hullwatch — interactive project dashboard

Open [index.html](index.html) in a browser. It is a local static page: documentation,
roadmap, and project context are embedded, and screenshot/diagram paths point to
the repository. No server, login, CDN, or internet connection is needed to read it.
The generated HTML is ignored by Git; the builder and sources are versioned.

```sh
python3 tools/build_dashboard.py
xdg-open docs/dashboard/index.html
```

The dashboard provides:

- An overview of the game, current handoff, recorded validation, and open gates.
- A full roadmap, with task status, acceptance criteria, and source evidence.
- Full-text search and a complete document reader with tables, checklists,
  code blocks, internal navigation, a contents list, and source downloads.
- The repository's visual archive, including local reference images, with
  folder filters and full-size inspection.
- An interactive knowledge-graph view rendered from `graphify-out/` when a
  graphify build exists, embedded fully offline.
- Documented pass history, Git checkpoints, local changes, and the system,
  data-resource, and test-file inventories.

The collector includes every Markdown, JSON, and text document under `docs/`,
root Markdown guides, release Markdown, game data resources under
`game/src/data/`, and the curated OpenWolf status, learnings, memory, anatomy,
protocol, and bug log. It does not collect user saves, credentials, transcripts,
or agent configuration files. Sources remain complete, including historical
and contradictory documents; their dates and current-source evidence are
shown rather than silently rewriting them.

## After each change

1. Update the active EA slice's task statuses and evidence in
   [roadmap.json](roadmap.json). Never add milestones or slices; only the
   operator adds, reorders or accepts them (`AGENTS.md` › EA build rules).
   Update the manifest's `updated` date when a status changes.
2. Update `.wolf/STATUS.md` with the actual outcome at session end.
3. The installed end hooks rebuild the page after the existing OpenWolf
   finalizer has completed. See [HOOKS.md](HOOKS.md) for runtime support and
   verification. Restart a running agent/server once to load new configuration.

This separates the authored meaning of a pass from generation. A new report is
automatically searchable and appears in the pass history; a report's existence
alone does not mark a milestone complete. The builder validates all roadmap
evidence paths and statuses, and failures remain visible.

The open tab refreshes every 60 seconds while visible, preserves its document
URL and page scroll, and avoids refreshing while an image is enlarged or text
has just been entered. Turn off **Auto-refresh** to keep a fixed reading view.
**Refresh snapshot** reloads immediately after a build.

```sh
# Direct refresh and freshness check
python3 tools/build_dashboard.py
python3 tools/build_dashboard.py --check

# Fallback for a running session that has not loaded the new end hooks
python3 tools/build_dashboard.py --watch

# Apply the agent hooks and optional local Git hooks to another checkout
python3 tools/install_dashboard_hooks.py --git
```

Python 3.10 or newer is sufficient. Rebuilding unchanged sources leaves the
HTML and its timestamp unchanged. Writes replace the file atomically; a browser
never reads a half-written snapshot. No game build or simulator test runs as
part of dashboard refresh, and hooks never stage, commit, or push files.

## Roadmap source

The overview and roadmap begin with the **Early Access build plan**: the twelve
ordered slices `EA01`–`EA12`, how many the operator has accepted, the active or
next slice with its player outcome and required proof, and the "not now" list.
Below it, the connected **Path to Early Access** (foundation → ship → finish the
game → accept on hardware and with strangers → release) shows each stage's exit
criteria, milestones and gates. The detailed milestone cards remain below; open
milestones from before the plan link to the slice that absorbed their work.

`roadmap.json` owns this presentation as well as the task statuses:
`ea_plan` (ordered `slices`, `wip_limit`, `later`, operator `decisions` and
`not_now`), `release_path.current_stage` and `release_path.stages`. Each slice
milestone carries `player_outcome`, `proof`, `out_of_scope` and the `gates` it
closes; earlier open milestones carry `absorbed_into`. The builder rejects:

- more active (`in_progress` or `needs_review`) slices than `wip_limit`;
- a slice started while an earlier slice is neither `complete` nor `blocked`;
- a slice without `player_outcome` or `proof`;
- a `complete` slice without image, video or `docs/playtests/` evidence;
- an open milestone that is not a slice, `LATER`, or absorbed into one of them;
- an open gate that does not belong to exactly one slice;
- unknown references or statuses, and evidence paths outside the repository or
  missing from it (paths under `.wolf/` are local agent context and may be absent
  from a clone).

GitHub Actions runs the same checks on every push and pull request
(`.github/workflows/roadmap-guard.yml`).

`checkpoint.source` records the latest scoped source-validation evidence;
`checkpoint.delivered` records the exact published platform builds separately.
Local changes do not become delivered merely because the dashboard is refreshed.

The manifest contains `milestones` and `gates`. Each has an `id`, `title`,
`status`, `summary`, and `evidence` entries shaped as `{path, label}`. Milestones
also have a `phase`, `tasks`, and `acceptance` criteria. Task statuses and
milestone statuses are one of `complete`, `in_progress`, `needs_review`,
`planned`, or `blocked`. Paths are repository-relative. The visual progress bar
counts completed tasks and pending reviews; it is not a percentage of game or
release readiness.

Every stage, milestone, gate and task has a permanent, globally unique `id`:
stages `STAGE_<NAME>`, milestones `[A-Z][A-Z0-9_]*`, gates `GATE_<NAME>`, and tasks
`<milestone>.<n>` (for example `SURVIVAL_SAVE.4`). The page shows each ID as a
badge that copies it on click, the search box finds roadmap items by ID or title,
and `#view=roadmap&id=<ID>` opens and highlights any item. IDs are never
renumbered or reused; the builder rejects missing, duplicate, mis-parented, or
wrongly prefixed IDs.

Recorded tests retain their original evidence dates. Refreshing the dashboard
does not run tests, validate an executable, or establish operator acceptance.
The page labels source modification dates separately from validation claims.

## GitHub issues mirror

`tools/sync_github_issues.py` mirrors the EA plan to the repository's GitHub issues with
the authenticated `gh` CLI: one milestone per slice (`EA03 — One complete expedition`,
description = player outcome, proof, out of scope, gates) and one issue per task
(`[EA03.2] …`, label `ea-plan`, a `status: …` label while in progress, in review or
blocked, closed when complete). The roadmap stays the source of truth; re-running the
script updates GitHub to match it and creates nothing twice. Issues of removed tasks are
closed as not planned.

```sh
python3 tools/sync_github_issues.py --dry-run   # show changes
python3 tools/sync_github_issues.py             # apply them
```

On `main`, `.github/workflows/issue-mirror.yml` runs the sync automatically whenever
`roadmap.json` or the script changes; it can also be started by hand from the Actions tab.

## Local or GitHub Pages?

**Recommendation: keep this complete developer dashboard local.** It includes
unresolved story/design decisions, sealed-fiction notes, internal handoffs,
and reference material. GitHub Pages is a suitable static host for a sharing
edition later. A private repository does not by itself provide private Pages
access; restricted Pages access requires GitHub Enterprise Cloud. See
[GitHub's Pages overview](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
and [Pages access control](https://docs.github.com/en/enterprise-cloud@latest/pages/getting-started-with-github-pages/changing-the-visibility-of-your-github-pages-site).

The same builder can produce a portable site, with relative asset links that
also work below a GitHub repository subpath:

```sh
python3 tools/build_dashboard.py --site-dir build/dashboard
```

The export contains the complete developer snapshot and copies its visual
assets into `assets/`; it does not publish anything. Review this content and
reference imagery before making it public. If Pages is selected later, an
Actions build can run this command and deploy that directory. Automatic local
refresh cannot update a hosted site until its changed sources are pushed and
the hosting build runs. There is no hosting account or Pages setting changed
by this task.

## Rendering license

Markdown is rendered by a locally vendored copy of **Marked 18.1.0**, under
the MIT license. Its [license](vendor/LICENSE.marked) and [version record](vendor/VERSION)
are retained. The builder embeds the script in the generated page, so no
package installation or network request is needed by a reader. Raw source
HTML is escaped and document links are restricted to supported destinations;
documentation is not executed as application code. The interface, styles,
and original ship icon are repository-authored.

The knowledge-graph view embeds a locally vendored copy of **vis-network 9.1.6**,
under the Apache-2.0 OR MIT license. Its [license](vendor/LICENSE.vis-network)
and [version record](vendor/VERSION) are retained; the builder inlines the
script into `knowledge-graph.html` (generated and Git-ignored) so the view
needs no CDN either.

## Browser check

The optional check uses an existing `playwright-core` installation and Chromium:

```sh
NODE_PATH=/path/to/installed/node_modules node tools/check_dashboard.cjs
```

It checks exact source contents, navigation, search, roadmap tasks, images,
safe Markdown, offline loading, and desktop/mobile layouts. Pass an exported
`index.html` path as the first argument to check a portable snapshot instead.
This tooling is for development; reading or rebuilding needs no browser package.
