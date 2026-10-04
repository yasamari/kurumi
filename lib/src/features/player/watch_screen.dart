import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/settings/app_settings.dart';
import '../../core/network/dio_provider.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/ts/audio_layout.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/tv_providers.dart';
import 'audio_switch.dart';
import 'danmaku_settings.dart';
import 'jikkyo_comment_controller.dart';
import 'jikkyo_danmaku_item.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'live_psi_controller.dart';
import 'live_session.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
import 'player_playback_controller.dart';
import 'player_settings_menu.dart';
import 'player_split_layout.dart';
import 'player_status_views.dart';
import 'player_video_view.dart';
import 'program_info_panel.dart';
import 'watch_providers.dart';

/// ライブ視聴画面。全画面プレイヤー遷移先 (`/watch/:channelId`)。
///
/// ナビゲーション (NavigationBar/Rail/Drawer) は表示しない。この画面は
/// StatefulShellRoute の外側 (`rootNavigatorKey` 上) に積まれるため、
/// シェル側のナビゲーションが隠れる。
///
/// 再生UIはmedia_kit標準 (`AdaptiveVideoControls`) を使う。戻るボタン・番組名は
/// AppBarではなく、標準コントロールの上部ボタンバーに載せる
/// ([buildPlayerTopButtonBar])。画質・弾幕・音声は下部バーの設定ボタン
/// ([PlayerSettingsButton]) にまとめ、字幕はその左に置く。ライブのため
/// シークバー・シーク系ジェスチャは無効化する ([PlayerControlsLayout.live])。
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(nowOnAirChannelsProvider);
    // 必要なのはバックエンド種別が画質選択に対応しているかだけ。弾幕や字幕の
    // 表示設定が保存されるたびに視聴画面が作り直されて映像まで巻き込まれる
    // ため、設定全体を購読せずこの値だけを見る。
    final showQualityMenu = ref.watch(
      appSettingsProvider.select(
        (settings) =>
            (settings.value?.backendType ?? BackendType.mirakurun)
                .supportsLiveQualitySelection,
      ),
    );

    return channels.when(
      loading: () => const PlayerPlaceholderScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return const PlayerPlaceholderScaffold(
            child: Center(child: Text('サーバーが設定されていません')),
          );
        }
        return PlayerPlaceholderScaffold(
          child: PlayerRetryView(
            message: '$error',
            onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
          ),
        );
      },
      data: (items) {
        final item =
            items.where((e) => e.channel.id == channelId).firstOrNull;
        if (item == null) {
          return PlayerPlaceholderScaffold(
            child: PlayerRetryView(
              message: 'チャンネルが見つかりません',
              onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
            ),
          );
        }
        final channel = item.channel;
        final title = channel.channelNumber.isEmpty
            ? channel.name
            : '${channel.channelNumber} ${channel.name}';
        return _WatchBody(
          channelId: channelId,
          item: item,
          title: title,
          showQualityMenu: showQualityMenu,
        );
      },
    );
  }
}

/// 前/次チャンネル切替ボタン (デスクトップ下部バー・モバイル中央ボタン用)。
///
/// 同一チャンネル種別内 (地デジなら地デジのみ) の順序で移動し、末尾では
/// 反対端に回り込む。`go` で画面を置き換えるため、旧画面のPlayerは破棄され
/// チューナーが解放される。
class _ChannelZapButton extends ConsumerWidget {
  const _ChannelZapButton({required this.channel, required this.isNext});

  final Channel channel;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids =
        ref.watch(nowOnAirChannelsProvider).value
            ?.where(
              (item) => item.channel.channelType == channel.channelType,
            )
            .map((item) => item.channel.id)
            .toList() ??
        const [];
    final index = ids.indexOf(channel.id);
    final enabled = ids.length > 1 && index >= 0;
    return IconButton(
      icon: Icon(isNext ? Icons.skip_next : Icons.skip_previous),
      color: Colors.white,
      tooltip: isNext ? '次のチャンネル' : '前のチャンネル',
      onPressed: enabled
          ? () {
              final nextIndex = isNext
                  ? (index + 1) % ids.length
                  : (index - 1 + ids.length) % ids.length;
              context.go('/watch/${ids[nextIndex]}');
            }
          : null,
    );
  }
}

