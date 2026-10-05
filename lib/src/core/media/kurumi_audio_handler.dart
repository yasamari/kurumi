import 'package:audio_service/audio_service.dart';

import 'media_control_target.dart';

/// main() で初期化したハンドラー。プレイヤー画面が再生状態の配信に使う。
///
/// 未初期化 (テストや非対応環境で初期化に失敗した場合) は null。
/// 画面側は `?.` で呼び、null なら何もしない。
KurumiAudioHandler? _handlerInstance;

/// [systemMediaHandler] の実体。テスト用に差し替えはしない。
KurumiAudioHandler? get systemMediaHandler => _handlerInstance;

/// システムのメディア操作を受け付ける準備をする。`main()` で1回だけ呼ぶ。
///
/// [AudioService.init] がプラットフォーム実装 (Android 通知 / Linux MPRIS /
/// Windows SMTC) を自動選択する。`androidNotificationChannelId` は MPRIS の
/// D-Bus 名登録にも必須なため必ず渡す。失敗時は例外をそのまま投げるので、
/// 呼び出し側で握りつぶして無効化すること ([PipMode._call] と同じ流儀)。
Future<KurumiAudioHandler> initSystemMedia() async {
  final handler = await AudioService.init(
    builder: () => KurumiAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'io.github.yasamari.kurumi.channel.audio',
      androidNotificationChannelName: 'Kurumi',
      // バックグラウンドに回っても再生中はフォアグラウンドで音声を流し続ける。
      // 通知タップでアプリに復帰する。`ongoing` と `stopForegroundOnPause`
      // の併用は audio_service 側の assert で必須化されている組み合わせ。
      androidNotificationOngoing: true,
      androidResumeOnClick: true,
      // LAN 内のロゴ・サムネイルを先読みする。16:9 の画像想定で縮小する。
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 288,
      // 録画の ±10 秒送りと PiP の [_pipSeekStep] を合わせる。
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
  _handlerInstance = handler;
  return handler;
}

/// システムのメディア操作 (通知・ロック画面・MPRIS・SMTC・ヘッドセット) を
/// 現在再生中のプレイヤーへ委譲する [AudioHandler]。
///
/// 再生実体は mpv ([PlayerPlaybackController]) が持ち、ここは操作の受付と状態の
/// 配信だけを担う。相手先は [MediaControls] の登録 (現在開いているプレイヤー
/// 画面) で、画面が無ければ何もしない。
///
/// 通知は映像の再構築に一切関与しない。画面側はストリーム通知のついでに
/// [reportLive]/[reportVideo]/[publishItem] を呼ぶだけで、自身の
/// `notifyListeners` や `setState` は起こさない。
class KurumiAudioHandler extends BaseAudioHandler with SeekHandler {
  MediaControlTarget? get _target => MediaControls.instance.target;

  @override
  Future<void> play() async {
    await _target?.play();
  }

  @override
  Future<void> pause() async {
    await _target?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final target = _target;
    if (target == null || !target.supportsSeek) return;
    await target.seekTo(position);
  }

  @override
  Future<void> skipToNext() async {
    final target = _target;
    if (target == null || !target.supportsZap) return;
    await target.zapToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    final target = _target;
    if (target == null || !target.supportsZap) return;
    await target.zapToPrevious();
  }

  /// 停止要求は一時停止として扱う。
  ///
  /// 通知の消去はプレイヤー画面の破棄時に [deactivate] で行う。画面を開いた
  /// まま停止だけ通知を消すとはしない (次に状態が変われば通知は戻るため、
  /// 中途半端に消さない)。
  @override
  Future<void> stop() async {
    await _target?.pause();
  }

  /// 再生中の番組情報を配信する。ライブ視聴・録画再生の共通部分。
  void publishItem(MediaItem? item) {
    mediaItem.add(item);
  }

  /// ライブ視聴の再生状態を配信する。
  ///
  /// ライブに尺は無いため位置・シーク系は載せない。前/次ボタンはチャンネル
  /// 送り ([MediaControlTarget.zapToNext]/[zapToPrevious]、PiP と同規則)。
  void reportLive({required bool playing, required bool buffering}) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {},
        processingState: buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: playing,
      ),
    );
  }

  /// 録画再生の再生状態を配信する。
  ///
  /// [position] はこの更新時点の再生位置。audio_service 側で速度・経過時間から
  /// 外挿されるため、連続配信はしない (再生・停止・シーク・停滞の変化点と
  /// 間引き更新だけで足りる)。尺は [MediaItem.duration] 側で配信する。
  void reportVideo({
    required bool playing,
    required bool buffering,
    Duration? position,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.fastForward,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: position ?? Duration.zero,
      ),
    );
  }

  /// プレイヤー画面の破棄時に通知を消す。
  ///
  /// [MediaControls.detach] が真を返したとき (本当に画面を離れたとき) だけ呼ぶ。
  /// チャンネル切替では新画面が既に自分の番組を配信しているため呼ばない。
  void deactivate() {
    mediaItem.add(null);
    playbackState.add(
      PlaybackState(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }
}
