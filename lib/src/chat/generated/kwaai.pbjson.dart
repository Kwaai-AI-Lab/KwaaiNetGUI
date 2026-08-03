// This is a generated file - do not edit.
//
// Generated from kwaai.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use storageReachabilityDescriptor instead')
const StorageReachability$json = {
  '1': 'StorageReachability',
  '2': [
    {'1': 'STORAGE_REACHABILITY_UNKNOWN', '2': 0},
    {'1': 'STORAGE_REACHABILITY_REACHABLE', '2': 1},
    {'1': 'STORAGE_REACHABILITY_UNREACHABLE', '2': 2},
  ],
};

/// Descriptor for `StorageReachability`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List storageReachabilityDescriptor = $convert.base64Decode(
    'ChNTdG9yYWdlUmVhY2hhYmlsaXR5EiAKHFNUT1JBR0VfUkVBQ0hBQklMSVRZX1VOS05PV04QAB'
    'IiCh5TVE9SQUdFX1JFQUNIQUJJTElUWV9SRUFDSEFCTEUQARIkCiBTVE9SQUdFX1JFQUNIQUJJ'
    'TElUWV9VTlJFQUNIQUJMRRAC');

@$core.Deprecated('Use updateReasonDescriptor instead')
const UpdateReason$json = {
  '1': 'UpdateReason',
  '2': [
    {'1': 'UPDATE_REASON_TICK', '2': 0},
    {'1': 'UPDATE_REASON_REACHABILITY', '2': 1},
    {'1': 'UPDATE_REASON_PEERS', '2': 2},
    {'1': 'UPDATE_REASON_HEARTBEAT', '2': 3},
  ],
};

/// Descriptor for `UpdateReason`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List updateReasonDescriptor = $convert.base64Decode(
    'CgxVcGRhdGVSZWFzb24SFgoSVVBEQVRFX1JFQVNPTl9USUNLEAASHgoaVVBEQVRFX1JFQVNPTl'
    '9SRUFDSEFCSUxJVFkQARIXChNVUERBVEVfUkVBU09OX1BFRVJTEAISGwoXVVBEQVRFX1JFQVNP'
    'Tl9IRUFSVEJFQVQQAw==');

@$core.Deprecated('Use peerConnKindDescriptor instead')
const PeerConnKind$json = {
  '1': 'PeerConnKind',
  '2': [
    {'1': 'PEER_CONN_KIND_DIRECT', '2': 0},
    {'1': 'PEER_CONN_KIND_RELAY', '2': 1},
  ],
};

/// Descriptor for `PeerConnKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List peerConnKindDescriptor = $convert.base64Decode(
    'CgxQZWVyQ29ubktpbmQSGQoVUEVFUl9DT05OX0tJTkRfRElSRUNUEAASGAoUUEVFUl9DT05OX0'
    'tJTkRfUkVMQVkQAQ==');

@$core.Deprecated('Use dhtRoleDescriptor instead')
const DhtRole$json = {
  '1': 'DhtRole',
  '2': [
    {'1': 'DHT_ROLE_UNKNOWN', '2': 0},
    {'1': 'DHT_ROLE_SERVER', '2': 1},
    {'1': 'DHT_ROLE_CLIENT', '2': 2},
  ],
};

/// Descriptor for `DhtRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List dhtRoleDescriptor = $convert.base64Decode(
    'CgdEaHRSb2xlEhQKEERIVF9ST0xFX1VOS05PV04QABITCg9ESFRfUk9MRV9TRVJWRVIQARITCg'
    '9ESFRfUk9MRV9DTElFTlQQAg==');

@$core.Deprecated('Use inferencePhaseDescriptor instead')
const InferencePhase$json = {
  '1': 'InferencePhase',
  '2': [
    {'1': 'INFERENCE_PHASE_UNSPECIFIED', '2': 0},
    {'1': 'INFERENCE_PHASE_RESOLVED', '2': 1},
    {'1': 'INFERENCE_PHASE_DISCOVERY_START', '2': 2},
    {'1': 'INFERENCE_PHASE_DISCOVERY_RESULT', '2': 3},
    {'1': 'INFERENCE_PHASE_CIRCUIT_LOADED', '2': 4},
    {'1': 'INFERENCE_PHASE_CHAIN_PINNED', '2': 5},
    {'1': 'INFERENCE_PHASE_PEER_DIAL', '2': 6},
    {'1': 'INFERENCE_PHASE_HOP_START', '2': 7},
    {'1': 'INFERENCE_PHASE_HOP_OK', '2': 8},
    {'1': 'INFERENCE_PHASE_HOP_FAILED', '2': 9},
    {'1': 'INFERENCE_PHASE_PATH_REBUILD', '2': 10},
    {'1': 'INFERENCE_PHASE_TOKEN_SAMPLED', '2': 11},
    {'1': 'INFERENCE_PHASE_COMPLETE', '2': 12},
  ],
};

/// Descriptor for `InferencePhase`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List inferencePhaseDescriptor = $convert.base64Decode(
    'Cg5JbmZlcmVuY2VQaGFzZRIfChtJTkZFUkVOQ0VfUEhBU0VfVU5TUEVDSUZJRUQQABIcChhJTk'
    'ZFUkVOQ0VfUEhBU0VfUkVTT0xWRUQQARIjCh9JTkZFUkVOQ0VfUEhBU0VfRElTQ09WRVJZX1NU'
    'QVJUEAISJAogSU5GRVJFTkNFX1BIQVNFX0RJU0NPVkVSWV9SRVNVTFQQAxIiCh5JTkZFUkVOQ0'
    'VfUEhBU0VfQ0lSQ1VJVF9MT0FERUQQBBIgChxJTkZFUkVOQ0VfUEhBU0VfQ0hBSU5fUElOTkVE'
    'EAUSHQoZSU5GRVJFTkNFX1BIQVNFX1BFRVJfRElBTBAGEh0KGUlORkVSRU5DRV9QSEFTRV9IT1'
    'BfU1RBUlQQBxIaChZJTkZFUkVOQ0VfUEhBU0VfSE9QX09LEAgSHgoaSU5GRVJFTkNFX1BIQVNF'
    'X0hPUF9GQUlMRUQQCRIgChxJTkZFUkVOQ0VfUEhBU0VfUEFUSF9SRUJVSUxEEAoSIQodSU5GRV'
    'JFTkNFX1BIQVNFX1RPS0VOX1NBTVBMRUQQCxIcChhJTkZFUkVOQ0VfUEhBU0VfQ09NUExFVEUQ'
    'DA==');

