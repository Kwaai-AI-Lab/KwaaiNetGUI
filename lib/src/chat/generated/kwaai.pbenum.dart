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

import 'package:protobuf/protobuf.dart' as $pb;

/// Whether a discovered node answered a storage RPC.
///
/// Reachability is a property of *this* node's route to the peer, not of
/// the peer itself: a node behind a NAT that we cannot traverse is
/// unreachable from here and fine from elsewhere.
class StorageReachability extends $pb.ProtobufEnum {
  /// Not probed yet. Every peer holds this in the first update of a
  /// round, and keeps it for the whole round when `skip_probes` is set.
  static const StorageReachability STORAGE_REACHABILITY_UNKNOWN =
      StorageReachability._(
          0, _omitEnumNames ? '' : 'STORAGE_REACHABILITY_UNKNOWN');

  /// Answered a /kwaai/storage/1.0.0 health RPC. `capacity_gb_free`
  /// and `tenant_count` on this peer are live values from that reply.
  static const StorageReachability STORAGE_REACHABILITY_REACHABLE =
      StorageReachability._(
          1, _omitEnumNames ? '' : 'STORAGE_REACHABILITY_REACHABLE');

  /// Advertised in the DHT but did not answer — offline, or running a
  /// build without the storage protocol.
  static const StorageReachability STORAGE_REACHABILITY_UNREACHABLE =
      StorageReachability._(
          2, _omitEnumNames ? '' : 'STORAGE_REACHABILITY_UNREACHABLE');

  static const $core.List<StorageReachability> values = <StorageReachability>[
    STORAGE_REACHABILITY_UNKNOWN,
    STORAGE_REACHABILITY_REACHABLE,
    STORAGE_REACHABILITY_UNREACHABLE,
  ];

  static final $core.List<StorageReachability?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static StorageReachability? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StorageReachability._(super.value, super.name);
}

/// Why a NetworkUpdate was sent.
///
/// Without this a client cannot tell a routine sample from a genuine
/// event, and would have to infer it by diffing successive snapshots.
class UpdateReason extends $pb.ProtobufEnum {
  /// The refresh timer fired and something changed, or this is the
  /// single update of a one-shot request.
  static const UpdateReason UPDATE_REASON_TICK =
      UpdateReason._(0, _omitEnumNames ? '' : 'UPDATE_REASON_TICK');

  /// Reachability, relay use, or announceability moved. Sent
  /// immediately rather than on the next tick boundary.
  static const UpdateReason UPDATE_REASON_REACHABILITY =
      UpdateReason._(1, _omitEnumNames ? '' : 'UPDATE_REASON_REACHABILITY');

  /// The connected-peer or routing set changed since the last update.
  static const UpdateReason UPDATE_REASON_PEERS =
      UpdateReason._(2, _omitEnumNames ? '' : 'UPDATE_REASON_PEERS');

  /// Nothing changed. Sent periodically so a client can distinguish a
  /// quiet network from a stalled feed.
  static const UpdateReason UPDATE_REASON_HEARTBEAT =
      UpdateReason._(3, _omitEnumNames ? '' : 'UPDATE_REASON_HEARTBEAT');

  static const $core.List<UpdateReason> values = <UpdateReason>[
    UPDATE_REASON_TICK,
    UPDATE_REASON_REACHABILITY,
    UPDATE_REASON_PEERS,
    UPDATE_REASON_HEARTBEAT,
  ];

  static final $core.List<UpdateReason?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static UpdateReason? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UpdateReason._(super.value, super.name);
}

/// How a connection reaches the peer.
class PeerConnKind extends $pb.ProtobufEnum {
  /// A plain transport address — directly dialable.
  static const PeerConnKind PEER_CONN_KIND_DIRECT =
      PeerConnKind._(0, _omitEnumNames ? '' : 'PEER_CONN_KIND_DIRECT');

  /// The path runs through a circuit relay.
  static const PeerConnKind PEER_CONN_KIND_RELAY =
      PeerConnKind._(1, _omitEnumNames ? '' : 'PEER_CONN_KIND_RELAY');

