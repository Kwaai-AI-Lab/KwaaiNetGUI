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

  test('an empty file fails without sending anything', () async {
    // The daemon rejects size 0, so don't announce one.
    final op = session.ragIngest(file: writeFile('empty.txt', 0));
    expect(op.id, isNull);
    await expectLater(op.done, throwsA(isA<RagFileRejected>()));
    await pumpEventQueue();
    expect(service.frames, isEmpty);
  });

  test('a file over 256 MiB fails without sending anything', () async {
    final file = File('${tmp.path}/huge.pdf');
    // Sparse: only the length is read before the check.
    file.openSync(mode: FileMode.write)
      ..truncateSync(kRagIngestMaxBytes + 1)
      ..closeSync();
    final op = session.ragIngest(file: file);
    expect(op.id, isNull);
    await expectLater(op.done, throwsA(isA<RagFileRejected>()));
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

  group('piece window', () {
    const piece = 1000;
    const pieces = 20;

    test('sends exactly 8 unacked pieces, then completes on acks', () async {
      service.withholdAcks = true;
      final file = writeFile('slow.txt', piece * pieces + 17);
      final op = session.ragIngest(file: file, pieceBytes: piece);

      await service.receivedAtLeast(kRagIngestMaxUnackedPieces * piece);
      // Room for a violation to show: nothing more may arrive unacked.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.pieces, kRagIngestMaxUnackedPieces);

      // One ack reopens exactly one slot.
      service.ackOne();
      await service.receivedAtLeast(9 * piece);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.pieces, 9);

      service.releaseAcks();
      await op.done.timeout(const Duration(seconds: 5));
      expect(service.pieces, pieces + 1);
      final joined = [
        for (final f in service.frames.where((f) => f.hasRagIngestData()))
          ...f.ragIngestData.data,
      ];
      expect(joined, file.readAsBytesSync());
    });

    test('a larger window is capped at the daemon\'s 8', () async {
      service.withholdAcks = true;
      final file = writeFile('capped.txt', piece * pieces);
      final op = session.ragIngest(
        file: file,
        pieceBytes: piece,
        maxUnackedPieces: 32,
      );
      await service.receivedAtLeast(kRagIngestMaxUnackedPieces * piece);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.pieces, kRagIngestMaxUnackedPieces);

      service.releaseAcks();
      await op.done.timeout(const Duration(seconds: 5));
    });

    test('a smaller window may lower it', () async {
      service.withholdAcks = true;
      final file = writeFile('narrow.txt', piece * pieces);
      final op = session.ragIngest(
        file: file,
        pieceBytes: piece,
        maxUnackedPieces: 2,
      );
      await service.receivedAtLeast(2 * piece);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.pieces, 2);

      service.releaseAcks();
      await op.done.timeout(const Duration(seconds: 5));
      expect(service.received, piece * pieces);
    });

    test('a daemon error while stalled ends the op promptly', () async {
      service.withholdAcks = true;
      final file = writeFile('fails.txt', piece * pieces);
      final op = session.ragIngest(file: file, pieceBytes: piece);
      await service.receivedAtLeast(kRagIngestMaxUnackedPieces * piece);

      service.failIngest();
      await expectLater(
        op.done.timeout(const Duration(seconds: 2)),
        throwsA(isA<SessionOpError>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.pieces, kRagIngestMaxUnackedPieces);
    });

    test('closing the session while stalled ends the op promptly', () async {
      service.withholdAcks = true;
      final file = writeFile('closes.txt', piece * pieces);
      final op = session.ragIngest(file: file, pieceBytes: piece);
      await service.receivedAtLeast(kRagIngestMaxUnackedPieces * piece);

      await session.close();
      await expectLater(
        op.done.timeout(const Duration(seconds: 2)),
        throwsA(isA<SessionEndedError>()),
      );
    });

    test('cancel sends Cancel for the op id and stops sending', () async {
      service.withholdAcks = true;
      final file = writeFile('cancel.txt', piece * pieces);
      final op = session.ragIngest(file: file, pieceBytes: piece);
      await service.receivedAtLeast(kRagIngestMaxUnackedPieces * piece);

      await op.cancel();
      final cancel = await service.cancel.future.timeout(
        const Duration(seconds: 5),
      );
      expect(cancel.targetId.toInt(), op.id);
      await expectLater(
        op.done.timeout(const Duration(seconds: 2)),
        throwsA(isA<SessionOpError>().having((e) => e.code, 'code', 4)),
      );
      // Acks arriving after the cancel must not release more pieces.
      service.releaseAcks();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.pieces, kRagIngestMaxUnackedPieces);
    });
  });
}

/// Records ClientFrames and plays the daemon: acks each piece with RECEIVING
/// progress (unless [withholdAcks]) and replies once the full size arrives.
/// A Cancel ends the ingest with CANCELLED, as the daemon does.
class _IngestService extends pbgrpc.KwaaiNetServiceBase {
  final frames = <pb.ClientFrame>[];
  final cancel = Completer<pb.Cancel>();
  bool withholdAcks = false;
  int received = 0;
  int pieces = 0;

  final _out = StreamController<pb.ServerFrame>();
  final _progress = StreamController<int>.broadcast();
  // Byte offset at the end of each piece not yet acked, in order.
  final _unacked = <int>[];
  Int64 _id = Int64.ZERO;
  int _size = -1;
  bool _ended = false;

  Future<void> receivedAtLeast(int n) async {
    if (received >= n) return;
    await _progress.stream
        .firstWhere((r) => r >= n)
        .timeout(const Duration(seconds: 5));
  }

  void ackOne() {
    if (_unacked.isNotEmpty) _ack(_unacked.removeAt(0));
  }

  void releaseAcks() {
    withholdAcks = false;
    while (_unacked.isNotEmpty) {
      ackOne();
    }
    if (received == _size) _reply();
  }

  void failIngest() => _out.add(
    pb.ServerFrame()
      ..id = _id
      ..error = (pb.Error()
        ..code = pb.Error_Code.CANCELLED
        ..message = 'cancelled'),
  );

  void _ack(int done) => _out.add(
    pb.ServerFrame()
      ..id = _id
      ..ragProgress = pb.RagProgress(
        phase: pb.RagProgress_RagPhase.RAG_PHASE_RECEIVING,
        done: done,
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
          _ended = true;
          failIngest();
          _out.add(
            pb.ServerFrame()
              ..id = f.id
              ..done = pb.Done(),
          );
          return;
        }
        frames.add(f);
        if (f.hasRagIngest()) {
          _id = f.id;
          _size = f.ragIngest.size.toInt();
        } else if (f.hasRagIngestData()) {
          received += f.ragIngestData.data.length;
          pieces++;
          _progress.add(received);
          if (withholdAcks) {
            _unacked.add(received);
          } else {
            _ack(received);
          }
        }
        if (received == _size && _unacked.isEmpty) _reply();
      },
      onError: (Object _) => _out.close(),
      onDone: _out.close,
    );
    return _out.stream;
  }

  void _reply() {
    if (_ended) return;
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

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