@$core.Deprecated('Use hopFailureDescriptor instead')
const HopFailure$json = {
  '1': 'HopFailure',
  '2': [
    {'1': 'HOP_FAILURE_UNSPECIFIED', '2': 0},
    {'1': 'HOP_FAILURE_NO_HANDLER', '2': 1},
    {'1': 'HOP_FAILURE_TRANSIENT', '2': 2},
    {'1': 'HOP_FAILURE_TIMEOUT', '2': 3},
    {'1': 'HOP_FAILURE_OTHER', '2': 4},
  ],
};

/// Descriptor for `HopFailure`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List hopFailureDescriptor = $convert.base64Decode(
    'CgpIb3BGYWlsdXJlEhsKF0hPUF9GQUlMVVJFX1VOU1BFQ0lGSUVEEAASGgoWSE9QX0ZBSUxVUk'
    'VfTk9fSEFORExFUhABEhkKFUhPUF9GQUlMVVJFX1RSQU5TSUVOVBACEhcKE0hPUF9GQUlMVVJF'
    'X1RJTUVPVVQQAxIVChFIT1BfRkFJTFVSRV9PVEhFUhAE');

@$core.Deprecated('Use clientFrameDescriptor instead')
const ClientFrame$json = {
  '1': 'ClientFrame',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {
      '1': 'ping',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.PingRequest',
      '9': 0,
      '10': 'ping'
    },
    {
      '1': 'generate',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.GenerateRequest',
      '9': 0,
      '10': 'generate'
    },
    {
      '1': 'shard_run',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.ShardRunRequest',
      '9': 0,
      '10': 'shardRun'
    },
    {
      '1': 'status',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.StatusRequest',
      '9': 0,
      '10': 'status'
    },
    {
      '1': 'cancel',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.Cancel',
      '9': 0,
      '10': 'cancel'
    },
    {
      '1': 'block_coverage',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.BlockCoverageRequest',
      '9': 0,
      '10': 'blockCoverage'
    },
    {
      '1': 'storage_discovery',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.StorageDiscoveryRequest',
      '9': 0,
      '10': 'storageDiscovery'
    },
    {
      '1': 'network',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.NetworkRequest',
      '9': 0,
      '10': 'network'
    },
    {
      '1': 'connect',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.ConnectRequest',
      '9': 0,
      '10': 'connect'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ClientFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientFrameDescriptor = $convert.base64Decode(
    'CgtDbGllbnRGcmFtZRIOCgJpZBgBIAEoBFICaWQSKwoEcGluZxgKIAEoCzIVLmt3YWFpLnYxLl'
    'BpbmdSZXF1ZXN0SABSBHBpbmcSNwoIZ2VuZXJhdGUYCyABKAsyGS5rd2FhaS52MS5HZW5lcmF0'
    'ZVJlcXVlc3RIAFIIZ2VuZXJhdGUSOAoJc2hhcmRfcnVuGAwgASgLMhkua3dhYWkudjEuU2hhcm'
    'RSdW5SZXF1ZXN0SABSCHNoYXJkUnVuEjEKBnN0YXR1cxgNIAEoCzIXLmt3YWFpLnYxLlN0YXR1'
    'c1JlcXVlc3RIAFIGc3RhdHVzEioKBmNhbmNlbBgOIAEoCzIQLmt3YWFpLnYxLkNhbmNlbEgAUg'
    'ZjYW5jZWwSRwoOYmxvY2tfY292ZXJhZ2UYDyABKAsyHi5rd2FhaS52MS5CbG9ja0NvdmVyYWdl'
    'UmVxdWVzdEgAUg1ibG9ja0NvdmVyYWdlElAKEXN0b3JhZ2VfZGlzY292ZXJ5GBAgASgLMiEua3'
    'dhYWkudjEuU3RvcmFnZURpc2NvdmVyeVJlcXVlc3RIAFIQc3RvcmFnZURpc2NvdmVyeRI0Cgdu'
    'ZXR3b3JrGBEgASgLMhgua3dhYWkudjEuTmV0d29ya1JlcXVlc3RIAFIHbmV0d29yaxI0Cgdjb2'
    '5uZWN0GBIgASgLMhgua3dhYWkudjEuQ29ubmVjdFJlcXVlc3RIAFIHY29ubmVjdEIGCgRib2R5');

@$core.Deprecated('Use serverFrameDescriptor instead')
const ServerFrame$json = {
  '1': 'ServerFrame',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {
      '1': 'pong',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.PingReply',
      '9': 0,
      '10': 'pong'
    },
    {
      '1': 'token',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.ChatToken',
      '9': 0,
      '10': 'token'
    },
    {
      '1': 'done',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.Done',
      '9': 0,
      '10': 'done'
    },
    {
      '1': 'error',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.Error',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'status',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.StatusReply',
      '9': 0,
      '10': 'status'
    },
    {
      '1': 'block_coverage',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.BlockCoverageUpdate',
      '9': 0,
      '10': 'blockCoverage'
    },
    {
      '1': 'storage',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.StorageUpdate',
      '9': 0,
      '10': 'storage'
    },
    {
      '1': 'network',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.NetworkUpdate',
      '9': 0,
      '10': 'network'
    },
    {
      '1': 'connect',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.ConnectReply',
      '9': 0,
      '10': 'connect'
    },
    {
      '1': 'inference_event',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.InferenceEvent',
      '9': 0,
      '10': 'inferenceEvent'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ServerFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverFrameDescriptor = $convert.base64Decode(
    'CgtTZXJ2ZXJGcmFtZRIOCgJpZBgBIAEoBFICaWQSKQoEcG9uZxgKIAEoCzITLmt3YWFpLnYxLl'
    'BpbmdSZXBseUgAUgRwb25nEisKBXRva2VuGAsgASgLMhMua3dhYWkudjEuQ2hhdFRva2VuSABS'
    'BXRva2VuEiQKBGRvbmUYDCABKAsyDi5rd2FhaS52MS5Eb25lSABSBGRvbmUSJwoFZXJyb3IYDS'
    'ABKAsyDy5rd2FhaS52MS5FcnJvckgAUgVlcnJvchIvCgZzdGF0dXMYDiABKAsyFS5rd2FhaS52'
    'MS5TdGF0dXNSZXBseUgAUgZzdGF0dXMSRgoOYmxvY2tfY292ZXJhZ2UYDyABKAsyHS5rd2FhaS'
    '52MS5CbG9ja0NvdmVyYWdlVXBkYXRlSABSDWJsb2NrQ292ZXJhZ2USMwoHc3RvcmFnZRgQIAEo'
    'CzIXLmt3YWFpLnYxLlN0b3JhZ2VVcGRhdGVIAFIHc3RvcmFnZRIzCgduZXR3b3JrGBEgASgLMh'
    'cua3dhYWkudjEuTmV0d29ya1VwZGF0ZUgAUgduZXR3b3JrEjIKB2Nvbm5lY3QYEiABKAsyFi5r'
    'd2FhaS52MS5Db25uZWN0UmVwbHlIAFIHY29ubmVjdBJDCg9pbmZlcmVuY2VfZXZlbnQYEyABKA'
    'syGC5rd2FhaS52MS5JbmZlcmVuY2VFdmVudEgAUg5pbmZlcmVuY2VFdmVudEIGCgRib2R5');

@$core.Deprecated('Use cancelDescriptor instead')
const Cancel$json = {
  '1': 'Cancel',
  '2': [
    {'1': 'target_id', '3': 1, '4': 1, '5': 4, '10': 'targetId'},
  ],
};

/// Descriptor for `Cancel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelDescriptor = $convert
    .base64Decode('CgZDYW5jZWwSGwoJdGFyZ2V0X2lkGAEgASgEUgh0YXJnZXRJZA==');

@$core.Deprecated('Use doneDescriptor instead')
const Done$json = {
  '1': 'Done',
};

/// Descriptor for `Done`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List doneDescriptor = $convert.base64Decode('CgREb25l');

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {
      '1': 'code',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.Error.Code',
      '10': 'code'
    },
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
  '4': [Error_Code$json],
};

@$core.Deprecated('Use errorDescriptor instead')
const Error_Code$json = {
  '1': 'Code',
  '2': [
    {'1': 'UNKNOWN', '2': 0},
    {'1': 'INVALID_ARGUMENT', '2': 1},
    {'1': 'NOT_FOUND', '2': 2},
    {'1': 'UNAVAILABLE', '2': 3},
    {'1': 'CANCELLED', '2': 4},
    {'1': 'INTERNAL', '2': 5},
    {'1': 'UNIMPLEMENTED', '2': 6},
    {'1': 'NO_PEERS_FOR_MODEL', '2': 7},
    {'1': 'INSUFFICIENT_COVERAGE', '2': 8},
    {'1': 'ALL_CANDIDATES_FAILED', '2': 9},
    {'1': 'MODEL_LOAD_FAILED', '2': 10},
  ],
};

/// Descriptor for `Error`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDescriptor = $convert.base64Decode(
    'CgVFcnJvchIoCgRjb2RlGAEgASgOMhQua3dhYWkudjEuRXJyb3IuQ29kZVIEY29kZRIYCgdtZX'
    'NzYWdlGAIgASgJUgdtZXNzYWdlIt4BCgRDb2RlEgsKB1VOS05PV04QABIUChBJTlZBTElEX0FS'
    'R1VNRU5UEAESDQoJTk9UX0ZPVU5EEAISDwoLVU5BVkFJTEFCTEUQAxINCglDQU5DRUxMRUQQBB'
    'IMCghJTlRFUk5BTBAFEhEKDVVOSU1QTEVNRU5URUQQBhIWChJOT19QRUVSU19GT1JfTU9ERUwQ'
    'BxIZChVJTlNVRkZJQ0lFTlRfQ09WRVJBR0UQCBIZChVBTExfQ0FORElEQVRFU19GQUlMRUQQCR'
    'IVChFNT0RFTF9MT0FEX0ZBSUxFRBAK');

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor =
    $convert.base64Decode('CgtQaW5nUmVxdWVzdA==');

@$core.Deprecated('Use pingReplyDescriptor instead')
const PingReply$json = {
  '1': 'PingReply',
  '2': [
    {'1': 'server_time', '3': 1, '4': 1, '5': 9, '10': 'serverTime'},
  ],
};

/// Descriptor for `PingReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingReplyDescriptor = $convert.base64Decode(
    'CglQaW5nUmVwbHkSHwoLc2VydmVyX3RpbWUYASABKAlSCnNlcnZlclRpbWU=');

@$core.Deprecated('Use generateRequestDescriptor instead')
const GenerateRequest$json = {
  '1': 'GenerateRequest',
  '2': [
    {'1': 'role', '3': 1, '4': 1, '5': 9, '10': 'role'},
    {'1': 'content', '3': 2, '4': 1, '5': 9, '10': 'content'},
    {
      '1': 'conversation_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `GenerateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateRequestDescriptor = $convert.base64Decode(
    'Cg9HZW5lcmF0ZVJlcXVlc3QSEgoEcm9sZRgBIAEoCVIEcm9sZRIYCgdjb250ZW50GAIgASgJUg'
    'djb250ZW50EiwKD2NvbnZlcnNhdGlvbl9pZBgDIAEoCUgAUg5jb252ZXJzYXRpb25JZIgBAUIS'
    'ChBfY29udmVyc2F0aW9uX2lk');

@$core.Deprecated('Use shardRunRequestDescriptor instead')
const ShardRunRequest$json = {
  '1': 'ShardRunRequest',
  '2': [
    {'1': 'role', '3': 1, '4': 1, '5': 9, '10': 'role'},
    {'1': 'content', '3': 2, '4': 1, '5': 9, '10': 'content'},
    {'1': 'model', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'model', '17': true},
    {
      '1': 'conversation_id',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'conversationId',
      '17': true
    },
    {'1': 'events', '3': 5, '4': 1, '5': 8, '10': 'events'},
  ],
  '8': [
    {'1': '_model'},
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `ShardRunRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shardRunRequestDescriptor = $convert.base64Decode(
    'Cg9TaGFyZFJ1blJlcXVlc3QSEgoEcm9sZRgBIAEoCVIEcm9sZRIYCgdjb250ZW50GAIgASgJUg'
    'djb250ZW50EhkKBW1vZGVsGAMgASgJSABSBW1vZGVsiAEBEiwKD2NvbnZlcnNhdGlvbl9pZBgE'
    'IAEoCUgBUg5jb252ZXJzYXRpb25JZIgBARIWCgZldmVudHMYBSABKAhSBmV2ZW50c0IICgZfbW'
    '9kZWxCEgoQX2NvbnZlcnNhdGlvbl9pZA==');

@$core.Deprecated('Use statusRequestDescriptor instead')
const StatusRequest$json = {
  '1': 'StatusRequest',
};

/// Descriptor for `StatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusRequestDescriptor =
    $convert.base64Decode('Cg1TdGF0dXNSZXF1ZXN0');

@$core.Deprecated('Use statusReplyDescriptor instead')
const StatusReply$json = {
  '1': 'StatusReply',
  '2': [
    {'1': 'server_time', '3': 1, '4': 1, '5': 9, '10': 'serverTime'},
    {'1': 'model', '3': 2, '4': 1, '5': 9, '10': 'model'},
    {'1': 'shard_ready', '3': 3, '4': 1, '5': 8, '10': 'shardReady'},
    {'1': 'peer_count', '3': 4, '4': 1, '5': 13, '10': 'peerCount'},
    {'1': 'uptime_secs', '3': 5, '4': 1, '5': 4, '10': 'uptimeSecs'},
    {'1': 'version', '3': 6, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `StatusReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List statusReplyDescriptor = $convert.base64Decode(
    'CgtTdGF0dXNSZXBseRIfCgtzZXJ2ZXJfdGltZRgBIAEoCVIKc2VydmVyVGltZRIUCgVtb2RlbB'
    'gCIAEoCVIFbW9kZWwSHwoLc2hhcmRfcmVhZHkYAyABKAhSCnNoYXJkUmVhZHkSHQoKcGVlcl9j'
    'b3VudBgEIAEoDVIJcGVlckNvdW50Eh8KC3VwdGltZV9zZWNzGAUgASgEUgp1cHRpbWVTZWNzEh'
    'gKB3ZlcnNpb24YBiABKAlSB3ZlcnNpb24=');

@$core.Deprecated('Use blockCoverageRequestDescriptor instead')
const BlockCoverageRequest$json = {
  '1': 'BlockCoverageRequest',
  '2': [
    {
      '1': 'dht_prefix',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'dhtPrefix',
      '17': true
    },
    {
      '1': 'total_blocks',
      '3': 2,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'totalBlocks',
      '17': true
    },
    {'1': 'subscribe', '3': 3, '4': 1, '5': 8, '10': 'subscribe'},
    {'1': 'interval_secs', '3': 4, '4': 1, '5': 13, '10': 'intervalSecs'},
  ],
  '8': [
    {'1': '_dht_prefix'},
    {'1': '_total_blocks'},
  ],
};

/// Descriptor for `BlockCoverageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockCoverageRequestDescriptor = $convert.base64Decode(
    'ChRCbG9ja0NvdmVyYWdlUmVxdWVzdBIiCgpkaHRfcHJlZml4GAEgASgJSABSCWRodFByZWZpeI'
    'gBARImCgx0b3RhbF9ibG9ja3MYAiABKA1IAVILdG90YWxCbG9ja3OIAQESHAoJc3Vic2NyaWJl'
    'GAMgASgIUglzdWJzY3JpYmUSIwoNaW50ZXJ2YWxfc2VjcxgEIAEoDVIMaW50ZXJ2YWxTZWNzQg'
    '0KC19kaHRfcHJlZml4Qg8KDV90b3RhbF9ibG9ja3M=');

@$core.Deprecated('Use blockPeerDescriptor instead')
const BlockPeer$json = {
  '1': 'BlockPeer',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'start_block', '3': 2, '4': 1, '5': 13, '10': 'startBlock'},
    {'1': 'end_block', '3': 3, '4': 1, '5': 13, '10': 'endBlock'},
    {'1': 'public_name', '3': 4, '4': 1, '5': 9, '10': 'publicName'},
    {'1': 'throughput', '3': 5, '4': 1, '5': 1, '10': 'throughput'},
    {'1': 'trust_score', '3': 6, '4': 1, '5': 1, '10': 'trustScore'},
    {'1': 'trust_tier', '3': 7, '4': 1, '5': 9, '10': 'trustTier'},
  ],
};

/// Descriptor for `BlockPeer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockPeerDescriptor = $convert.base64Decode(
    'CglCbG9ja1BlZXISFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEh8KC3N0YXJ0X2Jsb2NrGAIgAS'
    'gNUgpzdGFydEJsb2NrEhsKCWVuZF9ibG9jaxgDIAEoDVIIZW5kQmxvY2sSHwoLcHVibGljX25h'
    'bWUYBCABKAlSCnB1YmxpY05hbWUSHgoKdGhyb3VnaHB1dBgFIAEoAVIKdGhyb3VnaHB1dBIfCg'
    't0cnVzdF9zY29yZRgGIAEoAVIKdHJ1c3RTY29yZRIdCgp0cnVzdF90aWVyGAcgASgJUgl0cnVz'
    'dFRpZXI=');

@$core.Deprecated('Use blockCoverageUpdateDescriptor instead')
const BlockCoverageUpdate$json = {
  '1': 'BlockCoverageUpdate',
  '2': [
    {'1': 'server_time', '3': 1, '4': 1, '5': 9, '10': 'serverTime'},
    {'1': 'model', '3': 2, '4': 1, '5': 9, '10': 'model'},
    {'1': 'dht_prefix', '3': 3, '4': 1, '5': 9, '10': 'dhtPrefix'},
    {'1': 'total_blocks', '3': 4, '4': 1, '5': 13, '10': 'totalBlocks'},
    {'1': 'covered_blocks', '3': 5, '4': 1, '5': 13, '10': 'coveredBlocks'},
    {'1': 'full_coverage', '3': 6, '4': 1, '5': 8, '10': 'fullCoverage'},
    {
      '1': 'peers',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.kwaai.v1.BlockPeer',
      '10': 'peers'
    },
  ],
};

/// Descriptor for `BlockCoverageUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockCoverageUpdateDescriptor = $convert.base64Decode(
    'ChNCbG9ja0NvdmVyYWdlVXBkYXRlEh8KC3NlcnZlcl90aW1lGAEgASgJUgpzZXJ2ZXJUaW1lEh'
    'QKBW1vZGVsGAIgASgJUgVtb2RlbBIdCgpkaHRfcHJlZml4GAMgASgJUglkaHRQcmVmaXgSIQoM'
    'dG90YWxfYmxvY2tzGAQgASgNUgt0b3RhbEJsb2NrcxIlCg5jb3ZlcmVkX2Jsb2NrcxgFIAEoDV'
    'INY292ZXJlZEJsb2NrcxIjCg1mdWxsX2NvdmVyYWdlGAYgASgIUgxmdWxsQ292ZXJhZ2USKQoF'
    'cGVlcnMYByADKAsyEy5rd2FhaS52MS5CbG9ja1BlZXJSBXBlZXJz');

@$core.Deprecated('Use storageDiscoveryRequestDescriptor instead')
const StorageDiscoveryRequest$json = {
  '1': 'StorageDiscoveryRequest',
  '2': [
    {'1': 'subscribe', '3': 1, '4': 1, '5': 8, '10': 'subscribe'},
    {'1': 'interval_secs', '3': 2, '4': 1, '5': 13, '10': 'intervalSecs'},
    {'1': 'skip_probes', '3': 3, '4': 1, '5': 8, '10': 'skipProbes'},
  ],
};

/// Descriptor for `StorageDiscoveryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storageDiscoveryRequestDescriptor = $convert.base64Decode(
    'ChdTdG9yYWdlRGlzY292ZXJ5UmVxdWVzdBIcCglzdWJzY3JpYmUYASABKAhSCXN1YnNjcmliZR'
    'IjCg1pbnRlcnZhbF9zZWNzGAIgASgNUgxpbnRlcnZhbFNlY3MSHwoLc2tpcF9wcm9iZXMYAyAB'
    'KAhSCnNraXBQcm9iZXM=');

@$core.Deprecated('Use storagePeerDescriptor instead')
const StoragePeer$json = {
  '1': 'StoragePeer',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'public_name', '3': 2, '4': 1, '5': 9, '10': 'publicName'},
    {'1': 'mode', '3': 3, '4': 1, '5': 9, '10': 'mode'},
    {'1': 'vpk_version', '3': 4, '4': 1, '5': 9, '10': 'vpkVersion'},
    {'1': 'capacity_gb', '3': 5, '4': 1, '5': 1, '10': 'capacityGb'},
    {'1': 'tenant_count', '3': 6, '4': 1, '5': 13, '10': 'tenantCount'},
    {
      '1': 'reachability',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.StorageReachability',
      '10': 'reachability'
    },
    {'1': 'capacity_gb_free', '3': 8, '4': 1, '5': 1, '10': 'capacityGbFree'},
    {'1': 'trust_score', '3': 9, '4': 1, '5': 1, '10': 'trustScore'},
    {'1': 'trust_tier', '3': 10, '4': 1, '5': 9, '10': 'trustTier'},
  ],
};

/// Descriptor for `StoragePeer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storagePeerDescriptor = $convert.base64Decode(
    'CgtTdG9yYWdlUGVlchIXCgdwZWVyX2lkGAEgASgJUgZwZWVySWQSHwoLcHVibGljX25hbWUYAi'
    'ABKAlSCnB1YmxpY05hbWUSEgoEbW9kZRgDIAEoCVIEbW9kZRIfCgt2cGtfdmVyc2lvbhgEIAEo'
    'CVIKdnBrVmVyc2lvbhIfCgtjYXBhY2l0eV9nYhgFIAEoAVIKY2FwYWNpdHlHYhIhCgx0ZW5hbn'
    'RfY291bnQYBiABKA1SC3RlbmFudENvdW50EkEKDHJlYWNoYWJpbGl0eRgHIAEoDjIdLmt3YWFp'
    'LnYxLlN0b3JhZ2VSZWFjaGFiaWxpdHlSDHJlYWNoYWJpbGl0eRIoChBjYXBhY2l0eV9nYl9mcm'
    'VlGAggASgBUg5jYXBhY2l0eUdiRnJlZRIfCgt0cnVzdF9zY29yZRgJIAEoAVIKdHJ1c3RTY29y'
    'ZRIdCgp0cnVzdF90aWVyGAogASgJUgl0cnVzdFRpZXI=');

