import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/device_profile.dart';
import '../services/auth_service.dart';
import 'webui_page.dart';

/// Linux headless WebUI 服务：浏览器表单直接驱动 [AuthService]。
///
/// 完全无状态：每个请求新建一个认证客户端，不保存凭据、不写配置。
/// 登录流程中的换绑 / 已在线切换仍保持“人工确认”语义——服务端只在
/// 请求显式携带 confirm_rebind / confirm_switch 时才回调 true。
class HeadlessServer {
  HeadlessServer({
    this.host = '0.0.0.0',
    this.port = 8712,
    this.token = '',
    this.serverUrl = 'http://100.100.9.2',
    this.acName = 'GiWiFi_lnsfHG',
    AuthService Function()? authFactory,
  }) : _authFactory = authFactory ??
            (() => AuthService(
                  baseUrl: serverUrl,
                  wlanAcName: acName,
                  discover: true,
                ));

  final String host;
  final int port;

  /// 非空时所有请求都必须携带令牌（查询参数 token / Bearer / X-Auth-Token）。
  final String token;

  final String serverUrl;
  final String acName;
  final AuthService Function() _authFactory;

  HttpServer? _server;

  /// 实际监听端口（`port` 传 0 时由系统分配，测试用）。
  int get boundPort => _server?.port ?? port;

  bool get isRunning => _server != null;

  Future<void> start() async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    server.listen((request) {
      unawaited(_handleGuarded(request));
    });
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  // ================= 路由 =================

  Future<void> _handleGuarded(HttpRequest request) async {
    try {
      await _route(request);
    } on _HttpError catch (e) {
      await _sendJson(request.response, e.status, <String, dynamic>{
        'error': e.message,
      });
    } catch (e) {
      stderr.writeln('[giwifi] 请求处理异常：$e');
      try {
        await _sendJson(request.response, 500, <String, dynamic>{
          'error': '服务器内部错误',
        });
      } catch (_) {
        // 响应可能已开始写出，无法再补发错误
      }
    }
  }

  Future<void> _route(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/favicon.ico') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (!_authorized(request)) {
      await _sendText(
        request.response,
        HttpStatus.unauthorized,
        '需要访问令牌：请在 URL 后附加 ?token=你的令牌',
      );
      return;
    }

