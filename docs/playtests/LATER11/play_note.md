# LATER.11 — native gamepad support and default controls

2026-10-16. Requested by the operator in-session; it is **not** one of EA01–EA12, though it overlaps the planned EA10 (Deck controls and key rebinding) and does not change the slice list. Agent verification only: **operator review is pending**, and no real gamepad, Steam Deck or Windows machine was used.

Decisions taken with the operator: native gamepad support in the game (not a Steam Input layout file), prompts that switch to button names when a gamepad was last used, built on `main` and then merged into `playtest/steamdeck`.

## What it does

Before this, the game ignored gamepads entirely: every action was keyboard or mouse, and Steam Deck players had to hand-build about 20 Steam Input bindings to keyboard and mouse. The game now reads the pad directly, so Steam's default gamepad setup works with no configuration.

|Control|Action|
|---|---|
|Left stick|Move; free-flight thrust|
|Right stick|Look (same turn as the mouse, scaled by the renamed LOOK SENSITIVITY setting)|
|A|Interact; confirm a menu row|
|B|Drop the carried item; back out of a menu or readout; decrease a setting|
|X|Flashlight|
|Y|Magnetic boots|
|LB / RB|Crouch or thrust down / jump, push off or thrust up|
|RT|Scanner ping (primary)|
|LT|Drop the carried item (secondary)|
|L3|Brake in free flight; leave the pilot seat|
|View|Tether|
|Menu|Pause; close a readout or settings|
|D-pad up/down|Browse menu rows|
|D-pad left/right|Scroll readout text; roll in free flight|

On-screen hints (HUD, menus, readouts, overlays and the in-game manual) follow the device last used, so `[E] ...` becomes `[A] ...` on a pad and returns when a key is pressed. On a Steam Deck (environment `SteamDeck=1`) they start on pad names. Keyboard and mouse bindings are unchanged.

## Verified

- **Engine input path, synthetic gamepad events (no hardware):** a throwaway driver sent only joypad events through `Input.parse_input_event`. NEW WATCH started with D-pad and A. The left stick walked 2 m. The right stick turned and aimed. D-pad right scrolled a readout, D-pad down moved the highlighted row, A confirmed it without closing the readout, and B closed it **without dropping the wrench in hand**. One LT squeeze dropped the wrench once. Menu opened the pause menu and B backed out. A key press switched the hints back to the keyboard. Captures: [route sheet](gamepad_route_sheet.png), [menu on gamepad](menu_gamepad_hints.png) and [on keyboard](menu_keyboard_hints.png), [readout on gamepad](readout_gamepad_hints.png).
- **Full sweep:** startup, smoke and 97 existing suites, **99/99 passed**. Existing tests that pin keyboard hint text still pass, so keyboard wording is unchanged.
- New regression checks in existing suites: one trigger squeeze is one press; A never closes a readout while B and Menu do; hints switch with the device; 14 key actions have a gamepad binding; stick look turns the right way and keeps its pitch limit.
- Tool pickup by ray is unchanged by the model revamp: rays at all six tools from five standing positions hit the same targets on the old and new models.

## Found on the way

- **Godot's built-in `ui_accept` has no gamepad button in this build** (Enter, Keypad Enter and Space only), so A would never have confirmed a menu row. The game's own `menu_select` action, which every menu already checks, now carries A.
- **A trigger is an analog axis, and one squeeze produced five "pressed" events**, which would have pinged the scanner five times. `InputEdge.fresh` now treats a squeeze as one press; the left stick navigating menus uses it too.
- **A and B each had two jobs.** A both confirms a row and is Interact; B both closes a readout and drops a tool. While any menu is open the player now ignores gamepad buttons, and a readout closes on B or Menu but not on A.
- **Bindings were created for device 0 only**, which would have ignored a second controller. They are now for all devices.

## Limits

- **Not tested on a real pad, a Steam Deck, Steam Input or Windows.** Synthetic events prove the game's logic and the Input Map, not the Deck's own controller layer, dead zones or stick feel. The look speed (about 160° per second at full push) and the 0.25 dead zone are starting values to tune by hand.
- **Deck rear grips, trackpads and gyro are unused.** They emit nothing in the default gamepad layout.
- **Tool pickup next to the hull wall** works along the corridor but is easy to miss on a diagonal approach from the shelving side. That is existing geometry, unchanged here.
- **Prompts name Xbox-style buttons** (A/B/X/Y, LB/RB, LT/RT). Steam shows L1/R1 on the Deck; PlayStation pads would still read as A/B.
- **No key rebinding** (EA10.3 remains planned).
- The Steam Deck guide `docs/STEAM_DECK_PLAYTEST.md` still describes manual Steam Input setup; it lives on the Deck branch and is updated there.