@$core.Deprecated('Use storageUpdateDescriptor instead')
const StorageUpdate$json = {
  '1': 'StorageUpdate',
  '2': [
    {'1': 'server_time', '3': 1, '4': 1, '5': 9, '10': 'serverTime'},
    {'1': 'probes_pending', '3': 2, '4': 1, '5': 8, '10': 'probesPending'},
    {
      '1': 'peers',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.kwaai.v1.StoragePeer',
      '10': 'peers'
    },
  ],
};

/// Descriptor for `StorageUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storageUpdateDescriptor = $convert.base64Decode(
    'Cg1TdG9yYWdlVXBkYXRlEh8KC3NlcnZlcl90aW1lGAEgASgJUgpzZXJ2ZXJUaW1lEiUKDnByb2'
    'Jlc19wZW5kaW5nGAIgASgIUg1wcm9iZXNQZW5kaW5nEisKBXBlZXJzGAMgAygLMhUua3dhYWku'
    'djEuU3RvcmFnZVBlZXJSBXBlZXJz');

@$core.Deprecated('Use networkRequestDescriptor instead')
const NetworkRequest$json = {
  '1': 'NetworkRequest',
  '2': [
    {'1': 'subscribe', '3': 1, '4': 1, '5': 8, '10': 'subscribe'},
    {'1': 'interval_secs', '3': 2, '4': 1, '5': 13, '10': 'intervalSecs'},
  ],
};