/// 情報パネル側だけがタブ選択を購読する。
///
/// 映像 (`PlayerVideoView`) 側で `ref.watch` するとタブ切替のたびに映像まで
/// 作り直される (内部の表示パラメータ通知が飛んで映像・弾幕が一瞬止まる) ため、
/// 購読は情報パネル側だけに置く。
class _WatchInfoPanel extends ConsumerWidget {
  const _WatchInfoPanel({
    required this.item,
    required this.controller,
    required this.onChannelSelected,
    this.psi,
  });

  /// 番組情報パネルに表示するチャンネル+番組。
  final ChannelItem item;

  /// 実況コメントの取得状態。[_WatchLayoutState] が所有する。
  final JikkyoCommentController controller;

  /// EIT[p/f] の取得状態。PSIが組み立てられた後に非null。
  /// [_LivePlayerState] が更新する。
  final LivePsiController? psi;

  /// チャンネル切替タブでチャンネルを選んだときのコールバック。
  final ValueChanged<String> onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final psi = this.psi;
    Widget panel(int selectedIndex) => ProgramInfoPanel(
      item: item,
      controller: controller,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) =>
          ref.read(watchInfoTabProvider.notifier).select(index),
      onChannelSelected: onChannelSelected,
      livePresent: psi?.present,
      liveFollowing: psi?.following,
    );
    if (psi == null) {
      return panel(ref.watch(watchInfoTabProvider));
    }
    // PSIの更新で情報パネルだけ作り直す。映像には触らない。
    return ListenableBuilder(
      listenable: psi,
      builder: (context, _) => panel(ref.watch(watchInfoTabProvider)),
    );
  }
}

/// 画質切替を含む設定ボタンだけが画質を購読する。
///
/// 映像側で購読すると画質表示の更新のたびに映像まで作り直されるため、ここに
/// 切り出す。下部バーの設定ボタンはこのラッパーを置く。
class _LiveSettingsButton extends ConsumerWidget {
  const _LiveSettingsButton({
    required this.player,
    required this.dualMonoChannel,
    required this.onAudioSelected,
    required this.audioLayout,
    required this.danmakuSupported,
    required this.danmakuPreferences,
    required this.onDanmakuPreferencesChanged,
    required this.showQualityMenu,
  });

  final Player player;
  final DualMonoChannel? dualMonoChannel;
  final ValueChanged<AudioChoice> onAudioSelected;

  /// EIT[p/f] からの音声構成の通知元。購読は設定メニュー内で行うため、ここでは
  /// 参照だけを持つ (ここで購読すると映像まで作り直される)。
  final ValueListenable<LiveAudioLayout> audioLayout;

  final bool danmakuSupported;

  /// 弾幕の表示設定 (メニューを開いた時点の値)。実体 (_playback) は購読しない
  /// (購読すると映像まで作り直される)。
  final DanmakuPreferences danmakuPreferences;

  /// 弾幕の表示設定を変えたときのコールバック。永続化まで行う。
  final ValueChanged<DanmakuPreferences> onDanmakuPreferencesChanged;

  /// KonomiTVのときだけ真 (Mirakurunは `decode=1` 固定のため画質を出さない)。
  final bool showQualityMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(tvRepositoryProvider);
    // notifier は build 時 (＝ボタンが載っている間) に確保する。メニュー選択は
    // ボタン破棄後 (コントロール自動非表示) に起きうるため、コールバック内で
    // `ref.read` すると例外で画質が切り替わらない。notifier は keepAlive のため
    // ボタン破棄後も有効 ([watchQualityProvider] 参照)。
    final qualityNotifier = showQualityMenu
        ? ref.read(watchQualityProvider.notifier)
        : null;
    return PlayerSettingsButton(
      player: player,
      dualMonoChannel: dualMonoChannel,
      onAudioSelected: onAudioSelected,
      audioLayout: audioLayout,
      danmakuSupported: danmakuSupported,
      danmakuPreferences: danmakuPreferences,
      onDanmakuPreferencesChanged: onDanmakuPreferencesChanged,
      qualityCurrent: showQualityMenu ? ref.watch(watchQualityProvider) : null,
      qualities: showQualityMenu ? repository.getLiveQualities() : const [],
      onQualitySelected: qualityNotifier == null
          ? null
          : (quality) => qualityNotifier.setQuality(quality),
    );
  }
}

class _WatchBody extends ConsumerWidget {
  const _WatchBody({
    required this.channelId,
    required this.item,
    required this.title,
    required this.showQualityMenu,
  });

