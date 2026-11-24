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

/// `shard.backend` — the engine `shard serve` uses. Absent means auto.
enum ShardBackend {
  auto,
  candle,
  mlx;

  static ShardBackend fromYaml(Object? v) => switch (v) {
    'candle' || 'blocks' => ShardBackend.candle,
    'mlx' => ShardBackend.mlx,
    _ => ShardBackend.auto,
  };
}

/// `vpk_mode` — this node's VPK role. Absent means none chosen.
enum VpkMode {
  bob,
  eve,
  both;

  static VpkMode? fromYaml(Object? v) =>
      VpkMode.values.where((m) => m.name == v).firstOrNull;
}

/// Block counts `shard serve` accepts; anything else snaps to the nearest.
const validBlockCounts = [4, 8, 16, 32];

/// The daemon's `blocks` when the key is absent (and KWAAINET_BLOCKS unset).
const defaultBlocks = 8;

/// The daemon's `rebalance_interval_secs` and `rebalance_min_redundancy`.
const defaultRebalanceIntervalSecs = 300;
const defaultRebalanceMinRedundancy = 1;

/// Marks a [ConfigSnapshot.copyWith] argument as "not passed", so a nullable
/// field can be cleared by passing null.
const Object _keep = Object();

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
    this.blocks,
    this.startBlock,
    this.startBlockAuto = false,
    this.useGpu = true,
    this.shardBackend = ShardBackend.auto,
    this.autoRebalance = false,
    this.rebalanceIntervalSecs,
    this.rebalanceMinRedundancy,
    this.forwardChainServe = true,
    this.publicName = '',
    this.vpkEnabled = false,
    this.vpkMode,
    this.storageDataDir,
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

  /// `blocks` — how many transformer blocks this node serves. Null = the
  /// daemon's default ([defaultBlocks]).
  final int? blocks;

  /// `start_block` — the first block served. Null = never placed, so
  /// `shard serve` picks a gap to fill.
  final int? startBlock;

  /// `start_block_auto` — [startBlock] was chosen by auto-assignment, not
  /// pinned by the operator, so the rebalancer may still move it.
  final bool startBlockAuto;

  /// `use_gpu`.
  final bool useGpu;

  /// `shard.backend`.
  final ShardBackend shardBackend;

  /// `auto_rebalance` — move this node's blocks to fill coverage gaps.
  /// Never moves an operator-pinned range.
  final bool autoRebalance;

  /// `rebalance_interval_secs`. Null = [defaultRebalanceIntervalSecs].
  final int? rebalanceIntervalSecs;

  /// `rebalance_min_redundancy`. Null = [defaultRebalanceMinRedundancy].
  final int? rebalanceMinRedundancy;

  /// `shard.forward_chain.serve` — forward other nodes' chain steps onward.
  final bool forwardChainServe;

  /// `public_name` — the name peers and the network map show. Empty = none.
  final String publicName;

  /// `vpk_enabled` — poll the local VPK service and advertise it on the DHT.
  final bool vpkEnabled;

  /// `vpk_mode`. Null = no role chosen.
  final VpkMode? vpkMode;

  /// `storage.data_dir`. Null when the storage section hasn't been
  /// initialised yet — the GUI never creates that section itself.
  final String? storageDataDir;

  /// Nullable fields take [_keep] by default, so passing null clears them.
  ConfigSnapshot copyWith({
    String? model,
    bool? shardingEnabled,
    bool? storageEnabled,
    Object? storageCapacityGb = _keep,
    Object? port = _keep,
    String? publicIp,
    List<String>? initialPeers,
    bool? forcePrivate,
    bool? enableUpnp,
    bool? enableQuic,
    Ipv6Mode? ipv6,
    Object? maxConnections = _keep,
    bool? healthEnabled,
    String? healthEndpoint,
    Object? blocks = _keep,
    Object? startBlock = _keep,
    bool? startBlockAuto,
    bool? useGpu,
    ShardBackend? shardBackend,
    bool? autoRebalance,
    Object? rebalanceIntervalSecs = _keep,
    Object? rebalanceMinRedundancy = _keep,
    bool? forwardChainServe,
    String? publicName,
    bool? vpkEnabled,
    Object? vpkMode = _keep,
    Object? storageDataDir = _keep,
  }) {
    T pick<T>(Object? v, T current) => identical(v, _keep) ? current : v as T;
    return ConfigSnapshot(
      model: model ?? this.model,
      shardingEnabled: shardingEnabled ?? this.shardingEnabled,
      storageEnabled: storageEnabled ?? this.storageEnabled,
      storageCapacityGb: pick(storageCapacityGb, this.storageCapacityGb),
      port: pick(port, this.port),
      publicIp: publicIp ?? this.publicIp,
      initialPeers: initialPeers ?? this.initialPeers,
      forcePrivate: forcePrivate ?? this.forcePrivate,
      enableUpnp: enableUpnp ?? this.enableUpnp,
      enableQuic: enableQuic ?? this.enableQuic,
      ipv6: ipv6 ?? this.ipv6,
      maxConnections: pick(maxConnections, this.maxConnections),
      healthEnabled: healthEnabled ?? this.healthEnabled,
      healthEndpoint: healthEndpoint ?? this.healthEndpoint,
      blocks: pick(blocks, this.blocks),
      startBlock: pick(startBlock, this.startBlock),
      startBlockAuto: startBlockAuto ?? this.startBlockAuto,
      useGpu: useGpu ?? this.useGpu,
      shardBackend: shardBackend ?? this.shardBackend,
      autoRebalance: autoRebalance ?? this.autoRebalance,
      rebalanceIntervalSecs: pick(
        rebalanceIntervalSecs,
        this.rebalanceIntervalSecs,
      ),
      rebalanceMinRedundancy: pick(
        rebalanceMinRedundancy,
        this.rebalanceMinRedundancy,
      ),
      forwardChainServe: forwardChainServe ?? this.forwardChainServe,
      publicName: publicName ?? this.publicName,
      vpkEnabled: vpkEnabled ?? this.vpkEnabled,
      vpkMode: pick(vpkMode, this.vpkMode),
      storageDataDir: pick(storageDataDir, this.storageDataDir),
    );
  }
}

