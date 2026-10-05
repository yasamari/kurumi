import 'dart:async';
import 'dart:math';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';

import '../../core/pip/pip_mode.dart';
import '../../core/settings/app_settings.dart';
import '../../core/widgets/program_detail_body.dart';
import '../../domain/entities/video_program.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../videos/videos_providers.dart';
import 'audio_switch.dart';
import 'comment_list_panel.dart';
import 'danmaku_settings.dart';
import 'jikkyo_comment_source.dart';
import 'jikkyo_danmaku_item.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'jikkyo_past_comment_controller.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
import 'player_playback_controller.dart';
import 'player_settings_menu.dart';
import 'player_split_layout.dart';
import 'player_status_views.dart';
import 'player_video_view.dart';
import 'program_info_panel.dart';

/// 弾幕時計と再生位置の許容ずれ。外挿で滑らかに進め、超えたら補正する。
const _danmakuDriftThresholdMs = 400;

/// PiP ウィンドウの ±10 秒送り。`mediaWithSeek10` 相当のボタンに使う。
const _pipSeekStep = Duration(seconds: 10);

/// 弾幕ストアの保持期間。番組尺 + 余裕 (横流し・静止の表示期間分を十分上回る)。
int _danmakuRetentionMs(VideoProgram video) {
  final start = video.recordedFile?.recordingStartTime ?? video.startAt;
  final end = video.recordedFile?.recordingEndTime ?? video.endAt;
  return end.difference(start).inMilliseconds +
      const Duration(seconds: 30).inMilliseconds;
}
/// HLS視聴セッション ID を生成する。クライアント側で適宜生成した
/// ランダム値でよく、衝突しなければ形式は問わない (32桁hex)。
String generateVideoSessionId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// 録画再生画面。録画番組の再生遷移先 (`/videos/:videoId/play`)。
///
/// ライブ視聴 (`/watch/:channelId`) と同様、シェルの外側・root Navigator上に
/// 積み、ナビゲーションは表示しない。シーク有効の標準コントロールを使い
/// ([PlayerControlsLayout.seekable])、過去ログコメントを再生位置に追従して
/// 弾幕表示する。
class VideoPlayScreen extends ConsumerWidget {
  const VideoPlayScreen({super.key, required this.videoId});

  final int videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(videoDetailProvider(videoId));

    return detail.when(
      loading: () => const PlayerPlaceholderScaffold(
        backFallbackPath: '/videos',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return PlayerPlaceholderScaffold(
            backFallbackPath: '/videos',
            child: _SettingsGuide(
              onOpenSettings: () => context.go('/settings'),
            ),
          );
        }
        return PlayerPlaceholderScaffold(
          backFallbackPath: '/videos',
          child: PlayerRetryView(
            message: '$error',
            onRetry: () => ref.invalidate(videoDetailProvider(videoId)),
          ),
        );
      },
      data: (video) => _VideoPlayBody(video: video),
    );
  }
}

class _SettingsGuide extends StatelessWidget {
  const _SettingsGuide({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'サーバーが設定されていません',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onOpenSettings,
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }
}

/// 画質に応じたストリームを解決し、プレイヤーを載せる。
///
/// URL が変わったら `_VideoPlayer` を作り直す (画質切替対応)。
/// セッションIDは `_VideoPlayer` の State が持ち、作り直しのたびに
/// 採番し直す。
class _VideoPlayBody extends ConsumerWidget {
  const _VideoPlayBody({required this.video});

  final VideoProgram video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(videoPlayQualityProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: _VideoPlayer(
        key: ValueKey('$quality:${video.id}'),
        video: video,
        quality: quality,
      ),
    );
  }
}

/// 録画再生の映像スロットを所有する。
///
/// mpv のプレイヤーとエラー判定は [PlayerPlaybackController] が持つ (向きに
/// 依存しない位置なので、画面回転で作り直されても再生は保たれる)。HLSセッション
/// の keep-alive と過去ログコメントの接続 ([JikkyoPastCommentController]) は
/// ここが持つ。配置は [PlayerSplitLayout] に任せ、向きでサブツリーごと作り
/// 直されないようにしている。
class _VideoPlayer extends ConsumerStatefulWidget {
  const _VideoPlayer({
    super.key,
    required this.video,
    required this.quality,
  });

