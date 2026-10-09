# Dashboard refresh hooks

The local hooks regenerate `docs/dashboard/index.html` with
`python3 tools/build_dashboard.py --quiet`. The generator owns freshness and
ignores its generated output: replaying an unchanged pass leaves the HTML
unchanged. No background service, auto-commit, or game code is involved.

## Installed project configuration

| Agent | Event | Ordering |
| --- | --- | --- |
| Claude | `Stop`, `SessionEnd` | Wrapper runs the existing OpenWolf command to completion, then refreshes. |
| Codex | `Stop`, `SessionEnd` | Same wrapper in the project's existing OpenWolf `hooks.json` schema. |
| OpenCode | `session.idle` | Plugin waits for OpenWolf's final per-session `stop_count` write, then refreshes. |

Claude hooks can run in parallel, so adding a second independent command would
race the final OpenWolf writes. The wrapper preserves the original command,
stdin, stdout/stderr, other hook fields and unrelated configuration. Its timeout
is raised to 30 seconds to cover both commands. See the
[Claude hook reference](https://code.claude.com/docs/en/hooks).

The OpenCode plugin follows the existing `Plugin` interface and `event` handler
pattern ([OpenCode plugin reference](https://opencode.ai/docs/plugins/)). It
records the counter on startup, session creation and busy events; an idle event
waits up to 10 seconds for advancement. The installed OpenWolf handler writes
that counter after usage reconciliation, ledger and memory writes. This is an
explicit dependency on that installed implementation: if an OpenWolf update
changes it, the plugin must be reviewed. A timeout reports failure instead of
building before the final writes. It neither imports a second OpenWolf instance
nor edits vendor files.

**Configured is not the same as loaded.** These files are applied locally,
but a running agent may retain its startup configuration. Restart Claude/Codex
and the OpenCode server before relying on automatic refresh. The existing
`.codex/config.toml` already opts into hooks; this change uses the installed
OpenWolf integration and does not assert universal Codex runtime support.
Confirm actual `Stop`/`SessionEnd` delivery in that runtime after restart.
Direct/manual refresh works immediately and is the fallback when that runtime
does not deliver project hooks.

## Reapply or run manually

```sh
python3 tools/install_dashboard_hooks.py
printf '{}\n' | python3 tools/dashboard_hook.py
python3 tools/build_dashboard.py --check
```

The installer is idempotent and preserves unrelated JSON settings and hooks.
If OpenWolf reinstalls its hooks, rerun the installer. New hook commands resolve
the project from the agent's JSON `cwd` (walking parents); the runner otherwise
uses its own file location. Neither depends on the current machine's home path.
The existing OpenWolf command is kept verbatim, including any original absolute
path; moving the repository still requires reinstalling OpenWolf's own hooks.
Command arguments with spaces are passed intact. Python 3 must be available as
`python3`; the helper and generator require only the standard library.

The wrapper runs the finalizer even on a Stop continuation, but skips the refresh
when `stop_hook_active` is true. The generator inherits
`HULLWATCH_DASHBOARD_ACTIVE=1` to prevent nested refreshes. No success text is
sent to the agent, so refresh does not request another turn. A missing generator,
malformed JSON, finalizer failure or build failure produces stderr and a nonzero
exit. Both commands are attempted even if the finalizer fails; its failure code
takes precedence. OpenCode also reports errors through its console and an error
toast. Agent-specific treatment of nonzero hook exits still belongs to the agent.

For a live session that cannot reload hooks, use
`python3 tools/build_dashboard.py --watch`,
or run the direct refresh command after the final doc writes.

## Local Git hooks

```sh
python3 tools/install_dashboard_hooks.py --git
```

This option was run for this checkout on October 8, 2026. It installs local `post-commit`, `post-merge` and `post-checkout`
wrappers in the hooks directory selected by Git (including `core.hooksPath`).
It is not installed by the default command. Existing files are renamed to
`<hook>.hullwatch-original`; executable originals run first with every argument
unchanged. Non-executable originals remain preserved and inactive, as before.
The refresh runs even when an original hook fails, and that original exit code
is preserved. Reinstallation does nothing to an existing dashboard wrapper;
symlinks and conflicting backup files are rejected instead of overwritten.
Post hooks report failures but cannot undo the completed Git operation.

To remove an optional Git wrapper, remove that wrapper and rename its
`.hullwatch-original` backup to the original name, if present. Do not remove other
hooks or change `core.hooksPath`. Shared hook directories affect other working
trees; install there only when every target tree contains these dashboard tools.

## Checks

```sh
python3 - <<'PY'
import json
from pathlib import Path
for name in ('.claude/settings.json', '.codex/hooks.json'):
    data = json.loads(Path(name).read_text())
    for event in ('Stop', 'SessionEnd'):
        assert any('tools/dashboard_hook.py' in hook.get('command', '')
                   for entry in data['hooks'][event] for hook in entry['hooks'])
print('PASS: dashboard end hooks configured; JSON parses')
PY
printf '{}\n' | python3 tools/dashboard_hook.py
python3 tools/build_dashboard.py --check
```

Run the direct hook twice and compare the HTML modification time to verify the
generator's unchanged-pass contract. Configuration checks and direct execution
do not prove a previously running agent has loaded the hook: check delivery after
restart separately. A missing generator must fail visibly rather than report a successful refresh.