/// The daemon's answer length when `shard.max_tokens` is unset.
const defaultMaxTokens = 200;

/// Largest answer length the GUI accepts, to catch a stray extra digit.
const maxTokensCeiling = 4096;

/// The `config.yaml` keys the Chat tab edits. Unlike [ConfigSnapshot] they
/// are read on every run, so they are saved straight away — no Apply, no
/// restart.
class ChatConfig {
  const ChatConfig({this.maxTokens, this.forwardChainOriginate = false});

  /// `shard.max_tokens`. Null = the daemon's default (200).
  final int? maxTokens;

  /// `shard.forward_chain.originate` — route this node's own runs as a
  /// forward chain instead of star.
  final bool forwardChainOriginate;
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
    // Shard serving is opt-in on the daemon: absent means off.
    shardingEnabled: false,
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

  /// The parsed file, or null when it is missing or not a map.
  static YamlMap? _readDoc() {
    final f = File(path);
    if (!f.existsSync()) {
      _log('config.yaml missing — returning defaults');
      return null;
    }
    final doc = loadYaml(f.readAsStringSync());
    if (doc is! YamlMap) {
      _log('config.yaml is not a map — returning defaults');
      return null;
    }
    return doc;
  }

  /// Load the current config, falling back to sensible defaults if the file
  /// is missing or fields are unset.
  static Future<ConfigSnapshot> load() async {
    try {
      final doc = _readDoc();
      return doc == null ? _defaults : parse(doc);
    } catch (e) {
      _log('failed to parse config.yaml: $e — returning defaults');
      return _defaults;
    }
  }

