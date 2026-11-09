import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giwifi_ua_switcher/main.dart';
import 'package:giwifi_ua_switcher/services/settings_service.dart';

void main() {
  testWidgets('主界面渲染冒烟测试', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('giwifi_widget_test');
    SettingsService.configDirOverride = tmp.path;
    addTearDown(() {
      SettingsService.configDirOverride = null;
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    await tester.pumpWidget(const GiWiFiApp());
    await tester.pumpAndSettle();

    expect(find.text('GiWiFi 一键认证'), findsOneWidget);
    expect(find.text('一键认证'), findsOneWidget);
    expect(find.text('检查状态'), findsOneWidget);
    expect(find.text('记住账号密码'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);

    // 五种设备预设全部渲染（安卓平板预设已移除）
    for (final label in ['电脑', '安卓手机', 'iPhone', 'iPad', '自定义']) {
      expect(find.text(label), findsOneWidget, reason: '缺少设备选项：$label');
    }
    expect(find.text('安卓平板'), findsNothing);
  });

  testWidgets('在线检测：无网络时给出友好提示', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('giwifi_widget_test2');
    SettingsService.configDirOverride = tmp.path;
    addTearDown(() {
      SettingsService.configDirOverride = null;
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    await tester.pumpWidget(const GiWiFiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('检查状态'));
    await tester.pumpAndSettle();

    expect(find.text('状态未知（可能不在校园网）'), findsOneWidget);
  });

  testWidgets('报修热线：弹出运维信息对话框', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('giwifi_widget_test3');
    SettingsService.configDirOverride = tmp.path;
    addTearDown(() {
      SettingsService.configDirOverride = null;
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    await tester.pumpWidget(const GiWiFiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('报修热线'));
    await tester.pumpAndSettle();

    expect(find.text('报修与咨询'), findsOneWidget);
    expect(find.textContaining('18312680661'), findsOneWidget);
    expect(find.textContaining('尚雅 C 对面'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('报修与咨询'), findsNothing);
  });

  testWidgets('WiFi 充值：拉起系统浏览器并带上 AC 名参数', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('giwifi_widget_test4');
    SettingsService.configDirOverride = tmp.path;
    addTearDown(() {
      SettingsService.configDirOverride = null;
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    // url_launcher 平台通道打桩（6.3.x 实际走 legacy launch 方法），
    // 记录传入的 URL
    Object? launchedUrl;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') {
        launchedUrl = (call.arguments as Map<Object?, Object?>)['url'];
        return true;
      }
      return null;
    });
    addTearDown(() {
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(const GiWiFiApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('WiFi 充值'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WiFi 充值'));
    await tester.pumpAndSettle();

    expect(
      launchedUrl,
      'http://lnsfv2.pc.gwifi.com.cn/Gishop/index.php/pay/prevcharge'
      '?wa=GiWiFi_lnsfHG',
      reason: '未发现本机 IP 时只带 AC 名参数',
    );
  });
}
