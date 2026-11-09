import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:giwifi_ua_switcher/services/auth_service.dart';

String _formPage() => '''
<html><body>
<form id="loginForm">
  <input type="hidden" name="sign" value="sig123">
  <input type="hidden" name="sta_ip" value="10.0.0.1">
  <input type="hidden" name="iv" value="0123456789abcdef">
  <input type="hidden" name="login_type" value="1">
  <input type="password" name="user_password">
</form>
</body></html>
''';

void main() {
  group('parsePortalRedirect', () {
    test('标准劫持重定向：解析出地址 / AC 名 / 本机 IP', () {
      const location =
          'http://100.100.9.2/gportal/web/login?wlanuserip=10.13.49.245'
          '&wlanacname=GiWiFi_lnsfHG&pagetype=index&logintype=2';
      final found = AuthService.parsePortalRedirect(location)!;
      expect(found.base, 'http://100.100.9.2');
      expect(found.acName, 'GiWiFi_lnsfHG');
      expect(found.clientIp, '10.13.49.245');
    });

    test('非 80 端口保留在地址里', () {
      const location =
          'http://10.1.2.3:8080/gportal/web/login?wlanuserip=1.2.3.4&wlanacname=A';
      expect(
        AuthService.parsePortalRedirect(location)!.base,
        'http://10.1.2.3:8080',
      );
    });

    test('非登录页跳转 / 缺参数 / 非法 URL 都返回 null', () {
      expect(AuthService.parsePortalRedirect('http://www.baidu.com/'), isNull);
      expect(
        AuthService.parsePortalRedirect('http://x/gportal/web/login'),
        isNull,
      );
      expect(AuthService.parsePortalRedirect('not-a-url'), isNull);
    });
  });

  test('动态发现：探测点 302 劫持后改用重定向里的真实门户', () async {
    final portal = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final portalBase = 'http://127.0.0.1:${portal.port}';
    var loginGets = 0;
    String? loginQuery;
    var authenticated = false;

    portal.listen((req) async {
      final path = req.uri.path;
      try {
        if (path == '/gportal/web/login') {
          loginGets++;
          loginQuery = req.uri.query;
          req.response.headers.contentType = ContentType.html;
          req.response.write(_formPage());
        } else if (path == '/gportal/Web/loginAction') {
          authenticated = true;
          req.response.write(
            jsonEncode(<String, dynamic>{
              'status': 1,
              'info': '认证成功',
              'data': <String, dynamic>{},
            }),
          );
        } else if (path == '/gportal/web/logout') {
          final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (!authenticated) {
            req.response.write('<html>offline</html>');
          } else {
            req.response.write(
              '<html><input type="hidden" name="si" value="sess1">'
              'var start = "$start"; online_duration</html>',
            );
          }
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      } catch (_) {
        await req.response.close();
      }
    });

    probe.listen((req) async {
      // 模拟 AC 劫持：指向另一个端口上的"真实门户"
      req.response.statusCode = 302;
      req.response.headers.set(
        HttpHeaders.locationHeader,
        'http://127.0.0.1:${portal.port}/gportal/web/login'
        '?wlanuserip=10.5.5.5&wlanacname=GiWiFi_test',
      );
      await req.response.close();
    });

    // baseUrl 故意指向一个没人监听的端口：发现生效则全程不会碰它
    final auth = AuthService(
      baseUrl: 'http://127.0.0.1:9',
      probeUrl: 'http://127.0.0.1:${probe.port}/generate_204',
      discover: true,
      fastRetryDelay: const Duration(milliseconds: 50),
    );
    final result = await auth.login(
      username: 'test2024',
      password: 'TestPass123@',
      userAgent: 'TestUA',
    );
    await portal.close(force: true);
    await probe.close(force: true);

    expect(result.success, isTrue, reason: result.message);
    expect(loginGets, greaterThanOrEqualTo(1));
    // 首个请求应带发现到的真实参数（浏览器落地页同款 URL）
    expect(loginQuery, contains('wlanuserip=10.5.5.5'));
    expect(loginQuery, contains('wlanacname=GiWiFi_test'));
    expect(auth.effectiveBaseUrl, portalBase);
  });

  test('在线时探测点返回 204：不改变原配置', () async {
    final portal = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var authenticated = false;

    portal.listen((req) async {
      final path = req.uri.path;
      try {
        if (path == '/gportal/web/login') {
          req.response.headers.contentType = ContentType.html;
          req.response.write(_formPage());
        } else if (path == '/gportal/Web/loginAction') {
          authenticated = true;
          req.response.write(
            jsonEncode(<String, dynamic>{
              'status': 1,
              'info': '认证成功',
              'data': <String, dynamic>{},
            }),
          );
        } else if (path == '/gportal/web/logout') {
          final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (!authenticated) {
            req.response.write('<html>offline</html>');
          } else {
            req.response.write(
              '<html><input type="hidden" name="si" value="sess1">'
              'var start = "$start"; online_duration</html>',
            );
          }
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      } catch (_) {
        await req.response.close();
      }
    });

    probe.listen((req) async {
      req.response.statusCode = 204;
      await req.response.close();
    });

    final base = 'http://127.0.0.1:${portal.port}';
    final auth = AuthService(
      baseUrl: base,
      probeUrl: 'http://127.0.0.1:${probe.port}/generate_204',
      discover: true,
      fastRetryDelay: const Duration(milliseconds: 50),
    );
    final result = await auth.login(
      username: 'test2024',
      password: 'TestPass123@',
      userAgent: 'TestUA',
    );
    await portal.close(force: true);
    await probe.close(force: true);

    expect(result.success, isTrue, reason: result.message);
    expect(auth.effectiveBaseUrl, base);
  });

  test('快速重试：首次连接被重置后自动重发一次', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var loginGets = 0;
    var authenticated = false;

    server.listen((req) async {
      final path = req.uri.path;
      try {
        if (path == '/gportal/web/login') {
          loginGets++;
          if (loginGets == 1) {
            // 直接掐断连接，制造瞬时网络故障
            final socket = await req.response.detachSocket();
            socket.destroy();
            return;
          }
          req.response.headers.contentType = ContentType.html;
          req.response.write(_formPage());
        } else if (path == '/gportal/Web/loginAction') {
          authenticated = true;
          req.response.write(
            jsonEncode(<String, dynamic>{
              'status': 1,
              'info': '认证成功',
              'data': <String, dynamic>{},
            }),
          );
        } else if (path == '/gportal/web/logout') {
          final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (!authenticated) {
            req.response.write('<html>offline</html>');
          } else {
            req.response.write(
              '<html><input type="hidden" name="si" value="sess1">'
              'var start = "$start"; online_duration</html>',
            );
          }
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      } catch (_) {
        await req.response.close();
      }
    });

    final auth = AuthService(
      baseUrl: 'http://127.0.0.1:${server.port}',
      fastRetryDelay: const Duration(milliseconds: 50),
    );
    final result = await auth.login(
      username: 'test2024',
      password: 'TestPass123@',
      userAgent: 'TestUA',
    );
    await server.close(force: true);

    expect(result.success, isTrue, reason: result.message);
    expect(loginGets, greaterThanOrEqualTo(2), reason: '应自动重发了被掐断的请求');
  });
}