  static const $core.List<PeerConnKind> values = <PeerConnKind>[
    PEER_CONN_KIND_DIRECT,
    PEER_CONN_KIND_RELAY,
  ];

  static final $core.List<PeerConnKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static PeerConnKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PeerConnKind._(super.value, super.name);
}

/// A peer's DHT participation, as reported by identify.
///
/// Three states, not a bool: identify completes shortly *after* the
/// connection establishes, so a freshly-connected peer has no protocol
/// list yet. UNKNOWN keeps that gap honest — a client filtering on this
/// would otherwise blink rows in and out as connections settle.
class DhtRole extends $pb.ProtobufEnum {
  /// Identify has not reported this peer's protocols yet.
  static const DhtRole DHT_ROLE_UNKNOWN =
      DhtRole._(0, _omitEnumNames ? '' : 'DHT_ROLE_UNKNOWN');

  /// Advertises kad: a routing hop that can store records and be
  /// returned as a lookup result.
  static const DhtRole DHT_ROLE_SERVER =
      DhtRole._(1, _omitEnumNames ? '' : 'DHT_ROLE_SERVER');

  /// Identify completed and kad was absent. Queries the DHT without
  /// serving it. Common and permanent — every hivemind/Python process
  /// proxies through such a peer, and rust-libp2p nodes sit in this
  /// mode until reachability resolves.
  static const DhtRole DHT_ROLE_CLIENT =
      DhtRole._(2, _omitEnumNames ? '' : 'DHT_ROLE_CLIENT');

  static const $core.List<DhtRole> values = <DhtRole>[
    DHT_ROLE_UNKNOWN,
    DHT_ROLE_SERVER,
    DHT_ROLE_CLIENT,
  ];

  static final $core.List<DhtRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static DhtRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DhtRole._(super.value, super.name);
}

/// What stage of a distributed run an InferenceEvent describes.
///
/// Open enum: a client that does not recognise a value must render the
/// event's `message` generically rather than dropping it, so a newer
/// daemon's added phases stay legible on an older client.
class InferencePhase extends $pb.ProtobufEnum {
  static const InferencePhase INFERENCE_PHASE_UNSPECIFIED =
      InferencePhase._(0, _omitEnumNames ? '' : 'INFERENCE_PHASE_UNSPECIFIED');

  /// Run accepted; model / dht_prefix / total_blocks resolved.
  /// Sets: model, dht_prefix, total_blocks.
  static const InferencePhase INFERENCE_PHASE_RESOLVED =
      InferencePhase._(1, _omitEnumNames ? '' : 'INFERENCE_PHASE_RESOLVED');

  /// A DHT discovery round is starting. Sets: attempt, dht_prefix.
  static const InferencePhase INFERENCE_PHASE_DISCOVERY_START =
      InferencePhase._(
          2, _omitEnumNames ? '' : 'INFERENCE_PHASE_DISCOVERY_START');

  /// A discovery round returned. Sets: attempt, peer_count,
  /// covered_blocks, total_blocks. peer_count == 0 means the round
  /// found nothing and another attempt follows, up to the 30s cap.
  static const InferencePhase INFERENCE_PHASE_DISCOVERY_RESULT =
      InferencePhase._(
          3, _omitEnumNames ? '' : 'INFERENCE_PHASE_DISCOVERY_RESULT');

  /// The chain came from a saved circuit rather than the DHT.
  /// Sets: circuit_id, peer_count.
  static const InferencePhase INFERENCE_PHASE_CIRCUIT_LOADED = InferencePhase._(
      4, _omitEnumNames ? '' : 'INFERENCE_PHASE_CIRCUIT_LOADED');

  /// The route for this run was pinned. Sets: hops (ordered, gapless,
  /// covering [0, total_blocks)) and total_blocks. Re-emitted after a
  /// rebuild with `attempt` incremented.
  static const InferencePhase INFERENCE_PHASE_CHAIN_PINNED =
      InferencePhase._(5, _omitEnumNames ? '' : 'INFERENCE_PHASE_CHAIN_PINNED');