  /// Read a [ConfigSnapshot] out of a parsed config.yaml.
  @visibleForTesting
  static ConfigSnapshot parse(YamlMap doc) {
    final contribute = doc['contribute'];
    final storage = doc['storage'];
    final health = doc['health_monitoring'];
    final shard = doc['shard'];
    final forwardChain = shard is YamlMap ? shard['forward_chain'] : null;
    final rawPeers = doc['initial_peers'];
    return ConfigSnapshot(
      model: (doc['model'] as String?) ?? '',
      shardingEnabled: contribute is YamlMap
          ? (contribute['shards'] as bool? ?? false)
          : false,
      storageEnabled: contribute is YamlMap
          ? (contribute['storage'] as bool? ?? true)
          : true,
      storageCapacityGb: storage is YamlMap
          ? (storage['capacity_gb'] as num?)?.toDouble()
          : null,
      port: (doc['port'] as num?)?.toInt(),
      publicIp: (doc['public_ip'] as String?) ?? '',
      initialPeers: rawPeers is YamlList
          ? rawPeers.map((e) => e.toString()).toList()
          : <String>[],
      forcePrivate: (doc['force_private'] as bool?) ?? false,
      enableUpnp: (doc['enable_upnp'] as bool?) ?? true,
      enableQuic: (doc['enable_quic'] as bool?) ?? false,
      ipv6: Ipv6Mode.fromYaml(doc['ipv6']),
      maxConnections: (doc['max_connections'] as num?)?.toInt(),
      healthEnabled: health is YamlMap
          ? (health['enabled'] as bool? ?? true)
          : true,
      healthEndpoint: health is YamlMap
          ? (health['api_endpoint'] as String? ?? '')
          : '',
      blocks: (doc['blocks'] as num?)?.toInt(),
      startBlock: (doc['start_block'] as num?)?.toInt(),
      startBlockAuto: (doc['start_block_auto'] as bool?) ?? false,
      useGpu: (doc['use_gpu'] as bool?) ?? true,
      shardBackend: ShardBackend.fromYaml(
        shard is YamlMap ? shard['backend'] : null,
      ),
      autoRebalance: (doc['auto_rebalance'] as bool?) ?? false,
      rebalanceIntervalSecs: (doc['rebalance_interval_secs'] as num?)?.toInt(),
      rebalanceMinRedundancy: (doc['rebalance_min_redundancy'] as num?)
          ?.toInt(),
      forwardChainServe: forwardChain is YamlMap
          ? (forwardChain['serve'] as bool? ?? true)
          : true,
      publicName: (doc['public_name'] as String?) ?? '',
      vpkEnabled: (doc['vpk_enabled'] as bool?) ?? false,
      vpkMode: VpkMode.fromYaml(doc['vpk_mode']),
      storageDataDir: storage is YamlMap
          ? storage['data_dir'] as String?
          : null,
    );
  }

  /// Write [updated] back to ~/.kwaainet/config.yaml, preserving all other
  /// keys + comments + ordering via [YamlEditor].
  ///
  /// Only the keys controlled by the Features UI are touched.
  static Future<void> save(ConfigSnapshot updated) async {
    _edit((editor) => apply(editor, updated));
  }

