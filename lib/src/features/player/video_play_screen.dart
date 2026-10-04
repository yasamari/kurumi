import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/program_detail_body.dart';
import '../../domain/entities/video_program.dart';
import '../../domain/providers/backend_provider.dart';
import '../../domain/repositories/tv_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../videos/videos_providers.dart';
import 'comment_list_panel.dart';
import 'jikkyo_comment_source.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'jikkyo_past_comment_controller.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
import 'player_playback_controller.dart';
import 'player_split_layout.dart';
import 'player_status_views.dart';
import 'player_video_view.dart';
import 'program_info_panel.dart';

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
  late final PlayerPlaybackController _playback = PlayerPlaybackController();
  late final JikkyoPastCommentController _pastComments;
  late final String _sessionId;
  VideoStreamInfo? _stream;
  String? _streamError;
  Timer? _keepAliveTimer;

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
    _pastComments = JikkyoPastCommentController(
      player: _playback.player,
      video: widget.video,
    );
    _pastComments.start();
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

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    _pastComments.dispose();
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
    final pastComments = _pastComments;
    final video = ListenableBuilder(
      listenable: _playback,
      builder: (context, _) => PlayerVideoView(
        videoController: _playback.videoController,
        topButtonBar: buildPlayerTopButtonBar(
          title: widget.video.title,
          backFallbackPath: '/videos',
          player: _playback.player,
          dualMonoChannel: _playback.dualMonoChannel,
          onAudioSelected: _playback.selectAudio,
          danmakuSupported: pastComments.isSupported,
          danmakuEnabled: _playback.danmakuEnabled,
          onDanmakuToggled: _playback.toggleDanmaku,
          trailing: [_VideoQualityButton(quality: widget.quality)],
        ),
        layout: PlayerControlsLayout.seekable,
        danmaku: pastComments.isSupported
            ? JikkyoDanmakuLayer(
                displayAspect: _playback.videoDisplayAspect,
                child: JikkyoDanmakuOverlay(
                  controller: pastComments,
                  enabled: _playback.danmakuEnabled,
                ),
              )
            : null,
        errorMessage: _playback.errorMessage,
        onRetry: _open,
      ),
    );
    // 情報パネルはタブ選択だけを購読する別ウィジェットに切り出す。映像側で
    // 購読するとタブ切替のたびに映像 (`Video`) まで作り直され、内部の表示
    // パラメータ通知が飛んで映像・弾幕が一瞬止まる (ライブの `_WatchInfoPanel`
    // と同じ理由)。
    final info = Container(
      color: Theme.of(context).colorScheme.surface,
      child: _PlayInfoPanel(
        video: widget.video,
        comments: pastComments,
        syncStart: pastComments.syncStart,
        positionStream: _playback.position,
      ),
    );
    // 映像は黒帯、情報パネルはテーマの地色で描画する。向きで `Row`/`Column` を
    // 出し分けると映像のサブツリーごと破棄される (画面回転と、media_kit の
    // フルスクリーンでウィンドウサイズが変わる°) ので [PlayerSplitLayout] に
    // 任せる (同ウィジェットのコメントを参照)。
    return PlayerSplitLayout(video: video, info: info);
  }
}

/// 画質切替ボタン。映像とは切り離した `ConsumerWidget` に置く。
///
/// `buildPlayerTopButtonBar` の説明を参照。
class _VideoQualityButton extends ConsumerWidget {
  const _VideoQualityButton({required this.quality});

  /// 現在再生している画質。
  final String quality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(videoRepositoryProvider);
    return QualityMenuButton(
      current: quality,
      qualities: [
        if (repository.isOriginalVideoQuality('original')) 'original',
        ...repository.getVideoQualities(),
      ].where((q) => q.isNotEmpty).toList(),
      onSelected: (quality) =>
          ref.read(videoPlayQualityProvider.notifier).setQuality(quality),
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