  final String channelId;

  /// 番組情報パネルに表示するチャンネル+番組。
  final ChannelItem item;

  /// 上部ボタンバーに表示する番組名 (チャンネル番号 + 局名)。
  final String title;

  /// KonomiTVのときだけ画質切替を出す (Mirakurunは `decode=1` 固定のため)。
  final bool showQualityMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(liveStreamProvider(channelId));
    return Scaffold(
      backgroundColor: Colors.black,
      body: stream.when(
        // 読み込み中でも情報パネルは消さず、映像側だけ読み込み表示にする
        // (チャンネル切り替え中にパネルが点滅しないように)。
        loading: () => _WatchLayout(
          // channelId をキーにする。`go` による画面置き換えでも
          // Element の位置・型が同じだと State が残るが、実況コメントの
          // 接続はチャンネルごと作り直す必要があるため。
          key: ValueKey(channelId),
          stream: stream,
          item: item,
          title: title,
          showQualityMenu: showQualityMenu,
        ),
        error: (error, _) {
          final message = error is ChannelNotFoundException
              ? 'チャンネルが見つかりません'
              : 'ストリームの取得に失敗しました\n$error';
          return PlayerPlaceholderScaffold(
            child: PlayerRetryView(
              message: message,
              onRetry: () => ref.invalidate(liveStreamProvider(channelId)),
            ),
          );
        },
        data: (live) => _WatchLayout(
          // channelId をキーにする (loading 側と同じ理由)。
          key: ValueKey(channelId),
          stream: stream,
          item: item,
          title: title,
          showQualityMenu: showQualityMenu,
        ),
      ),
    );
  }
}

/// 映像スロットと情報パネルの配置を組み立てる。
///
/// 実況コメントの接続 ([JikkyoCommentController]) はこの State が所有する。
/// [_LivePlayer] の内側に置くと画面回転のたびに State が消えるため、切り替えの
/// 外側で持つ必要がある。チャンネル切り替えは `go` で視聴画面ごと置き換わる
/// ため、切り替われば破棄されて作り直される。
///
/// 配置は [PlayerSplitLayout] に任せる。`Row`/`Column` で出し分けると
/// `_LivePlayer` ごと破棄されるが、fullscreen 時に映像が黒く止まる原因になる。
///
/// `stream` をこの State 経由で下に渡すのは、`loading` → `data` の
/// 遷移でこの State を保ったまま映像側だけを差し替えるため
/// (実況コメントの接続をパネルごと切り離さない)。
class _WatchLayout extends ConsumerStatefulWidget {
  const _WatchLayout({
    super.key,
    required this.stream,
    required this.item,
    required this.title,
    required this.showQualityMenu,
  });

  final AsyncValue<LiveStream> stream;
  final ChannelItem item;
  final String title;
  final bool showQualityMenu;

  @override
  ConsumerState<_WatchLayout> createState() => _WatchLayoutState();
}

class _WatchLayoutState extends ConsumerState<_WatchLayout> {
  late final JikkyoCommentController _jikkyo;

  /// ライブ弾幕の保持期間。回転・フルスクリーン切替・一時的な無効化をまたいで
  /// 描画中の弾幕が残るだけの余裕を持たせる (表示期間の数倍)。
  static const _liveDanmakuRetentionMs = 60000;

  /// 弾幕の共有状態。回転・フルスクリーンで作り直されない位置なので、
  /// 描画中の弾幕が保たれる ([JikkyoDanmakuOverlay] 参照)。
  /// ライブは巻き戻さないため保持は直近のみ。
  late final DanmakuClock _danmakuClock = DanmakuClock();
  late final DanmakuStore<int> _danmakuStore =
      DanmakuStore<int>(retentionMs: _liveDanmakuRetentionMs);

