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
import 'audio_switch.dart';
import 'jikkyo_comment_controller.dart';
import 'jikkyo_danmaku_overlay.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
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
            child: SafeArea(child: PlayerBackButton()),
          ),
        ],
      ),
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
///
/// 情報パネルの選択中タブは `watchInfoTabProvider` を読むため
/// `ConsumerStatefulWidget` にする。`ConsumerWidget` ではなく Stateful なのは、
/// 回転・チャンネル切替で作り直されても Player と実況コメントの接続を保つため。
class _LivePlayer extends ConsumerStatefulWidget {
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
  ConsumerState<_LivePlayer> createState() => _LivePlayerState();
}

/// [Player] と実況コメントの接続を持つ。向きに依存しない位置なので、画面回転で
/// 作り直されても続きを保てる。情報パネルの選択中タブだけはチャンネル切替 (`go`
/// による画面の置き換え) でも保つ必要があるため、この State ではなく
/// `watchInfoTabProvider` が持つ。
class _LivePlayerState extends ConsumerState<_LivePlayer> {
  late final Player _player;
  late final VideoController _controller;
  late final JikkyoCommentController _jikkyo;

  /// 実況コメントの弾幕表示の on/off。
  ///
  /// ここも向きに依存しない State に持たせる。映像の `Stack` 内は回転で作り
  /// 直されるため、ウィジェット側に持たせると回転でリセットされる。
  bool _danmakuEnabled = true;

  /// 二重モノラルの復号チャンネル。null はステレオ (主＋副)。
  ///
  /// 画面回転ではこの State ごと保たれる。チャンネル切替は `go` で画面ごと
  /// 置き換わるため初期値に戻る。
  DualMonoChannel? _dualMonoChannel;

  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<AudioParams>? _audioParamsSub;
  Timer? _errorTimer;
  String? _pendingError;
  bool _isPlaying = false;

  /// 一度再生したうえで停止し、その後再開したかどうか。
  ///
  /// ライブ配信では再開しただけでは放送に追いつかないため、再開のたびに
  /// [seekToLiveEdge] で溜まった過去データを捨てる必要がある。
  /// 初回再生 (接続した時点で既にライブエッジにいる) や画質切替・再試行での
  /// `_open` では追いかけ不要なので [_open] でリセットする。
  bool _pausedAfterStart = false;
  bool _hasVideo = false;
  bool _hasAudio = false;
  String? _errorMessage;

