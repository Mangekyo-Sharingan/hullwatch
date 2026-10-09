# 12 — Final evidence and an optional authorized art release

## Objective

Close the art pass with honest whole-ship verification. Requires interior room packets and exterior pass complete. The current art-pass authorization covers source work, validation and review artifacts. **Publication/export for a new art release remains conditional on a separate explicit release request.**

## Owned files

Validation/review docs and the necessary runner/capture tooling. Release presets, release package/checksum/docs and git publication only when this packet is invoked with that authorization. Do not blanket-stage local agent configuration or frozen unrelated files.

## Procedure — verification first

1. Record all commits, outstanding modifications and accepted room/exterior artifacts. Reconcile them with the original target: which reference goals are met, which remain, and which changes were intentionally omitted.
2. Run import, both scene builders, a second deterministic generation comparison, startup smoke and every current suite. Save exact logs/results and reject new native/script faults. Keep intentional fixture errors and inherited shutdown warnings documented.
3. Exercise a complete work cycle: read a watch report, inspect/diagnose/refit, traverse the ship, use cockpit controls, travel, cycle airlock, reach exterior hardware, return and save/load. Verify art has not moved/hidden those functions. Check rolled movement recovery and seated interaction again.
4. Render final whole-ship and maintenance views with actual scene lighting, ordinary settings and preserved filter. Include relevant open/closed/powered/unpowered states. Record real rendered performance if available, plus headless profile limitations.
5. Prepare a concrete review report: accepted rubric, exact changed resources, failures/warnings, platform coverage and remaining work. An incomplete room or unverified platform must not be described as complete.

## Optional release — only when requested

1. Commit the reviewed source on the intended art branch. Do not amend or replace the published movement checkpoint or silently overwrite its zip.
2. Windows host: run `build.ps1` with the configured local engine. Linux host: use the equivalent import and Windows Desktop release export with an absolute output path. Record the tool/template version and source commit.
3. Check PE x86-64 output, byte identity/zip CRC and hashes. Exercise menu/player/startup against the embedded exported pack using the matching engine. These checks establish packaged content, not native Windows execution.
4. Execute the exe on Windows if that environment is available. Record startup, new/load/save/pause, movement and representative art interactions. Otherwise mark native Windows runtime unverified prominently.
5. Produce a uniquely named dated/art package, README with controls/source commit and SHA256SUMS. Use GitHub release assets when authenticated; the previous package used a branch Git LFS zip because release credentials were absent. Verify whichever publication path is actually used and report its real download link.
6. Push only authorized reviewed commits/artifacts; verify remote commit and LFS objects. Never claim that a local commit or export was published.

## Acceptance and final handoff

Source, generated geometry, tested state and exported build agree. All current suites have real PASS evidence and visual review is complete for the claimed scope. Report exact commits/download links only if actually created/pushed. Update status/memory and list any remaining operator/platform review. Stop after the requested verification or release scope.
