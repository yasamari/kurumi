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

- `core/` — router (`go_router`, 5-tab `StatefulShellRoute`), theme (Compose Material 3 の Dynamic Color)、settings (SharedPreferences-backed `AppSettings` + immutable `AppSettingsState`)、shared `Dio`, utils, `core/widgets/` (画面をまたいで共有するウィジェット: `ChannelCard` / `ChannelLogo` / `ProgramSymbolText`)。チャンネルカードはテレビ画面と視聴画面のチャンネル切替タブの両方で使うため `features/tv/widgets/` ではなく `core/widgets/` に置く。
- `domain/` — backend-agnostic entities (freezed) and the `TvRepository` interface.
- `data/backends/{mirakurun,konomi}/` — per-backend API client (dio), DTOs, `*_filter.dart` (pure mapping), repository.
- `data/nx_jikkyo/` — ニコニコ実況コメント (NX-Jikkyo)。`TvRepository` とは別系統で、`Channel` の network_id/service_id を `jk<N>` に変換する対応表と、2本の WebSocket セッション。
- `features/` — UI per tab, `shell/` holds the adaptive scaffold.

Key invariants when adding a backend (Mirakurun, KonomiTV, EDCB…): implement `TvRepository`, then add one line to the switch in `domain/providers/backend_provider.dart` **plus** the `switch` cases in `BackendType.label`, the capability getters (`supportsVideos`, `supportsRecordingReservations`), and `AppSettingsState.activeBaseUrl`, and a persisted URL + setter in `core/settings/app_settings.dart`. `TvRepository` doc comments state this explicitly. Nav availability follows automatically: `features/shell/app_destinations.dart` maps sections to those capabilities and never names a backend, so no update is needed there.

Filtering logic lives in pure functions (`buildMirakurunChannelItems`, `buildKonomiChannelItems`) with `DateTime now` / `baseUrl` injected — keep it that way so it stays unit-testable.

## 実況コメント (NX-Jikkyo)

接続先は `data/nx_jikkyo/jikkyo_endpoints.dart` の `nxJikkyoBaseUrl` で**コードに固定**。設定画面には出さない (ユーザーが選択済み)。

`jk<N>` への変換表 (`jikkyo_channel_map.dart`) は KonomiTV の `server/static/jikkyo_channels.json` (362行) を移植したもの。うち4組が同じ (network_id, service_id) を共有しているためキー数は358。重複組はどれも `jk` ID が同一なので畳んでも解決結果は変わらない。3点だけ KonomiTV 側と挙動が一致していない:

- 地上波の network_id は実 NID では 0x7880〜0x7FEF だが、表内では番線値 15 に束じてある。したがって `resolveJikkyoChannelId` は network_id を見ず、**`ChannelType` で地上波か判定**する。CATV の network_id (0x7CA0) が地上波の範囲に数値的に含まれうるため、NID の数値だけでは区別できない。
- 地上波では `sid`, `sid - 1`, `sid - 2` の順に引く (NHK総合2・東京が 1つ前の SID を持つため)。
- `jikkyo_id: -1` のエントリは `null` として**落とさず保持**する。落とすと sid-1 フォールバックが別地域の SID にマッチして誤検出しうる。登録済み判定は NX-Jikkyo の `KNOWN_JIKKYO_CHANNEL_IDS` (35件) との交差で行う (表にある `jk256` などは接続時に 1008 で拒否される)。

セッションは 2 本: `JikkyoWatchSession` (`/ws/watch`) を張り続け、`room` で得た threadId / yourPostKey から `JikkyoCommentSession` (`/ws/comment`) を起こす。過去ログは「既存より古い」コメントとして届くので `mergeJikkyoComments` (`jikkyo_comment_list.dart`) で常にコメ番順に並べ直すこと。

**実況コメントは Riverpod ではなく `JikkyoCommentController` (`features/player/`, `ChangeNotifier`) が所有する。** 視聴画面は `MediaQuery.orientationOf` で `Row` と `Column` を切り替えるが、ウィジェットの型が変わるとその下の Element が作り直されるため、`Row`/`Column` の内側にある State は画面回転ごとに失われる。コメント接続は回転しても保たれる必要があるため、向きに依存しない `_LivePlayerState` が controller を持ち、`dispose` でソケットを閉じる。**ここに `ConsumerWidget` や Riverpod provider を置くと回転のたびにタブが戻り、`connecting` に戻る。**

