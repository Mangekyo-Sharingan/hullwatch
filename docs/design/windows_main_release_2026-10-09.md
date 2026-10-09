# Merged-main Windows release — 2026-10-09

## Merge verified

GitHub PR #1 is merged and closed. Its head is
`feat/complete-playtest-menu-2026-10-09` (`a4fa6b0`), base `main`, and merge
commit `a194fe299ba840fd1be6b01cc5d521645d310387`. The merge tree matches the
feature branch exactly and contains the art/salvage checkpoint and the latest
menu/settings/route work. Local main was fast-forwarded to that merge.

## Published build

[GitHub Release: v0.12.0-playtest.20261009.1](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261009.1)
was published at 2026-10-09T17:54:22Z, marked prerelease, not draft. Its tag points
to the exact merge commit above. Attached files: `Hullwatch.exe`,
`Hullwatch-Windows.zip`, `SHA256SUMS`, `VALIDATION.json`. The repository is private;
downloads require repository access. The prior v0.11.0 stable release remains
GitHub's Latest stable entry; this development build is listed under Releases.

This is an actual GitHub Release, unlike the earlier repository-hosted
`c982415` package. It includes the newer confirmed Delete Watch, persistent
field/anomaly/planet settings, optional survey-orbit routes and v6 saves
(navigation state v4). The recovered battery remains provisional.
PE version metadata remains 0.11.0; the tag, release notes and SOURCE_COMMIT
inside the ZIP identify the newer development build.

## Fresh validation

- Windows x64 release cross-export succeeded using Godot 4.7.2 templates.
- All **90/90 source suites** passed with exit 0 and exact suite PASS.
- The pack extracted from the actual EXE passed **9/9 checks** in an empty
  project directory: startup, session flow/menu, settings, navigation, save
  migration, salvage, player traversal and hero cabins.
- ZIP integrity passed; its contained EXE matches the exported EXE.
- Assets were uploaded to a draft, downloaded independently from GitHub, then
  verified before publication: EXE, ZIP and validation JSON SHA-256 all OK.
- Published release API confirms draft=false and its tag resolves to the
  merged-main commit.

Detailed evidence: `windows_main_release_2026-10-09_results.json`; the same data
is attached as VALIDATION.json. Known renderer/resource shutdown and editor
popup-parent warning families remain separate from script/test failures.

Native Windows execution, a continuous human maintenance/travel/EVA route and
rendered performance remain unverified. The feature branch's prior sim profile
of 198.6 µs/tick is historical evidence, not a fresh profiler run here. Publishing
a development playtest does not close Alpha content, sustainability, broad
persistence, balance or Early Access readiness gates.

## Operational correction

The earlier source/EXE push did not create a Release entry because this host had
SSH/LFS access without an API login. After the operator's GitHub login became
available, the exact merged-main candidate was published and verified. Source
and build are now explicit; no new PR was created for release bookkeeping.
