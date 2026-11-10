import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:giwifi_ua_switcher/headless/headless_server.dart';
import 'package:giwifi_ua_switcher/models/device_profile.dart';
import 'package:giwifi_ua_switcher/services/auth_service.dart';

/// 可控的 AuthService 替身：记录入参并按脚本返回结果。
class _FakeAuth extends AuthService {
  _FakeAuth({
    this.onLogin,
    this.online = OnlineStatus.offline,
    this.duration,
    this.logoutResult = true,
  }) : super(discover: false);

  final Future<LoginResult> Function(_FakeAuth auth)? onLogin;
  final OnlineStatus online;
  final String? duration;
  final bool logoutResult;

  Future<bool> Function(String rebindInfo)? pendingRebind;
  Future<bool> Function()? pendingSwitch;

  String? lastUsername;
  String? lastPassword;
  String? lastUserAgent;
  bool logoutCalled = false;

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
    required String userAgent,
    String accountType = '2',
    Future<bool> Function(String rebindInfo)? onRebindConfirm,
    Future<bool> Function()? onSwitchConfirm,
    void Function(String status)? onStatus,
  }) async {
    lastUsername = username;
    lastPassword = password;
    lastUserAgent = userAgent;
    pendingRebind = onRebindConfirm;
    pendingSwitch = onSwitchConfirm;
    final handler = onLogin;
    if (handler != null) return handler(this);
    return const LoginResult(success: true, message: '认证成功');
  }

  @override
  Future<OnlineStatus> checkOnline(String userAgent) async {
    lastUserAgent = userAgent;
    return online;
  }

  @override
  Future<String?> fetchOnlineDuration(String userAgent) async => duration;

  @override
  Future<bool> logout(String userAgent) async {
    logoutCalled = true;
    lastUserAgent = userAgent;
    return logoutResult;
  }

  @override
  String get effectiveBaseUrl => 'http://10.1.2.3';

  @override
  String get effectiveAcName => 'GiWiFi_test';

  @override
  String? get effectiveClientIp => '10.1.2.99';
}

class _Response {
  const _Response(this.status, this.body);

