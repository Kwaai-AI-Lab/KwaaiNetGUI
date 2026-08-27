import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/ui/widgets/kwaai_status_bar.dart';
import 'package:kwaainet_gui/src/update/update_banner_spec.dart';
import 'package:kwaainet_gui/src/update/update_controller.dart';

UpdateBannerSpec spec(UpdateStage stage, {bool supported = true}) =>
    updateBannerSpec(
      stage: stage,
      version: '0.3.0',
      installSupported: supported,
    );

void main() {
  group('updateBannerSpec', () {
    test('idle offers Update / Later / Skip', () {
      final s = spec(const UpdateIdle());
      expect(s.message, 'KwaaiNet 0.3.0 is available.');
      expect(s.severity, KwaaiStatusSeverity.info);
      expect(s.actions, [
        UpdateBannerAction.update,
        UpdateBannerAction.later,
        UpdateBannerAction.skip,
      ]);
      expect(s.progress, isNull);
      expect(s.dismissible, isFalse);
    });

    test('an unsupported install root looks identical — only Update differs', () {
      // The button's behaviour (browser vs. install) is the widget's branch;
      // the banner itself must not change shape.
      expect(
        spec(const UpdateIdle(), supported: false).actions,
        spec(const UpdateIdle()).actions,
      );
      expect(
        spec(const UpdateIdle(), supported: false).message,
        spec(const UpdateIdle()).message,
      );
    });

    test('downloading shows a percentage and a determinate bar', () {
      final s = spec(const UpdateDownloading(0.42));
      expect(s.message, 'Downloading KwaaiNet 0.3.0… 42%');
      expect(s.progress, 0.42);
      expect(s.indeterminate, isFalse);
      expect(s.actions, [UpdateBannerAction.cancel]);
    });

    test('downloading with an unknown total goes indeterminate', () {
      final s = spec(const UpdateDownloading(null));
      expect(s.message, 'Downloading KwaaiNet 0.3.0…');
      expect(s.progress, isNull);
      expect(s.indeterminate, isTrue);
    });

    test('verifying is indeterminate and offers no Cancel', () {
      final s = spec(const UpdateVerifying());
      expect(s.message, 'Verifying KwaaiNet 0.3.0…');
      expect(s.indeterminate, isTrue);
      expect(s.progress, isNull);
      // The unpack is a child process we cannot interrupt cleanly.
      expect(s.actions, isEmpty);
    });

    test('ready reports the staged version, not a newer detected one', () {
      final s = updateBannerSpec(
        stage: const UpdateReady(
          version: '0.3.0',
          stagedPath: '/s/app',
          stagePath: '/s',
        ),
        version: '0.4.0',
        installSupported: true,
      );
      expect(s.message, 'KwaaiNet 0.3.0 is ready to install.');
      expect(
        updateTrayLabel(
          const UpdateReady(
            version: '0.3.0',
            stagedPath: '/s/app',
            stagePath: '/s',
          ),
          '0.4.0',
        ),
        '⬆️  Restart to update to 0.3.0',
      );
    });

    test('ready offers Restart now / Later, never restarts on its own', () {
      final s = spec(
        const UpdateReady(
          version: '0.3.0',
          stagedPath: '/s/app',
          stagePath: '/s',
        ),
      );
      expect(s.message, 'KwaaiNet 0.3.0 is ready to install.');
      expect(s.actions, [
        UpdateBannerAction.restart,
        UpdateBannerAction.later,
      ]);
    });

    test('failed is a dismissible warning with a browser fallback', () {
      final s = spec(const UpdateFailed('Couldn\'t download the update.'));
      expect(s.severity, KwaaiStatusSeverity.warning);
      expect(s.message, 'Couldn\'t download the update.');
      expect(s.actions, [
        UpdateBannerAction.retry,
        UpdateBannerAction.openReleasePage,
      ]);
      expect(s.dismissible, isTrue);
    });

    test('failed drops Retry when no install is possible', () {
      // Retrying a download we could never install is a dead end.
      final s = spec(const UpdateFailed('nope'), supported: false);
      expect(s.actions, [UpdateBannerAction.openReleasePage]);
    });
  });

  group('updatePanelSpec', () {
    UpdateBannerSpec panel(
      UpdateStage stage, {
      String? pending,
      bool supported = true,
      bool autoDownload = true,
    }) => updatePanelSpec(
      stage: stage,
      currentVersion: '0.2.0',
      pendingVersion: pending,
      installSupported: supported,
      autoDownload: autoDownload,
    );

    test('idle with nothing pending says the app is up to date', () {
      final s = panel(const UpdateIdle());
      expect(s.message, 'KwaaiNet 0.2.0 is up to date.');
      expect(s.actions, isEmpty);
      expect(s.progress, isNull);
      expect(s.indeterminate, isFalse);
    });

    test('idle with a pending release offers Download when auto is off', () {
      final s = panel(const UpdateIdle(), pending: '0.3.0', autoDownload: false);
      expect(s.message, 'KwaaiNet 0.3.0 is available.');
      expect(s.actions, [UpdateBannerAction.update]);
    });

    test('auto-download on leaves the offer to the machine', () {
      final s = panel(const UpdateIdle(), pending: '0.3.0');
      expect(s.message, 'KwaaiNet 0.3.0 is available.');
      expect(s.actions, isEmpty);
    });

    test('...unless nothing would pick it up, which must not dead-end', () {
      // Auto-download declines silently on an uninstallable root, so without
      // this the user would be left with an offer and no way to act on it.
      final s = panel(
        const UpdateIdle(),
        pending: '0.3.0',
        supported: false,
      );
      expect(s.actions, [UpdateBannerAction.update]);
    });

    test('downloading carries progress and Cancel, as the banner does', () {
      final s = panel(const UpdateDownloading(0.42), pending: '0.3.0');
      expect(s.message, 'Downloading KwaaiNet 0.3.0… 42%');
      expect(s.progress, 0.42);
      expect(s.actions, [UpdateBannerAction.cancel]);
    });

    test('verifying is indeterminate with no actions', () {
      final s = panel(const UpdateVerifying(), pending: '0.3.0');
      expect(s.message, 'Verifying KwaaiNet 0.3.0…');
      expect(s.indeterminate, isTrue);
      expect(s.actions, isEmpty);
    });

    test('ready states the staged version and leaves restart to the bar', () {
      final s = panel(
        const UpdateReady(
          version: '0.3.0',
          stagedPath: '/s/app',
          stagePath: '/s',
        ),
        pending: '0.4.0',
      );
      expect(s.message, 'KwaaiNet 0.3.0 is ready to install.');
      expect(s.actions, isEmpty);
    });

    test('failed offers Retry and stays dismissible', () {
      final s = panel(const UpdateFailed('Nope.'), pending: '0.3.0');
      expect(s.severity, KwaaiStatusSeverity.warning);
      expect(s.message, 'Nope.');
      expect(s.actions, [
        UpdateBannerAction.retry,
        UpdateBannerAction.openReleasePage,
      ]);
      expect(s.dismissible, isTrue);
    });

    test('never offers Later or Skip — those are banner-only', () {
      for (final stage in <UpdateStage>[
        const UpdateIdle(),
        const UpdateDownloading(0.5),
        const UpdateVerifying(),
        const UpdateReady(version: '1.0.0', stagedPath: '/a', stagePath: '/b'),
        const UpdateFailed('x'),
      ]) {
        final s = panel(stage, pending: '0.3.0', autoDownload: false);
        expect(s.actions, isNot(contains(UpdateBannerAction.later)));
        expect(s.actions, isNot(contains(UpdateBannerAction.skip)));
      }
    });
  });

  group('showUpdateBanner', () {
    test('silent while a download is in flight', () {
      // Progress lives in Settings → Updates; the top banner must not
      // interrupt the main window with it.
      expect(showUpdateBanner(const UpdateDownloading(0.1)), isFalse);
      expect(showUpdateBanner(const UpdateDownloading(null)), isFalse);
      expect(showUpdateBanner(const UpdateVerifying()), isFalse);
    });

    test('still speaks up for availability, ready and failure', () {
      // A user who never opens Settings must still learn an update exists,
      // and still needs a way to trigger the restart.
      expect(showUpdateBanner(const UpdateIdle()), isTrue);
      expect(
        showUpdateBanner(
          const UpdateReady(
            version: '0.3.0',
            stagedPath: '/s/app',
            stagePath: '/s',
          ),
        ),
        isTrue,
      );
      expect(showUpdateBanner(const UpdateFailed('x')), isTrue);
    });
  });

  group('tray label', () {
    test('follows the same stage', () {
      expect(
        updateTrayLabel(const UpdateIdle(), '0.3.0'),
        '⬆️  Update available: 0.3.0…',
      );
      expect(
        updateTrayLabel(const UpdateDownloading(0.42), '0.3.0'),
        '⬇️  Downloading update… 42%',
      );
      expect(
        updateTrayLabel(
          const UpdateReady(
            version: '0.3.0',
            stagedPath: '/s/app',
            stagePath: '/s',
          ),
          '0.3.0',
        ),
        '⬆️  Restart to update to 0.3.0',
      );
    });

    test('the item is inert only while work is in flight', () {
      expect(updateTrayItemDisabled(const UpdateDownloading(0.1)), isTrue);
      expect(updateTrayItemDisabled(const UpdateVerifying()), isTrue);
      expect(updateTrayItemDisabled(const UpdateIdle()), isFalse);
      expect(
        updateTrayItemDisabled(
          const UpdateReady(
            version: '0.3.0',
            stagedPath: '/s/app',
            stagePath: '/s',
          ),
        ),
        isFalse,
      );
    });
  });
}