  /// 最新の EIT[p/f] 取得状態。`_LivePlayerState` が開設のたびに更新する。
  final ValueNotifier<LivePsiController?> _psiNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    // 実況コメントの接続は実況チャンネルが取得できている場合に即開始する。
    // 弾幕を既定で表示するため、コメントタブを開くまで待たない。
    _jikkyo = JikkyoCommentController(
      channelId: jikkyoChannelIdFor(widget.item.channel) ?? '',
    );
    _jikkyo.start();
  }

  @override
  void dispose() {
    _jikkyo.dispose();
    _danmakuClock.dispose();
    _danmakuStore.dispose();
    _psiNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // セッション開設 (tap起動) 中は映像側だけ読み込み表示し、
    // 情報パネルは出したままにする。
    final video = widget.stream.when(
      loading: () => const PlayerLoadingView(),
      error: (error, _) => PlayerRetryView(
        message: '$error',
        onRetry: () =>
            ref.invalidate(liveStreamProvider(widget.item.channel.id)),
        backFallbackPath: '/tv',
      ),
      data: (live) {
        // 表示設定はここで読む。プレイヤーはベースURLが読めていないと開けない
        // ため、到達時には設定の読み込みが済んでいる。
        final settings = ref.read(appSettingsProvider).value;
        return _LivePlayer(
          // URLが変わったらPlayerを作り直す (画質切替対応)。
          key: ValueKey(live.url.toString()),
          sessionFactory: (player) => _liveSessionFactory(
            ref,
            player: player,
            showQualityMenu: widget.showQualityMenu,
            item: widget.item,
            liveUrl: live.url,
            quality: live.qualityLabel,
          ),
          item: widget.item,
          title: widget.title,
          showQualityMenu: widget.showQualityMenu,
          controller: _jikkyo,
          danmakuStore: _danmakuStore,
          danmakuClock: _danmakuClock,
          psiNotifier: _psiNotifier,
          danmakuPreferences: danmakuPreferencesOf(settings),
          subtitlesEnabled:
              settings?.subtitlesEnabled ?? defaultSubtitlesEnabled,
          onDanmakuPreferencesChanged: (preferences) => ref
              .read(appSettingsProvider.notifier)
              .setDanmakuPreferences(
                enabled: preferences.enabled,
                fontSize: preferences.settings.fontSize,
                opacity: preferences.settings.opacity,
                speed: preferences.settings.speed,
              ),
          onSubtitlesEnabledChanged: (enabled) => ref
              .read(appSettingsProvider.notifier)
              .setSubtitlesEnabled(enabled),
          // KonomiTVは `original` (生放送TS) のときだけデインタレースする。
          // Mirakurun (`decode=1` 固定) も生放送TSのためデインタレースする。
          // トランスコード済み画質はプログレッシブのため不要。
          deinterlace:
              widget.showQualityMenu
                  ? ref
                      .read(tvRepositoryProvider)
                      .isOriginalLiveQuality(live.qualityLabel)
                  : true,
        );
      },
    );
    final info = Container(
      color: Theme.of(context).colorScheme.surface,
      child: ValueListenableBuilder<LivePsiController?>(
        valueListenable: _psiNotifier,
        builder: (context, psi, _) {
          return _WatchInfoPanel(
            item: widget.item,
            controller: _jikkyo,
            psi: psi,
            // チャンネルの切替は `go` で視聴画面ごと置き換える。旧画面の Player と
            // 実況コメント・番組情報のソケットはこれで解放される。
            onChannelSelected: (id) => context.go('/watch/$id'),
          );
        },
      ),
    );
    // 映像は黒帯、情報パネルはテーマの地色で描画する。向きで `Row`/`Column` を
    // 出し分けると映像のサブツリーごと破棄される (画面回転と、media_kit の
    // フルスクリーンでウィンドウサイズが変わる°) ので [PlayerSplitLayout] に
    // 任せる (同ウィジェットのコメントを参照)。
    return PlayerSplitLayout(video: video, info: info);
  }
}

/// ライブセッションを開く。KonomiTVはmpegts直結、他はtap。
///
/// Mirakurun等は stream tap (`kurumi-ts://`) を使う。tap 未対応OS
/// (macOS/iOS) ではセッション開設に失敗し、再試行表示になる。
/// 画質・チャンネルが変わると `_LivePlayer` ごと作り直され、
/// 旧セッションは閉じられる。
Future<LiveSession> _liveSessionFactory(
  WidgetRef ref, {
  required Player player,
  required bool showQualityMenu,
  required ChannelItem item,
  required Uri liveUrl,
  required String quality,
}) {
  if (showQualityMenu) {
    return Future.value(
      buildKonomiLiveSession(
        dio: ref.watch(backendDioProvider),
        displayChannelId: item.channel.id,
        quality: quality,
        mpegtsUrl: liveUrl,
      ),
    );
  }
  return startStreamTapLiveSession(upstreamUrl: liveUrl, player: player);
}

