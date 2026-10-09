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
- Documented pass history, Git checkpoints, local changes, and the system,
  data-resource, and test-file inventories.

The collector includes every Markdown, JSON, and text document under `docs/`,
root Markdown guides, release Markdown, game data resources under
`game/src/data/`, and the curated OpenWolf status, learnings, memory, anatomy,
protocol, and bug log. It does not collect user saves, credentials, transcripts,
or agent configuration files. Sources remain complete, including historical
and contradictory documents; their dates and current-source evidence are
shown rather than silently rewriting them.

## After each pass

1. Record the pass result and update `.wolf/STATUS.md` with the actual outcome.
2. Update the relevant milestone/tasks in [roadmap.json](roadmap.json), adding
   a new milestone for a new pass. Include evidence paths and explicit pending
   reviews. Update the manifest's `updated` date when its status changes.
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

The manifest contains `milestones` and `gates`. Each has an `id`, `title`,
`status`, `summary`, and `evidence` entries shaped as `{path, label}`. Milestones
also have a `phase`, `tasks`, and `acceptance` criteria. Task statuses and
milestone statuses are one of `complete`, `in_progress`, `needs_review`,
`planned`, or `blocked`. Paths are repository-relative. The visual progress bar
counts completed tasks and pending reviews; it is not a percentage of game or
release readiness.

Recorded tests retain their original evidence dates. Refreshing the dashboard
does not run tests, validate an executable, or establish operator acceptance.
The page labels source modification dates separately from validation claims.

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

## Browser check

The optional check uses an existing `playwright-core` installation and Chromium:

```sh
NODE_PATH=/path/to/installed/node_modules node tools/check_dashboard.cjs
```

It checks exact source contents, navigation, search, roadmap tasks, images,
safe Markdown, offline loading, and desktop/mobile layouts. Pass an exported
`index.html` path as the first argument to check a portable snapshot instead.
This tooling is for development; reading or rebuilding needs no browser package.
