import 'package:flutter/material.dart';

/// Dismisses any open tooltip when the window's metrics change.
///
/// A tooltip lives in the app Overlay, positioned against its target's paint
/// transform, which `OverlayPortal.overlayChildLayoutBuilder` recomputes
/// during layout. A live resize moves the theater under it: the transform
/// degenerates, `RawTooltip` swaps the whole overlay subtree for a
/// `SizedBox.shrink()`, and deactivating it trips debug assertions in the
/// framework — the frame aborts and the window looks frozen.
class TooltipResizeGuard extends StatefulWidget {
  const TooltipResizeGuard({super.key, required this.child});

  final Widget child;

  @override
  State<TooltipResizeGuard> createState() => _TooltipResizeGuardState();
}

class _TooltipResizeGuardState extends State<TooltipResizeGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => Tooltip.dismissAllToolTips();

  @override
  Widget build(BuildContext context) => widget.child;
}
