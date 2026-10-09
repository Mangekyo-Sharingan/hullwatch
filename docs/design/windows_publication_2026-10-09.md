# Windows publication — 2026-10-09

## Delivered checkpoint

Operator authorized pushing the current game and a shareable Windows executable.
Source commit: `c982415bceb44b97cc139817c0b0ca518d97134e`.
Package commit: `48b01aab70e6e8d3fb2b244443ed9c23d3ced4e0`.
Both are on `origin/feat/starpath-art-pass-2026-10-01`.

[Windows downloads and instructions](../../releases/windows/2026-10-09/README.md).
The standalone EXE and ZIP are hosted in the repository with Git LFS. No GitHub
Release page was created: this host has SSH/LFS access but no API login.
Anonymous repository/download requests return 404; recipients require repository
access. The full internal documentation dashboard remains local.

## Contents and validation

The build contains the movement/menu improvements, current ship art pass and
common salvage prototype with a provisional auxiliary battery. It uses v5 saves
with supported older-save migration. This is a dated development playtest; the
PE version remains 0.11.0 and the description identifies October 9.

- Fresh source suite: **90/90**, exit 0 with exact PASS for every suite.
- Matching committed source fingerprint verified against the fresh test report:
  `docs/design/windows_playtest_2026-10-09_results.json`.
- Windows release cross-export succeeded using installed Godot 4.7.2 templates.
  The Linux import retained the known editor popup-parent warning family;
  export/test cleanup retained known renderer/resource shutdown warnings.
- Extracted the pack from the actual EXE, then used an empty project directory:
  startup, `test_salvage`, `test_player_traversal`, `test_session_flow`, and
  `test_hero_cabins` passed using the matching Linux engine.
- ZIP integrity and contained EXE hash match the export. `SHA256SUMS` records
  both downloadable files. GitHub's branch head and LFS pointer hashes match.
- A fresh SSH clone downloaded both files from GitHub after `git lfs install
  --local` and `git lfs pull`; both published-file SHA-256 checks returned OK.

Native Windows execution and a continuous human EVA playthrough remain unverified.
The last recorded simulation profile is still over budget: 201.0 µs/tick versus
200. Alpha content, broad resource sustainability, global persistence and the
first salvage technology choice remain open.

## Source freeze and concurrent work

Unrelated menu/settings/sector and playtest-readiness edits appeared after the
source freeze. They were preserved in the working tree and excluded from this
package. The published EXE is explicitly pinned to `c982415`, with an identical
committed fingerprint to its fresh validation. Do not describe later working-tree
changes as included without a new export and validation.

## File scope

Committed game sources, generated scenes, original Blender art, pass plans,
review evidence and authored dashboard tooling. Machine-local agent state,
settings, caches, reference material, engine binaries and the generated dashboard
were excluded. Nothing was merged into `main`; the feature branch is published.