/// Descriptor for `NetworkRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkRequestDescriptor = $convert.base64Decode(
    'Cg5OZXR3b3JrUmVxdWVzdBIcCglzdWJzY3JpYmUYASABKAhSCXN1YnNjcmliZRIjCg1pbnRlcn'
    'ZhbF9zZWNzGAIgASgNUgxpbnRlcnZhbFNlY3M=');

@$core.Deprecated('Use connectedPeerDescriptor instead')
const ConnectedPeer$json = {
  '1': 'ConnectedPeer',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'addr', '3': 2, '4': 1, '5': 9, '10': 'addr'},
    {
      '1': 'kind',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.PeerConnKind',
      '10': 'kind'
    },
    {'1': 'direction', '3': 4, '4': 1, '5': 9, '10': 'direction'},
    {'1': 'is_bootstrap', '3': 5, '4': 1, '5': 8, '10': 'isBootstrap'},
    {'1': 'is_trusted_relay', '3': 6, '4': 1, '5': 8, '10': 'isTrustedRelay'},
    {'1': 'protocols', '3': 7, '4': 3, '5': 9, '10': 'protocols'},
    {'1': 'rtt_ms', '3': 8, '4': 1, '5': 13, '10': 'rttMs'},
    {'1': 'agent_version', '3': 9, '4': 1, '5': 9, '10': 'agentVersion'},
    {'1': 'via', '3': 11, '4': 1, '5': 9, '10': 'via'},
    {'1': 'dcutr', '3': 10, '4': 1, '5': 8, '10': 'dcutr'},
    {
      '1': 'dht_role',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.DhtRole',
      '10': 'dhtRole'
    },
  ],
};

