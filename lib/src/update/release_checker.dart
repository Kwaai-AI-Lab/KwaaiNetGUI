import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings.dart';

/// GitHub repo that publishes the GUI app releases. The node binary lives
/// in a *different* repo (Kwaai-AI-Lab/KwaaiNet) with its own self-updater;
/// this check is only for the desktop app.
const _repoSlug = 'Kwaai-AI-Lab/KwaaiNetGUI';
const _latestReleaseApi =
    'https://api.github.com/repos/$_repoSlug/releases/latest';
const _releasesPage = 'https://github.com/$_repoSlug/releases/latest';

/// A published GUI release, as far as the update check cares.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.htmlUrl});

  /// Normalized version string with no leading "v" (e.g. "0.1.3").
  final String version;

  /// The release's web page — where "Update" sends the user.
  final String htmlUrl;
}

/// Fetches the latest GUI release from GitHub and compares versions.
///
/// Stateless and side-effect-free apart from the network GET — all
/// "should we show the banner" policy lives in [UpdateAvailability].
class ReleaseChecker {
  ReleaseChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GETs the latest release. Returns null on any network/parse error or
  /// non-200 status — a failed check should be invisible, never an error
  /// surfaced to the user.
  Future<ReleaseInfo?> fetchLatest() async {
    try {
      final resp = await _client
          .get(
            Uri.parse(_latestReleaseApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is! Map) return null;
      final tag = body['tag_name'];
      if (tag is! String || tag.isEmpty) return null;
      final url = body['html_url'];
      return ReleaseInfo(
        version: normalizeVersion(tag),
        htmlUrl: (url is String && url.isNotEmpty) ? url : _releasesPage,
      );
    } catch (_) {
      return null;
    }
  }

  /// Strips a leading "v" and surrounding whitespace: "v0.1.3" → "0.1.3".
  static String normalizeVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    return s;
  }

  /// True if [latest] is strictly greater than [current] under a simple
  /// major.minor.patch compare. Mirrors the Rust node updater's
  /// `is_newer()` (kwaai-cli/src/updater.rs): split on '.', missing or
  /// non-numeric parts count as 0, tuple compare. Both inputs are
  /// normalized first, so a leading "v" on either side is fine.
  static bool isNewer(String latest, String current) {
    (int, int, int) parse(String s) {
      final parts = normalizeVersion(s)
          .split('.')
          .map((p) => int.tryParse(p) ?? 0)
          .toList();
      return (
        parts.isNotEmpty ? parts[0] : 0,
        parts.length > 1 ? parts[1] : 0,
        parts.length > 2 ? parts[2] : 0,
      );
    }

    final a = parse(latest);
    final b = parse(current);
    if (a.$1 != b.$1) return a.$1 > b.$1;
    if (a.$2 != b.$2) return a.$2 > b.$2;
    return a.$3 > b.$3;
  }

  void dispose() => _client.close();
}

final releaseCheckerProvider = Provider<ReleaseChecker>((ref) {
  final checker = ReleaseChecker();
  ref.onDispose(checker.dispose);
  return checker;
});

/// Result of the startup update check: the newer release (if any) and the
/// running app's version. `latest` is null when no check has completed or
/// the running build is already current.
class UpdateAvailability {
  const UpdateAvailability({this.latest, required this.current});

  /// The newer release, or null if up to date / not yet checked.
  final ReleaseInfo? latest;

  /// The running app's version, normalized (no leading "v").
  final String current;

  UpdateAvailability copyWith({
    ReleaseInfo? latest,
    bool clearLatest = false,
    String? current,
  }) {
    return UpdateAvailability(
      latest: clearLatest ? null : (latest ?? this.latest),
      current: current ?? this.current,
    );
  }
}

/// Drives the startup update check and owns the session-only "Later"
/// dismissal. The durable "Skip" lives in [Settings.skippedVersion] /
/// [skippedVersionProvider]; this notifier writes through to both.
///
/// Only hits the network in release builds (and honours a
/// KWAAINET_GUI_FORCE_UPDATE_CHECK escape hatch for manual testing), so
/// `flutter run` in debug never calls GitHub.
class UpdateAvailabilityNotifier extends AsyncNotifier<UpdateAvailability> {
  /// Set by "Later": hides the banner for this session only. Not persisted,
  /// so it returns on next launch.
  bool _dismissedForSession = false;

  bool get dismissedForSession => _dismissedForSession;

  @override
  Future<UpdateAvailability> build() async {
    final info = await PackageInfo.fromPlatform();
    final current = ReleaseChecker.normalizeVersion(info.version);

    final enabled = kReleaseMode ||
        const bool.fromEnvironment('KWAAINET_GUI_FORCE_UPDATE_CHECK');
    if (!enabled) {
      return UpdateAvailability(current: current);
    }

    final latest = await ref.read(releaseCheckerProvider).fetchLatest();
    if (latest != null && ReleaseChecker.isNewer(latest.version, current)) {
      return UpdateAvailability(latest: latest, current: current);
    }
    return UpdateAvailability(current: current);
  }

  /// Opens the release page in the browser. The app can't self-replace a
  /// running bundle, so the user downloads + swaps the new build manually.
  Future<void> openReleasePage() async {
    final url = state.valueOrNull?.latest?.htmlUrl ?? _releasesPage;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// "Later" — hide for this session; the banner returns on next launch.
  void later() {
    if (_dismissedForSession) return;
    _dismissedForSession = true;
    // Re-emit current state so watchers (banner) recompute visibility.
    state = AsyncData(state.valueOrNull ??
        const UpdateAvailability(current: ''));
  }

  /// "Skip" — persist this version so the banner stays hidden until a
  /// strictly newer release ships. Writes through to durable [Settings]
  /// and the [skippedVersionProvider] mirror so the banner clears now.
  Future<void> skip() async {
    final version = state.valueOrNull?.latest?.version;
    if (version == null) return;
    await ref.read(settingsProvider).setSkippedVersion(version);
    ref.read(skippedVersionProvider.notifier).state = version;
  }
}

final updateAvailabilityProvider =
    AsyncNotifierProvider<UpdateAvailabilityNotifier, UpdateAvailability>(
  UpdateAvailabilityNotifier.new,
);

/// The release to offer right now, or null if there's nothing to show.
///
/// Centralizes the visibility policy used by both the banner and the tray:
/// a newer release exists, it wasn't dismissed this session (banner-only —
/// the tray passes `respectSession: false`), and it isn't a version the
/// user durably skipped (unless an even newer one has since shipped).
ReleaseInfo? pendingUpdate(Ref ref, {required bool respectSession}) {
  final notifier = ref.watch(updateAvailabilityProvider.notifier);
  final avail = ref.watch(updateAvailabilityProvider).valueOrNull;
  final latest = avail?.latest;
  if (latest == null) return null;
  if (respectSession && notifier.dismissedForSession) return null;

  final skipped = ref.watch(skippedVersionProvider);
  if (skipped != null && skipped.isNotEmpty) {
    // Suppress unless this release is strictly newer than what was skipped.
    if (!ReleaseChecker.isNewer(latest.version, skipped)) return null;
  }
  return latest;
}

/// Banner visibility: pending update honouring the session "Later".
final updateBannerProvider = Provider<ReleaseInfo?>((ref) {
  return pendingUpdate(ref, respectSession: true);
});

/// Tray visibility: pending update ignoring the session "Later" (the tray
/// item is a persistent affordance; only "Skip" suppresses it).
final updateTrayProvider = Provider<ReleaseInfo?>((ref) {
  return pendingUpdate(ref, respectSession: false);
});