  final VideoProgram video;
  final String quality;

  @override
  ConsumerState<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends ConsumerState<_VideoPlayer> {
  /// 表示設定は `AppSettings` から読む。プレイヤーはベースURLが読めていないと
  /// 開けないため、到達時には設定の読み込みが済んでいる。
  late final PlayerPlaybackController _playback = PlayerPlaybackController(
    initialDanmakuPreferences: danmakuPreferencesOf(
      ref.read(appSettingsProvider).value,
    ),
    initialSubtitlesEnabled:
        ref.read(appSettingsProvider).value?.subtitlesEnabled ??
        defaultSubtitlesEnabled,
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
  );
  late final JikkyoPastCommentController _pastComments;
  late final String _sessionId;

  /// 弾幕の共有状態。向きに依存しない位置なので、画面回転・フルスクリーンで
  /// 作り直されても描画中の弾幕が保たれる ([JikkyoDanmakuOverlay] 参照)。
  late final DanmakuClock _danmakuClock =
      DanmakuClock(initialMs: 0, running: false);
  late final DanmakuStore<int> _danmakuStore =
      DanmakuStore<int>(retentionMs: _danmakuRetentionMs(widget.video));

  VideoStreamInfo? _stream;
  String? _streamError;
  Timer? _keepAliveTimer;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<Duration>? _danmakuPositionSub;

  /// 弾幕時計の駆動条件の最新値 ([danmakuClockShouldRun] の入力)。
  bool _playingForDanmaku = false;
  bool _bufferingForDanmaku = false;

  @override
  void initState() {
    super.initState();
    _sessionId = generateVideoSessionId();
    // PiP ウィンドウのボタン (再生/一時停止) と自動 PiP を有効にする。解除は
    // `dispose` 側 ([PipMode.disable] のコメントを参照)。
    unawaited(
      PipMode.instance.enable(
        owner: this,
        actions: PipActionsLayout.mediaOnlyPause,
        onAction: _onPipAction,
      ),
    );
    try {
      _stream = ref.read(videoRepositoryProvider).getVideoStream(
        videoId: widget.video.id,
        quality: widget.quality,
        sessionId: _sessionId,
      );
    } on BackendUnconfiguredException {
      _streamError = 'サーバーが設定されていません';
    }
    _pastComments = JikkyoPastCommentController(video: widget.video);
    _pastComments.start();
    // 弾幕時計は再生位置に追従させる。位置通知の間は壁時計で外挿して滑らかに
    // 進め、ずれが開いたら補正する。一時停止・バッファ中は凍結する。
    _playingSub = _playback.player.stream.playing.listen(_onPlayingForDanmaku);
    _bufferingSub =
        _playback.player.stream.buffering.listen(_onBufferingForDanmaku);
    _danmakuPositionSub =
        _playback.player.stream.position.listen(_onPositionForDanmaku);
    if (_stream != null) {
      _startKeepAlive();
      _initialize();
    }
  }

  /// HLSセッションの維持を開始する。ダウンロード再生では不要。
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    if (_stream?.isHls != true) return;
    _keepAliveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _keepAlive(),
    );
  }

  Future<void> _keepAlive() async {
    if (!mounted) return;
    try {
      await ref.read(videoRepositoryProvider).keepVideoStreamAlive(
        videoId: widget.video.id,
        quality: widget.quality,
        sessionId: _sessionId,
      );
    } catch (_) {
      // 維持失敗は再生エラーとして表面化するためここでは無視する。
    }
  }

  /// mpvオプションを適用してから映像を開く。
  ///
  /// デインタレースは `original` かつ動画コーデックが MPEG-2 のときだけ
  /// 有効化する。解除済みの動画に掛けても mpv は何もしないが、無駄な
  /// 判定を避けるため事前に絞る。
  ///
  /// オプションはデコーダ生成時に読まれるため、必ず `open` より前に渡す。
  Future<void> _initialize() async {
    final repository = ref.read(videoRepositoryProvider);
    await applyVideoMpvOptions(
      _playback.player,
      deinterlace: repository.needsVideoDeinterlace(
        isOriginal: repository.isOriginalVideoQuality(widget.quality),
        videoCodec: widget.video.recordedFile?.videoCodec,
      ),
    );
    if (!mounted) return;
    await _open();
  }

  Future<void> _open() async {
    final stream = _stream;
    if (stream == null) return;
    _playback.resetPlaybackState();
    await _playback.openUri(stream.url);
  }

  /// 再生状態に弾幕時計を追従させる。開始・停滞解消時は再生位置に合わせ直す。
  ///
  /// PiP ウィンドウの play/pause ボタンの状態もここで合わせる。
  void _onPlayingForDanmaku(bool playing) {
    PipMode.instance.reportPlaying(playing);
    _playingForDanmaku = playing;
    _syncDanmakuRunning();
  }

  /// PiP ウィンドウのボタン操作を mpv に反映する。
  ///
  /// 録画はシーク可能なので ±10 秒の送りも扱うが、PiP ウィンドウには
  /// 再生/一時停止だけを出す ([enable] で `mediaOnlyPause` を指定するため、
  /// 他の操作は来ない)。
  void _onPipAction(PipAction action) {
    final player = _playback.player;
    switch (action) {
      case PipAction.play:
        unawaited(player.play());
      case PipAction.pause:
        unawaited(player.pause());
      case PipAction.rewind:
        unawaited(player.seek(player.state.position - _pipSeekStep));
      case PipAction.forward:
        unawaited(player.seek(player.state.position + _pipSeekStep));
      case PipAction.previous:
      case PipAction.next:
      case PipAction.live:
        // PiP ウィンドウにはこれらは出さない。
        break;
    }
  }

  /// バッファ (`paused-for-cache`) に弾幕時計を追従させる。停滞中は映像と
  /// 一緒にスクロールを止める。`playing` は停滞で変わらないため別途購読する。
  void _onBufferingForDanmaku(bool buffering) {
    _bufferingForDanmaku = buffering;
    _syncDanmakuRunning();
  }

  void _syncDanmakuRunning() {
    if (!mounted) return;
    if (danmakuClockShouldRun(
      playing: _playingForDanmaku,
      buffering: _bufferingForDanmaku,
    )) {
      _danmakuClock.seekTo(_playback.player.state.position.inMilliseconds);
      _danmakuClock.setRunning(true);
    } else {
      _danmakuClock.setRunning(false);
    }
  }

  /// 再生位置に弾幕時計を追従させる。外挿とのずれが開いたら補正する
  /// (シーク時は大きくずれるため、そのまま時計が飛ぶ)。
  void _onPositionForDanmaku(Duration position) {
    if (!mounted) return;
    final drift = position.inMilliseconds - _danmakuClock.nowMs;
    if (drift.abs() > _danmakuDriftThresholdMs) {
      _danmakuClock.seekTo(position.inMilliseconds);
    }
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _danmakuPositionSub?.cancel();
    // 自動 PiP と PiP ウィンドウのボタンを戻す。停止の待たずに抜ける。
    // 画質変更で新旧画面の破棄順が入れ替わっても壊れないよう、`owner` で同一性
    // を判別する ([PipMode.disable] を参照)。
    unawaited(PipMode.instance.disable(owner: this));
    _pastComments.dispose();
    _danmakuClock.dispose();
    _danmakuStore.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null) {
      return PlayerPlaceholderScaffold(
        backFallbackPath: '/videos',
        child: _SettingsGuide(
          onOpenSettings: () => context.go('/settings'),
        ),
      );
    }
    // PiP への入退室を購読する。向きと同じく親を差し替えず、矩形と情報パネルの
    // 有無だけを変える (`PipWidget` のように `child`/`pipChild` を入れ替えると
    // この State と mpv のプレイヤーが失われる)。
    return ValueListenableBuilder<bool>(
      valueListenable: PipMode.instance.active,
      builder: (context, pictureInPicture, _) =>
          _buildLayout(pictureInPicture),
    );
  }

  Widget _buildLayout(bool pictureInPicture) {
    final pastComments = _pastComments;
    final video = ListenableBuilder(
      listenable: _playback,
      builder: (context, _) {
        // 下部バーは「字幕 → 設定 → PiP → フルスクリーン」の並び。録画の下端は
        // media_kit の既定構成に字幕・設定・PiP を足す。
        Widget settingsButton() => _VideoSettingsButton(
          player: _playback.player,
          dualMonoChannel: _playback.dualMonoChannel,
          onAudioSelected: _playback.selectAudio,
          danmakuSupported: pastComments.isSupported,
          danmakuPreferences: _playback.danmakuPreferences.value,
          onDanmakuPreferencesChanged: _playback.setDanmakuPreferences,
          quality: widget.quality,
        );
        return PlayerVideoView(
          videoController: _playback.videoController,
          topButtonBar: buildPlayerTopButtonBar(
            title: widget.video.title,
            backFallbackPath: '/videos',
          ),
          layout: PlayerControlsLayout.seekable,
          // PiP 中は標準コントロールを出さない (操作はシステムの PiP ボタンと
          // 画面タップで戻ることになり、Flutter 側では触れないため)。
          showControls: !pictureInPicture,
          seekableBottomButtonBar: [
            const MaterialPositionIndicator(),
            const Spacer(),
            SubtitleToggleButton(
              enabled: _playback.subtitlesEnabled,
              onToggled: _playback.toggleSubtitles,
            ),
            settingsButton(),
            const PipModeButton(),
            const MaterialFullscreenButton(),
          ],
          seekableDesktopBottomButtonBar: [
            const MaterialDesktopSkipPreviousButton(),
            const MaterialDesktopPlayOrPauseButton(),
            const MaterialDesktopSkipNextButton(),
            const MaterialDesktopVolumeButton(),
            const MaterialDesktopPositionIndicator(),
            const Spacer(),
            SubtitleToggleButton(
              enabled: _playback.subtitlesEnabled,
              onToggled: _playback.toggleSubtitles,
            ),
            settingsButton(),
            const PipModeButton(),
            const MaterialDesktopFullscreenButton(),
          ],
          danmaku: pastComments.isSupported
              ? JikkyoDanmakuLayer(
                  displayAspect: _playback.videoDisplayAspect,
                  child: JikkyoDanmakuOverlay(
                    controller: pastComments,
                    store: _danmakuStore,
                    clock: _danmakuClock,
                    preferences: _playback.danmakuPreferences,
                    birthMsOf: (comment) => danmakuBirthMsOf(
                      comment: comment,
                      syncStart: pastComments.syncStart,
                    ),
                  ),
                )
              : null,
          errorMessage: _playback.errorMessage,
          onRetry: _open,
        );
      },
    );
    // 映像は黒帯、情報パネルはテーマの地色で描画する。向きで `Row`/`Column` を
    // 出し分けると映像のサブツリーごと破棄される (画面回転と、media_kit の
    // フルスクリーンでウィンドウサイズが変わる°) ので [PlayerSplitLayout] に
    // 任せる (同ウィジェットのコメントを参照)。
    //
    // PiP 中は情報パネルを描かない。不可視のまま載せるとコメント一覧が再生位置
    // 通知のたびに作り直し・移動を続け、映像のフレームを奪うため。
    return PlayerSplitLayout(
      pictureInPicture: pictureInPicture,
      video: video,
      info: pictureInPicture
          ? const SizedBox.shrink()
          : Container(
              color: Theme.of(context).colorScheme.surface,
              // 情報パネルはタブ選択だけを購読する別ウィジェットに切り出す。
              // 映像側で購読するとタブ切替のたびに映像 (`Video`) まで作り直され、
              // 内部の表示パラメータ通知が飛んで映像・弾幕が一瞬止まる (ライブの
              // `_WatchInfoPanel` と同じ理由)。
              child: _PlayInfoPanel(
                video: widget.video,
                comments: pastComments,
                syncStart: pastComments.syncStart,
                positionStream: _playback.position,
              ),
            ),
    );
  }
}

