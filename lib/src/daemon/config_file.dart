import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'paths.dart';

void _log(String msg) {
  stderr.writeln('[config-file] $msg');
}

/// `ipv6` — auto binds /ip6/:: and tolerates failure, on refuses to start
/// without an IPv6 listener, off never binds it. Absent means auto.
enum Ipv6Mode {
  auto,
  on,
  off;

  /// YAML types `true` as a bool but `auto` as a String, so this takes
  /// Object?. Anything unrecognised reads as auto, same as an absent key.
  static Ipv6Mode fromYaml(Object? v) {
    if (v is bool) return v ? Ipv6Mode.on : Ipv6Mode.off;
    switch (v is String ? v.toLowerCase() : null) {
      case 'true':
        return Ipv6Mode.on;
      case 'false':
        return Ipv6Mode.off;
      default:
        return Ipv6Mode.auto;
    }
  }

  /// What to write to config.yaml; null means remove the key, since absent
  /// is how auto is spelled.
  Object? get yamlValue => switch (this) {
    Ipv6Mode.auto => null,
    Ipv6Mode.on => true,
    Ipv6Mode.off => false,
  };
}

/// Subset of ~/.kwaainet/config.yaml that the GUI surfaces in the Features
/// settings. Other keys in the file are read but never touched on write.
class ConfigSnapshot {
  const ConfigSnapshot({
    required this.model,
    required this.shardingEnabled,
    required this.storageEnabled,
    required this.storageCapacityGb,
    required this.port,
    required this.publicIp,
    required this.initialPeers,
    required this.forcePrivate,
    required this.enableUpnp,
    required this.enableQuic,
    required this.ipv6,
    required this.maxConnections,
    required this.healthEnabled,
    required this.healthEndpoint,
  });

  /// Top-level `model` — the HuggingFace model id this node serves.
  final String model;

  /// `contribute.shards` — true if the daemon should auto-start shard
  /// serving on boot.
  final bool shardingEnabled;

  /// `contribute.storage` — true if the daemon should auto-start the
  /// storage API on boot.
  final bool storageEnabled;

  /// `storage.capacity_gb` — how much disk the storage feature offers.
  /// Null when the storage section hasn't been initialised yet.
  final double? storageCapacityGb;

  /// `port` — TCP port the libp2p listener binds. Null = key absent /
  /// daemon picks one.
  final int? port;

  /// `public_ip` — externally-reachable IP this node announces. Empty
  /// string means auto-detect (NAT-PMP / observed address).
  final String publicIp;

  /// `initial_peers` — list of multiaddrs used to bootstrap the DHT.
  final List<String> initialPeers;

  /// `force_private` — when true, the daemon assumes its reachability
  /// is "Private" and skips AutoNAT probing. Forces relayed connections
  /// (no hole-punching attempts on incoming dials).
  final bool forcePrivate;

  /// `enable_upnp` — ask the local gateway to map our listen port.
  ///
  /// Defaults true on the daemon side. Turning it off is how you get a
  /// genuinely NATed node without touching router settings; it also stops the
  /// node asking the router to open a port at all.
  final bool enableUpnp;

  /// `enable_quic` — listen on and dial QUIC as well as TCP.
  ///
  /// Off by default, matching the daemon: some networks block or throttle
  /// UDP. Bound at startup, so changing it needs a restart.
  final bool enableQuic;

  /// `ipv6` — whether the daemon binds an IPv6 listener. Bound at startup,
  /// so changing it needs a restart.
  final Ipv6Mode ipv6;

  /// `max_connections` — ceiling on simultaneously established connections,
  /// inbound and outbound. Null = key absent, so the daemon's own default
  /// (100) applies. The daemon rejects anything below 8.
  final int? maxConnections;

  /// `health_monitoring.enabled`.
  final bool healthEnabled;

  /// `health_monitoring.api_endpoint`.
  final String healthEndpoint;

