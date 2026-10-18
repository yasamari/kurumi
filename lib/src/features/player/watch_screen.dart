import 'dart:async';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';

import '../../core/pip/pip_mode.dart';
import '../../core/media/kurumi_audio_handler.dart';
import '../../core/media/media_control_target.dart';
import '../../core/media/now_playing_item.dart';
import '../../core/settings/app_settings.dart';
import '../../core/network/dio_provider.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/ts/audio_layout.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/entities/channel_type.dart';
import '../../domain/entities/live_stream.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/epg_providers.dart';
import '../tv/tv_providers.dart';
import 'audio_switch.dart';
import 'danmaku_settings.dart';
import 'jikkyo_comment_controller.dart';
import 'jikkyo_danmaku_item.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'live_psi_controller.dart';
import 'live_session.dart';
import 'mpv_options.dart';
import 'player_capture.dart';
import 'player_control_buttons.dart';
import 'player_playback_controller.dart';
import 'player_providers.dart';
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
        (settings) => (settings.value?.backendType ?? BackendType.mirakurun)
            .supportsLiveQualitySelection,
      ),
    );

    // Mirakurun は毎分再計算・数時間ごとに裏更新が走る。そのたびに読み込み
    // 表示に戻すと映像スロットが `PlayerLoadingView` に差し替わり、
    // `_LivePlayerState` ごと破棄されて mpv が開き直される。
    // 前回データを出し続ける (初回読み込みとエラー表示はそのまま)。
    return channels.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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
            // 同期 provider は keepAlive のため、再取得には明示の invalidate
            // が要る (一覧だけではキャッシュされたエラーのままになる)。
            onRetry: () {
              ref.invalidate(mirakurunEpgSyncProvider);
              ref.invalidate(nowOnAirChannelsProvider);
            },
          ),
        );
      },
      data: (items) {
        final item = items.where((e) => e.channel.id == channelId).firstOrNull;
        if (item == null) {
          return PlayerPlaceholderScaffold(
            child: PlayerRetryView(
              message: 'チャンネルが見つかりません',
              onRetry: () {
                ref.invalidate(mirakurunEpgSyncProvider);
                ref.invalidate(nowOnAirChannelsProvider);
              },
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

/// 同一チャンネル種別内 (地デジなら地デジのみ) のチャンネル ID を表示順に並べる。
///
/// 前/次チャンネル切替の行き先はこれで求めた並びに対して計算する。
List<String> channelIdsOfSameType(List<ChannelItem> items, ChannelType type) {
  return items
      .where((item) => item.channel.channelType == type)
      .map((item) => item.channel.id)
      .toList();
}

/// 前/次チャンネル切替の行き先のチャンネル ID。
///
/// [channelIds] の順序で移動し、末尾では反対端に回り込む。切替できないとき
/// (候補が1件以下・現在チャンネルが一覧に無い) は null。
///
/// 標準コントロールのボタンと PiP ウィンドウのボタンが同じ規則を共有する。
String? channelZapId(
  List<String> channelIds,
  String currentId, {
  required bool isNext,
}) {
  if (channelIds.length <= 1) return null;
  final index = channelIds.indexOf(currentId);
  if (index < 0) return null;
  final target = isNext
      ? (index + 1) % channelIds.length
      : (index - 1 + channelIds.length) % channelIds.length;
  return channelIds[target];
}

/// チャンネルを切り替える。
///
/// 視聴画面はシェル外・root Navigator 上の1ページとして積まれているので、
/// **`pushReplacement` で「自分自身」だけを差し替える。**
///
/// - `go` だとページスタック**全体**が置き換わり、下にテレビ画面が残らない。
///   戻る対象がなくなって、**Android のシステム戻る でアプリが閉じてしまう**
///   (画面左上の戻るボタンは `canPop` が false なので `go('/tv')` に
///   フォールバックするので動く一方、システム側だけが落ちる。実測した症状)。
/// - `push` だと前の視聴画面がスタックに残り、破棄されないので mpv のプレイヤー
///   と再生セッション ([LiveSession])、実況コメントのソケットが解放されない。
///
/// 差し替えは新しい page key で行うため、旧視聴画面の State は確実に dispose
/// される (新旧の破棄順は `owner` の同一性で吸収する — [PipMode.disable] を参照)。
void zapToChannel(BuildContext context, String channelId) {
  context.pushReplacement('/watch/$channelId');
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
    final items = ref.watch(nowOnAirChannelsProvider).value;
    final ids = items == null
        ? const <String>[]
        : channelIdsOfSameType(items, channel.channelType);
    final target = channelZapId(ids, channel.id, isNext: isNext);
    return IconButton(
      icon: Icon(isNext ? Icons.skip_next : Icons.skip_previous),
      color: Colors.white,
      tooltip: isNext ? '次のチャンネル' : '前のチャンネル',
      onPressed: target == null ? null : () => zapToChannel(context, target),
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
    required this.captures,
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

  /// キャプチャ一覧の通知元。[_WatchLayoutState] が所有する。
  final ValueListenable<List<CaptureEntry>> captures;

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
      captures: captures,
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
      // KonomiTV は番組境界ごとに再取得で作り直されるため、前回データを
      // 出し続ける (読み込み表示に戻すと `_LivePlayerState` ごと破棄される)。
      body: stream.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
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
  late final DanmakuStore<int> _danmakuStore = DanmakuStore<int>(
    retentionMs: _liveDanmakuRetentionMs,
  );

  /// 最新の EIT[p/f] 取得状態。`_LivePlayerState` が開設のたびに更新する。
  final ValueNotifier<LivePsiController?> _psiNotifier = ValueNotifier(null);

  /// キャプチャ一覧。チャンネル切り替えで破棄される (セッション内のみ保持)。
  final ValueNotifier<List<CaptureEntry>> _captures = ValueNotifier([]);

  /// 弾幕付きキャプチャ用の撮像境界のキー。回転で生き残る位置で持つ。
  final GlobalKey _danmakuBoundaryKey = GlobalKey();

  /// フルスクリーン側の撮像境界のキー。通常表示とフルスクリーンは同じ
  /// `controls` ビルダーから別サブツリーとして同時に組まれるため、同じ
  /// [GlobalKey] を両方に置くと通常側の弾幕がフルスクリーン復帰後に消える
  /// (`JikkyoDanmakuLayer` 参照)。回転で生き残る位置で持つ。
  final GlobalKey _danmakuFullscreenBoundaryKey = GlobalKey();

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
    _captures.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PiP への入退室を購読する。向きと同じく親を差し替えず、矩形と情報パネルの
    // 有無だけを変える (`PipWidget` のように `child`/`pipChild` を入れ替えると
    // `_LivePlayer` の State が破棄され、mpv と PSI 取得が落ちる)。
    return ValueListenableBuilder<bool>(
      valueListenable: PipMode.instance.active,
      builder: (context, pictureInPicture, _) => _buildLayout(pictureInPicture),
    );
  }

  Widget _buildLayout(bool pictureInPicture) {
    // セッション開設 (tap起動) 中は映像側だけ読み込み表示し、
    // 情報パネルは出したままにする。
    // KonomiTV は番組境界ごとに再取得で作り直されるため、前回データを
    // 出し続ける (読み込み表示に戻すと `_LivePlayerState` ごと破棄されて
    // mpv が開き直される)。画質切替はURLキーで作り直されるため影響しない。
    final video = widget.stream.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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
          pictureInPicture: pictureInPicture,
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
          danmakuBoundaryKey: _danmakuBoundaryKey,
          danmakuFullscreenBoundaryKey: _danmakuFullscreenBoundaryKey,
          captures: _captures,
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
          deinterlace: widget.showQualityMenu
              ? ref
                    .read(tvRepositoryProvider)
                    .isOriginalLiveQuality(live.qualityLabel)
              : true,
        );
      },
    );
    // 映像は黒帯、情報パネルはテーマの地色で描画する。向きで `Row`/`Column` を
    // 出し分けると映像のサブツリーごと破棄される (画面回転と、media_kit の
    // フルスクリーンでウィンドウサイズが変わる°) ので [PlayerSplitLayout] に
    // 任せる (同ウィジェットのコメントを参照)。
    //
    // パネルは常に渡す。**表示しないとき (PiP 中・デスクトップでパネルを隠した
    // とき) は `PlayerSplitLayout` が載せない** — 矩形を 0 にしただけで載せると
    // 子ツリーが組まれたまま、PSI 更新やコメント一覧の作り直しを裏で続ける。
    return PlayerSplitLayout(
      pictureInPicture: pictureInPicture,
      // 値ではなく notifier を渡す。`PlayerSplitLayout` 自身が購読するため、
      // ここではレイアウトだけが変わって映像は作り直されない。
      infoVisible: ref.watch(infoPanelVisibilityProvider).visible,
      video: video,
      info: Container(
        color: Theme.of(context).colorScheme.surface,
        child: ValueListenableBuilder<LivePsiController?>(
          valueListenable: _psiNotifier,
          builder: (context, psi, _) {
            return _WatchInfoPanel(
              item: widget.item,
              controller: _jikkyo,
              psi: psi,
              // チャンネルの切替は視聴画面だけを差し替える。旧画面の Player と
              // 実況コメント・番組情報のソケットはこれで解放される
              // ([zapToChannel] のコメントを参照)。
              onChannelSelected: (id) => zapToChannel(context, id),
              captures: _captures,
            );
          },
        ),
      ),
    );
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
/// **購読はしない。** 画質の購読は [_LiveSettingsButton]、情報パネルのタブ
/// 選択は [_WatchInfoPanel] がそれぞれ持つため、ここでは購読するものが無い。
/// PiP ウィンドウのチャンネル送りだけ `ref.read` で一覧を取り出す (build の
/// 外側なので何も作り直さない)。
/// セッションを持ち直す必要があるため `ConsumerStatefulWidget` にする。
class _LivePlayer extends ConsumerStatefulWidget {
  const _LivePlayer({
    super.key,
    required this.sessionFactory,
    required this.pictureInPicture,
    required this.item,
    required this.title,
    required this.showQualityMenu,
    required this.deinterlace,
    required this.controller,
    required this.danmakuStore,
    required this.danmakuClock,
    required this.psiNotifier,
    required this.danmakuBoundaryKey,
    required this.danmakuFullscreenBoundaryKey,
    required this.captures,
    required this.danmakuPreferences,
    required this.subtitlesEnabled,
    required this.onDanmakuPreferencesChanged,
    required this.onSubtitlesEnabledChanged,
  });

  /// 再生セッション (mpvが開くURL+EIT用パケット列) を開く。
  final LiveSessionFactory sessionFactory;

  /// Android の PiP ウィンドウにいるか。標準コントロールを隠す。
  final bool pictureInPicture;

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

  /// 弾幕付きキャプチャ用の撮像境界のキー。[_WatchLayoutState] が所有する。
  final GlobalKey danmakuBoundaryKey;

  /// フルスクリーン側の撮像境界のキー。[_WatchLayoutState] が所有する。
  final GlobalKey danmakuFullscreenBoundaryKey;

  /// キャプチャ一覧の通知先。[_WatchLayoutState] が持つ。
  final ValueNotifier<List<CaptureEntry>> captures;

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
  ConsumerState<_LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends ConsumerState<_LivePlayer> {
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

  /// EIT[p/f] から得た現在番組のイベント ID。番組切り替わりの検出用。
  ///
  /// システム通知の番組名を追従させるためだけに持つ。映像の再構築には
  /// 関与しない ([_publishLiveItem] 参照)。
  int? _liveProgramEventId;

  @override
  void initState() {
    super.initState();
    // PiP ウィンドウのボタン (前/次チャンネル・再生/一時停止) と自動 PiP を有効に
    // する。解除は `dispose` 側 ([PipMode.disable] のコメントを参照)。
    unawaited(
      PipMode.instance.enable(
        owner: this,
        actions: PipActionsLayout.media,
        onAction: _onPipAction,
      ),
    );
    // システムのメディア操作 (通知・MPRIS・SMTC) の委譲先として登録する。
    // 解除は `dispose` 側 ([MediaControls.detach] のコメントを参照)。
    MediaControls.instance.attach(
      owner: this,
      target: _LiveMediaTarget(
        onPlay: () => _playback.player.play(),
        onPause: () => _playback.player.pause(),
        onZapNext: () => _zapChannel(isNext: true),
        onZapPrevious: () => _zapChannel(isNext: false),
      ),
    );
    _publishLiveItem();
    _reportLiveState();
    // `playing` はキャッシュ停滞で変わらないため、停滞検出は別途購読する。
    _playingSub = _playback.player.stream.playing.listen(_onPlayingForDanmaku);
    _bufferingSub = _playback.player.stream.buffering.listen(
      _onBufferingForDanmaku,
    );
    _initialize();
  }

  /// 再生状態に弾幕時計を追従させる。再開時は一時停止中の壁時計分だけ
  /// 進めてライブエッジに追従させる (停止中のコメントが一斉に現れないよう)。
  ///
  /// PiP ウィンドウの play/pause ボタンの状態もここで合わせる。
  void _onPlayingForDanmaku(bool playing) {
    PipMode.instance.reportPlaying(playing);
    if (!mounted) return;
    if (!playing && _playingForDanmaku) {
      _pausedAt = DateTime.now();
    }
    _playingForDanmaku = playing;
    _syncDanmakuRunning();
    _reportLiveState();
  }

  /// PiP ウィンドウのボタン操作を mpv とチャンネル切替に反映する。
  ///
  /// 前/次は標準コントロールのチャンネル送りと同じ規則
  /// ([channelZapId]) で `go` する。視聴画面ごと置き換わるため、旧画面の
  /// セッションと PSI 取得は解放される。
  void _onPipAction(PipAction action) {
    final player = _playback.player;
    switch (action) {
      case PipAction.play:
        unawaited(player.play());
      case PipAction.pause:
        unawaited(player.pause());
      case PipAction.previous:
        _zapChannel(isNext: false);
      case PipAction.next:
        _zapChannel(isNext: true);
      case PipAction.live:
      case PipAction.rewind:
      case PipAction.forward:
        // PiP ウィンドウにはこれらは出さない (`PipActionsLayout.media`)。
        break;
    }
  }

  /// PiP ウィンドウのチャンネル送り。行き先が無いときは何もしない。
  void _zapChannel({required bool isNext}) {
    if (!mounted) return;
    final items = ref.read(nowOnAirChannelsProvider).value;
    if (items == null) return;
    final target = channelZapId(
      channelIdsOfSameType(items, widget.item.channel.channelType),
      widget.item.channel.id,
      isNext: isNext,
    );
    if (target == null) return;
    zapToChannel(context, target);
  }

  /// バッファ (`paused-for-cache`) に弾幕時計を追従させる。停滞中は映像と
  /// 一緒にスクロールを止める。解消時は合わせ直さず壁時計で再開する
  /// (遅延分だけ映像に追従するため)。
  void _onBufferingForDanmaku(bool buffering) {
    if (!mounted) return;
    _bufferingForDanmaku = buffering;
    _syncDanmakuRunning();
    _reportLiveState();
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

  /// キャプチャを実行する。成功時は通知せず、キャプチャタブへ追加する。
  ///
  /// 撮影時の番組情報 (EIT[p/f] の現在番組) をスナップショットして EXIF に
  /// 入れる。EIT 未受信時はチャンネル名と撮影時刻で埋める。
  void _capture({required bool withDanmaku}) {
    final at = DateTime.now();
    final present = _psi?.present;
    final startAt = present?.startAt ?? at;
    final endAt = present?.endAt ?? at;
    unawaited(
      runPlayerCapture(
        context: context,
        player: _playback.player,
        withDanmaku: withDanmaku,
        danmakuBoundaryKey: widget.danmakuBoundaryKey,
        fullscreenDanmakuBoundaryKey: widget.danmakuFullscreenBoundaryKey,
        danmakuVisible:
            _jikkyo.isSupported &&
            _playback.danmakuPreferences.value.enabled &&
            _playback.videoDisplayAspect != null,
        metadata: CaptureMetadata(
          capturedAt: at,
          playbackPositionSec: present == null
              ? 0
              : at.difference(startAt).inMilliseconds / 1000,
          networkId: widget.item.channel.networkId,
          serviceId: widget.item.channel.serviceId,
          eventId: present?.eventId ?? 0,
          title: present?.title ?? widget.title,
          description: present?.description ?? '',
          startAt: startAt,
          endAt: endAt,
          durationSec: present == null
              ? 0
              : endAt.difference(startAt).inSeconds,
          isCaptionComposited: _playback.subtitlesEnabled.value,
        ),
        onCaptured: (entry) {
          if (!mounted) return;
          widget.captures.value = appendCaptureEntry(
            widget.captures.value,
            entry,
          );
        },
      ),
    );
  }

  /// キーボードショートカット。`c` でキャプチャ、`v` で弾幕付きキャプチャ。
  ///
  /// media_kit のフルスクリーンは別ルートになるためここでは効かず、
  /// ボタンを使う。設定メニューを開いている間はフォーカスが移るため
  /// 誤爆しない。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // 長押しのリピートでは連写しない。
    if (event is KeyRepeatEvent || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      _capture(withDanmaku: false);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      _capture(withDanmaku: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  /// EIT[p/f] の現在番組が切り替わったら、システム通知の番組名を追従させる。
  ///
  /// [_syncAudioLayout] と同じ PSI 通知で検出する。`notifyListeners` は起こさず、
  /// 通知への配信だけを行う (映像の再構築に巻き込まないため)。
  void _syncLiveProgram() {
    final present = _psi?.present;
    if (present?.eventId == _liveProgramEventId) return;
    _liveProgramEventId = present?.eventId;
    _publishLiveItem();
  }

  /// 現在の番組情報をシステム通知へ配信する。アルバムアートはチャンネルロゴ。
  ///
  /// EIT 未受信時はチャンネル名だけを載せる。`notifyListeners` は起こさない。
  void _publishLiveItem() {
    final handler = systemMediaHandler;
    if (handler == null) return;
    final channel = widget.item.channel;
    handler.publishItem(
      liveMediaItem(
        channelId: channel.id,
        channelTitle: widget.title,
        programTitle: _psi?.present?.title,
        artUri: artUriOf(channel.logoUrl),
      ),
    );
  }

  /// 再生・停滞状態をシステム通知へ配信する。`notifyListeners` は起こさない。
  void _reportLiveState() {
    systemMediaHandler?.reportLive(
      playing: _playingForDanmaku,
      buffering: _bufferingForDanmaku,
    );
  }

  /// mpvオプションを適用してから映像を開く。
  ///
  /// オプションはデコーダ生成時に読まれるため、必ず `open` より前に渡す。
  Future<void> _initialize() async {
    await applyLiveMpvOptions(
      _playback.player,
      deinterlace: widget.deinterlace,
    );
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
    _psi!.addListener(_syncLiveProgram);
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
    // システムのメディア操作の委譲を外す。本当に画面を離れたときだけ通知を
    // 消す (チャンネル切替では新画面が登録済みのため何もしない)。
    if (MediaControls.instance.detach(owner: this)) {
      systemMediaHandler?.deactivate();
    }
    // 自動 PiP と PiP ウィンドウのボタンを戻す。停止の待たずに抜ける。
    // チャンネル切替で新旧画面の破棄順が入れ替わっても壊れないよう、`owner` で
    // 同一性を判別する ([PipMode.disable] を参照)。
    unawaited(PipMode.instance.disable(owner: this));
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
    // 値ではなく notifier を参照だけ渡す (購読はボタンとレイアウトの中だけ)。
    final infoPanel = ref.watch(infoPanelVisibilityProvider);
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
        // キーボードショートカット (`c` / `v`) を受ける。フォーカスは奪わず
        // media_kit 標準の操作 (左右矢印のシークやスペースの一時停止) に譲る。
        // `autofocus` で奪うと内側の controls の `CallbackShortcuts` より
        // 手前でフォーカスし、標準操作が効かなくなる。`canRequestFocus: false`
        // なら祖先としてバブリングだけ受け、内側の操作と両立する。
        return Focus(
          canRequestFocus: false,
          onKeyEvent: _onKeyEvent,
          child: PlayerVideoView(
            videoController: _playback.videoController,
            topButtonBar: buildPlayerTopButtonBar(
              title: widget.title,
              backFallbackPath: '/tv',
            ),
            layout: PlayerControlsLayout.live,
            // PiP 中は標準コントロールを出さない (操作はシステムの PiP ボタンと
            // 画面タップで戻ることになり、Flutter 側では触れないため)。
            showControls: !widget.pictureInPicture,
            livePrimaryButtonBar: [
              const Spacer(flex: 2),
              _ChannelZapButton(channel: widget.item.channel, isNext: false),
              const Spacer(),
              const MaterialPlayOrPauseButton(iconSize: 56.0),
              const Spacer(),
              _ChannelZapButton(channel: widget.item.channel, isNext: true),
              const Spacer(flex: 2),
            ],
            // 下部バーは「キャプチャ → 弾幕付きキャプチャ → 字幕 → 設定 →
            // PiP → フルスクリーン」の並び。
            // (デスクトップは PiP の代わりに情報パネルの表示切替が入る)
            liveBottomButtonBar: [
              const Spacer(),
              CaptureButton(onPressed: () => _capture(withDanmaku: false)),
              DanmakuCaptureButton(
                onPressed: () => _capture(withDanmaku: true),
              ),
              SubtitleToggleButton(
                enabled: _playback.subtitlesEnabled,
                onToggled: _playback.toggleSubtitles,
              ),
              settingsButton(),
              const PipModeButton(),
              const MaterialFullscreenButton(),
            ],
            liveDesktopBottomButtonBar: [
              _ChannelZapButton(channel: widget.item.channel, isNext: false),
              const MaterialDesktopPlayOrPauseButton(),
              _ChannelZapButton(channel: widget.item.channel, isNext: true),
              const MaterialDesktopVolumeButton(),
              const Spacer(),
              CaptureButton(onPressed: () => _capture(withDanmaku: false)),
              DanmakuCaptureButton(
                onPressed: () => _capture(withDanmaku: true),
              ),
              SubtitleToggleButton(
                enabled: _playback.subtitlesEnabled,
                onToggled: _playback.toggleSubtitles,
              ),
              settingsButton(),
              const PipModeButton(),
              // デスクトップでは PiP ボタン (Android 専用) の場所 情報パネルを
              // 隠すボタンになる。
              InfoPanelToggleButton(
                visible: infoPanel.visible,
                onToggled: infoPanel.toggle,
              ),
              const MaterialDesktopFullscreenButton(),
            ],
            danmaku: jikkyo.isSupported
                ? JikkyoDanmakuLayer(
                    displayAspect: _playback.videoDisplayAspect,
                    repaintKey: widget.danmakuBoundaryKey,
                    fullscreenRepaintKey: widget.danmakuFullscreenBoundaryKey,
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
          ),
        );
      },
    );
  }
}

/// ライブ視聴のシステムメディア操作の委譲先。
///
/// 再生・停止は mpv、前/次は標準コントロールと同じチャンネル送り
/// ([channelZapId]) に流す。シークはライブでは対応しない。
class _LiveMediaTarget implements MediaControlTarget {
  _LiveMediaTarget({
    required this.onPlay,
    required this.onPause,
    required this.onZapNext,
    required this.onZapPrevious,
  });

  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final void Function() onZapNext;
  final void Function() onZapPrevious;

  @override
  Future<void> play() => onPlay();

  @override
  Future<void> pause() => onPause();

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> zapToNext() async => onZapNext();

  @override
  Future<void> zapToPrevious() async => onZapPrevious();

  @override
  bool get supportsSeek => false;

  @override
  bool get supportsZap => true;
}
