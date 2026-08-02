// Probe: read one NetworkUpdate off the live daemon and print each peer's
// dht_role, to confirm the field is populated end to end.
import 'package:grpc/grpc.dart';
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbgrpc.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;

Future<void> main() async {
  final channel = ClientChannel(
    '127.0.0.1',
    port: 8099,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );
  final stub = pb.KwaaiNetClient(channel);

  final req = pb.ClientFrame()
    ..network = (pb.NetworkRequest()
      ..subscribe = false
      ..intervalSecs = 5);

  try {
    await for (final frame in stub.session(Stream.value(req))) {
      if (!frame.hasNetwork()) continue;
      final u = frame.network;
      print('reason=${u.reason}  connected=${u.connected.length}');
      for (final p in u.connected) {
        final id = p.peerId.length > 12
            ? '${p.peerId.substring(0, 10)}…${p.peerId.substring(p.peerId.length - 8)}'
            : p.peerId;
        final kad = p.protocols.any((s) => s.contains('/kad/'));
        print('  $id  role=${p.dhtRole.name.padRight(16)} '
            'kad=$kad  agent=${p.agentVersion}');
      }
      final clients = u.connected
          .where((p) => p.dhtRole == pbenum.DhtRole.DHT_ROLE_CLIENT)
          .length;
      print('CLIENT-MODE PEERS: $clients');
      break;
    }
  } catch (e) {
    print('ERROR: $e');
  }
  await channel.shutdown();
}
