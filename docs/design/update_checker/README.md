# Startup GitHub update check — October 13

A release-tagged build checks the public Hullwatch GitHub release list once per
process using Godot HTTPRequest, off the simulation path. The main menu shows
its exact installed tag and update status. VIEW UPDATE ON GITHUB uses the
existing wheel/arrows/Enter/mouse menu and opens a validated release page.
Checking never gates New/Load/Continue. No automatic download or install.

## Selection and failure behavior

Windows and Steam Deck playtests are separate channels. Numeric base version,
stable rank, date and sequence determine the newest compatible published
release; same-base stable outranks a playtest. Assets must be uploaded/nonempty
and match the package for this platform. Drafts, malformed records and tag/flag
mismatches are ignored. The URL is constructed from a fixed repository and a
validated tag, so response text cannot choose another host. No credentials,
saves, telemetry or machine identifiers are sent.

One anonymous request per launch; eight-second timeout, 2 MiB response limit,
TLS and no redirects. It reads the first 100 releases. No compatible candidate
means unavailable rather than a false up-to-date result. Offline, timeout,
rate limiting and malformed responses retain playable menus and display
UPDATE CHECK UNAVAILABLE. A result survives return to the main menu, preserves
the highlighted action and does not interrupt a save-slot chooser.

## Build identity

`game/src/data/build_version.json` is included explicitly by export presets.
Its committed default is an empty development identity. Editor/headless startup
does not make automatic requests. Released builds must stamp their exact tag:

```powershell
.\build.ps1 -ReleaseTag v0.12.0-playtest.20261013.3
```

On the separate Deck branch:

```sh
python3 tools/build_steam_deck.py --engine /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 --release-tag v0.12.0-steamdeck-playtest.20261013.2
```

Both builders validate the tag/channel, temporarily stamp UTF-8 JSON and restore
original bytes in finally. Serialize exports within each checkout. Linux
cross-export of Windows uses the same temporary identity contract. A plain build
without a tag is a development build and deliberately makes no update claims.
The Deck package records its tag in BUILD_INFO.json. No simulation/save changes.

## Validation and delivery

Published and independently downloaded/verified:

- [Windows v0.12.0-playtest.20261013.3](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-playtest.20261013.3), source d66661a: source **93/93**, actual EXE embedded-project **15/15**.
- [Steam Deck v0.12.0-steamdeck-playtest.20261013.2](https://github.com/Mangekyo-Sharingan/hullwatch/releases/tag/v0.12.0-steamdeck-playtest.20261013.2), source72b5181 on separate branch: source **94/94**, actual ELF embedded-project **16/16**.

Both actual exported projects contain their exact release tag and correct
platform channel. Six menu views each pass bounds at1280x800 with default1.0
and maximum1.4 UI scale. Windows content renders under Wayland/Forward+;
Deck under Wayland/Mobile. Available notices at both scales were reviewed.
The native Linux release automatically checks on startup and displays its
installed Deck tag plus UP TO DATE; its relocated launcher rendered90 menu
movie frames. These are Linux host checks, not Deck performance results.

The anonymous live source check with an older Windows identity detects a real
newer release. After publication, each actual exported project checks GitHub
again and selects its own current release. Fixture captures of a future update
use sequence .10; that release was not published. No browser was opened by tests.

Evidence: [source suites](source_suites.json), [export/render checks](validation.json),
[published download identity and hashes](delivery.json), [live published API](published_live_api.txt).
Tests cover numeric ordering, channel/asset selection, invalid metadata,
current/newer releases, offline/rate-limit/parse failures, menu feedback,
async selection preservation and duplicate startup checks. All final checks
use isolated userdata. Localization was regenerated with91 strings.

Native Windows execution, Windows PowerShell helper execution, and actual
Steam Deck/Big Picture browser/input/performance/suspend review remain open.
Linux cross-export uses the same temporary JSON stamp/restore contract as the
PowerShell helper. Existing eight ObjectDB shutdown warnings persist. A first
concurrent Forward+ capture timed out; the separate retry passed all six views.
**Existing testers must install one of these packages once to gain future
startup notices.** There is no automatic download or installer.

[GitHub releases API](https://docs.github.com/en/rest/releases/releases#list-releases)
returns prereleases in the list; /latest excludes them.
[Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
provides asynchronous completion, timeout and response-size controls.
