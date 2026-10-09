# Windows playtest — 2026-10-09

[Download Hullwatch.exe](https://github.com/Mangekyo-Sharingan/hullwatch/raw/refs/heads/feat/starpath-art-pass-2026-10-01/releases/windows/2026-10-09/Hullwatch.exe) or [Hullwatch-Windows.zip](https://github.com/Mangekyo-Sharingan/hullwatch/raw/refs/heads/feat/starpath-art-pass-2026-10-01/releases/windows/2026-10-09/Hullwatch-Windows.zip).

Run `Hullwatch.exe` directly, or extract the ZIP and run it. The executable contains the game data; no Godot installation is needed. Windows x64, Vulkan-capable GPU (Forward+ renderer).

Source checkpoint: `c982415bceb44b97cc139817c0b0ca518d97134e`. Includes movement/menu improvements, the current ship art pass and the useful-salvage prototype (provisional auxiliary battery). Existing tagged version metadata remains 0.11.0; this dated package is a newer development playtest.

Controls: WASD move/thrust; Space push/up; Ctrl crouch/down; Shift brake; Z/C roll; Q release boots/land; E interact; F torch; T tether; X leave seat; Esc pause.

Salvage: approach a debris contact, isolate its recovery supply, release the case with a wrench, carry it to the hull cargo port, then use a pod socket to diagnose with a multimeter, repair with a wrench and metal, fit it, or scrap it. Fitted batteries add storage capacity, not power generation or free charge.

Save format v5, with migration from older supported saves. Back up existing saves before trying this development build.

Validation: 90/90 fresh source suites passed. The executable's extracted embedded project passed startup, salvage, movement, menu/save flow and hero art checks using the matching Linux engine. Cross-exported with Godot 4.7.2 Windows release templates; native Windows execution and continuous manual EVA playthrough remain unverified. The last simulation profile remains slightly over budget (201.0 µs/tick vs 200).

Files are stored with Git LFS. GitHub's download links serve the real binaries; a source checkout requires `git lfs pull`. Checksums are in `SHA256SUMS`.
