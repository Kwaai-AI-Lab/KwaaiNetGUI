# Changelog

All notable changes to KwaaiNet GUI are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.4.0] - 2026-09-04

### Added
- **Bootstrap-down banner.** A red app-level bar, persistent across the main
  and Settings routes, when no bootstrap peer has been reachable recently.
  Silent for the first 30 s after start and when the daemon cannot say
  (an older daemon, or peers without a `/p2p` id).
- **Peers: free-text search** on the table caption bar, matching peer id
  (the full id, not the abbreviated cell), agent version, addresses and relay.
- **Peers: protocol filter** drop-down, discovered lazily from what this node
  serves and what its connected peers advertise. Matched by protocol family so
  a version skew still counts.
- **Peers: IPv6.** A chip in the self-status header showing the daemon's IPv6
  verdict; IPv6 and QUIC observed addresses are grouped like TCP ones, and
  IPv4-mapped loopbacks are classified as the v4 address they are.
- **Settings: IPv6 mode** selector (auto / on / off) in Reachability. Auto
  removes the key so the daemon decides.
- **Settings: QUIC toggle** (`enable_quic`) in Reachability.
- **Settings: max connections** (`max_connections`) in Network. Empty leaves
  the daemon default in place; values under 8 are refused.
- **Sharding: hide empty peers.** Peers announcing the nominal one-block range
  no longer count as servers; a "Show empty peers" checkbox brings them back.
- **Per-instance daemon.** A GUI run from a source checkout gets its own state
  directory (`<root>/.kwaainet-dev`), its own ports and its own preferences,
  so a debug build no longer reports, or kills, an installed build's daemon.
  The GUI allocates the gRPC port and follows the one the daemon reports.
- **`KWAAINET_EXTERNAL_DAEMON=1`** forces external mode without touching the
  stored setting, for pointing the GUI at a remote daemon alongside
  `KWAAINET_GRPC_PORT`.
- **Tray:** left click opens Chat; right click opens the menu (Linux
  unchanged). The menu's update item now downloads, stages and restarts in
  one click.

### Changed
- Status header follows the gRPC channel when `KWAAINET_GRPC_PORT` is set,
  reporting the daemon the app is actually talking to rather than the local
  PID file.
- Flutter 3.47.2 / Dart 3.13.2; dependencies upgraded within constraints.
  All macOS plugins are now Swift Packages and the CocoaPods integration is
  removed.
- Tooltips are disabled in debug builds only, to avoid a Flutter overlay
  resize assertion (flutter/flutter#192030). Release builds keep them.

### Fixed
- `enable_quic` defaulted to on in the GUI while the daemon defaults to off,
  so applying any setting silently enabled QUIC on a fresh config.
- Port allocation checks both address families, since the daemon binds its
  port on IPv6 as well.
- Peers caption bar layout: search field height, summary alignment, and both
  filter checkboxes always visible.

### Removed
- Support for macOS 11 and earlier. Flutter 3.47 requires a 12.0 deployment
  target.

## [0.3.4] - 2026-08-27

### Fixed
- Re-selecting the already-active option in Settings no longer counts as an
  edit.
- Update check test fixture provides an asset for every platform.

## [0.3.3] - 2026-08-27

### Changed
- Update UI moved into Settings.

## [0.3.2] - 2026-08-27

### Changed
- README explains the macOS "No such file or directory" error on upgrade.
- Release bundle can be built locally exactly as CI does.

## [0.3.1] - 2026-08-27

### Fixed
- macOS: the GUI no longer launches itself as its own node.

## [0.3.0] - 2026-08-27

### Added
- In-place updates: download, verify and install a new release.
- Peers: filter unconnected peers; show how this node is reached.
- VPK: node list ordered by reachability; selected unreachable nodes are
  highlighted on the cylinder.
- Peers documentation covering the reachability pill, PATH values and table
  columns.

### Fixed
- Settings Apply gates on the whole draft, not a drifted tab index.
- Tooltips are dismissed on resize so the overlay is never swapped mid-layout.
- macOS: the daemon is bundled in Resources rather than MacOS.

## [0.2.0] - 2026-08-26

### Added
- Peers tab showing live p2p state: a single peer table with DCUtR upgrades
  named, a connections panel, relay and routing addresses, DHT client-mode
  marking, and connect-from-the-table for known but unconnected peers.
- Protocols described in words, with the raw id beside each description.
- VPK tab showing network storage.
- Sharding tab (renamed from Blocks) with a live block-coverage view that
  marks itself stale when the daemon goes quiet.
- Chat: markdown rendering, a stop button that stops the daemon, dismissable
  full-width error bar, truncation marker.
- Settings: daemon version display, UPnP port-mapping toggle.
- `KWAAINET_GRPC_PORT` points the GUI at another daemon.

### Changed
- Flutter 3.44.9; bundled kwaainet v0.6.2.

### Fixed
- Chat times out silently stalled streams.
- Peers tab no longer burns frames while idle.
- Remote-daemon tabs are not gated on a local PID file.

## [0.1.3] - 2026-05-31

### Added
- Self-update check with Update / Later / Skip.

### Changed
- macOS desktop app renamed to "KwaaiNet".

## [0.1.2] - 2026-05-30

### Fixed
- Daemon is stopped on true quit; kwaainet/p2pd are no longer orphaned.
- Shutdown reaps the whole node and mirrors the startup takeover screen.
- Built-in daemon label is honest about release vs dev.

## [0.1.1] - 2026-05-30

### Fixed
- macOS: app renamed to "KwaaiNet GUI" and re-signed after bundling.

## [0.1.0] - 2026-05-30

Initial standalone release: daemon control with status, settings and tray;
chat over gRPC to a local or external kwaainet daemon; CI builds for macOS,
Linux and Windows with the daemon bundled.

[0.4.0]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.3.4...v0.4.0
[0.3.4]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/releases/tag/v0.1.0
