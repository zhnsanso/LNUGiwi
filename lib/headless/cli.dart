import 'dart:async';
import 'dart:io';

import 'headless_server.dart';

/// headless 版版本号；必须与 pubspec.yaml 的版本号（不含 build 号）一致，
/// 由 test/headless_cli_test.dart 校验。
const String kHeadlessVersion = '2.1.1';

/// `serve` 子命令的启动参数。
class ServeOptions {
  const ServeOptions({
    this.host = '0.0.0.0',
    this.port = 8712,
    this.token = '',
    this.serverUrl = 'http://100.100.9.2',
    this.acName = 'GiWiFi_lnsfHG',
    this.help = false,
  });

  final String host;
  final int port;
  final String token;
  final String serverUrl;
  final String acName;
  final bool help;

  /// 解析 `serve` 之后的参数。
  ///
  /// [environment] 提供 GIWIFI_TOKEN 兜底（systemd 里用 Environment= 配置，
  /// 避免令牌出现在 `ps` 的命令行里）；命令行 --token 优先。
  static ServeOptions parse(
    List<String> args, {
    Map<String, String> environment = const <String, String>{},
  }) {
    var host = '0.0.0.0';
    var port = 8712;
    var token = environment['GIWIFI_TOKEN']?.trim() ?? '';
    var serverUrl = 'http://100.100.9.2';
    var acName = 'GiWiFi_lnsfHG';

    for (var i = 0; i < args.length; i++) {
      var name = args[i];
      String? inline;
      if (name.startsWith('--')) {
        final eq = name.indexOf('=');
        if (eq > 0) {
          inline = name.substring(eq + 1);
          name = name.substring(0, eq);
        }
      }

      String takeValue() {
        if (inline != null) return inline;
        if (i + 1 >= args.length) {
          throw FormatException('参数 $name 缺少取值');
        }
        i++;
        return args[i];
      }

      switch (name) {
        case '-h' || '--help':
          return ServeOptions(
            host: host,
            port: port,
            token: token,
            serverUrl: serverUrl,
            acName: acName,
            help: true,
          );
        case '--host':
          final value = takeValue().trim();
          if (value.isEmpty) {
            throw const FormatException('监听地址不能为空');
          }
          host = value;
        case '--port':
          final raw = takeValue().trim();
          final value = int.tryParse(raw);
          if (value == null || value < 1 || value > 65535) {
            throw FormatException('端口无效：$raw');
          }
          port = value;
        case '--token':
          token = takeValue().trim();
        case '--server':
          final value = takeValue().trim();
          final uri = Uri.tryParse(value);
          if (uri == null ||
              (uri.scheme != 'http' && uri.scheme != 'https') ||
              uri.host.isEmpty) {
            throw FormatException('认证服务器地址无效：$value');
          }
          serverUrl = value;
        case '--ac':
          acName = takeValue().trim();
          if (acName.isEmpty) {
            throw const FormatException('AC 名称不能为空');
          }
        default:
          throw FormatException('未知参数：$name');
      }
    }

    return ServeOptions(
      host: host,
      port: port,
      token: token,
      serverUrl: serverUrl,
      acName: acName,
    );
  }
}

/// headless CLI 入口：目前只有 `serve` 子命令。
Future<void> runHeadlessCli(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    _printUsage();
    return;
  }
  if (args.first != 'serve') {
    stderr.writeln('未知命令：${args.first}');
    _printUsage();
    exitCode = 64;
    return;
  }

  ServeOptions options;
  try {
    options = ServeOptions.parse(
      args.skip(1).toList(),
      environment: Platform.environment,
    );
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    _printUsage();
    exitCode = 64;
    return;
  }
  if (options.help) {
    _printUsage();
    return;
  }

  final server = HeadlessServer(
    host: options.host,
    port: options.port,
    token: options.token,
    serverUrl: options.serverUrl,
    acName: options.acName,
  );
  try {
    await server.start();
  } on SocketException catch (e) {
    stderr.writeln(
      '启动失败：无法监听 ${options.host}:${options.port}（${e.message}）',
    );
    exitCode = 1;
    return;
  }

  await _printBanner(server, options);
  await _waitForShutdown();
  await server.close();
  stdout.writeln('已停止');
}

Future<void> _printBanner(
  HeadlessServer server,
  ServeOptions options,
) async {
  final suffix = options.token.isEmpty ? '' : '/?token=你的令牌';
  stdout.writeln('GiWiFi headless WebUI v$kHeadlessVersion');
  stdout.writeln('监听：http://${options.host}:${server.boundPort}');
  for (final address in await _lanAddresses()) {
    stdout.writeln('  局域网：http://$address:${server.boundPort}$suffix');
  }
  if (options.token.isEmpty) {
    stdout.writeln('令牌：未启用（同一网络内任何人都可访问，请仅在可信网络使用）');
  } else {
    stdout.writeln('令牌：已启用（访问时请在 URL 后附加 ?token=你的令牌）');
  }
  stdout.writeln(
    '认证服务器兜底：${options.serverUrl}（AC ${options.acName}），'
    '首次请求会自动发现门户参数',
  );
  stdout.writeln('按 Ctrl+C 停止');
}

Future<void> _waitForShutdown() async {
  final completer = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  for (final signal in <ProcessSignal>[
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    try {
      subscriptions.add(
        signal.watch().listen((_) {
          if (!completer.isCompleted) completer.complete();
        }),
      );
    } catch (_) {
      // 仅 Linux 需要；平台不支持该信号时忽略
    }
  }
  await completer.future;
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
}

Future<List<String>> _lanAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    return <String>[
      for (final interface in interfaces)
        for (final address in interface.addresses) address.address,
    ];
  } catch (_) {
    return const <String>[];
  }
}

void _printUsage() {
  stdout.writeln('''
用法：
  giwifi-headless serve [选项]

选项：
  --host <地址>      监听地址（默认 0.0.0.0）
  --port <端口>      监听端口（默认 8712）
  --token <令牌>     访问令牌；也可用环境变量 GIWIFI_TOKEN（默认不启用）
  --server <地址>    认证服务器兜底地址（默认 http://100.100.9.2）
  --ac <名称>        AC 名称兜底值（默认 GiWiFi_lnsfHG）
  -h, --help         显示本帮助

说明：
  WebUI 提供终端槽位选择（电脑 / 安卓手机 / iPhone / iPad / 自定义）
  与登录、注销、在线状态检测。凭据不做任何落盘，刷新页面即清除。''');
}
