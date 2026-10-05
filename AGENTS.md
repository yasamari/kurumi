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

- `core/` — router (`go_router`, 5-tab `StatefulShellRoute`), theme (Compose Material 3 の Dynamic Color)、settings (SharedPreferences-backed `AppSettings` + immutable `AppSettingsState`。バックエンドURL に加えてプレイヤーの表示設定 = 弾幕 on/off・文字サイズ・不透明度・速度・字幕 on/off もここで永続化する)、shared `Dio`, utils, `core/widgets/` (画面をまたいで共有するウィジェット: `ChannelCard` / `ChannelLogo` / `ProgramSymbolText`)。チャンネルカードはテレビ画面と視聴画面のチャンネル切替タブの両方で使うため `features/tv/widgets/` ではなく `core/widgets/` に置く。
- `domain/` — backend-agnostic entities (freezed) and the `TvRepository` interface.
- `data/backends/{mirakurun,konomi}/` — per-backend API client (dio), DTOs, `*_filter.dart` (pure mapping), repository.
- `data/nx_jikkyo/` — ニコニコ実況コメント (NX-Jikkyo)。`TvRepository` とは別系統で、`Channel` の network_id/service_id を `jk<N>` に変換する対応表と、2本の WebSocket セッション。
- `features/` — UI per tab, `shell/` holds the adaptive scaffold.

Key invariants when adding a backend (Mirakurun, KonomiTV, EDCB…): implement `TvRepository`, then add one line to the switch in `domain/providers/backend_provider.dart` **plus** the `switch` cases in `BackendType.label`, the capability getters (`supportsVideos`, `supportsRecordingReservations`), and `AppSettingsState.activeBaseUrl`, and a persisted URL + setter in `core/settings/app_settings.dart`. `TvRepository` doc comments state this explicitly. Nav availability follows automatically: `features/shell/app_destinations.dart` maps sections to those capabilities and never names a backend, so no update is needed there.

**`AppSettings` は接続先と表示設定が混在する 1つの state を持つ。接続先と無関係な値を見る provider は `select` / `selectAsync` を使う。** 丸ごと `ref.watch(appSettingsProvider)` した provider は、弾幕の文字サイズや字幕 on/off の保存のたびに再計算される。その連鎖は `backendDio` → `tvRepository` / `videoRepository` → `nowOnAirChannels` / `videoDetail` → `liveStream` と続き、`/watch/:id` では一覧が `AsyncLoading` に戻るため映像スロットが `PlayerLoadingView` に差し替わり、**`_LivePlayerState` ごと破棄されて mpv とセッションを作り直す** (弾幕スライダーを1つ動かすたびに映像が作り直される)。 そのため、接続先だけを見るなら `ref.watch(appSettingsProvider.select(...))`、非同期 provider で「設定されたか」だけ見るなら `selectAsync(...)` を使う (`appSettingsProvider.future` をそのまま購読すると future のインスタンスが変わるたびに再実行される)。対象は `core/network/dio_provider.dart`、`domain/providers/backend_provider.dart`、`features/tv/tv_providers.dart` と、視聴画面の `showQualityMenu` (`watch_screen.dart`)。`select` は拡張なのでそのファイルには `flutter_riverpod` の import が必要。回帰は `test/backend_endpoint_test.dart` で検出する。

Filtering logic lives in pure functions (`buildMirakurunChannelItems`, `buildKonomiChannelItems`) with `DateTime now` / `baseUrl` injected — keep it that way so it stays unit-testable.

## 実況コメント (NX-Jikkyo)

接続先は `data/nx_jikkyo/jikkyo_endpoints.dart` の `nxJikkyoBaseUrl` で**コードに固定**。設定画面には出さない (ユーザーが選択済み)。

`jk<N>` への変換表 (`jikkyo_channel_map.dart`) は KonomiTV の `server/static/jikkyo_channels.json` (362行) を移植したもの。うち4組が同じ (network_id, service_id) を共有しているためキー数は358。重複組はどれも `jk` ID が同一なので畳んでも解決結果は変わらない。3点だけ KonomiTV 側と挙動が一致していない:

- 地上波の network_id は実 NID では 0x7880〜0x7FEF だが、表内では番線値 15 に束じてある。したがって `resolveJikkyoChannelId` は network_id を見ず、**`ChannelType` で地上波か判定**する。CATV の network_id (0x7CA0) が地上波の範囲に数値的に含まれうるため、NID の数値だけでは区別できない。
- 地上波では `sid`, `sid - 1`, `sid - 2` の順に引く (NHK総合2・東京が 1つ前の SID を持つため)。
- `jikkyo_id: -1` のエントリは `null` として**落とさず保持**する。落とすと sid-1 フォールバックが別地域の SID にマッチして誤検出しうる。登録済み判定は NX-Jikkyo の `KNOWN_JIKKYO_CHANNEL_IDS` (35件) との交差で行う (表にある `jk256` などは接続時に 1008 で拒否される)。

セッションは 2 本: `JikkyoWatchSession` (`/ws/watch`) を張り続け、`room` で得た threadId / yourPostKey から `JikkyoCommentSession` (`/ws/comment`) を起こす。過去ログは「既存より古い」コメントとして届くので `mergeJikkyoComments` (`jikkyo_comment_list.dart`) で常にコメ番順に並べ直すこと。

