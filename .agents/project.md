# Project Context

GiWiFi 校园网认证工具（岭南师范学院），单一 Flutter 实现，支持 Android / macOS / Windows（iOS 可源码自建）。UI、文档、注释为中文。

## 版本

- 版本号在 `pubspec.yaml`，格式 `X.Y.Z+日期NNN`（如 `2.0.0+2026110801`），build 号为日期式。
- 发版 tag `vX.Y.Z` 必须与 pubspec 版本一致；tag 为轻量 tag，需按名推送（见 rules.md）。
- CI 使用 `channel: stable`（未钉版本）；本地工具链应使用最新 stable，避免 `dart format` 输出与 CI 漂移。

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
