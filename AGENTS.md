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
- Style tokens are mandatory: every corner comes from `lib/ui/shape.dart` (`AppShape`/`AppRadius`, superellipse only — no `ClipRRect`/`RoundedRectangleBorder`/`StadiumBorder`/`BorderRadius.circular`) and every text size/weight from `lib/ui/typography.dart` (`AppTextStyle`). `test/lint/style_tokens_test.dart` fails the build on violations elsewhere in `lib/`.
- Widget tests must set `SettingsService.configDirOverride` to a temp dir, or they hit the real `%APPDATA%\giwifi_ua_switcher` on Windows.
- Goldens were regenerated on Linux: they must be regenerated (`flutter test --update-goldens`) on a Linux toolchain after any intentional UI change, or CI (ubuntu-24.04) fails them.
- Run `flutter analyze --fatal-infos` and `flutter test` before pushing — the `check` workflow runs the same gates on every push and fails on any info.
- Release order: bump `pubspec.yaml` → update CHANGELOG → commit → lightweight tag → push tag **by name** (`--follow-tags` skips lightweight tags silently).
- The repository is **private**: Release assets are only downloadable by authorized accounts. Making releases reachable to students requires flipping visibility to public (owner decision, `gh repo edit --visibility public --accept-visibility-change-consequences`).
- Credentials are stored in plaintext by design; never commit real accounts, passwords, or captured portal data.