**実況コメントは Riverpod ではなく `JikkyoCommentController` (`features/player/`, `ChangeNotifier`) が所有する。** 視聴画面は `MediaQuery.orientationOf` で `Row` と `Column` を切り替えるが、ウィジェットの型が変わるとその下の Element が作り直されるため、`Row`/`Column` の内側にある State は画面回転ごとに失われる。コメント接続は回転しても保たれる必要があるため、向きに依存しない `_WatchLayoutState` が controller を持ち (`_WatchLayout` に channelId をキーで渡し、チャンネル切替では作り直す)、`dispose` でソケットを閉じる。**ここに `ConsumerWidget` や Riverpod provider を置くと回転のたびにタブが戻り、`connecting` に戻る。**

情報パネルのタブは 3 つ (番組情報 / チャンネル / コメント)。選択位置は **`watchInfoTabProvider` (`@Riverpod(keepAlive: true)`) が持つ**。State のフィールドだとチャンネル切替でタブが戻る — 切替は `context.go('/watch/<id>')` で視聴画面ごと置き換えるため、回転と異なり映像スロットごと破棄される。keepAlive provider なら回転・チャンネル切替の両方で保たれる。なお `IndexedStack` は `if` で子を落とすとコメント選択時 (index 2) に子が1件只剩って範囲外.Assertion を出すので、未選択タブも `SizedBox.shrink()` で埋めて **タブ数固定**で渡す。この制約は `PlayerInfoTabs` (`program_info_panel.dart`) に集約してあり、`tabCount` と `children.length` / `destinations.length` の不一致は assert で検出する。

弾幕 (`canvas_danmaku`) は `features/player/jikkyo_danmaku_overlay.dart`。`DanmakuScreen` は `LayoutBuilder` で親の制約からサイズを取るため `Positioned.fill` が必須。**置く場所は外側の `Stack` ではなく `Video` の `controls` ビルダーが返す `Stack` の中**。`Video` は「映像テクスチャ → 字幕 → 標準コントロール」を内側の `Stack` で描画しているため、外側の `Stack` に重ねると (1) コントロールより上になる / (2) 順序を入れ替えると映像テクスチャより下になって見えない、のどちらかで破綻する。controls レイヤーの内側なら「映像の上・操作オーバーレイの下」におさまる。**この制約は `PlayerVideoView` (`player_video_view.dart`) の `controls` ビルダーの中に閉じてあり**、両画面はこのウィジェットを使うだけ。同じ `Stack` には `StackFit.expand` を指定する (`Video` 側は `Positioned.fill` で tight 制約を渡しており、標準コントロールに loose な制約を渡すとグラデーション等が縮む)。コントロール自動非表示時 (`mount=false`) でもビルダーの返り値はツリーに残るので、弾幕だけが消えることはない。**ただし `Video` は `FittedBox(fit: BoxFit.contain)` で描くため、そのまま重ねるとレターボックス (黒帯・柱状) にも弾幕が出る**。映像の**表示**アスペクト比を `videoDisplayAspectOf` (`player_error.dart`) で取り、`JikkyoDanmakuLayer` の `Align` + `AspectRatio` で矩形を絞る。`FittedBox(contain)` と同じ矩形になるので幅高を自前で計算しなくてよい。比が確定するまで (`video-params` 未着・音声のみ) 弾幕は描画しない。**`w`/`h` (符号化サイズ) を使ってはいけない**: 日本語デジタル放送には 1440x1080 を 16:9 に引き伸ばすチャンネルが多く mpv が PAR 12:11 として持つため、`w`/`h` は 1.333 になるが**表示は 1.778**。ここを間違えると矩形が縦に伸びて弾幕が黒帯に侵入し、かつ端に届かない。

**弾幕の on/off は回転で破棄されない位置に持つ。** `PlayerPlaybackController` のフィールド (`danmakuPreferences`) で、**通知は映像には配らない**。映像の `Stack` 内に持つと回転でリセットされる。`controller.liveComments` (ライブ) は購読直後のバックログ (直近100件) を除外した新規コメントだけを送る。`DanmakuOption.fontSize` は画面全体で1つなので `mail` のサイズコマンド (`small`/`big`) は弾幕では表現できない。

**弾幕と字幕の設定は一切 `PlayerPlaybackController.notifyListeners` に出さない。** 通知すると `PlayerVideoView` ごと作り直されるうえ、`Video` の `controls` ビルダーが毎回新しいクロージャになるため media_kit 内部の表示パラメータ notifier まで更新が飛び、映像・弾幕が一瞬止まる。弾幕は `danmakuPreferences` の `ValueNotifier<DanmakuPreferences>` を**弾幕の層の中** (`JikkyoDanmakuOverlay`) で、字幕は `subtitlesEnabled` の `ValueNotifier<bool>` を**字幕ボタンの中** (`SubtitleToggleButton`) で購読する。どちらも映像の `Stack` の**内側**なので安全で、設定を変えるたびに弾幕のサブツリー (それぞれボタン 1個) だけが作り直される。

**文字サイズ・透明度・速度は `danmaku_settings.dart` に集約する。** 値は `DanmakuDisplaySettings` (画面固定値との合成は純関数 `danmakuOptionOf`、スライダー値の正規化は `danmakuFontSizeOf` ほか)。実行時の持ち主は `PlayerPlaybackController.danmakuPreferences` (`ValueNotifier<DanmakuPreferences>`。on/off と3項目をまとめる)。購読するのは弾幕の層だけで、設定メニューはコールバック経由 (`_SettingsMenuPanel` がローカルに値を鏡写する) にする。どちらも映像の `Stack` の**内側かポップアップルートの中**なので安全。

