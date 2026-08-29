import 'package:flutter/foundation.dart';

/// Suppresses every tooltip — in debug builds only.
///
/// Workaround for a Flutter framework bug: a tooltip still on screen when an
/// opaque route is pushed over its owner leaves an overlay child mounted but
/// offstage. `_RenderTheater` skips laying that obstructed entry out, so on
/// the next window resize the child is laid out with its pre-resize size and
/// two assertions fire — overlay.dart:2895 `size == theater.size` and
/// object.dart:4323 `debugNeedsLayout`.
///
/// Assertions are compiled out of profile and release builds, so shipped
/// builds are unaffected and keep their tooltips. Debug is the only mode that
/// pays, and there the assertions halt the debugger.
///
/// Filed upstream as https://github.com/flutter/flutter/issues/192030;
/// unfixed on master. Drop this file
/// and the `tooltipTheme` line in theme_variants.dart once the fix lands.
const bool kTooltipsDisabled = kDebugMode;
