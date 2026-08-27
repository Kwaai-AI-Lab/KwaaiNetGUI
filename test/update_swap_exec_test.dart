@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/update/update_installer.dart';

/// Executes the real helper text against a throwaway tree. The goldens assert
/// the script's shape; this asserts what it actually does to a filesystem.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kw-swap');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// A dead pid the helper's `kill -0` loop will fall straight through.
  Future<int> deadPid() async {
    final p = await Process.start('/bin/sh', ['-c', 'exit 0']);
    await p.exitCode;
    return p.pid;
  }

  Future<ProcessResult> runSwap({
    required String target,
    required String staged,
    required String stage,
    String relaunch = ':',
    InstallKind kind = InstallKind.linuxDir,
  }) async {
    final script = File('${tmp.path}/swap.sh');
    await script.writeAsString(
      swapScript(
        pid: await deadPid(),
        target: target,
        staged: staged,
        stage: stage,
        relaunch: relaunch,
        kind: kind,
      ),
    );
    return Process.run('/bin/sh', [script.path]);
  }

  test('swaps the staged build in and clears .old and the stage', () async {
    final target = Directory('${tmp.path}/App')..createSync();
    File('${target.path}/marker').writeAsStringSync('old');
    final stage = Directory('${tmp.path}/.kwaainet-update-0.3.0')..createSync();
    final staged = Directory('${stage.path}/bundle')..createSync();
    File('${staged.path}/marker').writeAsStringSync('new');

    final r = await runSwap(
      target: target.path,
      staged: staged.path,
      stage: stage.path,
    );

    expect(r.exitCode, 0);
    expect(File('${target.path}/marker').readAsStringSync(), 'new');
    expect(Directory('${target.path}.old').existsSync(), isFalse);
    expect(stage.existsSync(), isFalse);
  });

  test('rolls back to .old when the staged build is missing', () async {
    final target = Directory('${tmp.path}/App')..createSync();
    File('${target.path}/marker').writeAsStringSync('old');
    final stage = Directory('${tmp.path}/.kwaainet-update-0.3.0')..createSync();

    final r = await runSwap(
      target: target.path,
      staged: '${stage.path}/bundle', // never created
      stage: stage.path,
    );

    expect(r.exitCode, 1);
    // The original install is back, with its contents intact.
    expect(File('${target.path}/marker').readAsStringSync(), 'old');
  });

  test('runs the relaunch command only after a successful swap', () async {
    final target = Directory('${tmp.path}/App')..createSync();
    final stage = Directory('${tmp.path}/.kwaainet-update-0.3.0')..createSync();
    Directory('${stage.path}/bundle').createSync();
    final witness = '${tmp.path}/relaunched';

    // macOS form: Linux backgrounds the relaunch with nohup, which would make
    // this a race rather than an ordering assertion.
    final ok = await runSwap(
      target: target.path,
      staged: '${stage.path}/bundle',
      stage: stage.path,
      relaunch: 'touch ${shQuote(witness)}',
      kind: InstallKind.macOsApp,
    );
    expect(ok.exitCode, 0);
    expect(File(witness).existsSync(), isTrue);
  });

  test('a path containing a quote still swaps cleanly', () async {
    // "Darren's Apps" would be a syntax error if the path were not quoted.
    final dir = Directory("${tmp.path}/Darren's Apps")..createSync();
    final target = Directory('${dir.path}/App')..createSync();
    File('${target.path}/marker').writeAsStringSync('old');
    final stage = Directory('${dir.path}/.kwaainet-update-0.3.0')..createSync();
    final staged = Directory('${stage.path}/bundle')..createSync();
    File('${staged.path}/marker').writeAsStringSync('new');

    final r = await runSwap(
      target: target.path,
      staged: staged.path,
      stage: stage.path,
    );

    expect(r.stderr.toString(), isEmpty);
    expect(r.exitCode, 0);
    expect(File('${target.path}/marker').readAsStringSync(), 'new');
  });

  test('refuses to swap while the pid is still alive', () async {
    final live = await Process.start('/bin/sh', ['-c', 'sleep 30']);
    addTearDown(live.kill);

    final target = Directory('${tmp.path}/App')..createSync();
    final stage = Directory('${tmp.path}/.kwaainet-update-0.3.0')..createSync();
    Directory('${stage.path}/bundle').createSync();

    final script = File('${tmp.path}/swap.sh');
    await script.writeAsString(
      swapScript(
        pid: live.pid,
        target: target.path,
        staged: '${stage.path}/bundle',
        stage: stage.path,
        relaunch: ':',
        kind: InstallKind.linuxDir,
      ).replaceFirst('-ge 240', '-ge 2'), // shorten the bounded wait
    );
    final r = await Process.run('/bin/sh', [script.path]);

    expect(r.exitCode, 1);
    // Nothing was touched while the app was still running.
    expect(Directory('${target.path}.old').existsSync(), isFalse);
    expect(target.existsSync(), isTrue);
  });
}
