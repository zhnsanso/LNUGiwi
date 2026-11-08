# Changelog

本项目的显著变更记录。遵循 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 提交规范，发布时手动汇总至此。

## Unreleased

### Planned

- **ui**: 移除应用内源码仓库链接入口（`kRepoUrl` 与右上角仓库按钮）

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
