import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbgrpc.dart' as pbgrpc;
import 'package:kwaainet_gui/src/chat/session_client.dart';

/// A [pbgrpc.KwaaiNetClient] whose Session is driven by the test rather
/// than a socket. Overriding `session` is enough — nothing else on the
/// stub is reached by the paths under test, so no channel is ever used.
class _FakeStub extends pbgrpc.KwaaiNetClient {
  _FakeStub() : super(ClientChannel('127.0.0.1', port: 1));

  final inbound = StreamController<pb.ServerFrame>();
  final sent = <pb.ClientFrame>[];

  @override
  ResponseStream<pb.ServerFrame> session(
    Stream<pb.ClientFrame> request, {
    CallOptions? options,
  }) {
    request.listen(sent.add);
    return ResponseStream(_FakeCall(inbound.stream));
  }
}

/// Minimal [ClientCall] stand-in: [ResponseStream] only reads `response`.
class _FakeCall implements ClientCall<pb.ClientFrame, pb.ServerFrame> {
  _FakeCall(this._responses);

  final Stream<pb.ServerFrame> _responses;

  @override
  Stream<pb.ServerFrame> get response => _responses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

pb.ServerFrame _token(int id, String text) => pb.ServerFrame()
  ..id = Int64(id)
  ..token = (pb.ChatToken()..text = text);

pb.ServerFrame _event(int id, pb.InferencePhase phase) => pb.ServerFrame()
  ..id = Int64(id)
  ..inferenceEvent = (pb.InferenceEvent()..phase = phase);

pb.ServerFrame _done(int id) => pb.ServerFrame()
  ..id = Int64(id)
  ..done = pb.Done();

pb.ServerFrame _error(int id, String message) => pb.ServerFrame()
  ..id = Int64(id)
  ..error = (pb.Error()
    ..code = pb.Error_Code.INTERNAL
    ..message = message);

void main() {
  late _FakeStub stub;
  late SessionClient client;

  setUp(() {
    stub = _FakeStub();
    client = SessionClient(stub);
  });

  tearDown(() async {
    await client.close();
    if (!stub.inbound.isClosed) await stub.inbound.close();
  });

  group('shardRunOp', () {
    test('does not request events unless asked', () async {
      client.shardRunOp('hi');
      await Future<void>.delayed(Duration.zero);
      expect(stub.sent.single.shardRun.events, isFalse);
    });

    test('asks the daemon for events when requested', () async {
      client.shardRunOp('hi', events: true);
      await Future<void>.delayed(Duration.zero);
      expect(stub.sent.single.shardRun.events, isTrue);
    });

    test('events stream is empty when not requested', () async {
      final op = client.shardRunOp('hi');
      expect(await op.events.toList(), isEmpty);
    });

    /// The router is single-subscription, so the tee has to fan out from
    /// one listen. Getting this wrong throws "Stream has already been
    /// listened to" the moment both sides are read.
    test('splits one operation into tokens and events', () async {
      final op = client.shardRunOp('hi', events: true);
      final id = op.id!;

      final tokens = op.tokens.toList();
      final events = op.events.toList();

      await Future<void>.delayed(Duration.zero);
      stub.inbound
        ..add(_event(id, pb.InferencePhase.INFERENCE_PHASE_RESOLVED))
        ..add(_token(id, 'Hello'))
        ..add(_event(id, pb.InferencePhase.INFERENCE_PHASE_HOP_OK))
        ..add(_token(id, ' world'))
        ..add(_done(id));

      expect(await tokens, ['Hello', ' world']);
      expect(
        (await events).map((e) => e.phase),
        [
          pb.InferencePhase.INFERENCE_PHASE_RESOLVED,
          pb.InferencePhase.INFERENCE_PHASE_HOP_OK,
        ],
      );
    });

    /// Both sides have to see the failure. If the error only reached the
    /// tokens, anything watching events would wait forever on a run that
    /// has already ended.
    test('an operation error reaches both streams', () async {
      final op = client.shardRunOp('hi', events: true);
      final id = op.id!;

      final tokens = expectLater(op.tokens, emitsError(isA<SessionOpError>()));
      final events = expectLater(op.events, emitsError(isA<SessionOpError>()));

      await Future<void>.delayed(Duration.zero);
      stub.inbound.add(_error(id, 'boom'));

      await tokens;
      await events;
    });

    /// Plain (buffering) controllers are what make this work: a broadcast
    /// controller would drop frames that arrive before the listener
    /// attaches, which on a fast daemon is exactly the chain discovery.
    test('events sent before subscribing are not lost', () async {
      final op = client.shardRunOp('hi', events: true);
      final id = op.id!;

      await Future<void>.delayed(Duration.zero);
      stub.inbound
        ..add(_event(id, pb.InferencePhase.INFERENCE_PHASE_RESOLVED))
        ..add(_event(id, pb.InferencePhase.INFERENCE_PHASE_CHAIN_PINNED))
        ..add(_done(id));

      // Subscribe only now, after every frame has already been delivered.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await op.events.length, 2);
    });
  });
}