  /// 映像の**表示**アスペクト比 (幅 / 高さ)。まだ mpv から届いていなければ null。
  ///
  /// media_kit の `Video` は `BoxFit.contain` で描くため、ウィジェット全体には
  /// 黒帯や柱状 (レターボックス) ができる。弾幕を映像の上だけに重ねるにはこの比
  /// が必要で、届くまで弾幕は描画しない。
  ///
  /// 符号化サイズ (4:3) ではなく表示アスペクト比 (16:9) を使う必要がある。日本語
  /// のデジタル放送には 1440x1080 を 16:9 に引き伸ばしているチャンネルがあり、
  /// ここを間違えると矩形がズレて弾幕が黒帯に出る。
  /// [videoDisplayAspectOf] 参照。
  double? _videoDisplayAspect;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    // 実況コメントの接続は実況チャンネルが取得できている場合に即開始する。
    // 弾幕を既定で表示するため、コメントタブを開くまで待たない。
    _jikkyo = JikkyoCommentController(
      channelId: jikkyoChannelIdFor(widget.item.channel) ?? '',
    );
    _jikkyo.start();
    // media_kit の `error` は mpv のログレベル `error` をそのまま流すため、
    // 一過性のデコード失敗 (`Could not open codec`、`Error decoding audio.`
    // など) でも届く。再生状態と組み合わせて判定し、再生できている場合は
    // エラー表示しない (`player_error.dart` 参照)。
    _errorSub = _player.stream.error.listen(_onPlayerError);
    _playingSub = _player.stream.playing.listen(_onPlayingChanged);
    _videoParamsSub = _player.stream.videoParams.listen((params) {
      if (hasValidVideoSize(dw: params.dw, dh: params.dh, w: params.w, h: params.h)) {
        _hasVideo = true;
        _clearErrorIfRecovered();
      }
      // 弾幕を映像の Letterbox の内側に収めるため、表示アスペクト比を保持する。
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
    // 開き直した時点がライブエッジなので、停止からの再開として扱わない。
    _pausedAfterStart = false;
    if (mounted) {
      setState(() => _errorMessage = null);
    }
    await _player.open(Media(widget.url.toString()));
  }

  /// 再生状態の変化を反映する。
  ///
  /// 停止 (`pause` プロパティが立った状態) してから再開したらライブエッジへ
  /// 戻す。停止中は Demuxer キャッシュとソケットバッファに過去データが溜まる
  /// ため、これでは放送に追いつかない。
  ///
  /// `playing` は mpv の `pause` プロパティの変化で通知されるので停止→再開の
  /// 判別に使える。一時的なバッファ停滞は `paused-for-cache` なので混同しない。
  void _onPlayingChanged(bool playing) {
    if (playing) {
      if (_pausedAfterStart) {
        _pausedAfterStart = false;
        // 溜まった過去データを捨てるだけなので、失敗しても再生自体には
        // 影響しない。
        unawaited(seekToLiveEdge(_player));
      }
    } else if (_isPlaying) {
      _pausedAfterStart = true;
    }
    _isPlaying = playing;
    _clearErrorIfRecovered();
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

  /// 情報パネルのタブを切り替える。
  ///
  /// 選択位置は `watchInfoTabProvider` が持つ。画面回転でもチャンネル切り替えでも
  /// outlive するため、ここでは State に持たせない。
  ///
  /// 実況コメントは弾幕を既定で表示するため、視聴画面を開いた時点で既に接続
  /// 済み。ここでは接続を開始しない。

  @override
  void dispose() {
    _errorTimer?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _videoParamsSub?.cancel();
    _audioParamsSub?.cancel();
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
        selectedIndex: ref.watch(watchInfoTabProvider),
        onDestinationSelected: (index) =>
            ref.read(watchInfoTabProvider.notifier).select(index),
        // チャンネルの切替は `go` で視聴画面ごと置き換える。旧画面の Player と
        // 実況コメントのソケットはこれで解放される。
        onChannelSelected: (id) => context.go('/watch/$id'),
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
      const PlayerBackButton(),
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
      SubtitleToggleButton(player: _player),
      // 音声切替 (二重ステレオ/二重モノラル) は字幕切替の右に置く。
      AudioMenuButton(
        player: _player,
        dualMonoChannel: _dualMonoChannel,
        onSelected: _onAudioSelected,
      ),
      // 弾幕切替は字幕切替の右。実況チャンネルが対応している場合のみ出す。
      if (_jikkyo.isSupported)
        DanmakuToggleButton(
          enabled: _danmakuEnabled,
          onPressed: () => setState(() => _danmakuEnabled = !_danmakuEnabled),
        ),
      if (widget.showQualityMenu)
        QualityMenuButton(
          current: ref.watch(watchQualityProvider),
          qualities: konomiLiveQualities,
          onSelected: (quality) =>
              ref.read(watchQualityProvider.notifier).setQuality(quality),
        ),
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
    // 弾幕は映像の上に重ねる。ただし映像ウィジェットは `BoxFit.contain` で
    // 描くため、そのまま重ねると黒帯 (レターボックス) にも出てしまう。
    // 映像の**表示**アスペクト比に合わせて矩形を絞る。`Align` + `AspectRatio`
    // は `FittedBox(fit: contain)` と同じ矩形になるので、幅高を自分で計算する
    // 必要はない。比が確定するまで (起動直後・音声のみ) は描画しない。
    //
    // 描画位置は映像の上・操作オーバーレイの下。media_kit の `Video` は
    // 「映像テクスチャ → 字幕 → 標準コントロール」を内側の `Stack` で
    // 描画しているため、弾幕を外側の `Stack` に重ねるとコントロールより上に
    // なってしまう (逆に順序を入れ替えれば映像テクスチャより下に回って
    // 見えなくなる)。差し込めるのは controls レイヤーの内側だけなので、
    // 下の `controls` ビルダーに渡す。
    final danmaku = _jikkyo.isSupported && _videoDisplayAspect != null
        ? Positioned.fill(
            child: Align(
              child: AspectRatio(
                aspectRatio: _videoDisplayAspect!,
                child: JikkyoDanmakuOverlay(
                  controller: _jikkyo,
                  enabled: _danmakuEnabled,
                ),
              ),
            ),
          )
        : null;
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
              controls: (state) => Stack(
                // `Video` 側は `Positioned.fill` で tight 制約を渡している。
                // 標準コントロールに loose な制約を渡すとグラデーション等が
                // 縮むため、`Video` と同じ tight 制約を渡す。
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