  ConfigSnapshot copyWith({
    String? model,
    bool? shardingEnabled,
    bool? storageEnabled,
    double? storageCapacityGb,
    int? port,
    String? publicIp,
    List<String>? initialPeers,
    bool? forcePrivate,
    bool? enableUpnp,
    bool? enableQuic,
    Ipv6Mode? ipv6,
    int? maxConnections,
    bool? healthEnabled,
    String? healthEndpoint,
  }) {
    return ConfigSnapshot(
      model: model ?? this.model,
      shardingEnabled: shardingEnabled ?? this.shardingEnabled,
      storageEnabled: storageEnabled ?? this.storageEnabled,
      storageCapacityGb: storageCapacityGb ?? this.storageCapacityGb,
      port: port ?? this.port,
      publicIp: publicIp ?? this.publicIp,
      initialPeers: initialPeers ?? this.initialPeers,
      forcePrivate: forcePrivate ?? this.forcePrivate,
      enableUpnp: enableUpnp ?? this.enableUpnp,
      enableQuic: enableQuic ?? this.enableQuic,
      ipv6: ipv6 ?? this.ipv6,
      maxConnections: maxConnections ?? this.maxConnections,
      healthEnabled: healthEnabled ?? this.healthEnabled,
      healthEndpoint: healthEndpoint ?? this.healthEndpoint,
    );
  }
}

class ConfigFile {
  ConfigFile._();

  /// Path to ~/.kwaainet/config.yaml.
  static String get path => KwaainetPaths.configFile;

  /// The snapshot returned when config.yaml is missing or unreadable.
  @visibleForTesting
  static ConfigSnapshot get defaults => _defaults;

  static const ConfigSnapshot _defaults = ConfigSnapshot(
    model: '',
    shardingEnabled: true,
    storageEnabled: true,
    storageCapacityGb: null,
    port: null,
    publicIp: '',
    initialPeers: [],
    forcePrivate: false,
    // Mirror the daemon's own defaults, so a config that has never set a
    // key reads the same here as it behaves there.
    enableUpnp: true,
    enableQuic: false,
    ipv6: Ipv6Mode.auto,
    maxConnections: null,
    healthEnabled: true,
    healthEndpoint: '',
  );

  /// Load the current config, falling back to sensible defaults if the file
  /// is missing or fields are unset.
  static Future<ConfigSnapshot> load() async {
    final f = File(path);
    if (!f.existsSync()) {
      _log('config.yaml missing — returning defaults');
      return _defaults;
    }
    try {
      final raw = f.readAsStringSync();
      final doc = loadYaml(raw);
      if (doc is! YamlMap) {
        _log('config.yaml is not a map — returning defaults');
        return _defaults;
      }
      final model = (doc['model'] as String?) ?? '';
      final contribute = doc['contribute'];
      final shardingEnabled = contribute is YamlMap
          ? (contribute['shards'] as bool? ?? true)
          : true;
      final storageEnabled = contribute is YamlMap
          ? (contribute['storage'] as bool? ?? true)
          : true;
      final storage = doc['storage'];
      final storageCapacityGb = storage is YamlMap
          ? (storage['capacity_gb'] as num?)?.toDouble()
          : null;
      final port = (doc['port'] as num?)?.toInt();
      final publicIp = (doc['public_ip'] as String?) ?? '';
      final rawPeers = doc['initial_peers'];
      final initialPeers = rawPeers is YamlList
          ? rawPeers.map((e) => e.toString()).toList()
          : <String>[];
      final forcePrivate = (doc['force_private'] as bool?) ?? false;
      final enableUpnp = (doc['enable_upnp'] as bool?) ?? true;
      final enableQuic = (doc['enable_quic'] as bool?) ?? false;
      final ipv6 = Ipv6Mode.fromYaml(doc['ipv6']);
      final maxConnections = (doc['max_connections'] as num?)?.toInt();
      final health = doc['health_monitoring'];
      final healthEnabled = health is YamlMap
          ? (health['enabled'] as bool? ?? true)
          : true;
      final healthEndpoint = health is YamlMap
          ? (health['api_endpoint'] as String? ?? '')
          : '';
      return ConfigSnapshot(
        model: model,
        shardingEnabled: shardingEnabled,
        storageEnabled: storageEnabled,
        storageCapacityGb: storageCapacityGb,
        port: port,
        publicIp: publicIp,
        initialPeers: initialPeers,
        forcePrivate: forcePrivate,
        enableUpnp: enableUpnp,
        enableQuic: enableQuic,
        ipv6: ipv6,
        maxConnections: maxConnections,
        healthEnabled: healthEnabled,
        healthEndpoint: healthEndpoint,
      );
    } catch (e) {
      _log('failed to parse config.yaml: $e — returning defaults');
      return _defaults;
    }
  }

