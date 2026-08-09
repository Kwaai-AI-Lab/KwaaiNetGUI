import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/chat/generated/kwaai.pb.dart' as pb;
import 'package:kwaainet_gui/src/chat/session_client.dart';
import 'package:kwaainet_gui/src/daemon/daemon_state.dart';
import 'package:kwaainet_gui/src/daemon/rag_state.dart';
import 'package:kwaainet_gui/src/ui/pages/rag_tab.dart';
import 'package:kwaainet_gui/src/ui/theme/theme_variants.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_button.dart';
import 'package:kwaainet_gui/src/ui/widgets/kwaai_text_field.dart';

/// Tests for the RAG tab.
///
/// The tab's four states are chosen from two inputs — daemon availability
/// and the status future — so each state is reachable by overriding those
/// two providers alone. That is the seam these tests drive: no daemon, no
/// platform channels, and no drag-and-drop plumbing required.
pb.RagStatusUpdate _status(List<pb.RagKb> kbs) =>
    pb.RagStatusUpdate()..kbs.addAll(kbs);

pb.RagKb _kb({
  String name = 'default',
  String embedModel = 'nomic-embed-text',
  List<String> docs = const [],
  bool remote = false,
}) => pb.RagKb()
  ..name = name
  ..embedModel = embedModel
  ..docs.addAll(docs)
  ..remote = remote;