設定の変更は引数の差し替えでは反映しない。**`DanmakuScreen` は `option` を `initState` でしか読まない** (`didUpdateWidget` が無い) ため、`DanmakuScreen.option` に新しい値を渡すだけでは何も起きない。`createdController` で受けた `DanmakuController.updateOption` で配る。`DanmakuScreen` の破棄は親に通知されないので、登録の解除は `_DanmakuScreenView` (オーバーレイ内の薄いラッパ) の `dispose` で行う — 解除しないと通常表示→フルスクリーン切替で破棄済みの notifier に触って落ちる。文字サイズが変わったら `store.resetMeasurements()` が必要 (キャッシュされた幅は旧サイズのまま測り直されない)。オーバーレイ側でも 1 度落とす: `updateOption` 側も落とすため二重呼びだが、その間の再測定は起きない。オーバーレイは `build` の中で `ValueListenableBuilder` を使い、`enabled` と現在の `option` を**画面を作り直す側**に与える (既に作られた画面は `updateOption` 側で追従し、後から作られた画面は現在の値を受け取る)。

**表示設定は `AppSettings` に永続化する** (弾幕の on/off・文字サイズ・不透明度・速度、字幕の on/off)。`AppSettingsState` が値を持ち、既定値も**そこにだけ**置く (`DanmakuDisplaySettings.defaultFontSize` などは `AppSettingsState` の定数を引く。値を二重に持たない)。プレイヤーは生成時にスナップショットを初期値として受け取り (`danmakuPreferencesOf`)、変更はコールバック (`onDanmakuPreferencesChanged` / `onSubtitlesEnabledChanged`) で notifier に渡す。**プレイヤーはバックエンドのベースURLが読めていないと開けないので、到達時には設定の読み込みが済んでいる** — 生成時に読むだけで再購読はしなくてよい。回転・一時停止・画質変更・チャンネル切替・アプリ再起動をまたいで値が保たれる。**保存 (`AppSettings` の状態更新) でプレイヤーが作り直されないことも守る**: 視聴画面は設定全体を `ref.watch` せず、描画に必要な値だけ `select` する (画質メニューを出すかの要否はバックエンド種別 → `appSettingsProvider.select`)。

**字幕は既定で非表示** (`AppSettingsState.defaultSubtitlesEnabled`)。mpv は既定で `sid=auto` (字幕があれば出す) なので、プレイヤーは映像を開くたび ([`PlayerPlaybackController.openUri`]) に `SubtitleTrack.no()` / `auto()` を選び直して適用する (`toggleSubtitles` は mpv 適用・notifier 更新・永続化をまとめて行う)。字幕ボタンは mpv のトラックを自分で購読せず、表示状態は `subtitlesEnabled` の通知を購読して受ける (`SubtitleToggleButton`)。

弾幕エンジンは `canvas_danmaku` のフォーク (`yasamari/canvas_danmaku`、MIT。`pubspec.yaml` は rev ピン留め git 依存)。描画は**決定論的**: 各弾幕は共有時計 (`DanmakuClock`) 上の birth を持ち、位置は `now - birth` の純関数 (`danmaku_track_assign.dart`)。軌道も birth 順の純関数で、`Random` は使わない — ただし**一度決まったら二度と変えない** (下の不変条件 2)。計測 (幅) とラスタ化は初回描画時に遅延実行し、挿入時はソート挿入だけ (一括取得が重くならない)。`CustomPainter` 3層分離・Ticker 自動停止・バッチ描画の高速化機構は温存する。

**弾幕エンジンの不変条件 (3 つとも守ること)。** 破ると「消える少し前の弾幕が上段へ飛ぶ」症状 (描画中に `yPosition` が変わる) に戻る:

1. **画面上の滞在時間は `duration` ちょうどで、幅に依存させない** (`scrollDanmakuGone`)。`scrollDanmakuX` は `W + w` を `duration` で進むので `x == -w` (= 完全退出) は幅によらず `birth + duration`。幅依存の transit を使うと消滅順が出生順とズレ、不可視の弾幕が軌道を占め続け、alive 窓の head 一括掃き出しも効かなくなる。
2. **軌道は 1 回だけ決め、弾幕自身に記録する** (`DanmakuItem.track` / `admitScrollTrack`)。**作り直しのたびに決め直してはいけない。** 読み直しは出生順の別の場所 (`now - 2 * duration`) から始まるので逐次処理と結果が同じにならず、窓の外 (描画されない古い弾幕) が軌道を確保しているかどうかで途中の弾幕が変わり、それが連鎖して表示中の弾幕まで動く。`store.prune` は 11 フレームごとに version を上げるので**窓の作り直しは 1 秒に約 5 回**起きており、弾幕数が多いほど露見する。記録は store 経由の共有なので、回転・フルスクリーンで新しく作られた `DanmakuScreen` も同じ行になる (軌道数が減って範囲外になった記録だけ開き直す)。静的弾幕 (`ue` / `shita`) の `admitStaticTrack` にも同じ規則を適用する。
3. **再構築の開始点は `now - 2 * duration`** (`trackReplaySpanMs`)。塞ぎ条件はどちらも `elapsed < duration` を要求するので、それより古い弾幕は画面上のどの弾幕も塞げない。窓をこれより狭くすると、再構築時に読み飛ばした弾幕の衝突が反映されない (2. の記録があるので表示中の弾幕は行が動かないが、これは前提であって記録の代わりにはならない)。

