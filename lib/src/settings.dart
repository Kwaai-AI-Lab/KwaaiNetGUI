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

class Settings {
  Settings._(this._prefs);

  static const _modeKey = 'daemon.mode';
  static const _pathKey = 'daemon.customPath';
  static const _keepInTrayKey = 'window.keepInTrayOnClose';
  static const _startOnStartupKey = 'daemon.startOnStartup';
  static const _localChatKey = 'dev.localChatEnabled';
  static const _skippedVersionKey = 'app.skippedVersion';

  final SharedPreferences _prefs;

  static Future<Settings> load() async {
    return Settings._(await SharedPreferences.getInstance());
  }

  DaemonMode get mode => _parse(_prefs.getString(_modeKey));
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