  /// Write [updated] back to ~/.kwaainet/config.yaml, preserving all other
  /// keys + comments + ordering via [YamlEditor].
  ///
  /// Only the keys controlled by the Features UI are touched.
  static Future<void> save(ConfigSnapshot updated) async {
    final f = File(path);
    final dir = Directory(KwaainetPaths.home);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final existing = f.existsSync() ? f.readAsStringSync() : '';
    final editor = YamlEditor(existing.isEmpty ? '{}\n' : existing);

    _setScalar(editor, ['model'], updated.model);
    _setScalar(editor, ['contribute', 'shards'], updated.shardingEnabled);
    _setScalar(editor, ['contribute', 'storage'], updated.storageEnabled);
    if (updated.storageCapacityGb != null) {
      _setScalar(editor, ['storage', 'capacity_gb'], updated.storageCapacityGb);
    }
    _setScalar(editor, ['port'], updated.port);
    _setScalar(editor, ['public_ip'], updated.publicIp);
    _setScalar(editor, ['initial_peers'], updated.initialPeers);
    _setScalar(editor, ['force_private'], updated.forcePrivate);
    _setScalar(editor, ['enable_upnp'], updated.enableUpnp);
    _setScalar(editor, ['enable_quic'], updated.enableQuic);
    // Auto is spelled "key absent", so clear it rather than writing a null.
    final ipv6Value = updated.ipv6.yamlValue;
    if (ipv6Value != null) {
      _setScalar(editor, ['ipv6'], ipv6Value);
    } else {
      _removeIfPresent(editor, ['ipv6']);
    }
    // Unset means "let the daemon decide". Written as an explicit null the
    // key would be present with a value serde cannot read into a usize, so
    // clear it instead of writing one.
    if (updated.maxConnections != null) {
      _setScalar(editor, ['max_connections'], updated.maxConnections);
    } else {
      _removeIfPresent(editor, ['max_connections']);
    }
    _setScalar(editor, ['health_monitoring', 'enabled'], updated.healthEnabled);
    _setScalar(editor, [
      'health_monitoring',
      'api_endpoint',
    ], updated.healthEndpoint);

    f.writeAsStringSync(editor.toString());
    _log('wrote ${f.path}');
  }

  /// Drop a key only if it is actually there — [YamlEditor.remove] throws
  /// on a path that does not exist.
  static void _removeIfPresent(YamlEditor editor, List<String> keyPath) {
    try {
      editor.parseAt(keyPath);
    } catch (_) {
      return;
    }
    editor.remove(keyPath);
  }

  /// Update a single key path. yaml_edit's [YamlEditor.update] throws if any
  /// parent is missing — walk the path and create intermediate maps as
  /// needed.
  static void _setScalar(
    YamlEditor editor,
    List<String> keyPath,
    Object? value,
  ) {
    for (var i = 0; i < keyPath.length - 1; i++) {
      final parentPath = keyPath.sublist(0, i + 1);
      try {
        editor.parseAt(parentPath);
      } catch (_) {
        // Parent missing — create an empty map for it.
        editor.update(parentPath, <String, dynamic>{});
      }
    }
    editor.update(keyPath, value);
  }
}
