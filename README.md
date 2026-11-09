# GiWiFi 岭南师范学院校园网认证工具

面向岭南师范学院校园网的第三方开源认证工具。项目基于 [Yanmo552/giwifi-ua-switcher](https://github.com/Yanmo552/giwifi-ua-switcher) 的开源实现进行适配与扩展，重点补充了湖光校区门户所需的 `wlanacname`（AC 名称）参数。

> 本项目与学校、校园网运营方及上游项目作者没有隶属或官方合作关系。湖光校区适配根据实际门户响应进行验证；其他校区和网络环境请自行测试。

## 下载与安装

从 [GitHub Releases](https://github.com/zhnsanso/LNUGiwi/releases) 页面获取各平台安装包（推送 `v*` 标签后由 Actions 自动构建，附 `SHA256SUMS` 校验和）：

| 平台 | 产物 | 说明 |
| --- | --- | --- |
| Android | `GiWiFi-Android.apk` | 通用包，下载即装；正式签名（自 v2.1.1 起；v2.1.0 及更早为 debug 签名，跨签名升级需先卸载旧版） |
| Windows x64 | `GiWiFi-Windows-x64.zip` | 解压后运行 `giwifi_ua_switcher.exe` |
| macOS（Intel + Apple Silicon） | `GiWiFi-macOS-universal.dmg` | 通用二进制，打开后拖入 Applications 即完成安装 |

macOS 版发布包为同时支持 Intel 和 Apple Silicon 的 universal binary，由 GitHub Actions 的 `Builds` 工作流构建。

目前未配置 Apple Developer 签名与公证，因此首次打开时，macOS 可能需要在“系统设置 → 隐私与安全性”中手动允许打开。

## 从源码构建

单一 Flutter 代码库，支持 Android / iOS / macOS / Windows。安装 [Flutter SDK](https://docs.flutter.dev/get-started/install) 及对应平台工具链后：

```bash
flutter pub get
flutter run
```

发布构建：

```bash
flutter build apk --release        # Android
flutter build windows --release    # Windows，产物在 build/windows/x64/runner/Release/
flutter build macos --release
```

> 发布通道只覆盖 Android / macOS / Windows；iOS 因无签名证书不提供安装包，可自行从源码构建。

> 自 v2.0.0 起项目回归单一 Flutter 实现，早期的 .NET Windows 轻量版（`windows-lite/`）已移除，可从 git 历史找回。此前使用轻量版的用户：Flutter 版读取同一个配置文件 `%APPDATA%\giwifi_ua_switcher\settings.json`，已保存的账号密码与设置会自动沿用，无需重新填写。

## 湖光校区设置

连接需要认证的校园 Wi-Fi 后，打开应用并填写自己的校园网上网账号和密码。认证服务器默认 `http://100.100.9.2`、AC 名称默认 `GiWiFi_lnsfHG`，两者都只是**兜底值**：

- **门户动态发现**：未认证状态下，应用会向小米的 204 探测地址发起一次连通性请求；校园网 AC 会把该请求 302 劫持到门户登录页（携带真实的 `wlanuserip` / `wlanacname`），应用据此在运行时自动覆盖门户地址与 AC 名称。学校调整门户配置时通常无需手动改设置。
- 在线或无劫持时保持界面配置不变；其他校区可在界面中手动填写该校区实际使用的值。

程序会请求类似下面的登录地址，并解析门户返回的隐藏字段：

```text
http://100.100.9.2/gportal/web/login?wlanacname=GiWiFi_lnsfHG
```

登录页没有返回密码框时，程序会提示检查校园 Wi-Fi 连接、认证服务器和 AC 名称；不能仅凭此提示判断账号密码是否正确。

## 功能

- 选择电脑、安卓手机、iPhone、iPad 等用户代理（User-Agent），或填写自定义 UA。
- 一键获取门户登录表单并提交认证。
- 门户地址 / AC 名称 / 本机 IP 动态发现（探测 AC 劫持重定向），学校调整门户配置无需改设置。
- 在线检测优先走劫持探测：被劫持即确定掉线（即时、不依赖页面模板），探测不可达时回落 logout 页嗅探。
- 单请求网络异常自动快速重试一次，弱 Wi-Fi 下更稳。
- 状态栏常驻显示在线时长（登录、手动检测、自动重连时刷新）。
- 遇到门户要求更换绑定设备时，确认后自动提交换绑并等待冷却，再重试认证。
- 已在线时可确认先下线再切换设备类型；可选开启每 60 秒掉线检查和自动重连。
- 页脚一键打开门户自带的 WiFi 充值页面（参数自动带上 AC 名与本机 IP）。
- 报修热线与营业厅地址随手可查。
- 查看最近认证记录并清空日志；可选在本机记住账号密码。

## 数据与安全

- 工具不会将账号、密码或认证日志上传到本项目维护者的服务器；认证请求发送到界面配置的校园网认证服务器。
- 在线检测与门户发现会向小米的公共 204 探测地址（`connect.rom.miui.com/generate_204`）发起一次**不含任何个人数据**的连通性请求；若被校园网 AC 劫持重定向，仅解析重定向地址中的门户参数。
- 勾选“记住账号密码”时，会将凭据以**未加密明文**保存到本机配置文件（Windows 为 `%APPDATA%\giwifi_ua_switcher\settings.json`，其他平台为应用支持目录）。仅在个人设备上使用；取消勾选可关闭保存。请勿分享该配置文件或包含个人凭据的日志。
- 本工具只应用于你获准使用的校园网账号，并遵守学校及网络运营方的规定。设备类型选择和认证行为可能受套餐、门户策略或校区配置限制。
- 发现本次对话或测试中曾暴露的密码时，请及时更换，不要将真实账号密码写进 issue、截图或源码。

## 来源与许可

- 上游项目：[Yanmo552/giwifi-ua-switcher](https://github.com/Yanmo552/giwifi-ua-switcher)。感谢原作者提供 Flutter 版本及认证流程实现。本项目保留上游 `LICENSE` 文件中的 MIT 许可与版权声明。
- 本仓库的修改以仓库中的 MIT License 文件为准；继续分发时请保留许可和版权声明。
- GiWiFi、岭南师范学院及相关网络标识归其各自权利人所有。本项目不代表学校官方软件。

## 反馈

请提交 issue 时注明操作系统、所在校区、门户登录 URL 中的 AC 名称、应用版本和脱敏后的错误信息。**不要提交账号、密码、Cookie、认证令牌或完整的个人网络信息。**