/// 画質切替を含む設定ボタン。画質は親 ([_VideoPlayBody]) が購読し、URL変更で
/// プレイヤーごと作り直すため、ここでは購読しない。
class _VideoSettingsButton extends ConsumerWidget {
  const _VideoSettingsButton({
    required this.player,
    required this.dualMonoChannel,
    required this.onAudioSelected,
    required this.danmakuSupported,
    required this.danmakuPreferences,
    required this.onDanmakuPreferencesChanged,
    required this.quality,
  });

  final Player player;
  final DualMonoChannel? dualMonoChannel;
  final ValueChanged<AudioChoice> onAudioSelected;
  final bool danmakuSupported;

  /// 弾幕の表示設定 (メニューを開いた時点の値)。実体 (_playback) は購読しない
  /// (購読すると映像まで作り直される)。
  final DanmakuPreferences danmakuPreferences;

  /// 弾幕の表示設定を変えたときのコールバック。永続化まで行う。
  final ValueChanged<DanmakuPreferences> onDanmakuPreferencesChanged;

  /// 現在再生している画質。
  final String quality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(videoRepositoryProvider);
    // notifier は build 時 (＝ボタンが載っている間) に確保する。メニュー選択は
    // ボタン破棄後 (コントロール自動非表示) に起きうるため、コールバック内で
    // `ref.read` すると例外で画質が切り替わらない。notifier は keepAlive のため
    // ボタン破棄後も有効 ([videoPlayQualityProvider] 参照)。
    final qualityNotifier = ref.read(videoPlayQualityProvider.notifier);
    return PlayerSettingsButton(
      player: player,
      dualMonoChannel: dualMonoChannel,
      onAudioSelected: onAudioSelected,
      danmakuSupported: danmakuSupported,
      danmakuPreferences: danmakuPreferences,
      onDanmakuPreferencesChanged: onDanmakuPreferencesChanged,
      qualityCurrent: quality,
      qualities: [
        if (repository.isOriginalVideoQuality('original')) 'original',
        ...repository.getVideoQualities(),
      ].where((q) => q.isNotEmpty).toList(),
      onQualitySelected: (quality) => qualityNotifier.setQuality(quality),
    );
  }
}

