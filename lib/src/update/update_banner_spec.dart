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

/// The Settings → Status panel's view of the same state machine.
///
/// Same shape as [updateBannerSpec], deliberately: one stage→text mapping,
/// two surfaces. The panel differs in that it is always on screen, so it has
/// an up-to-date state and no Later/Skip, and it leaves the restart to the
/// pinned bottom bar.
UpdateBannerSpec updatePanelSpec({
  required UpdateStage stage,
  required String currentVersion,
  required String? pendingVersion,
  required bool installSupported,
  required bool autoDownload,
}) {
  switch (stage) {
    case UpdateDownloading() || UpdateVerifying() || UpdateFailed():
      return updateBannerSpec(
        stage: stage,
        version: pendingVersion ?? currentVersion,
        installSupported: installSupported,
      );
    case UpdateReady(version: final staged):
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.info,
        message: 'KwaaiNet $staged is ready to install.',
        actions: const [],
      );
    case UpdateIdle():
      if (pendingVersion == null) {
        return UpdateBannerSpec(
          severity: KwaaiStatusSeverity.info,
          message: 'KwaaiNet $currentVersion is up to date.',
          actions: const [],
        );
      }
      // Auto-download would have moved us off idle already, so an offer here
      // means it is off — or declined, which a non-installable root does
      // silently. Either way the user needs the manual way forward.
      return UpdateBannerSpec(
        severity: KwaaiStatusSeverity.info,
        message: 'KwaaiNet $pendingVersion is available.',
        actions: [
          if (!autoDownload || !installSupported) UpdateBannerAction.update,
        ],
      );
  }
}

/// Whether the main window's top banner shows anything for [stage].
///
/// Download progress belongs to Settings → Updates; the banner is reserved
/// for what a user who never opens Settings still has to see — that an update
/// exists, that one is ready, or that one failed.
bool showUpdateBanner(UpdateStage stage) =>
    stage is! UpdateDownloading && stage is! UpdateVerifying;

/// Label for the tray's update item, following the same stage.
///
/// The idle label states the restart because the tray item does the whole
/// job in one click; without an installable root it can only open the
/// release page, so it says less.
String updateTrayLabel(
  UpdateStage stage,
  String version, {
  required bool installSupported,
}) => switch (stage) {
  UpdateDownloading(:final progress) =>
    progress == null
        ? '⬇️  Downloading update…'
        : '⬇️  Downloading update… ${(progress * 100).round()}%',
  UpdateVerifying() => '⬇️  Verifying update…',
  UpdateReady(version: final staged) => '⬆️  Restart to update to $staged',
  UpdateFailed() => '⚠️  Update failed — open release page',
  UpdateIdle() =>
    installSupported
        ? '⬆️  Update to $version and restart'
        : '⬆️  Update available: $version…',
};

/// The tray item is inert while work is in flight.
bool updateTrayItemDisabled(UpdateStage stage) =>
    stage is UpdateDownloading || stage is UpdateVerifying;