なお alive 窓のカーソルは添字ではなく **birth 処理済み境界** (`lowerBoundBirth` で毎回引く)。`prune` が出生順リストの先頭を落とした分だけ添字がずれると、新着弾幕を黙って落とす。回帰テストは `test/danmaku_track_stability_test.dart` (窓管理を再現して高流量を回し、飛行中の行の変化数と「後から作った view との一致」を見る)。`test/danmaku_engine_test.dart` は個別の純関数。

**ストア更新後は `SchedulerBinding.instance.ensureVisualUpdate()` で次のフレームを立てる** (`JikkyoDanmakuOverlay._ensureFrame`)。ビューはストアの通知を受けて **`addPostFrameCallback` (= 描画されたフレームの最後) で起き上がる** ので、フレームが立たないままでは起き上がりが永久に届かない。弾幕が1つも無い間は ticker も止まっており (**Ticker 自動停止** の最適化)、他に dirty なものが無ければフレーム自体が立たない → コメントがストアに溜まり続けるのに描画されず、「情報パネルのタブ切替や操作オーバーレイの表示など何かをするまで弾幕が出ない」という症状になる (Linux/Wayland で実測。Android は映像テクスチャの更新が常にフレームを立てるため表面化しにくい)。本来はエンジンの `_requestWake` を直すところだが、ストアを書く当の層が ensure している。

**描画状態 (`DanmakuStore`) と時計は映像の `Stack` の外に持つ。** media_kit のフルスクリーンは同じ `controls` ビルダーで別ルートに新しい `Video` を積むため、`DanmakuScreen` が2つになる。両方に同じ store/clock を渡すと、同じ時計窓を描くので切替時に描画中の弾幕が消えない。回転も同様 (作り直されたviewが時計窓から描き直す)。所有者はライブが `_WatchLayoutState`、録画が `_VideoPlayerState` (どちらも回転で生き残る)。コメント二重購読 (通常+全画面) は store の重複排除キーで吸収する。store の画像キャッシュは共有で、view 側で破棄しない (重複破棄は null 化で冪等だが、他viewの表示中テクスチャを消さないこと)。

- ライブ: 受信時の時計値を birth にする。保持は直近60秒 (`_liveDanmakuRetentionMs`)。バッファ (`paused-for-cache`、`player.stream.buffering`) 中と一時停止中は時計を凍結する (`danmakuClockShouldRun` の純関数)。バッファ解消は壁時計から再開し (再生位置の基準が無いため合わせ直しはしない)、一時停止の再開は停止中の壁時計分だけ進めて (`danmakuLiveResumeMs` の純関数) ライブエッジに追従させる。
- 録画: `JikkyoPastCommentController` は全件取得して `state` に置くだけ (位置購読・送出ポインタは持たない)。オーバーレイが `danmakuBirthMsOf` (`postedAt - syncStart`、`jikkyo_danmaku_item.dart` の純関数) で birth 換算して一括登録する。時計は `_VideoPlayerState` が `player.stream.position` (ずれ400ms超で補正) + `playing`/`buffering` の合成 (`danmakuClockShouldRun` の純関数、停滞中は凍結) で駆動し、通知間は壁時計で外挿する。シーク先の表示期間内コメントは途中位置から描画される。store 保持は番組尺+30秒。

## ライブEIT (番組情報)

視聴画面の番組情報はライブEIT[p/f]からのみ取得する (`/api/channels` 由来の番組表示はしない)。EIT未受信時は「番組情報を取得中」と出す。TVタブの一覧・チャンネル切替は従来通り API 由来 (`nowOnAirChannelsProvider`)。

