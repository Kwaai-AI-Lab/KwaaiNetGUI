import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbenum.dart' as pbenum;
import 'package:kwaainet_gui/src/ui/pages/peers_tab.dart';

/// The staleness cue exists because the daemon suppresses snapshots that would
/// say nothing new (see `HEARTBEAT` and `network_identity` in
/// kwaai-cli/src/grpc_server.rs). Silence is therefore normal, and the only
/// thing separating "healthy and quiet" from "wedged" is that the daemon still
/// sends an unchanged snapshot every 60 s.
///
/// That makes these constants a cross-repo contract rather than a local style
/// choice, which is what this test pins.
void main() {
  group('peers staleness threshold', () {
    // The daemon's HEARTBEAT, shared with block coverage and storage
    // discovery. If that constant moves, this test should fail and
    // peersStaleAfter has to move with it.
    const daemonHeartbeat = Duration(seconds: 60);

    test('clears the daemon heartbeat with margin', () {
      expect(
        peersStaleAfter,
        greaterThan(daemonHeartbeat),
        reason: 'a threshold at or below the heartbeat would flag every '
            'healthy quiet period as stale',
      );
      expect(
        peersStaleAfter - daemonHeartbeat,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
        reason: 'too little margin makes the cue flap on normal jitter',
      );
    });

    test('still catches a genuinely quiet daemon promptly', () {
      expect(
        peersStaleAfter,
        lessThanOrEqualTo(daemonHeartbeat * 3),
        reason: 'too much slack leaves a stale peer table looking live',
      );
    });

    test('re-evaluates often enough to be responsive', () {
      // Nothing rebuilds the view between updates, so the tick is what makes
      // the cue appear at all.
      expect(peersStaleTick, lessThan(peersStaleAfter));
      expect(peersStaleTick.inSeconds, greaterThan(0));
    });

    test('tolerates a sampling interval well inside the heartbeat', () {
      // The daemon samples the swarm every 5 s but only *sends* on a change or
      // the heartbeat. Staleness must be measured against the send cadence,
      // not the sample cadence — keying it to 5 s would mark a perfectly
      // healthy idle node stale within seconds.
      const daemonSampleInterval = Duration(seconds: 5);
      expect(peersStaleAfter, greaterThan(daemonSampleInterval * 4));
    });
  });

  group('update reason semantics', () {
    // The GUI relies on TICK being the proto3 zero value: an update from a
    // daemon that somehow omitted the field must not read as a reachability
    // event.
    test('an unset reason decodes as TICK', () {
      final decoded = pb.NetworkUpdate.fromBuffer(pb.NetworkUpdate().writeToBuffer());
      expect(decoded.reason, pbenum.UpdateReason.UPDATE_REASON_TICK);
    });

    test('every reason survives a round trip', () {
      for (final reason in [
        pbenum.UpdateReason.UPDATE_REASON_TICK,
        pbenum.UpdateReason.UPDATE_REASON_REACHABILITY,
        pbenum.UpdateReason.UPDATE_REASON_PEERS,
        pbenum.UpdateReason.UPDATE_REASON_HEARTBEAT,
      ]) {
        final update = pb.NetworkUpdate()..reason = reason;
        expect(
          pb.NetworkUpdate.fromBuffer(update.writeToBuffer()).reason,
          reason,
        );
      }
    });
  });

  group('connected/routing set relationship', () {
    // The two sets overlap without either containing the other. The view
    // renders them as separate sections for exactly this reason, so both edges
    // have to be representable.
    test('a node can have connections and an empty routing table', () {
      // Kademlia stays in client mode — adding nothing — until reachability
      // resolves, so this is the normal state of a freshly started node.
      final update = pb.NetworkUpdate()
        ..connected.add(pb.ConnectedPeer()..peerId = 'A')
        ..selfStatus = (pb.SelfStatus()..reachability = 'unknown');

      final decoded = pb.NetworkUpdate.fromBuffer(update.writeToBuffer());
      expect(decoded.connected, hasLength(1));
      expect(decoded.routing, isEmpty);
    });

    test('the routing table can hold peers we are not connected to', () {
      final update = pb.NetworkUpdate()
        ..routing.add(pb.RoutingPeer()
          ..peerId = 'B'
          ..connected = false);

      final decoded = pb.NetworkUpdate.fromBuffer(update.writeToBuffer());
      expect(decoded.connected, isEmpty);
      expect(decoded.routing.single.connected, isFalse);
    });
  });

  group('connection enrichment', () {
    // protocols/rttMs/agentVersion arrive from identify and ping, which
    // complete *after* the connection establishes. The empty state means "not
    // yet known" and must be distinguishable from a real value.
    test('a freshly established connection carries no enrichment', () {
      final peer = pb.ConnectedPeer()
        ..peerId = 'A'
        ..addr = '/ip4/198.18.0.10/tcp/8000'
        ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT
        ..direction = 'outbound';

      final decoded = pb.ConnectedPeer.fromBuffer(peer.writeToBuffer());
      expect(decoded.protocols, isEmpty);
      expect(decoded.agentVersion, isEmpty);
      expect(
        decoded.rttMs,
        0,
        reason: '0 means no ping has completed, never zero latency — the view '
            'renders it as an em dash rather than "0 ms"',
      );
    });

    test('a relayed connection is distinguishable from a direct one', () {
      final relayed = pb.ConnectedPeer()
        ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_RELAY;
      expect(
        pb.ConnectedPeer.fromBuffer(relayed.writeToBuffer()).kind,
        pbenum.PeerConnKind.PEER_CONN_KIND_RELAY,
      );
      // DIRECT is the zero value, so it encodes to nothing — worth pinning,
      // since a client that treated "absent" as "unknown" would mislabel every
      // direct connection.
      final direct = pb.ConnectedPeer()
        ..kind = pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT;
      expect(
        pb.ConnectedPeer.fromBuffer(direct.writeToBuffer()).kind,
        pbenum.PeerConnKind.PEER_CONN_KIND_DIRECT,
      );
    });
  });
}
