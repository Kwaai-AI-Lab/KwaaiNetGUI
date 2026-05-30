# KwaaiNet GUI

A desktop app for [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) — the
distributed inference network. Chat with models running across the network,
contribute your machine to the mesh, and control the `kwaainet` node from a
menu-bar tray. Runs on **macOS, Linux, and Windows**.

## Download

Pre-built apps for all three desktop platforms are produced by CI on every
push to `main`. Grab the latest from the
**[Actions tab](https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/actions/workflows/ci.yml?query=branch%3Amain+is%3Asuccess)**:
open the most recent successful run and download the artifact for your
platform — `kwaainet-gui-macos`, `kwaainet-gui-windows`, or
`kwaainet-gui-linux`. Each is a zip of the ready-to-run app.

Each download bundles the matching KwaaiNet node, so the app works out of the
box — no separate install needed. Open the app, and it starts a node for you.

> **Heads up: these are unpackaged, unsigned builds.** You download a zipped
> app folder (not an installer yet), and your OS will warn that the app is from
> an unidentified developer. To run it anyway:
>
> - **macOS** — unzip, then **right-click `kwaainet_gui.app` → Open** and click
>   **Open** in the dialog (a plain double-click will be blocked). Or allow it
>   under System Settings → Privacy & Security → **Open Anyway**.
> - **Windows** — unzip and run `kwaainet_gui.exe`. If SmartScreen appears,
>   click **More info → Run anyway**.
> - **Linux** — unzip and run `./kwaainet_gui` from the extracted folder.
>
> Downloading artifacts requires a (free) GitHub login, and they expire after
> 14 days. Proper signed installers — `.dmg` / `.msix` / `.deb` / `.rpm`
> published to the [Releases page](https://github.com/Kwaai-AI-Lab/KwaaiNetGUI/releases)
> — are coming.

## Getting started

1. Download and unzip the build for your platform (above).
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
