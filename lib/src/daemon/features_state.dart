import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config_file.dart';

/// The currently-persisted feature config (mirrors what's in
/// ~/.kwaainet/config.yaml). Refresh via `ref.invalidate(featuresProvider)`
/// after writing.
final featuresProvider = FutureProvider<ConfigSnapshot>((ref) async {
  return ConfigFile.load();
});

/// Holds an in-memory draft of feature settings the user is editing in the
/// Features tab. Initialised from [featuresProvider] on first access; cleared
/// when [apply()] persists the draft to config.yaml.
class FeaturesDraftNotifier extends Notifier<ConfigSnapshot?> {
  @override
  ConfigSnapshot? build() => null;

  /// Seed the draft from the on-disk values if it hasn't been started,
  /// or if the prior draft was constructed against a different schema
  /// (e.g. across a hot-reload that added new ConfigSnapshot fields —
  /// without this, reads of the new fields throw a non-null assertion).
  void seed(ConfigSnapshot loaded) {
    final s = state;
    if (s == null || !_hasAllFields(s)) {
      state = loaded;
    }
  }

  /// Defensive: touch every field to surface any null-from-stale-shape
  /// errors here, so we can re-seed instead of crashing during build.
  bool _hasAllFields(ConfigSnapshot s) {
    try {
      s.model;
      s.shardingEnabled;
      s.storageEnabled;
      s.storageCapacityGb;
      s.port;
      s.publicIp;
      s.initialPeers;
      s.forcePrivate;
      s.enableUpnp;
      s.enableQuic;
      s.ipv6;
      s.maxConnections;
      s.healthEnabled;
      s.healthEndpoint;
      s.blocks;
      s.startBlock;
      s.startBlockAuto;
      s.useGpu;
      s.shardBackend;
      s.autoRebalance;
      s.rebalanceIntervalSecs;
      s.rebalanceMinRedundancy;
      s.forwardChainServe;
      s.publicName;
      s.vpkEnabled;
      s.vpkMode;
      s.storageDataDir;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _update(ConfigSnapshot Function(ConfigSnapshot) change) {
    final s = state;
    if (s != null) state = change(s);
  }

  void setModel(String v) => _update((s) => s.copyWith(model: v));
  void setShardingEnabled(bool v) =>
      _update((s) => s.copyWith(shardingEnabled: v));
  void setStorageEnabled(bool v) =>
      _update((s) => s.copyWith(storageEnabled: v));
  void setStorageCapacityGb(double? v) =>
      _update((s) => s.copyWith(storageCapacityGb: v));
  void setPort(int? v) => _update((s) => s.copyWith(port: v));
  void setPublicIp(String v) => _update((s) => s.copyWith(publicIp: v));
  void setInitialPeers(List<String> v) =>
      _update((s) => s.copyWith(initialPeers: v));
  void setForcePrivate(bool v) => _update((s) => s.copyWith(forcePrivate: v));
  void setEnableUpnp(bool v) => _update((s) => s.copyWith(enableUpnp: v));
  void setEnableQuic(bool v) => _update((s) => s.copyWith(enableQuic: v));
  void setIpv6(Ipv6Mode v) => _update((s) => s.copyWith(ipv6: v));

  /// Null clears the key so the daemon's own default applies.
  void setMaxConnections(int? v) =>
      _update((s) => s.copyWith(maxConnections: v));
  void setHealthEnabled(bool v) => _update((s) => s.copyWith(healthEnabled: v));
  void setHealthEndpoint(String v) =>
      _update((s) => s.copyWith(healthEndpoint: v));
  void setBlocks(int? v) => _update((s) => s.copyWith(blocks: v));

  /// A start block typed here is the operator's pin; null hands placement
  /// back to `shard serve`.
  void setStartBlock(int? v) =>
      _update((s) => s.copyWith(startBlock: v, startBlockAuto: false));
  /// An emptied start-block field: back to the file's placement if that was
  /// automatic (so the recorded range survives), else unplaced.
  void clearStartBlock(ConfigSnapshot onDisk) => _update(
    (s) => onDisk.startBlockAuto
        ? s.copyWith(startBlock: onDisk.startBlock, startBlockAuto: true)
        : s.copyWith(startBlock: null, startBlockAuto: false),
  );
  void setUseGpu(bool v) => _update((s) => s.copyWith(useGpu: v));
  void setShardBackend(ShardBackend v) =>
      _update((s) => s.copyWith(shardBackend: v));
  void setAutoRebalance(bool v) => _update((s) => s.copyWith(autoRebalance: v));
  void setRebalanceIntervalSecs(int? v) =>
      _update((s) => s.copyWith(rebalanceIntervalSecs: v));
  void setRebalanceMinRedundancy(int? v) =>
      _update((s) => s.copyWith(rebalanceMinRedundancy: v));
  void setForwardChainServe(bool v) =>
      _update((s) => s.copyWith(forwardChainServe: v));
  void setPublicName(String v) => _update((s) => s.copyWith(publicName: v));
  void setVpkEnabled(bool v) => _update((s) => s.copyWith(vpkEnabled: v));
  void setVpkMode(VpkMode? v) => _update((s) => s.copyWith(vpkMode: v));
  void setStorageDataDir(String? v) =>
      _update((s) => s.copyWith(storageDataDir: v));

  /// True when the draft differs from the on-disk snapshot.
  bool isDirty(ConfigSnapshot onDisk) {
    final s = state;
    if (s == null) return false;
    return s.model != onDisk.model ||
        s.shardingEnabled != onDisk.shardingEnabled ||
        s.storageEnabled != onDisk.storageEnabled ||
        s.storageCapacityGb != onDisk.storageCapacityGb ||
        s.port != onDisk.port ||
        s.publicIp != onDisk.publicIp ||
        !_listsEqual(s.initialPeers, onDisk.initialPeers) ||
        s.forcePrivate != onDisk.forcePrivate ||
        s.enableUpnp != onDisk.enableUpnp ||
        s.enableQuic != onDisk.enableQuic ||
        s.ipv6 != onDisk.ipv6 ||
        s.maxConnections != onDisk.maxConnections ||
        s.healthEnabled != onDisk.healthEnabled ||
        s.healthEndpoint != onDisk.healthEndpoint ||
        s.blocks != onDisk.blocks ||
        s.startBlock != onDisk.startBlock ||
        s.startBlockAuto != onDisk.startBlockAuto ||
        s.useGpu != onDisk.useGpu ||
        s.shardBackend != onDisk.shardBackend ||
        s.autoRebalance != onDisk.autoRebalance ||
        s.rebalanceIntervalSecs != onDisk.rebalanceIntervalSecs ||
        s.rebalanceMinRedundancy != onDisk.rebalanceMinRedundancy ||
        s.forwardChainServe != onDisk.forwardChainServe ||
        s.publicName != onDisk.publicName ||
        s.vpkEnabled != onDisk.vpkEnabled ||
        s.vpkMode != onDisk.vpkMode ||
        s.storageDataDir != onDisk.storageDataDir;
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Persist the draft to config.yaml. Returns the snapshot that was
  /// written so callers can refresh other state.
  Future<ConfigSnapshot> apply() async {
    final s = state;
    if (s == null) throw StateError('No draft to apply');
    await ConfigFile.save(s);
    return s;
  }
}

final featuresDraftProvider =
    NotifierProvider<FeaturesDraftNotifier, ConfigSnapshot?>(
      FeaturesDraftNotifier.new,
    );

/// True when the user has applied feature changes that need a service
/// restart to take effect. Cleared by [clear()] when the daemon next
/// reports it has been restarted (or the user manually dismisses it).
class RestartNeededNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;
  void clear() => state = false;
}

final restartNeededProvider = NotifierProvider<RestartNeededNotifier, bool>(
  RestartNeededNotifier.new,
);

/// The Chat tab's config keys, as on disk. Saved straight away (see
/// [ConfigFile.saveChat]); invalidate after writing.
final chatConfigProvider = FutureProvider<ChatConfig>((ref) async {
  return ConfigFile.loadChat();
});
