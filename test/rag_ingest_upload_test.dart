import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/generated/kwaai.pbgrpc.dart' as pbgrpc;
import 'package:kwaainet_gui/src/chat/session_client.dart';

/// `ragIngest` against a real in-process gRPC server that records every
/// ClientFrame the Session carries, so the wire shape is what is asserted.
void main() {
  late Directory tmp;
  late Server server;
  late _IngestService service;
  late ClientChannel channel;
  late SessionClient session;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rag_ingest_upload_test');
    service = _IngestService();
    server = Server.create(services: [service]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    channel = ClientChannel(
      InternetAddress.loopbackIPv4,
      port: server.port!,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    session = SessionClient(pbgrpc.KwaaiNetClient(channel));
  });

  tearDown(() async {
    await session.close();
    await channel.shutdown();
    await server.shutdown();
    await tmp.delete(recursive: true);
  });

  File writeFile(String name, int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = (i * 31 + 7) & 0xff;
    }
    return File('${tmp.path}/$name')..writeAsBytesSync(bytes);
  }

  test('sends RagIngest then the file as pieces under the same id', () async {
    const piece = 1000;
    final file = writeFile('report.pdf', 3 * piece + 123);
    final op = session.ragIngest(file: file, kb: 'docs', pieceBytes: piece);

    final reply = await op.done.timeout(const Duration(seconds: 5));
    expect(reply.chunksIngested, 1);

    final ingest = service.frames.first;
    expect(ingest.id.toInt(), op.id);
    expect(ingest.ragIngest.docName, 'report.pdf');
    expect(ingest.ragIngest.kb, 'docs');
    expect(ingest.ragIngest.size.toInt(), file.lengthSync());

    final data = service.frames.skip(1).toList();
    expect(data, isNotEmpty);
    for (final f in data) {
      expect(f.whichBody(), pb.ClientFrame_Body.ragIngestData);
      expect(f.id.toInt(), op.id);
      expect(f.ragIngestData.data.length, lessThanOrEqualTo(piece));
    }
    expect(data.map((f) => f.ragIngestData.data.length), [
      piece,
      piece,
      piece,
      123,
    ]);
    final joined = [for (final f in data) ...f.ragIngestData.data];
    expect(joined, file.readAsBytesSync());
  });

  test(
    'default pieces stay at 256 KiB and docName can be overridden',
    () async {
      final file = writeFile('blob.bin', 600 * 1024);
      final op = session.ragIngest(file: file, docName: 'notes.md');
      await op.done.timeout(const Duration(seconds: 5));

      expect(service.frames.first.ragIngest.docName, 'notes.md');
      final sizes = service.frames
          .skip(1)
          .map((f) => f.ragIngestData.data.length)
          .toList();
      expect(sizes, [kRagIngestPieceBytes, kRagIngestPieceBytes, 88 * 1024]);
    },
  );

  test('an empty file sends no data frames', () async {
    final file = writeFile('empty.txt', 0);
    final op = session.ragIngest(file: file);
    await op.done.timeout(const Duration(seconds: 5));
    expect(service.frames.single.ragIngest.size.toInt(), 0);
  });

  test('a read that comes up short fails the ingest and cancels it', () async {
    final file = writeFile('shrinks.txt', 4096);
    final op = session.ragIngest(file: file, pieceBytes: 1024);
    // Announced at 4096 bytes; the read (which starts asynchronously) sees 0.
    file.writeAsBytesSync(const []);

    await expectLater(
      op.done.timeout(const Duration(seconds: 5)),
      throwsA(isA<FileSystemException>()),
    );
    final cancel = await service.cancel.future.timeout(
      const Duration(seconds: 5),
    );
    expect(cancel.targetId.toInt(), op.id);
  });

  test('a missing file fails without sending anything', () async {
    final op = session.ragIngest(file: File('${tmp.path}/nope.pdf'));
    expect(op.id, isNull);
    await expectLater(op.done, throwsA(isA<FileSystemException>()));
  });

  test('acks reach the caller as RECEIVING progress', () async {
    const piece = 1000;
    final file = writeFile('acks.txt', 5 * piece);
    final op = session.ragIngest(file: file, pieceBytes: piece);
    final seen = <pb.RagProgress>[];
    op.progress.listen(seen.add);
    await op.done.timeout(const Duration(seconds: 5));
    await pumpEventQueue();

    expect(seen.map((p) => p.phase).toSet(), {
      pb.RagProgress_RagPhase.RAG_PHASE_RECEIVING,
    });
    expect(seen.map((p) => p.done), [1000, 2000, 3000, 4000, 5000]);
    expect(seen.last.total, 5000);
  });

  group('in-flight window', () {
    const piece = 1000;
    const window = 4 * piece;
    const pieces = 20;

    test('stalls at the window until acks arrive, then completes', () async {
      service.withholdAcks = true;
      final file = writeFile('slow.txt', piece * pieces);
      final op = session.ragIngest(
        file: file,
        pieceBytes: piece,
        windowBytes: window,
      );

      await service.receivedAtLeast(window);
      // Room for a violation to show: nothing more may arrive unacked.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.received, window);

      service.releaseAcks();
      await op.done.timeout(const Duration(seconds: 5));
      final joined = [
        for (final f in service.frames.where((f) => f.hasRagIngestData()))
          ...f.ragIngestData.data,
      ];
      expect(joined, file.readAsBytesSync());
    });

    test('a window under one piece still admits a piece', () async {
      final file = writeFile('tiny-window.txt', 3 * piece);
      final op = session.ragIngest(
        file: file,
        pieceBytes: piece,
        windowBytes: 1,
      );
      await op.done.timeout(const Duration(seconds: 5));
      expect(service.received, 3 * piece);
    });

    test('a daemon error while stalled ends the op promptly', () async {
      service.withholdAcks = true;
      final file = writeFile('fails.txt', piece * pieces);
      final op = session.ragIngest(
        file: file,
        pieceBytes: piece,
        windowBytes: window,
      );
      await service.receivedAtLeast(window);

      service.failIngest();
      await expectLater(
        op.done.timeout(const Duration(seconds: 2)),
        throwsA(isA<SessionOpError>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.received, window);
    });

    test('closing the session while stalled ends the op promptly', () async {
      service.withholdAcks = true;
      final file = writeFile('closes.txt', piece * pieces);
      final op = session.ragIngest(
        file: file,
        pieceBytes: piece,
        windowBytes: window,
      );
      await service.receivedAtLeast(window);

      await session.close();
      await expectLater(
        op.done.timeout(const Duration(seconds: 2)),
        throwsA(isA<SessionEndedError>()),
      );
    });
  });
}

