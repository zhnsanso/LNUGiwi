# Changelog

本项目的显著变更记录。遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 提交规范，发布时手动汇总至此。

## Unreleased

- **feat**: 门户动态发现——登录前探测 AC 劫持重定向（`connect.rom.miui.com/generate_204`），从 302 Location 解析真实的门户地址 / `wlanacname` / `wlanuserip` 并在运行时覆盖配置（学习官方客户端的发现机制）；在线或无劫持时保持原配置，任何探测失败静默跳过
- **feat**: 在线检测劫持探测优先（`checkOnline`）——被劫持重定向即**确定掉线**（仅校园 AC 未认证时会发生，已在真实环境验证），顺带刷新门户参数；探测正常应答不能区分校园在线/家庭宽带，仍回落 logout 页 si 嗅探确认；探测不可达同样回落。60 秒自动重连由此获得即时且不依赖页面模板的掉线判定
- **feat**: 单请求快速重试——网络类异常（连接失败 / 超时 / 中断）先以 1.2 秒间隔自动重发一次再上抛，弱 WiFi 下不必进入上层 6 秒冷却的整轮重试
- **feat**: WiFi 充值入口——页脚新增"WiFi 充值"按钮，拉起系统浏览器打开门户自带充值页（`lnsfv2.pc.gwifi.com.cn/Gishop`），参数用动态发现的 AC 名 / 本机 IP 拼装；为此重新引入 `url_launcher`（Flutter 官方插件）
- **feat**: 在线时长常驻显示——状态胶囊第二行实时显示"已在线 HH:MM:SS"，登录成功 / 手动检测 / 60 秒自动重连 tick 均会刷新
- **feat**: 报修热线——页脚新增"报修热线"按钮，弹窗展示公众网服务热线与营业厅地址
- **test**: `test/portal_discovery_test.dart`：重定向解析单测 + 302 劫持切换门户 / 在线不干扰 / 连接重置自愈 / checkOnline 三分支共 9 个测试
- **test**: widget 测试新增报修弹窗与充值拉起（平台通道打桩）；goldens 随页脚操作行重新生成

## v2.0.2 (2026-11-08)

重构完成后的首个正式发布：单一 Flutter 实现 + FlClash 式工程体系 + 设计令牌。发布产物见 GitHub Release（Android APK / macOS dmg+zip / Windows zip，附 SHA256SUMS）。

### 风格设计（学习 prism_ui）

- **ui**: 设计令牌层——`lib/ui/shape.dart`（`AppRadius`/`AppShape`，全超椭圆圆角）与 `lib/ui/typography.dart`（`AppTextStyle` 字号阶梯）
- **ui**: 全面替换为超椭圆圆角（`RoundedSuperellipseBorder` / `ClipRSuperellipse`，胶囊亦为超椭圆全半径）
- **ui**: 移除应用内源码仓库链接入口（`kRepoUrl` 与右上角按钮），去掉 `url_launcher` 依赖
- **test**: `test/lint/style_tokens_test.dart` 固化令牌规则（令牌层外禁裸 `fontSize`/`FontWeight`/圆角 API）
- **test**: goldens 随 UI 变更重新生成

## v2.0.1 (2026-11-08)

### 工程规范（学习 FlClash 工程体系）

- **lint**: 新增 `lint_options.yaml`（flutter_lints + 扩展规则：单引号、尾逗号、`child:` 最后、const/final 偏好、`always_declare_return_types` 等）
- **ci**: 新增 `check` workflow——每次推送跑 `dart format` 检查 + `flutter analyze --fatal-infos` + `flutter test`
- **ci**: actions 升级到 Node 24 版本（checkout@v5、upload/download-artifact@v6），runner 钉住 `ubuntu-24.04`
- **refactor**: `lib/` 分层——`utils/` → `common/`，`theme.dart` → `ui/theme.dart`
- **docs**: AGENTS.md 瘦身为入口 + `.agents/` 三层文档（project / commands / rules）

## v2.0.0 (2026-11-08)

### Features

- **release**: Android universal APK 加入发布产物（debug 签名）
- **release**: Windows x64 zip 加入发布产物
- **release**: Release 附 `SHA256SUMS` 校验和文件
- **release**: workflow 由 "Apple builds" 改名 "Builds" 并迁至 `builds.yml`；iOS 不再产出无签名包（不可安装，需源码自建）

### Breaking

- 移除 .NET Windows 轻量版（`windows-lite/`），回归单一 Flutter 实现。两实现读写同一 `%APPDATA%\giwifi_ua_switcher\settings.json`，已保存配置无缝沿用
