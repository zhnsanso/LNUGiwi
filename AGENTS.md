# AGENTS.md

GiWiFi campus-network auth tool for 岭南师范学院 (Lingnan Normal University). UI strings, docs, and comments are in Chinese — keep new user-facing text and README content in Chinese.

## Start Here

Read before making changes:

- [.agents/project.md](.agents/project.md): versions, implementation history, crypto sync points, storage.
- [.agents/commands.md](.agents/commands.md): build, analyze, test, golden, tooling commands.
- [.agents/rules.md](.agents/rules.md): lint, commit, testing, and release rules.

## Highest Priority Rules

- Single Flutter implementation since v2.0.0 — do not reintroduce a C#/.NET copy; extend the Dart code.
- Crypto/form logic lives in two places that must stay in sync: `lib/common/aes_crypto.dart` and `tool/gen_test_vectors.py` (vectors baked into tests and selfcheck). Change one, update both, regenerate vectors.
- Widget tests must set `SettingsService.configDirOverride` to a temp dir, or they hit the real `%APPDATA%\giwifi_ua_switcher` on Windows.
- Run `flutter analyze --fatal-infos` and `flutter test` before pushing — the `check` workflow runs the same gates on every push and fails on any info.
- Release order: bump `pubspec.yaml` → update CHANGELOG → commit → lightweight tag → push tag **by name** (`--follow-tags` skips lightweight tags silently).
- Credentials are stored in plaintext by design; never commit real accounts, passwords, or captured portal data.
