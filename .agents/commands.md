# Commands

## 日常开发

```bash
flutter pub get
flutter analyze --fatal-infos      # 本地与 check CI 同强度
flutter test                       # 全部测试
flutter test test/aes_crypto_test.dart   # 单文件
dart run tool/selfcheck.dart       # 独立自检，无需额外包
```

推送前必跑 `flutter analyze` 与 `flutter test`——`check` workflow 对每次推送执行同样的检查（format / analyze / test），红了会被直接看见。

## 格式化

```bash
dart format lib test tool          # CI 用 --set-exit-if-changed 校验
```

## 金色截图（goldens）

`test/screenshot_test.dart` 使用 `test/fonts/` 下的子集字体渲染（`make_test_fonts.py` 生成，依赖 fonttools，下载 Noto Sans SC，按 `lib/` 实际字符/图标子集化）。新增 UI 字符串或图标需重新生成字体（图标 `--icons-only`），否则 golden 渲染为回退字形。

```bash
flutter test --update-goldens      # 仅在有意的 UI 变更后
python tool/make_test_fonts.py     # 需 pip install fonttools
```

注意：golden 更新与字体再生成必须在有 Flutter 工具链的环境执行；test/fonts 与 goldens 均提交进仓库。

## tool/ 脚本（Python，仅开发用）

Python 工具一律优先用 [uv](https://docs.astral.sh/uv/)：

```bash
uv venv && uv pip install pillow fonttools pycryptodome   # 一次性准备
uv run --python .venv python tool/make_app_icons.py       # 运行示例
```

- `make_app_icons.py`（pillow）——从单一母版重新生成全部平台应用图标。
- `make_test_fonts.py`（fonttools）——见上。
- `gen_test_vectors.py`（pycryptodome）——重新生成 AES 测试向量。

## 发布

见 rules.md 的发版顺序。构建产物由 `Builds` workflow 生成（Android universal APK / Windows x64 zip / macOS universal dmg+zip，附 SHA256SUMS），手动 dispatch 或推 `v*` tag 触发。
