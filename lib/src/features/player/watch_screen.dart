import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/settings/app_settings.dart';
import '../../core/network/dio_provider.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/tv_providers.dart';
import 'jikkyo_comment_controller.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'live_psi_controller.dart';
import 'live_session.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
import 'player_playback_controller.dart';
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
/// 再生UIはmedia_kit標準 (`AdaptiveVideoControls`) を使う。戻るボタン・番組名・
/// 画質切替ボタンはAppBarではなく、標準コントロールの上部ボタンバーに載せる
/// ([buildPlayerTopButtonBar])。ライブのためシークバー・シーク系ジェスチャは
/// 無効化する ([PlayerControlsLayout.live])。
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(nowOnAirChannelsProvider);
    final settings = ref.watch(appSettingsProvider).value;
    final backendType = settings?.backendType ?? BackendType.mirakurun;

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
          showQualityMenu: backendType.supportsLiveQualitySelection,
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

  /// EIT[p/f] の取得状態。KonomiTV時のみ非null。[_LivePlayerState] が更新する。
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

/// 画質切替ボタンだけが画質を購読する。
///
/// 映像側で購読すると画質表示の更新のたびに映像まで作り直されるため、ここに
/// 切り出す (`buildPlayerTopButtonBar` の説明を参照)。
class _LiveQualityButton extends ConsumerWidget {
  const _LiveQualityButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(tvRepositoryProvider);
    return QualityMenuButton(
      current: ref.watch(watchQualityProvider),
      qualities: repository.getLiveQualities(),
      onSelected: (quality) =>
          ref.read(watchQualityProvider.notifier).setQuality(quality),
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
      data: (live) => _LivePlayer(
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
        psiNotifier: _psiNotifier,
        // KonomiTVは `original` (生放送TS) のときだけデインタレースする。
        // Mirakurun (`decode=1` 固定) も生放送TSのためデインタレースする。
        // トランスコード済み画質はプログレッシブのため不要。
        deinterlace: widget.showQualityMenu
            ? ref.read(tvRepositoryProvider).isOriginalLiveQuality(live.qualityLabel)
            : true,
      ),
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
    required this.psiNotifier,
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

  /// 最新の EIT[p/f] 取得状態の通知先。[_WatchLayoutState] が持つ。
  final ValueNotifier<LivePsiController?> psiNotifier;

  @override
  State<_LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<_LivePlayer> {
  late final PlayerPlaybackController _playback =
      PlayerPlaybackController(seekToLiveEdgeOnResume: true);

  /// EIT[p/f] の接続。セッション確立後に作る。
  LivePsiController? _psi;

  /// 再生セッション (mpvが開くURL+EIT用パケット列)。
  LiveSession? _session;

  /// セッション開設中かどうか。開設完了まで映像の代わりに読み込み表示する。
  bool _sessionLoading = true;

  /// セッション開設の失敗内容。null以外は再試行表示する。
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  JikkyoCommentController get _jikkyo => widget.controller;

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
    _psi?.dispose();
    _psi = null;
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
        return PlayerVideoView(
          videoController: _playback.videoController,
          topButtonBar: buildPlayerTopButtonBar(
            title: widget.title,
            backFallbackPath: '/tv',
            player: _playback.player,
            dualMonoChannel: _playback.dualMonoChannel,
            onAudioSelected: _playback.selectAudio,
            danmakuSupported: jikkyo.isSupported,
            danmakuEnabled: _playback.danmakuEnabled,
            onDanmakuToggled: _playback.toggleDanmaku,
            trailing: [
              // 画質ボタンだけが画質を購読する (`_LiveQualityButton` 参照)。
              if (widget.showQualityMenu) const _LiveQualityButton(),
            ],
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
          liveBottomButtonBar: const [
            Spacer(),
            MaterialFullscreenButton(),
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
            const MaterialDesktopFullscreenButton(),
          ],
          danmaku: jikkyo.isSupported
              ? JikkyoDanmakuLayer(
                  displayAspect: _playback.videoDisplayAspect,
                  child: JikkyoDanmakuOverlay(
                    controller: jikkyo,
                    enabled: _playback.danmakuEnabled,
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