  /// Write [updated]'s keys into [editor].
  @visibleForTesting
  static void apply(YamlEditor editor, ConfigSnapshot updated) {
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
    _setOrRemove(editor, ['ipv6'], updated.ipv6.yamlValue);
    // Unset means "let the daemon decide". Written as an explicit null the
    // key would be present with a value serde cannot read into a usize, so
    // clear it instead of writing one.
    _setOrRemove(editor, ['max_connections'], updated.maxConnections);
    _setScalar(editor, ['health_monitoring', 'enabled'], updated.healthEnabled);
    _setScalar(editor, [
      'health_monitoring',
      'api_endpoint',
    ], updated.healthEndpoint);

    // The keys below are written only when they differ from the daemon's
    // default, so the file records choices rather than defaults.
    _setOrRemove(editor, ['blocks'], updated.blocks);
    // An unplaced node has neither key. A pin has no `start_block_auto`,
    // which is what stops the rebalancer moving it.
    _setOrRemove(editor, ['start_block'], updated.startBlock);
    _setOrRemove(editor, [
      'start_block_auto',
    ], updated.startBlock != null && updated.startBlockAuto ? true : null);
    _setOrRemove(editor, ['use_gpu'], updated.useGpu ? null : false);
    _setOrRemove(
      editor,
      ['shard', 'backend'],
      updated.shardBackend == ShardBackend.auto
          ? null
          : updated.shardBackend.name,
    );
    _setOrRemove(editor, [
      'auto_rebalance',
    ], updated.autoRebalance ? true : null);
    _setOrRemove(editor, [
      'rebalance_interval_secs',
    ], updated.rebalanceIntervalSecs);
    _setOrRemove(editor, [
      'rebalance_min_redundancy',
    ], updated.rebalanceMinRedundancy);
    _setOrRemove(editor, [
      'shard',
      'forward_chain',
      'serve',
    ], updated.forwardChainServe ? null : false);
    _setOrRemove(editor, [
      'public_name',
    ], updated.publicName.isEmpty ? null : updated.publicName);
    _setOrRemove(editor, ['vpk_enabled'], updated.vpkEnabled ? true : null);
    _setOrRemove(editor, ['vpk_mode'], updated.vpkMode?.name);
    // Only an initialised storage section takes a data_dir: writing one into
    // a fresh file would make the daemon think storage was set up.
    final dataDir = updated.storageDataDir;
    if (dataDir != null && dataDir.isNotEmpty && _has(editor, ['storage'])) {
      _setScalar(editor, ['storage', 'data_dir'], dataDir);
    }
  }

  /// The Chat tab's keys; defaults when the file is missing or unreadable.
  static Future<ChatConfig> loadChat() async {
    try {
      final doc = _readDoc();
      return doc == null ? const ChatConfig() : parseChat(doc);
    } catch (e) {
      _log('failed to parse config.yaml: $e — returning chat defaults');
      return const ChatConfig();
    }
  }

  @visibleForTesting
  static ChatConfig parseChat(YamlMap doc) {
    final shard = doc['shard'];
    final forwardChain = shard is YamlMap ? shard['forward_chain'] : null;
    final maxTokens = shard is YamlMap
        ? (shard['max_tokens'] as num?)?.toInt()
        : null;
    return ChatConfig(
      // The daemon reads 0 as its default, so the GUI does too.
      maxTokens: maxTokens != null && maxTokens > 0 ? maxTokens : null,
      forwardChainOriginate: forwardChain is YamlMap
          ? (forwardChain['originate'] as bool? ?? false)
          : false,
    );
  }

  /// Save the Chat tab's keys straight away, touching nothing else.
  static Future<void> saveChat(ChatConfig chat) async {
    _edit((editor) => applyChat(editor, chat));
  }

  @visibleForTesting
  static void applyChat(YamlEditor editor, ChatConfig chat) {
    _setOrRemove(editor, ['shard', 'max_tokens'], chat.maxTokens);
    _setOrRemove(editor, [
      'shard',
      'forward_chain',
      'originate',
    ], chat.forwardChainOriginate ? true : null);
  }

  /// Read config.yaml, let [change] edit it, and write it back.
  static void _edit(void Function(YamlEditor) change) {
    final f = File(path);
    final dir = Directory(KwaainetPaths.home);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final existing = f.existsSync() ? f.readAsStringSync() : '';
    final editor = YamlEditor(existing.isEmpty ? '{}\n' : existing);
    change(editor);
    f.writeAsStringSync(editor.toString());
    _log('wrote ${f.path}');
  }

  static bool _has(YamlEditor editor, List<String> keyPath) {
    try {
      editor.parseAt(keyPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Write [value] at [keyPath], or drop the key when it is null.
  static void _setOrRemove(
    YamlEditor editor,
    List<String> keyPath,
    Object? value,
  ) {
    if (value != null) {
      _setScalar(editor, keyPath, value);
    } else if (_has(editor, keyPath)) {
      editor.remove(keyPath);
    }
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
      if (!_has(editor, parentPath)) {
        editor.update(parentPath, <String, dynamic>{});
      }
    }
    editor.update(keyPath, value);
  }
}
