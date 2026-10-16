# Hullwatch native Linux / Steam Deck playtest

This is a **native Linux x86_64 playtest**, using the same game content and v8
save schema as the October 13 survival build. The game reads the controller
directly with a default layout and on-screen button prompts, so **no manual
Steam Input configuration is needed**. There is no Steam Deck hardware result
or Deck Verified certification; Deck performance, control comfort and
suspend/resume are pending.

The launcher requests **1280×800, fullscreen, Mobile Vulkan, maximum 30 FPS**.
A frame cap is a target, not proof that the Deck sustains it. Existing analogue
filter defaults are preserved; UI scale, mouse sensitivity and filter strength
remain adjustable in SETTINGS. Mobile supports desktop Vulkan with fewer
rendering features than Forward+; compare lighting on hardware before settling
on a profile. [Godot renderer documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

## 1. Get the native package

Download **Hullwatch-SteamDeck.tar.gz** and its adjacent **SHA256SUMS** from
[the Steam Deck playtest release](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-steamdeck-playtest.20261013.4). The Windows October 13
release's EXE/ZIP is a different package. Do not rename or launch its EXE for
this native test. The branch is `playtest/steamdeck`; the dated release identifies the exact source.

Alternatively build on a Linux development machine with Git LFS assets checked
out, Python 3, Godot **4.7.2 stable editor**, and matching **4.7.2.stable export
templates** installed. The engine's template directory normally is
`~/.local/share/godot/export_templates/4.7.2.stable/` (or beneath an overridden
XDG data directory). It must include `linux_release.x86_64`.
[Godot Linux export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_linux.html)

From the isolated `playtest/steamdeck` checkout:

```sh
python3 tools/build_steam_deck.py --engine /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 --release-tag v0.12.0-steamdeck-playtest.20261013.4
```

On the current developer host the exact command is:

```sh
python3 tools/build_steam_deck.py --engine /home/uru/Projekt/OperationSpacer/Engine/Godot_v4.7.2-stable_linux.x86_64 --release-tag v0.12.0-steamdeck-playtest.20261013.4
```

The build uses temporary XDG userdata for Godot import/export and links the
installed template directory there; it does not use your watch saves/settings.
One invocation imports the project, exports the release ELF with embedded game
pack, creates the launcher and guide, records source identity, checks hashes,
execute bits and launcher relocation, and writes:

```text
build/steamdeck/
  Hullwatch-SteamDeck.tar.gz
  SHA256SUMS                       archive checksum
  Hullwatch-SteamDeck/
    Hullwatch.x86_64               native ELF64, embedded game pack
    Hullwatch.sh                   portable launcher
    README.md                     this guide
    SOURCE_COMMIT                  full Git base commit
    BUILD_INFO.json                engine, dirty paths, save schema/profile
    SHA256SUMS                     checksums of package files
```

Rebuild after committing for a delivery tied to one source revision.
`BUILD_INFO.json` reports uncommitted source paths for development builds;
`SOURCE_COMMIT` alone does not describe their changes. The command is repeatable,
but archive bytes are not guaranteed identical across builds (timestamps and
Godot export metadata). Windows presets and the global project renderer are
unchanged. The Linux preset alone supplies the `steam_deck` feature tag, whose
viewport overrides are 1280×800. No Steam SDK, Proton, Godot editor or Python is required on the Deck
when using the finished package.

## 2. Copy and extract in Desktop Mode

1. On the Deck, open the Steam menu, choose Power → Switch to Desktop. Keep Steam
   running for Steam Input. Valve documents Desktop Mode in its
   [SteamOS FAQ](https://help.steampowered.com/en/faqs/view/69E3-14AF-9764-4C28).
2. Transfer the archive and adjacent checksum file to `Downloads` using a USB
   drive, local network transfer or the browser. In Dolphin create
   `/home/deck/Games`. For this guide use internal storage; an SD card is also
   possible but its actual mount path and execute permission must be checked.
3. Open Konsole and verify/extract using these commands:

   ```sh
   cd /home/deck/Downloads
   sha256sum -c SHA256SUMS
   mkdir -p /home/deck/Games
   tar -xzf Hullwatch-SteamDeck.tar.gz -C /home/deck/Games
   cd /home/deck/Games/Hullwatch-SteamDeck
   chmod +x Hullwatch.sh Hullwatch.x86_64
   sha256sum -c SHA256SUMS
   ```

   Both checksum checks should say `OK`. If the outer checksum file lists other
   assets, use the line for this archive. For an update, quit the running game,
   rename the previous game folder, and extract into a fresh folder. Saves live
   elsewhere and are not overwritten by extraction.
4. First launch from Konsole in a window:

   ```sh
   ./Hullwatch.sh --windowed
   ```

   Confirm the menu, text and sound appear. Use the trackpad and left click to
   choose SETTINGS if needed, then quit normally. The gamepad layout applies in
   Game Mode through the Steam shortcut below. On-screen keyboard: Steam + X.
   No system write protection changes or `sudo` dependency installs are needed.

## 3. Add the Steam shortcut

In Desktop Steam choose **Games → Add a Non-Steam Game to My Library → Browse**,
select `/home/deck/Games/Hullwatch-SteamDeck/Hullwatch.sh`, and add it. If the
picker filters out shell scripts, choose all files. Rename the shortcut
**Hullwatch — Linux Playtest**, then open Properties → Shortcut:

| Field | Exact value for the guide's install location |
|---|---|
| Target | `"/home/deck/Games/Hullwatch-SteamDeck/Hullwatch.sh"` |
| Start In | `"/home/deck/Games/Hullwatch-SteamDeck"` |
| Launch Options | Leave empty for the default profile |
| Compatibility | Leave **Force the use of a specific Steam Play compatibility tool** unchecked |

Keep Target and Start In aligned if you move the folder. Target is the launcher,
not the archive, Windows EXE or source project. Do not add `%command%` to ordinary
launcher arguments. The launcher changes into its own directory and uses an
absolute ELF path, so it also works from folders with spaces.

Valve documents adding a Desktop application to Steam and finding it under
Non-Steam in Game Mode in its
[Desktop FAQ](https://help.steampowered.com/en/faqs/view/671A-4453-E8D2-323C).

## 4. Controls

The game reads the Deck's controller itself, so Steam's default **Gamepad**
layout for the shortcut works as-is. Do **not** switch the shortcut to the
Keyboard (WASD) and Mouse template: it would send keys the game no longer needs
and hide the button prompts. The trackpads still act as a mouse in menus.

On a Deck the on-screen hints start on button names (A, B, LB, RT) and switch to
key names if you press a key.

| Deck control | Game use |
|---|---|
| Left stick | Walk; free-flight thrust |
| Right stick | Look, including while seated (speed follows LOOK SENSITIVITY in SETTINGS) |
| A | Interact with the aimed object; confirm the highlighted menu row |
| B | Back out of a menu or readout; drop the carried item when nothing is open |
| X | Flashlight |
| Y | Toggle magnetic boots near a surface |
| LB / RB | Crouch or thrust down / jump, push off or thrust up |
| RT | Scanner ping while carrying the scanner |
| LT | Drop the carried item; decrease the highlighted setting |
| Left stick click (L3) | Brake in free flight; leave the pilot chair |
| View button | Release the tether, or reattach when in range |
| Menu button | Pause; close a readout or settings |
| D-pad up / down | Move through menu rows and manual pages |
| D-pad left / right | Scroll a long readout; hold for roll in free flight |

The rear grips, trackpad clicks and gyro are not used by default.

### World interaction and menus

- **A** opens a door, terminal, manual, service panel, locker, cargo port,
  fabrication panel, dock plate or machine socket when aimed at it. It picks up
  tools and containers, deploys the pilot chair, eats rations and operates the
  bunk. Follow the displayed prompt for repeated maintenance steps.
- With a menu or readout open, **D-pad up/down** moves the highlight, **A**
  confirms the row, and **B** or **Menu** closes it. A never closes a readout,
  and B closing a readout does not drop what you are carrying.
- In SETTINGS, **A** increases or toggles the highlighted value; **LT or B**
  decreases it; **Menu** closes it. UI scale defaults to 1.0. Test higher values
  at 1280×800 before keeping them; the largest pages may need the default scale.
- Multimeter and wear scanner: pick up with A, aim at the test probe and press
  A. The scanner's separate field ping is **RT** while carrying it.
- Cutter: **A** takes it and clips it to the suit, leaving the carry slot free
  for a sample canister. Take an empty canister, approach a mineable contact and
  **A** operates extraction. Mining is not triggered by RT. Cargo-port **A**
  unloads the carried canister. **LT or B** drops carried objects.
- Repairs: carry the required tool, isolate/power down through the controls,
  then use **A** on each prompted step. Probe and drive service menus use
  **D-pad** and **A** for choices. Sealant must be carried when applying it.
- Navigation: sit with A, aim at the nav console, open with A; browse STAR
  CHART or SENSOR CONTACTS and confirm routes/approach/drift with A. Read costs
  and refusal messages. **L3** stands up.
- EVA: wear the suit, use the airlock panel and hatches in the safe order,
  check pressure, boots and tether HUD. RB and LB provide vertical thrust; L3
  brakes. The View button can release a safety tether, so use it deliberately.
- For long terminal and manual readouts use **D-pad left/right**. The manual's
  D-pad up/down changes pages; A records a page read. Save, load, new watch and
  quit are ordinary main/pause menu choices; there are no save hotkeys.

Look speed and stick dead zones are first values, set without a Deck in hand.
Adjust LOOK SENSITIVITY in SETTINGS and report anything that feels too fast,
slow or drifts when the stick is released.

## 5. Launch with one Play press in Game Mode or Big Picture

Use the Desktop **Return to Gaming Mode** shortcut. Find Hullwatch under
Library → Non-Steam, confirm the default Gamepad layout is selected, and launch.
After the one-time import and layout setup, **press Play once**. The shipped
launcher starts the native ELF directly with all defaults; it has no prompts,
downloads, editor, terminal steps or Python runtime requirement. Quit through
the game menu to return to Steam.

On a Linux PC, enter Steam **Big Picture Mode**, open Library → Non-Steam, select
the same shortcut and press Play. The setup and Target/Start In/Launch Options
are identical. This is a Linux package; Windows Big Picture cannot run its ELF.
Any gamepad with the standard Xbox-style buttons uses the same layout, with
Steam showing L1/R1/L2/R2 where this guide says LB/RB/LT/RT. Steam integration
on an actual Deck and Big Picture client still requires the hardware/client
check below.

The launcher requests fullscreen 1280×800 without forcing a display backend;
Gamescope/SteamOS selects its display environment. Initial shader compilation
may cause a longer first launch. Do not infer a hang from that alone.

Start with the Deck's normal power settings and a 30 FPS cap. Record frame time,
watts and readability on the real device before reducing TDP or rendering
resolution. If Steam's overlay cap is also enabled, use matching limits.

## 6. Saves, backups, screenshots and logs

Godot's native Linux `user://` location for this project is normally
`/home/deck/.local/share/godot/app_userdata/Hullwatch/`. If `XDG_DATA_HOME` is
set, it is under `$XDG_DATA_HOME/godot/app_userdata/Hullwatch/` instead.
[Godot user data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

| File/folder under `Hullwatch/` | Purpose |
|---|---|
| `saves/slot_1.json` through `slot_3.json` | Watch saves, schema v8 |
| `settings.cfg` | UI scale, mouse/audio/filter and encounter preferences |
| `logs/godot.log` | Default engine log; retain immediately after a failure |
| `captures/` | Developer capture output, if a capture script was run |

Before updating or testing an old save, quit the game and back up the whole
userdata folder in Dolphin, or run:

```sh
mkdir -p /home/deck/Documents/Hullwatch-backups
tar -czf "/home/deck/Documents/Hullwatch-backups/userdata-$(date +%Y%m%d-%H%M%S).tar.gz" \
  -C /home/deck/.local/share/godot/app_userdata Hullwatch
```

Restore with the game closed. Native Linux saves are not in a Proton prefix.
This Non-Steam package has no Steam Cloud integration. Windows saves from the
v8 build may be copied into `saves/` after a backup; preserve slot filenames and
verify loading. Schema parity does not mean every cross-platform workflow has
been checked on Deck. Do not load a v8 save in an older build.

For screenshots use **Steam + R1**; manage them through Steam's screenshot/media
UI. No screenshot key is implemented by this port. Export the images with the
report. For a retained diagnostic log, put this in shortcut Launch Options:

```text
--log-file /home/deck/Documents/hullwatch-deck.log --verbose
```

Or run from Konsole:

```sh
cd /home/deck/Games/Hullwatch-SteamDeck
./Hullwatch.sh --windowed --verbose --log-file /home/deck/Documents/hullwatch-deck.log
```

Attach that log, `SOURCE_COMMIT`, `BUILD_INFO.json`, controller layout screenshots,
Deck model, SteamOS version, renderer, power/cap settings and the exact failing
interaction. Back up private saves before sharing them.

## 7. Troubleshooting

| Symptom | Action |
|---|---|
| Permission denied / nothing launches | Recheck both `chmod +x` bits and quoted Target/Start In; extract onto internal storage if a removable drive forbids execution. Run from Konsole to see the error. |
| Wrong app / Proton opens | Target must be `Hullwatch.sh`; uncheck forced Steam Play compatibility. |
| Sticks/buttons do nothing | Keep Steam Input enabled with the default **Gamepad** layout, not Keyboard (WASD) and Mouse. Launch through Steam. |
| A closes or does nothing in a menu | A confirms the highlighted row; B or Menu closes. If the layout was changed to keyboard/mouse, restore the default Gamepad layout. |
| Prompts show keys instead of buttons | Press any controller button once; hints follow the last device used. |
| Cannot see lower readout text | Use D-pad left/right; D-pad up/down changes menu rows. |
| Text too small / panel clipped | SETTINGS → UI SCALE; use default 1.0 first, increase cautiously. Lower filter intensity separately if desired. |
| Look too fast or slow | Adjust LOOK SENSITIVITY in SETTINGS. |
| Black window / Vulkan error | Retain verbose log; try `--rendering-method forward_plus` in Launch Options and compare. For driver diagnosis also try `--rendering-method gl_compatibility`, whose lighting may differ and is not the accepted profile. |
| Desktop display-specific failure | Try `--display-driver wayland --windowed` only as a Desktop diagnosis when Wayland is available; do not force Wayland for Game Mode. A developer host's X11 failure is not a Deck result. |
| Frame pacing / battery draw poor | Log measured FPS/frame times/watts first; compare Mobile vs Forward+ at 1280×800. The cap does not guarantee 30 FPS. |
| Settings appear reset after reinstall | Check the userdata/XDG path and user account. Do not delete saves to repair graphics settings; back up then rename only `settings.cfg`. |
| Build fails on missing assets/templates | Fetch Git LFS assets, use the exact editor/template version, inspect import/export output, then rebuild. Do not use pointer files as art. |

Launcher arguments are appended to the defaults. Godot honors the later renderer,
window mode and frame-cap options; for example Launch Options
`--rendering-method forward_plus --max-fps 30` compares Forward+ without changing
source. For Desktop screenshots use `--windowed`. Keep the default 1280×800 for
initial hardware review.
[Godot command-line options](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

## 8. Actual Steam Deck checklist — pending hardware

Record LCD/OLED model, SteamOS/Steam version, internal/SD install path, layout,
renderer, UI scale, filter intensity, frame cap and power settings. Check each
item on the device; host tests cannot close these items.

- [ ] Fresh Desktop install: hashes, execute permissions, first menu and sound.
- [ ] Non-Steam shortcut starts with one Play press in Game Mode/Big Picture
      without Proton, terminal commands or launcher prompts; normal quit returns
      to Steam.
- [ ] Cold launch, repeated launch and shader-compilation behavior.
- [ ] All mapped controls work; simultaneous movement/look/brake and diagonals.
- [ ] Crouch, push-off, upward/downward thrust, both rolls, boots, safe tether toggle.
- [ ] Pilot seating, freelook, console reach, X-key stand-up and hatch traversal.
- [ ] Main/pause/settings pages, slots/confirmation/back, settings plus/minus.
- [ ] Every terminal/readout at 1280×800, long wall readouts and all manual pages;
      inspect SHIP CONTROL/LIGHTING and dynamically installed pod rows too.
- [ ] Tool pickup/drop, multimeter diagnosis, probe wear scan and scanner field ping.
- [ ] Maintenance: breakers/isolation, scrubber steps, reclaimer, patch with sealant,
      exterior drive service, correct HUD feedback and manual readability.
- [ ] Suit/airlock round trip, tethered EVA, cutter plus canister, extraction,
      anomaly salvage and cargo unload.
- [ ] Fabrication, dock build/teardown, pod entry and machine fit/remove menus.
- [ ] Plot route, contacts/approach, resume drift, transit/arrival and normal sleep.
- [ ] Save/quit/relaunch/load plus backup/restore and carried equipment continuity.
- [ ] Suspend/resume at menu, aboard and during EVA; audio/input recovery; verify
      simulation does not jump unexpectedly. Save before each test.
- [ ] 30-minute ship session and EVA: FPS/frame time, stutter, temperatures, watts,
      battery estimate and visual differences for Mobile/Forward+.
- [ ] Readability at normal handheld distance and Steam overlay/screenshot behavior.

Formal Steam hardware compatibility is a separate Valve review. This manual
layout still shows keyboard/mouse prompts and does not establish Verified status.
[Valve compatibility review](https://partner.steamgames.com/doc/steamhardware/compat?l=english)

## Startup update notices

A release-tagged build checks the public GitHub release list once per launch,
with an eight-second timeout. The main menu shows its exact installed version
and offers VIEW UPDATE ON GITHUB when a newer compatible package exists. Steam
Deck and Windows playtests are separate channels; stable releases qualify only
with a compatible package. The link opens the release page for a manual update.
Failed/offline checks leave the game playable. Development builds without
`--release-tag` do not check automatically. This checker first ships in
`v0.12.0-steamdeck-playtest.20261013.4`; earlier archives cannot acquire it
without installing a new build. Back up saves before changing versions.

## In-client manifest updates

This bootstrap package adds DOWNLOAD UPDATE AND RESTART to the main menu when
a newer compatible manifest is available. The update page shows progress and
lets you cancel before installation. Transfers restart from the beginning after
interruption. The updater verifies GitHub's asset digests, manifest, exact size
and SHA256, then replaces the embedded executable through the shipped helper.
Keep Hullwatch.sh and Hullwatch-Updater.sh in place: the existing Steam shortcut
continues to use the same path, and the wrapper owns the child/restart loop.

The previous executable is kept under .hullwatch-update/previous. If an update
was interrupted, the wrapper checks recovery before starting the game. Manual
recovery from Desktop Mode is also available:

```sh
cd /home/deck/Games/Hullwatch-SteamDeck
sh Hullwatch-Updater.sh --recover /home/deck/Games/Hullwatch-SteamDeck/Hullwatch.x86_64
```

Saves/settings are excluded from replacement. Original SOURCE_COMMIT,
BUILD_INFO.json and package SHA256SUMS describe the extracted archive; after
in-client updates, the game’s embedded version/source identity and
.hullwatch-update/installed.json identify the active executable. Earlier
checker-only releases require one manual install of this bootstrap. Actual
Steam/Game Mode restart continuity and physical power-loss review are pending.