- EITパイプラインはバックエンド非依存で `data/ts/` に置く (`eit.dart` セクション再構成+記述子パース / `arib_text.dart` + `arib_tables.dart` ARIB文字列 / `live_program.dart` `TvProgram` 組み立て / `audio_layout.dart` 音声構成判定 / `ts_sync.dart` 188B整列 / `stream_tap_*.dart` ネイティブ tap 連携)。node-aribts と KonomiTV `ProgramUtils` / `LivePSIArchivedDataDecoder` の移植。音声レイアウトは ariblib (`ariblib/constants.py` `COMPONENT_TYPE`) / KonomiTV `TSInfoAnalyzer` の `primary_audio_type` 判定に相当する。文字列整形は `core/utils/program_text.dart` の `formatProgramText` を使い回すこと (二重実装しない)。
- パケット源はバックエンド別: KonomiTV は PSIアーカイブAPI→ `KonomiTsPackets` (`data/backends/konomi/`)、Mirakurun等は stream tap (`kurumi-ts://`)。どちらも `LiveSession` (`features/player/live_session.dart`: mpvが開くURL + 188Bパケット列 + close) に包んで `_LivePlayerState` が所有し、`_open` でセッション確立→ `LivePsiController` 起動→ `player.open` の順に開く。開設中は読み込み表示、失敗は再試行表示。
- **mpv の `stream_cb` コールバック自体は Dart で書かない。** コールバックはmpv側スレッドから呼ばれるが、pure Dart の `isolateLocal` / `Pointer.fromFunction` は作成スレッド以外から呼ぶとプロセスごと abort し、`listener` は戻り値を返せない (`read_fn` はバイト数を返す必要がある)。ブロッキングする read は `native/stream_tap/` の C (`kurumi_tap_*` リング+同期プリミティブ) が持ち、HTTP 取得と EIT 解析は Dart のまま。Dart→mpv 方向の呼び出しは `mpv_stream_cb_add_ro` の1回だけで、`features/player/mpv_stream_tap.dart` に集約する。同一ハンドルへの再登録は mpv が -4 で拒否するため正常扱いにする。
- media_kit は temp playlist 経由 (`loadlist`) で開くため、tap (`kurumi-ts://`) の再生には `load-unsafe-playlists=yes` が要る。無いとプレイリスト由来の origin ゲートで UNSAFE 拒否され、後続ハンドラの NO_MATCH に上書きされて見かけ上 protocol unsupported 相当のエラーになる (`_open` で tap 時のみ設定)。
- ネイティブ tap の対応は Linux (`linux/CMakeLists.txt` でバンドル `lib/` へ)・Android (`android/app/src/main/cpp/CMakeLists.txt` + `externalNativeBuild`)・Windows (`windows/CMakeLists.txt` で実行ファイルと同階層へ)。同期プリミティブの差異 (pthread / SRWLOCK+CONDITION_VARIABLE) は `stream_tap.c` 内の `#ifdef _WIN32` で吸収し、API は共通。`flake.nix` の fileset に `native/` を入れること (抜くと `nix build` 成果物に `.so` が入らない)。nix 成果物はラッパー起動でバンドル相対が外れうるため、tap 用 `.so` は別 derivation (`stream-tap-lib`) でも作り `runtimeDependencies` に載せて soname 解決の保険にしている。macOS/iOS は未対応で、Mirakurun等はセッション開設失敗 (再試行表示) になる。
- **取得ポンプは worker isolate で回す** (`StreamTapSession` が `Isolate.spawn` し、`StreamTapPump` を走らせる)。フルTS (15〜24Mbps) の受取・188B整列・リングへの push をUI isolate で行うとイベントループが圧迫され、mpv への供給が途切れ途切れになって**映像が僅かに遅くなり音声が途切れる** (Mirakurun等だけ 発生。KonomiTV は mpegts を mpv が直接開くため無関係)。worker →メインisolate は `TapWorker*` メッセージで、**EITバッチ (PID 0x12 のみ) しか運ばない**。`LivePsiController` は受け取った 188B バッチを自前でさらに PID フィルタする (二重化しても無害だが、Konomi 経路はフルTS がそのまま流れるので必要)。ポンプは isolate 非依存な `StreamTapPump` に分けてあり、`test/stream_tap_session_test.dart` は `_FakeTapNative` を直接注入して単体テストする。
- `TsSectionAssembler` は PUSI=1 のとき、**pointer_field が示すバイト数を前セクションの続きとしてバッファへ足してから**新セクションに切り替える。実TSはセクションが詰めて置かれるため「長いセクションの末尾 + 次のセクションの開始」が同一パケットに入り、そのパケットは PUSI=1 + pointer_field>0 になる。これを捨てると複数パケットにまたがるセクションが丸ごと失われる (node-aribts `ariblib/packet.py` `sections()` の `buffer.extend(prev)` に相当)。`afc` は 0b01 が adaptation 無し、0b11 が adaptation あり、0b10 はペイロード無し。stuffing (先頭 0xFF) で打ち切る。
- `LivePsiController` は PID 0x12 を組み立て**前**に抜く。フルTS (映像PES含む) をそのまま組み立てると他PIDの断片がバッファに溜まり続ける。
- **音声レイアウト (主音声のみ / ステレオ / デュアルモノラル) もライブEIT[p/f] だけから判定する** (`data/ts/audio_layout.dart` の `detectLiveAudioLayout`、API からは取らない = リアルタイム)。判定材料は EIT イベントの**音声コンポーネント記述子 (0xC4) の `component_type`** (ARIB STD-B10-2 表6-5) で、`eit.dart` が既に `AudioComponentDescriptor` としてパースしている (かつ `live_program.dart` が読み捨てている)。`0x01`=1/0モード・`0x03`=2/0モード → `mainAudioOnly`、`0x02`=1/0+1/0モード → `dualMono`、**それ以外 (3/0以上・5.1/7.1・`0x40` 音声解説・`0x41`) と記述子なしは `unknown`**。判定するのは主・副の切替が要るかどうかだけで、マルチチャンネルは mpv の音声トラック認識に委ねる。PMT からは判定できない (通常のステレオと区別が付かない) ため PMT は見ない。`main_component_flag` が偽の記述子は副音声=**別トラック** (二重ステレオ) なので判定に使わず、mpv が2本出すのに任せる (KonomiTV の再エンコード画質は元の放送が dual mono でも右チャンネルを副音声トラックに分離して2本出すため、**mpv のトラック数を最優先**する)。
- `LivePsiController.audioLayout` は現在番組 (`section_number == 0`) の EIT からのみ更新し、`unknown` は反映しない (音声コンポーネント記述子を含まない再送で「選択可能だった音声」が突然できなくなるのを避ける)。チャンネル・画質切替ではコントローラーごと作り直されるためそのときに戻る。
- `dualMono` と分かった時点で主音声を自動適用する (`_LivePlayerState._syncAudioLayout` → `PlayerPlaybackController.selectAudio(DualMonoChoice(main))`)。既定の `dual_mono_mode=auto` は Lch=主/Rch=副 を同時に出力するため。通知は `ValueNotifier<LiveAudioLayout>` を `_LiveSettingsButton` へ**参照だけ**渡し、`ValueListenableBuilder` は設定メニュー (`_SettingsMenuPanel`) 内で行う (ボタン側で購読すると映像の再構築に巻き込まれる。`_WatchInfoPanel` と同じ理屈)。
- 設定メニュー側の分岐は純関数 `audioMenuMode` / `audioMenuLabel` (`features/player/audio_switch.dart`) に集約し、テスト対象にする。mpv の実トラック2本以上 → トラック一覧 / `dualMono` → 主音声・副音声の**2項目だけ** / それ以外 → **1行だけ表示して押せない** (表示は `主音声`)。録画再生 (`video_play_screen.dart`) は TS を一切見ないので notifier を渡さず `unknown` のまま = mpv に委ねる (Mirakurun の実 dual mono 録画では副音声を選べない)。

