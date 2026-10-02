import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/widgets/program_detail_body.dart';
import '../../data/backends/konomi/konomi_video_stream.dart';
import '../../domain/entities/video_program.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../videos/videos_providers.dart';
import 'audio_switch.dart';
import 'comment_list_panel.dart';
import 'jikkyo_comment_source.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'jikkyo_past_comment_controller.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
import 'player_error.dart';

/// 録画再生画面。録画番組の再生遷移先 (`/videos/:videoId/play`)。
///
/// ライブ視聴 (`/watch/:channelId`) と同様、シェルの外側・root Navigator上に
/// 積み、ナビゲーションは表示しない。シーク有効の標準コントロールを使い、
/// 過去ログコメントを再生位置に追従して弾幕表示する。
class VideoPlayScreen extends ConsumerWidget {
  const VideoPlayScreen({super.key, required this.videoId});

  final int videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(videoDetailProvider(videoId));

    return detail.when(
      loading: () => const _PlaceholderScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return _PlaceholderScaffold(
            child: _SettingsGuide(
              onOpenSettings: () => context.go('/settings'),
            ),
          );
        }
        return _PlaceholderScaffold(
          child: _RetryError(
            message: '$error',
            onRetry: () => ref.invalidate(videoDetailProvider(videoId)),
          ),
        );
      },
      data: (video) => _VideoPlayBody(video: video),
    );
  }
}

/// まだプレイヤーを描画していない状態 (読み込み中・エラー) の土台。
class _PlaceholderScaffold extends StatelessWidget {
  const _PlaceholderScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned(
            left: 4,
            top: 4,
            child: SafeArea(
              child: PlayerBackButton(fallbackPath: '/videos'),
            ),
          ),
        ],
      ),
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

