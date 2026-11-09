import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/check_backoff.dart';
import '../models/device_profile.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../ui/shape.dart';
import '../ui/typography.dart';
import '../widgets/auth_log_card.dart';
import '../widgets/device_tile.dart';
import '../widgets/footer_actions.dart';
import '../widgets/home_header.dart';
import '../widgets/primary_auth_button.dart';
import '../widgets/result_banner.dart';
import '../widgets/section_title.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _serverCtrl = TextEditingController(
    text: 'http://100.100.9.2',
  );
  final TextEditingController _acNameCtrl = TextEditingController(
    text: 'GiWiFi_lnsfHG',
  );
  final TextEditingController _customUaCtrl = TextEditingController();

  String _profileId = 'pc';
  bool _remember = true;
  bool _obscurePassword = true;
  bool _busy = false;
  bool _checking = false;
  bool _keepAlive = false;

  String? _resultMessage;
  bool _resultSuccess = false;
  OnlineStatus? _status;

  /// 常驻显示的在线时长（HH:MM:SS），离线/未知时为 null。
  String? _onlineDuration;

  /// 自动重连检测的自适应间隔状态。
  final CheckBackoff _backoff = CheckBackoff();

  /// 动态发现到的本机 IP（充值链接参数；可能为 null）。
  String? _lastClientIp;

  List<LogEntry> _log = <LogEntry>[];
  Timer? _keepAliveTimer;
  AuthService? _activeAuth;

  AuthService get _auth => AuthService(
        baseUrl: _serverCtrl.text.trim(),
        wlanAcName: _acNameCtrl.text.trim(),
        discover: true,
      );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _activeAuth?.cancel();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    _acNameCtrl.dispose();
    _customUaCtrl.dispose();
    super.dispose();
  }

  DeviceProfile get _selectedProfile {
    if (_profileId == 'custom') {
      return DeviceProfile(
        id: 'custom',
        label: '自定义',
        userAgent: _customUaCtrl.text.trim(),
      );
    }
    return DeviceProfile.byId(_profileId);
  }

  // ================= 数据 =================

  Future<void> _loadSettings() async {
    final s = await SettingsService.loadLoginInfo();
    if (!mounted) return;
    setState(() {
      _usernameCtrl.text = s[SettingsService.kUsername] as String;
      _passwordCtrl.text = s[SettingsService.kPassword] as String;
      _serverCtrl.text = s[SettingsService.kServerUrl] as String;
      _acNameCtrl.text = s[SettingsService.kWlanAcName] as String;
      _profileId = s[SettingsService.kProfileId] as String;
      _customUaCtrl.text = s[SettingsService.kCustomUa] as String;
      _remember = s[SettingsService.kRemember] as bool;
    });
    final log = await SettingsService.loadLog();
    if (!mounted) return;
    setState(() => _log = log);
  }

  Future<void> _saveSettings() => SettingsService.saveLoginInfo(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        serverUrl: _serverCtrl.text.trim(),
        wlanAcName: _acNameCtrl.text.trim(),
        profileId: _profileId,
        customUa: _customUaCtrl.text.trim(),
        remember: _remember,
      );

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _appendLog(LogEntry entry) async {
    if (!mounted) return;
    setState(() => _log.insert(0, entry));
    await SettingsService.appendLog(entry);
  }

  String _friendlyError(Object e) {
    if (e is SocketException) {
      return '无法连接认证服务器，请确认已连接校园网 WiFi';
    }
    if (e is TimeoutException) {
      return '连接认证服务器超时，请稍后重试';
    }
    return '请求异常：$e';
  }

  // ================= 动作 =================

  Future<void> _doLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      _showSnack('请先填写账号和密码');
      return;
    }
    final profile = _selectedProfile;
    if (profile.userAgent.isEmpty) {
      _showSnack('请选择设备类型（自定义模式需填写 UA）');
      return;
    }

    setState(() {
      _busy = true;
      _resultMessage = null;
    });
    await _saveSettings();

    final auth = _auth;
    _activeAuth = auth;
    try {
      final result = await auth.login(
        username: username,
        password: password,
        userAgent: profile.userAgent,
        onStatus: (status) {
          if (!mounted) return;
          setState(() {
            _resultMessage = status;
            _resultSuccess = false;
          });
        },
        onRebindConfirm: _confirmRebindDialog,
        onSwitchConfirm: _confirmSwitchDialog,
      );
      if (!mounted) return;
      setState(() {
        _resultMessage = result.message;
        _resultSuccess = result.success;
        _status = result.success ? OnlineStatus.online : OnlineStatus.offline;
        _onlineDuration = result.success ? result.onlineDuration : null;
        _lastClientIp = auth.effectiveClientIp ?? _lastClientIp;
      });
      // 新会话建立后从最快档重新积累在线时长阶梯
      if (result.success) _backoff.reset();
      await _appendLog(
        LogEntry(
          time: DateTime.now(),
          device: profile.label,
          success: result.success,
          message: result.message,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is AuthCancelledException || auth.isCancelled
          ? '认证已停止'
          : _friendlyError(e);
      setState(() {
        _resultMessage = msg;
        _resultSuccess = false;
        _status = OnlineStatus.unknown;
      });
      await _appendLog(
        LogEntry(
          time: DateTime.now(),
          device: profile.label,
          success: false,
          message: msg,
        ),
      );
    } finally {
      if (identical(_activeAuth, auth)) _activeAuth = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 服务器要求更换绑定设备时弹窗确认（resultCode=124）。
  Future<bool> _confirmRebindDialog(String info) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.devices_other_rounded, color: scheme.primary),
          title: const Text('确认更换绑定设备'),
          content: Text(
            info,
            style: AppTextStyle.calloutNormal,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('确认换绑'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  /// 当前设备已在线时弹窗询问是否下线切换。
  Future<bool> _confirmSwitchDialog() async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.swap_horiz_rounded, color: scheme.primary),
          title: const Text('当前设备已在线'),
          content: const Text(
            '要继续切换设备吗？将先注销当前在线设备，'
            '再按所选设备类型重新认证（会校验账号密码）。',
            style: AppTextStyle.calloutNormal,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('下线并切换'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _cancelLogin() {
    if (!_busy) return;
    _activeAuth?.cancel();
    if (mounted) setState(() => _resultMessage = '正在停止认证…');
  }

  Future<void> _checkOnline() async {
    final profile = _selectedProfile;
    if (profile.userAgent.isEmpty) {
      _showSnack('请选择设备类型（自定义模式需填写 UA）');
      return;
    }
    setState(() => _checking = true);
    try {
      final auth = _auth;
      final status = await auth.checkOnline(profile.userAgent);
      String? duration;
      if (status == OnlineStatus.online) {
        duration = await auth.fetchOnlineDuration(profile.userAgent);
      }
      if (!mounted) return;
      const map = <OnlineStatus, String>{
        OnlineStatus.online: '当前设备已在线',
        OnlineStatus.offline: '当前设备未认证（离线）',
        OnlineStatus.unknown: '状态未知（可能不在校园网）',
      };
      setState(() {
        _resultMessage = map[status];
        _resultSuccess = status == OnlineStatus.online;
        _status = status;
        _onlineDuration = duration;
        _lastClientIp = auth.effectiveClientIp ?? _lastClientIp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultMessage = _friendlyError(e);
        _resultSuccess = false;
        _status = OnlineStatus.unknown;
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _toggleKeepAlive(bool value) {
    setState(() => _keepAlive = value);
    _keepAliveTimer?.cancel();
    if (value) {
      _backoff.reset();
      _scheduleNextCheck();
      _showSnack('已开启断线自动重连（掉线即重连，在线时逐步放缓检测）');
    }
  }

  /// 按当前自适应间隔安排下一次检测。
  void _scheduleNextCheck() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(_backoff.current, _keepAliveTick);
  }

  Future<void> _keepAliveTick() async {
    if (_busy) {
      _scheduleNextCheck();
      return;
    }
    final profile = _selectedProfile;
    if (profile.userAgent.isEmpty) {
      _scheduleNextCheck();
      return;
    }
    try {
      final auth = _auth;
      final status = await auth.checkOnline(profile.userAgent);
      if (status == OnlineStatus.online) {
        _backoff.advance();
        final duration = await auth.fetchOnlineDuration(profile.userAgent);
        if (mounted && duration != _onlineDuration) {
          setState(() => _onlineDuration = duration);
        }
        if (mounted) _scheduleNextCheck();
        return;
      }
      // 掉线 / 状态未知：回到最快档，掉线立即重连
      _backoff.reset();
      if (mounted) setState(() => _onlineDuration = null);
      if (status == OnlineStatus.offline) {
        await _doLogin();
      }
      if (mounted && _keepAlive) _scheduleNextCheck();
    } catch (_) {
      if (mounted && _keepAlive) _scheduleNextCheck();
      // 下个周期重试
    }
  }

  Future<void> _clearLog() async {
    await SettingsService.clearLog();
    if (!mounted) return;
    setState(() => _log = <LogEntry>[]);
    _showSnack('日志已清除');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _selectedProfile;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeHeader(status: _status, onlineDuration: _onlineDuration),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      _buildDeviceCard(),
                      const SizedBox(height: 16),
                      _buildAccountCard(),
                      if (profile.id == 'custom') ...[
                        const SizedBox(height: 16),
                        _buildCustomUaCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildAdvancedCard(),
                      const SizedBox(height: 20),
                      _buildActionRow(),
                      ResultBanner(ok: _resultSuccess, message: _resultMessage),
                      const SizedBox(height: 16),
                      AuthLogCard(entries: _log, onClear: _clearLog),
                      FooterActions(
                        onRecharge: _openRecharge,
                        onSupport: _showSupportInfo,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(Icons.devices_rounded, '认证设备', '决定占用哪个终端槽位'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final width = (constraints.maxWidth - spacing * 2) / 3;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final p in DeviceProfile.presets)
                      DeviceTile(
                        width: width,
                        profile: p,
                        selected: _profileId == p.id,
                        onSelect: (id) => setState(() => _profileId = id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              Icons.person_outline_rounded,
              '账号信息',
              '仅保存在本机，不会上传',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: '上网账号',
                hintText: '学号 / 手机号',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('记住账号密码', style: AppTextStyle.body),
                      const SizedBox(height: 1),
                      Text(
                        '明文保存在本机配置文件，仅建议个人设备使用',
                        style: AppTextStyle.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomUaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              Icons.code_rounded,
              '自定义 User-Agent',
              '选择“自定义”设备后生效',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customUaCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '完整 UA 字符串',
                hintText: '粘贴浏览器开发者工具中的完整 UA',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          iconColor: scheme.onSurfaceVariant,
          collapsedIconColor: scheme.onSurfaceVariant,
          title: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              const Text('高级设置', style: AppTextStyle.title),
            ],
          ),
          children: [
            TextField(
              controller: _serverCtrl,
              decoration: const InputDecoration(
                labelText: '认证服务器地址',
                hintText: 'http://100.100.9.2',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _acNameCtrl,
              decoration: const InputDecoration(
                labelText: '校园 AC 名称（wlanacname）',
                hintText: 'GiWiFi_lnsfHG',
                prefixIcon: Icon(Icons.router_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Switch(
                  value: _keepAlive,
                  onChanged: _toggleKeepAlive,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('断线自动重连', style: AppTextStyle.body),
                      const SizedBox(height: 1),
                      Text(
                        '掉线自动用当前设备类型重新认证；'
                        '在线时检测间隔逐步放缓（最长 10 分钟）',
                        style: AppTextStyle.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: PrimaryAuthButton(
            checking: _checking,
            busy: _busy,
            onPressed: _checking ? null : (_busy ? _cancelLogin : _doLogin),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 8,
          child: OutlinedButton.icon(
            onPressed: _busy || _checking ? null : _checkOnline,
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded, size: 20),
            label: Text(_checking ? '检测中…' : '检查状态'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ],
    );
  }

  /// 门户自带的充值入口（登录页"WiFi充值"同款链接），
  /// 参数用动态发现的 AC 名 / 本机 IP，未发现时退回设置值。
  String get _rechargeUrl {
    final acName = _acNameCtrl.text.trim().isNotEmpty
        ? _acNameCtrl.text.trim()
        : 'GiWiFi_lnsfHG';
    final ip = _lastClientIp;
    return 'http://lnsfv2.pc.gwifi.com.cn/Gishop/index.php/pay/prevcharge'
        '?wa=${Uri.encodeQueryComponent(acName)}'
        '${ip == null ? '' : '&ip=${Uri.encodeQueryComponent(ip)}'}';
  }

  Future<void> _openRecharge() async {
    final url = Uri.parse(_rechargeUrl);
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) _showSnack('未能打开浏览器，充值地址：$url');
    } catch (_) {
      _showSnack('未能打开浏览器，充值地址：$url');
    }
  }

  Future<void> _showSupportInfo() async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: AppShape.card,
        title: Row(
          children: [
            Icon(
              Icons.support_agent_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            const Text('报修与咨询', style: AppTextStyle.title),
          ],
        ),
        content: const Text(
          '公众网统一服务热线：18312680661（短号 666111）\n'
          '公众网营业厅：岭南师范学院尚雅 C 对面',
          style: AppTextStyle.calloutNormal,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