## プレイヤー画面の共通層

ライブ視聴 (`watch_screen.dart`) と録画再生 (`video_play_screen.dart`) は同じ mpv でほぼ同じ構成の二つの画面だが、映像周りの組み立ては共通ウィジェットにしてある。**破れやすい制約をここへ寄せ、画面側では mpv 固有の設定だけを書く**こと。

- `player_playback_controller.dart` — `PlayerPlaybackController` (`ChangeNotifier`)。mpv の `Player`/`VideoController` を所有し、エラー回復の判定 (`player_error.dart` の純関数を呼ぶだけ)、表示アスペクト比、二重モノラル、弾幕 on/off、再生位置ストリームを持つ。`dispose` で `Player` も解放する。**Riverpod にはしない** — 下節の回転耐性の要件。同上。
- `player_video_view.dart` — `PlayerVideoView`。`Video` + モバイル/デスクトップ両方の `MaterialVideoControls` テーマデータ + `controls` レイヤー内の弾幕スロット + 再生エラーオーバーレイを**一つ**にまとめる。向きには依存せず常に単一の `Stack` を返す。コントロールの差異は `PlayerControlsLayout` (`live` / `seekable`) で表す。ボタン行は media_kit のテーマデータが非 nullable なので、既定のままにする側は分岐で切り替える (**既定値を自前で書き写さない**)。
- `jikkyo_danmaku_overlay.dart` — `JikkyoDanmakuLayer` が表示矩形の絞り込み、`JikkyoDanmakuOverlay` が store/clock 共有の描画 (ライブは受信時 birth、録画は `birthMsOf` 一括登録)。
- `player_status_views.dart` — `PlayerPlaceholderScaffold` / `PlayerStatusOverlay` / `PlayerLoadingView` / `PlayerRetryView` / `PlayerErrorOverlay`。読み込み・再試行・戻るボタンの土台をライブ/録画で共有する。
- `player_control_buttons.dart` — `buildPlayerTopButtonBar` が戻る→タイトルの並びを組み立て、`PipModeButton` が下部バーの PiP ボタン (対応可否を非同期に解決し、非対応なら描かない)、`InfoPanelToggleButton` が情報パネルの表示切替ボタン (デスクトップ専用) を持つ。どちらも notifier を参照だけ受け把自己的サブツリーの中で購読する。画質ボタンは `trailing` で渡し、**購読する `ConsumerWidget` を包む** (購読すると映像まで作り直され、コントロール自動非表示中のメニュー選択が `onSelected` に届かない)。
- `player_providers.dart` — `infoPanelVisibilityProvider` (keepAlive) が情報パネルの表示状態を持つ。`ref.watch` するのは**インスタンス**で値を購読しない — 画面側で値を購読すると画面全体の build が回り、直下の `video` が新しいウィジェットインスタンスになって映像 (`PlayerVideoView`) まで作り直される。
- `program_info_panel.dart` — `PlayerInfoTabs` が情報パネルの `IndexedStack` + `NavigationBar` を共有 (タブ数固定の制約はここに集約)。
- `player_error.dart` の純関数 (`isPlayerRecovered` / `hasValidVideoSize` / `videoDisplayAspectOf` / `hasValidAudioFormat`) と `player_controls_theme.dart` の純関数は移動しない。テスト対象。
- `watch_screen.dart` のチャンネル送り純関数 (`channelIdsOfSameType` / `channelZapId`) も移動しない。標準コントロールのボタンと PiP ウィンドウのボタンが同じ規則を使う。テスト対象。
- **視聴画面への遷移は `pushReplacement` を使う (`zapToChannel`)。** `/watch/:channelId` はシェル外・root Navigator 上の1ページとして積まれるので、`go` だとページスタック全体が置き換わり下にテレビ画面が残らない。戻る対象がなくなって **Android のシステム戻る でアプリが閉じてしまう** (画面左上の戻るボタンは `canPop` が false なので `go('/tv')` にフォールバックして動くため気づきにくい。実測した症状)。`push` だと前の視聴画面がスタックに残り mpv と `LiveSession` が解放されない。テレビ一覧からの 진입は `push` (`tv_screen.dart`)、チャンネル切替 (標準コントロール・情報パネル・PiP ウィンドウすべて) は `zapToChannel` に集約する。

画面側に残るのはセッションの種類 (tap/Konomi/HLS keep-alive)、EIT 取得の有無、番組名・チャンネル送り・画質一覧だけ。

## プレイヤー画面のレイアウト

映像と情報パネルの配置は `features/player/player_split_layout.dart` の `PlayerSplitLayout` に集約する (矩形計算は純関数 `playerSplitRects`)。

