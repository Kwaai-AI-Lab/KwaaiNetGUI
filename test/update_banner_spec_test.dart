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

    test('verifying is indeterminate', () {
      final s = spec(const UpdateVerifying());
      expect(s.message, 'Verifying KwaaiNet 0.3.0…');
      expect(s.indeterminate, isTrue);
      expect(s.progress, isNull);
    });

    test('ready offers Restart now / Later, never restarts on its own', () {
      final s = spec(
        const UpdateReady(stagedPath: '/s/app', stagePath: '/s'),
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
          const UpdateReady(stagedPath: '/s/app', stagePath: '/s'),
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
          const UpdateReady(stagedPath: '/s/app', stagePath: '/s'),
        ),
        isFalse,
      );
    });
  });
}