情報パネルのタブは 3 つ (番組情報 / チャンネル / コメント)。選択位置は **`watchInfoTabProvider` (`@Riverpod(keepAlive: true)`) が持つ**。`_LivePlayerState` のフィールドだとチャンネル切替でタブが戻る — 切替は `context.go('/watch/<id>')` で視聴画面ごと置き換えるため、回転と異なり `_LivePlayerState` ごと破棄される。keepAlive provider なら回転・チャンネル切替の両方で保たれる (`watch_screen.dart` の `_LivePlayer` はこのため `ConsumerStatefulWidget`)。なお `ProgramInfoPanel` の `IndexedStack` は `if` で子を落とすとコメント選択時 (index 2) に子が1件只剩って範囲外.Assertion を出すので、未選択タブも `SizedBox.shrink()` で埋めて **3件固定**で渡す。

弾幕 (`canvas_danmaku`) は `Positioned.fill` で描く (`features/player/jikkyo_danmaku_overlay.dart`)。`DanmakuScreen` は `LayoutBuilder` で親の制約からサイズを取るため `Positioned.fill` が必須。**置く場所は外側の `Stack` ではなく `Video` の `controls` ビルダーが返す `Stack` の中**。`Video` は「映像テクスチャ → 字幕 → 標準コントロール」を内側の `Stack` で描画しているため、外側の `Stack` に重ねると (1) コントロールより上になる / (2) 順序を入れ替えると映像テクスチャより下になって見えない、のどちらかで破綻する。controls レイヤーの内側なら「映像の上・操作オーバーレイの下」におさまる (`watch_screen.dart`)。この `Stack` には `StackFit.expand` を指定する。`Video` 側は `Positioned.fill` で tight 制約を渡しており、標準コントロールに loose な制約を渡すとグラデーション等が縮む。コントロール自動非表示時 (`mount=false`) でもビルダーの返り値はツリーに残るので、弾幕だけが消えることはない。**ただし `Video` は `FittedBox(fit: BoxFit.contain)` で描くため、そのまま重ねるとレターボックス (黒帯・柱状) にも弾幕が出る**。映像の**表示**アスペクト比を `videoDisplayAspectOf` (`player_error.dart`) で取り、`Align` + `AspectRatio` で矩形を絞る。`FittedBox(contain)` と同じ矩形になるので幅高を自前で計算しなくてよい。比が確定するまで (`video-params` 未着・音声のみ) 弾幕は描画しない。**`w`/`h` (符号化サイズ) を使ってはいけない**: 日本語デジタル放送には 1440x1080 を 16:9 に引き伸ばすチャンネルが多く mpv が PAR 12:11 として持つため、`w`/`h` は 1.333 になるが**表示は 1.778**。ここを間違えると矩形が縦に伸びて弾幕が黒帯に侵入し、かつ端に届かない。

**弾幕の on/off と参照は映像の `Stack` 内にあり回転で作り直される**が、弾幕は一時アニメーションなので消えても問題ない。ソケットは `JikkyoCommentController` が別に持つため回転しても切れない。`controller.liveComments` は購読直後のバックログ (直近100件) を除外した新規コメントだけを送る。`DanmakuOption.fontSize` は画面全体で1つなので `mail` のサイズコマンド (`small`/`big`) は弾幕では表現できない。

## ライブEIT (番組情報)

視聴画面の番組情報はライブEIT[p/f]からのみ取得する (`/api/channels` 由来の番組表示はしない)。EIT未受信時は「番組情報を取得中」と出す。TVタブの一覧・チャンネル切替は従来通り API 由来 (`nowOnAirChannelsProvider`)。

