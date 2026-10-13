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

Deterministic `test_update_checker.gd` covers numeric ordering, channel/asset
selection, invalid metadata, current/newer releases, offline/rate-limit/parse
failures, menu feedback, async selection preservation and duplicate checks.
Current source full-suite results, live request, captures, embedded-project
identity and delivery evidence are recorded alongside this document as they
complete. Windows PowerShell execution and native Windows/Deck hardware review
remain separate from Linux export validation. Existing published builds cannot
acquire this feature without installing a refreshed package.

[GitHub releases API](https://docs.github.com/en/rest/releases/releases#list-releases)
returns prereleases in the list; /latest excludes them.
[Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
provides asynchronous completion, timeout and response-size controls.
