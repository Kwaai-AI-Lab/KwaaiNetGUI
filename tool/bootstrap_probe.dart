// Throwaway probe: ask the running daemon for Status + one NetworkUpdate
// over the Session RPC on the unix socket, print the bootstrap fields.
// Run: dart run tool/bootstrap_probe.dart
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbgrpc.dart';

Future<void> main(List<String> args) async {
  final channel = ClientChannel(
    InternetAddress(
      args.isNotEmpty
          ? args.first
          : '${Platform.environment['HOME']}/.kwaainet/run/kwaai.sock',
      type: InternetAddressType.unix,
    ),
    port: 0,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );
  final stub = KwaaiNetClient(channel);
  final reqs = StreamController<ClientFrame>();
  final resp = stub.session(reqs.stream);
  reqs.add(ClientFrame(id: Int64(1), status: StatusRequest()));
  reqs.add(
    ClientFrame(id: Int64(2), network: NetworkRequest(subscribe: false)),
  );

  var pending = 2;
  await for (final frame in resp.timeout(const Duration(seconds: 10))) {
    if (frame.hasStatus()) {
      final s = frame.status;
      print(
        'STATUS: version=${s.version} uptime=${s.uptimeSecs}s '
        'peer_count=${s.peerCount} bootstrap_total=${s.bootstrapTotal} '
        'bootstrap_reachable=${s.bootstrapReachable}',
      );
    }
    if (frame.hasNetwork()) {
      final n = frame.network;
      print(
        'NETWORK: reason=${n.reason} connected=${n.connected.length} '
        'routing=${n.routing.length} bootstrap_total=${n.bootstrapTotal} '
        'bootstrap_reachable=${n.bootstrapReachable}',
      );
      for (final p in n.connected.where((p) => p.isBootstrap)) {
        print('  connected bootstrap: ${p.peerId} ${p.addr}');
      }
      for (final p in n.routing.where((p) => p.isBootstrap)) {
        print('  routing bootstrap: ${p.peerId} connected=${p.connected}');
      }
    }
    if (frame.hasError()) {
      print('ERROR id=${frame.id}: ${frame.error.code} ${frame.error.message}');
      pending--;
    }
    if (frame.hasDone()) pending--;
    if (pending == 0) break;
  }
  await reqs.close();
  await channel.shutdown();
}