**向きで `Row`/`Column` を出し分けない。** ウィジェットの型が変わるとその下の Element がすべて作り直され、**`_LivePlayer` / `_VideoPlayer` の State ごと破棄される**。State が持つ `PlayerPlaybackController` (中の `Player`) と `LiveSession` が解放され、PSI 取得とライブ追従が中断する。

これが **media_kit のフルスクリーンで映像が黒く止まる (音は出続ける) 直接の原因**になる。フルスクリーンは先に `Navigator` へ*同じ `VideoController` を使う新しい `Video`* を積む (`enterFullscreen`)。その後に向きが変わると (デスクトップは GTK/ネイティブフルスクリーンでウィンドウサイズが変わる → `MediaQuery` 更新、Android は `setPreferredOrientations` で回転)、通常側は破棄されて新しい `Player` で開き直すが、**フルスクリーン側は破棄済みの `VideoController` を参照したまま**になる。音声だけは作り直された `Player` から出て、結果として映像が黒いまま止まる。フルスクリーンから戻るとルートの pop で通常側の新しい `Player` が見えるので「復活」したように見える。画面回転だけでも同じ作り直しが起きる。

`SafeArea` で囲む場合も `isLandscape ? content : SafeArea(child: content)` と**戻り値の型を変えない**。有効辺 (`left`/`top`/…) を切り替えるだけにする。

**情報パネルの表示切替 (`infoVisible`) も `PlayerSplitLayout` 自身が購読する。** 画面側で購読する (`ref.watch(infoPanelVisibilityProvider.select(...))` など) と画面全体の build が回り、直下の `video` が新しいウィジェットインスタンスになって映像が作り直される。ここで購読すれば `video` は同じインスタンスのままなので `Element.updateChild` が短絡する。値を画面側から読ませないのが要点。

**パネルは「載せない」ことで隠す。** `info` を渡したうえで、PiP 中と `infoVisible == false` のときは `Stack` に載せない — 矩形を 0 にしただけで載せると子ツリーが組まれたまま PSI 更新・コメント一覧の作り直しを裏で続けてしまう。`infoVisible` は**デスクトップ平台的だけ従う** (`isDesktopPlatform`)。モバイルは情報パネルが映像の下にあり、`AdaptiveVideoControls` もプラットフォーム判定で標準コントロールを替える (デスクトップだけ `MaterialDesktopVideoControls`) ので、切り替えボタンの載る場所が無い。切替ボタンはデスクトップ下部バーの PiP ボタンの位置に置いた (PiP は Android 専用なので非 Android ではこのボタンだけが出る)。

## PiP (Android)

`simple_pip_mode` を使う。状態の持ち主は `core/pip/pip_mode.dart` の `PipMode.instance` (プラットフォーム機能なので `core` 置き、Dynamic Color と同じ流儀)。ライブ視聴・録画再生の両対応で、ボタンは下部バーの**フルスクリーンボタンの左** (`PipModeButton`、下部バーの並びは「字幕 → 設定 → PiP → フルスクリーン」)。

**`SimplePip` のインスタンスは1個だけ。** コンストラクタが `puntito.simple_pip_mode` のメソッドハンドラを `setMethodCallHandler` で上書きするため、複数作ると最後に作ったものだけが PiP コールバックを受ける。