/// ライブ再生の映像スロットを所有する。
///
/// mpv のプレイヤーとエラー判定は [PlayerPlaybackController] が持つ
/// (向きに依存しない位置なので、画面回転で作り直されても続きを保てる)。
/// 再生セッション ([LiveSession]) と EIT 取得 ([LivePsiController]) だけ
/// ここが持つ。実況コメントの接続は外側 ([_WatchLayoutState]) が持つ。
///
/// Riverpod は使わない。画質の購読は [_LiveQualityButton]、情報パネルのタブ
/// 選択は [_WatchInfoPanel] がそれぞれ持つため、ここでは購読するものが無い。
/// セッションを持ち直す必要があるため `StatefulWidget` にする。
class _LivePlayer extends StatefulWidget {
  const _LivePlayer({
    super.key,
    required this.sessionFactory,
    required this.item,
    required this.title,
    required this.showQualityMenu,
    required this.deinterlace,
    required this.controller,
    required this.danmakuStore,
    required this.danmakuClock,
    required this.psiNotifier,
    required this.danmakuPreferences,
    required this.subtitlesEnabled,
    required this.onDanmakuPreferencesChanged,
    required this.onSubtitlesEnabledChanged,
  });

  /// 再生セッション (mpvが開くURL+EIT用パケット列) を開く。
  final LiveSessionFactory sessionFactory;

  /// 番組情報パネルに表示するチャンネル+番組。
  final ChannelItem item;
  final String title;
  final bool showQualityMenu;

  /// 生放送TS (インターレース) のとき真。mpvの自動デインタレースに使う。
  final bool deinterlace;

  /// 実況コメントの取得状態。[_WatchLayoutState] が所有する。
  final JikkyoCommentController controller;

  /// 弾幕の共有ストア。[_WatchLayoutState] が所有する。
  final DanmakuStore<int> danmakuStore;

  /// 弾幕の共有時計。[_WatchLayoutState] が所有する。
  final DanmakuClock danmakuClock;

  /// 最新の EIT[p/f] 取得状態の通知先。[_WatchLayoutState] が持つ。
  final ValueNotifier<LivePsiController?> psiNotifier;

  /// 弾幕の表示設定の初期値。永続化済みの値 ([_WatchLayoutState] が
  /// `AppSettings` から読んで渡す)。
  final DanmakuPreferences danmakuPreferences;

  /// 字幕表示の初期値。永続化済みの値。既定は非表示。
  final bool subtitlesEnabled;

  /// 弾幕の表示設定を変えたときのコールバック。永続化まで行う。
  final ValueChanged<DanmakuPreferences> onDanmakuPreferencesChanged;

  /// 字幕表示を変えたときのコールバック。永続化まで行う。
  final ValueChanged<bool> onSubtitlesEnabledChanged;

  @override
  State<_LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<_LivePlayer> {
  late final PlayerPlaybackController _playback = PlayerPlaybackController(
    seekToLiveEdgeOnResume: true,
    initialDanmakuPreferences: widget.danmakuPreferences,
    initialSubtitlesEnabled: widget.subtitlesEnabled,
    onDanmakuPreferencesChanged: widget.onDanmakuPreferencesChanged,
    onSubtitlesEnabledChanged: widget.onSubtitlesEnabledChanged,
  );

  /// EIT[p/f] の接続。セッション確立後に作る。
  LivePsiController? _psi;

  /// 音声構成の通知先。設定メニューに渡すだけなので、購読はメニュー内で行う。
  final ValueNotifier<LiveAudioLayout> _audioLayout = ValueNotifier(
    LiveAudioLayout.unknown,
  );

  /// 再生セッション (mpvが開くURL+EIT用パケット列)。
  LiveSession? _session;

  /// セッション開設中かどうか。開設完了まで映像の代わりに読み込み表示する。
  bool _sessionLoading = true;

  /// セッション開設の失敗内容。null以外は再試行表示する。
  String? _sessionError;

  /// バッファ (`paused-for-cache`) の購読。停滞中は弾幕時計を凍結する。
  StreamSubscription<bool>? _bufferingSub;

  /// 再生状態の購読。一時停止中は弾幕時計を凍結する。
  StreamSubscription<bool>? _playingSub;

  /// 弾幕時計の駆動条件の最新値 ([danmakuClockShouldRun] の入力)。
  bool _playingForDanmaku = true;
  bool _bufferingForDanmaku = false;

  /// 一時停止に入った壁時計。再開時に進んだ分だけ時計を進める。
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    // `playing` はキャッシュ停滞で変わらないため、停滞検出は別途購読する。
    _playingSub = _playback.player.stream.playing.listen(_onPlayingForDanmaku);
    _bufferingSub = _playback.player.stream.buffering.listen(
      _onBufferingForDanmaku,
    );
    _initialize();
  }