  /// Best-effort dial of a chain member before generation starts.
  /// Sets: peer_id, peer_name, ok.
  static const InferencePhase INFERENCE_PHASE_PEER_DIAL =
      InferencePhase._(6, _omitEnumNames ? '' : 'INFERENCE_PHASE_PEER_DIAL');

  /// A hop is being dispatched. Sets: peer_id, peer_name, block_start,
  /// block_end, is_self, token_index, is_prefill, candidate_index.
  static const InferencePhase INFERENCE_PHASE_HOP_START =
      InferencePhase._(7, _omitEnumNames ? '' : 'INFERENCE_PHASE_HOP_START');

  /// A hop returned activations or logits. Sets everything HOP_START
  /// does, plus duration_ms.
  static const InferencePhase INFERENCE_PHASE_HOP_OK =
      InferencePhase._(8, _omitEnumNames ? '' : 'INFERENCE_PHASE_HOP_OK');

  /// A hop failed. Sets everything HOP_START does, plus duration_ms,
  /// message (the error) and failure. Followed by either a HOP_START
  /// for the next candidate at the same block_start, or a
  /// PATH_REBUILD when no candidate is left.
  static const InferencePhase INFERENCE_PHASE_HOP_FAILED =
      InferencePhase._(9, _omitEnumNames ? '' : 'INFERENCE_PHASE_HOP_FAILED');

  /// Every candidate for a block position failed; the path is being
  /// rebuilt and the token retried. The KV cache is lost at this
  /// point, so output may degrade. Sets: block_start, message, attempt.
  static const InferencePhase INFERENCE_PHASE_PATH_REBUILD = InferencePhase._(
      10, _omitEnumNames ? '' : 'INFERENCE_PHASE_PATH_REBUILD');

  /// A token was sampled. Sets: token_index, is_prefill, duration_ms
  /// (wall time for this token's whole forward pass).
  static const InferencePhase INFERENCE_PHASE_TOKEN_SAMPLED = InferencePhase._(
      11, _omitEnumNames ? '' : 'INFERENCE_PHASE_TOKEN_SAMPLED');

  /// Generation finished. Sets: token_index (total generated),
  /// duration_ms (whole run) and message (the stop reason).
  static const InferencePhase INFERENCE_PHASE_COMPLETE =
      InferencePhase._(12, _omitEnumNames ? '' : 'INFERENCE_PHASE_COMPLETE');

  static const $core.List<InferencePhase> values = <InferencePhase>[
    INFERENCE_PHASE_UNSPECIFIED,
    INFERENCE_PHASE_RESOLVED,
    INFERENCE_PHASE_DISCOVERY_START,
    INFERENCE_PHASE_DISCOVERY_RESULT,
    INFERENCE_PHASE_CIRCUIT_LOADED,
    INFERENCE_PHASE_CHAIN_PINNED,
    INFERENCE_PHASE_PEER_DIAL,
    INFERENCE_PHASE_HOP_START,
    INFERENCE_PHASE_HOP_OK,
    INFERENCE_PHASE_HOP_FAILED,
    INFERENCE_PHASE_PATH_REBUILD,
    INFERENCE_PHASE_TOKEN_SAMPLED,
    INFERENCE_PHASE_COMPLETE,
  ];

  static final $core.List<InferencePhase?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static InferencePhase? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const InferencePhase._(super.value, super.name);
}

/// Why a hop failed, which decides whether the peer stays eligible for
/// the rest of the run.
class HopFailure extends $pb.ProtobufEnum {
  static const HopFailure HOP_FAILURE_UNSPECIFIED =
      HopFailure._(0, _omitEnumNames ? '' : 'HOP_FAILURE_UNSPECIFIED');

  /// The peer answered but has no inference handler registered
  /// ("protocols not supported"). Blacklisted for this run.
  static const HopFailure HOP_FAILURE_NO_HANDLER =
      HopFailure._(1, _omitEnumNames ? '' : 'HOP_FAILURE_NO_HANDLER');

