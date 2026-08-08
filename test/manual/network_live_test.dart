@Tags(['manual'])
library;

// End-to-end probe for the Network session op against a *running* daemon.
// Excluded from the default suite (see dart_test.yaml) because it needs one.
//
//   flutter test test/manual/network_live_test.dart --tags manual
//
// Prints each update's reason so the push-vs-sample split is observable, and
// asserts the invariants that only a live daemon can demonstrate: that the
// self-status and peer tables agree with each other, that a connected peer
// marked as being in the routing table really is, and that suppression keeps a
// quiet node quiet.

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';
import 'package:kwaainet_gui/src/chat/session_client.dart';

void main() {
  test(
    'network op serves live swarm state',
    () async {
      final client = KwaaiRpcClient();
      addTearDown(client.close);

      final updates = <pb.NetworkUpdate>[];
      Object? failure;
      final started = DateTime.now();

      final sub = client
          .networkStream(intervalSecs: 5)
          .listen(
            (u) {
              updates.add(u);
              final elapsed =
                  DateTime.now().difference(started).inMilliseconds / 1000.0;
              final s = u.hasSelfStatus() ? u.selfStatus : pb.SelfStatus();
              // ignore: avoid_print
              print(
                '[${elapsed.toStringAsFixed(1).padLeft(6)}s] '
                'reason=${u.reason.name.replaceFirst('UPDATE_REASON_', '').padRight(12)} '
                'reach=${(s.reachability.isEmpty ? '-' : s.reachability).padRight(8)} '
                'src=${(s.reachabilitySource.isEmpty ? '-' : s.reachabilitySource).padRight(9)} '
                'relay=${s.usingRelay.toString().padRight(5)} '
                'connected=${u.connected.length.toString().padLeft(3)} '
                'routing=${u.routing.length.toString().padLeft(3)}',
              );
              for (final p in u.connected.take(8)) {
                final path = p.kind == pbenum.PeerConnKind.PEER_CONN_KIND_RELAY
                    ? 'relay'
                    : p.dcutr
                    ? 'p2p'
                    : 'direct';
                // ignore: avoid_print
                print(
                  '            ${path.padRight(7)} '
                  '${p.direction.padRight(9)} '
                  'rtt=${(p.rttMs == 0 ? '-' : '${p.rttMs}ms').padRight(7)} '
                  'proto=${p.protocols.length.toString().padLeft(2)} '
                  '${p.agentVersion.isEmpty ? '-' : p.agentVersion} '
                  '${p.peerId.substring(0, 12)}… '
                  '${p.isBootstrap
                      ? '(bootstrap)'
                      : p.isTrustedRelay
                      ? '(trusted relay)'
                      : ''}',
                );
              }
              final bootstraps = u.routing.where((r) => r.isBootstrap).length;
              // ignore: avoid_print
              print(
                '            routing: ${u.routing.length} '
                '(${u.routing.where((r) => r.connected).length} connected, '
                '$bootstraps bootstrap)',
              );
            },
            onError: (Object e) {
              failure = e;
              if (e is SessionOpError) {
                // ignore: avoid_print
                print('ERROR code=${e.code} message=${e.message}');
              } else {
                // ignore: avoid_print
                print('ERROR $e');
              }
            },
          );
      addTearDown(sub.cancel);

      // Long enough to see the first snapshot plus a few sample intervals.
      await Future<void>.delayed(const Duration(seconds: 25));

      if (failure is SessionOpError && (failure! as SessionOpError).code == 6) {
        // ignore: avoid_print
        print(
          'daemon is on the Go p2p path — this is the expected degradation, '
          'and the Peers tab renders "Network information is not available"',
        );
        return;
      }
      expect(failure, isNull, reason: 'the subscription errored');
      expect(updates, isNotEmpty, reason: 'no update arrived within 25s');

      final first = updates.first;

      // Self-status is always present on a native daemon.
      expect(first.hasSelfStatus(), isTrue);
      expect(first.selfStatus.peerId, isNotEmpty);
      expect(
        first.selfStatus.reachability,
        anyOf('unknown', 'public', 'private'),
      );
      // A source only means anything for a positive verdict.
      if (first.selfStatus.reachability != 'public') {
        expect(first.selfStatus.reachabilitySource, isEmpty);
      }
      // announceable mirrors the announce loop's own gate.
      expect(
        first.selfStatus.announceable,
        first.selfStatus.reachability != 'unknown',
      );
      // using_relay must agree with the relay address list rather than being
      // reported independently of it.
      expect(
        first.selfStatus.usingRelay,
        first.selfStatus.relayAddrs.isNotEmpty,
      );

      // Every connection carries the fields that do not depend on identify.
      for (final p in first.connected) {
        expect(p.peerId, isNotEmpty);
        expect(p.addr, isNotEmpty);
        expect(p.direction, anyOf('inbound', 'outbound'));
      }

      // The IN TABLE column must not lie: a connection flagged as being in the
      // routing table has to appear in the routing list of the same snapshot.
      final routingIds = {for (final r in first.routing) r.peerId};
      for (final r in first.routing.where((r) => r.connected)) {
        expect(
          first.connected.any((c) => c.peerId == r.peerId),
          isTrue,
          reason:
              'routing peer ${r.peerId} claims connected but is not in the '
              'connected list of the same snapshot',
        );
      }
      // …and the converse flag is computed from the same snapshot too.
      for (final c in first.connected) {
        final inTable = routingIds.contains(c.peerId);
        final claimed = first.routing
            .where((r) => r.peerId == c.peerId)
            .map((r) => r.connected);
        if (inTable) {
          expect(claimed.every((v) => v), isTrue);
        }
      }

      // Suppression: at a 5s sample interval a 25s window would yield ~5 updates
      // if nothing were suppressed. Peer sets do change on a live network, so
      // this is a loose ceiling — it catches "suppression is broken entirely",
      // which is the failure that matters (rtt_ms leaking into the identity
      // would produce an update every single tick).
      // ignore: avoid_print
      print('received ${updates.length} update(s) in 25s');
      expect(
        updates.length,
        lessThanOrEqualTo(5),
        reason:
            'more updates than sample ticks means suppression is not working',
      );

      // Reasons must be from the documented set, and a first update is never a
      // heartbeat.
      expect(
        first.reason,
        anyOf(
          pbenum.UpdateReason.UPDATE_REASON_TICK,
          pbenum.UpdateReason.UPDATE_REASON_REACHABILITY,
          pbenum.UpdateReason.UPDATE_REASON_PEERS,
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