/// media_kitのPlayer/Controllerを所有するウィジェット。
///
/// 画面離脱・画質切替時に `dispose` し直す。HLSセッションの keep-alive と
/// 過去ログコメントの接続もここが持つ。向きに依存しない位置なので、
/// 画面回転で作り直されても再生・コメント取得は保たれる。
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
  late final Player _player;
  late final VideoController _controller;
  late final JikkyoPastCommentController _pastComments;
  late final String _sessionId;
  VideoStreamInfo? _stream;
  String? _streamError;

  /// 実況コメントの弾幕表示の on/off。向きに依存しない State に持たせる。
  bool _danmakuEnabled = true;

  /// 二重モノラルの復号チャンネル。null はステレオ (主＋副)。
  ///
  /// 画面回転ではこの State ごと保たれる。画質切替は URL 変更で
  /// `_VideoPlayer` ごと置き換わるため初期値に戻る。
  DualMonoChannel? _dualMonoChannel;

  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<AudioParams>? _audioParamsSub;
  Timer? _errorTimer;
  Timer? _keepAliveTimer;
  String? _pendingError;
  bool _isPlaying = false;
  bool _hasVideo = false;
  bool _hasAudio = false;
  String? _errorMessage;

  /// 映像の**表示**アスペクト比。ライブと同様、弾幕をレターボックスの
  /// 内側に収めるために使う ([videoDisplayAspectOf] 参照)。
  double? _videoDisplayAspect;

  @override
  void initState() {
    super.initState();
    _sessionId = generateVideoSessionId();
    try {
      _stream = ref.read(videoRepositoryProvider).getVideoStream(
            videoId: widget.video.id,
            quality: widget.quality,
            sessionId: _sessionId,
          );
    } on BackendUnconfiguredException {
      _streamError = 'サーバーが設定されていません';
    }
    _player = Player();
    _controller = VideoController(_player);
    _pastComments = JikkyoPastCommentController(
      player: _player,
      video: widget.video,
    );
    _pastComments.start();
    _errorSub = _player.stream.error.listen(_onPlayerError);
    _playingSub = _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _clearErrorIfRecovered();
    });
    _videoParamsSub = _player.stream.videoParams.listen((params) {
      if (hasValidVideoSize(dw: params.dw, dh: params.dh, w: params.w, h: params.h)) {
        _hasVideo = true;
        _clearErrorIfRecovered();
      }
      final aspect = videoDisplayAspectOf(
        aspect: params.aspect,
        w: params.w,
        h: params.h,
        dw: params.dw,
        dh: params.dh,
      );
      if (aspect == null || aspect == _videoDisplayAspect) return;
      if (!mounted) return;
      setState(() => _videoDisplayAspect = aspect);
    });
    _audioParamsSub = _player.stream.audioParams.listen((params) {
      if (hasValidAudioFormat(
        sampleRate: params.sampleRate,
        channelCount: params.channelCount,
      )) {
        _hasAudio = true;
        _clearErrorIfRecovered();
      }
    });
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
    await applyVideoMpvOptions(
      _player,
      deinterlace: needsVideoDeinterlace(
        isOriginal: widget.quality == originalKonomiVideoQuality,
        videoCodec: widget.video.recordedFile?.videoCodec,
      ),
    );
    if (!mounted) return;
    await _open();
  }

  Future<void> _open() async {
    final stream = _stream;
    if (stream == null) return;
    _errorTimer?.cancel();
    _errorTimer = null;
    _pendingError = null;
    _isPlaying = false;
    _hasVideo = false;
    _hasAudio = false;
    if (mounted) {
      setState(() => _errorMessage = null);
    }
    await _player.open(Media(stream.url.toString()));
  }

  /// `error` 受信時の処理。ライブと同様、再生中の一過性エラーは無視する。
  void _onPlayerError(String message) {
    if (message.isEmpty || !mounted) return;
    if (_isRecovered()) return;
    _pendingError = message;
    _errorTimer?.cancel();
    _errorTimer = Timer(playerErrorGracePeriod, () {
      if (!mounted) return;
      if (_isRecovered()) return;
      setState(() => _errorMessage = _pendingError);
      _pendingError = null;
    });
  }

  /// 再生が軌道に乗っていれば、表示中・表示待ちのエラーを取り下げる。
  void _clearErrorIfRecovered() {
    if (!_isRecovered()) return;
    _errorTimer?.cancel();
    _errorTimer = null;
    _pendingError = null;
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  bool _isRecovered() => isPlayerRecovered(
        isPlaying: _isPlaying,
        hasVideo: _hasVideo,
        hasAudio: _hasAudio,
      );

  /// 音声メニューの選択を反映する。
  ///
  /// トラック選択 (二重ステレオ) は mpv にそのまま委ねる。二重モノラルは
  /// デコーダオプションの切り替えになるため [applyDualMonoChannel] で
  /// 音声デコーダを作り直す。
  Future<void> _onAudioSelected(AudioChoice choice) async {
    switch (choice) {
      case AudioTrackChoice(:final trackId):
        await _player.setAudioTrack(AudioTrack(trackId, null, null));
      case DualMonoChoice(:final channel):
        setState(() => _dualMonoChannel = channel);
        await applyDualMonoChannel(_player, channel);
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _keepAliveTimer?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _videoParamsSub?.cancel();
    _audioParamsSub?.cancel();
    _pastComments.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null) {
      return _PlaceholderScaffold(
        child: _SettingsGuide(
          onOpenSettings: () => context.go('/settings'),
        ),
      );
    }
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final video = _buildVideo(context);
    final info = Container(
      color: Theme.of(context).colorScheme.surface,
      child: _VideoInfoPanel(
        video: widget.video,
        comments: _pastComments,
        syncStart: _pastComments.syncStart,
        positionStream: _player.stream.position,
        selectedIndex: ref.watch(videoInfoTabProvider),
        onDestinationSelected: (index) =>
            ref.read(videoInfoTabProvider.notifier).select(index),
      ),
    );
    // 映像は黒帯、情報パネルはテーマの地色で描画する。
    final content = isLandscape
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(color: Colors.black, child: video),
              ),
              SizedBox(width: 400, child: info),
            ],
          )
        : Column(
            children: [
              Container(
                color: Colors.black,
                child: AspectRatio(aspectRatio: 16 / 9, child: video),
              ),
              Expanded(child: info),
            ],
          );
    // 横画面は画面端まで描画する (フルブリード)。縦画面のみ SafeArea。
    if (isLandscape) return content;
    return SafeArea(child: content);
  }

  /// 映像+標準コントロール+エラー表示。レイアウトによらず共通。
  ///
  /// ライブと異なりシークバー・シーク操作は有効のままにする。
  Widget _buildVideo(BuildContext context) {
    final topButtonBar = <Widget>[
      const PlayerBackButton(fallbackPath: '/videos'),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          widget.video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      SubtitleToggleButton(player: _player),
      AudioMenuButton(
        player: _player,
        dualMonoChannel: _dualMonoChannel,
        onSelected: _onAudioSelected,
      ),
      if (_pastComments.isSupported)
        DanmakuToggleButton(
          enabled: _danmakuEnabled,
          onPressed: () => setState(() => _danmakuEnabled = !_danmakuEnabled),
        ),
      QualityMenuButton(
        current: widget.quality,
        qualities: const [
          originalKonomiVideoQuality,
          ...konomiVideoQualities,
        ],
        onSelected: (quality) =>
            ref.read(videoPlayQualityProvider.notifier).setQuality(quality),
      ),
    ];

    final vodMaterialTheme = MaterialVideoControlsThemeData(
      topButtonBar: topButtonBar,
      visibleOnMount: true,
      controlsHoverDuration: const Duration(seconds: 15),
    );
    final vodDesktopTheme = MaterialDesktopVideoControlsThemeData(
      visibleOnMount: true,
      controlsHoverDuration: const Duration(seconds: 15),
      topButtonBar: topButtonBar,
    );
    // 弾幕は映像の上・操作オーバーレイの下に重ねる。矩形の絞り方は
    // ライブと同様 (`JikkyoDanmakuOverlay` 参照)。
    final danmaku = _pastComments.isSupported && _videoDisplayAspect != null
        ? Positioned.fill(
            child: Align(
              child: AspectRatio(
                aspectRatio: _videoDisplayAspect!,
                child: JikkyoDanmakuOverlay(
                  controller: _pastComments,
                  enabled: _danmakuEnabled,
                ),
              ),
            ),
          )
        : null;
    return Stack(
      children: [
        MaterialVideoControlsTheme(
          normal: vodMaterialTheme,
          fullscreen: vodMaterialTheme,
          child: MaterialDesktopVideoControlsTheme(
            normal: vodDesktopTheme,
            fullscreen: vodDesktopTheme,
            child: Video(
              controller: _controller,
              controls: (state) => Stack(
                fit: StackFit.expand,
                children: [
                  ?danmaku,
                  AdaptiveVideoControls(state),
                ],
              ),
            ),
          ),
        ),
        if (_errorMessage != null)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '再生に失敗しました',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _open,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 録画再生画面用の情報パネル。番組情報と実況コメントの2タブ。
///
/// チャンネル切替タブは無い (録画はチャンネル送りしない)。
/// 選択位置は `videoInfoTabProvider` (keepAlive) が持つ。
/// コメント一覧は再生位置に追従する ([CommentListPanel] の録画モード)。
class _VideoInfoPanel extends StatelessWidget {
  const _VideoInfoPanel({
    required this.video,
    required this.comments,
    required this.syncStart,
    required this.positionStream,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final VideoProgram video;
  final JikkyoCommentSource comments;

  /// 再生位置0に対応する録画開始時刻。
  final DateTime syncStart;

  /// 再生位置のストリーム。
  final Stream<Duration> positionStream;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: selectedIndex,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ProgramDetailBody(
                  channel: video.channel,
                  program: video.toTvProgram(),
                  subtitle: video.subtitle,
                ),
              ),
              CommentListPanel(
                controller: comments,
                syncStart: syncStart,
                positionStream: positionStream,
              ),
            ],
          ),
        ),
        NavigationBar(
          height: 64,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
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
        ),
      ],
    );
  }
}

class _RetryError extends StatelessWidget {
  const _RetryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              '取得に失敗しました',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}
