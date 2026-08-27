import '../ui/widgets/kwaai_status_bar.dart';
import 'update_controller.dart';

/// A button the update banner can offer. The widget layer maps these to
/// callbacks; keeping them as data is what makes the mapping unit-testable.
enum UpdateBannerAction {
  /// Starts the install when supported, otherwise opens the release page.
  update,
  restart,
  cancel,
  retry,
  openReleasePage,
  later,
  skip,
}

/// Everything the banner needs, derived from the stage alone.
class UpdateBannerSpec {
  const UpdateBannerSpec({
    required this.severity,
    required this.message,
    required this.actions,
    this.progress,
    this.indeterminate = false,
    this.dismissible = false,
  });

  final KwaaiStatusSeverity severity;
  final String message;
  final List<UpdateBannerAction> actions;

  /// Determinate bar value, or null for none.
  final double? progress;

  /// Show a bar with no value (work of unknown length).
  final bool indeterminate;

  /// Show KwaaiStatusBar's × affordance.
  final bool dismissible;
}

/// Stage → banner content. Pure, so the whole table is a unit test.
///
/// [installSupported] false means a debug build or an unrecognised install
/// layout: the banner still appears, but Update opens the browser as it
/// always has.
UpdateBannerSpec updateBannerSpec({
  required UpdateStage stage,
  required String version,
  required bool installSupported,
}) {
  switch (stage) {
    case UpdateDownloading(:final progress):
      final pct = progress == null ? '' : ' ${(progress * 100).round()}%';
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.info,
        message: 'Downloading KwaaiNet $version…$pct',
        actions: const [UpdateBannerAction.cancel],
        progress: progress,
        indeterminate: progress == null,
      );
    // No Cancel: the unpack is a child process we cannot interrupt cleanly,
    // and deleting its input mid-run is worse than letting it finish.
    case UpdateVerifying():
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.info,
        message: 'Verifying KwaaiNet $version…',
        actions: const [],
        indeterminate: true,
      );
    // Deliberately the *staged* version, not the newest detected: a newer
    // release can land while one is already prepared, and a restart would
    // install the staged one.
    case UpdateReady(version: final staged):
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.info,
        message: 'KwaaiNet $staged is ready to install.',
        actions: const [UpdateBannerAction.restart, UpdateBannerAction.later],
      );
    // Retry is only offered where an install could actually succeed;
    // otherwise the release page is the only useful way forward.
    case UpdateFailed(:final message):
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.warning,
        message: message,
        actions: [
          if (installSupported) UpdateBannerAction.retry,
          UpdateBannerAction.openReleasePage,
        ],
        dismissible: true,
      );
    case UpdateIdle():
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.info,
        message: 'KwaaiNet $version is available.',
        actions: const [
          UpdateBannerAction.update,
          UpdateBannerAction.later,
          UpdateBannerAction.skip,
        ],
      );
  }
}

/// Label for the tray's update item, following the same stage.
String updateTrayLabel(UpdateStage stage, String version) => switch (stage) {
  UpdateDownloading(:final progress) =>
    progress == null
        ? '⬇️  Downloading update…'
        : '⬇️  Downloading update… ${(progress * 100).round()}%',
  UpdateVerifying() => '⬇️  Verifying update…',
  UpdateReady(version: final staged) => '⬆️  Restart to update to $staged',
  UpdateFailed() => '⚠️  Update failed — open release page',
  UpdateIdle() => '⬆️  Update available: $version…',
};

/// The tray item is inert while work is in flight.
bool updateTrayItemDisabled(UpdateStage stage) =>
    stage is UpdateDownloading || stage is UpdateVerifying;