- EITパイプラインはバックエンド非依存で `data/ts/` に置く (`eit.dart` セクション再構成+記述子パース / `arib_text.dart` + `arib_tables.dart` ARIB文字列 / `live_program.dart` `TvProgram` 組み立て / `ts_sync.dart` 188B整列 / `stream_tap_*.dart` ネイティブ tap 連携)。node-aribts と KonomiTV `ProgramUtils` / `LivePSIArchivedDataDecoder` の移植。文字列整形は `core/utils/program_text.dart` の `formatProgramText` を使い回すこと (二重実装しない)。
- パケット源はバックエンド別: KonomiTV は PSIアーカイブAPI→ `KonomiTsPackets` (`data/backends/konomi/`)、Mirakurun等は stream tap (`kurumi-ts://`)。どちらも `LiveSession` (`features/player/live_session.dart`: mpvが開くURL + 188Bパケット列 + close) に包んで `_LivePlayerState` が所有し、`_open` でセッション確立→ `LivePsiController` 起動→ `player.open` の順に開く。開設中は読み込み表示、失敗は再試行表示。
- **mpv の `stream_cb` コールバック自体は Dart で書かない。** コールバックはmpv側スレッドから呼ばれるが、pure Dart の `isolateLocal` / `Pointer.fromFunction` は作成スレッド以外から呼ぶとプロセスごと abort し、`listener` は戻り値を返せない (`read_fn` はバイト数を返す必要がある)。ブロッキングする read は `native/stream_tap/` の C (`kurumi_tap_*` リング+同期プリミティブ) が持ち、HTTP 取得と EIT 解析は Dart のまま。Dart→mpv 方向の呼び出しは `mpv_stream_cb_add_ro` の1回だけで、`features/player/mpv_stream_tap.dart` に集約する。同一ハンドルへの再登録は mpv が -4 で拒否するため正常扱いにする。
- media_kit は temp playlist 経由 (`loadlist`) で開くため、tap (`kurumi-ts://`) の再生には `load-unsafe-playlists=yes` が要る。無いとプレイリスト由来の origin ゲートで UNSAFE 拒否され、後続ハンドラの NO_MATCH に上書きされて見かけ上 protocol unsupported 相当のエラーになる (`_open` で tap 時のみ設定)。
- ネイティブ tap の対応は Linux (`linux/CMakeLists.txt` でバンドル `lib/` へ)・Android (`android/app/src/main/cpp/CMakeLists.txt` + `externalNativeBuild`)・Windows (`windows/CMakeLists.txt` で実行ファイルと同階層へ)。同期プリミティブの差異 (pthread / SRWLOCK+CONDITION_VARIABLE) は `stream_tap.c` 内の `#ifdef _WIN32` で吸収し、API は共通。`flake.nix` の fileset に `native/` を入れること (抜くと `nix build` 成果物に `.so` が入らない)。nix 成果物はラッパー起動でバンドル相対が外れうるため、tap 用 `.so` は別 derivation (`stream-tap-lib`) でも作り `runtimeDependencies` に載せて soname 解決の保険にしている。macOS/iOS は未対応で、Mirakurun等はセッション開設失敗 (再試行表示) になる。
- **取得ポンプは worker isolate で回す** (`StreamTapSession` が `Isolate.spawn` し、`StreamTapPump` を走らせる)。フルTS (15〜24Mbps) の受取・188B整列・リングへの push をUI isolate で行うとイベントループが圧迫され、mpv への供給が途切れ途切れになって**映像が僅かに遅くなり音声が途切れる** (Mirakurun等だけ 발생。KonomiTV は mpegts を mpv が直接開くため無関係)。worker →メインisolate は `TapWorker*` メッセージで、**EITバッチ (PID 0x12 のみ) しか運ばない**。`LivePsiController` は受け取った 188B バッチを自前でさらに PID フィルタする (二重化しても無害だが、Konomi 経路はフルTS がそのまま流れるので必要)。ポンプは isolate 非依存な `StreamTapPump` に分けてあり、`test/stream_tap_session_test.dart` は `_FakeTapNative` を直接注入して単体テストする。
- `TsSectionAssembler` は PUSI=1 のとき、**pointer_field が示すバイト数を前セクションの続きとしてバッファへ足してから**新セクションに切り替える。実TSはセクションが詰めて置かれるため「長いセクションの末尾 + 次のセクションの開始」が同一パケットに入り、そのパケットは PUSI=1 + pointer_field>0 になる。これを捨てると複数パケットにまたがるセクションが丸ごと失われる (node-aribts `ariblib/packet.py` `sections()` の `buffer.extend(prev)` に相当)。`afc` は 0b01 が adaptation 無し、0b11 が adaptation あり、0b10 はペイロード無し。stuffing (先頭 0xFF) で打ち切る。
- `LivePsiController` は PID 0x12 を組み立て**前**に抜く。フルTS (映像PES含む) をそのまま組み立てると他PIDの断片がバッファに溜まり続ける。

## Conventions

- **Doc comments, test names, and user-facing strings are in Japanese.** Match this.
- Imports inside `lib/` are **relative**; `test/` imports via `package:kurumi/src/...`.
- Only the TV tab is implemented; the other four tabs render `PlaceholderScreen`. The 5-tab order is duplicated in `core/router/router.dart` (branches) and `features/shell/app_destinations.dart` — **keep both in sync**. Breakpoints live in `AdaptiveBreakpoints`.
- Tests cover pure logic only (no widget/golden tests, no network). Keep new logic in testable pure functions rather than widget code.

## Native media stack (ARIB 字幕)

プラットフォームごとに libmpv の入手元が違う。編集時は 3 つ全部を見る。

