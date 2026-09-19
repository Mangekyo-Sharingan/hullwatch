# Shipping Checklist

State as of the v0.10.0 test build — items marked TODO are honest gaps, not paperwork.

## Build pipeline
- [x] `build.ps1` produces a single-file Windows build (`build/windows/Hullwatch.exe`, PCK embedded)
- [x] Export presets committed (`game/export_presets.cfg`, release + debug)
- [x] Export templates documented (Godot 4.7.2 stable; installed locally)
- [x] Exported build boots clean headless (exit 0)
- [x] Application icon (generated `game/icon.png`, wired into project + export presets)
- [ ] Code signing (not needed until public release)
- [ ] Installer / installer branding

## Game content
- [x] Playable loop: walk, repair, sleep, stabilize, travel legs
- [x] 8 ship spaces, 5 procedures, wear + failures, cascades, save/load
- [x] Carry/pickup system (procedures + diagnostic tools)
- [x] Food/hunger (ration stores wired into vitals)
- [x] Humidity/condensation model with cascades
- [x] Diagnostics: tools gate fault modes and wear readouts (spec §4.3)
- [x] Comms narrative: latency, unread traffic, the late reply (spec §4.1/§5)
- [x] Win state (final waypoint) + loss states with mercy recovery
- [ ] External playtest of current content (spec §8.5 success test: manual-only survival) — v0.6.0 round returned; v0.7.0-v0.10.0 rounds pending
- [ ] Balance pass across a full 3-day session on real hardware

## Technical
- [x] 44 headless suites green; runtime clean
- [x] Versioned saves with migration (v1 → v2) + migration tests
- [x] Settings persisted (ConfigFile) with validated ranges
- [x] Localization prep: 44 extracted strings, CSV translation registered
- [x] Sim + scene profilers (`tools/profile_sim.gd` 128 µs/tick, `tools/profile_scene.gd` 0.81 ms/frame scene cost)
- [ ] Performance validation on mid-range hardware (profilers exist; real GPU run pending)
- [ ] Accessibility pass beyond settings (subtitles do not exist yet — most audio is diagnostic)

## Legal / credits
- [x] Asset credits recorded (`docs/ASSET_CREDITS.md`), all CC0
- [x] Engine license: Godot 4.7.2 (MIT) — no attribution required in-game
- [ ] EULA / privacy policy if store-required
- [ ] Third-party notices page in-game (nice-to-have)

## Store
- [x] Draft store copy (`docs/STORE_PAGE.md`)
- [x] Capsule set (`docs/store/capsule_*.png`)
- [x] Real in-game screenshots (`docs/store/screenshot_01..10.png`)
- [ ] Real key art (capsules are still generated)
- [ ] Steamworks (or itch.io) account + depot configuration
- [x] Public GitHub releases with test builds attached (`v0.6.0` through `v0.10.0`)