/// Hosts [RagTab] with the daemon reported available and the status future
/// resolved to whatever the case under test needs.
Widget _host({
  required AsyncValue<pb.RagStatusUpdate> status,
  bool daemonUp = true,
  Size size = const Size(900, 700),
}) {
  return ProviderScope(
    overrides: [
      daemonAvailableProvider.overrideWithValue(daemonUp),
      // overrideWith on a FutureProvider wants a Future; an AsyncError is
      // reproduced by throwing, which is what the error state consumes.
      ragStatusProvider.overrideWith((ref) async {
        return status.when(
          data: (d) => d,
          loading: () => Completer<pb.RagStatusUpdate>().future,
          error: (e, st) => Future<pb.RagStatusUpdate>.error(e, st),
        );
      }),
    ],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: const RagTab(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offers to initialise when the daemon reports no KBs', (
    tester,
  ) async {
    await tester.pumpWidget(_host(status: AsyncValue.data(_status(const []))));
    await tester.pumpAndSettle();

    expect(find.text('RAG isn\'t set up yet'), findsOneWidget);
    expect(find.text('Initialize RAG'), findsOneWidget);
    // The init gate must not be confused with the ready state, whose
    // document panel is the thing that would otherwise show through.
    expect(find.text('Documents'), findsNothing);
  });

  testWidgets('reports a daemon built without RAG as unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.error(
          SessionOpError(code: kRagUnimplemented, message: 'no rag feature'),
          StackTrace.empty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RAG isn\'t available in this daemon'), findsOneWidget);
    // Offering an Initialize button here would be a dead end.
    expect(find.text('Initialize RAG'), findsNothing);
  });

  testWidgets('shows the daemon-unavailable view when nothing is running', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(status: AsyncValue.data(_status(const [])), daemonUp: false),
    );
    await tester.pumpAndSettle();

    // Whatever the status says, an unreachable daemon takes priority.
    expect(find.text('RAG isn\'t set up yet'), findsNothing);
    expect(find.text('Initialize RAG'), findsNothing);
  });

  testWidgets('ready state lists the selected KB and its documents', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.data(
          _status([
            _kb(docs: const ['handbook.pdf', 'notes.md']),
            _kb(name: 'archive'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Doc count and embedding model share the panel's subtitle line.
    // (The KB *name* is shown by RagKbPicker in the window's top bar,
    // which is outside this widget — see the picker tests below.)
    expect(find.textContaining('2 documents'), findsOneWidget);
    expect(find.textContaining('nomic-embed-text'), findsOneWidget);
    expect(find.text('handbook.pdf'), findsOneWidget);
    expect(find.text('notes.md'), findsOneWidget);
    // Ingest affordances are live for a local KB.
    expect(find.text('Browse…'), findsOneWidget);
    expect(find.text('Query'), findsOneWidget);
  });

  testWidgets('empty KB explains itself rather than showing a blank list', (
    tester,
  ) async {
    await tester.pumpWidget(_host(status: AsyncValue.data(_status([_kb()]))));
    await tester.pumpAndSettle();

    expect(find.textContaining('No documents yet'), findsOneWidget);
    expect(find.textContaining('0 documents'), findsOneWidget);
  });

  testWidgets('a remote KB is shown but neither ingests nor queries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.data(
          _status([
            _kb(name: 'shared', remote: true, docs: const ['a.txt']),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Remote KBs aren\'t supported yet'),
      findsOneWidget,
    );
    // The browse affordance is gone entirely, and Query is genuinely
    // disabled — a null onPressed, not merely dimmed styling.
    expect(find.text('Browse…'), findsNothing);
    final query = tester.widget<KwaaiButton>(
      find.widgetWithText(KwaaiButton, 'Query'),
    );
    expect(query.onPressed, isNull);
  });

  testWidgets('renders retrieved chunks with rank, score and provenance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _results([
        _chunk(rank: 1, score: 0.8412, doc: 'handbook.pdf', index: 4),
        _chunk(rank: 2, score: 0.5, doc: 'notes.md', index: 0),
      ]),
    );
    await tester.pumpAndSettle();

    // Scores are fixed to 3 decimals so the column compares cleanly —
    // 0.5 must not render as "0.5".
    expect(find.text('0.841'), findsOneWidget);
    expect(find.text('0.500'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('handbook.pdf'), findsOneWidget);
    // Rank and chunk index share the '#n' form; index 4 belongs to the
    // first card and rank 2 to the second, so both appear once.
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('#2'), findsWidgets);
    expect(find.textContaining('chunk body'), findsNWidgets(2));
  });

  testWidgets('says so when a query matches nothing', (tester) async {
    await tester.pumpWidget(_results(const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing matched'), findsOneWidget);
  });

  testWidgets('the search field sits below the results area', (tester) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.data(
          _status([
            _kb(docs: const ['handbook.pdf']),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The point of the layout: the query row is pinned to the bottom, so
    // the placeholder (and later, results) occupies the space above it.
    final field = tester.getRect(find.byType(KwaaiTextField));
    final placeholder = tester.getRect(
      find.textContaining('Search this knowledge base'),
    );
    expect(field.top, greaterThan(placeholder.bottom));
    // ...and it is pinned to the bottom of the tab rather than floating
    // directly under a header. Measured against the tab's own rect (the
    // 700px host is clipped by the 800x600 test window), leaving only the
    // query row's bottom padding.
    final tab = tester.getRect(find.byType(RagTab));
    expect(field.bottom, greaterThan(tab.bottom - 40));
  });

  testWidgets('each document offers a delete control on hover', (tester) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.data(
          _status([
            _kb(docs: const ['handbook.pdf']),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Hidden until pointed at, so the list reads as filenames rather than
    // as a column of buttons.
    expect(find.byTooltip('Delete document'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('handbook.pdf')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Delete document'), findsOneWidget);
  });

  testWidgets('deleting asks before destroying anything', (tester) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.data(
          _status([
            _kb(docs: const ['handbook.pdf']),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('handbook.pdf')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete document'));
    await tester.pumpAndSettle();

    // A confirmation naming the document, not an immediate delete — the
    // rpc client here is unoverridden, so reaching it would throw.
    expect(find.text('Delete document?'), findsOneWidget);
    expect(find.textContaining('handbook.pdf'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete document?'), findsNothing);
  });

  testWidgets('a remote KB offers no delete control', (tester) async {
    await tester.pumpWidget(
      _host(
        status: AsyncValue.data(
          _status([
            _kb(name: 'shared', remote: true, docs: const ['a.txt']),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('a.txt')));
    await tester.pumpAndSettle();

    // Deleting from a remote KB fails daemon-side, so don't offer it.
    expect(find.byTooltip('Delete document'), findsNothing);
  });

  group('RagKbPicker', () {
    testWidgets('lists every KB and marks the selected one', (tester) async {
      await tester.pumpWidget(
        _pickerHost([_kb(), _kb(name: 'archive')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('default'), findsOneWidget);
      expect(find.text('Create KB'), findsOneWidget);
    });

    testWidgets('renders nothing when no KB exists', (tester) async {
      await tester.pumpWidget(_pickerHost(const []));
      await tester.pumpAndSettle();

      // Nothing to pick between, and the tab is showing its init gate —
      // an empty dropdown in the title bar would be noise.
      expect(find.text('Create KB'), findsNothing);
    });
  });
}

/// Hosts [RagKbPicker] alone — it reads the same status provider as the
/// tab but lives in the window's top bar, so it is driven separately.
Widget _pickerHost(List<pb.RagKb> kbs) {
  return ProviderScope(
    overrides: [
      daemonAvailableProvider.overrideWithValue(true),
      ragStatusProvider.overrideWith((ref) async => _status(kbs)),
    ],
    child: MaterialApp(
      theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
      home: const Scaffold(body: Row(children: [RagKbPicker()])),
    ),
  );
}

pb.RagChunk _chunk({
  required int rank,
  required double score,
  required String doc,
  required int index,
}) => pb.RagChunk()
  ..rank = rank
  ..score = score
  ..doc = doc
  ..chunkIndex = index
  ..text = 'chunk body $rank';

/// Hosts the result list on its own — it takes chunks rather than fetching
/// them, so no daemon or provider override is involved.
Widget _results(List<pb.RagChunk> chunks) {
  return MaterialApp(
    theme: buildKwaaiTheme(ThemeVariantKey.kwaai, Brightness.dark),
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 700,
        child: SingleChildScrollView(child: RagResultList(chunks: chunks)),
      ),
    ),
  );
}
