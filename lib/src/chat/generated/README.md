# Generated gRPC bindings

These files are generated from `core/crates/kwaai-rpc/proto/kwaai.proto` in
the [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) repo — do not edit
by hand. They mirror the Rust bindings tonic produces for the daemon side,
so a change there has to be re-run through `protoc` to keep the GUI in sync.

## Regenerate

The GUI is its own repo, so the proto lives in a *separate* checkout. Point
`KWAAINET` at it — a sibling clone is the usual layout:

```bash
dart pub global activate protoc_plugin  # one-time
export PATH="$HOME/.pub-cache/bin:$PATH"

KWAAINET="${KWAAINET:-$(cd "$(git rev-parse --show-toplevel)/../KwaaiNet" && pwd)}"
PROTO_DIR="$KWAAINET/core/crates/kwaai-rpc/proto"

cd "$(git rev-parse --show-toplevel)/lib/src/chat/generated"
protoc --dart_out=grpc:. -I"$PROTO_DIR" "$PROTO_DIR/kwaai.proto"
```

`protoc` itself can come from anywhere — Homebrew (`brew install protobuf`)
or the copy the `kwaai-p2p-daemon` build script downloads under
`$KWAAINET/core/target` when no system one is on `PATH`.

## Check the branch first

**Regenerate against a proto that is a superset of what the GUI already
uses**, not whichever branch happens to be checked out. The daemon's ops
land on separate feature branches, so `upstream/main` can be *behind* the
GUI: generating from it silently deletes the bindings for ops the GUI
already calls, and the failure surfaces as missing getters in
`sharding_tab.dart` / `storage_tab.dart` rather than as an error here.

`git -C "$KWAAINET" show <branch>:core/crates/kwaai-rpc/proto/kwaai.proto`
is the quick way to inspect a branch's proto without checking it out. After
regenerating, `flutter analyze` catches anything that was dropped.
