import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/session_client.dart';
import 'package:kwaainet_gui/src/daemon/rag_state.dart';
import 'package:kwaainet_gui/src/ui/pages/rag_tab.dart';

/// Pure-function tests for the RAG tab's decision helpers.
///
/// These carry the logic that is easy to get subtly wrong and invisible in
/// a screenshot: which KB gets selected, whether a daemon error is fatal or
/// merely a failed operation, and which files are worth sending at all.
pb.RagKb _kb(String name) => pb.RagKb()..name = name;

void main() {
  group('selectKb', () {
    test('returns null only when there are no KBs', () {
      expect(selectKb(const [], null), isNull);
      expect(selectKb([_kb('a')], null), 'a');
    });

    test('honours an explicit selection that still exists', () {
      expect(selectKb([_kb('a'), _kb('b')], 'b'), 'b');
    });

    test('falls back when the selection has gone away', () {
      // A KB can vanish between the selection and the next status refresh;
      // holding a dangling name would render an empty tab.
      expect(selectKb([_kb('a'), _kb('b')], 'deleted'), 'a');
    });

    test('prefers a KB named default over declaration order', () {
      expect(selectKb([_kb('archive'), _kb('default')], null), 'default');
    });

    test('uses the first KB when none is named default', () {
      expect(selectKb([_kb('archive'), _kb('notes')], null), 'archive');
    });
  });

  group('isRagUnavailable', () {
    test('is true only for UNIMPLEMENTED', () {
      expect(
        isRagUnavailable(
          SessionOpError(code: kRagUnimplemented, message: 'nope'),
        ),
        isTrue,
      );
      expect(
        isRagUnavailable(SessionOpError(code: kRagUnavailable, message: 'x')),
        isFalse,
      );
      expect(isRagUnavailable(null), isFalse);
      expect(isRagUnavailable(Exception('boom')), isFalse);
    });
  });

  group('ragErrorText', () {
    test('passes the daemon message through for UNAVAILABLE', () {
      // The daemon names the remedy here ("start Ollama", "pull the
      // model"), so replacing it with generic copy would lose the only
      // actionable part.
      expect(
        ragErrorText(
          SessionOpError(
            code: kRagUnavailable,
            message: 'Ollama is not running on 127.0.0.1:11434',
          ),
        ),
        'Ollama is not running on 127.0.0.1:11434',
      );
    });

    test('falls back to its own copy when the message is empty', () {
      expect(
        ragErrorText(SessionOpError(code: kRagUnavailable, message: '')),
        contains('Ollama'),
      );
    });

    test('explains NOT_FOUND as an uninitialised KB', () {
      expect(
        ragErrorText(SessionOpError(code: kRagNotFound, message: 'missing')),
        contains('does not exist'),
      );
    });

    test('reports a lost session without leaking the exception type', () {
      final text = ragErrorText(
        SessionEndedError(kind: SessionEndKind.remoteClose, reason: 'bye'),
      );
      expect(text, contains('daemon'));
      expect(text, isNot(contains('SessionEndedError')));
    });
  });

  group('isSupportedRagFile', () {
    test('accepts the extensions the daemon extracts', () {
      for (final ext in kRagSupportedExtensions) {
        expect(isSupportedRagFile('/tmp/doc.$ext'), isTrue, reason: ext);
      }
    });

    test('is case-insensitive', () {
      expect(isSupportedRagFile('/tmp/REPORT.PDF'), isTrue);
    });

    test('rejects unknown and extensionless files', () {
      expect(isSupportedRagFile('/tmp/archive.zip'), isFalse);
      expect(isSupportedRagFile('/tmp/README'), isFalse);
      // A trailing dot has no extension after it.
      expect(isSupportedRagFile('/tmp/weird.'), isFalse);
      // A dotfile is a name, not an extension.
      expect(isSupportedRagFile('/tmp/.md'), isFalse);
    });

    test('keys off the basename, not the directory', () {
      // A path whose *directory* looks like a document must not qualify a
      // file that isn't one.
      expect(isSupportedRagFile('/home/notes.md/binary'), isFalse);
      expect(isSupportedRagFile('/home/v1.0/notes.md'), isTrue);
    });
  });

  group('basename', () {
    test('handles both separators and bare names', () {
      expect(basename('/a/b/c.txt'), 'c.txt');
      expect(basename(r'C:\a\b\c.txt'), 'c.txt');
      expect(basename('c.txt'), 'c.txt');
    });
  });

  group('validateKbName', () {
    test('accepts a plain name', () {
      expect(validateKbName('handbook'), isNull);
    });

    test('rejects empty, spaced and slashed names', () {
      expect(validateKbName(''), isNotNull);
      expect(validateKbName('my kb'), isNotNull);
      // Names become directories daemon-side.
      expect(validateKbName('a/b'), isNotNull);
      expect(validateKbName(r'a\b'), isNotNull);
    });
  });

  group('ragPhaseLabel', () {
    test('omits counts for the phase that has none', () {
      // EXTRACTING is one indivisible step and reports 0/0; showing that
      // as "0/0" would read as stalled.
      expect(
        ragPhaseLabel(pb.RagProgress_RagPhase.RAG_PHASE_EXTRACTING),
        isNot(contains('0')),
      );
    });

    test('includes counts for the counted phases', () {
      expect(
        ragPhaseLabel(
          pb.RagProgress_RagPhase.RAG_PHASE_EMBEDDING,
          done: 3,
          total: 10,
        ),
        contains('3/10'),
      );
      expect(
        ragPhaseLabel(
          pb.RagProgress_RagPhase.RAG_PHASE_UPLOADING,
          done: 9,
          total: 9,
        ),
        contains('9/9'),
      );
    });
  });

  group('RagIngestJob.fraction', () {
    test('is null when the phase reports no total', () {
      const job = RagIngestJob(path: '/a.md', name: 'a.md', kb: 'default');
      expect(job.fraction, isNull);
    });

    test('is a clamped ratio when counts are present', () {
      const job = RagIngestJob(
        path: '/a.md',
        name: 'a.md',
        kb: 'default',
        done: 5,
        total: 10,
      );
      expect(job.fraction, 0.5);
      // A daemon reporting done > total must not produce a bar past 100%.
      const over = RagIngestJob(
        path: '/a.md',
        name: 'a.md',
        kb: 'default',
        done: 12,
        total: 10,
      );
      expect(over.fraction, 1.0);
    });

    test('carries its KB through copyWith', () {
      // The KB identifies where the file lands, so it must survive every
      // progress update — each of which rebuilds the job via copyWith.
      const job = RagIngestJob(path: '/a.md', name: 'a.md', kb: 'archive');
      expect(job.copyWith(status: RagJobStatus.running).kb, 'archive');
      expect(job.copyWith(done: 3, total: 4).kb, 'archive');
    });
  });

  group('RagIngestQueue', () {
    test('stamps each job with the KB it was queued for', () {
      // Regression: the KB used to be a parameter of the drain loop rather
      // than a property of the job. Enqueuing while a drain was already
      // running returned early and left the original loop to pick the new
      // jobs up with *its* KB, so files dropped after switching the
      // dropdown were ingested into the previously selected KB.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final queue = container.read(ragIngestQueueProvider.notifier);

      queue.enqueue(const ['/docs/a.md'], kb: 'alpha');
      queue.enqueue(const ['/docs/b.md'], kb: 'beta');

      final jobs = container.read(ragIngestQueueProvider);
      expect(jobs.map((j) => j.name), ['a.md', 'b.md']);
      expect(jobs.map((j) => j.kb), ['alpha', 'beta']);
    });

    test('ignores an empty enqueue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final queue = container.read(ragIngestQueueProvider.notifier);

      queue.enqueue(const [], kb: 'alpha');
      expect(container.read(ragIngestQueueProvider), isEmpty);
    });
  });
}
