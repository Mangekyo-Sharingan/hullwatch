# Hullwatch v0.7.0 — early test build

Playable Windows test build from the post-M6 expansion: the cramped-station art
pass, diagnostics, comms, and the fixes from the v0.6.0 playtest round.
This is still a **pre-playtest build of the current content** — expect rough edges.

## What's new since v0.6.0
- **A rebuilt ship.** The greybox freighter is now a cramped eight-space faceted interior with a canted, ribbed corridor and seamless "xenon-metal" structure — grown, not welded. Read log 02 for the survey note.
- **Analogue-horror look.** A film-grain filter (scanlines, vignette, scratches, breathing brightness) with a toggle and intensity slider in settings, plus CRT phosphor screens on every readout.
- **Diagnostics: information is a tool.** Components can fail silently. The status panel shows `FAULT (UNDIAGNOSED)` and wear as `--` until you investigate: carry the **multimeter** to a glowing probe to identify a failure mode, the **scanner** to log wear percentages, and mind the **wrench** — the scrubber housing will not open without it. Tools and probes are explained on the new DIAGNOSTICS manual page.
- **Comms.** The cockpit terminal has an inbox and two sendable drafts. Traffic arrives on ship days; replies take weeks; one report is simply never acknowledged, and the rotation query gets its answer on day 11.
- **Playtest fixes (from the v0.6.0 round).** Every readout now closes with **E or Esc from anywhere** (no more getting stranded in the manual), scans/diagnoses/refusals print a HUD line with a beep, component failures and new comms traffic announce themselves, and the probe prompt tells you which tool you are carrying.
- Manual is now eight pages (operations, power, life support, thermal, damage control, symptoms, diagnostics, comms).
- Ten real in-game screenshots in `docs/store/` replace the placeholder cards.

## How to play
Run `Hullwatch.exe` (Windows x64, single file, PCK embedded).
Controls are on the first page of the in-game manual (E at the binder).
Esc opens settings; E or Esc also closes any open readout.
Saves live in `%APPDATA%\Godot\app_userdata\Hullwatch\saves\`.

## Known gaps (honest list)
- No external playtest of this content yet — the v0.6.0 feedback round produced the fixes above, but that build predated diagnostics and comms.
- Art is CC0 textures + kit props on generated geometry; real key art is not made.
- Sleep fast-forward causes a brief (~0.6 s) hitch behind the fade.
- Carried-item position is not persisted (items return to spawn after load).
- Balance across a full 3-day session on real hardware is still pending.
