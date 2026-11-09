# Project Context

GiWiFi 校园网认证工具（岭南师范学院），单一 Flutter 实现，支持 Android / macOS / Windows（iOS 可源码自建）。UI、文档、注释为中文。

## 仓库可见性

- 仓库当前为 **private**：Release 资产仅登录且有权限的账号可下载。若要让学生用户下载安装包，需所有者将仓库转为 public（网页 Settings → Danger Zone，或 `gh repo edit zhnsanso/LNUGiwi --visibility public --accept-visibility-change-consequences`）。**2026-11-09 决定：v2.1.0 后处于观察期，暂不转公开**——在此之前不要主动重提可见性变更。
- 发版管线已两次实战全绿：v2.0.2（2026-11-08）首跑、v2.1.0（2026-11-09）复跑——三平台构建 + release job（产物合并、APK 重命名、SHA256SUMS、GitHub Release）稳定可用。

## 版本

- 版本号在 `pubspec.yaml`，格式 `X.Y.Z+日期NNN`（如 `2.0.0+2026110801`），build 号为日期式。
- 发版 tag `vX.Y.Z` 必须与 pubspec 版本一致；tag 为轻量 tag，需按名推送（见 rules.md）。
- CI 使用 `channel: stable`（未钉版本）；本地工具链应使用最新 stable，避免 `dart format` 输出与 CI 漂移。
- 当前版本 **v2.1.0+2026110901**（2026-11-09）：动态发现 / 劫持探测在线检测 / 快速重试 / 充值入口 / 在线时长常驻 / 报修热线。

## 门户协议与官方客户端情报（v2.1.0 认证重构的依据）

用 REA（jadx-headless-mcp）逆向官方安卓客户端 `com.gbcom.gwifi.school` 2.4.1.21 + 真实环境实测得出，改动认证链路前先读这里：

- **劫持探测是核心机制**：未认证时任意 HTTP 请求被 AC 302 到 `gportal/web/login?wlanuserip=<真IP>&wlanacname=<真AC名>`（真实环境已验证）。`AuthService` 用小米 204 探测点（`kPortalProbeUrl`）做两件事：登录前动态发现门户参数；`checkOnline` 判掉线（被劫持=确定掉线，探测 204 不能证明在校园网——家庭宽带同样 204，必须回落 logout 页 si 嗅探）。
- **本部署无 wifidog**：网关 `10.13.0.1:8060` 无响应（官方客户端云模式的 `wifidog/get_auth_state` 在湖光校区不可用，别再试）；官方在 gportal 模式（authMethod=2）也不走它。
- 官方 App API（`/gportal/app/*`、AES-ECB key `5447c08b53e8dac4`、云端 `login.gwifi.com.cn`）是私有协议，本项目**不采用**；网页协议（AES-CBC ZeroPadding）与浏览器同源，更稳。
- 充值入口是门户自带的 `lnsfv2.pc.gwifi.com.cn/Gishop/index.php/pay/prevcharge?wa=<AC名>&ip=<IP>`，页脚按钮按动态发现的参数拼装。
- 门户页含运维信息：热线 18312680661（短号 666111）、营业厅尚雅 C 对面（已进报修弹窗）。

## Android 正式签名（v2.1.1 起）

- 密钥库在仓库外 `/root/giwifi-signing/`（jks + 密码 + base64 备份 + 备份说明）；别名 `giwifi-release`，RSA-2048，有效期 30 年，SHA-256 指纹 `F3:A7:85:88:EA:C6:46:D1:43:93:44:09:84:61:C6:CF:2C:AB:72:A5:1D:E1:A0:D3:26:33:60:D9:F9:5C:97:28`。
- GitHub Secrets：`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`；builds.yml 构建前解码 jks 并生成 `android/key.properties`（gitignored），未配置时回退 debug 签名。
- `android/app/build.gradle.kts` 按 key.properties 是否存在选择 release/debug 签名——本地 `flutter run --release` 依然可用。
- **密钥丢失 = 永久失去更新已安装用户的能力**；备份目录务必保存到密码管理器/私有云。换签名 = 所有用户必须卸载重装（跨签名覆盖安装被 Android 拒绝）。
- 验签方法：`keytool -printcert -jarfile GiWiFi-Android.apk`，比对上面指纹。

## 历史结构（勿回退）

- v2.0.0 起为单一 Flutter 实现；此前的 .NET Windows 轻量版（`windows-lite/`）已移除，可从 git 历史找回。不要重新引入 C# 副本，扩展 Dart 实现。
- 两实现曾共用 `%APPDATA%\giwifi_ua_switcher\settings.json`，这是配置无缝迁移的原因。

## 加密/认证实现的两处同步点

- `lib/common/aes_crypto.dart`——手写 AES-128-CBC，无第三方加密包。不要换依赖而不同步测试向量。
- `tool/gen_test_vectors.py`（pycryptodome）——参考实现，生成 `tool/vectors.json`；其输出固化在 `test/auth_flow_test.dart`、`test/aes_crypto_test.dart`、`tool/selfcheck.dart` 的期望密文中。

改动表单构建、填充或加密时必须同步另一处并重新生成测试向量，否则对拍测试失败。

加密细节：CryptoJS 兼容的 ZeroPadding（明文已 16 字节对齐时不追加填充块）；密钥为硬编码常量 `kGiWifiAesKey` = `1234567887654321`；IV 来自门户页隐藏字段 `iv`。

## 存储

- Windows：`%APPDATA%\giwifi_ua_switcher`；其他平台：path_provider 支持目录。
- 勾选"记住账号密码"时凭据**明文**保存。绝不提交真实账号、密码或抓包数据。
