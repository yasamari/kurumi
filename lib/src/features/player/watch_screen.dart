import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/settings/app_settings.dart';
import '../../data/backends/konomi/konomi_live.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../domain/entities/backend_type.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/tv_providers.dart';
import 'jikkyo_comment_controller.dart';
import 'mpv_options.dart';
import 'player_error.dart';
import 'program_info_panel.dart';
import 'watch_providers.dart';

/// ライブ視聴画面。全画面プレイヤー遷移先 (`/watch/:channelId`)。
///
/// ナビゲーション (NavigationBar/Rail/Drawer) は表示しない。この画面は
/// StatefulShellRoute の外側 (`rootNavigatorKey` 上) に積まれるため、
/// シェル側のナビゲーションが隠れる。
///
/// 再生UIはmedia_kit標準 (`AdaptiveVideoControls`) を使う。戻るボタン・番組名・
/// 画質切替ボタンはAppBarではなく、標準コントロールの上部ボタンバーに載せる。
/// ライブのためシークバー・シーク系ジェスチャは無効化する。
class WatchScreen extends ConsumerWidget {
  const WatchScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(nowOnAirChannelsProvider);
    final settings = ref.watch(appSettingsProvider).value;
    final backendType = settings?.backendType ?? BackendType.mirakurun;

    return channels.when(
      loading: () => const _PlaceholderScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return const _PlaceholderScaffold(
            child: Center(child: Text('サーバーが設定されていません')),
          );
        }
        return _PlaceholderScaffold(
          child: _RetryError(
            message: '$error',
            onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
          ),
        );
      },
      data: (items) {
        final item =
            items.where((e) => e.channel.id == channelId).firstOrNull;
        if (item == null) {
          return _PlaceholderScaffold(
            child: _RetryError(
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
          showQualityMenu: backendType == BackendType.konomiTv,
        );
      },
    );
  }
}

/// まだプレイヤーを描画していない状態 (読み込み中・エラー) の土台。
/// media_kitの標準コントロールが存在しないため、戻るボタンは自前で置く。
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
            child: SafeArea(child: _BackButton()),
          ),
        ],
      ),
    );
  }
}

/// テレビ画面へ戻るボタン。
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/tv');
        }
      },
      icon: const Icon(Icons.arrow_back),
      color: Colors.white,
      tooltip: '戻る',
    );
  }
}

/// 画質切替ボタン (KonomiTVのみ表示)。全17画質から選択できる。
///
/// `PopupMenuButton` は使わない。media_kit のコントロールは自動非表示になる
/// と `mount=false` としてツリーから取り除かれるため、メニュー選択時点で
/// このウィジェットが破棄されていることがある。その場合 Flutter 内部の
/// `if (!mounted) return;` により `onSelected` が呼ばれず、画質が切り替わらない。
/// そのため `showMenu` を直接呼び、`ProviderContainer` 経由で反映する。
class _QualityMenuButton extends ConsumerWidget {
  const _QualityMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(watchQualityProvider);
    return IconButton(
      icon: const Icon(Icons.high_quality_outlined),
      color: Colors.white,
      tooltip: '画質切替',
      onPressed: () => _showQualityMenu(context, quality),
    );
  }
}

/// 画質選択メニューを表示し、選択結果を反映する。
Future<void> _showQualityMenu(BuildContext context, String current) async {
  // コントロールが破棄された後でも状態を反映できるよう、コンテナを先に控える。
  final container = ProviderScope.containerOf(context, listen: false);
  final anchorBox = context.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (anchorBox == null || !anchorBox.hasSize) return;
  if (overlayBox == null || !overlayBox.hasSize) return;

  final origin = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final selected = await showMenu<String>(
    context: context,
    // `PopupMenuButton` の既定位置指定に合わせる (ボタン直下・左右16px)。
    position: RelativeRect.fromLTRB(
      origin.dx + 16,
      origin.dy + anchorBox.size.height,
      overlayBox.size.width - origin.dx - anchorBox.size.width - 16,
      overlayBox.size.height - origin.dy - anchorBox.size.height,
    ),
    items: [
      for (final q in konomiLiveQualities)
        CheckedPopupMenuItem<String>(
          value: q,
          checked: q == current,
          child: Text(q),
        ),
    ],
  );
  if (selected == null) return;
  container.read(watchQualityProvider.notifier).setQuality(selected);
}

