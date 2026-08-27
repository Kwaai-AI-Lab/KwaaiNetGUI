import 'package:flutter_test/flutter_test.dart';

import 'package:kwaainet_gui/src/update/update_installer.dart';

void main() {
  group('resolveInstallRoot', () {
    test('macOS: three parents up from the bundle executable', () {
      final root = resolveInstallRoot(
        exePath: '/Applications/KwaaiNet.app/Contents/MacOS/KwaaiNet',
        kind: InstallKind.macOsApp,
      );
      expect(root?.path, '/Applications/KwaaiNet.app');
      expect(root?.parentPath, '/Applications');
    });

    test('macOS: keyed off the bundle shape, not the bundled daemon', () {
      // A locally-built .app has no kwaainet in Contents/Resources; it must
      // still be updatable.
      final root = resolveInstallRoot(
        exePath: '/Users/me/Apps/KwaaiNet.app/Contents/MacOS/KwaaiNet',
        kind: InstallKind.macOsApp,
        exists: (_) => false,
      );
      expect(root?.path, '/Users/me/Apps/KwaaiNet.app');
    });

    test('macOS: a root that is not a .app is rejected', () {
      expect(
        resolveInstallRoot(
          exePath: '/opt/KwaaiNet/Contents/MacOS/KwaaiNet',
          kind: InstallKind.macOsApp,
        ),
        isNull,
      );
    });

    test('macOS: a non-bundle layout is rejected', () {
      expect(
        resolveInstallRoot(
          exePath: '/usr/local/bin/KwaaiNet',
          kind: InstallKind.macOsApp,
        ),
        isNull,
      );
    });

    test('Linux: exe dir with data/flutter_assets beside it', () {
      final root = resolveInstallRoot(
        exePath: '/opt/kwaainet/kwaainet_gui',
        kind: InstallKind.linuxDir,
        exists: (p) => p == '/opt/kwaainet/data/flutter_assets',
      );
      expect(root?.path, '/opt/kwaainet');
      expect(root?.parentPath, '/opt');
    });

    test('Windows: same, with backslashes', () {
      final root = resolveInstallRoot(
        exePath: r'C:\Program Files\KwaaiNet\kwaainet_gui.exe',
        kind: InstallKind.windowsDir,
        exists: (p) => p == r'C:\Program Files\KwaaiNet\data\flutter_assets',
      );
      expect(root?.path, r'C:\Program Files\KwaaiNet');
      expect(root?.parentPath, r'C:\Program Files');
    });

    test('a dev tree with no flutter_assets is rejected', () {
      expect(
        resolveInstallRoot(
          exePath: '/usr/local/bin/kwaainet_gui',
          kind: InstallKind.linuxDir,
          exists: (_) => false,
        ),
        isNull,
      );
    });
  });

  group('staging paths', () {
    const mac = InstallRoot(
      path: '/Applications/KwaaiNet.app',
      kind: InstallKind.macOsApp,
    );
    const linux = InstallRoot(
      path: '/opt/kwaainet',
      kind: InstallKind.linuxDir,
    );
    const win = InstallRoot(
      path: r'C:\Program Files\KwaaiNet',
      kind: InstallKind.windowsDir,
    );

    test('stage dir sits beside the install root, so the move is a rename', () {
      expect(stagePathFor(mac, '0.3.0'), '/Applications/.kwaainet-update-0.3.0');
      expect(stagePathFor(linux, '0.3.0'), '/opt/.kwaainet-update-0.3.0');
      expect(
        stagePathFor(win, '0.3.0'),
        r'C:\Program Files\.kwaainet-update-0.3.0',
      );
    });

    test('payload name follows each archive layout', () {
      expect(
        stagedPayloadPath(mac, stagePathFor(mac, '0.3.0')),
        '/Applications/.kwaainet-update-0.3.0/KwaaiNet.app',
      );
      expect(
        stagedPayloadPath(linux, stagePathFor(linux, '0.3.0')),
        '/opt/.kwaainet-update-0.3.0/bundle',
      );
      // The Windows zip is flat, so it gets a wrapper to match the others.
      expect(
        stagedPayloadPath(win, stagePathFor(win, '0.3.0')),
        r'C:\Program Files\.kwaainet-update-0.3.0\app',
      );
    });
  });

  group('swapScript', () {
    String unix(InstallKind kind, String relaunch) => swapScript(
      pid: 4242,
      target: '/Applications/KwaaiNet.app',
      staged: '/Applications/.kwaainet-update-0.3.0/KwaaiNet.app',
      stage: '/Applications/.kwaainet-update-0.3.0',
      relaunch: relaunch,
      kind: kind,
    );

    test('macOS: waits on the pid, renames aside, rolls back, relaunches', () {
      final s = unix(InstallKind.macOsApp, 'open -n "/Applications/KwaaiNet.app"');
      expect(s, startsWith('#!/bin/sh'));
      expect(s, contains('while kill -0 4242 2>/dev/null; do'));
      // Bounded wait — a wedged app must not leave the helper spinning.
      expect(s, contains(r'[ "$i" -ge 240 ] && exit 1'));
      expect(s, contains(r'mv "$TARGET" "$TARGET.old" || exit 1'));
      expect(
        s,
        contains(
          r'mv "$STAGED" "$TARGET" || { rm -rf "$TARGET"; '
          r'mv "$TARGET.old" "$TARGET"; exit 1; }',
        ),
      );
      expect(s, contains('open -n "/Applications/KwaaiNet.app"'));
      // .old is only removed once the new build has landed.
      expect(
        s.indexOf(r'mv "$STAGED" "$TARGET"'),
        lessThan(s.lastIndexOf(r'rm -rf "$TARGET.old"')),
      );
    });

    test('Linux: relaunch is detached from the helper', () {
      final s = unix(InstallKind.linuxDir, '"/opt/kwaainet/kwaainet_gui"');
      expect(s, contains('nohup "/opt/kwaainet/kwaainet_gui" >/dev/null 2>&1 &'));
      expect(s, contains(r'mv "$TARGET.old" "$TARGET"; exit 1; }'));
    });

    test('Windows: Wait-Process, then rename-aside with a rollback catch', () {
      final s = swapScript(
        pid: 99,
        target: r'C:\Program Files\KwaaiNet',
        staged: r'C:\Program Files\.kwaainet-update-0.3.0\app',
        stage: r'C:\Program Files\.kwaainet-update-0.3.0',
        relaunch: relaunchCommand(
          const InstallRoot(
            path: "C:" r"\Program Files\KwaaiNet",
            kind: InstallKind.windowsDir,
          ),
        ),
        kind: InstallKind.windowsDir,
      );
      expect(s, contains('Wait-Process -Id 99 -Timeout 120'));
      // -ErrorAction SilentlyContinue swallows the timeout, so the wait alone
      // proves nothing — liveness must be checked explicitly.
      expect(
        s,
        contains(
          'if (Get-Process -Id 99 -ErrorAction SilentlyContinue) { exit 1 }',
        ),
      );
      expect(s, contains(r'Move-Item -LiteralPath $target -Destination $old'));
      expect(s, contains('} catch {'));
      expect(s, contains(r'Move-Item -LiteralPath $old -Destination $target'));
      expect(s, contains('exit 1'));
      expect(s, contains("Start-Process 'C:" r"\Program Files\KwaaiNet\kwaainet_gui.exe'"));
      // Rollback must precede the success-path cleanup of .old.
      expect(
        s.indexOf('} catch {'),
        lessThan(s.indexOf(r'Remove-Item -LiteralPath $old -Recurse -Force' '\n')),
      );
    });
  });

  group('quoting on embed', () {
    test('sh: a path with a quote is escaped, not interpolated raw', () {
      final s = swapScript(
        pid: 1,
        target: "/Users/me/Darren's Apps/KwaaiNet.app",
        staged: "/Users/me/Darren's Apps/.kwaainet-update-0.3.0/KwaaiNet.app",
        stage: "/Users/me/Darren's Apps/.kwaainet-update-0.3.0",
        relaunch: 'open -n x',
        kind: InstallKind.macOsApp,
      );
      // '\'' is the sh idiom for a literal quote inside single quotes.
      expect(s, contains(r"TARGET='/Users/me/Darren'\''s Apps/KwaaiNet.app'"));
      expect(s, isNot(contains("TARGET='/Users/me/Darren's Apps")));
    });

    test('sh: shell metacharacters in a path stay inert', () {
      final s = swapScript(
        pid: 1,
        target: r'/tmp/a$(id)/App',
        staged: '/tmp/x',
        stage: '/tmp/s',
        relaunch: ':',
        kind: InstallKind.linuxDir,
      );
      // Single-quoted, so $(id) is literal text to sh.
      expect(s, contains(r"TARGET='/tmp/a$(id)/App'"));
    });

    test('PowerShell: a quote is doubled', () {
      final s = swapScript(
        pid: 1,
        target: "C:" r"\Users\Darren's Apps\KwaaiNet",
        staged: r'C:\s\app',
        stage: r'C:\s',
        relaunch: 'x',
        kind: InstallKind.windowsDir,
      );
      expect(s, contains(r"$target = 'C:\Users\Darren''s Apps\KwaaiNet'"));
    });

    test('relaunchCommand quotes the path it embeds', () {
      expect(
        relaunchCommand(
          const InstallRoot(
            path: "/Apps/Darren's/KwaaiNet.app",
            kind: InstallKind.macOsApp,
          ),
        ),
        r"open -n '/Apps/Darren'\''s/KwaaiNet.app'",
      );
    });

    test('shQuote / psQuote', () {
      expect(shQuote('plain'), "'plain'");
      expect(shQuote("it's"), r"'it'\''s'");
      expect(psQuote("it's"), "'it''s'");
    });
  });

  group('relaunchCommand', () {
    test('per platform, always quoted', () {
      expect(
        relaunchCommand(
          const InstallRoot(
            path: '/Applications/KwaaiNet.app',
            kind: InstallKind.macOsApp,
          ),
        ),
        "open -n '/Applications/KwaaiNet.app'",
      );
      expect(
        relaunchCommand(
          const InstallRoot(path: '/opt/kwaainet', kind: InstallKind.linuxDir),
        ),
        "'/opt/kwaainet/kwaainet_gui'",
      );
      expect(
        relaunchCommand(
          const InstallRoot(
            path: "C:" r"\KwaaiNet",
            kind: InstallKind.windowsDir,
          ),
        ),
        "'C:" r"\KwaaiNet\kwaainet_gui.exe'",
      );
    });
  });
}
