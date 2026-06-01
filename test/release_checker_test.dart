import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kwaainet_gui/src/settings.dart';
import 'package:kwaainet_gui/src/update/release_checker.dart';

/// Test notifier that exposes a fixed pending release so we can exercise
/// the visibility policy without hitting the network.
class _FakeUpdateNotifier extends UpdateAvailabilityNotifier {
  _FakeUpdateNotifier(this._latest);
  final ReleaseInfo? _latest;

  @override
  Future<UpdateAvailability> build() async {
    return UpdateAvailability(latest: _latest, current: '0.1.2');
  }
}

ProviderContainer _containerWith({
  ReleaseInfo? latest,
  String? skipped,
}) {
  final c = ProviderContainer(
    overrides: [
      updateAvailabilityProvider.overrideWith(() => _FakeUpdateNotifier(latest)),
      skippedVersionProvider.overrideWith((_) => skipped),
    ],
  );
  // Resolve the AsyncNotifier so .valueOrNull is populated.
  c.read(updateAvailabilityProvider);
  return c;
}

void main() {
  group('ReleaseChecker.normalizeVersion', () {
    test('strips a leading v/V and whitespace', () {
      expect(ReleaseChecker.normalizeVersion('v0.1.3'), '0.1.3');
      expect(ReleaseChecker.normalizeVersion('V0.1.3'), '0.1.3');
      expect(ReleaseChecker.normalizeVersion('  v0.1.3 '), '0.1.3');
      expect(ReleaseChecker.normalizeVersion('0.1.3'), '0.1.3');
    });
  });

  group('ReleaseChecker.isNewer', () {
    // Mirrors the Rust node updater's is_newer ordering tests
    // (kwaai-cli/src/updater.rs).
    test('ordering', () {
      expect(ReleaseChecker.isNewer('0.4.2', '0.4.1'), isTrue);
      expect(ReleaseChecker.isNewer('0.5.0', '0.4.99'), isTrue);
      expect(ReleaseChecker.isNewer('1.0.0', '0.9.9'), isTrue);
      expect(ReleaseChecker.isNewer('0.4.1', '0.4.1'), isFalse);
      expect(ReleaseChecker.isNewer('0.4.0', '0.4.1'), isFalse);
    });

    test('tolerates leading v on either side', () {
      expect(ReleaseChecker.isNewer('v0.1.3', '0.1.2'), isTrue);
      expect(ReleaseChecker.isNewer('0.1.3', 'v0.1.3'), isFalse);
    });

    test('missing or non-numeric parts count as zero', () {
      expect(ReleaseChecker.isNewer('0.2', '0.1.9'), isTrue);
      expect(ReleaseChecker.isNewer('1', '0.9.9'), isTrue);
      expect(ReleaseChecker.isNewer('0.1', '0.1.0'), isFalse);
      expect(ReleaseChecker.isNewer('0.1.x', '0.1.0'), isFalse);
    });
  });

  group('banner / tray visibility policy', () {
    const newer = ReleaseInfo(
      version: '0.1.3',
      htmlUrl: 'https://example.test/releases/v0.1.3',
    );

    test('no pending release → both hidden', () async {
      final c = _containerWith(latest: null);
      addTearDown(c.dispose);
      await c.read(updateAvailabilityProvider.future);
      expect(c.read(updateBannerProvider), isNull);
      expect(c.read(updateTrayProvider), isNull);
    });

    test('newer release → both show it', () async {
      final c = _containerWith(latest: newer);
      addTearDown(c.dispose);
      await c.read(updateAvailabilityProvider.future);
      expect(c.read(updateBannerProvider)?.version, '0.1.3');
      expect(c.read(updateTrayProvider)?.version, '0.1.3');
    });

    test('Later hides the banner but not the tray', () async {
      final c = _containerWith(latest: newer);
      addTearDown(c.dispose);
      await c.read(updateAvailabilityProvider.future);
      c.read(updateAvailabilityProvider.notifier).later();
      expect(c.read(updateBannerProvider), isNull);
      expect(c.read(updateTrayProvider)?.version, '0.1.3');
    });

    test('skipped version suppresses both', () async {
      final c = _containerWith(latest: newer, skipped: '0.1.3');
      addTearDown(c.dispose);
      await c.read(updateAvailabilityProvider.future);
      expect(c.read(updateBannerProvider), isNull);
      expect(c.read(updateTrayProvider), isNull);
    });

    test('a release newer than the skipped one still shows', () async {
      final c = _containerWith(latest: newer, skipped: '0.1.2');
      addTearDown(c.dispose);
      await c.read(updateAvailabilityProvider.future);
      expect(c.read(updateBannerProvider)?.version, '0.1.3');
    });

    test('skip() persists the version and clears the banner', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await Settings.load();
      final c = ProviderContainer(
        overrides: [
          updateAvailabilityProvider
              .overrideWith(() => _FakeUpdateNotifier(newer)),
          settingsProvider.overrideWithValue(settings),
          skippedVersionProvider.overrideWith((_) => settings.skippedVersion),
        ],
      );
      addTearDown(c.dispose);
      await c.read(updateAvailabilityProvider.future);
      expect(c.read(updateBannerProvider)?.version, '0.1.3');

      await c.read(updateAvailabilityProvider.notifier).skip();

      expect(settings.skippedVersion, '0.1.3'); // persisted
      expect(c.read(skippedVersionProvider), '0.1.3'); // mirror updated
      expect(c.read(updateBannerProvider), isNull); // banner cleared
      expect(c.read(updateTrayProvider), isNull); // tray cleared
    });
  });
}
