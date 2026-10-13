# Manifest full-build updater — October 13

Operator approved an in-client full-build download and restart with integrity
checks, staging, a separate installer, retained previous build and unchanged
save/settings files. Incremental resource/delta patches remain a later pass.

## Contract

Each published release supplies UPDATE_WINDOWS.json or UPDATE_STEAMDECK.json:

```json
{"schema_version":1,"minimum_updater":1,"release_tag":"v0.12.0-playtest.20261013.5","channel":"windows","source_commit":"40 lower-case Git hex characters","payload":{"name":"Hullwatch.exe","url":"exact GitHub repository/tag asset URL","size":123456,"sha256":"64 lower-case hex characters"}}
```

Both manifest and raw executable require uploaded assets and SHA256 digests
from GitHub's authenticated HTTPS API. Manifest bytes must match that digest;
its declared payload size/hash must also match GitHub's asset metadata. Release
selection retains numeric tag ordering and separate platform channels. Stable
releases can supply both platform manifests. The initial asset path is fixed;
redirects are limited to HTTPS GitHub/asset-CDN hosts, with no credentials or
nonstandard ports. No GitHub token ships in the game. Repository access remains
the publishing authority; this version has no separate signing key.

## Player flow

The main menu offers DOWNLOAD UPDATE AND RESTART after a valid newer manifest.
Its update page shows transfer percentage, verification and restart status,
with cancellation during download/verification. Escape cancels before returning
to ordinary play. No active watch is interrupted: restart is allowed only from
the main menu. Malformed/old releases retain the manual GitHub fallback.
Failed transfers or verification leave the installed executable intact and
allow retry. Transfers restart in full rather than using HTTP Range resume.

## Installation and recovery

The running executable determines the destination; manifest fields cannot
choose installation paths. Staging is on the same filesystem in
.hullwatch-update. PID registration and an atomic download lock serialize jobs;
helpers recheck hashes after a bounded process wait and hold a kernel apply
lock. Both helpers reject links/reparse points and fixed-path violations.
The old binary remains at its normal path until an atomic replacement, with a
verified backup under .hullwatch-update/previous. Durable local hash receipts
permit idempotent interrupted-install recovery; recovery never reinstalls an
abandoned payload. The new GUI acknowledges successful startup separately.
Filesystem/power-loss durability still requires platform review; no blanket
hardware power-cut guarantee is inferred from simulated process interruption.

Windows uses its system PowerShell and File.Replace. An adjacent trusted
Hullwatch-Updater.ps1 is shipped for recovery if the executable cannot start:

```powershell
powershell -NoProfile -File .\Hullwatch-Updater.ps1 -Recover -Target "C:\Games\Hullwatch\Hullwatch.exe"
```

Steam Deck's stable Hullwatch.sh remains the Steam shortcut target and owns the
child/restart loop. Exit42 requests apply; the wrapper runs its trusted adjacent
Hullwatch-Updater.sh synchronously, recovers before launch and preserves argv
and Steam environment. Direct ELF launches use an asynchronous shell helper.
No Python is required on either player's system. Saves/config remain outside
the installation and update file lists; save schema stays v8.

## Builds

Embedded build_version.json now records tag, source commit, platform and updater
protocol. Windows build.ps1 stamps/restores it and writes the platform manifest
plus adjacent recovery helper. The Deck builder does the same and exposes the
raw ELF as well as its TAR. tools/write_update_manifest.py generates manifests
for Linux cross-exports and validates the embedded-pack payload. Initial manual
installation of this bootstrap build is required; earlier checker-only builds
cannot install updates themselves. Helpers/launcher use fixed protocol1;
protocol-breaking changes need a fresh bootstrap package.

Initial package SOURCE_COMMIT/BUILD_INFO/SHA256SUMS describe the original
archive. After an in-client update, embedded identity and
.hullwatch-update/installed.json describe the active binary. Do not treat the
original package receipt as the post-update installation identity.

## Current validation and delivery

- [Windows20261013.5](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261013.5), source756fd95: **94/94** clean source suites, **16/16** actual EXE embedded-project checks.
- [Deck20261013.4](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-steamdeck-playtest.20261013.4), source9ac234b on separate branch: **95/95** source, **17/17** actual final ELF checks.
- Installer tests: **46 passed/1 skipped** (47 total). Shell plus temporary verified PowerShell7.6.6 on Linux; the Windows file-sharing case requires Windows. Additional shared checks cover interrupted backup/receipt publication. Initial PowerShell null-string rollback defect was fixed and rerun.
- Sixteen menu fixture views total pass bounds at1280x800/default1.0 and maximum1.4 UI scale, under Forward+/Mobile. Download offer, transfer/cancel page and failed-checksum presentation reviewed. These use simulated future notices and progress; they are not measured hardware FPS.
- **Native end-to-end PASS:** disposable client with controlled automatic menu selection reads the actual public GitHub manifest, streams the real full ELF from the asset CDN, verifies it, hands off to the shipped helper, replaces the executable, restarts and acknowledges the new GUI. The wrapper remains alive; argv forwarding, previous backup and installed hash/source identity are verified. Controlled older fixture is not a published game build.
- Both published asset sets downloaded independently: SHA256, manifest payload size/hash, source target and archive contents verified. Executable payloads were not replaced under their published tags; validation evidence was updated after the native scenario.

Evidence: [clean/source suites](source_suites.json), [installer checks](installer_checks.txt), [export/protocol checks](validation.json), [native scenario](native_update.json), [native log](native_update_log.txt), [published delivery](delivery.json).

Windows source/export came from a clean detached worktree because concurrent
unrelated computer/notice changes were present in the shared main checkout.
Those changes are excluded from this delivery and remain unstaged.
No save-format or simulation change. All checks use isolated userdata and
installation folders. Existing eight ObjectDB shutdown warnings persist.

Native Windows execution/PowerShell5.1/file-sharing, actual Steam Deck/Game Mode
restart/input/suspend and physical power-loss durability remain review gates.
The native host test validates the intended launcher process structure, not
Steam integration. Filesystem durability is qualified, not a blanket power-cut
guarantee. Previous binary recovery does not reverse later save migrations.