  /// Stream reset, early eof, or connection closed. NOT blacklisted:
  /// the peer may recover and is retried on the next token.
  static const HopFailure HOP_FAILURE_TRANSIENT =
      HopFailure._(2, _omitEnumNames ? '' : 'HOP_FAILURE_TRANSIENT');

  /// Exceeded the per-hop deadline. Blacklisted for this run.
  static const HopFailure HOP_FAILURE_TIMEOUT =
      HopFailure._(3, _omitEnumNames ? '' : 'HOP_FAILURE_TIMEOUT');

  /// Anything else. Blacklisted for this run.
  static const HopFailure HOP_FAILURE_OTHER =
      HopFailure._(4, _omitEnumNames ? '' : 'HOP_FAILURE_OTHER');

  static const $core.List<HopFailure> values = <HopFailure>[
    HOP_FAILURE_UNSPECIFIED,
    HOP_FAILURE_NO_HANDLER,
    HOP_FAILURE_TRANSIENT,
    HOP_FAILURE_TIMEOUT,
    HOP_FAILURE_OTHER,
  ];

  static final $core.List<HopFailure?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static HopFailure? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HopFailure._(super.value, super.name);
}

class Error_Code extends $pb.ProtobufEnum {
  static const Error_Code UNKNOWN =
      Error_Code._(0, _omitEnumNames ? '' : 'UNKNOWN');
  static const Error_Code INVALID_ARGUMENT =
      Error_Code._(1, _omitEnumNames ? '' : 'INVALID_ARGUMENT');
  static const Error_Code NOT_FOUND =
      Error_Code._(2, _omitEnumNames ? '' : 'NOT_FOUND');
  static const Error_Code UNAVAILABLE =
      Error_Code._(3, _omitEnumNames ? '' : 'UNAVAILABLE');
  static const Error_Code CANCELLED =
      Error_Code._(4, _omitEnumNames ? '' : 'CANCELLED');
  static const Error_Code INTERNAL =
      Error_Code._(5, _omitEnumNames ? '' : 'INTERNAL');
  static const Error_Code UNIMPLEMENTED =
      Error_Code._(6, _omitEnumNames ? '' : 'UNIMPLEMENTED');

  /// The DHT had no peers serving this model at all. Often
  /// transient at startup before discovery completes; sometimes
  /// permanent if the model isn't being served by anyone on the
  /// network.
  static const Error_Code NO_PEERS_FOR_MODEL =
      Error_Code._(7, _omitEnumNames ? '' : 'NO_PEERS_FOR_MODEL');

  /// Peers exist but they don't collectively cover every block
  /// of the model — the dispatcher can't build a full chain.
  static const Error_Code INSUFFICIENT_COVERAGE =
      Error_Code._(8, _omitEnumNames ? '' : 'INSUFFICIENT_COVERAGE');

  /// A chain was built but every candidate for at least one
  /// position failed mid-inference (most peers don't actually
  /// have a working inference handler).
  static const Error_Code ALL_CANDIDATES_FAILED =
      Error_Code._(9, _omitEnumNames ? '' : 'ALL_CANDIDATES_FAILED');

  /// The local InferenceEngine couldn't load the requested
  /// model (HF download error, Ollama blob missing, OOM, etc.).
  /// Only emitted by the `generate` path, not `shard_run`.
  static const Error_Code MODEL_LOAD_FAILED =
      Error_Code._(10, _omitEnumNames ? '' : 'MODEL_LOAD_FAILED');

  static const $core.List<Error_Code> values = <Error_Code>[
    UNKNOWN,
    INVALID_ARGUMENT,
    NOT_FOUND,
    UNAVAILABLE,
    CANCELLED,
    INTERNAL,
    UNIMPLEMENTED,
    NO_PEERS_FOR_MODEL,
    INSUFFICIENT_COVERAGE,
    ALL_CANDIDATES_FAILED,
    MODEL_LOAD_FAILED,
  ];

  static final $core.List<Error_Code?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static Error_Code? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Error_Code._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
