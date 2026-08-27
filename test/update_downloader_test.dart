import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kwaainet_gui/src/update/release_checker.dart';
import 'package:kwaainet_gui/src/update/update_downloader.dart';

const _body = 'the quick brown fox jumps over the lazy dog';
final _bytes = utf8.encode(_body);
final _digest = sha256.convert(_bytes).toString();

http.Client _serving(List<int> bytes, {int status = 200}) {
  return MockClient.streaming((req, _) async {
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      contentLength: bytes.length,
    );
  });
}

ReleaseAsset _asset(String? sha) => ReleaseAsset(
  name: 'kwaainet-gui-macos.zip',
  url: 'https://example.test/kwaainet-gui-macos.zip',
  sizeBytes: _bytes.length,
  sha256: sha,
);

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kw-dl-test');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  File dest() => File('${tmp.path}/kwaainet-gui-macos.zip');
  File part() => File('${dest().path}.part');

  test('a matching digest writes the file and leaves no partial', () async {
    final dl = UpdateDownloader(client: _serving(_bytes));
    final seen = <int>[];
    await for (final p in dl.download(_asset(_digest), dest: dest())) {
      seen.add(p.received);
    }
    expect(await dest().readAsString(), _body);
    expect(await part().exists(), isFalse);
    expect(seen.last, _bytes.length);
  });

  test('progress reports a fraction against the declared length', () async {
    final dl = UpdateDownloader(client: _serving(_bytes));
    final fractions = <double?>[];
    await for (final p in dl.download(_asset(_digest), dest: dest())) {
      fractions.add(p.fraction);
    }
    expect(fractions.last, 1.0);
  });

  test('a corrupted byte fails, deletes the partial, installs nothing', () async {
    final corrupt = [..._bytes];
    corrupt[0] ^= 0xff;
    final dl = UpdateDownloader(client: _serving(corrupt));

    await expectLater(
      dl.download(_asset(_digest), dest: dest()).drain<void>(),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(await part().exists(), isFalse);
    expect(await dest().exists(), isFalse);
  });

  test('a null digest fails closed — nothing is written', () async {
    final dl = UpdateDownloader(client: _serving(_bytes));
    await expectLater(
      dl.download(_asset(null), dest: dest()).drain<void>(),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(await dest().exists(), isFalse);
    expect(await part().exists(), isFalse);
  });

  test('a non-200 fails and leaves nothing behind', () async {
    final dl = UpdateDownloader(client: _serving(_bytes, status: 404));
    await expectLater(
      dl.download(_asset(_digest), dest: dest()).drain<void>(),
      throwsA(isA<UpdateDownloadException>()),
    );
    expect(await dest().exists(), isFalse);
    expect(await part().exists(), isFalse);
  });
  test('cancelling the subscription deletes the partial', () async {
    // The cleanup lives in a finally, not a catch: a cancelled subscription
    // unwinds the generator without raising, so a catch would leak the .part.
    final chunks = StreamController<List<int>>();
    final dl = UpdateDownloader(
      client: MockClient.streaming((req, _) async {
        return http.StreamedResponse(chunks.stream, 200, contentLength: 1000);
      }),
    );

    final started = Completer<void>();
    final sub = dl.download(_asset(_digest), dest: dest()).listen((_) {
      if (!started.isCompleted) started.complete();
    });

    chunks.add(_bytes);
    await started.future;
    expect(await part().exists(), isTrue, reason: 'partial exists mid-flight');

    // Cancellation of an async* generator is delivered at its next yield, so
    // one more chunk is what lets it unwind — hence cancel() is not awaited
    // in the controller either.
    final cancelled = sub.cancel();
    chunks.add(_bytes);
    await cancelled.timeout(const Duration(seconds: 5));
    await chunks.close();

    expect(await part().exists(), isFalse);
    expect(await dest().exists(), isFalse);
  });
}
