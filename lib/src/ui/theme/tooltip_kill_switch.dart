/// Suppresses every tooltip in the app.
///
/// Workaround for a Flutter framework bug: a tooltip that is still on screen
/// when an opaque route is pushed over it leaves an overlay child inside an
/// obstructed OverlayEntry. `_RenderTheater` skips laying that entry out, so
/// on the next window resize the child is laid out with its pre-resize size
/// and two assertions fire — overlay.dart:2895 `size == theater.size` and
/// object.dart:4323 `debugNeedsLayout`. Both halt the debugger.
///
/// Reproduced against Flutter 3.47.2 in a framework-only widget test; still
/// unfixed on upstream master. Only `Tooltip`, `MenuAnchor` and `Autocomplete`
/// use the API involved (`OverlayPortal.overlayChildLayoutBuilder`), and
/// tooltips are this app's exposure — a tooltip is showing on the Settings
/// button at the moment the button is clicked.
///
/// Set back to `false` once the upstream fix lands.
const bool kTooltipsDisabled = true;