  /// 再生状態に弾幕時計を追従させる。再開時は一時停止中の壁時計分だけ
  /// 進めてライブエッジに追従させる (停止中のコメントが一斉に現れないよう)。
  void _onPlayingForDanmaku(bool playing) {
    if (!mounted) return;
    if (!playing && _playingForDanmaku) {
      _pausedAt = DateTime.now();
    }
    _playingForDanmaku = playing;
    _syncDanmakuRunning();
  }

  /// バッファ (`paused-for-cache`) に弾幕時計を追従させる。停滞中は映像と
  /// 一緒にスクロールを止める。解消時は合わせ直さず壁時計で再開する
  /// (遅延分だけ映像に追従するため)。
  void _onBufferingForDanmaku(bool buffering) {
    if (!mounted) return;
    _bufferingForDanmaku = buffering;
    _syncDanmakuRunning();
  }

  void _syncDanmakuRunning() {
    if (!mounted) return;
    final clock = widget.danmakuClock;
    if (danmakuClockShouldRun(
      playing: _playingForDanmaku,
      buffering: _bufferingForDanmaku,
    )) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null) {
        clock.seekTo(
          danmakuLiveResumeMs(
            frozenNowMs: clock.nowMs,
            pausedAt: pausedAt,
            resumedAt: DateTime.now(),
          ),
        );
      }
      clock.setRunning(true);
    } else {
      clock.setRunning(false);
    }
  }

  JikkyoCommentController get _jikkyo => widget.controller;

  /// EIT[p/f] から得た音声構成をメニューへ流す。
  ///
  /// デュアルモノラルと分かった時点で主音声へ倒す。既定の `auto` は
  /// Lch=主 / Rch=副 を同時に出力するため、判定できた瞬間切り替えておく。
  /// 判定が変わったときだけ呼ぶので、ユーザーが副音声を選んでいても上書き
  /// されない。
  void _syncAudioLayout() {
    final layout = _psi?.audioLayout;
    if (layout == null || layout == _audioLayout.value) return;
    _audioLayout.value = layout;
    if (layout == LiveAudioLayout.dualMono) {
      unawaited(
        _playback.selectAudio(const DualMonoChoice(DualMonoChannel.main)),
      );
    }
  }

  /// mpvオプションを適用してから映像を開く。
  ///
  /// オプションはデコーダ生成時に読まれるため、必ず `open` より前に渡す。
  Future<void> _initialize() async {
    await applyLiveMpvOptions(_playback.player, deinterlace: widget.deinterlace);
    if (!mounted) return;
    await _open();
  }

  Future<void> _open() async {
    // 開き直した時点がライブエッジなので、停止からの再開として扱わない。
    _playback.resetPlaybackState();
    // 旧セッション (tap・PSI取得) を閉じてから開き直す。
    _psi?.dispose();
    _psi = null;
    // 音声構成は「まだ分からない」状態に戻す (PSIごとに作り直されるため
    // 判定そのものは残さない)。
    _audioLayout.value = LiveAudioLayout.unknown;
    // 情報パネルの「取得中」表示に戻す。新しいPSIは下で通知する。
    widget.psiNotifier.value = null;
    final oldSession = _session;
    _session = null;
    if (oldSession != null) {
      await oldSession.close();
    }
    if (!mounted) return;
    setState(() {
      _sessionLoading = true;
      _sessionError = null;
    });
    LiveSession session;
    try {
      session = await widget.sessionFactory(_playback.player);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sessionLoading = false;
        _sessionError = '$error';
      });
      return;
    }
    if (!mounted) {
      await session.close();
      return;
    }
    _session = session;
    // 番組情報 (EIT[p/f]) は情報パネルを開くまで待たず、受信次第反映する。
    _psi = LivePsiController(
      networkId: widget.item.channel.networkId,
      serviceId: widget.item.channel.serviceId,
      packets: session.packets,
    )..start();
    _psi!.addListener(_syncAudioLayout);
    widget.psiNotifier.value = _psi;
    setState(() => _sessionLoading = false);
    // stream tap (`kurumi-ts://`) は media_kit が temp playlist 経由
    // (loadlist) で開く。プレイリスト由来の origin ゲート
    // (`STREAM_ORIGIN_UNSAFE` 拒否) を通すため、開く前に許可する。
    // 無いと UNSAFE が後続の NO_MATCH で上書きされ、見かけ上
    // protocol unsupported 相当のエラーになる。
    final player = _playback.player;
    if (session.playUrl.scheme == 'kurumi-ts') {
      final platform = player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('load-unsafe-playlists', 'yes');
      }
    }
    await _playback.openUri(session.playUrl);
  }

  @override
  void dispose() {
    // 視聴画面を離れたときにソケットを閉じる (_jikkyo は外側が所有する)。
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _psi?.dispose();
    _psi = null;
    _audioLayout.dispose();
    final session = _session;
    _session = null;
    if (session != null) {
      // セッションの停止を待たずに抜ける。
      unawaited(session.close());
    }
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // セッション開設中は映像の代わりに読み込み表示する (tap起動待ち等)。
    // 情報パネルは外側の `_WatchLayout` が描くので、ここでは映像スロット分だけ返す。
    if (_sessionLoading) {
      return const PlayerLoadingView();
    }
    // セッション開設失敗は再試行表示する。
    final sessionError = _sessionError;
    if (sessionError != null) {
      return PlayerRetryView(
        message: sessionError,
        onRetry: _open,
        backFallbackPath: '/tv',
      );
    }
    final jikkyo = _jikkyo;
    return ListenableBuilder(
      listenable: _playback,
      builder: (context, _) {
        // 設定ボタンだけが画質を購読する (`_LiveSettingsButton` 参照)。
        // 映像まで作り直されないよう、購読はボタンの中に閉じる。
        Widget settingsButton() => _LiveSettingsButton(
          player: _playback.player,
          dualMonoChannel: _playback.dualMonoChannel,
          onAudioSelected: _playback.selectAudio,
          audioLayout: _audioLayout,
          danmakuSupported: jikkyo.isSupported,
          danmakuPreferences: _playback.danmakuPreferences.value,
          onDanmakuPreferencesChanged: _playback.setDanmakuPreferences,
          showQualityMenu: widget.showQualityMenu,
        );
        return PlayerVideoView(
          videoController: _playback.videoController,
          topButtonBar: buildPlayerTopButtonBar(
            title: widget.title,
            backFallbackPath: '/tv',
          ),
          layout: PlayerControlsLayout.live,
          livePrimaryButtonBar: [
            const Spacer(flex: 2),
            _ChannelZapButton(
              channel: widget.item.channel,
              isNext: false,
            ),
            const Spacer(),
            const MaterialPlayOrPauseButton(iconSize: 56.0),
            const Spacer(),
            _ChannelZapButton(channel: widget.item.channel, isNext: true),
            const Spacer(flex: 2),
          ],
          // 下部バーは「字幕 → 設定 → フルスクリーン」の並び。
          liveBottomButtonBar: [
            const Spacer(),
            SubtitleToggleButton(
              enabled: _playback.subtitlesEnabled,
              onToggled: _playback.toggleSubtitles,
            ),
            settingsButton(),
            const MaterialFullscreenButton(),
          ],
          liveDesktopBottomButtonBar: [
            _ChannelZapButton(
              channel: widget.item.channel,
              isNext: false,
            ),
            const MaterialDesktopPlayOrPauseButton(),
            _ChannelZapButton(channel: widget.item.channel, isNext: true),
            const MaterialDesktopVolumeButton(),
            const Spacer(),
            SubtitleToggleButton(
              enabled: _playback.subtitlesEnabled,
              onToggled: _playback.toggleSubtitles,
            ),
            settingsButton(),
            const MaterialDesktopFullscreenButton(),
          ],
          danmaku: jikkyo.isSupported
              ? JikkyoDanmakuLayer(
                  displayAspect: _playback.videoDisplayAspect,
                  child: JikkyoDanmakuOverlay(
                    controller: jikkyo,
                    store: widget.danmakuStore,
                    clock: widget.danmakuClock,
                    preferences: _playback.danmakuPreferences,
                  ),
                )
              : null,
          errorMessage: _playback.errorMessage,
          onRetry: _open,
        );
      },
    );
  }
}