/// Records ClientFrames and plays the daemon: acks each piece with RECEIVING
/// progress (unless [withholdAcks]) and replies once the full size arrives.
class _IngestService extends pbgrpc.KwaaiNetServiceBase {
  final frames = <pb.ClientFrame>[];
  final cancel = Completer<pb.Cancel>();
  bool withholdAcks = false;
  int received = 0;

  final _out = StreamController<pb.ServerFrame>();
  final _progress = StreamController<int>.broadcast();
  Int64 _id = Int64.ZERO;
  int _size = -1;

  Future<void> receivedAtLeast(int n) async {
    if (received >= n) return;
    await _progress.stream
        .firstWhere((r) => r >= n)
        .timeout(const Duration(seconds: 5));
  }

  void releaseAcks() {
    withholdAcks = false;
    _ack();
  }

  void failIngest() => _out.add(
    pb.ServerFrame()
      ..id = _id
      ..error = (pb.Error()
        ..code = pb.Error_Code.CANCELLED
        ..message = 'cancelled'),
  );

  void _ack() => _out.add(
    pb.ServerFrame()
      ..id = _id
      ..ragProgress = pb.RagProgress(
        phase: pb.RagProgress_RagPhase.RAG_PHASE_RECEIVING,
        done: received,
        total: _size,
      ),
  );

  @override
  Stream<pb.ServerFrame> session(
    ServiceCall call,
    Stream<pb.ClientFrame> incoming,
  ) {
    incoming.listen(
      (f) {
        if (f.hasCancel()) {
          if (!cancel.isCompleted) cancel.complete(f.cancel);
          return;
        }
        frames.add(f);
        if (f.hasRagIngest()) {
          _id = f.id;
          _size = f.ragIngest.size.toInt();
        } else if (f.hasRagIngestData()) {
          received += f.ragIngestData.data.length;
          _progress.add(received);
          if (!withholdAcks) _ack();
        }
        if (received == _size) {
          _out
            ..add(
              pb.ServerFrame()
                ..id = _id
                ..ragIngest = pb.RagIngestReply(chunksIngested: 1),
            )
            ..add(
              pb.ServerFrame()
                ..id = _id
                ..done = pb.Done(),
            );
          _size = -1;
        }
      },
      onError: (Object _) => _out.close(),
      onDone: _out.close,
    );
    return _out.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
