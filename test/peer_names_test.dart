import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbgrpc.dart' as pbgrpc;
import 'package:kwaainet_gui/src/chat/session_client.dart';
import 'package:kwaainet_gui/src/daemon/peers_state.dart';

/// The Peers table's NAME column is derived from the block-coverage and
/// storage-registry feeds; these pin how the two are combined.
void main() {
  group('names from each feed', () {
    test('empty announced names are dropped', () {
      final coverage = pb.BlockCoverageUpdate(
        peers: [
          pb.BlockPeer(peerId: 'A', publicName: 'alpha'),
          pb.BlockPeer(peerId: 'B'),
        ],
      );
      final storage = pb.StorageUpdate(
        peers: [
          pb.StoragePeer(peerId: 'C', publicName: 'gamma'),
          pb.StoragePeer(peerId: 'D'),
        ],
      );
      expect(namesFromCoverage(coverage), {'A': 'alpha'});
      expect(namesFromStorage(storage), {'C': 'gamma'});
    });

    test('a block record names a peer present in both', () {
      expect(
        mergePeerNames({'A': 'from-blocks'}, {'A': 'from-vpk', 'C': 'gamma'}),
        {'A': 'from-blocks', 'C': 'gamma'},
      );
    });
  });

  group('mergePeerNameStreams', () {
    test('one source updating keeps the other source\'s names', () async {
      final blocks = StreamController<Map<String, String>>();
      final storage = StreamController<Map<String, String>>();
      final out = <Map<String, String>>[];
      final sub = mergePeerNameStreams(
        blocks.stream,
        storage.stream,
      ).listen(out.add);

      blocks.add({'A': 'alpha'});
      await pumpEventQueue();
      storage.add({'C': 'gamma'});
      await pumpEventQueue();
      storage.add({'C': 'gamma2'});
      await pumpEventQueue();

      expect(out, [
        {'A': 'alpha'},
        {'A': 'alpha', 'C': 'gamma'},
        {'A': 'alpha', 'C': 'gamma2'},
      ]);
      await sub.cancel();
    });

    test('a failing source does not blank the other', () async {
      final blocks = StreamController<Map<String, String>>();
      final storage = StreamController<Map<String, String>>();
      final out = <Map<String, String>>[];
      final sub = mergePeerNameStreams(
        blocks.stream,
        storage.stream,
      ).listen(out.add);

      blocks.add({'A': 'alpha'});
      storage.addError(StateError('UNIMPLEMENTED'));
      await storage.close();
      blocks.add({'A': 'alpha', 'B': 'beta'});
      await pumpEventQueue();

      expect(out.last, {'A': 'alpha', 'B': 'beta'});
      await sub.cancel();
    });

    test('cancelling the result cancels both sources', () async {
      var cancelled = 0;
      final blocks = StreamController<Map<String, String>>(
        onCancel: () => cancelled++,
      );
      final storage = StreamController<Map<String, String>>(
        onCancel: () => cancelled++,
      );
      final sub = mergePeerNameStreams(
        blocks.stream,
        storage.stream,
      ).listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      expect(cancelled, 2);
    });
  });

  group('storageDiscoverySubscribe', () {
    late Server server;
    late _CapturingService service;
    late ClientChannel channel;

    setUp(() async {
      service = _CapturingService();
      server = Server.create(services: [service]);
      await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
      channel = ClientChannel(
        InternetAddress.loopbackIPv4,
        port: server.port!,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
    });

    tearDown(() async {
      await channel.shutdown();
      await server.shutdown();
    });

    Future<pb.StorageDiscoveryRequest> sent({bool? skipProbes}) async {
      final session = SessionClient(pbgrpc.KwaaiNetClient(channel));
      final op = skipProbes == null
          ? session.storageDiscoverySubscribe(intervalSecs: 60)
          : session.storageDiscoverySubscribe(
              intervalSecs: 60,
              skipProbes: skipProbes,
            );
      final sub = op.updates.listen((_) {}, onError: (Object _) {});
      final req = await service.request.future.timeout(
        const Duration(seconds: 5),
      );
      await sub.cancel();
      await session.close();
      return req;
    }

    test('skipProbes reaches the request', () async {
      final req = await sent(skipProbes: true);
      expect(req.skipProbes, isTrue);
      expect(req.intervalSecs, 60);
      expect(req.subscribe, isTrue);
    });

    test('probes stay on by default', () async {
      expect((await sent()).skipProbes, isFalse);
    });
  });
}

/// Records the first storage-discovery request a Session carries.
class _CapturingService extends pbgrpc.KwaaiNetServiceBase {
  final request = Completer<pb.StorageDiscoveryRequest>();

  @override
  Stream<pb.ServerFrame> session(
    ServiceCall call,
    Stream<pb.ClientFrame> frames,
  ) async* {
    await for (final f in frames) {
      if (f.hasStorageDiscovery() && !request.isCompleted) {
        request.complete(f.storageDiscovery);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