/// Descriptor for `ConnectedPeer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectedPeerDescriptor = $convert.base64Decode(
    'Cg1Db25uZWN0ZWRQZWVyEhcKB3BlZXJfaWQYASABKAlSBnBlZXJJZBISCgRhZGRyGAIgASgJUg'
    'RhZGRyEioKBGtpbmQYAyABKA4yFi5rd2FhaS52MS5QZWVyQ29ubktpbmRSBGtpbmQSHAoJZGly'
    'ZWN0aW9uGAQgASgJUglkaXJlY3Rpb24SIQoMaXNfYm9vdHN0cmFwGAUgASgIUgtpc0Jvb3RzdH'
    'JhcBIoChBpc190cnVzdGVkX3JlbGF5GAYgASgIUg5pc1RydXN0ZWRSZWxheRIcCglwcm90b2Nv'
    'bHMYByADKAlSCXByb3RvY29scxIVCgZydHRfbXMYCCABKA1SBXJ0dE1zEiMKDWFnZW50X3Zlcn'
    'Npb24YCSABKAlSDGFnZW50VmVyc2lvbhIQCgN2aWEYCyABKAlSA3ZpYRIUCgVkY3V0chgKIAEo'
    'CFIFZGN1dHISLAoIZGh0X3JvbGUYDCABKA4yES5rd2FhaS52MS5EaHRSb2xlUgdkaHRSb2xl');

