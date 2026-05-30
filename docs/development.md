# Development guide

KwaaiNet GUI is a Flutter desktop app. This covers building it from source,
running the tests, and regenerating the gRPC bindings.

## Prerequisites

- Flutter SDK **3.11.4** or newer (`flutter --version`)
- A working desktop toolchain for your platform:
  - macOS: Xcode command-line tools
  - Linux: GTK 3 / clang / ninja / pkg-config (see
    [Flutter Linux setup](https://docs.flutter.dev/get-started/install/linux/desktop))
  - Windows: Visual Studio with the "Desktop development with C++" workload
- A `kwaainet` binary on `PATH`, or a sibling checkout of the
  [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) repo if you want the GUI
  to drive a debug build of the node (see [Daemon modes](daemon-modes.md))

## Build & run

```bash
flutter pub get
flutter run -d macos      # or: -d linux, -d windows
```

Release builds land under `build/<platform>/` — e.g.
`build/macos/Build/Products/Release/kwaainet_gui.app`,
`build/linux/x64/release/bundle/`,
`build/windows/x64/runner/Release/`.

## Tests & lint

```bash
flutter analyze
flutter test
```

CI runs both on every push and PR (see [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)),
along with a release build for each desktop platform.

## gRPC bindings

The Dart bindings under `lib/src/chat/generated/` are generated from the
`kwaai.proto` in the KwaaiNet repo (`core/crates/kwaai-rpc/proto/kwaai.proto`).
See [`lib/src/chat/generated/README.md`](../lib/src/chat/generated/README.md)
for how to regenerate them.

## Project layout

```
lib/
├── main.dart
└── src/
    ├── chat/        # gRPC client, chat state, generated bindings
    ├── daemon/      # daemon lifecycle (spawn/probe/stop)
    ├── settings.dart
    ├── tray/        # menu-bar tray integration
    ├── ui/          # widgets and pages
    └── window/      # window/lifecycle wiring
macos/  linux/  windows/   # platform shells
test/
```
