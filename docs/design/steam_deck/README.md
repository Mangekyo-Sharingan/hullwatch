# Steam Deck playtest port — October13

Dedicated sub-agent implementation on isolated `playtest/steamdeck`, based on
main9c1ea7a and Windows playtest20261013.2. Same game content/global save8.
Native Linux x86_64 embedded export, packaged with a relocatable shell launcher,
source identity, checksums and detailed [setup guide](../../STEAM_DECK_PLAYTEST.md).

One-time import as a Non-Steam game and manual Steam Input keyboard/mouse mapping
are required. After setup, one Play press in Game Mode or Linux Big Picture
executes the native ELF with1280x800/fullscreen/Mobile/30FPS-cap defaults; no
terminal/editor/per-launch setup. Default launch and space-containing paths are
checked mechanically; actual Steam client/device integration is a hardware gate.

Port fixes long manual pages spilling below800px, adds PageUp/Down scrolling to
manual/terminal readouts, moves guide tips below menus and applies1280x800 logical
viewport only to the custom SteamDeck export feature. Windows/global renderer,
analogue defaults, simulation and save format stay the same.

Independent parent source **93/93** PASS (exit0/exactmarkers/no script errors).
Agent's final source and exported Mobile profiles render22 inspectionframes at
1280x800; actual releaseELF renders12 menu frames and exits0. The release template
disables --script, so embedded-project suites run using the matching editor on
that actual ELF from an empty directory. Final committed build validation and
published/downloaded hashes will be recorded in validation.json after rebuilding.
No Steam Deck hardware/FPS/comfort/SteamInput/suspend result or Verified claim.

Earlier Mobile clipping failures and uncommitted packages remain historical.
Some early sidecar checks used default userdata; final checks/builds are isolated.
Source inspection found test_ui_scale removes settings.cfg; original config
presence is unknown, so no speculative restoration was performed. Focused suites
used in-memory saves; later full93 are isolated per suite. Do not infer original
local preferences were preserved by those early runs.
