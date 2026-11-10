# AGENTS.md

GiWiFi campus-network auth tool for 岭南师范学院 (Lingnan Normal University). UI strings, docs, and comments are in Chinese — keep new user-facing text and README content in Chinese.

## Start Here

Read before making changes:

- [.agents/project.md](.agents/project.md): versions, implementation history, crypto sync points, storage.
- [.agents/commands.md](.agents/commands.md): build, analyze, test, golden, tooling commands.
- [.agents/rules.md](.agents/rules.md): lint, commit, testing, and release rules.

## Highest Priority Rules

- Single Flutter implementation since v2.0.0 — do not reintroduce a C#/.NET copy; extend the Dart code. The Linux headless build (`bin/giwifi_headless.dart` + `lib/headless/`) is a second entry point of the same Dart code, not a second implementation — it reuses `AuthService`; never add a Python/Go/Node rewrite.
- Crypto/form logic lives in two places that must stay in sync: `lib/common/aes_crypto.dart` and `tool/gen_test_vectors.py` (vectors baked into tests and selfcheck). Change one, update both, regenerate vectors.
- Style tokens are mandatory: every corner comes from `lib/ui/shape.dart` (`AppShape`/`AppRadius`, superellipse only — no `ClipRRect`/`RoundedRectangleBorder`/`StadiumBorder`/`BorderRadius.circular`) and every text size/weight from `lib/ui/typography.dart` (`AppTextStyle`). `test/lint/style_tokens_test.dart` fails the build on violations elsewhere in `lib/`.
- Widget tests must set `SettingsService.configDirOverride` to a temp dir, or they hit the real `%APPDATA%\giwifi_ua_switcher` on Windows.
- Goldens were regenerated on Linux: they must be regenerated (`flutter test --update-goldens`) on a Linux toolchain after any intentional UI change, or CI (ubuntu-24.04) fails them.
- Run `flutter analyze --fatal-infos` and `flutter test` before pushing — the `check` workflow runs the same gates on every push and fails on any info.
- Release order: bump `pubspec.yaml` → update CHANGELOG → commit → lightweight tag → push tag **by name** (`--follow-tags` skips lightweight tags silently).
- The repository is **private**: Release assets are only downloadable by authorized accounts. Making releases reachable to students requires flipping visibility to public (owner decision, `gh repo edit --visibility public --accept-visibility-change-consequences`).
- Credentials are stored in plaintext by design; never commit real accounts, passwords, or captured portal data.
- Portal discovery and probe-first offline detection are intentional core behavior (v2.1.0, verified on the real network): do not reintroduce hardcoded portal assumptions or drop the hijack probe from `checkOnline` — `test/portal_discovery_test.dart` freezes this. The gateway wifidog port (8060) does not exist in this deployment; do not revisit it.

## REA Reverse-Engineering Toolkit (project-local)

`rea-agents` is installed as an exact-pinned devDependency (`package.json`); `node_modules/` is gitignored. The `rea` MCP server is registered **project-level** in `opencode.json` (`node node_modules/rea-agents/scripts/rea.mjs mcp`), so CLI and MCP share one installation. Commit `package.json`, `package-lock.json`, and `opencode.json`; a fresh clone needs `npm install` to restore both.

- MCP availability: the server auto-loads only for sessions opened in this repo. OpenCode hot-reloads the config — verify with `opencode mcp list` (expect `✓ rea connected`).
- CLI usage: run `node_modules/.bin/rea <command>` (or `npm exec -- rea …`); `npx` resolves the local install first. Route large Evidence results to files outside the repo (e.g. `/tmp`), then page them with `rea inspect-analysis-view`.
- Updating: `rea update` manages only global installs and is a no-op here. Update with `npm install --save-dev --save-exact rea-agents@latest`; the MCP command path follows `node_modules`, so `opencode.json` needs no change.
- Diagnostics: `rea doctor` reads only **user-level** registrations — a project-level entry showing `config_drift` or `missing_analysis_engine` is expected, not a bug. `opencode mcp list` is the authoritative connection check.
- Native engines (Hopper/Ghidra/IDA/JADX/Kuna) are **not** installed. Built-in static analysis (JS/Electron, .NET, PE/ELF headers, Go/Rust metadata, Flutter APK) needs none. For native decompilation, add provider env vars under the `rea` server entry in `opencode.json` (e.g. `HOPPER_LAUNCHER_PATH`, `REA_GHIDRA_STARTUP_TIMEOUT_MS`) — do **not** run `npx rea-agents setup`, it writes user-level config and skill files.
- Exception: `REA_JADX_MCP_JAR` **is** wired in `opencode.json` to `/root/LNUGiwi/tools/jadx-headless-mcp-0.7.1-all.jar` (gitignored, sha256 `6e5eacf5…`, from `1013503897/jadx-headless-mcp` v0.7.1 — must be exactly 0.7.1). It enables `inspect-android-class/method`, `search-android-classes` for DEX analysis. A fresh clone must re-download the JAR to that path. Requires JDK 17+.
- The bundled REA skill is not installed (it is user-level and independent of this project setup).
- REA Evidence files, snapshots, and captures may embed real portal data and credentials — never commit them; keep them outside the repo. Use REA only on software we own or are authorized to analyze.