@$core.Deprecated('Use routingPeerDescriptor instead')
const RoutingPeer$json = {
  '1': 'RoutingPeer',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'connected', '3': 2, '4': 1, '5': 8, '10': 'connected'},
    {'1': 'is_bootstrap', '3': 3, '4': 1, '5': 8, '10': 'isBootstrap'},
    {'1': 'addrs', '3': 4, '4': 3, '5': 9, '10': 'addrs'},
  ],
};

/// Descriptor for `RoutingPeer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List routingPeerDescriptor = $convert.base64Decode(
    'CgtSb3V0aW5nUGVlchIXCgdwZWVyX2lkGAEgASgJUgZwZWVySWQSHAoJY29ubmVjdGVkGAIgAS'
    'gIUgljb25uZWN0ZWQSIQoMaXNfYm9vdHN0cmFwGAMgASgIUgtpc0Jvb3RzdHJhcBIUCgVhZGRy'
    'cxgEIAMoCVIFYWRkcnM=');

@$core.Deprecated('Use selfStatusDescriptor instead')
const SelfStatus$json = {
  '1': 'SelfStatus',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'reachability', '3': 2, '4': 1, '5': 9, '10': 'reachability'},
    {
      '1': 'reachability_source',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'reachabilitySource'
    },
    {'1': 'using_relay', '3': 4, '4': 1, '5': 8, '10': 'usingRelay'},
    {'1': 'announceable', '3': 5, '4': 1, '5': 8, '10': 'announceable'},
    {'1': 'listen_addrs', '3': 6, '4': 3, '5': 9, '10': 'listenAddrs'},
    {'1': 'observed_addrs', '3': 7, '4': 3, '5': 9, '10': 'observedAddrs'},
    {'1': 'relay_addrs', '3': 8, '4': 3, '5': 9, '10': 'relayAddrs'},
    {'1': 'local_protocols', '3': 9, '4': 3, '5': 9, '10': 'localProtocols'},
  ],
};

/// Descriptor for `SelfStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List selfStatusDescriptor = $convert.base64Decode(
    'CgpTZWxmU3RhdHVzEhcKB3BlZXJfaWQYASABKAlSBnBlZXJJZBIiCgxyZWFjaGFiaWxpdHkYAi'
    'ABKAlSDHJlYWNoYWJpbGl0eRIvChNyZWFjaGFiaWxpdHlfc291cmNlGAMgASgJUhJyZWFjaGFi'
    'aWxpdHlTb3VyY2USHwoLdXNpbmdfcmVsYXkYBCABKAhSCnVzaW5nUmVsYXkSIgoMYW5ub3VuY2'
    'VhYmxlGAUgASgIUgxhbm5vdW5jZWFibGUSIQoMbGlzdGVuX2FkZHJzGAYgAygJUgtsaXN0ZW5B'
    'ZGRycxIlCg5vYnNlcnZlZF9hZGRycxgHIAMoCVINb2JzZXJ2ZWRBZGRycxIfCgtyZWxheV9hZG'
    'RycxgIIAMoCVIKcmVsYXlBZGRycxInCg9sb2NhbF9wcm90b2NvbHMYCSADKAlSDmxvY2FsUHJv'
    'dG9jb2xz');

@$core.Deprecated('Use networkUpdateDescriptor instead')
const NetworkUpdate$json = {
  '1': 'NetworkUpdate',
  '2': [
    {'1': 'server_time', '3': 1, '4': 1, '5': 9, '10': 'serverTime'},
    {
      '1': 'reason',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.UpdateReason',
      '10': 'reason'
    },
    {
      '1': 'self_status',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.kwaai.v1.SelfStatus',
      '10': 'selfStatus'
    },
    {
      '1': 'connected',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.kwaai.v1.ConnectedPeer',
      '10': 'connected'
    },
    {
      '1': 'routing',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.kwaai.v1.RoutingPeer',
      '10': 'routing'
    },
  ],
};

