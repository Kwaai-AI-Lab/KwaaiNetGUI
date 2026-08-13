import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DaemonMode { builtIn, system, custom, external }

DaemonMode _parse(String? s) => switch (s) {
  'system' => DaemonMode.system,
  'custom' => DaemonMode.custom,
  'external' => DaemonMode.external,
  _ => DaemonMode.builtIn,
};

String _serialize(DaemonMode m) => switch (m) {
  DaemonMode.builtIn => 'builtin',
  DaemonMode.system => 'system',
  DaemonMode.custom => 'custom',
  DaemonMode.external => 'external',
};

/// Whether [raw] — the value of `KWAAINET_EXTERNAL_DAEMON` — pins the app to
/// [DaemonMode.external].
///
/// Absent, empty, and the usual falsey spellings all mean "not forced", so
/// exporting the variable empty (a common shell accident, and what
/// `FOO=$UNSET` expands to) does not silently take over daemon management.
/// Anything else is true, on the reasoning that someone who sets this at all
/// is opting out of management.
///
/// Split from [Settings.externalDaemonForced] so it is testable — Dart cannot
/// mutate `Platform.environment` in-process. Mirrors `parseGrpcPort`.
bool isExternalDaemonForced(String? raw) {
  final v = raw?.trim().toLowerCase();
  if (v == null || v.isEmpty) return false;
  return v != '0' && v != 'false' && v != 'no' && v != 'off';
}

class Settings {
  Settings._(this._prefs);

  static const _modeKey = 'daemon.mode';
  static const _pathKey = 'daemon.customPath';
  static const _keepInTrayKey = 'window.keepInTrayOnClose';
  static const _startOnStartupKey = 'daemon.startOnStartup';
  static const _localChatKey = 'dev.localChatEnabled';
  static const _skippedVersionKey = 'app.skippedVersion';
  static const _autoDownloadKey = 'app.autoDownloadUpdates';

  final SharedPreferences _prefs;

  static Future<Settings> load() async {
    return Settings._(await SharedPreferences.getInstance());
  }

  /// Env override that forces [DaemonMode.external] regardless of what is
  /// stored on disk. Set it to pin the app to "don't manage the daemon".
  /// Public so the settings UI can name it in the note it shows.
  static const externalDaemonEnvVar = 'KWAAINET_EXTERNAL_DAEMON';

  /// True when [externalDaemonEnvVar] pins external mode.
  static bool get externalDaemonForced =>
      isExternalDaemonForced(Platform.environment[externalDaemonEnvVar]);

  /// The effective daemon mode.
  ///
  /// [externalDaemonEnvVar] wins over the stored value so a throwaway run can
  /// disclaim daemon management without mutating the user's saved settings —
  /// which matters because the on-disk mode is shared with their normal
  /// desktop use of the app. Pointing the GUI at a containerised node with
  /// `KWAAINET_GRPC_PORT` and leaving the mode at its stored default means
  /// the app spawns a *local* daemon at startup that nothing is talking to,
  /// then reports that local process's state in the Status tab while the
  /// data tabs stream from the container.
  DaemonMode get mode =>
      externalDaemonForced ? DaemonMode.external : _storedMode;

  /// The mode as persisted, ignoring [externalDaemonEnvVar]. The settings UI reads
  /// this so the picker still shows — and can still edit — the user's real
  /// stored choice while the override is in force.
  DaemonMode get storedMode => _storedMode;

  DaemonMode get _storedMode => _parse(_prefs.getString(_modeKey));
  String? get customPath => _prefs.getString(_pathKey);

  /// When true, closing the window hides it to the menu-bar tray and the
  /// app keeps running. When false, closing the window quits the app.
  /// Defaults to true (Slack/Discord/Docker Desktop convention).
  bool get keepInTrayOnClose => _prefs.getBool(_keepInTrayKey) ?? true;

  /// When true, the app starts the kwaainet service at boot if it's not
  /// already running. Defaults to true.
  bool get startServiceOnStartup => _prefs.getBool(_startOnStartupKey) ?? true;

  /// Developer preference — when true, the main page shows a second
  /// tab "Local chat" that drives `kwaainet generate` (single-node
  /// local inference). Off by default; meant for development /
  /// fallback when you want to bypass the shard mesh.
  bool get localChatEnabled => _prefs.getBool(_localChatKey) ?? false;

  /// The app release version the user chose to "Skip" from the update
  /// banner (e.g. "0.1.3", normalized without a leading "v"). The banner
  /// stays hidden until a release strictly newer than this ships. Null
  /// when nothing has been skipped.
  String? get skippedVersion => _prefs.getString(_skippedVersionKey);

  /// When true, a detected update downloads and stages itself in the
  /// background; the user is only asked to restart. When false nothing is
  /// fetched until they click Update. Defaults to true.
  bool get autoDownloadUpdates => _prefs.getBool(_autoDownloadKey) ?? true;

  Future<void> setMode(DaemonMode m) async {
    await _prefs.setString(_modeKey, _serialize(m));
  }

  Future<void> setCustomPath(String? p) async {
    if (p == null || p.isEmpty) {
      await _prefs.remove(_pathKey);
    } else {
      await _prefs.setString(_pathKey, p);
    }
  }

  Future<void> setKeepInTrayOnClose(bool v) async {
    await _prefs.setBool(_keepInTrayKey, v);
  }

  Future<void> setStartServiceOnStartup(bool v) async {
    await _prefs.setBool(_startOnStartupKey, v);
  }

  Future<void> setLocalChatEnabled(bool v) async {
    await _prefs.setBool(_localChatKey, v);
  }

  Future<void> setAutoDownloadUpdates(bool v) async {
    await _prefs.setBool(_autoDownloadKey, v);
  }

  Future<void> setSkippedVersion(String? v) async {
    if (v == null || v.isEmpty) {
      await _prefs.remove(_skippedVersionKey);
    } else {
      await _prefs.setString(_skippedVersionKey, v);
    }
  }
}

/// The single app-wide [Settings] instance. Overridden in the
/// [ProviderScope] at app start (see main.dart) so providers — e.g. the
/// update notifier persisting a skipped version — can reach it without
/// threading it through widget constructors.
final settingsProvider = Provider<Settings>((ref) {
  throw UnimplementedError(
    'settingsProvider must be overridden with the app-wide Settings '
    'instance via ProviderScope.overrides.',
  );
});

/// Riverpod-visible mirror of [Settings.localChatEnabled]. Widgets that
/// need to react to the toggle (e.g. the main page's tab bar) watch
/// this provider rather than re-reading the prefs object. Initial
/// value is seeded by main.dart at startup; the Settings UI both
/// writes through to Settings.setLocalChatEnabled() and updates this
/// provider so subscribers see the change immediately.
final localChatEnabledProvider = StateProvider<bool>((_) => false);

/// Riverpod-visible mirror of [Settings.skippedVersion]. The update
/// banner / tray watch this so a "Skip" takes effect immediately without
/// re-reading prefs. Seeded by main.dart at startup; the update notifier
/// writes through to [Settings.setSkippedVersion] and updates this
/// provider so the banner disappears on the same frame. Null = nothing
/// skipped.
final skippedVersionProvider = StateProvider<String?>((_) => null);

/// Riverpod-visible mirror of [Settings.autoDownloadUpdates]. The update
/// controller reads this when a pending release appears to decide whether to
/// start downloading on its own. Seeded by main.dart at startup; the Settings
/// UI writes through to both.
final autoDownloadUpdatesProvider = StateProvider<bool>((_) => true);
