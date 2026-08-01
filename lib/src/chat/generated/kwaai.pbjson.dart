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
    'dhYWkudjEuU3RvcmFnZURpc2NvdmVyeVJlcXVlc3RIAFIQc3RvcmFnZURpc2NvdmVyeUIGCgRi'
    'b2R5');

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
    'CzIXLmt3YWFpLnYxLlN0b3JhZ2VVcGRhdGVIAFIHc3RvcmFnZUIGCgRib2R5');

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
    'IAEoCUgBUg5jb252ZXJzYXRpb25JZIgBAUIICgZfbW9kZWxCEgoQX2NvbnZlcnNhdGlvbl9pZA'
    '==');

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