/// Descriptor for `NetworkUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List networkUpdateDescriptor = $convert.base64Decode(
    'Cg1OZXR3b3JrVXBkYXRlEh8KC3NlcnZlcl90aW1lGAEgASgJUgpzZXJ2ZXJUaW1lEi4KBnJlYX'
    'NvbhgCIAEoDjIWLmt3YWFpLnYxLlVwZGF0ZVJlYXNvblIGcmVhc29uEjUKC3NlbGZfc3RhdHVz'
    'GAMgASgLMhQua3dhYWkudjEuU2VsZlN0YXR1c1IKc2VsZlN0YXR1cxI1Cgljb25uZWN0ZWQYBC'
    'ADKAsyFy5rd2FhaS52MS5Db25uZWN0ZWRQZWVyUgljb25uZWN0ZWQSLwoHcm91dGluZxgFIAMo'
    'CzIVLmt3YWFpLnYxLlJvdXRpbmdQZWVyUgdyb3V0aW5n');

@$core.Deprecated('Use connectRequestDescriptor instead')
const ConnectRequest$json = {
  '1': 'ConnectRequest',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
  ],
};

/// Descriptor for `ConnectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectRequestDescriptor = $convert
    .base64Decode('Cg5Db25uZWN0UmVxdWVzdBIXCgdwZWVyX2lkGAEgASgJUgZwZWVySWQ=');

