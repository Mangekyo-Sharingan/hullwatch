# Steam Deck playtest delivery — October 13

Latest package includes the startup checker: [Deck20261013.2](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-steamdeck-playtest.20261013.2); see [current validation/delivery](../update_checker/README.md). The original port checkpoint below remains historical.

[Download the native playtest](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-steamdeck-playtest.20261013.1) · [Setup and controls](../../STEAM_DECK_PLAYTEST.md)

Delivered on the separate `playtest/steamdeck` branch; game source
`1876691958392f93556a5332f49d33728f9cedc1`, based on main `9c1ea7a` and Windows
playtest `20261013.2`. Same game content and global save schema v8. The release
contains `Hullwatch-SteamDeck.tar.gz`, archive `SHA256SUMS` and `VALIDATION.json`.
Independent downloads match all three local artifacts; package identity,
executable modes and all internal hashes passed again after download.

## Launch

One-time Non-Steam import and manual Steam Input keyboard/mouse mapping are
required. After setup, one Play press in Deck Game Mode or Linux Big Picture
runs the native executable with 1280×800, fullscreen, Mobile Vulkan and a 30 FPS
cap. No editor, Python, Proton or per-launch terminal setup is required.
The bundled README documents transfer, import, complete bindings, saves,
updates, troubleshooting and the hardware checklist. Actual Steam integration
is pending; launcher mechanics were checked separately on the Linux host.

## Changes

The Deck export has its own viewport overrides and export preset. Long manual
pages wrap and scroll; manual and terminal readouts support Page Up/Down; guide
tips draw below menus. The launcher handles relocation, spaces and an unrelated
working directory. The builder records clean committed source identity and
ships an embedded native ELF with complete file checksums. Windows presets,
simulation and the save format retain their existing behavior.

## Current checks

- Independent source: **93/93 PASS**, exit 0, exact suite markers and no script
  errors. See [source results](full_suite_results.json).
- Actual exported project: **15/15 PASS**, including startup, Deck UI,
  lighting, power, terminal controls, save migration, interior gate, traversal,
  salvage, session flow, mining, sector and module/fitting/effects checks.
- Matching editor renders **22** exported-project inspection views at 1280×800
  with Wayland/Mobile. Main menu, lighting and the long EVA manual page were
  reviewed and copied here. Bounds fixtures pause simulation; this is not an
  uninterrupted human playthrough.
- Actual release ELF starts headless and with the default launcher profile,
  renders 12 menu movie frames in a window, and exits 0. These runs use an
  extracted archive in a folder with spaces, launched from `/`.
- Package selfcheck passes ELF64/x86_64, modes, complete hashes, relocated
  launcher argument forwarding and working-directory handling.
- Published assets downloaded independently: hashes, source and save version
  confirmed. Exact evidence: [validation](validation.json), [delivery](delivery.json).

The release template disables `--script`: exported-project tests use the
matching editor with `--main-pack` pointing at the actual ELF from an empty
project. Native release startup and rendering are checked separately.
Existing eight ObjectDB shutdown warnings persist. Movie capture timestamps
are not sustained gameplay FPS measurements.

## Open review and historical limits

**Actual Steam client and Deck hardware testing remains open:** Non-Steam
import, Game Mode/Big Picture integration, Steam Input comfort, sustained FPS,
lighting comparison and suspend/resume. There is no Deck Verified claim.
The roadmap marks implementation and delivery complete, hardware review pending.
All sub-agents are closed; the branch remains separate from main.

Earlier Mobile clipping failures and uncommitted packages are historical.
Some early sidecar checks used default userdata; `test_ui_scale` removes
`settings.cfg`, and original config presence is unknown. No speculative
restoration was performed. Final builds and all independent parent checks use
isolated userdata; do not infer early runs preserved original preferences.
