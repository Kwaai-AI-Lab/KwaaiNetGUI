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
  connect,
  ragStatus,
  ragInit,
  ragIngest,
  ragQuery,
  ragIngestData,
  ragDelete,
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
    ConnectRequest? connect,
    RagStatusRequest? ragStatus,
    RagInitRequest? ragInit,
    RagIngestRequest? ragIngest,
    RagQueryRequest? ragQuery,
    RagIngestData? ragIngestData,
    RagDeleteRequest? ragDelete,
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
    if (connect != null) result.connect = connect;
    if (ragStatus != null) result.ragStatus = ragStatus;
    if (ragInit != null) result.ragInit = ragInit;
    if (ragIngest != null) result.ragIngest = ragIngest;
    if (ragQuery != null) result.ragQuery = ragQuery;
    if (ragIngestData != null) result.ragIngestData = ragIngestData;
    if (ragDelete != null) result.ragDelete = ragDelete;
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
    18: ClientFrame_Body.connect,
    20: ClientFrame_Body.ragStatus,
    21: ClientFrame_Body.ragInit,
    22: ClientFrame_Body.ragIngest,
    23: ClientFrame_Body.ragQuery,
    24: ClientFrame_Body.ragIngestData,
    25: ClientFrame_Body.ragDelete,
    0: ClientFrame_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25])
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
    ..aOM<ConnectRequest>(18, _omitFieldNames ? '' : 'connect',
        subBuilder: ConnectRequest.create)
    ..aOM<RagStatusRequest>(20, _omitFieldNames ? '' : 'ragStatus',
        subBuilder: RagStatusRequest.create)
    ..aOM<RagInitRequest>(21, _omitFieldNames ? '' : 'ragInit',
        subBuilder: RagInitRequest.create)
    ..aOM<RagIngestRequest>(22, _omitFieldNames ? '' : 'ragIngest',
        subBuilder: RagIngestRequest.create)
    ..aOM<RagQueryRequest>(23, _omitFieldNames ? '' : 'ragQuery',
        subBuilder: RagQueryRequest.create)
    ..aOM<RagIngestData>(24, _omitFieldNames ? '' : 'ragIngestData',
        subBuilder: RagIngestData.create)
    ..aOM<RagDeleteRequest>(25, _omitFieldNames ? '' : 'ragDelete',
        subBuilder: RagDeleteRequest.create)
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
  @$pb.TagNumber(18)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  ClientFrame_Body whichBody() => _ClientFrame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
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

  /// Dial a peer by id. One ConnectReply, then Done.
  @$pb.TagNumber(18)
  ConnectRequest get connect => $_getN(9);
  @$pb.TagNumber(18)
  set connect(ConnectRequest value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasConnect() => $_has(9);
  @$pb.TagNumber(18)
  void clearConnect() => $_clearField(18);
  @$pb.TagNumber(18)
  ConnectRequest ensureConnect() => $_ensure(9);

  /// Snapshot of every configured knowledge base. One
  /// ServerFrame.rag_status reply, then Done. An empty kbs list
  /// means "RAG is compiled in but nothing is initialised"; a
  /// build without the `rag` feature answers UNIMPLEMENTED
  /// instead, so the client can tell the two apart.
  @$pb.TagNumber(20)
  RagStatusRequest get ragStatus => $_getN(10);
  @$pb.TagNumber(20)
  set ragStatus(RagStatusRequest value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasRagStatus() => $_has(10);
  @$pb.TagNumber(20)
  void clearRagStatus() => $_clearField(20);
  @$pb.TagNumber(20)
  RagStatusRequest ensureRagStatus() => $_ensure(10);

  /// Create (or idempotently re-create) a knowledge base. Probes
  /// the embedding model for its dimension, so it fails with
  /// UNAVAILABLE when Ollama isn't reachable.
  @$pb.TagNumber(21)
  RagInitRequest get ragInit => $_getN(11);
  @$pb.TagNumber(21)
  set ragInit(RagInitRequest value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasRagInit() => $_has(11);
  @$pb.TagNumber(21)
  void clearRagInit() => $_clearField(21);
  @$pb.TagNumber(21)
  RagInitRequest ensureRagInit() => $_ensure(11);

  /// Ingest one document, whose bytes follow as rag_ingest_data
  /// frames under this op's id. Emits ServerFrame.rag_progress
  /// frames before the terminal rag_ingest reply. Reusing the id
  /// of an op still in flight fails with INVALID_ARGUMENT.
  /// Cancellable. A cancel, or the session closing, mid-upload ends
  /// the ingest; one that fails or is cancelled after storing
  /// vectors removes them again (best-effort).
  @$pb.TagNumber(22)
  RagIngestRequest get ragIngest => $_getN(12);
  @$pb.TagNumber(22)
  set ragIngest(RagIngestRequest value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasRagIngest() => $_has(12);
  @$pb.TagNumber(22)
  void clearRagIngest() => $_clearField(22);
  @$pb.TagNumber(22)
  RagIngestRequest ensureRagIngest() => $_ensure(12);

  /// Retrieve chunks for a query. One ServerFrame.rag_query reply,
  /// then Done.
  @$pb.TagNumber(23)
  RagQueryRequest get ragQuery => $_getN(13);
  @$pb.TagNumber(23)
  set ragQuery(RagQueryRequest value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasRagQuery() => $_has(13);
  @$pb.TagNumber(23)
  void clearRagQuery() => $_clearField(23);
  @$pb.TagNumber(23)
  RagQueryRequest ensureRagQuery() => $_ensure(13);

  /// One piece of an ingest's document, sent in order with
  /// ClientFrame.id set to that ingest's id. Acknowledged by a
  /// RAG_PHASE_RECEIVING progress frame; see RagIngestData.
  @$pb.TagNumber(24)
  RagIngestData get ragIngestData => $_getN(14);
  @$pb.TagNumber(24)
  set ragIngestData(RagIngestData value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasRagIngestData() => $_has(14);
  @$pb.TagNumber(24)
  void clearRagIngestData() => $_clearField(24);
  @$pb.TagNumber(24)
  RagIngestData ensureRagIngestData() => $_ensure(14);

  /// Remove one document and every chunk it contributed. One
  /// ServerFrame.rag_delete reply, then Done. Deleting a document
  /// the KB doesn't hold is NOT_FOUND rather than a silent no-op,
  /// so a stale UI row doesn't read as a successful delete.
  @$pb.TagNumber(25)
  RagDeleteRequest get ragDelete => $_getN(15);
  @$pb.TagNumber(25)
  set ragDelete(RagDeleteRequest value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasRagDelete() => $_has(15);
  @$pb.TagNumber(25)
  void clearRagDelete() => $_clearField(25);
  @$pb.TagNumber(25)
  RagDeleteRequest ensureRagDelete() => $_ensure(15);
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
  connect,
  ragStatus,
  ragInit,
  ragProgress,
  ragQuery,
  ragIngest,
  ragDelete,
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
    ConnectReply? connect,
    RagStatusUpdate? ragStatus,
    RagInitReply? ragInit,
    RagProgress? ragProgress,
    RagQueryReply? ragQuery,
    RagIngestReply? ragIngest,
    RagDeleteReply? ragDelete,
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
    if (connect != null) result.connect = connect;
    if (ragStatus != null) result.ragStatus = ragStatus;
    if (ragInit != null) result.ragInit = ragInit;
    if (ragProgress != null) result.ragProgress = ragProgress;
    if (ragQuery != null) result.ragQuery = ragQuery;
    if (ragIngest != null) result.ragIngest = ragIngest;
    if (ragDelete != null) result.ragDelete = ragDelete;
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
    18: ServerFrame_Body.connect,
    20: ServerFrame_Body.ragStatus,
    21: ServerFrame_Body.ragInit,
    22: ServerFrame_Body.ragProgress,
    23: ServerFrame_Body.ragQuery,
    24: ServerFrame_Body.ragIngest,
    25: ServerFrame_Body.ragDelete,
    0: ServerFrame_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerFrame',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25])
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
    ..aOM<ConnectReply>(18, _omitFieldNames ? '' : 'connect',
        subBuilder: ConnectReply.create)
    ..aOM<RagStatusUpdate>(20, _omitFieldNames ? '' : 'ragStatus',
        subBuilder: RagStatusUpdate.create)
    ..aOM<RagInitReply>(21, _omitFieldNames ? '' : 'ragInit',
        subBuilder: RagInitReply.create)
    ..aOM<RagProgress>(22, _omitFieldNames ? '' : 'ragProgress',
        subBuilder: RagProgress.create)
    ..aOM<RagQueryReply>(23, _omitFieldNames ? '' : 'ragQuery',
        subBuilder: RagQueryReply.create)
    ..aOM<RagIngestReply>(24, _omitFieldNames ? '' : 'ragIngest',
        subBuilder: RagIngestReply.create)
    ..aOM<RagDeleteReply>(25, _omitFieldNames ? '' : 'ragDelete',
        subBuilder: RagDeleteReply.create)
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
  @$pb.TagNumber(18)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
  ServerFrame_Body whichBody() => _ServerFrame_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  @$pb.TagNumber(24)
  @$pb.TagNumber(25)
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

  /// Reply to a ConnectRequest.
  @$pb.TagNumber(18)
  ConnectReply get connect => $_getN(9);
  @$pb.TagNumber(18)
  set connect(ConnectReply value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasConnect() => $_has(9);
  @$pb.TagNumber(18)
  void clearConnect() => $_clearField(18);
  @$pb.TagNumber(18)
  ConnectReply ensureConnect() => $_ensure(9);

  /// Reply to RagStatusRequest.
  @$pb.TagNumber(20)
  RagStatusUpdate get ragStatus => $_getN(10);
  @$pb.TagNumber(20)
  set ragStatus(RagStatusUpdate value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasRagStatus() => $_has(10);
  @$pb.TagNumber(20)
  void clearRagStatus() => $_clearField(20);
  @$pb.TagNumber(20)
  RagStatusUpdate ensureRagStatus() => $_ensure(10);

  /// Reply to RagInitRequest.
  @$pb.TagNumber(21)
  RagInitReply get ragInit => $_getN(11);
  @$pb.TagNumber(21)
  set ragInit(RagInitReply value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasRagInit() => $_has(11);
  @$pb.TagNumber(21)
  void clearRagInit() => $_clearField(21);
  @$pb.TagNumber(21)
  RagInitReply ensureRagInit() => $_ensure(11);

  /// Mid-operation progress for rag_ingest. Zero or more of these
  /// precede the terminal rag_ingest reply; a client that ignores
  /// them still gets a correct result.
  @$pb.TagNumber(22)
  RagProgress get ragProgress => $_getN(12);
  @$pb.TagNumber(22)
  set ragProgress(RagProgress value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasRagProgress() => $_has(12);
  @$pb.TagNumber(22)
  void clearRagProgress() => $_clearField(22);
  @$pb.TagNumber(22)
  RagProgress ensureRagProgress() => $_ensure(12);

  /// Reply to RagQueryRequest.
  @$pb.TagNumber(23)
  RagQueryReply get ragQuery => $_getN(13);
  @$pb.TagNumber(23)
  set ragQuery(RagQueryReply value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasRagQuery() => $_has(13);
  @$pb.TagNumber(23)
  void clearRagQuery() => $_clearField(23);
  @$pb.TagNumber(23)
  RagQueryReply ensureRagQuery() => $_ensure(13);

  /// Terminal reply to RagIngestRequest.
  @$pb.TagNumber(24)
  RagIngestReply get ragIngest => $_getN(14);
  @$pb.TagNumber(24)
  set ragIngest(RagIngestReply value) => $_setField(24, value);
  @$pb.TagNumber(24)
  $core.bool hasRagIngest() => $_has(14);
  @$pb.TagNumber(24)
  void clearRagIngest() => $_clearField(24);
  @$pb.TagNumber(24)
  RagIngestReply ensureRagIngest() => $_ensure(14);

  /// Reply to RagDeleteRequest.
  @$pb.TagNumber(25)
  RagDeleteReply get ragDelete => $_getN(15);
  @$pb.TagNumber(25)
  set ragDelete(RagDeleteReply value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasRagDelete() => $_has(15);
  @$pb.TagNumber(25)
  void clearRagDelete() => $_clearField(25);
  @$pb.TagNumber(25)
  RagDeleteReply ensureRagDelete() => $_ensure(15);
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
    $core.int? bootstrapTotal,
    $core.int? bootstrapReachable,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    if (model != null) result.model = model;
    if (shardReady != null) result.shardReady = shardReady;
    if (peerCount != null) result.peerCount = peerCount;
    if (uptimeSecs != null) result.uptimeSecs = uptimeSecs;
    if (version != null) result.version = version;
    if (bootstrapTotal != null) result.bootstrapTotal = bootstrapTotal;
    if (bootstrapReachable != null)
      result.bootstrapReachable = bootstrapReachable;
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
    ..aI(7, _omitFieldNames ? '' : 'bootstrapTotal',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'bootstrapReachable',
        fieldType: $pb.PbFieldType.OU3)
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

  /// Bootstrap connectivity, for surfacing "my configured initial peers
  /// are down" to clients. `bootstrap_total` counts the distinct peer IDs
  /// derivable from the configured bootstrap set (initial_peers, or the
  /// built-in defaults when that list is absent); entries without a /p2p
  /// component contribute nothing, so 0 with peers configured means the
  /// condition is unknowable, not healthy.
  ///
  /// `bootstrap_reachable` counts those that are currently connected OR
  /// successfully established a connection within the last ~15 minutes.
  /// Recency, not the live set, because bootstraps close idle connections
  /// (~30s) while the announce loop re-contacts them every ~5 minutes, so
  /// a healthy idle node keeps refreshing inside the window. And not the
  /// routing table, because kad seeds it with the configured addresses
  /// before any dial succeeds — membership proves nothing.
  ///
  /// Both 0 on daemons built before these fields existed and on the Go
  /// p2p path; clients should only act on reachable == 0 when total > 0.
  @$pb.TagNumber(7)
  $core.int get bootstrapTotal => $_getIZ(6);
  @$pb.TagNumber(7)
  set bootstrapTotal($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBootstrapTotal() => $_has(6);
  @$pb.TagNumber(7)
  void clearBootstrapTotal() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get bootstrapReachable => $_getIZ(7);
  @$pb.TagNumber(8)
  set bootstrapReachable($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBootstrapReachable() => $_has(7);
  @$pb.TagNumber(8)
  void clearBootstrapReachable() => $_clearField(8);
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
    DhtRole? dhtRole,
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
    if (dhtRole != null) result.dhtRole = dhtRole;
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
    ..aE<DhtRole>(12, _omitFieldNames ? '' : 'dhtRole',
        enumValues: DhtRole.values)
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

  /// Whether this peer serves the DHT, from its advertised protocols.
  ///
  /// Separate from is_bootstrap/is_trusted_relay rather than a variant
  /// of them: those are operator configuration, this is observed peer
  /// behaviour, and they are independent. A client-mode peer still
  /// advertises circuit relay hop, and a relayed node of ours runs kad
  /// in client mode while remaining a full peer — so "client" is a
  /// marker on a row, not a role that replaces the others.
  @$pb.TagNumber(12)
  DhtRole get dhtRole => $_getN(11);
  @$pb.TagNumber(12)
  set dhtRole(DhtRole value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasDhtRole() => $_has(11);
  @$pb.TagNumber(12)
  void clearDhtRole() => $_clearField(12);
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
    $core.Iterable<$core.String>? addrs,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    if (connected != null) result.connected = connected;
    if (isBootstrap != null) result.isBootstrap = isBootstrap;
    if (addrs != null) result.addrs.addAll(addrs);
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
    ..pPS(4, _omitFieldNames ? '' : 'addrs')
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

  /// The addresses the routing table holds for this peer, as multiaddr
  /// strings.
  ///
  /// Empty means kad knows the peer but has no address a third party
  /// could dial — a materially different state from "known and not
  /// currently connected", and one a peer id alone cannot express. It is
  /// also what makes a poisoned entry legible: a peer whose only address
  /// is its own loopback reads as healthy until the address is visible.
  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get addrs => $_getList(3);
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
    $core.String? ipv6,
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
    if (ipv6 != null) result.ipv6 = ipv6;
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
    ..aOS(10, _omitFieldNames ? '' : 'ipv6')
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

  /// What IPv6 ended up doing: "off" | "active" | "unavailable". Empty
  /// from a daemon predating the field.
  @$pb.TagNumber(10)
  $core.String get ipv6 => $_getSZ(9);
  @$pb.TagNumber(10)
  set ipv6($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIpv6() => $_has(9);
  @$pb.TagNumber(10)
  void clearIpv6() => $_clearField(10);
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
    $core.int? bootstrapTotal,
    $core.int? bootstrapReachable,
  }) {
    final result = create();
    if (serverTime != null) result.serverTime = serverTime;
    if (reason != null) result.reason = reason;
    if (selfStatus != null) result.selfStatus = selfStatus;
    if (connected != null) result.connected.addAll(connected);
    if (routing != null) result.routing.addAll(routing);
    if (bootstrapTotal != null) result.bootstrapTotal = bootstrapTotal;
    if (bootstrapReachable != null)
      result.bootstrapReachable = bootstrapReachable;
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
    ..aI(6, _omitFieldNames ? '' : 'bootstrapTotal',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'bootstrapReachable',
        fieldType: $pb.PbFieldType.OU3)
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

  /// Bootstrap connectivity, so a client can tell "my configured initial
  /// peers are down" apart from ordinary churn. Same definitions as the
  /// StatusReply pair: `bootstrap_total` is the distinct peer IDs derivable
  /// from the configured bootstrap set (0 = unknowable, not healthy), and
  /// `bootstrap_reachable` counts those connected or successfully connected
  /// within the last ~15 minutes — see StatusReply for why neither the live
  /// set nor the routing table can carry this on its own.
  ///
  /// Both fields are part of the subscription's change identity, so a flip
  /// in either direction — a bootstrap appearing, or the count falling as
  /// the contact window expires — is pushed on the next sample rather than
  /// suppressed as an unchanged snapshot.
  @$pb.TagNumber(6)
  $core.int get bootstrapTotal => $_getIZ(5);
  @$pb.TagNumber(6)
  set bootstrapTotal($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBootstrapTotal() => $_has(5);
  @$pb.TagNumber(6)
  void clearBootstrapTotal() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get bootstrapReachable => $_getIZ(6);
  @$pb.TagNumber(7)
  set bootstrapReachable($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasBootstrapReachable() => $_has(6);
  @$pb.TagNumber(7)
  void clearBootstrapReachable() => $_clearField(7);
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

/// Dial a peer we know of but hold no connection to.
///
/// A bare peer id is resolved through the DHT first, the way Go's routed
/// host does it, so the caller does not need an address — which is the
/// point: the routing table knows peers it has no connection to, and this
/// is how you reach one.
///
/// Note this makes *us* the dialer, so it will not trigger a DCUtR
/// upgrade: libp2p has the inbound side initiate hole punching.
class ConnectRequest extends $pb.GeneratedMessage {
  factory ConnectRequest({
    $core.String? peerId,
  }) {
    final result = create();
    if (peerId != null) result.peerId = peerId;
    return result;
  }

  ConnectRequest._();

  factory ConnectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'peerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectRequest copyWith(void Function(ConnectRequest) updates) =>
      super.copyWith((message) => updates(message as ConnectRequest))
          as ConnectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectRequest create() => ConnectRequest._();
  @$core.override
  ConnectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectRequest>(create);
  static ConnectRequest? _defaultInstance;

  /// libp2p peer id, base58. An address is resolved via the DHT.
  @$pb.TagNumber(1)
  $core.String get peerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set peerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPeerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeerId() => $_clearField(1);
}

class ConnectReply extends $pb.GeneratedMessage {
  factory ConnectReply({
    $core.bool? connected,
    $core.String? error,
  }) {
    final result = create();
    if (connected != null) result.connected = connected;
    if (error != null) result.error = error;
    return result;
  }

  ConnectReply._();

  factory ConnectReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'connected')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectReply copyWith(void Function(ConnectReply) updates) =>
      super.copyWith((message) => updates(message as ConnectReply))
          as ConnectReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectReply create() => ConnectReply._();
  @$core.override
  ConnectReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectReply>(create);
  static ConnectReply? _defaultInstance;

  /// True when a connection exists after the attempt — including when
  /// one already existed, since the caller's goal is met either way.
  @$pb.TagNumber(1)
  $core.bool get connected => $_getBF(0);
  @$pb.TagNumber(1)
  set connected($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConnected() => $_has(0);
  @$pb.TagNumber(1)
  void clearConnected() => $_clearField(1);

  /// Failure detail, empty on success.
  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// One knowledge base as reported by rag_status / rag_init.
class RagKb extends $pb.GeneratedMessage {
  factory RagKb({
    $core.String? name,
    $core.String? embedModel,
    $core.bool? remote,
    $core.Iterable<RagDoc>? documents,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (embedModel != null) result.embedModel = embedModel;
    if (remote != null) result.remote = remote;
    if (documents != null) result.documents.addAll(documents);
    return result;
  }

  RagKb._();

  factory RagKb.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagKb.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagKb',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'embedModel')
    ..aOB(3, _omitFieldNames ? '' : 'remote')
    ..pPM<RagDoc>(4, _omitFieldNames ? '' : 'documents',
        subBuilder: RagDoc.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagKb clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagKb copyWith(void Function(RagKb) updates) =>
      super.copyWith((message) => updates(message as RagKb)) as RagKb;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagKb create() => RagKb._();
  @$core.override
  RagKb createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagKb getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RagKb>(create);
  static RagKb? _defaultInstance;

  /// KB name, e.g. "default". Unique per daemon.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Ollama embedding model this KB was initialised with. Chunks
  /// embedded with a different model are not comparable, so this is
  /// effectively part of the KB's identity.
  @$pb.TagNumber(2)
  $core.String get embedModel => $_getSZ(1);
  @$pb.TagNumber(2)
  set embedModel($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmbedModel() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmbedModel() => $_clearField(2);

  /// True when the KB's vectors live somewhere other than the local
  /// embedded store (a remote Eve node or an HTTP storage service).
  /// Phase 1 can report these but not query or ingest into them.
  @$pb.TagNumber(3)
  $core.bool get remote => $_getBF(2);
  @$pb.TagNumber(3)
  set remote($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRemote() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemote() => $_clearField(3);

  /// Documents ingested so far, each with its chunk count. Best-effort:
  /// a KB whose metadata store can't be opened is still reported, with
  /// an empty list, rather than failing the whole status op.
  @$pb.TagNumber(4)
  $pb.PbList<RagDoc> get documents => $_getList(3);
}

/// One ingested document, as reported by rag_status.
class RagDoc extends $pb.GeneratedMessage {
  factory RagDoc({
    $core.String? name,
    $core.int? chunks,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (chunks != null) result.chunks = chunks;
    return result;
  }

  RagDoc._();

  factory RagDoc.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagDoc.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagDoc',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'chunks', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagDoc clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagDoc copyWith(void Function(RagDoc) updates) =>
      super.copyWith((message) => updates(message as RagDoc)) as RagDoc;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagDoc create() => RagDoc._();
  @$core.override
  RagDoc createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagDoc getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RagDoc>(create);
  static RagDoc? _defaultInstance;

  /// Display name recorded at ingest — what rag_delete expects back.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Chunks this document contributed, which is also its vector count.
  /// 0 when the metadata row exists but couldn't be read, rather than
  /// omitting the document entirely.
  @$pb.TagNumber(2)
  $core.int get chunks => $_getIZ(1);
  @$pb.TagNumber(2)
  set chunks($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChunks() => $_has(1);
  @$pb.TagNumber(2)
  void clearChunks() => $_clearField(2);
}

class RagStatusRequest extends $pb.GeneratedMessage {
  factory RagStatusRequest() => create();

  RagStatusRequest._();

  factory RagStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagStatusRequest copyWith(void Function(RagStatusRequest) updates) =>
      super.copyWith((message) => updates(message as RagStatusRequest))
          as RagStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagStatusRequest create() => RagStatusRequest._();
  @$core.override
  RagStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagStatusRequest>(create);
  static RagStatusRequest? _defaultInstance;
}

class RagStatusUpdate extends $pb.GeneratedMessage {
  factory RagStatusUpdate({
    $core.Iterable<RagKb>? kbs,
  }) {
    final result = create();
    if (kbs != null) result.kbs.addAll(kbs);
    return result;
  }

  RagStatusUpdate._();

  factory RagStatusUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagStatusUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagStatusUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..pPM<RagKb>(1, _omitFieldNames ? '' : 'kbs', subBuilder: RagKb.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagStatusUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagStatusUpdate copyWith(void Function(RagStatusUpdate) updates) =>
      super.copyWith((message) => updates(message as RagStatusUpdate))
          as RagStatusUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagStatusUpdate create() => RagStatusUpdate._();
  @$core.override
  RagStatusUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagStatusUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagStatusUpdate>(create);
  static RagStatusUpdate? _defaultInstance;

  /// Empty when RAG is compiled in but no KB has been initialised.
  @$pb.TagNumber(1)
  $pb.PbList<RagKb> get kbs => $_getList(0);
}

class RagInitRequest extends $pb.GeneratedMessage {
  factory RagInitRequest({
    $core.String? kb,
    $core.String? embedModel,
  }) {
    final result = create();
    if (kb != null) result.kb = kb;
    if (embedModel != null) result.embedModel = embedModel;
    return result;
  }

  RagInitRequest._();

  factory RagInitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagInitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagInitRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kb')
    ..aOS(2, _omitFieldNames ? '' : 'embedModel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagInitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagInitRequest copyWith(void Function(RagInitRequest) updates) =>
      super.copyWith((message) => updates(message as RagInitRequest))
          as RagInitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagInitRequest create() => RagInitRequest._();
  @$core.override
  RagInitRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagInitRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagInitRequest>(create);
  static RagInitRequest? _defaultInstance;

  /// KB to create. Empty means "default". Re-initialising an existing
  /// KB keeps its data directory and documents; a remote KB answers
  /// UNIMPLEMENTED.
  @$pb.TagNumber(1)
  $core.String get kb => $_getSZ(0);
  @$pb.TagNumber(1)
  set kb($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKb() => $_has(0);
  @$pb.TagNumber(1)
  void clearKb() => $_clearField(1);

  /// Ollama embedding model. Empty means the daemon's default for a new
  /// KB and the current model for an existing one. Changing the model of
  /// a KB that holds documents fails with INVALID_ARGUMENT.
  @$pb.TagNumber(2)
  $core.String get embedModel => $_getSZ(1);
  @$pb.TagNumber(2)
  set embedModel($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmbedModel() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmbedModel() => $_clearField(2);
}

class RagInitReply extends $pb.GeneratedMessage {
  factory RagInitReply({
    RagKb? kb,
  }) {
    final result = create();
    if (kb != null) result.kb = kb;
    return result;
  }

  RagInitReply._();

  factory RagInitReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagInitReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagInitReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOM<RagKb>(1, _omitFieldNames ? '' : 'kb', subBuilder: RagKb.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagInitReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagInitReply copyWith(void Function(RagInitReply) updates) =>
      super.copyWith((message) => updates(message as RagInitReply))
          as RagInitReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagInitReply create() => RagInitReply._();
  @$core.override
  RagInitReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagInitReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagInitReply>(create);
  static RagInitReply? _defaultInstance;

  /// The KB as it exists after init. `documents` is empty for a fresh
  /// KB and populated when init refreshed an existing one.
  @$pb.TagNumber(1)
  RagKb get kb => $_getN(0);
  @$pb.TagNumber(1)
  set kb(RagKb value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasKb() => $_has(0);
  @$pb.TagNumber(1)
  void clearKb() => $_clearField(1);
  @$pb.TagNumber(1)
  RagKb ensureKb() => $_ensure(0);
}

class RagIngestRequest extends $pb.GeneratedMessage {
  factory RagIngestRequest({
    $core.String? kb,
    $core.String? docName,
    $fixnum.Int64? size,
  }) {
    final result = create();
    if (kb != null) result.kb = kb;
    if (docName != null) result.docName = docName;
    if (size != null) result.size = size;
    return result;
  }

  RagIngestRequest._();

  factory RagIngestRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagIngestRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagIngestRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kb')
    ..aOS(2, _omitFieldNames ? '' : 'docName')
    ..a<$fixnum.Int64>(3, _omitFieldNames ? '' : 'size', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagIngestRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagIngestRequest copyWith(void Function(RagIngestRequest) updates) =>
      super.copyWith((message) => updates(message as RagIngestRequest))
          as RagIngestRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagIngestRequest create() => RagIngestRequest._();
  @$core.override
  RagIngestRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagIngestRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagIngestRequest>(create);
  static RagIngestRequest? _defaultInstance;

  /// KB to ingest into. Empty means "default".
  @$pb.TagNumber(1)
  $core.String get kb => $_getSZ(0);
  @$pb.TagNumber(1)
  set kb($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKb() => $_has(0);
  @$pb.TagNumber(1)
  void clearKb() => $_clearField(1);

  /// Display name for the document, required. Its extension picks the
  /// parser (`.pdf`, `.docx`, …), so send the original file name.
  @$pb.TagNumber(2)
  $core.String get docName => $_getSZ(1);
  @$pb.TagNumber(2)
  set docName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDocName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDocName() => $_clearField(2);

  /// Total bytes the rag_ingest_data frames will carry, above 0 and at
  /// most 256 MiB. The ingest starts once exactly this many have
  /// arrived. A piece carrying bytes past it fails the ingest; pieces
  /// sent after exactly `size` bytes are discarded.
  ///
  /// A daemon receives at most 4 uploads at once; beyond that the
  /// ingest fails with UNAVAILABLE before any piece is read.
  @$pb.TagNumber(3)
  $fixnum.Int64 get size => $_getI64(2);
  @$pb.TagNumber(3)
  set size($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);
}

/// A piece of the document an ingest is uploading. Keep each well under
/// the 4 MiB gRPC frame limit; 256 KiB is a good size.
///
/// Flow control is a window of 8 pieces: at most 8 may be unacknowledged
/// (sent, with no RAG_PHASE_RECEIVING frame for them yet). The server
/// buffers no more, so a ninth can fail the ingest with INVALID_ARGUMENT.
/// An upload that sends nothing for 60 s fails the same way.
class RagIngestData extends $pb.GeneratedMessage {
  factory RagIngestData({
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (data != null) result.data = data;
    return result;
  }

  RagIngestData._();

  factory RagIngestData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagIngestData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagIngestData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagIngestData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagIngestData copyWith(void Function(RagIngestData) updates) =>
      super.copyWith((message) => updates(message as RagIngestData))
          as RagIngestData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagIngestData create() => RagIngestData._();
  @$core.override
  RagIngestData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagIngestData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagIngestData>(create);
  static RagIngestData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

/// Progress for an in-flight ingest. Deliberately ONE flat message with
/// a phase enum rather than a oneof-per-phase: phases are a fixed,
/// ordered pipeline sharing the same done/total shape, and a flat
/// message lets a client render a progress bar without a match on
/// every variant. Adding a phase later is then an enum value, not a
/// new oneof arm every client must handle.
class RagProgress extends $pb.GeneratedMessage {
  factory RagProgress({
    RagProgress_RagPhase? phase,
    $core.int? done,
    $core.int? total,
    $core.String? detail,
  }) {
    final result = create();
    if (phase != null) result.phase = phase;
    if (done != null) result.done = done;
    if (total != null) result.total = total;
    if (detail != null) result.detail = detail;
    return result;
  }

  RagProgress._();

  factory RagProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aE<RagProgress_RagPhase>(1, _omitFieldNames ? '' : 'phase',
        enumValues: RagProgress_RagPhase.values)
    ..aI(2, _omitFieldNames ? '' : 'done', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'total', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'detail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagProgress copyWith(void Function(RagProgress) updates) =>
      super.copyWith((message) => updates(message as RagProgress))
          as RagProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagProgress create() => RagProgress._();
  @$core.override
  RagProgress createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagProgress getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagProgress>(create);
  static RagProgress? _defaultInstance;

  @$pb.TagNumber(1)
  RagProgress_RagPhase get phase => $_getN(0);
  @$pb.TagNumber(1)
  set phase(RagProgress_RagPhase value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPhase() => $_has(0);
  @$pb.TagNumber(1)
  void clearPhase() => $_clearField(1);

  /// Units completed / expected for this phase. Both 0 when the
  /// phase has no meaningful subdivision.
  @$pb.TagNumber(2)
  $core.int get done => $_getIZ(1);
  @$pb.TagNumber(2)
  set done($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDone() => $_has(1);
  @$pb.TagNumber(2)
  void clearDone() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get total => $_getIZ(2);
  @$pb.TagNumber(3)
  set total($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotal() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotal() => $_clearField(3);

  /// Optional human-readable detail (e.g. the document name).
  @$pb.TagNumber(4)
  $core.String get detail => $_getSZ(3);
  @$pb.TagNumber(4)
  set detail($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDetail() => $_has(3);
  @$pb.TagNumber(4)
  void clearDetail() => $_clearField(4);
}

class RagIngestReply extends $pb.GeneratedMessage {
  factory RagIngestReply({
    $core.int? chunksIngested,
    $core.int? vectorsUploaded,
  }) {
    final result = create();
    if (chunksIngested != null) result.chunksIngested = chunksIngested;
    if (vectorsUploaded != null) result.vectorsUploaded = vectorsUploaded;
    return result;
  }

  RagIngestReply._();

  factory RagIngestReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagIngestReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagIngestReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'chunksIngested',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'vectorsUploaded',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagIngestReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagIngestReply copyWith(void Function(RagIngestReply) updates) =>
      super.copyWith((message) => updates(message as RagIngestReply))
          as RagIngestReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagIngestReply create() => RagIngestReply._();
  @$core.override
  RagIngestReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagIngestReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagIngestReply>(create);
  static RagIngestReply? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get chunksIngested => $_getIZ(0);
  @$pb.TagNumber(1)
  set chunksIngested($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChunksIngested() => $_has(0);
  @$pb.TagNumber(1)
  void clearChunksIngested() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get vectorsUploaded => $_getIZ(1);
  @$pb.TagNumber(2)
  set vectorsUploaded($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVectorsUploaded() => $_has(1);
  @$pb.TagNumber(2)
  void clearVectorsUploaded() => $_clearField(2);
}

class RagQueryRequest extends $pb.GeneratedMessage {
  factory RagQueryRequest({
    $core.String? kb,
    $core.String? text,
    $core.int? topK,
    $core.double? minScore,
  }) {
    final result = create();
    if (kb != null) result.kb = kb;
    if (text != null) result.text = text;
    if (topK != null) result.topK = topK;
    if (minScore != null) result.minScore = minScore;
    return result;
  }

  RagQueryRequest._();

  factory RagQueryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagQueryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagQueryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kb')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aI(3, _omitFieldNames ? '' : 'topK', fieldType: $pb.PbFieldType.OU3)
    ..aD(4, _omitFieldNames ? '' : 'minScore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagQueryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagQueryRequest copyWith(void Function(RagQueryRequest) updates) =>
      super.copyWith((message) => updates(message as RagQueryRequest))
          as RagQueryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagQueryRequest create() => RagQueryRequest._();
  @$core.override
  RagQueryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagQueryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagQueryRequest>(create);
  static RagQueryRequest? _defaultInstance;

  /// KB to query. Empty means "default".
  @$pb.TagNumber(1)
  $core.String get kb => $_getSZ(0);
  @$pb.TagNumber(1)
  set kb($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKb() => $_has(0);
  @$pb.TagNumber(1)
  void clearKb() => $_clearField(1);

  /// The query text.
  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  /// Max chunks to return. 0 means the server default (20).
  @$pb.TagNumber(3)
  $core.int get topK => $_getIZ(2);
  @$pb.TagNumber(3)
  set topK($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTopK() => $_has(2);
  @$pb.TagNumber(3)
  void clearTopK() => $_clearField(3);

  /// Drop chunks scoring below this. 0 keeps everything.
  @$pb.TagNumber(4)
  $core.double get minScore => $_getN(3);
  @$pb.TagNumber(4)
  set minScore($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMinScore() => $_has(3);
  @$pb.TagNumber(4)
  void clearMinScore() => $_clearField(4);
}

/// One retrieved chunk. Mirrors the JSON the HTTP RAG API returns.
class RagChunk extends $pb.GeneratedMessage {
  factory RagChunk({
    $core.int? rank,
    $core.double? score,
    $core.String? doc,
    $core.int? chunkIndex,
    $core.String? text,
  }) {
    final result = create();
    if (rank != null) result.rank = rank;
    if (score != null) result.score = score;
    if (doc != null) result.doc = doc;
    if (chunkIndex != null) result.chunkIndex = chunkIndex;
    if (text != null) result.text = text;
    return result;
  }

  RagChunk._();

  factory RagChunk.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagChunk.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagChunk',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'rank', fieldType: $pb.PbFieldType.OU3)
    ..aD(2, _omitFieldNames ? '' : 'score')
    ..aOS(3, _omitFieldNames ? '' : 'doc')
    ..aI(4, _omitFieldNames ? '' : 'chunkIndex', fieldType: $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagChunk clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagChunk copyWith(void Function(RagChunk) updates) =>
      super.copyWith((message) => updates(message as RagChunk)) as RagChunk;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagChunk create() => RagChunk._();
  @$core.override
  RagChunk createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagChunk getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RagChunk>(create);
  static RagChunk? _defaultInstance;

  /// 1-based position in the result list.
  @$pb.TagNumber(1)
  $core.int get rank => $_getIZ(0);
  @$pb.TagNumber(1)
  set rank($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRank() => $_has(0);
  @$pb.TagNumber(1)
  void clearRank() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get score => $_getN(1);
  @$pb.TagNumber(2)
  set score($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScore() => $_has(1);
  @$pb.TagNumber(2)
  void clearScore() => $_clearField(2);

  /// Document this chunk came from.
  @$pb.TagNumber(3)
  $core.String get doc => $_getSZ(2);
  @$pb.TagNumber(3)
  set doc($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDoc() => $_has(2);
  @$pb.TagNumber(3)
  void clearDoc() => $_clearField(3);

  /// 0-based index of the chunk within its document.
  @$pb.TagNumber(4)
  $core.int get chunkIndex => $_getIZ(3);
  @$pb.TagNumber(4)
  set chunkIndex($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChunkIndex() => $_has(3);
  @$pb.TagNumber(4)
  void clearChunkIndex() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get text => $_getSZ(4);
  @$pb.TagNumber(5)
  set text($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasText() => $_has(4);
  @$pb.TagNumber(5)
  void clearText() => $_clearField(5);
}

class RagQueryReply extends $pb.GeneratedMessage {
  factory RagQueryReply({
    $core.Iterable<RagChunk>? chunks,
  }) {
    final result = create();
    if (chunks != null) result.chunks.addAll(chunks);
    return result;
  }

  RagQueryReply._();

  factory RagQueryReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagQueryReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagQueryReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..pPM<RagChunk>(1, _omitFieldNames ? '' : 'chunks',
        subBuilder: RagChunk.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagQueryReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagQueryReply copyWith(void Function(RagQueryReply) updates) =>
      super.copyWith((message) => updates(message as RagQueryReply))
          as RagQueryReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagQueryReply create() => RagQueryReply._();
  @$core.override
  RagQueryReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagQueryReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagQueryReply>(create);
  static RagQueryReply? _defaultInstance;

  /// Ordered best-first. Empty when nothing cleared min_score.
  @$pb.TagNumber(1)
  $pb.PbList<RagChunk> get chunks => $_getList(0);
}

class RagDeleteRequest extends $pb.GeneratedMessage {
  factory RagDeleteRequest({
    $core.String? kb,
    $core.String? docName,
  }) {
    final result = create();
    if (kb != null) result.kb = kb;
    if (docName != null) result.docName = docName;
    return result;
  }

  RagDeleteRequest._();

  factory RagDeleteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagDeleteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagDeleteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kb')
    ..aOS(2, _omitFieldNames ? '' : 'docName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagDeleteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagDeleteRequest copyWith(void Function(RagDeleteRequest) updates) =>
      super.copyWith((message) => updates(message as RagDeleteRequest))
          as RagDeleteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagDeleteRequest create() => RagDeleteRequest._();
  @$core.override
  RagDeleteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagDeleteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagDeleteRequest>(create);
  static RagDeleteRequest? _defaultInstance;

  /// KB to delete from. Empty means "default".
  @$pb.TagNumber(1)
  $core.String get kb => $_getSZ(0);
  @$pb.TagNumber(1)
  set kb($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKb() => $_has(0);
  @$pb.TagNumber(1)
  void clearKb() => $_clearField(1);

  /// Document name as reported in RagDoc.name — the display name the
  /// ingest recorded, not a filesystem path. Deleting by name rather
  /// than by chunk id keeps the client from having to know how a
  /// document was split.
  @$pb.TagNumber(2)
  $core.String get docName => $_getSZ(1);
  @$pb.TagNumber(2)
  set docName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDocName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDocName() => $_clearField(2);
}

class RagDeleteReply extends $pb.GeneratedMessage {
  factory RagDeleteReply({
    $core.int? chunksDeleted,
  }) {
    final result = create();
    if (chunksDeleted != null) result.chunksDeleted = chunksDeleted;
    return result;
  }

  RagDeleteReply._();

  factory RagDeleteReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RagDeleteReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RagDeleteReply',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'kwaai.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'chunksDeleted',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagDeleteReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RagDeleteReply copyWith(void Function(RagDeleteReply) updates) =>
      super.copyWith((message) => updates(message as RagDeleteReply))
          as RagDeleteReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RagDeleteReply create() => RagDeleteReply._();
  @$core.override
  RagDeleteReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RagDeleteReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RagDeleteReply>(create);
  static RagDeleteReply? _defaultInstance;

  /// Chunks removed from the metadata store, which is also the number
  /// of vectors dropped. Never 0 on success: a document with no chunks
  /// answers NOT_FOUND instead.
  @$pb.TagNumber(1)
  $core.int get chunksDeleted => $_getIZ(0);
  @$pb.TagNumber(1)
  set chunksDeleted($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChunksDeleted() => $_has(0);
  @$pb.TagNumber(1)
  void clearChunksDeleted() => $_clearField(1);
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