@$core.Deprecated('Use connectReplyDescriptor instead')
const ConnectReply$json = {
  '1': 'ConnectReply',
  '2': [
    {'1': 'connected', '3': 1, '4': 1, '5': 8, '10': 'connected'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ConnectReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectReplyDescriptor = $convert.base64Decode(
    'CgxDb25uZWN0UmVwbHkSHAoJY29ubmVjdGVkGAEgASgIUgljb25uZWN0ZWQSFAoFZXJyb3IYAi'
    'ABKAlSBWVycm9y');

@$core.Deprecated('Use inferenceHopDescriptor instead')
const InferenceHop$json = {
  '1': 'InferenceHop',
  '2': [
    {'1': 'peer_id', '3': 1, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'peer_name', '3': 2, '4': 1, '5': 9, '10': 'peerName'},
    {'1': 'block_start', '3': 3, '4': 1, '5': 13, '10': 'blockStart'},
    {'1': 'block_end', '3': 4, '4': 1, '5': 13, '10': 'blockEnd'},
    {'1': 'is_self', '3': 5, '4': 1, '5': 8, '10': 'isSelf'},
    {
      '1': 'trust_score',
      '3': 6,
      '4': 1,
      '5': 1,
      '9': 0,
      '10': 'trustScore',
      '17': true
    },
    {'1': 'throughput', '3': 7, '4': 1, '5': 1, '10': 'throughput'},
  ],
  '8': [
    {'1': '_trust_score'},
  ],
};

/// Descriptor for `InferenceHop`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inferenceHopDescriptor = $convert.base64Decode(
    'CgxJbmZlcmVuY2VIb3ASFwoHcGVlcl9pZBgBIAEoCVIGcGVlcklkEhsKCXBlZXJfbmFtZRgCIA'
    'EoCVIIcGVlck5hbWUSHwoLYmxvY2tfc3RhcnQYAyABKA1SCmJsb2NrU3RhcnQSGwoJYmxvY2tf'
    'ZW5kGAQgASgNUghibG9ja0VuZBIXCgdpc19zZWxmGAUgASgIUgZpc1NlbGYSJAoLdHJ1c3Rfc2'
    'NvcmUYBiABKAFIAFIKdHJ1c3RTY29yZYgBARIeCgp0aHJvdWdocHV0GAcgASgBUgp0aHJvdWdo'
    'cHV0Qg4KDF90cnVzdF9zY29yZQ==');

@$core.Deprecated('Use inferenceEventDescriptor instead')
const InferenceEvent$json = {
  '1': 'InferenceEvent',
  '2': [
    {'1': 'elapsed_ms', '3': 1, '4': 1, '5': 4, '10': 'elapsedMs'},
    {
      '1': 'phase',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.InferencePhase',
      '10': 'phase'
    },
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {'1': 'peer_id', '3': 10, '4': 1, '5': 9, '10': 'peerId'},
    {'1': 'peer_name', '3': 11, '4': 1, '5': 9, '10': 'peerName'},
    {'1': 'is_self', '3': 12, '4': 1, '5': 8, '10': 'isSelf'},
    {
      '1': 'block_start',
      '3': 20,
      '4': 1,
      '5': 13,
      '9': 0,
      '10': 'blockStart',
      '17': true
    },
    {
      '1': 'block_end',
      '3': 21,
      '4': 1,
      '5': 13,
      '9': 1,
      '10': 'blockEnd',
      '17': true
    },
    {
      '1': 'total_blocks',
      '3': 22,
      '4': 1,
      '5': 13,
      '9': 2,
      '10': 'totalBlocks',
      '17': true
    },
    {
      '1': 'covered_blocks',
      '3': 23,
      '4': 1,
      '5': 13,
      '9': 3,
      '10': 'coveredBlocks',
      '17': true
    },
    {
      '1': 'duration_ms',
      '3': 30,
      '4': 1,
      '5': 1,
      '9': 4,
      '10': 'durationMs',
      '17': true
    },
    {
      '1': 'token_index',
      '3': 40,
      '4': 1,
      '5': 13,
      '9': 5,
      '10': 'tokenIndex',
      '17': true
    },
    {'1': 'is_prefill', '3': 41, '4': 1, '5': 8, '10': 'isPrefill'},
    {
      '1': 'candidate_index',
      '3': 42,
      '4': 1,
      '5': 13,
      '9': 6,
      '10': 'candidateIndex',
      '17': true
    },
    {
      '1': 'attempt',
      '3': 43,
      '4': 1,
      '5': 13,
      '9': 7,
      '10': 'attempt',
      '17': true
    },
    {'1': 'ok', '3': 44, '4': 1, '5': 8, '10': 'ok'},
    {'1': 'session_id', '3': 45, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'seq_pos',
      '3': 46,
      '4': 1,
      '5': 13,
      '9': 8,
      '10': 'seqPos',
      '17': true
    },
    {
      '1': 'failure',
      '3': 50,
      '4': 1,
      '5': 14,
      '6': '.kwaai.v1.HopFailure',
      '10': 'failure'
    },
    {'1': 'model', '3': 60, '4': 1, '5': 9, '10': 'model'},
    {'1': 'dht_prefix', '3': 61, '4': 1, '5': 9, '10': 'dhtPrefix'},
    {
      '1': 'peer_count',
      '3': 62,
      '4': 1,
      '5': 13,
      '9': 9,
      '10': 'peerCount',
      '17': true
    },
    {'1': 'circuit_id', '3': 63, '4': 1, '5': 9, '10': 'circuitId'},
    {
      '1': 'hops',
      '3': 70,
      '4': 3,
      '5': 11,
      '6': '.kwaai.v1.InferenceHop',
      '10': 'hops'
    },
  ],
  '8': [
    {'1': '_block_start'},
    {'1': '_block_end'},
    {'1': '_total_blocks'},
    {'1': '_covered_blocks'},
    {'1': '_duration_ms'},
    {'1': '_token_index'},
    {'1': '_candidate_index'},
    {'1': '_attempt'},
    {'1': '_seq_pos'},
    {'1': '_peer_count'},
  ],
};

/// Descriptor for `InferenceEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inferenceEventDescriptor = $convert.base64Decode(
    'Cg5JbmZlcmVuY2VFdmVudBIdCgplbGFwc2VkX21zGAEgASgEUgllbGFwc2VkTXMSLgoFcGhhc2'
    'UYAiABKA4yGC5rd2FhaS52MS5JbmZlcmVuY2VQaGFzZVIFcGhhc2USGAoHbWVzc2FnZRgDIAEo'
    'CVIHbWVzc2FnZRIXCgdwZWVyX2lkGAogASgJUgZwZWVySWQSGwoJcGVlcl9uYW1lGAsgASgJUg'
    'hwZWVyTmFtZRIXCgdpc19zZWxmGAwgASgIUgZpc1NlbGYSJAoLYmxvY2tfc3RhcnQYFCABKA1I'
    'AFIKYmxvY2tTdGFydIgBARIgCglibG9ja19lbmQYFSABKA1IAVIIYmxvY2tFbmSIAQESJgoMdG'
    '90YWxfYmxvY2tzGBYgASgNSAJSC3RvdGFsQmxvY2tziAEBEioKDmNvdmVyZWRfYmxvY2tzGBcg'
    'ASgNSANSDWNvdmVyZWRCbG9ja3OIAQESJAoLZHVyYXRpb25fbXMYHiABKAFIBFIKZHVyYXRpb2'
    '5Nc4gBARIkCgt0b2tlbl9pbmRleBgoIAEoDUgFUgp0b2tlbkluZGV4iAEBEh0KCmlzX3ByZWZp'
    'bGwYKSABKAhSCWlzUHJlZmlsbBIsCg9jYW5kaWRhdGVfaW5kZXgYKiABKA1IBlIOY2FuZGlkYX'
    'RlSW5kZXiIAQESHQoHYXR0ZW1wdBgrIAEoDUgHUgdhdHRlbXB0iAEBEg4KAm9rGCwgASgIUgJv'
    'axIdCgpzZXNzaW9uX2lkGC0gASgJUglzZXNzaW9uSWQSHAoHc2VxX3BvcxguIAEoDUgIUgZzZX'
    'FQb3OIAQESLgoHZmFpbHVyZRgyIAEoDjIULmt3YWFpLnYxLkhvcEZhaWx1cmVSB2ZhaWx1cmUS'
    'FAoFbW9kZWwYPCABKAlSBW1vZGVsEh0KCmRodF9wcmVmaXgYPSABKAlSCWRodFByZWZpeBIiCg'
    'pwZWVyX2NvdW50GD4gASgNSAlSCXBlZXJDb3VudIgBARIdCgpjaXJjdWl0X2lkGD8gASgJUglj'
    'aXJjdWl0SWQSKgoEaG9wcxhGIAMoCzIWLmt3YWFpLnYxLkluZmVyZW5jZUhvcFIEaG9wc0IOCg'
    'xfYmxvY2tfc3RhcnRCDAoKX2Jsb2NrX2VuZEIPCg1fdG90YWxfYmxvY2tzQhEKD19jb3ZlcmVk'
    'X2Jsb2Nrc0IOCgxfZHVyYXRpb25fbXNCDgoMX3Rva2VuX2luZGV4QhIKEF9jYW5kaWRhdGVfaW'
    '5kZXhCCgoIX2F0dGVtcHRCCgoIX3NlcV9wb3NCDQoLX3BlZXJfY291bnQ=');

@$core.Deprecated('Use chatMessageDescriptor instead')
const ChatMessage$json = {
  '1': 'ChatMessage',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
    {'1': 'role', '3': 2, '4': 1, '5': 9, '10': 'role'},
    {
      '1': 'conversation_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'conversationId',
      '17': true
    },
  ],
  '8': [
    {'1': '_conversation_id'},
  ],
};

/// Descriptor for `ChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode(
    'CgtDaGF0TWVzc2FnZRIYCgdjb250ZW50GAEgASgJUgdjb250ZW50EhIKBHJvbGUYAiABKAlSBH'
    'JvbGUSLAoPY29udmVyc2F0aW9uX2lkGAMgASgJSABSDmNvbnZlcnNhdGlvbklkiAEBQhIKEF9j'
    'b252ZXJzYXRpb25faWQ=');

@$core.Deprecated('Use chatTokenDescriptor instead')
const ChatToken$json = {
  '1': 'ChatToken',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'done', '3': 2, '4': 1, '5': 8, '10': 'done'},
    {
      '1': 'finish_reason',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'finishReason',
      '17': true
    },
  ],
  '8': [
    {'1': '_finish_reason'},
  ],
};

/// Descriptor for `ChatToken`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatTokenDescriptor = $convert.base64Decode(
    'CglDaGF0VG9rZW4SEgoEdGV4dBgBIAEoCVIEdGV4dBISCgRkb25lGAIgASgIUgRkb25lEigKDW'
    'ZpbmlzaF9yZWFzb24YAyABKAlIAFIMZmluaXNoUmVhc29uiAEBQhAKDl9maW5pc2hfcmVhc29u');