- **Android 以外では `SimplePip` を呼ばない** (`Platform.isAndroid` ガードが `PipMode` にある)。`isPipAvailable` も含めて他のOSで呼ぶと `MissingPluginException` になる。ボタンの対応可否判定はボタンの中で非同期に解決し、非対応なら描かない (`PipMode.active` も購読しない — 購読すると映像の再構築に巻き込まれる)。
- **`PipWidget` は使わない。** `child`/`pipChild` を入れ替えるとその下のウィジェット型が変わり、`_LivePlayer` / `_VideoPlayer` の State ごと破棄される (上節と同じ理屈)。`PipMode.active` を `ValueListenableBuilder` で購読し、矩形と情報パネルの有無だけを変える (`_buildLayout(pictureInPicture)` に切り出すのは両分岐で同じ型の木を返すため)。
- **矩形は `playerSplitRects` の `pictureInPicture` / `infoVisible` に集約する** (`PlayerSplitLayout` も同じ引数を持つ)。PiP ウィンドウはパネル幅 400 未満なので、横画面の通常の計算だと映像幅が 0 になる。判定は向きより先に行う。
- **PiP 中は情報パネルを描かない** (`PlayerSplitLayout` が載せない。`SizedBox.shrink()` を渡す必要なし)。不可視のまま載せると PSI 更新 / コメント一覧の作り直しを続けているため。
- **PiP 中は標準コントロールだけ外す** (`PlayerVideoView` の `showControls: false`)。controls レイヤーの内側から `AdaptiveVideoControls` を外すだけなので**弾幕は残る**。PiP ウィンドウ内の Flutter 側コントロールは操作できない (画面タップはシステムが処理してアプリに戻る) うえ文字が潰れるため。PiP 入退室で controls クロージャが1回だけ差し替わり mpv の表示パラメータ通知が飛ぶ (設定変更と同じ理屈。一瞬止まるのは許容)。
- **PiP ウィンドウのボタン (RemoteAction)** は `enable(actions:)` で選ぶ。ライブは `PipActionsLayout.media` (前チャンネル・再生/一時停止・次チャンネル)、録画は `mediaOnlyPause`。操作は `PipMode.onAction` を受けて mpv に反映する。ライブの前/次は標準コントロールのチャンネル送りと同じ純関数 (`channelZapId` / `channelIdsOfSameType`、`watch_screen.dart`) で行き先を求めて `zapToChannel` で `pushReplacement` する (`_LivePlayer` は PiP ハンドラからのみ `ref.read` で一覧を取るため `ConsumerStatefulWidget`、購読はしない)。`reportPlaying` で play/pause アイコンを再生状態に合わせる。
- **`enterPipMode` は `setPipActionsLayout` の後に呼ぶ。** ネイティブ側がその時点のボタン一覧を `PictureInPictureParams` に焼き込むため、先に設定しないとボタンが出ない。
- **自動 PiP (ホームキーで自動的に PiP へ入る / API 31+) はプレイヤー画面の mount/unmount に素直に付ける** (設定項目は持たない)。ただし **`enable` / `disable` は `owner` (普通は `this`) を必ず渡す**。チャンネル切替は `go` で視聴画面ごと置き換えるため **新旧画面の破棄順が固定できない** — キーの付け替え (画質変更) は「新 `initState` → 旧 `dispose`」だが、ルート入れ替えは逆になりうる。素直に実装すると **新画面が mount した直後に旧画面の `disable` が走り、`setAutoPipMode` が空のボタン一覧で `PictureInPictureParams` を作り直して「PiP ウィンドウの3つのボタンが消える」** (実測した症状)。`disable` は `identical(_owner, owner)` で現在の持ち主かを見てから外し、解除は次のイベントループに回す (`Timer(Duration.zero, …)`、間に `enable` が来たらキャンセルする)。回帰テストは `test/pip_mode_test.dart` (非 Android では `Platform.isAndroid` が false でネイティブ呼び出しが起きないため、`enable`/`disable` の状態機械をそのまま検証できる)。
- PiP 中は Activity が pause されるが stop はしないので Flutter の `AppLifecycleState` は `inactive`。media_kit `Video` の `pauseUponEnteringBackgroundMode` は `paused`/`detached` でしか止まらないため再生は保たれる。縮小も SurfaceProducer のバッファが映像サイズ固定 + `FittedBox(contain)` なので、PiP ウィンドウに VV されるだけ (VV → 単にスケールされる)。
- Android 側の必須変更は2つ: `AndroidManifest.xml` の activity に `android:supportsPictureInPicture="true"`、`MainActivity` を `PipCallbackHelperActivityWrapper` に継承する (コールバックは `onPictureInPictureModeChanged` からのみ届く。`configureFlutterEngine` の `super` がラッパーの実装になり、`DynamicColorBridge` の据付はその後に書く)。


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
- **`canvas_danmaku` を直すには参照先の差し替えが要る。** `pubspec.yaml` は git 依存の rev ピン留めなので、`../canvas_danmaku` を直しても解決先は `~/.pub-cache/git/canvas_danmaku-<rev>/` のままで反映されない。作業中は `pubspec_overrides.yaml` (gitignore 済み) で path 参照に差し替える。フォークを push して `pubspec.yaml` の `ref:` を上げたら **override を削除し、`pubspec.lock` を git 依存の記載に戻す** — 残しておくと lock が `../canvas_danmaku` を指し、`flake.nix` の fileset にそのパスが無く `nix build` が落ちる。
- **`canvas_danmaku` の rev を上げたら `flake.nix` の `gitHashes` も更新する。** `buildFlutterApplication` は git 依存を `fetchgit` (固定出力) で取るので、`gitHashes.canvas_danmaku` は rev ごとの木ハッシュ。古いままだと `nix build` が hash mismatch で落ちる。新しい値は `hash = pkgs.lib.fakeHash` で `nix build` してエラー出力の `got:` を使う (空文字でも.hash を教えてくれる)。
- Both backends are plain-HTTP LAN servers. Android is fine — `android/app/src/main/AndroidManifest.xml` already declares `INTERNET` **and** `usesCleartextTraffic="true"`, and `ios`/`macos` `Info.plist` declare `NSAllowsLocalNetworking` (local network only; internet-bound cleartext stays blocked by ATS).
- **Android プラグインの `compileSdk` に注意。** プラグインは自分の `compileSdk` を要求し、AGP は SDK Raises に該当プラットフォームを探しにいく。Nix の store は読み取り専用なので 入っていないと「SDK ディレクトリが書けない」でビルドが失敗する。`simple_pip_mode` は `compileSdk 34` を要求するため `flake.nix` の `platformVersions` に `"34"` を入れてある。**新しい Android プラグインを追加したら `compileSdk` を確認して、必要なら `platformVersions` に追加する。** Gradle 側 (根の `android/build.gradle.kts`) から上書きすると AGP 9 では `It is too late to set compileSdk` で弾かれる (評価中に設定するとプラグイン自身の `android {}` に上書きされる) ので、フラグ側を直すこと。
- `simple_pip_mode` は Kotlin Gradle Plugin を適用するため、ビルド時に「Future versions of Flutter will fail to build …」の警告が出る。`android/gradle.properties` の `android.builtInKotlin=false` があるので今は通る。警告はそのままにしてよい (解消するにはプラグイン側が Built-in Kotlin 対応化する必要があり、`packages/` へ vendor することになる)。
- No CI config exists; verification is local `flutter analyze` + `flutter test` (both currently clean). Android 側の確認は `direnv exec . flutter build apk --debug`。