- **Linux** — `flake.nix` が `ffmpeg-headless` ベースの最小構成 ffmpeg (`withAribcaption` のみ足す。Android の `default.sh` と同方針) + それにリンクした最小構成 mpv を、ルートの `mpegts-tsreadex.patch` 付きでビルドする。このパッチは fileset に含まれていないが、flake の式が `patches` リストで直接参照するので sources には入る。カスタム構成のため初回は ffmpeg/mpv のローカルコンパイルが必要 (バイナリキャッシュなし)。
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

KonomiTV の再エンコード画質では字幕が ID3 timed-metadata (`TIMED_ID3`) で流れ、`mpegts-tsreadex.patch` が ARIB ペイロード (PRIV/aribb24.js) を読んだ時点で初めて字幕ストリームへ追従する。mpv のトラック一覧は `avformat_find_stream_info()` の後にしか構築されないため、`apply-profile low-latency` 由来の `demuxer-lavf-probe-info=nostreams` (MPEG-TS ではプローブ省略が成立する) と `demuxer-lavf-analyzeduration=0.1` をそのまま使うと字幕が一切出ない。同ファイルで両方を上書き (+`demuxer-lavf-probe-info=auto` / `analyzeduration=0`) している。低遅延を諦める `apply-profile` 行を消すのは非推奨。

## Dynamic Color

Compose Material 3 の `dynamicLightColorScheme()` / `dynamicDarkColorScheme()` を **Android 側で直接呼ぶ** (`android/.../DynamicColorBridge.kt`)。返り値をロール単位の ARGB で MethodChannel に送って Flutter 側が割り当てる (`lib/src/core/theme/dynamic_color.dart`)。

**`dynamic_color` パッケージを Android で使ってはいけない。** 同パッケージは `android.R.color.system_accent*` / `system_neutral*_*` を受け取って **Flutter 側で tonal palette を組み立て直す**ため、Compose と複数の role でずれる。特に `surfaceContainer*` / `surfaceBright` / `surfaceDim` が `ColorScheme.fromSeed(primary)` 由来になり、`surface` / `onSurface` / `inverseSurface` が neutral1 基準 (Compose は neutralVariant 基準) になる。Compose 側の実装 (`DynamicTonalPalette.android.kt`) も API で分岐しており、**34+ は `system_*_light/dark` の role resource を直接読むが、31-33 は neutralVariant 基準の tone にマップし、`system_*` に無い tone (light の 98/96/94/92/87、dark の 24/22/17/12/6/4) だけを CAM16 + HctSolver で合成する**。Flutter 側で再実装しても一致しない。

- `android/app/build.gradle.kts` の `androidx.compose.material3:material3:1.3.1` が要る。UI 部品は参照しないので R8 が落とし、release APK への寄与は **約 +110KB**。`1.5.0-alpha` は compileSdk 37 を要求するので使えない (SDK は android-36 まで)。
- 1.3.1 の `ColorScheme` に `primaryFixed` などの fixed role が無い。Flutter 側の既定値に委ねている (本アプリでは未使用)。
- `background` / `onBackground` / `surfaceVariant` は Compose にはあるが Flutter では非推奨なので意図的に転送していない (Flutter のフォールバックは `surface` / `onSurface`)。
- ロール名は Kotlin の `toRoleMap()` と Dart の `composeDynamicColorRoles` で 1 対 1 に保つこと。片方だけ増やすと Dart 側で例外になる。
- `dynamic_color` は Android 以外 (macOS / Windows / GTK 系 Linux の accent color) のためだけに依存を残してある。Linux 版が `nix build` 対象なので消すと挙動が変わる。

## Gotchas

- `flake.nix` builds from an explicit `fileset` (`analysis_options.yaml`, `lib`, `linux`, `packages`, `pubspec.yaml`, `pubspec.lock`, launcher icon). Adding `test/`, `assets/`, or new platform dirs requires updating that list or `nix build` breaks. `packages/` は `dependency_overrides` の path 依存なので、ここを抜くと Android ビルド以外でも `pub get` が失敗する。
- `pubspec.lock` に path 依存が `relative: true` で記録される。`packages/` 以下の相対パスを変えたら lock を作り直す。
- Both backends are plain-HTTP LAN servers. Android is fine — `android/app/src/main/AndroidManifest.xml` already declares `INTERNET` **and** `usesCleartextTraffic="true"`, and `ios`/`macos` `Info.plist` declare `NSAllowsLocalNetworking` (local network only; internet-bound cleartext stays blocked by ATS).
- No CI config exists; verification is local `flutter analyze` + `flutter test` (both currently clean).
