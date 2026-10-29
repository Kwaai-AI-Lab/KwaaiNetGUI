import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kwaainet_gui/src/chat/kwaai_rpc_client.dart';

void main() {
  late Directory dir;
  late String defaultFile;
  late String namedFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('grpc_token_test');
    defaultFile = '${dir.path}${Platform.pathSeparator}kwaainet.token';
    namedFile = '${dir.path}${Platform.pathSeparator}named.token';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String? resolve(String? env) =>
      resolveGrpcToken(envFile: env, defaultFile: defaultFile);

  test('reads the daemon token file, trimmed', () {
    File(defaultFile).writeAsStringSync('abc123\n');
    expect(resolve(null), 'abc123');
  });

  test('a file named in the env var outranks the default', () {
    File(defaultFile).writeAsStringSync('default');
    File(namedFile).writeAsStringSync('named');
    expect(resolve(namedFile), 'named');
  });

  test('an empty env var falls through to the default', () {
    File(defaultFile).writeAsStringSync('default');
    expect(resolve(''), 'default');
  });

  test('a named file that is missing sends no token, not the default', () {
    File(defaultFile).writeAsStringSync('default');
    expect(resolve(namedFile), isNull);
  });

  test('no file sends no token (pre-auth daemon)', () {
    expect(resolve(null), isNull);
  });

  test('an empty file sends no token', () {
    File(defaultFile).writeAsStringSync('\n');
    expect(resolve(null), isNull);
  });
}
