# KwaaiNet GUI

A desktop app for [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) — the
distributed inference network. Chat with models running across the network,
contribute your machine to the mesh, and control the `kwaainet` node from a
menu-bar tray. Runs on **macOS, Linux, and Windows**.

## Download

Get the latest build for your platform from the
**[Releases page](https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/releases/latest)**:

| Platform | Download              |
| -------- | --------------------- |
| macOS    | `.dmg`                |
| Windows  | `.msix`               |
| Linux    | `.deb` / `.rpm`       |

Each download bundles the matching KwaaiNet node, so the app works out of the
box — no separate install needed. Open the app, and it starts a node for you.

> **Heads up: these builds aren't code-signed yet.** Your OS will warn that the
> app is from an unidentified developer. To install anyway:
>
> - **macOS** — the `.dmg` opens fine, but the first time you launch the app,
>   macOS will block it. **Right-click the app → Open**, then click **Open** in
>   the dialog. (Or: System Settings → Privacy & Security → **Open Anyway**.)
> - **Windows** — the `.msix` is signed with a self-signed certificate.
>   Double-click it, and if Windows shows a SmartScreen prompt click
>   **More info → Run anyway**. (You may first need to trust the bundled
>   certificate — see the install notes on the release.)
> - **Linux** — install the package directly: `sudo dpkg -i <file>.deb` or
>   `sudo rpm -i <file>.rpm`. No signing prompt.
>
> Signed/notarized builds are coming.

## Getting started

1. Download and install for your platform (above).
2. Launch **KwaaiNet GUI**. It starts a local node automatically and lives in
   your menu bar / system tray.
3. Open the chat tab and start talking to the network.

Want to point the app at a node you run yourself (on `PATH`, a custom path, or
managed by something else)? See **[Daemon modes](docs/daemon-modes.md)**.

## Contributing

KwaaiNet GUI is built with Flutter. To build it from source, run the tests, or
regenerate the gRPC bindings, see the **[development guide](docs/development.md)**.

## Documentation

- [Development guide](docs/development.md) — build, run, test, project layout
- [Daemon modes](docs/daemon-modes.md) — how the app finds and runs the node