    switch ((request.method, path)) {
      case ('GET', '/'):
        await _sendHtml(request.response, kHeadlessWebUiHtml);
      case ('GET', '/api/profiles'):
        await _handleProfiles(request.response);
      case ('GET', '/api/status'):
        await _handleStatus(request);
      case ('POST', '/api/login'):
        await _handleLogin(request);
      case ('POST', '/api/logout'):
        await _handleLogout(request);
      default:
        final known = <String>{
          '/',
          '/api/profiles',
          '/api/status',
          '/api/login',
          '/api/logout',
        };
        if (known.contains(path)) {
          await _sendJson(request.response, HttpStatus.methodNotAllowed, {
            'error': '不支持的请求方法',
          });
        } else {
          await _sendJson(request.response, HttpStatus.notFound, {
            'error': '未找到该接口',
          });
        }
    }
  }

  bool _authorized(HttpRequest request) {
    if (token.isEmpty) return true;
    if (request.uri.queryParameters['token'] == token) return true;
    if (request.headers.value(HttpHeaders.authorizationHeader) ==
        'Bearer $token') {
      return true;
    }
    return request.headers.value('X-Auth-Token') == token;
  }

  // ================= 接口实现 =================

  Future<void> _handleProfiles(HttpResponse response) async {
    await _sendJson(response, HttpStatus.ok, <String, dynamic>{
      'profiles': <Map<String, String>>[
        for (final profile in DeviceProfile.presets)
          <String, String>{'id': profile.id, 'label': profile.label},
      ],
      'defaultSlot': 'pc',
    });
  }

  /// 在线状态：开启动态发现，先做劫持探测再嗅探 logout 页。
  Future<void> _handleStatus(HttpRequest request) async {
    final profile = _resolveProfile(
      request.uri.queryParameters['slot'],
      request.uri.queryParameters['custom_ua'],
    );
    if (profile == null) {
      throw const _HttpError(HttpStatus.badRequest, '自定义槽位需要填写 UA');
    }

    final auth = _authFactory();
    final status = await auth.checkOnline(profile.userAgent);
    String? duration;
    if (status == OnlineStatus.online) {
      duration = await auth.fetchOnlineDuration(profile.userAgent);
    }
    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'status': status.name,
      'duration': duration,
      'portal': _portalOf(auth),
    });
  }

  Future<void> _handleLogin(HttpRequest request) async {
    final body = await _readJsonObject(request);
    final username = (body['username'] as String? ?? '').trim();
    final password = body['password'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) {
      throw const _HttpError(HttpStatus.badRequest, '请填写账号和密码');
    }
    final profile = _resolveProfile(
      body['slot'] as String?,
      body['custom_ua'] as String?,
    );
    if (profile == null) {
      throw const _HttpError(HttpStatus.badRequest, '自定义槽位需要填写 UA');
    }
    final confirmRebind = body['confirm_rebind'] == true;
    final confirmSwitch = body['confirm_switch'] == true;

    final auth = _authFactory();
    String? rebindInfo;
    var switchRequested = false;

    LoginResult result;
    try {
      result = await auth.login(
        username: username,
        password: password,
        userAgent: profile.userAgent,
        onRebindConfirm: (info) async {
          rebindInfo = info;
          return confirmRebind;
        },
        onSwitchConfirm: () async {
          switchRequested = true;
          return confirmSwitch;
        },
      );
    } catch (e) {
      await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
        'success': false,
        'message': _friendlyError(e),
        'needsRebind': false,
        'rebindInfo': null,
        'alreadyOnline': false,
        'onlineDuration': null,
        'portal': _portalOf(auth),
      });
      return;
    }

    // 人工确认语义：AuthService 在回调返回 false 时只给出通用文案，
    // 这里用回调里捕获的信息还原“待确认换绑 / 待确认切换”状态。
    final pendingRebind =
        rebindInfo != null && !confirmRebind && !result.success;
    final pendingSwitch = switchRequested && !confirmSwitch && !result.success;
    final message = pendingRebind
        ? '服务器要求更换绑定设备：$rebindInfo\n确认后将自动提交换绑并重新认证。'
        : pendingSwitch
            ? '当前设备已在线，确认后将先注销再重新认证（会校验账号密码）。'
            : result.message;

    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'success': result.success,
      'message': message,
      'needsRebind': pendingRebind,
      'rebindInfo': rebindInfo,
      'alreadyOnline': pendingSwitch,
      'onlineDuration': result.onlineDuration,
      'portal': _portalOf(auth),
    });
  }

  Future<void> _handleLogout(HttpRequest request) async {
    final body = await _readJsonObject(request);
    final profile = _resolveProfile(
      body['slot'] as String?,
      body['custom_ua'] as String?,
    );
    if (profile == null) {
      throw const _HttpError(HttpStatus.badRequest, '自定义槽位需要填写 UA');
    }
    final auth = _authFactory();
    final success = await auth.logout(profile.userAgent);
    await _sendJson(request.response, HttpStatus.ok, <String, dynamic>{
      'success': success,
      'message': success ? '已注销当前在线设备' : '注销失败：当前可能未在线，或门户未确认下线',
    });
  }

  // ================= 工具 =================

  DeviceProfile? _resolveProfile(String? slot, String? customUa) {
    final id = (slot ?? 'pc').trim();
    if (id.isEmpty) return DeviceProfile.byId('pc');
    final profile = DeviceProfile.byId(id);
    if (profile.id != 'custom') return profile;
    final ua = (customUa ?? '').trim();
    if (ua.isEmpty) return null;
    return DeviceProfile(id: 'custom', label: '自定义', userAgent: ua);
  }

  Map<String, dynamic> _portalOf(AuthService auth) => <String, dynamic>{
        'baseUrl': auth.effectiveBaseUrl,
        'acName': auth.effectiveAcName,
        'clientIp': auth.effectiveClientIp,
      };

  String _friendlyError(Object error) {
    if (error is SocketException) {
      return '无法连接认证服务器，请确认设备已连接校园网';
    }
    if (error is TimeoutException) {
      return '连接认证服务器超时，请稍后重试';
    }
    return '请求异常：$error';
  }

  Future<Map<String, dynamic>> _readJsonObject(HttpRequest request) async {
    const maxBytes = 64 * 1024;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const _HttpError(
          HttpStatus.requestEntityTooLarge,
          '请求体过大',
        );
      }
    }
    final text = utf8.decode(builder.takeBytes(), allowMalformed: true).trim();
    if (text.isEmpty) return <String, dynamic>{};
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const _HttpError(HttpStatus.badRequest, '请求体不是有效的 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const _HttpError(HttpStatus.badRequest, '请求体必须是 JSON 对象');
    }
    return decoded;
  }

  Future<void> _sendJson(
    HttpResponse response,
    int status,
    Map<String, dynamic> payload,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(jsonEncode(payload));
    await response.close();
  }

  Future<void> _sendHtml(HttpResponse response, String html) async {
    response.headers.contentType = ContentType.html;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(html);
    await response.close();
  }

  Future<void> _sendText(
    HttpResponse response,
    int status,
    String text,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType(
      'text',
      'plain',
      charset: 'utf-8',
    );
    response.write(text);
    await response.close();
  }
}

class _HttpError implements Exception {
  const _HttpError(this.status, this.message);

  final int status;
  final String message;
}