/// 録画再生画面用の情報パネル。番組情報と実況コメントの2タブ。
///
/// チャンネル切替タブは無い (録画はチャンネル送りしない)。
/// 選択位置は `videoInfoTabProvider` (keepAlive) が持つ。
/// コメント一覧は再生位置に追従する ([CommentListPanel] の録画モード)。
/// コメントタブは選択されている間だけ載せる。不可視のまま載せると再生位置
/// 通知のたびに作り直し・移動を続けて映像のフレームを奪う (ライブの
/// [ProgramInfoPanel] と同じ)。番組情報は静的なので載せたままにする
/// (スクロール位置の保持のため。ライブと同じ)。
class _PlayInfoPanel extends ConsumerWidget {
  const _PlayInfoPanel({
    required this.video,
    required this.comments,
    required this.syncStart,
    required this.positionStream,
  });

  final VideoProgram video;
  final JikkyoCommentSource comments;

  /// 再生位置0に対応する録画開始時刻。
  final DateTime syncStart;

  /// 再生位置のストリーム。
  final Stream<Duration> positionStream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(videoInfoTabProvider);
    return PlayerInfoTabs(
      tabCount: 2,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) =>
          ref.read(videoInfoTabProvider.notifier).select(index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.tv_outlined),
          selectedIcon: Icon(Icons.tv),
          label: '番組情報',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'コメント',
        ),
      ],
      children: [
        // 番組情報の中身はビデオ詳細と共有する [ProgramDetailBody]。
        // 静的なので載せたままにし、スクロール位置を保つ (ライブと同じ)。
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ProgramDetailBody(
            channel: video.channel,
            program: video.toTvProgram(),
            subtitle: video.subtitle,
          ),
        ),
        // コメント一覧は選択中だけ載せる: 載せたままだと不可視の一覧が毎回の
        // 再生位置通知で作り直し・移動を続け、映像のフレームを奪う。戻った
        // ときは追従ON・再生位置着地で作り直される (ライブと同じ)。
        if (selectedIndex == 1)
          CommentListPanel(
            controller: comments,
            syncStart: syncStart,
            positionStream: positionStream,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
