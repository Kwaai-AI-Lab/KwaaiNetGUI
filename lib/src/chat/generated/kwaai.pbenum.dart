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