  final int status;
  final String body;

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

Future<HeadlessServer> _startServer({
  AuthService Function()? factory,
  String token = '',
}) async {
  final server = HeadlessServer(
    host: '127.0.0.1',
    port: 0,
    token: token,
    authFactory: factory,
  );
  await server.start();
  addTearDown(server.close);
  return server;
}

Future<_Response> _request(
  HeadlessServer server,
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
  bool headerToken = false,
  String? rawBody,
}) async {
  final client = HttpClient();
  try {
    final suffix = token == null || headerToken
        ? ''
        : '${path.contains('?') ? '&' : '?'}'
            'token=${Uri.encodeQueryComponent(token)}';
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.boundPort}$path$suffix'),
    );
    if (headerToken && token != null) {
      request.headers.set('X-Auth-Token', token);
    }
    if (rawBody != null) {
      request.headers.contentType = ContentType.json;
      request.write(rawBody);
    } else if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    return _Response(response.statusCode, await utf8.decodeStream(response));
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('HeadlessServer', () {
    test('GET / 返回内嵌页面', () async {
      final server = await _startServer();
      final response = await _request(server, 'GET', '/');
      expect(response.status, HttpStatus.ok);
      expect(response.body, contains('GiWiFi 校园网认证台'));
      expect(response.body, contains('终端槽位'));
    });

    test('GET /api/profiles 返回五个终端槽位', () async {
      final server = await _startServer();
      final response = await _request(server, 'GET', '/api/profiles');
      expect(response.status, HttpStatus.ok);
      final profiles = (response.json['profiles'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(profiles.map((p) => p['id']), [
        'pc',
        'android_phone',
        'iphone',
        'ipad',
        'custom',
      ]);
      expect(response.json['defaultSlot'], 'pc');
    });

    test('令牌启用时三种携带方式均生效，缺失返回 401', () async {
      final server = await _startServer(token: 'secret');
      expect(
        (await _request(server, 'GET', '/api/profiles')).status,
        HttpStatus.unauthorized,
      );
      expect(
        (await _request(server, 'GET', '/api/profiles', token: 'wrong')).status,
        HttpStatus.unauthorized,
      );
      expect(
        (await _request(server, 'GET', '/api/profiles', token: 'secret'))
            .status,
        HttpStatus.ok,
      );
      expect(
        (await _request(
          server,
          'GET',
          '/api/profiles',
          token: 'secret',
          headerToken: true,
        ))
            .status,
        HttpStatus.ok,
      );
    });

    test('登录透传账号与所选槽位 UA', () async {
      final fake = _FakeAuth();
      final server = await _startServer(factory: () => fake);
      final response = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': '20230001',
          'password': 'p@ss',
          'slot': 'android_phone',
        },
      );

      expect(response.status, HttpStatus.ok);
      expect(response.json['success'], true);
      expect(fake.lastUsername, '20230001');
      expect(fake.lastPassword, 'p@ss');
      expect(
        fake.lastUserAgent,
        DeviceProfile.byId('android_phone').userAgent,
      );
      expect(response.json['portal'], <String, dynamic>{
        'baseUrl': 'http://10.1.2.3',
        'acName': 'GiWiFi_test',
        'clientIp': '10.1.2.99',
      });
    });

    test('自定义槽位使用请求中的 UA', () async {
      final fake = _FakeAuth();
      final server = await _startServer(factory: () => fake);
      final response = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'custom',
          'custom_ua': 'MyAgent/1.0',
        },
      );

      expect(response.json['success'], true);
      expect(fake.lastUserAgent, 'MyAgent/1.0');
    });

    test('自定义槽位缺少 UA 返回 400', () async {
      final server = await _startServer(factory: () => _FakeAuth());
      final response = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'custom',
        },
      );
      expect(response.status, HttpStatus.badRequest);
      expect(response.json['error'], contains('UA'));
    });

    test('缺少账号密码返回 400', () async {
      final server = await _startServer(factory: () => _FakeAuth());
      final response = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{'username': '', 'password': ''},
      );
      expect(response.status, HttpStatus.badRequest);
    });

    test('非法 JSON 返回 400', () async {
      final server = await _startServer(factory: () => _FakeAuth());
      final response = await _request(
        server,
        'POST',
        '/api/login',
        rawBody: '{not json',
      );
      expect(response.status, HttpStatus.badRequest);
    });

    test('换绑两阶段：首轮不换绑并提示确认，确认后才继续', () async {
      final fake = _FakeAuth(
        onLogin: (auth) async {
          final confirmed = await auth.pendingRebind!('绑定设备数量已达上限');
          if (!confirmed) {
            return const LoginResult(
              success: false,
              message: '已取消换绑，认证未完成',
            );
          }
          return const LoginResult(success: true, message: '认证成功');
        },
      );
      final server = await _startServer(factory: () => fake);

      final first = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'pc',
        },
      );
      expect(first.json['success'], false);
      expect(first.json['needsRebind'], true);
      expect(first.json['rebindInfo'], '绑定设备数量已达上限');
      expect(first.json['alreadyOnline'], false);

      final second = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'pc',
          'confirm_rebind': true,
        },
      );
      expect(second.json['success'], true);
      expect(second.json['needsRebind'], false);
    });

    test('已在线两阶段：确认后才切换设备', () async {
      final fake = _FakeAuth(
        onLogin: (auth) async {
          final confirmed = await auth.pendingSwitch!();
          if (!confirmed) {
            return const LoginResult(
              success: false,
              message: '当前设备已在线，已取消切换（未验证账号密码）',
            );
          }
          return const LoginResult(success: true, message: '认证成功');
        },
      );
      final server = await _startServer(factory: () => fake);

      final first = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'iphone',
        },
      );
      expect(first.json['alreadyOnline'], true);
      expect(first.json['needsRebind'], false);

      final second = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'iphone',
          'confirm_switch': true,
        },
      );
      expect(second.json['success'], true);
      expect(second.json['alreadyOnline'], false);
    });

    test('登录异常转换为友好提示', () async {
      final fake = _FakeAuth(
        onLogin: (_) async => throw const SocketException('boom'),
      );
      final server = await _startServer(factory: () => fake);
      final response = await _request(
        server,
        'POST',
        '/api/login',
        body: <String, dynamic>{
          'username': 'u',
          'password': 'p',
          'slot': 'pc',
        },
      );
      expect(response.status, HttpStatus.ok);
      expect(response.json['success'], false);
      expect(response.json['message'], contains('无法连接认证服务器'));
    });

    test('注销调用 AuthService.logout', () async {
      final fake = _FakeAuth(logoutResult: true);
      final server = await _startServer(factory: () => fake);
      final response = await _request(
        server,
        'POST',
        '/api/logout',
        body: <String, dynamic>{'slot': 'pc'},
      );
      expect(response.json['success'], true);
      expect(fake.logoutCalled, true);
    });

    test('状态查询返回在线时长与门户信息', () async {
      final fake = _FakeAuth(
        online: OnlineStatus.online,
        duration: '01:02:03',
      );
      final server = await _startServer(factory: () => fake);
      final response = await _request(
        server,
        'GET',
        '/api/status?slot=ipad',
      );

      expect(response.status, HttpStatus.ok);
      expect(response.json['status'], 'online');
      expect(response.json['duration'], '01:02:03');
      expect(
        fake.lastUserAgent,
        DeviceProfile.byId('ipad').userAgent,
      );
      expect(response.json['portal'], isA<Map<String, dynamic>>());
    });

    test('未知接口返回 404，错误方法返回 405', () async {
      final server = await _startServer();
      expect(
        (await _request(server, 'GET', '/api/nope')).status,
        HttpStatus.notFound,
      );
      expect(
        (await _request(server, 'GET', '/api/login')).status,
        HttpStatus.methodNotAllowed,
      );
    });
  });
}
