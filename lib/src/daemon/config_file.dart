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

  /// What to write to config.yaml.
  Object get yamlValue => switch (this) {
    Ipv6Mode.auto => 'auto',
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

/// The daemon's defaults for keys the GUI shows greyed while unset.
const defaultModel = 'unsloth/Llama-3.1-8B-Instruct';
const defaultPort = 8080;
const defaultMaxConnections = 100;
const defaultStorageCapacityGb = 5.0;
const defaultHealthEndpoint = 'https://map.kwaai.ai/api/v1/state';

/// Marks a [ConfigSnapshot.copyWith] argument as "not passed", so a nullable
/// field can be cleared by passing null.
const Object _keep = Object();

/// Subset of ~/.kwaainet/config.yaml that the GUI surfaces in the Features
/// settings. Other keys in the file are read but never touched on write.
///
/// Every field is null while its key is absent from the file, so the UI can
/// show a key the file sets as a concrete value and an absent one as the
/// daemon's default, greyed. The `…Effective` getters fold the default in.
class ConfigSnapshot {
  const ConfigSnapshot({
    this.model,
    this.shardingEnabled,
    this.storageEnabled,
    this.storageCapacityGb,
    this.port,
    this.publicIp,
    this.initialPeers,
    this.forcePrivate,
    this.enableUpnp,
    this.enableQuic,
    this.ipv6,
    this.maxConnections,
    this.healthEnabled,
    this.healthEndpoint,
    this.blocks,
    this.startBlock,
    this.startBlockAuto = false,
    this.useGpu,
    this.shardBackend,
    this.autoRebalance,
    this.rebalanceIntervalSecs,
    this.rebalanceMinRedundancy,
    this.forwardChainServe,
    this.publicName,
    this.vpkEnabled,
    this.vpkMode,
    this.storageDataDir,
  });

  /// Top-level `model` — the HuggingFace model id this node serves.
  final String? model;

  /// `contribute.shards` — auto-start shard serving on boot. Opt-in.
  final bool? shardingEnabled;

  /// `contribute.storage` — auto-start the storage API on boot.
  final bool? storageEnabled;

  /// `storage.capacity_gb` — how much disk the storage feature offers.
  final double? storageCapacityGb;

  /// `port` — TCP port the libp2p listener binds.
  final int? port;

  /// `public_ip` — externally-reachable IP this node announces. Absent means
  /// auto-detect (NAT-PMP / observed address).
  final String? publicIp;

  /// `initial_peers` — multiaddrs used to bootstrap the DHT. Absent means
  /// the KwaaiNet bootstrap peers.
  final List<String>? initialPeers;

  /// `force_private` — assume "Private" reachability and skip AutoNAT.
  final bool? forcePrivate;

  /// `enable_upnp` — ask the local gateway to map our listen port.
  final bool? enableUpnp;

  /// `enable_quic` — listen on and dial QUIC as well as TCP.
  final bool? enableQuic;

  /// `ipv6` — whether the daemon binds an IPv6 listener.
  final Ipv6Mode? ipv6;

  /// `max_connections` — ceiling on established connections. The daemon
  /// rejects anything below 8.
  final int? maxConnections;

  /// `health_monitoring.enabled`.
  final bool? healthEnabled;

  /// `health_monitoring.api_endpoint`.
  final String? healthEndpoint;

  /// `blocks` — how many transformer blocks this node serves.
  final int? blocks;

  /// `start_block` — the first block served. Null = never placed, so
  /// `shard serve` picks a gap to fill.
  final int? startBlock;

  /// `start_block_auto` — [startBlock] was chosen by auto-assignment, not
  /// pinned by the operator, so the rebalancer may still move it.
  final bool startBlockAuto;

  /// `use_gpu`.
  final bool? useGpu;

  /// `shard.backend`.
  final ShardBackend? shardBackend;

  /// `auto_rebalance` — move this node's blocks to fill coverage gaps.
  /// Never moves an operator-pinned range.
  final bool? autoRebalance;

  /// `rebalance_interval_secs`.
  final int? rebalanceIntervalSecs;

  /// `rebalance_min_redundancy`.
  final int? rebalanceMinRedundancy;

  /// `shard.forward_chain.serve` — forward other nodes' chain steps onward.
  final bool? forwardChainServe;

  /// `public_name` — the name peers and the network map show.
  final String? publicName;

  /// `vpk_enabled` — poll the local VPK service and advertise it on the DHT.
  final bool? vpkEnabled;

  /// `vpk_mode`. Null = no role chosen.
  final VpkMode? vpkMode;

  /// `storage.data_dir`. Null when the storage section hasn't been
  /// initialised yet — the GUI never creates that section itself.
  final String? storageDataDir;

  bool get shardingEnabledEffective => shardingEnabled ?? false;
  bool get storageEnabledEffective => storageEnabled ?? true;
  bool get forcePrivateEffective => forcePrivate ?? false;
  bool get enableUpnpEffective => enableUpnp ?? true;
  bool get enableQuicEffective => enableQuic ?? false;
  bool get healthEnabledEffective => healthEnabled ?? true;
  bool get useGpuEffective => useGpu ?? true;
  bool get autoRebalanceEffective => autoRebalance ?? false;
  bool get forwardChainServeEffective => forwardChainServe ?? true;
  bool get vpkEnabledEffective => vpkEnabled ?? false;

  /// Every argument takes [_keep] by default, so passing null clears it.
  ConfigSnapshot copyWith({
    Object? model = _keep,
    Object? shardingEnabled = _keep,
    Object? storageEnabled = _keep,
    Object? storageCapacityGb = _keep,
    Object? port = _keep,
    Object? publicIp = _keep,
    Object? initialPeers = _keep,
    Object? forcePrivate = _keep,
    Object? enableUpnp = _keep,
    Object? enableQuic = _keep,
    Object? ipv6 = _keep,
    Object? maxConnections = _keep,
    Object? healthEnabled = _keep,
    Object? healthEndpoint = _keep,
    Object? blocks = _keep,
    Object? startBlock = _keep,
    bool? startBlockAuto,
    Object? useGpu = _keep,
    Object? shardBackend = _keep,
    Object? autoRebalance = _keep,
    Object? rebalanceIntervalSecs = _keep,
    Object? rebalanceMinRedundancy = _keep,
    Object? forwardChainServe = _keep,
    Object? publicName = _keep,
    Object? vpkEnabled = _keep,
    Object? vpkMode = _keep,
    Object? storageDataDir = _keep,
  }) {
    T pick<T>(Object? v, T current) => identical(v, _keep) ? current : v as T;
    return ConfigSnapshot(
      model: pick(model, this.model),
      shardingEnabled: pick(shardingEnabled, this.shardingEnabled),
      storageEnabled: pick(storageEnabled, this.storageEnabled),
      storageCapacityGb: pick(storageCapacityGb, this.storageCapacityGb),
      port: pick(port, this.port),
      publicIp: pick(publicIp, this.publicIp),
      initialPeers: pick(initialPeers, this.initialPeers),
      forcePrivate: pick(forcePrivate, this.forcePrivate),
      enableUpnp: pick(enableUpnp, this.enableUpnp),
      enableQuic: pick(enableQuic, this.enableQuic),
      ipv6: pick(ipv6, this.ipv6),
      maxConnections: pick(maxConnections, this.maxConnections),
      healthEnabled: pick(healthEnabled, this.healthEnabled),
      healthEndpoint: pick(healthEndpoint, this.healthEndpoint),
      blocks: pick(blocks, this.blocks),
      startBlock: pick(startBlock, this.startBlock),
      startBlockAuto: startBlockAuto ?? this.startBlockAuto,
      useGpu: pick(useGpu, this.useGpu),
      shardBackend: pick(shardBackend, this.shardBackend),
      autoRebalance: pick(autoRebalance, this.autoRebalance),
      rebalanceIntervalSecs: pick(
        rebalanceIntervalSecs,
        this.rebalanceIntervalSecs,
      ),
      rebalanceMinRedundancy: pick(
        rebalanceMinRedundancy,
        this.rebalanceMinRedundancy,
      ),
      forwardChainServe: pick(forwardChainServe, this.forwardChainServe),
      publicName: pick(publicName, this.publicName),
      vpkEnabled: pick(vpkEnabled, this.vpkEnabled),
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
  const ChatConfig({this.maxTokens, this.forwardChainOriginate});

  /// `shard.max_tokens`. Null = the daemon's default (200).
  final int? maxTokens;

  /// `shard.forward_chain.originate` — route this node's own runs as a
  /// forward chain instead of star. Null = unset (star).
  final bool? forwardChainOriginate;
}

class ConfigFile {
  ConfigFile._();

  /// Path to ~/.kwaainet/config.yaml.
  static String get path => KwaainetPaths.configFile;

  /// The snapshot returned when config.yaml is missing or unreadable.
  @visibleForTesting
  static ConfigSnapshot get defaults => _defaults;

  /// Nothing is set when the file is missing.
  static const ConfigSnapshot _defaults = ConfigSnapshot();

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
    final rawIpv6 = doc['ipv6'];
    final rawBackend = shard is YamlMap ? shard['backend'] : null;
    Object? at(Object? map, String key) => map is YamlMap ? map[key] : null;
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    return ConfigSnapshot(
      model: text(doc['model']),
      shardingEnabled: at(contribute, 'shards') as bool?,
      storageEnabled: at(contribute, 'storage') as bool?,
      storageCapacityGb: (at(storage, 'capacity_gb') as num?)?.toDouble(),
      port: (doc['port'] as num?)?.toInt(),
      publicIp: text(doc['public_ip']),
      initialPeers: rawPeers is YamlList && rawPeers.isNotEmpty
          ? rawPeers.map((e) => e.toString()).toList()
          : null,
      forcePrivate: doc['force_private'] as bool?,
      enableUpnp: doc['enable_upnp'] as bool?,
      enableQuic: doc['enable_quic'] as bool?,
      ipv6: rawIpv6 == null ? null : Ipv6Mode.fromYaml(rawIpv6),
      maxConnections: (doc['max_connections'] as num?)?.toInt(),
      healthEnabled: at(health, 'enabled') as bool?,
      healthEndpoint: text(at(health, 'api_endpoint')),
      blocks: (doc['blocks'] as num?)?.toInt(),
      startBlock: (doc['start_block'] as num?)?.toInt(),
      startBlockAuto: (doc['start_block_auto'] as bool?) ?? false,
      useGpu: doc['use_gpu'] as bool?,
      shardBackend: rawBackend == null
          ? null
          : ShardBackend.fromYaml(rawBackend),
      autoRebalance: doc['auto_rebalance'] as bool?,
      rebalanceIntervalSecs: (doc['rebalance_interval_secs'] as num?)?.toInt(),
      rebalanceMinRedundancy: (doc['rebalance_min_redundancy'] as num?)
          ?.toInt(),
      forwardChainServe: at(forwardChain, 'serve') as bool?,
      publicName: text(doc['public_name']),
      vpkEnabled: doc['vpk_enabled'] as bool?,
      vpkMode: VpkMode.fromYaml(doc['vpk_mode']),
      storageDataDir: text(at(storage, 'data_dir')),
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
    // Each key is written when set and removed when not, so the file holds
    // exactly what the user chose. Empty text and lists count as unset.
    String? text(String? v) => v == null || v.isEmpty ? null : v;
    _setOrRemove(editor, ['model'], text(updated.model));
    _setOrRemove(editor, ['contribute', 'shards'], updated.shardingEnabled);
    _setOrRemove(editor, ['contribute', 'storage'], updated.storageEnabled);
    _setOrRemove(editor, ['port'], updated.port);
    _setOrRemove(editor, ['public_ip'], text(updated.publicIp));
    final peers = updated.initialPeers;
    _setOrRemove(editor, [
      'initial_peers',
    ], peers == null || peers.isEmpty ? null : peers);
    _setOrRemove(editor, ['force_private'], updated.forcePrivate);
    _setOrRemove(editor, ['enable_upnp'], updated.enableUpnp);
    _setOrRemove(editor, ['enable_quic'], updated.enableQuic);
    _setOrRemove(editor, ['ipv6'], updated.ipv6?.yamlValue);
    _setOrRemove(editor, ['max_connections'], updated.maxConnections);
    _setOrRemove(editor, [
      'health_monitoring',
      'enabled',
    ], updated.healthEnabled);
    _setOrRemove(editor, [
      'health_monitoring',
      'api_endpoint',
    ], text(updated.healthEndpoint));
    _setOrRemove(editor, ['blocks'], updated.blocks);
    // An unplaced node has neither key. A pin has no `start_block_auto`,
    // which is what stops the rebalancer moving it.
    _setOrRemove(editor, ['start_block'], updated.startBlock);
    _setOrRemove(editor, [
      'start_block_auto',
    ], updated.startBlock != null && updated.startBlockAuto ? true : null);
    _setOrRemove(editor, ['use_gpu'], updated.useGpu);
    _setOrRemove(editor, ['shard', 'backend'], updated.shardBackend?.name);
    _setOrRemove(editor, ['auto_rebalance'], updated.autoRebalance);
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
    ], updated.forwardChainServe);
    _setOrRemove(editor, ['public_name'], text(updated.publicName));
    _setOrRemove(editor, ['vpk_enabled'], updated.vpkEnabled);
    _setOrRemove(editor, ['vpk_mode'], updated.vpkMode?.name);
    _setOrRemove(editor, ['storage', 'capacity_gb'], updated.storageCapacityGb);
    // Only an initialised storage section takes a data_dir: writing one into
    // a fresh file would make the daemon think storage was set up.
    final dataDir = text(updated.storageDataDir);
    if (dataDir != null && _has(editor, ['storage'])) {
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
          ? forwardChain['originate'] as bool?
          : null,
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
    ], chat.forwardChainOriginate);
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
