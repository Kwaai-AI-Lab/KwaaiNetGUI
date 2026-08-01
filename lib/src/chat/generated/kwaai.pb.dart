// This is a generated file - do not edit.
//
// Generated from kwaai.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'kwaai.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'kwaai.pbenum.dart';

enum ClientFrame_Body {
  ping,
  generate,
  shardRun,
  status,
  cancel,
  blockCoverage,
  storageDiscovery,
  network,
  notSet
}

/// Frame sent from client → server on the Session stream. The `body`
/// oneof selects which operation type this frame drives. Operation
/// names match the CLI subcommand they correspond to, dot-to-camelcase:
///
///   ping              ←  (no CLI equivalent; gRPC-only liveness probe)
///   generate          ←  `kwaainet generate <PROMPT>`
///   shardRun          ←  `kwaainet shard run <PROMPT>`
///   status            ←  `kwaainet status`
///   cancel            ←  (no CLI equivalent; aborts an in-flight op)
///   blockCoverage     ←  `kwaainet shard chain`
///
/// New operations are added as siblings here; preserving the flat shape
/// keeps the dispatch trivial on both sides.
class ClientFrame extends $pb.GeneratedMessage {
  factory ClientFrame({
    $fixnum.Int64? id,
    PingRequest? ping,
    GenerateRequest? generate,
    ShardRunRequest? shardRun,
    StatusRequest? status,
    Cancel? cancel,
    BlockCoverageRequest? blockCoverage,
    StorageDiscoveryRequest? storageDiscovery,
    NetworkRequest? network,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (ping != null) result.ping = ping;
    if (generate != null) result.generate = generate;
    if (shardRun != null) result.shardRun = shardRun;
    if (status != null) result.status = status;
    if (cancel != null) result.cancel = cancel;
    if (blockCoverage != null) result.blockCoverage = blockCoverage;
    if (storageDiscovery != null) result.storageDiscovery = storageDiscovery;
    if (network != null) result.network = network;
    return result;
  }

  ClientFrame._();

  factory ClientFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClientFrame_Body> _ClientFrame_BodyByTag = {
    10: ClientFrame_Body.ping,
    11: ClientFrame_Body.generate,
    12: ClientFrame_Body.shardRun,
    13: ClientFrame_Body.status,
    14: ClientFrame_Body.cancel,
    15: ClientFrame_Body.blockCoverage,
    16: ClientFrame_Body.storageDiscovery,
    17: ClientFrame_Body.network,
    0: ClientFrame_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17])
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<PingRequest>(10, _omitFieldNames ? '' : 'ping',
        subBuilder: PingRequest.create)
    ..aOM<GenerateRequest>(11, _omitFieldNames ? '' : 'generate',
        subBuilder: GenerateRequest.create)
    ..aOM<ShardRunRequest>(12, _omitFieldNames ? '' : 'shardRun',
        subBuilder: ShardRunRequest.create)
    ..aOM<StatusRequest>(13, _omitFieldNames ? '' : 'status',
        subBuilder: StatusRequest.create)
    ..aOM<Cancel>(14, _omitFieldNames ? '' : 'cancel',
        subBuilder: Cancel.create)
    ..aOM<BlockCoverageRequest>(15, _omitFieldNames ? '' : 'blockCoverage',
        subBuilder: BlockCoverageRequest.create)
    ..aOM<StorageDiscoveryRequest>(
        16, _omitFieldNames ? '' : 'storageDiscovery',
        subBuilder: StorageDiscoveryRequest.create)
    ..aOM<NetworkRequest>(17, _omitFieldNames ? '' : 'network',
        subBuilder: NetworkRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientFrame copyWith(void Function(ClientFrame) updates) =>
      super.copyWith((message) => updates(message as ClientFrame))
          as ClientFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientFrame create() => ClientFrame._();
  @$core.override
  ClientFrame createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientFrame getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientFrame>(create);
  static ClientFrame? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  ClientFrame_Body whichBody() => _ClientFrame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  void clearBody() => $_clearField($_whichOneof(0));

  /// Operation correlation id. Pick any non-zero value unused by an
  /// active operation on this Session. Reuse after Done/Error.
  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(10)
  PingRequest get ping => $_getN(1);
  @$pb.TagNumber(10)
  set ping(PingRequest value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPing() => $_has(1);
  @$pb.TagNumber(10)
  void clearPing() => $_clearField(10);
  @$pb.TagNumber(10)
  PingRequest ensurePing() => $_ensure(1);

  /// Single-node inference using the local InferenceEngine. The
  /// node must have the model loaded locally — most useful for
  /// dev / fallback when the shard mesh isn't ready.
  @$pb.TagNumber(11)
  GenerateRequest get generate => $_getN(2);
  @$pb.TagNumber(11)
  set generate(GenerateRequest value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasGenerate() => $_has(2);
  @$pb.TagNumber(11)
  void clearGenerate() => $_clearField(11);
  @$pb.TagNumber(11)
  GenerateRequest ensureGenerate() => $_ensure(2);

  /// Distributed inference across the shard mesh. Routes blocks
  /// to peer nodes via the existing block_rpc layer. This is the
  /// default chat path for the GUI.
  @$pb.TagNumber(12)
  ShardRunRequest get shardRun => $_getN(3);
  @$pb.TagNumber(12)
  set shardRun(ShardRunRequest value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasShardRun() => $_has(3);
  @$pb.TagNumber(12)
  void clearShardRun() => $_clearField(12);
  @$pb.TagNumber(12)
  ShardRunRequest ensureShardRun() => $_ensure(3);

  /// Snapshot of node status (uptime, peers, model state). One
  /// ServerFrame.status reply, then Done.
  @$pb.TagNumber(13)
  StatusRequest get status => $_getN(4);
  @$pb.TagNumber(13)
  set status(StatusRequest value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(13)
  void clearStatus() => $_clearField(13);
  @$pb.TagNumber(13)
  StatusRequest ensureStatus() => $_ensure(4);

  /// Cancel an in-flight operation by id.
  @$pb.TagNumber(14)
  Cancel get cancel => $_getN(5);
  @$pb.TagNumber(14)
  set cancel(Cancel value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCancel() => $_has(5);
  @$pb.TagNumber(14)
  void clearCancel() => $_clearField(14);
  @$pb.TagNumber(14)
  Cancel ensureCancel() => $_ensure(5);

  /// Block-coverage snapshot / subscription. One-shot when
  /// `subscribe` is false (one BlockCoverageUpdate reply, then
  /// Done); a live feed when true (a BlockCoverageUpdate every
  /// refresh interval until cancelled with a `Cancel` body).
  @$pb.TagNumber(15)
  BlockCoverageRequest get blockCoverage => $_getN(6);
  @$pb.TagNumber(15)
  set blockCoverage(BlockCoverageRequest value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasBlockCoverage() => $_has(6);
  @$pb.TagNumber(15)
  void clearBlockCoverage() => $_clearField(15);
  @$pb.TagNumber(15)
  BlockCoverageRequest ensureBlockCoverage() => $_ensure(6);

  /// VPK storage-node discovery. Like block_coverage, but for the
  /// `_kwaai.vpk.nodes` DHT registry. Note that a one-shot request
  /// yields *two* StorageUpdate replies before Done — see
  /// StorageUpdate.probes_pending.
  @$pb.TagNumber(16)
  StorageDiscoveryRequest get storageDiscovery => $_getN(7);
  @$pb.TagNumber(16)
  set storageDiscovery(StorageDiscoveryRequest value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasStorageDiscovery() => $_has(7);
  @$pb.TagNumber(16)
  void clearStorageDiscovery() => $_clearField(16);
  @$pb.TagNumber(16)
  StorageDiscoveryRequest ensureStorageDiscovery() => $_ensure(7);

  /// Local p2p state: connections, DHT routing table and this
  /// node's own reachability. Unlike the two above it queries no
  /// DHT — it reads the swarm — so it is cheap enough to poll at a
  /// few seconds. Reachability changes push out of band rather than
  /// waiting for the next tick; see NetworkUpdate.reason.
  @$pb.TagNumber(17)
  NetworkRequest get network => $_getN(8);
  @$pb.TagNumber(17)
  set network(NetworkRequest value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasNetwork() => $_has(8);
  @$pb.TagNumber(17)
  void clearNetwork() => $_clearField(17);
  @$pb.TagNumber(17)
  NetworkRequest ensureNetwork() => $_ensure(8);
}

enum ServerFrame_Body {
  pong,
  token,
  done,
  error,
  status,
  blockCoverage,
  storage,
  network,
  notSet
}

/// Frame sent from server → client on the Session stream. The `id`
/// matches the originating ClientFrame.id, so the client can dispatch
/// frames to whichever caller is awaiting them.
class ServerFrame extends $pb.GeneratedMessage {
  factory ServerFrame({
    $fixnum.Int64? id,
    PingReply? pong,
    ChatToken? token,
    Done? done,
    Error? error,
    StatusReply? status,
    BlockCoverageUpdate? blockCoverage,
    StorageUpdate? storage,
    NetworkUpdate? network,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (pong != null) result.pong = pong;
    if (token != null) result.token = token;
    if (done != null) result.done = done;
    if (error != null) result.error = error;
    if (status != null) result.status = status;
    if (blockCoverage != null) result.blockCoverage = blockCoverage;
    if (storage != null) result.storage = storage;
    if (network != null) result.network = network;
    return result;
  }

  ServerFrame._();

  factory ServerFrame.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerFrame.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ServerFrame_Body> _ServerFrame_BodyByTag = {
    10: ServerFrame_Body.pong,
    11: ServerFrame_Body.token,
    12: ServerFrame_Body.done,
    13: ServerFrame_Body.error,
    14: ServerFrame_Body.status,
    15: ServerFrame_Body.blockCoverage,
    16: ServerFrame_Body.storage,
    17: ServerFrame_Body.network,
    0: ServerFrame_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17])
    ..a<$fixnum.Int64>(1, _omitFieldNames ? '' : 'id', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<PingReply>(10, _omitFieldNames ? '' : 'pong',
        subBuilder: PingReply.create)
    ..aOM<ChatToken>(11, _omitFieldNames ? '' : 'token',
        subBuilder: ChatToken.create)
    ..aOM<Done>(12, _omitFieldNames ? '' : 'done', subBuilder: Done.create)
    ..aOM<Error>(13, _omitFieldNames ? '' : 'error', subBuilder: Error.create)
    ..aOM<StatusReply>(14, _omitFieldNames ? '' : 'status',
        subBuilder: StatusReply.create)
    ..aOM<BlockCoverageUpdate>(15, _omitFieldNames ? '' : 'blockCoverage',
        subBuilder: BlockCoverageUpdate.create)
    ..aOM<StorageUpdate>(16, _omitFieldNames ? '' : 'storage',
        subBuilder: StorageUpdate.create)
    ..aOM<NetworkUpdate>(17, _omitFieldNames ? '' : 'network',
        subBuilder: NetworkUpdate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerFrame clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerFrame copyWith(void Function(ServerFrame) updates) =>
      super.copyWith((message) => updates(message as ServerFrame))
          as ServerFrame;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerFrame create() => ServerFrame._();
  @$core.override
  ServerFrame createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerFrame getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerFrame>(create);
  static ServerFrame? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  ServerFrame_Body whichBody() => _ServerFrame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(10)
  PingReply get pong => $_getN(1);
  @$pb.TagNumber(10)
  set pong(PingReply value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPong() => $_has(1);
  @$pb.TagNumber(10)
  void clearPong() => $_clearField(10);
  @$pb.TagNumber(10)
  PingReply ensurePong() => $_ensure(1);

  /// Mid-stream token from generate / shard_run. Multiple tokens
  /// arrive for one id before the operation ends.
  @$pb.TagNumber(11)
  ChatToken get token => $_getN(2);
  @$pb.TagNumber(11)
  set token(ChatToken value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasToken() => $_has(2);
  @$pb.TagNumber(11)
  void clearToken() => $_clearField(11);
  @$pb.TagNumber(11)
  ChatToken ensureToken() => $_ensure(2);

  /// Operation completed cleanly. Always the last frame for a
  /// given id on success. After Done the id is free to reuse.
  @$pb.TagNumber(12)
  Done get done => $_getN(3);
  @$pb.TagNumber(12)
  set done(Done value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasDone() => $_has(3);
  @$pb.TagNumber(12)
  void clearDone() => $_clearField(12);
  @$pb.TagNumber(12)
  Done ensureDone() => $_ensure(3);

  /// Operation failed. Mutually exclusive with Done; same
  /// semantics (operation is over, id is free).
  @$pb.TagNumber(13)
  Error get error => $_getN(4);
  @$pb.TagNumber(13)
  set error(Error value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(13)
  void clearError() => $_clearField(13);
  @$pb.TagNumber(13)
  Error ensureError() => $_ensure(4);

  /// Reply to a StatusRequest.
  @$pb.TagNumber(14)
  StatusReply get status => $_getN(5);
  @$pb.TagNumber(14)
  set status(StatusReply value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(14)
  void clearStatus() => $_clearField(14);
  @$pb.TagNumber(14)
  StatusReply ensureStatus() => $_ensure(5);

  /// Snapshot of model block coverage. Exactly one arrives for a
  /// one-shot BlockCoverageRequest; a subscription delivers one
  /// per refresh interval until the op is cancelled.
  @$pb.TagNumber(15)
  BlockCoverageUpdate get blockCoverage => $_getN(6);
  @$pb.TagNumber(15)
  set blockCoverage(BlockCoverageUpdate value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasBlockCoverage() => $_has(6);
  @$pb.TagNumber(15)
  void clearBlockCoverage() => $_clearField(15);
  @$pb.TagNumber(15)
  BlockCoverageUpdate ensureBlockCoverage() => $_ensure(6);

  /// Snapshot of discovered VPK storage nodes. Arrives in pairs
  /// per discovery round: one with probes_pending set, then one
  /// with reachability resolved.
  @$pb.TagNumber(16)
  StorageUpdate get storage => $_getN(7);
  @$pb.TagNumber(16)
  set storage(StorageUpdate value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasStorage() => $_has(7);
  @$pb.TagNumber(16)
  void clearStorage() => $_clearField(16);
  @$pb.TagNumber(16)
  StorageUpdate ensureStorage() => $_ensure(7);

  /// Snapshot of local p2p state. One arrives for a one-shot
  /// NetworkRequest; a subscription delivers one per refresh
  /// interval, plus one immediately whenever reachability changes.
  @$pb.TagNumber(17)
  NetworkUpdate get network => $_getN(8);
  @$pb.TagNumber(17)
  set network(NetworkUpdate value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasNetwork() => $_has(8);
  @$pb.TagNumber(17)
  void clearNetwork() => $_clearField(17);
  @$pb.TagNumber(17)
  NetworkUpdate ensureNetwork() => $_ensure(8);
}

/// Sent from client → server to abort an in-flight operation by id.
class Cancel extends $pb.GeneratedMessage {
  factory Cancel({
    $fixnum.Int64? targetId,
  }) {
    final result = create();
    if (targetId != null) result.targetId = targetId;
    return result;
  }

  Cancel._();

  factory Cancel.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Cancel.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Cancel',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'targetId', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Cancel clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Cancel copyWith(void Function(Cancel) updates) =>
      super.copyWith((message) => updates(message as Cancel)) as Cancel;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Cancel create() => Cancel._();
  @$core.override
  Cancel createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Cancel getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Cancel>(create);
  static Cancel? _defaultInstance;

  /// The operation id (not the Cancel frame's own id) to abort. The
  /// server emits an Error{code=CANCELLED} for `target_id` and the
  /// operation winds down.
  @$pb.TagNumber(1)
  $fixnum.Int64 get targetId => $_getI64(0);
  @$pb.TagNumber(1)
  set targetId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetId() => $_clearField(1);
}

/// Generic terminator for a successful operation. Reserved tag range
/// 1-15 left for future per-op summary data.
class Done extends $pb.GeneratedMessage {
  factory Done() => create();

  Done._();

  factory Done.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Done.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Done',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Done clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Done copyWith(void Function(Done) updates) =>
      super.copyWith((message) => updates(message as Done)) as Done;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Done create() => Done._();
  @$core.override
  Done createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Done getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Done>(create);
  static Done? _defaultInstance;
}

/// Generic operation-level failure. Distinct from grpc transport errors
/// (which surface as the rpc's own Status) — these are application-level
/// failures inside an otherwise-healthy Session.
class Error extends $pb.GeneratedMessage {
  factory Error({
    Error_Code? code,
    $core.String? message,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (message != null) result.message = message;
    return result;
  }

  Error._();

  factory Error.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Error.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Error',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aE<Error_Code>(1, _omitFieldNames ? '' : 'code',
        enumValues: Error_Code.values)
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error copyWith(void Function(Error) updates) =>
      super.copyWith((message) => updates(message as Error)) as Error;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Error create() => Error._();
  @$core.override
  Error createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Error getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Error>(create);
  static Error? _defaultInstance;

  @$pb.TagNumber(1)
  Error_Code get code => $_getN(0);
  @$pb.TagNumber(1)
  set code(Error_Code value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class PingRequest extends $pb.GeneratedMessage {
  factory PingRequest() => create();

  PingRequest._();

  factory PingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest copyWith(void Function(PingRequest) updates) =>
      super.copyWith((message) => updates(message as PingRequest))
          as PingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingRequest create() => PingRequest._();
  @$core.override
  PingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingRequest>(create);
  static PingRequest? _defaultInstance;
}

class PingReply extends $pb.GeneratedMessage {
  factory PingReply({
    $core.String? serverTime,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    return result;
  }

  PingReply._();

  factory PingReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PingReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingReply copyWith(void Function(PingReply) updates) =>
      super.copyWith((message) => updates(message as PingReply)) as PingReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingReply create() => PingReply._();
  @$core.override
  PingReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PingReply getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingReply>(create);
  static PingReply? _defaultInstance;

  /// Wall-clock time on the daemon, RFC 3339.
  @$pb.TagNumber(1)
  $core.String get serverTime => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverTime($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTime() => $_clearField(1);
}

/// `kwaainet generate <PROMPT>` — single-node local inference.
class GenerateRequest extends $pb.GeneratedMessage {
  factory GenerateRequest({
    $core.String? role,
    $core.String? content,
    $core.String? conversationId,
  }) {
    final result = create();
    if (role != null) result.role = role;
    if (content != null) result.content = content;
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  GenerateRequest._();

  factory GenerateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GenerateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GenerateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'role')
    ..aOS(2, _omitFieldNames ? '' : 'content')
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GenerateRequest copyWith(void Function(GenerateRequest) updates) =>
      super.copyWith((message) => updates(message as GenerateRequest))
          as GenerateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateRequest create() => GenerateRequest._();
  @$core.override
  GenerateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GenerateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GenerateRequest>(create);
  static GenerateRequest? _defaultInstance;

  /// Conventional roles: "user", "assistant", "system". Free-form.
  @$pb.TagNumber(1)
  $core.String get role => $_getSZ(0);
  @$pb.TagNumber(1)
  set role($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRole() => $_has(0);
  @$pb.TagNumber(1)
  void clearRole() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get content => $_getSZ(1);
  @$pb.TagNumber(2)
  set content($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearContent() => $_clearField(2);

  /// Optional client-supplied conversation id for future multi-turn.
  /// Ignored today.
  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);
}

/// `kwaainet shard run <PROMPT>` — distributed inference across the mesh.
class ShardRunRequest extends $pb.GeneratedMessage {
  factory ShardRunRequest({
    $core.String? role,
    $core.String? content,
    $core.String? model,
    $core.String? conversationId,
  }) {
    final result = create();
    if (role != null) result.role = role;
    if (content != null) result.content = content;
    if (model != null) result.model = model;
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  ShardRunRequest._();

  factory ShardRunRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShardRunRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShardRunRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'role')
    ..aOS(2, _omitFieldNames ? '' : 'content')
    ..aOS(3, _omitFieldNames ? '' : 'model')
    ..aOS(4, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShardRunRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShardRunRequest copyWith(void Function(ShardRunRequest) updates) =>
      super.copyWith((message) => updates(message as ShardRunRequest))
          as ShardRunRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShardRunRequest create() => ShardRunRequest._();
  @$core.override
  ShardRunRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShardRunRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShardRunRequest>(create);
  static ShardRunRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get role => $_getSZ(0);
  @$pb.TagNumber(1)
  set role($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRole() => $_has(0);
  @$pb.TagNumber(1)
  void clearRole() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get content => $_getSZ(1);
  @$pb.TagNumber(2)
  set content($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearContent() => $_clearField(2);

  /// Optional model override. Defaults to the daemon's configured
  /// model when empty.
  @$pb.TagNumber(3)
  $core.String get model => $_getSZ(2);
  @$pb.TagNumber(3)
  set model($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasModel() => $_has(2);
  @$pb.TagNumber(3)
  void clearModel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get conversationId => $_getSZ(3);
  @$pb.TagNumber(4)
  set conversationId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConversationId() => $_has(3);
  @$pb.TagNumber(4)
  void clearConversationId() => $_clearField(4);
}

/// `kwaainet status` — daemon-side state snapshot.
class StatusRequest extends $pb.GeneratedMessage {
  factory StatusRequest() => create();

  StatusRequest._();

  factory StatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatusRequest copyWith(void Function(StatusRequest) updates) =>
      super.copyWith((message) => updates(message as StatusRequest))
          as StatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StatusRequest create() => StatusRequest._();
  @$core.override
  StatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StatusRequest>(create);
  static StatusRequest? _defaultInstance;
}

class StatusReply extends $pb.GeneratedMessage {
  factory StatusReply({
    $core.String? serverTime,
    $core.String? model,
    $core.bool? shardReady,
    $core.int? peerCount,
    $fixnum.Int64? uptimeSecs,
    $core.String? version,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    if (model != null) result.model = model;
    if (shardReady != null) result.shardReady = shardReady;
    if (peerCount != null) result.peerCount = peerCount;
    if (uptimeSecs != null) result.uptimeSecs = uptimeSecs;
    if (version != null) result.version = version;
    return result;
  }

  StatusReply._();

  factory StatusReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StatusReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StatusReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverTime')
    ..aOS(2, _omitFieldNames ? '' : 'model')
    ..aOB(3, _omitFieldNames ? '' : 'shardReady')
    ..aI(4, _omitFieldNames ? '' : 'peerCount', fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'uptimeSecs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatusReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StatusReply copyWith(void Function(StatusReply) updates) =>
      super.copyWith((message) => updates(message as StatusReply))
          as StatusReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StatusReply create() => StatusReply._();
  @$core.override
  StatusReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StatusReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StatusReply>(create);
  static StatusReply? _defaultInstance;

  /// Daemon wall-clock time, RFC 3339 — same format as PingReply.
  @$pb.TagNumber(1)
  $core.String get serverTime => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverTime($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTime() => $_clearField(1);

  /// The model this node is configured to serve.
  @$pb.TagNumber(2)
  $core.String get model => $_getSZ(1);
  @$pb.TagNumber(2)
  set model($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModel() => $_has(1);
  @$pb.TagNumber(2)
  void clearModel() => $_clearField(2);

  /// True when the local shard server (the one this node contributes
  /// to the mesh) is up and serving its block range.
  @$pb.TagNumber(3)
  $core.bool get shardReady => $_getBF(2);
  @$pb.TagNumber(3)
  set shardReady($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasShardReady() => $_has(2);
  @$pb.TagNumber(3)
  void clearShardReady() => $_clearField(3);

  /// Number of peers currently in the routing table (best-effort
  /// snapshot from kwaai-p2p-daemon).
  @$pb.TagNumber(4)
  $core.int get peerCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set peerCount($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPeerCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearPeerCount() => $_clearField(4);

  /// Daemon process uptime in seconds.
  @$pb.TagNumber(5)
  $fixnum.Int64 get uptimeSecs => $_getI64(4);
  @$pb.TagNumber(5)
  set uptimeSecs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUptimeSecs() => $_has(4);
  @$pb.TagNumber(5)
  void clearUptimeSecs() => $_clearField(5);

  /// Version of the running daemon binary (CARGO_PKG_VERSION), e.g.
  /// "0.5.4" — no leading "v". Lets a client report the version of the
  /// process it is actually talking to, which can differ from whatever
  /// binary is on disk after an upgrade or a config change that has not
  /// been restarted into yet.
  ///
  /// Empty when talking to a daemon built before this field existed;
  /// clients should treat "" as unknown rather than as a version.
  @$pb.TagNumber(6)
  $core.String get version => $_getSZ(5);
  @$pb.TagNumber(6)
  set version($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearVersion() => $_clearField(6);
}

/// `kwaainet shard chain` — model block coverage from the DHT.
class BlockCoverageRequest extends $pb.GeneratedMessage {
  factory BlockCoverageRequest({
    $core.String? dhtPrefix,
    $core.int? totalBlocks,
    $core.bool? subscribe,
    $core.int? intervalSecs,
  }) {
    final result = create();
    if (dhtPrefix != null) result.dhtPrefix = dhtPrefix;
    if (totalBlocks != null) result.totalBlocks = totalBlocks;
    if (subscribe != null) result.subscribe = subscribe;
    if (intervalSecs != null) result.intervalSecs = intervalSecs;
    return result;
  }

  BlockCoverageRequest._();

  factory BlockCoverageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockCoverageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockCoverageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dhtPrefix')
    ..aI(2, _omitFieldNames ? '' : 'totalBlocks',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'subscribe')
    ..aI(4, _omitFieldNames ? '' : 'intervalSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockCoverageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockCoverageRequest copyWith(void Function(BlockCoverageRequest) updates) =>
      super.copyWith((message) => updates(message as BlockCoverageRequest))
          as BlockCoverageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockCoverageRequest create() => BlockCoverageRequest._();
  @$core.override
  BlockCoverageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockCoverageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockCoverageRequest>(create);
  static BlockCoverageRequest? _defaultInstance;

  /// DHT prefix to query. Defaults to the daemon's configured model
  /// prefix when empty.
  @$pb.TagNumber(1)
  $core.String get dhtPrefix => $_getSZ(0);
  @$pb.TagNumber(1)
  set dhtPrefix($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDhtPrefix() => $_has(0);
  @$pb.TagNumber(1)
  void clearDhtPrefix() => $_clearField(1);

  /// Total transformer blocks in the model. Defaults to the daemon's
  /// model config (`num_hidden_layers`) when unset.
  @$pb.TagNumber(2)
  $core.int get totalBlocks => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalBlocks($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalBlocks() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalBlocks() => $_clearField(2);

  /// When true the operation stays open and the server pushes a fresh
  /// BlockCoverageUpdate every `interval_secs` until the client sends
  /// a Cancel body for this op id. When false a single update is sent
  /// followed by Done.
  @$pb.TagNumber(3)
  $core.bool get subscribe => $_getBF(2);
  @$pb.TagNumber(3)
  set subscribe($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubscribe() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubscribe() => $_clearField(3);

  /// Refresh cadence for subscriptions, in seconds. 0 means the
  /// server default (5s). Ignored when `subscribe` is false.
  @$pb.TagNumber(4)
  $core.int get intervalSecs => $_getIZ(3);
  @$pb.TagNumber(4)
  set intervalSecs($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIntervalSecs() => $_has(3);
  @$pb.TagNumber(4)
  void clearIntervalSecs() => $_clearField(4);
}

/// One peer serving a contiguous block range, as announced in the DHT.
class BlockPeer extends $pb.GeneratedMessage {
  factory BlockPeer({
    $core.String? peerId,
    $core.int? startBlock,
    $core.int? endBlock,
    $core.String? publicName,
    $core.double? throughput,
    $core.double? trustScore,
    $core.String? trustTier,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (startBlock != null) result.startBlock = startBlock;
    if (endBlock != null) result.endBlock = endBlock;
    if (publicName != null) result.publicName = publicName;
    if (throughput != null) result.throughput = throughput;
    if (trustScore != null) result.trustScore = trustScore;
    if (trustTier != null) result.trustTier = trustTier;
    return result;
  }

  BlockPeer._();

  factory BlockPeer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockPeer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockPeer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aI(2, _omitFieldNames ? '' : 'startBlock', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'endBlock', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'publicName')
    ..aD(5, _omitFieldNames ? '' : 'throughput')
    ..aD(6, _omitFieldNames ? '' : 'trustScore')
    ..aOS(7, _omitFieldNames ? '' : 'trustTier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockPeer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockPeer copyWith(void Function(BlockPeer) updates) =>
      super.copyWith((message) => updates(message as BlockPeer)) as BlockPeer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockPeer create() => BlockPeer._();
  @$core.override
  BlockPeer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockPeer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockPeer>(create);
  static BlockPeer? _defaultInstance;

  /// libp2p peer id, base58.
  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  /// Served block range: [start_block, end_block).
  @$pb.TagNumber(2)
  $core.int get startBlock => $_getIZ(1);
  @$pb.TagNumber(2)
  set startBlock($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartBlock() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartBlock() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get endBlock => $_getIZ(2);
  @$pb.TagNumber(3)
  set endBlock($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEndBlock() => $_has(2);
  @$pb.TagNumber(3)
  void clearEndBlock() => $_clearField(3);

  /// Human-readable name the peer announced (may be empty).
  @$pb.TagNumber(4)
  $core.String get publicName => $_getSZ(3);
  @$pb.TagNumber(4)
  set publicName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPublicName() => $_has(3);
  @$pb.TagNumber(4)
  void clearPublicName() => $_clearField(4);

  /// Tokens/sec the peer claimed in its DHT announcement (0 = unknown).
  @$pb.TagNumber(5)
  $core.double get throughput => $_getN(4);
  @$pb.TagNumber(5)
  set throughput($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasThroughput() => $_has(4);
  @$pb.TagNumber(5)
  void clearThroughput() => $_clearField(5);

  /// Local reputation score in [0, 1]. Only meaningful when
  /// `trust_tier` is non-empty.
  @$pb.TagNumber(6)
  $core.double get trustScore => $_getN(5);
  @$pb.TagNumber(6)
  set trustScore($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTrustScore() => $_has(5);
  @$pb.TagNumber(6)
  void clearTrustScore() => $_clearField(6);

  /// Trust tier label ("UNKNOWN" / "KNOWN" / "VERIFIED" / "TRUSTED").
  /// Empty when the local reputation system is disabled.
  @$pb.TagNumber(7)
  $core.String get trustTier => $_getSZ(6);
  @$pb.TagNumber(7)
  set trustTier($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTrustTier() => $_has(6);
  @$pb.TagNumber(7)
  void clearTrustTier() => $_clearField(7);
}

/// Snapshot of which peers cover which blocks of the model.
class BlockCoverageUpdate extends $pb.GeneratedMessage {
  factory BlockCoverageUpdate({
    $core.String? serverTime,
    $core.String? model,
    $core.String? dhtPrefix,
    $core.int? totalBlocks,
    $core.int? coveredBlocks,
    $core.bool? fullCoverage,
    $core.Iterable<BlockPeer>? peers,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    if (model != null) result.model = model;
    if (dhtPrefix != null) result.dhtPrefix = dhtPrefix;
    if (totalBlocks != null) result.totalBlocks = totalBlocks;
    if (coveredBlocks != null) result.coveredBlocks = coveredBlocks;
    if (fullCoverage != null) result.fullCoverage = fullCoverage;
    if (peers != null) result.peers.addAll(peers);
    return result;
  }

  BlockCoverageUpdate._();

  factory BlockCoverageUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockCoverageUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockCoverageUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverTime')
    ..aOS(2, _omitFieldNames ? '' : 'model')
    ..aOS(3, _omitFieldNames ? '' : 'dhtPrefix')
    ..aI(4, _omitFieldNames ? '' : 'totalBlocks',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'coveredBlocks',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(6, _omitFieldNames ? '' : 'fullCoverage')
    ..pPM<BlockPeer>(7, _omitFieldNames ? '' : 'peers',
        subBuilder: BlockPeer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockCoverageUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockCoverageUpdate copyWith(void Function(BlockCoverageUpdate) updates) =>
      super.copyWith((message) => updates(message as BlockCoverageUpdate))
          as BlockCoverageUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockCoverageUpdate create() => BlockCoverageUpdate._();
  @$core.override
  BlockCoverageUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockCoverageUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BlockCoverageUpdate>(create);
  static BlockCoverageUpdate? _defaultInstance;

  /// Daemon wall-clock time of this snapshot, RFC 3339.
  @$pb.TagNumber(1)
  $core.String get serverTime => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverTime($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTime() => $_clearField(1);

  /// The model whose coverage was queried (daemon's configured model).
  @$pb.TagNumber(2)
  $core.String get model => $_getSZ(1);
  @$pb.TagNumber(2)
  set model($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasModel() => $_has(1);
  @$pb.TagNumber(2)
  void clearModel() => $_clearField(2);

  /// The DHT prefix actually queried.
  @$pb.TagNumber(3)
  $core.String get dhtPrefix => $_getSZ(2);
  @$pb.TagNumber(3)
  set dhtPrefix($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDhtPrefix() => $_has(2);
  @$pb.TagNumber(3)
  void clearDhtPrefix() => $_clearField(3);

  /// Total transformer blocks in the model.
  @$pb.TagNumber(4)
  $core.int get totalBlocks => $_getIZ(3);
  @$pb.TagNumber(4)
  set totalBlocks($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalBlocks() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalBlocks() => $_clearField(4);

  /// Number of blocks covered by at least one peer.
  @$pb.TagNumber(5)
  $core.int get coveredBlocks => $_getIZ(4);
  @$pb.TagNumber(5)
  set coveredBlocks($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCoveredBlocks() => $_has(4);
  @$pb.TagNumber(5)
  void clearCoveredBlocks() => $_clearField(5);

  /// True when every block is covered — distributed inference ready.
  @$pb.TagNumber(6)
  $core.bool get fullCoverage => $_getBF(5);
  @$pb.TagNumber(6)
  set fullCoverage($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFullCoverage() => $_has(5);
  @$pb.TagNumber(6)
  void clearFullCoverage() => $_clearField(6);

  /// All discovered block servers, sorted by start_block.
  @$pb.TagNumber(7)
  $pb.PbList<BlockPeer> get peers => $_getList(6);
}

/// `kwaainet vpk discover` — VPK storage nodes from the DHT.
class StorageDiscoveryRequest extends $pb.GeneratedMessage {
  factory StorageDiscoveryRequest({
    $core.bool? subscribe,
    $core.int? intervalSecs,
    $core.bool? skipProbes,
  }) {
    final result = create();
    if (subscribe != null) result.subscribe = subscribe;
    if (intervalSecs != null) result.intervalSecs = intervalSecs;
    if (skipProbes != null) result.skipProbes = skipProbes;
    return result;
  }

  StorageDiscoveryRequest._();

  factory StorageDiscoveryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StorageDiscoveryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StorageDiscoveryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'subscribe')
    ..aI(2, _omitFieldNames ? '' : 'intervalSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(3, _omitFieldNames ? '' : 'skipProbes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StorageDiscoveryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StorageDiscoveryRequest copyWith(
          void Function(StorageDiscoveryRequest) updates) =>
      super.copyWith((message) => updates(message as StorageDiscoveryRequest))
          as StorageDiscoveryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StorageDiscoveryRequest create() => StorageDiscoveryRequest._();
  @$core.override
  StorageDiscoveryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StorageDiscoveryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StorageDiscoveryRequest>(create);
  static StorageDiscoveryRequest? _defaultInstance;

  /// When true the operation stays open and the server runs a fresh
  /// discovery round every `interval_secs` until the client sends a
  /// Cancel body for this op id. When false a single round runs and
  /// the op ends with Done.
  @$pb.TagNumber(1)
  $core.bool get subscribe => $_getBF(0);
  @$pb.TagNumber(1)
  set subscribe($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscribe() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscribe() => $_clearField(1);

  /// Discovery cadence for subscriptions, in seconds. 0 means the
  /// server default (30s). Ignored when `subscribe` is false.
  ///
  /// Slower than block coverage by default: each round dials every
  /// advertised node, so a tight interval spends real network work to
  /// observe a registry that only changes on the ~120s announce cycle.
  @$pb.TagNumber(2)
  $core.int get intervalSecs => $_getIZ(1);
  @$pb.TagNumber(2)
  set intervalSecs($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIntervalSecs() => $_has(1);
  @$pb.TagNumber(2)
  void clearIntervalSecs() => $_clearField(2);

  /// Skip the reachability probes and report DHT records only. Yields
  /// a single StorageUpdate per round with every peer left UNKNOWN,
  /// for callers that just want the advertised registry cheaply.
  @$pb.TagNumber(3)
  $core.bool get skipProbes => $_getBF(2);
  @$pb.TagNumber(3)
  set skipProbes($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSkipProbes() => $_has(2);
  @$pb.TagNumber(3)
  void clearSkipProbes() => $_clearField(3);
}

/// One VPK-capable node, as advertised in the DHT and (optionally)
/// confirmed by a live health probe.
class StoragePeer extends $pb.GeneratedMessage {
  factory StoragePeer({
    $core.String? peerId,
    $core.String? publicName,
    $core.String? mode,
    $core.String? vpkVersion,
    $core.double? capacityGb,
    $core.int? tenantCount,
    StorageReachability? reachability,
    $core.double? capacityGbFree,
    $core.double? trustScore,
    $core.String? trustTier,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (publicName != null) result.publicName = publicName;
    if (mode != null) result.mode = mode;
    if (vpkVersion != null) result.vpkVersion = vpkVersion;
    if (capacityGb != null) result.capacityGb = capacityGb;
    if (tenantCount != null) result.tenantCount = tenantCount;
    if (reachability != null) result.reachability = reachability;
    if (capacityGbFree != null) result.capacityGbFree = capacityGbFree;
    if (trustScore != null) result.trustScore = trustScore;
    if (trustTier != null) result.trustTier = trustTier;
    return result;
  }

  StoragePeer._();

  factory StoragePeer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoragePeer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoragePeer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'publicName')
    ..aOS(3, _omitFieldNames ? '' : 'mode')
    ..aOS(4, _omitFieldNames ? '' : 'vpkVersion')
    ..aD(5, _omitFieldNames ? '' : 'capacityGb')
    ..aI(6, _omitFieldNames ? '' : 'tenantCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aE<StorageReachability>(7, _omitFieldNames ? '' : 'reachability',
        enumValues: StorageReachability.values)
    ..aD(8, _omitFieldNames ? '' : 'capacityGbFree')
    ..aD(9, _omitFieldNames ? '' : 'trustScore')
    ..aOS(10, _omitFieldNames ? '' : 'trustTier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoragePeer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoragePeer copyWith(void Function(StoragePeer) updates) =>
      super.copyWith((message) => updates(message as StoragePeer))
          as StoragePeer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoragePeer create() => StoragePeer._();
  @$core.override
  StoragePeer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StoragePeer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StoragePeer>(create);
  static StoragePeer? _defaultInstance;

  /// libp2p peer id, base58.
  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  /// Human-readable name the node announced (may be empty).
  @$pb.TagNumber(2)
  $core.String get publicName => $_getSZ(1);
  @$pb.TagNumber(2)
  set publicName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPublicName() => $_has(1);
  @$pb.TagNumber(2)
  void clearPublicName() => $_clearField(2);

  /// VPK role: "bob" (client), "eve" (server), or "both".
  @$pb.TagNumber(3)
  $core.String get mode => $_getSZ(2);
  @$pb.TagNumber(3)
  set mode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);

  /// VPK version string the node announced (may be empty).
  @$pb.TagNumber(4)
  $core.String get vpkVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set vpkVersion($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVpkVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearVpkVersion() => $_clearField(4);

  /// Capacity the node advertised in its DHT record, in GB. Always
  /// present — this is what the registry claims.
  @$pb.TagNumber(5)
  $core.double get capacityGb => $_getN(4);
  @$pb.TagNumber(5)
  set capacityGb($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCapacityGb() => $_has(4);
  @$pb.TagNumber(5)
  void clearCapacityGb() => $_clearField(5);

  /// Tenants the node advertised in its DHT record.
  @$pb.TagNumber(6)
  $core.int get tenantCount => $_getIZ(5);
  @$pb.TagNumber(6)
  set tenantCount($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTenantCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearTenantCount() => $_clearField(6);

  /// Whether this node answered a health probe this round.
  @$pb.TagNumber(7)
  StorageReachability get reachability => $_getN(6);
  @$pb.TagNumber(7)
  set reachability(StorageReachability value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReachability() => $_has(6);
  @$pb.TagNumber(7)
  void clearReachability() => $_clearField(7);

  /// Free capacity in GB, from the health probe. Only meaningful when
  /// `reachability` is REACHABLE; 0 otherwise.
  @$pb.TagNumber(8)
  $core.double get capacityGbFree => $_getN(7);
  @$pb.TagNumber(8)
  set capacityGbFree($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCapacityGbFree() => $_has(7);
  @$pb.TagNumber(8)
  void clearCapacityGbFree() => $_clearField(8);

  /// Local reputation score in [0, 1]. Only meaningful when
  /// `trust_tier` is non-empty.
  @$pb.TagNumber(9)
  $core.double get trustScore => $_getN(8);
  @$pb.TagNumber(9)
  set trustScore($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTrustScore() => $_has(8);
  @$pb.TagNumber(9)
  void clearTrustScore() => $_clearField(9);

  /// Trust tier label ("UNKNOWN" / "KNOWN" / "VERIFIED" / "TRUSTED").
  /// Empty when the local reputation system is disabled.
  @$pb.TagNumber(10)
  $core.String get trustTier => $_getSZ(9);
  @$pb.TagNumber(10)
  set trustTier($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTrustTier() => $_has(9);
  @$pb.TagNumber(10)
  void clearTrustTier() => $_clearField(10);
}

/// Snapshot of the VPK storage nodes visible from this daemon.
///
/// The first discovery round emits two of these: one as soon as the DHT
/// answers (`probes_pending` true, every peer UNKNOWN), and one once the
/// health probes resolve. The DHT lookup is fast and the probes are not —
/// splitting them lets a client render the registry immediately rather
/// than holding a blank view until the slowest dial times out.
///
/// Subsequent rounds emit at most one update, and only when something
/// actually changed: re-sending the pending phase would throw a client's
/// status column back to "checking" every round, and an unchanged
/// resolved snapshot is suppressed. A client should therefore treat
/// silence as "nothing has changed", not as a stalled feed — an unchanged
/// snapshot is still sent periodically as a heartbeat, so a feed that
/// goes quiet for much longer than the discovery interval is genuinely
/// wedged.
class StorageUpdate extends $pb.GeneratedMessage {
  factory StorageUpdate({
    $core.String? serverTime,
    $core.bool? probesPending,
    $core.Iterable<StoragePeer>? peers,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    if (probesPending != null) result.probesPending = probesPending;
    if (peers != null) result.peers.addAll(peers);
    return result;
  }

  StorageUpdate._();

  factory StorageUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StorageUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StorageUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverTime')
    ..aOB(2, _omitFieldNames ? '' : 'probesPending')
    ..pPM<StoragePeer>(3, _omitFieldNames ? '' : 'peers',
        subBuilder: StoragePeer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StorageUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StorageUpdate copyWith(void Function(StorageUpdate) updates) =>
      super.copyWith((message) => updates(message as StorageUpdate))
          as StorageUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StorageUpdate create() => StorageUpdate._();
  @$core.override
  StorageUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StorageUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StorageUpdate>(create);
  static StorageUpdate? _defaultInstance;

  /// Daemon wall-clock time of this snapshot, RFC 3339.
  @$pb.TagNumber(1)
  $core.String get serverTime => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverTime($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTime() => $_clearField(1);

  /// True on the pending update that opens the *first* round: the peer
  /// list is complete but reachability is still resolving, so a client
  /// should show the rows in a pending state rather than as
  /// unreachable. Never set on later rounds, and never when
  /// `skip_probes` was set.
  @$pb.TagNumber(2)
  $core.bool get probesPending => $_getBF(1);
  @$pb.TagNumber(2)
  set probesPending($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProbesPending() => $_has(1);
  @$pb.TagNumber(2)
  void clearProbesPending() => $_clearField(2);

  /// All discovered nodes, sorted by public_name then peer_id so the
  /// ordering is stable across rounds.
  @$pb.TagNumber(3)
  $pb.PbList<StoragePeer> get peers => $_getList(2);
}

/// `kwaainet p2p peers list`, and more — local swarm state.
///
/// Requires the native p2p stack. The Go p2p daemon's control protocol
/// reports only (peer id, addresses) per connection, so direction,
/// protocols, latency and the routing table have nowhere to come from;
/// rather than serve a mostly-blank view the daemon answers
/// UNIMPLEMENTED, which a client should treat as permanent for the
/// daemon's lifetime. UNAVAILABLE means something different here — the
/// native node is still starting and a retry will succeed.
class NetworkRequest extends $pb.GeneratedMessage {
  factory NetworkRequest({
    $core.bool? subscribe,
    $core.int? intervalSecs,
  }) {
    final result = create();
    if (subscribe != null) result.subscribe = subscribe;
    if (intervalSecs != null) result.intervalSecs = intervalSecs;
    return result;
  }

  NetworkRequest._();

  factory NetworkRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NetworkRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'subscribe')
    ..aI(2, _omitFieldNames ? '' : 'intervalSecs',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkRequest copyWith(void Function(NetworkRequest) updates) =>
      super.copyWith((message) => updates(message as NetworkRequest))
          as NetworkRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkRequest create() => NetworkRequest._();
  @$core.override
  NetworkRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NetworkRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkRequest>(create);
  static NetworkRequest? _defaultInstance;

  /// When true the operation stays open and the server pushes updates
  /// until the client sends a Cancel body for this op id. When false a
  /// single update is sent followed by Done.
  @$pb.TagNumber(1)
  $core.bool get subscribe => $_getBF(0);
  @$pb.TagNumber(1)
  set subscribe($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSubscribe() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscribe() => $_clearField(1);

  /// Refresh cadence for subscriptions, in seconds. 0 means the server
  /// default (5s). Ignored when `subscribe` is false.
  ///
  /// This is the *sampling* floor, not the whole story: connections and
  /// the routing table have no event source and so are polled, but
  /// reachability changes are pushed the moment they happen. See
  /// NetworkUpdate.reason.
  @$pb.TagNumber(2)
  $core.int get intervalSecs => $_getIZ(1);
  @$pb.TagNumber(2)
  set intervalSecs($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIntervalSecs() => $_has(1);
  @$pb.TagNumber(2)
  void clearIntervalSecs() => $_clearField(2);
}

/// One live connection.
///
/// Per connection, not per peer: a peer reachable both directly and over
/// a relay appears twice, which is what makes a hole-punch upgrade
/// visible while it happens.
class ConnectedPeer extends $pb.GeneratedMessage {
  factory ConnectedPeer({
    $core.String? peerId,
    $core.String? addr,
    PeerConnKind? kind,
    $core.String? direction,
    $core.bool? isBootstrap,
    $core.bool? isTrustedRelay,
    $core.Iterable<$core.String>? protocols,
    $core.int? rttMs,
    $core.String? agentVersion,
    $core.bool? dcutr,
    $core.String? via,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (addr != null) result.addr = addr;
    if (kind != null) result.kind = kind;
    if (direction != null) result.direction = direction;
    if (isBootstrap != null) result.isBootstrap = isBootstrap;
    if (isTrustedRelay != null) result.isTrustedRelay = isTrustedRelay;
    if (protocols != null) result.protocols.addAll(protocols);
    if (rttMs != null) result.rttMs = rttMs;
    if (agentVersion != null) result.agentVersion = agentVersion;
    if (dcutr != null) result.dcutr = dcutr;
    if (via != null) result.via = via;
    return result;
  }

  ConnectedPeer._();

  factory ConnectedPeer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectedPeer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectedPeer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'addr')
    ..aE<PeerConnKind>(3, _omitFieldNames ? '' : 'kind',
        enumValues: PeerConnKind.values)
    ..aOS(4, _omitFieldNames ? '' : 'direction')
    ..aOB(5, _omitFieldNames ? '' : 'isBootstrap')
    ..aOB(6, _omitFieldNames ? '' : 'isTrustedRelay')
    ..pPS(7, _omitFieldNames ? '' : 'protocols')
    ..aI(8, _omitFieldNames ? '' : 'rttMs', fieldType: $pb.PbFieldType.OU3)
    ..aOS(9, _omitFieldNames ? '' : 'agentVersion')
    ..aOB(10, _omitFieldNames ? '' : 'dcutr')
    ..aOS(11, _omitFieldNames ? '' : 'via')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectedPeer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectedPeer copyWith(void Function(ConnectedPeer) updates) =>
      super.copyWith((message) => updates(message as ConnectedPeer))
          as ConnectedPeer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectedPeer create() => ConnectedPeer._();
  @$core.override
  ConnectedPeer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectedPeer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectedPeer>(create);
  static ConnectedPeer? _defaultInstance;

  /// libp2p peer id, base58.
  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  /// The connection's multiaddr — the remote address for outbound
  /// connections, the observed send-back address for inbound ones.
  @$pb.TagNumber(2)
  $core.String get addr => $_getSZ(1);
  @$pb.TagNumber(2)
  set addr($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAddr() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddr() => $_clearField(2);

  @$pb.TagNumber(3)
  PeerConnKind get kind => $_getN(2);
  @$pb.TagNumber(3)
  set kind(PeerConnKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  /// "inbound" if the peer dialed us, "outbound" if we dialed them.
  @$pb.TagNumber(4)
  $core.String get direction => $_getSZ(3);
  @$pb.TagNumber(4)
  set direction($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDirection() => $_has(3);
  @$pb.TagNumber(4)
  void clearDirection() => $_clearField(4);

  /// Set when this peer is one of our configured bootstrap nodes.
  @$pb.TagNumber(5)
  $core.bool get isBootstrap => $_getBF(4);
  @$pb.TagNumber(5)
  set isBootstrap($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsBootstrap() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsBootstrap() => $_clearField(5);

  /// Set when this peer is one of our configured trusted relays.
  @$pb.TagNumber(6)
  $core.bool get isTrustedRelay => $_getBF(5);
  @$pb.TagNumber(6)
  set isTrustedRelay($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsTrustedRelay() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsTrustedRelay() => $_clearField(6);

  /// Protocols the peer advertised over identify. Empty until identify
  /// completes, which is shortly *after* the connection establishes —
  /// empty means "not yet known", not "speaks nothing".
  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get protocols => $_getList(6);

  /// Most recent ping round-trip time. 0 means no ping has completed
  /// yet, not zero latency.
  @$pb.TagNumber(8)
  $core.int get rttMs => $_getIZ(7);
  @$pb.TagNumber(8)
  set rttMs($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRttMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearRttMs() => $_clearField(8);

  /// The peer's advertised software version. May be empty.
  @$pb.TagNumber(9)
  $core.String get agentVersion => $_getSZ(8);
  @$pb.TagNumber(9)
  set agentVersion($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAgentVersion() => $_has(8);
  @$pb.TagNumber(9)
  void clearAgentVersion() => $_clearField(9);

  /// Whether DCUtR upgraded this connection from a relayed path to a
  /// direct one.
  ///
  /// Only ever true alongside PEER_CONN_KIND_DIRECT, and it means
  /// something stronger: the path was established *through* a NAT by
  /// coordinated simultaneous dial, rather than there being no NAT in
  /// the way. A node reporting "private" reachability can still hold
  /// upgraded connections — that is DCUtR working, not a
  /// contradiction.
  @$pb.TagNumber(10)
  $core.bool get dcutr => $_getBF(9);
  @$pb.TagNumber(10)
  set dcutr($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDcutr() => $_has(9);
  @$pb.TagNumber(10)
  void clearDcutr() => $_clearField(10);

  /// The relay an inbound connection arrived through, when it was
  /// relayed. Empty otherwise.
  ///
  /// An inbound relayed connection's `addr` is a bare `/p2p/<peer>`: it
  /// names who reached us and says nothing about how. This is the local
  /// end of that connection — our circuit listener — and is the only
  /// place the relay's address and identity appear. Outbound needs no
  /// equivalent, since the dialled address already carries the relay.
  @$pb.TagNumber(11)
  $core.String get via => $_getSZ(10);
  @$pb.TagNumber(11)
  set via($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasVia() => $_has(10);
  @$pb.TagNumber(11)
  void clearVia() => $_clearField(11);
}

/// One entry in the Kademlia routing table.
///
/// The routing table and the connected set overlap but neither contains
/// the other: k-buckets hold a bounded number of entries per distance
/// range, the table deliberately retains peers we are not currently
/// connected to, and kad stays in client mode (adding nothing) until
/// reachability resolves. A young node can have live connections and an
/// empty table.
class RoutingPeer extends $pb.GeneratedMessage {
  factory RoutingPeer({
    $core.String? peerId,
    $core.bool? connected,
    $core.bool? isBootstrap,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (connected != null) result.connected = connected;
    if (isBootstrap != null) result.isBootstrap = isBootstrap;
    return result;
  }

  RoutingPeer._();

  factory RoutingPeer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RoutingPeer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RoutingPeer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOB(2, _omitFieldNames ? '' : 'connected')
    ..aOB(3, _omitFieldNames ? '' : 'isBootstrap')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutingPeer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RoutingPeer copyWith(void Function(RoutingPeer) updates) =>
      super.copyWith((message) => updates(message as RoutingPeer))
          as RoutingPeer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RoutingPeer create() => RoutingPeer._();
  @$core.override
  RoutingPeer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RoutingPeer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RoutingPeer>(create);
  static RoutingPeer? _defaultInstance;

  /// libp2p peer id, base58.
  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  /// Whether this peer also appears in NetworkUpdate.connected.
  @$pb.TagNumber(2)
  $core.bool get connected => $_getBF(1);
  @$pb.TagNumber(2)
  set connected($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConnected() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnected() => $_clearField(2);

  /// Whether this peer is one of our configured bootstrap nodes.
  ///
  /// Derived from local configuration, the same way it is for a
  /// connection: the DHT does not label bootstraps, and which nodes
  /// hold that role is the operator's choice.
  @$pb.TagNumber(3)
  $core.bool get isBootstrap => $_getBF(2);
  @$pb.TagNumber(3)
  set isBootstrap($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsBootstrap() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsBootstrap() => $_clearField(3);
}

/// This node's own position in the network.
class SelfStatus extends $pb.GeneratedMessage {
  factory SelfStatus({
    $core.String? peerId,
    $core.String? reachability,
    $core.String? reachabilitySource,
    $core.bool? usingRelay,
    $core.bool? announceable,
    $core.Iterable<$core.String>? listenAddrs,
    $core.Iterable<$core.String>? observedAddrs,
    $core.Iterable<$core.String>? relayAddrs,
    $core.Iterable<$core.String>? localProtocols,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (reachability != null) result.reachability = reachability;
    if (reachabilitySource != null)
      result.reachabilitySource = reachabilitySource;
    if (usingRelay != null) result.usingRelay = usingRelay;
    if (announceable != null) result.announceable = announceable;
    if (listenAddrs != null) result.listenAddrs.addAll(listenAddrs);
    if (observedAddrs != null) result.observedAddrs.addAll(observedAddrs);
    if (relayAddrs != null) result.relayAddrs.addAll(relayAddrs);
    if (localProtocols != null) result.localProtocols.addAll(localProtocols);
    return result;
  }

  SelfStatus._();

  factory SelfStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SelfStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SelfStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..aOS(2, _omitFieldNames ? '' : 'reachability')
    ..aOS(3, _omitFieldNames ? '' : 'reachabilitySource')
    ..aOB(4, _omitFieldNames ? '' : 'usingRelay')
    ..aOB(5, _omitFieldNames ? '' : 'announceable')
    ..pPS(6, _omitFieldNames ? '' : 'listenAddrs')
    ..pPS(7, _omitFieldNames ? '' : 'observedAddrs')
    ..pPS(8, _omitFieldNames ? '' : 'relayAddrs')
    ..pPS(9, _omitFieldNames ? '' : 'localProtocols')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelfStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SelfStatus copyWith(void Function(SelfStatus) updates) =>
      super.copyWith((message) => updates(message as SelfStatus)) as SelfStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SelfStatus create() => SelfStatus._();
  @$core.override
  SelfStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SelfStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SelfStatus>(create);
  static SelfStatus? _defaultInstance;

  /// Our libp2p peer id, base58.
  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);

  /// "unknown" until a verdict is reached, then "public" or "private".
  /// Announcing is deferred while unknown.
  @$pb.TagNumber(2)
  $core.String get reachability => $_getSZ(1);
  @$pb.TagNumber(2)
  set reachability($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReachability() => $_has(1);
  @$pb.TagNumber(2)
  void clearReachability() => $_clearField(2);

  /// What produced the verdict, weakest evidence first: "identify"
  /// (enough distinct peers reported the same address), "upnp" (the
  /// local gateway says it mapped us), "autonat" (a peer dialed us back
  /// and got through) or "declared" (operator configuration — an
  /// instruction, not evidence at all). Empty unless reachability is
  /// "public": a private or undecided verdict has no source.
  @$pb.TagNumber(3)
  $core.String get reachabilitySource => $_getSZ(2);
  @$pb.TagNumber(3)
  set reachabilitySource($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReachabilitySource() => $_has(2);
  @$pb.TagNumber(3)
  void clearReachabilitySource() => $_clearField(3);

  /// Whether at least one *confirmed* circuit reservation is live. A
  /// requested-but-unanswered reservation does not count.
  @$pb.TagNumber(4)
  $core.bool get usingRelay => $_getBF(3);
  @$pb.TagNumber(4)
  set usingRelay($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUsingRelay() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsingRelay() => $_clearField(4);

  /// Whether there is any point announcing to the DHT yet. False only
  /// while reachability is unknown.
  @$pb.TagNumber(5)
  $core.bool get announceable => $_getBF(4);
  @$pb.TagNumber(5)
  set announceable($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAnnounceable() => $_has(4);
  @$pb.TagNumber(5)
  void clearAnnounceable() => $_clearField(5);

  /// The swarm's listen addresses.
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get listenAddrs => $_getList(5);

  /// Addresses peers reported observing us at — our external-address
  /// candidates. Ordered by the number of distinct peers that agreed,
  /// most-confirmed first.
  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get observedAddrs => $_getList(6);

  /// Addresses of confirmed circuit-relay reservations. Empty when not
  /// relaying.
  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get relayAddrs => $_getList(7);

  /// Protocols this node serves to peers, sorted.
  ///
  /// The handlers actually registered rather than everything the swarm
  /// might negotiate: libp2p keeps its full advertised set private, and
  /// this is the more useful answer anyway — it is what this node will
  /// *do* for a peer, which is what a reader comparing it against a
  /// peer's protocol list wants to know.
  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get localProtocols => $_getList(8);
}

/// Snapshot of local p2p state.
///
/// A subscription suppresses unchanged snapshots, so a client should read
/// silence as "nothing changed" rather than as a stalled feed — an
/// unchanged snapshot is still sent periodically as a heartbeat, so a
/// feed quiet for much longer than the heartbeat is genuinely wedged.
class NetworkUpdate extends $pb.GeneratedMessage {
  factory NetworkUpdate({
    $core.String? serverTime,
    UpdateReason? reason,
    SelfStatus? selfStatus,
    $core.Iterable<ConnectedPeer>? connected,
    $core.Iterable<RoutingPeer>? routing,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    if (reason != null) result.reason = reason;
    if (selfStatus != null) result.selfStatus = selfStatus;
    if (connected != null) result.connected.addAll(connected);
    if (routing != null) result.routing.addAll(routing);
    return result;
  }

  NetworkUpdate._();

  factory NetworkUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NetworkUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'serverTime')
    ..aE<UpdateReason>(2, _omitFieldNames ? '' : 'reason',
        enumValues: UpdateReason.values)
    ..aOM<SelfStatus>(3, _omitFieldNames ? '' : 'selfStatus',
        subBuilder: SelfStatus.create)
    ..pPM<ConnectedPeer>(4, _omitFieldNames ? '' : 'connected',
        subBuilder: ConnectedPeer.create)
    ..pPM<RoutingPeer>(5, _omitFieldNames ? '' : 'routing',
        subBuilder: RoutingPeer.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkUpdate copyWith(void Function(NetworkUpdate) updates) =>
      super.copyWith((message) => updates(message as NetworkUpdate))
          as NetworkUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NetworkUpdate create() => NetworkUpdate._();
  @$core.override
  NetworkUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NetworkUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkUpdate>(create);
  static NetworkUpdate? _defaultInstance;

  /// Daemon wall-clock time of this snapshot, RFC 3339.
  @$pb.TagNumber(1)
  $core.String get serverTime => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverTime($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerTime() => $_clearField(1);

  @$pb.TagNumber(2)
  UpdateReason get reason => $_getN(1);
  @$pb.TagNumber(2)
  set reason(UpdateReason value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  SelfStatus get selfStatus => $_getN(2);
  @$pb.TagNumber(3)
  set selfStatus(SelfStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSelfStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelfStatus() => $_clearField(3);
  @$pb.TagNumber(3)
  SelfStatus ensureSelfStatus() => $_ensure(2);

  /// One entry per live connection, ordered bootstrap → trusted relay →
  /// direct → relayed, then by peer id, so the ordering is stable
  /// across updates.
  @$pb.TagNumber(4)
  $pb.PbList<ConnectedPeer> get connected => $_getList(3);

  /// The Kademlia routing table, sorted by peer id.
  @$pb.TagNumber(5)
  $pb.PbList<RoutingPeer> get routing => $_getList(4);
}

class ChatMessage extends $pb.GeneratedMessage {
  factory ChatMessage({
    $core.String? content,
    $core.String? role,
    $core.String? conversationId,
  }) {
    final result = create();
    if (content != null) result.content = content;
    if (role != null) result.role = role;
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  ChatMessage._();

  factory ChatMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..aOS(2, _omitFieldNames ? '' : 'role')
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMessage copyWith(void Function(ChatMessage) updates) =>
      super.copyWith((message) => updates(message as ChatMessage))
          as ChatMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatMessage create() => ChatMessage._();
  @$core.override
  ChatMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatMessage>(create);
  static ChatMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get role => $_getSZ(1);
  @$pb.TagNumber(2)
  set role($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);
}

class ChatToken extends $pb.GeneratedMessage {
  factory ChatToken({
    $core.String? text,
    $core.bool? done,
    $core.String? finishReason,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (done != null) result.done = done;
    if (finishReason != null) result.finishReason = finishReason;
    return result;
  }

  ChatToken._();

  factory ChatToken.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ChatToken.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatToken',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOB(2, _omitFieldNames ? '' : 'done')
    ..aOS(3, _omitFieldNames ? '' : 'finishReason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatToken clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatToken copyWith(void Function(ChatToken) updates) =>
      super.copyWith((message) => updates(message as ChatToken)) as ChatToken;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ChatToken create() => ChatToken._();
  @$core.override
  ChatToken createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ChatToken getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatToken>(create);
  static ChatToken? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get done => $_getBF(1);
  @$pb.TagNumber(2)
  set done($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDone() => $_has(1);
  @$pb.TagNumber(2)
  void clearDone() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get finishReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set finishReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFinishReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearFinishReason() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
