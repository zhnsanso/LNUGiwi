# Rules

## 代码风格

- 规则集在根目录 `lint_options.yaml`，`analysis_options.yaml` include 它；增删规则改 `lint_options.yaml`，不要在别处另设。
- 核心强制项：单引号、多行参数尾逗号、`child:` 最后、禁 `print()`、const/final 偏好、`always_declare_return_types`、`only_throw_errors`、`unawaited_futures`。
- `flutter analyze --fatal-infos` 必须零通过才算干净（与 check CI 一致）。
- 注释只写代码说不出的东西（非显然约束、绕过的上游行为、易误读的原因）；不逐行复述代码、不叙述刚做的改动。顺手删除所改文件中的注释掉的代码和过期备注。

## 风格令牌（v2.0.2 起）

- 圆角一律取自 `lib/ui/shape.dart`（`AppRadius` 值 + `AppShape` 预构建形状），渲染一律超椭圆：`RoundedSuperellipseBorder` / `ClipRSuperellipse`；胶囊用 `AppShape.pill`（超椭圆全半径），不用 `StadiumBorder`。
- 字号/字重一律取自 `lib/ui/typography.dart` 的 `AppTextStyle` 阶梯；颜色等场景差异用 `copyWith` 叠加，不进阶梯。
- 令牌层（`lib/ui/` 三个文件）之外禁止裸 `fontSize:` / `FontWeight.` / `ClipRRect` / `RoundedRectangleBorder` / `StadiumBorder` / `BorderRadius.circular(`；`test/lint/style_tokens_test.dart` 扫描 `lib/` 强制执行。
- 只接受 Radius 的 API（如 `OutlineInputBorder`）无法用超椭圆：取值仍从 `AppRadius` 拿。
- goldens 在 Linux 上生成：有意的 UI 变更后必须在 Linux 工具链 `flutter test --update-goldens`，否则 ubuntu-24.04 CI 必失败（字体抗锯齿跨平台有约 1-2% 像素噪声，布局无关）。

## 提交与变更范围

- Conventional Commits：`feat:` / `fix:` / `docs:` / `refactor:` / `ci:` / `chore:`，scope 用英文小写（如 `release`、`lint`、`ui`）。
- 请求即范围：任务没要求的前置 bug、清理、重构作为总结中的后续项提出，不混入本次改动。
- 不给提交加 `Co-authored-by` 署名 credit。

## 测试

- Widget 测试必须设置 `SettingsService.configDirOverride` 指向临时目录，否则 Windows 上会读写真实 `%APPDATA%\giwifi_ua_switcher`。
- 认证流测试是纯 Dart 加密/表单固定向量测试，无网络、无 mock。
- 改 UI 后 golden 失败先判断是"有意变更"（→ `--update-goldens` + 更新字体）还是回归。

## 发版顺序

pubspec 版本与 tag 不一致会发布内部版本错位的应用（v1.1.6 踩过）：

1. 升 `pubspec.yaml` 的 `version:`（build 号日期式）
2. 更新 `CHANGELOG.md`（Unreleased → 版本号 + 日期）
3. 提交
4. `git tag vX.Y.Z`（轻量 tag）
5. **按名推送 tag**：`git push origin vX.Y.Z`。`--follow-tags` 只推附注 tag，会静默跳过轻量 tag 导致发版 workflow 不触发。

## 约束

- 不要重新引入 C# / .NET 副本实现（见 project.md 历史结构）。
- 加密、表单、填充逻辑改动必须同步 `lib/common/` 与 `tool/gen_test_vectors.py` 并重生成向量。
- 不提交真实账号、密码、Cookie、抓包数据。
