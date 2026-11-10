import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:giwifi_ua_switcher/headless/cli.dart';

void main() {
  group('ServeOptions.parse', () {
    test('默认值', () {
      final options = ServeOptions.parse(const <String>[]);
      expect(options.host, '0.0.0.0');
      expect(options.port, 8712);
      expect(options.token, '');
      expect(options.serverUrl, 'http://100.100.9.2');
      expect(options.acName, 'GiWiFi_lnsfHG');
      expect(options.help, false);
    });

    test('解析全部参数（含 = 形式）', () {
      final options = ServeOptions.parse(const <String>[
        '--host',
        '127.0.0.1',
        '--port=9000',
        '--token',
        'abc123',
        '--server',
        'https://portal.example.com',
        '--ac',
        'TestAC',
      ]);
      expect(options.host, '127.0.0.1');
      expect(options.port, 9000);
      expect(options.token, 'abc123');
      expect(options.serverUrl, 'https://portal.example.com');
      expect(options.acName, 'TestAC');
    });

    test('命令行 --token 优先于环境变量', () {
      const environment = <String, String>{'GIWIFI_TOKEN': 'env-token'};
      expect(
        ServeOptions.parse(const <String>[], environment: environment).token,
        'env-token',
      );
      expect(
        ServeOptions.parse(
          const <String>['--token', 'flag-token'],
          environment: environment,
        ).token,
        'flag-token',
      );
    });

    test('非法端口抛出 FormatException', () {
      expect(
        () => ServeOptions.parse(const <String>['--port', '0']),
        throwsFormatException,
      );
      expect(
        () => ServeOptions.parse(const <String>['--port', 'abc']),
        throwsFormatException,
      );
      expect(
        () => ServeOptions.parse(const <String>['--port', '70000']),
        throwsFormatException,
      );
    });

    test('非法服务器地址与未知参数抛出 FormatException', () {
      expect(
        () => ServeOptions.parse(const <String>['--server', 'ftp://x']),
        throwsFormatException,
      );
      expect(
        () => ServeOptions.parse(const <String>['--nope']),
        throwsFormatException,
      );
      expect(
        () => ServeOptions.parse(const <String>['--port']),
        throwsFormatException,
      );
    });

    test('--help 标记帮助', () {
      expect(ServeOptions.parse(const <String>['--help']).help, true);
      expect(ServeOptions.parse(const <String>['-h']).help, true);
    });
  });

  test('版本号与 pubspec 一致', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;
    expect(kHeadlessVersion, version);
  });
}