/// 字幕表示のオンオフ切替ボタン (ARIB字幕など)。画質ボタンの左に置く。
class _SubtitleToggleButton extends StatelessWidget {
  const _SubtitleToggleButton({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Track>(
      stream: player.stream.track,
      builder: (context, snapshot) {
        final current =
            snapshot.data?.subtitle ?? player.state.track.subtitle;
        final isOff = current.id == SubtitleTrack.no().id;
        return IconButton(
          icon: Icon(
            isOff
                ? Icons.closed_caption_off_outlined
                : Icons.closed_caption,
          ),
          color: Colors.white,
          tooltip: isOff ? '字幕を表示' : '字幕を非表示',
          onPressed: () => player.setSubtitleTrack(
            isOff ? SubtitleTrack.auto() : SubtitleTrack.no(),
          ),
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
        loading: () => const _PlaceholderScaffold(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) {
          final message = error is ChannelNotFoundException
              ? 'チャンネルが見つかりません'
              : 'ストリームの取得に失敗しました\n$error';
          return _PlaceholderScaffold(
            child: _RetryError(
              message: message,
              onRetry: () => ref.invalidate(liveStreamProvider(channelId)),
            ),
          );
        },
        data: (live) => _LivePlayer(
          // URLが変わったらPlayerを作り直す (画質切替対応)。
          key: ValueKey(live.url.toString()),
          url: live.url,
          item: item,
          title: title,
          showQualityMenu: showQualityMenu,
          // KonomiTVは `original` (生放送TS) のときだけデインタレースする。
          // Mirakurun (`decode=1` 固定) も生放送TSのためデインタレースする。
          // トランスコード済み画質はプログレッシブのため不要。
          deinterlace: showQualityMenu
              ? isOriginalKonomiQuality(live.qualityLabel)
              : true,
        ),
      ),
    );
  }
}

/// media_kitのPlayer/Controllerを所有するウィジェット。
///
/// 画面離脱・画質切替時に `dispose`/`open` し直すことでチューナーを解放する。
class _LivePlayer extends StatefulWidget {
  const _LivePlayer({
    super.key,
    required this.url,
    required this.item,
    required this.title,
    required this.showQualityMenu,
    required this.deinterlace,
  });

  final Uri url;

  /// 番組情報パネルに表示するチャンネル+番組。
  final ChannelItem item;
  final String title;
  final bool showQualityMenu;

  /// 生放送TS (インターレース) のとき真。mpvの自動デインタレースに使う。
  final bool deinterlace;

  @override
  State<_LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<_LivePlayer> {
  late final Player _player;
  late final VideoController _controller;
  late final JikkyoCommentController _jikkyo;

  /// 情報パネルの選択中タブ。
  ///
  /// 画面回転で情報パネルが作り直されても選択を維持するため、向きに依存しない
  /// 位置 (この State) に保持する。
  int _infoTabIndex = ProgramInfoPanel.programTab;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<AudioParams>? _audioParamsSub;
  Timer? _errorTimer;
  String? _pendingError;
  bool _isPlaying = false;
  bool _hasVideo = false;
  bool _hasAudio = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    // 実況コメントの接続はここでは張らない。コメントタブを開いた時点で
    // `selectInfoTab` から開始する (無関係なチャンネルの視聴者数を増やさない)。
    _jikkyo = JikkyoCommentController(
      channelId: jikkyoChannelIdFor(widget.item.channel) ?? '',
    );
    _jikkyo.addListener(_onJikkyoChanged);
    // media_kit の `error` は mpv のログレベル `error` をそのまま流すため、
    // 一過性のデコード失敗 (`Could not open codec`、`Error decoding audio.`
    // など) でも届く。再生状態と組み合わせて判定し、再生できている場合は
    // エラー表示しない (`player_error.dart` 参照)。
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
    _initialize();
  }

  /// mpvオプションを適用してから映像を開く。
  ///
  /// オプションはデコーダ生成時に読まれるため、必ず `open` より前に渡す。
  Future<void> _initialize() async {
    await applyLiveMpvOptions(_player, deinterlace: widget.deinterlace);
    if (!mounted) return;
    await _open();
  }

  Future<void> _open() async {
    _errorTimer?.cancel();
    _errorTimer = null;
    _pendingError = null;
    _isPlaying = false;
    _hasVideo = false;
    _hasAudio = false;
    if (mounted) {
      setState(() => _errorMessage = null);
    }
    await _player.open(Media(widget.url.toString()));
  }

  /// `error` 受信時の処理。再生中の一過性エラーは無視し、それ以外は猶予時間
  /// 後にまだ回復していなければエラー表示する。
  void _onPlayerError(String message) {
    if (message.isEmpty || !mounted) return;
    if (_isRecovered()) return;
    _pendingError = message;
    _errorTimer?.cancel();
    _errorTimer = Timer(playerErrorGracePeriod, () {
      if (!mounted) return;
      // 猶予時間内に再生が始まっていれば一過性エラーだったものとして捨てる。
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

  /// 情報パネルのタブを切り替える。
  ///
  /// 実況コメントの実況チャンネルが取得できている場合にだけ接続を開始する。
  /// すでに開始済み (同じ画面内でタブを往復した) なら何もしないので、再接続は
  /// 起こらない。
  void _selectInfoTab(int index) {
    if (index == ProgramInfoPanel.commentTab) _jikkyo.start();
    if (_infoTabIndex == index) return;
    setState(() => _infoTabIndex = index);
  }

  /// コメント状態の更新を反映する。
  void _onJikkyoChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _videoParamsSub?.cancel();
    _audioParamsSub?.cancel();
    _jikkyo.removeListener(_onJikkyoChanged);
    // 視聴画面を離れたときにソケットを閉じる。
    _jikkyo.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final video = _buildVideo(context);
    final info = Container(
      color: Theme.of(context).colorScheme.surface,
      child: ProgramInfoPanel(
        item: widget.item,
        controller: _jikkyo,
        selectedIndex: _infoTabIndex,
        onDestinationSelected: _selectInfoTab,
      ),
    );
    // 映像は黒帯、情報パネルはテーマの地色で描画する。
    final content = isLandscape
        // 横画面: 映像の右に情報パネルを置く。
        ? Row(
            // パネルを画面の高さいっぱいに広げる (既定のcenterだと
            // 内容量に応じた高さに縮んでしまうため)。
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(color: Colors.black, child: video),
              ),
              SizedBox(width: 400, child: info),
            ],
          )
        // 縦画面など: 映像の下に情報パネルを置く。
        : Column(
            children: [
              Container(
                color: Colors.black,
                child: AspectRatio(aspectRatio: 16 / 9, child: video),
              ),
              Expanded(child: info),
            ],
          );
    // 横画面はインカメラ等を避けず、画面端まで描画する (フルブリード)。
    // 縦画面のみ SafeArea でノッチ等を避ける。
    if (isLandscape) return content;
    return SafeArea(child: content);
  }

  /// 映像+標準コントロール+エラー表示。レイアウトによらず共通。
  Widget _buildVideo(BuildContext context) {
    // AppBarの代わりに、標準コントロールの上部ボタンバーへ載せる。
    final topButtonBar = <Widget>[
      const _BackButton(),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // 字幕切替は画質切替の左に置く (両バックエンド共通)。
      _SubtitleToggleButton(player: _player),
      if (widget.showQualityMenu) const _QualityMenuButton(),
    ];

    // ライブのためシークバー・シーク系操作を無効化する。
    final liveMaterialTheme = MaterialVideoControlsThemeData(
      displaySeekBar: false,
      seekGesture: false,
      seekOnDoubleTap: false,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      // 中央ボタンは既定のプレイリスト送り (単品再生では無動作) の代わりに、
      // 前/次チャンネル送りを置く。大きさ・間隔は既定の構成を踏襲する。
      primaryButtonBar: [
        const Spacer(flex: 2),
        _ChannelZapButton(
          channel: widget.item.channel,
          isNext: false,
        ),
        const Spacer(),
        const MaterialPlayOrPauseButton(iconSize: 56.0),
        const Spacer(),
        _ChannelZapButton(
          channel: widget.item.channel,
          isNext: true,
        ),
        const Spacer(flex: 2),
      ],
      // ライブに再生時刻表示は不要のため、時刻表示を外して
      // フルスクリーンボタンだけ残す。
      bottomButtonBar: const [
        Spacer(),
        MaterialFullscreenButton(),
      ],
      // 画面を開いた直後は操作ボタン (戻るボタン等) を表示しておく。
      visibleOnMount: true,
      // 既定3秒だと画質メニュー (全17件) を操作する前に消えてしまうため、
      // 長く表示し続ける。
      controlsHoverDuration: const Duration(seconds: 15),
      topButtonBar: topButtonBar,
    );
    final liveDesktopTheme = MaterialDesktopVideoControlsThemeData(
      displaySeekBar: false,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      // ライブに再生時刻表示は不要のため、時刻表示を外して
      // 前/次 (チャンネル送り)・再生・音量・フルスクリーンボタンを残す。
      bottomButtonBar: [
        _ChannelZapButton(
          channel: widget.item.channel,
          isNext: false,
        ),
        const MaterialDesktopPlayOrPauseButton(),
        _ChannelZapButton(
          channel: widget.item.channel,
          isNext: true,
        ),
        const MaterialDesktopVolumeButton(),
        const Spacer(),
        const MaterialDesktopFullscreenButton(),
      ],
      visibleOnMount: true,
      controlsHoverDuration: const Duration(seconds: 15),
      topButtonBar: topButtonBar,
    );
    return Stack(
      children: [
        MaterialVideoControlsTheme(
          normal: liveMaterialTheme,
          fullscreen: liveMaterialTheme,
          child: MaterialDesktopVideoControlsTheme(
            normal: liveDesktopTheme,
            fullscreen: liveDesktopTheme,
            // media_kit標準UI。平台で自動切替される。
            child: Video(
              controller: _controller,
              controls: AdaptiveVideoControls,
            ),
          ),
        ),
        if (_errorMessage != null)
          Positioned.fill(
            // 上部のコントロール (戻るボタン等) を隠さないよう上端だけ空ける。
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
