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
`build/macos/Build/Products/Release/KwaaiNet.app`,
`build/linux/x64/release/bundle/`,
`build/windows/x64/runner/Release/`.

## Pointing the GUI at another daemon

By default the GUI talks to the daemon on this machine: the Unix socket at
`~/.kwaainet/run/kwaai.sock` on macOS/Linux, falling back to TCP `127.0.0.1:8093`.

`KWAAINET_GRPC_PORT` overrides the port, which is how you inspect a daemon that
is not the local one:

```bash
KWAAINET_GRPC_PORT=8099 flutter run -d macos
```

Setting it also skips the Unix socket. That is deliberate — the socket belongs
to whatever is running locally, so leaving it in the chain would mean the local
daemon silently answered and the override did nothing.

The main use is kwaaiai-env's NAT test topology, which publishes each
containerised node's gRPC on its own host port (`make gui-bridge NODE=node-f`
in that repo, then port 8099 for node-f). Handy for seeing the Network tab
against a NATed or relay-only node rather than your own.

An unparseable or out-of-range value logs a line and falls back to 8093 rather
than failing the connection outright.

### Not managing the daemon

`KWAAINET_EXTERNAL_DAEMON=1` forces the "Service managed externally" mode
regardless of what is stored on disk, so the app neither spawns nor stops a
daemon:

```bash
KWAAINET_GRPC_PORT=8099 KWAAINET_EXTERNAL_DAEMON=1 flutter run -d macos
```

Pair it with `KWAAINET_GRPC_PORT` whenever you point the GUI at a container.
The port override only changes *who the app talks to*; without this variable
the app still starts a **local** daemon at boot that nothing is connected to,
and reports that local process while the data tabs stream from the container.
That split is the usual "the daemon is not running" confusion.

With an explicit port the Status header follows the gRPC channel rather than
the local PID file, so it reads `Running · port 8099` for a container that
answers and `Unreachable · port 8099` for one that does not. The pid, uptime,
memory and CPU bits are dropped in that mode — every one of them comes from
this host's status file and would describe the wrong process.

The override does not rewrite the saved setting: the picker in
Settings → Service shows "Service managed externally" selected and read-only,
and your stored choice applies again the moment you run without the variable.

Falsey values (`0`, `false`, `no`, `off`) and an empty value all count as
unset, so `KWAAINET_EXTERNAL_DAEMON=` does not silently take over.

kwaaiai-env sets both variables for you: `make gui-run NODE=node-f` to run
under `flutter run`, or its "KwaaiNet GUI (NAT test node)" launch
configuration to run under the VS Code debugger. Both live in that repo
rather than this one, since the topology they target is defined there — open
the kwaaiai-env folder (or `kwaaiai.code-workspace`) to get the launch config.

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
