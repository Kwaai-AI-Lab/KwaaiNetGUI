# Daemon modes

The GUI talks to a `kwaainet` node over gRPC. The Settings page exposes four
ways for it to find and run that node (see
[`lib/src/settings.dart`](../lib/src/settings.dart) and
[`lib/src/daemon/daemon_controller.dart`](../lib/src/daemon/daemon_controller.dart)):

| Mode        | Behaviour                                                              |
| ----------- | ---------------------------------------------------------------------- |
| `builtIn`   | Run a bundled `kwaainet`, or the debug binary from a sibling `KwaaiNet/` checkout (`../KwaaiNet/core/target/debug/kwaainet`); override with the `KWAAINET_DEBUG_BIN` environment variable |
| `system`    | Find `kwaainet` on `PATH`                                              |
| `custom`    | Run a binary at a user-chosen path                                     |
| `external`  | Don't manage the node — assume something else (launchd, systemd, Docker, a shell) is already running it |

The first three modes spawn and supervise the node process; the GUI writes the
PID to a state file and surfaces start/stop controls. In `external` mode the
GUI is read-only and only probes the node over gRPC.

## Bundled node version

Downloaded builds ship with a `kwaainet` node (and its `p2pd` helper) pulled
from a pinned [KwaaiNet release](https://github.com/Kwaai-AI-Lab/KwaaiNet/releases).
The pinned tag lives in [`.kwaainet-version`](../.kwaainet-version); bump it
(and regenerate the [gRPC bindings](development.md#grpc-bindings) if the RPC
surface changed) to ship a newer node.
