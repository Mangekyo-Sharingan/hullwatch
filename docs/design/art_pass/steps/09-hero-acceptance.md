# 09 — Verify and review the hero pair

## Objective

Produce evidence that the cockpit and quarters establish the requested style and retain working gameplay. Requires 08. This packet is verification and reporting; do not quietly redesign during review.

## Owned files

`game/tools/capture_screenshots.gd` for missing review angles only; focused tests if a genuinely uncovered regression needs a check; `docs/design/art_pass/hero_review.md`; final capture artifacts; `.wolf/STATUS.md`. Changes discovered in generators/materials go back to the owning implementation packet, then verification is repeated.

## Procedure

1. Record exact source commit/worktree diff and relevant resource hashes. Review the geometry/lighting changes against the approved target and the shared rubric. Confirm the provisional test error from 01 is gone.
2. Import, regenerate affected scenes and prove byte-for-byte deterministic second generation. Do not hand-edit generated files or tolerate unexpected resource missing messages.
3. Run every current headless test and smoke using isolated user data, preserving logs/results. Compute the current suite count. Require actual PASS markers and inspect all new native errors as well as script errors. Intentional error fixtures are not a reason to ignore unrelated errors.
4. Exercise real traversal/reattachment, seated station use, blade focus/stow, pressure hatch movement, breaker lights and adjoining pod access. Include important animated states in screenshots or a short original recording.
5. Capture approach, seated front/port/starboard, utility close-up, quarters aisle/bunk/dock and lights-off/torch states. Use existing normal lighting and unchanged filter. Hide overlays only for clearly identified presentation shots; keep gameplay shots too.
6. Run scene/simulation profiles as applicable and record their limitations. If actual rendered timings are available, use the same hardware/settings and an unmodified baseline for comparison. No invented FPS target or claim of Windows verification.
7. Write a six-row rubric review with visible evidence. Label accepted items, remaining defects and stylistic questions. Supply a bounded correction list instead of a generic 'needs polish' statement.

## Acceptance and review boundary

All technical guards pass and the final images reflect the tested diff. The hero is ready to show the operator; operator acceptance is not implied by test success. 10's rollout requires an accepted style baseline, so do not automatically spread an unresolved look through every room.

## Handoff

Return exact test results, artifact links, known limitations and correction owners. Update status with which hero elements are actually complete. Stop after the evidence packet; no release upload in this step.
