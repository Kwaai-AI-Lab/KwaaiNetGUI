import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'release_checker.dart';

/// Bytes received so far, and the expected total when the server declares one.
class DownloadProgress {
  const DownloadProgress({required this.received, this.total});

  final int received;
  final int? total;

  /// 0..1, or null when the total is unknown (indeterminate bar).
  double? get fraction {
    final t = total;
    if (t == null || t <= 0) return null;
    final f = received / t;
    return f > 1 ? 1 : f;
  }
}

/// A download that did not produce a verified file. The message is shown to
/// the user, so keep it short and non-technical where possible.
class UpdateDownloadException implements Exception {
  UpdateDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Streams a release asset to disk, hashing as it goes.
class UpdateDownloader {
  UpdateDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Downloads [asset] to [dest], emitting progress. Completes normally only
  /// when the sha256 matches; on any failure the partial is deleted and
  /// [dest] is never created.
  ///
  /// Writes to `<dest>.part` and renames on success, so a half-written file
  /// can never be mistaken for a verified one.
  Stream<DownloadProgress> download(
    ReleaseAsset asset, {
    required File dest,
  }) async* {
    final expected = asset.sha256;
    // No digest means no way to prove what we fetched — refuse rather than
    // install unverified bytes.
    if (expected == null || expected.isEmpty) {
      throw UpdateDownloadException(
        'The release does not publish a checksum for ${asset.name}.',
      );
    }

    final part = File('${dest.path}.part');
    await dest.parent.create(recursive: true);
    if (await part.exists()) await part.delete();

    final digestOut = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestOut);
    final sink = part.openWrite();
    var received = 0;
    var ok = false;

    // finally, not catch: a cancelled subscription unwinds the generator
    // without an error, and must still leave no partial behind.
    try {
      final resp = await _client.send(
        http.Request('GET', Uri.parse(asset.url))
          ..followRedirects = true
          ..headers['Accept'] = 'application/octet-stream',
      );
      if (resp.statusCode != 200) {
        throw UpdateDownloadException(
          'Download failed (HTTP ${resp.statusCode}).',
        );
      }
      final total = resp.contentLength ?? (asset.sizeBytes > 0 ? asset.sizeBytes : null);

      await for (final chunk in resp.stream) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        yield DownloadProgress(received: received, total: total);
      }

      await sink.flush();
      await sink.close();
      hasher.close();

      final actual = digestOut.value?.toString();
      if (actual != expected) {
        throw UpdateDownloadException(
          'The downloaded file failed its checksum and was discarded.',
        );
      }
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
      ok = true;
    } finally {
      if (!ok) await _discard(sink, part);
    }
  }

  /// Best-effort cleanup — also runs when the consumer cancels the stream.
  Future<void> _discard(IOSink sink, File part) async {
    try {
      await sink.close();
    } catch (_) {}
    try {
      if (await part.exists()) await part.delete();
    } catch (_) {}
  }

  void dispose() => _client.close();
}

/// Captures the single [Digest] a chunked sha256 conversion emits on close.
class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
