# Windows playtest — 2026-10-01

[Download Hullwatch-Windows.zip](Hullwatch-Windows.zip), extract it and run `Hullwatch.exe`.
The executable is self-contained. The zip is stored with Git LFS; use the GitHub file download button or `git lfs pull` in a checkout.

Source checkpoint: `6c472eb65e4e795467512feec15d2562f02f4eb3`. The later ship art pass is not included.

Movement: WASD, Space/Ctrl up/down, Shift brake, Z/C roll, Q land/release boots. E interact, F torch, T tether, X leave seat, Esc pause.

Built with the local Godot 4.7.2 Linux engine and Windows Desktop release template (the same import/export operations as `build.ps1`). 88/88 source suites pass. The executable's embedded project passes player/menu checks and startup using the matching Linux engine. Native Windows execution remains unverified.

Zip SHA-256: `175ffba1e1388a31c43d265366297800ad62c1366eff3491cfec026aaf508237`. Executable SHA-256: `0646f356048d80bb6ec917561b3e804e431bf08844da6cb5baed0291802ba45f`.
