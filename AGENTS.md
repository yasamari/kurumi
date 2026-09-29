# AGENTS.md

## Toolchain

`flutter`/`dart` are **not** on PATH. They come from the Nix flake devShell (`.envrc` → `use flake`). Prefix commands:

```sh
direnv exec . flutter analyze
direnv exec . flutter test
direnv exec . flutter test test/mirakurun_filter_test.dart   # single file
nix build                                                        # Linux app package
```

`dart run ...` fails here (`kurumi depends on flutter_test from sdk which doesn't exist`). Always go through `flutter pub run`, e.g.:

```sh
direnv exec . flutter pub run build_runner build --delete-conflicting-outputs
```

## Codegen

- `*.g.dart` (riverpod_generator / json_serializable) and `*.freezed.dart` are **committed**. Regenerate and commit them; don't hand-edit them.
- Every annotated file declares `part '<name>.g.dart'` / `part '<name>.freezed.dart'`.
- `riverpod_lint` is a dev dependency but no `custom_lint`/lint runner config exists, so **none of its rules are active** — only `flutter_lints` (`analysis_options.yaml`).
- `mirakurun-openapi.json` / `konomitv-openapi.json` at the repo root are reference specs only. DTOs are hand-written; nothing regenerates them.

## Architecture

`lib/src/` is layered, dependencies point inward (`features` → `domain`/`core` → `data`):

- `core/` — router (`go_router`, 5-tab `StatefulShellRoute`), theme (dynamic_color), settings (SharedPreferences-backed `AppSettings` + immutable `AppSettingsState`), shared `Dio`, utils.
- `domain/` — backend-agnostic entities (freezed) and the `TvRepository` interface.
- `data/backends/{mirakurun,konomi}/` — per-backend API client (dio), DTOs, `*_filter.dart` (pure mapping), repository.
- `features/` — UI per tab, `shell/` holds the adaptive scaffold.

Key invariants when adding a backend (Mirakurun, KonomiTV, EDCB…): implement `TvRepository`, then add one line to the switch in `domain/providers/backend_provider.dart` **plus** the `switch` cases in `BackendType.label` and `AppSettingsState.activeBaseUrl`, and a persisted URL + setter in `core/settings/app_settings.dart`. `TvRepository` doc comments state this explicitly.

Filtering logic lives in pure functions (`buildMirakurunChannelItems`, `buildKonomiChannelItems`) with `DateTime now` / `baseUrl` injected — keep it that way so it stays unit-testable.

## Conventions

- **Doc comments, test names, and user-facing strings are in Japanese.** Match this.
- Imports inside `lib/` are **relative**; `test/` imports via `package:kurumi/src/...`.
- Only the TV tab is implemented; the other four tabs render `PlaceholderScreen`. The 5-tab order is duplicated in `core/router/router.dart` (branches) and `features/shell/app_destinations.dart` — **keep both in sync**. Breakpoints live in `AdaptiveBreakpoints`.
- Tests cover pure logic only (no widget/golden tests, no network). Keep new logic in testable pure functions rather than widget code.

## Native media stack (ARIB 字幕)

プラットフォームごとに libmpv の入手元が違う。編集時は 3 つ全部を見る。

- **Linux** — `flake.nix` が nixpkgs の mpv + `ffmpeg-full` をルートの `mpegts-tsreadex.patch` 付きでビルドする。このパッチは fileset に含まれていないが、flake の式が `patches` リストで直接参照するので sources には入る。
- **Android** — `packages/media_kit_libs_android_video` (pub.dev 版 1.3.8 のベンダリング) を `pubspec.yaml` の `dependency_overrides` で path 差し替えている。その `android/build.gradle` が **自前の** `yasamari/libmpv-android-video-build` リリースから `.jar` を取得し、ffmpeg に libaribcaption を有効化してある。
- **iOS / macOS / Windows** — pub.dev 版のまま。ARIB 字幕は非対応。

自前ビルドを更新したときは:

```sh
cd ../libmpv-android-video-build
# 変更 → commit → push → Actions 完了を待つ
gh release view <tag> --repo yasamari/libmpv-android-video-build
# 新しい .jar を tmp に落とし MD5 を控える
```

控えた MD5 は `packages/media_kit_libs_android_video/android/build.gradle` の `filesToDownload` の **URL・`md5`・`destination` の `$buildDir/<tag>/` の 3 箇所**を更新する。**書き換えが 1 つでも欠けると Gradle が `MD5 verification failed` で落ちる**。更新後は `direnv exec . flutter clean` を挟む (古い `$buildDir` の jar が残る)。

`features/player/mpv_options.dart` の `sub-lavc-o=sub_type=bitmap` は libaribcaption の bitmap レンダラ (freetype 必須) を使うため、`ARIBCC_NO_RENDERER=ON` でビルドした libmpv では字幕が出ない。

## Gotchas

- `flake.nix` builds from an explicit `fileset` (`analysis_options.yaml`, `lib`, `linux`, `packages`, `pubspec.yaml`, `pubspec.lock`, launcher icon). Adding `test/`, `assets/`, or new platform dirs requires updating that list or `nix build` breaks. `packages/` は `dependency_overrides` の path 依存なので、ここを抜くと Android ビルド以外でも `pub get` が失敗する。
- `pubspec.lock` に path 依存が `relative: true` で記録される。`packages/` 以下の相対パスを変えたら lock を作り直す。
- Both backends are plain-HTTP LAN servers. `android/app/src/main/AndroidManifest.xml` has **no `INTERNET` permission** (only `src/debug` and `src/profile` do), and `ios`/`macos` `Info.plist` have **no ATS cleartext exception** — release builds on those platforms cannot reach a backend until this is fixed.
- No CI config exists; verification is local `flutter analyze` + `flutter test` (both currently clean).
