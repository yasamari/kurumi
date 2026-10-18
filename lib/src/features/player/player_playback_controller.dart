import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'audio_switch.dart';
import 'danmaku_settings.dart';
import 'mpv_options.dart';
import 'player_control_buttons.dart';
import 'player_error.dart';

/// 再生状態 (mpv の [Player] とその派生状態) を所有するコントローラー。
///
/// ライブ視聴 (`watch_screen.dart`) と録画再生 (`video_play_screen.dart`) の
/// 共通部分。再生セッションの種類や EIT 取得の有無といった画面ごとの違いは
/// 呼び出し側の State が持ち、ここは「mpv をどう起動し、開いた映像をどう判定
/// し、音声や弾幕の選択をどう反映するか」だけを担う。
///
/// **Why `ChangeNotifier` であり Riverpod ではないのか**:
/// 視聴画面のレイアウトは `MediaQuery.orientationOf` に応じて `Row` と `Column`
/// を切り替える。ウィジェットの型が変わるとその下の Element がすべて作り直される
/// 作り直されるため、`Row`/`Column` の内側の State は画面回転のたびに失われる。
/// [Player] と再生セッションはそこで解放され、作り直しになる (PSI 取得とライブ
/// 追従の中断。実況コメントの接続だけは `_WatchLayoutState` 側の持ちなので
/// 保たれる)。これが fullscreen で映像が黒く止まる原因でもあるため、回転で
/// 作り直されない位置にこのコントローラーを持たせる必要がある。実況コメント
/// (`JikkyoCommentController`) と同じ流儀。
///
/// 通知はエラー表示・表示アスペクト比・二重モノラルが変わったときだけ起きる。
/// 再生フレームごとに通知は起きない。
///
/// **弾幕の表示設定 ([danmakuPreferences]) と字幕の on/off ([subtitlesEnabled])
/// はこの通知では配らない。** どちらも映像のサブツリー (弾幕の層・字幕ボタン)
/// だけが購読する専用 notifier で配る。ここに乗せると、設定を1つ変えるたびに
/// 映像 ([PlayerVideoView]) まで作り直されるうえ、`Video` の controls ビルダーが
/// 差し替わるため mpv の内部パラメータ通知まで飛び、フレームが一瞬止まる。
class PlayerPlaybackController extends ChangeNotifier {
  PlayerPlaybackController({
    this.seekToLiveEdgeOnResume = false,
    this.initialDanmakuPreferences = const DanmakuPreferences(),
    this.initialSubtitlesEnabled = defaultSubtitlesEnabled,
    this.onDanmakuPreferencesChanged,
    this.onSubtitlesEnabledChanged,
  }) {
    danmakuPreferences = ValueNotifier(initialDanmakuPreferences);
    subtitlesEnabled = ValueNotifier(initialSubtitlesEnabled);
    videoController = VideoController(player);
    // media_kit の `error` は mpv のログレベル `error` をそのまま流すため、
    // 一過性のデコード失敗 (`Could not open codec`、`Error decoding audio.`
    // など) でも届く。再生状態と組み合わせて判定し、再生できている場合は
    // エラー表示しない (`player_error.dart` 参照)。
    _errorSub = player.stream.error.listen(_onPlayerError);
    _playingSub = player.stream.playing.listen(_onPlayingChanged);
    _videoParamsSub = player.stream.videoParams.listen(_onVideoParams);
    _audioParamsSub = player.stream.audioParams.listen(_onAudioParams);
  }

  /// mpv のプレイヤー。[dispose] で解放する。
  final Player player = Player();

  /// media_kit の映像ウィジェットに渡すコントローラー。
  late final VideoController videoController;

  /// 停止 (`pause` プロパティが立った状態) してから再開したらライブエッジへ
  /// 戻すかどうか。ライブ配信だけ真。
  ///
  /// ライブ配信では停止している間も Demuxer キャッシュとソケットバッファに
  /// 過去データが溜まるため、再開してもその続きから再生されるだけで、停止した
  /// 時間だけ放送に遅れたままになる (前方向のシークでは追いつけない。
  /// [seekToLiveEdge] 参照)。録画再生は放送に追従しないので不要。
  final bool seekToLiveEdgeOnResume;

  /// 弾幕の表示設定の初期値。永続化済みの値を呼び出し側が渡す
  /// (`AppSettings` のスナップショットから作る)。
  final DanmakuPreferences initialDanmakuPreferences;

  /// 字幕表示の初期値。永続化済みの値を呼び出し側が渡す。既定は非表示。
  final bool initialSubtitlesEnabled;

  /// 弾幕の表示設定が変わったときのコールバック。呼び出し側が永続化する。
  final ValueChanged<DanmakuPreferences>? onDanmakuPreferencesChanged;

  /// 字幕表示が変わったときのコールバック。呼び出し側が永続化する。
  final ValueChanged<bool>? onSubtitlesEnabledChanged;

  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<AudioParams>? _audioParamsSub;
  Timer? _errorTimer;
  String? _pendingError;
  bool _isPlaying = false;
  bool _hasVideo = false;
  bool _hasAudio = false;

  /// 一度再生したうえで停止し、その後再開したかどうか。
  ///
  /// 初回再生 (接続した時点で既にライブエッジにいる) や画質切替・再試行では
  /// 追いかけ不要なので [resetPlaybackState] でリセットする。
  bool _pausedAfterStart = false;

  String? _errorMessage;
  double? _videoDisplayAspect;
  DualMonoChannel? _dualMonoChannel;
  bool _disposed = false;

  /// 表示中の再生エラー。null なら表示しない。
  String? get errorMessage => _errorMessage;

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
  double? get videoDisplayAspect => _videoDisplayAspect;

  /// 現在選択中の二重モノラルのチャンネル。null はステレオ (主＋副)。
  DualMonoChannel? get dualMonoChannel => _dualMonoChannel;

  /// 弾幕の表示設定 (on/off と文字サイズ・不透明度・速度) の通知元。
  ///
  /// 向きに依存しない状態に持たせる。映像の `Stack` 内は回転で作り直される
  /// ため、ウィジェット側に持たせると回転でリセットされる。
  ///
  /// 購読は弾幕の層 ([JikkyoDanmakuOverlay]) だけが行う。設定メニューは
  /// この notifier を購読せず、コールバック経由 ([onDanmakuPreferencesChanged])
  /// で反映するため変わらない ([PlayerSettingsButton] が購読すると映像の
  /// 再構築に巻き込まれるため)。
  ///
  /// この notifier を [notifyListeners] と連動させないのは、設定を1つ変える
  /// たびに映像 ([PlayerVideoView]) まで作り直されるため。設定は弾幕以外の
  /// 要素に影響しない。
  late final ValueNotifier<DanmakuPreferences> danmakuPreferences;

  /// 字幕を表示するかどうかの通知元。既定は非表示。
  ///
  /// mpv 側の字幕トラック選択は [_applySubtitleSelection] で別に追従させる。
  /// 購読は字幕ボタン ([SubtitleToggleButton]) だけが行う ([danmakuPreferences]
  /// と同じ理屈)。
  late final ValueNotifier<bool> subtitlesEnabled;

  /// 再生位置のストリーム。録画のコメント追従 (再生位置に追従する一覧) に使う。
  Stream<Duration> get position => player.stream.position;

  /// 弾幕の表示設定を決める。永続化は [onDanmakuPreferencesChanged] の
  /// 呼び出し側に任せる。
  ///
  /// [notifyListeners] は呼ばない。弾幕の層が [danmakuPreferences] を購読して
  /// いるため、設定変更は弾幕のサブツリーにだけ届く。
  void setDanmakuPreferences(DanmakuPreferences preferences) {
    if (preferences == danmakuPreferences.value) return;
    danmakuPreferences.value = preferences;
    onDanmakuPreferencesChanged?.call(preferences);
  }

  /// 字幕表示を切り替える。mpv の字幕トラック選択にそのまま反映し、
  /// [onSubtitlesEnabledChanged] で永続化する。
  ///
  /// [notifyListeners] は呼ばない。字幕ボタンが [subtitlesEnabled] を購読して
  /// いる ([danmakuPreferences] と同じ理屈)。
  void toggleSubtitles() {
    final next = !subtitlesEnabled.value;
    subtitlesEnabled.value = next;
    unawaited(_applySubtitleSelection());
    onSubtitlesEnabledChanged?.call(next);
  }

  /// 字幕の選択を mpv に適用する。
  ///
  /// mpv は既定で `sid=auto` (字幕があれば出す) なので、非表示にしたい場合は
  /// 選び直す。映像を開き直すたび ([openUri]) に呼ぶことで、画質変更や再試行
  /// の後も選択が保たれる。
  Future<void> _applySubtitleSelection() {
    return player.setSubtitleTrack(
      subtitlesEnabled.value ? SubtitleTrack.auto() : SubtitleTrack.no(),
    );
  }

  /// 音声メニューの選択を反映する。
  ///
  /// トラック選択 (二重ステレオ) は mpv にそのまま委ねる。二重モノラルは
  /// デコーダオプションの切り替えになるため [applyDualMonoChannel] で音声
  /// デコーダを作り直す。
  Future<void> selectAudio(AudioChoice choice) async {
    switch (choice) {
      case AudioTrackChoice(:final trackId):
        await player.setAudioTrack(AudioTrack(trackId, null, null));
      case DualMonoChoice(:final channel):
        if (_dualMonoChannel == channel) return;
        _dualMonoChannel = channel;
        notifyListeners();
        await applyDualMonoChannel(player, channel);
    }
  }

  /// 映像を開き直す前の状態を初期化する。
  ///
  /// 開いた時点が新しいライブエッジ (セッションも作り直した状態) なので、
  /// 停止からの再開として扱わない。エラー表示の解除は [openUri] が担う。
  void resetPlaybackState() {
    _errorTimer?.cancel();
    _errorTimer = null;
    _pendingError = null;
    _isPlaying = false;
    _hasVideo = false;
    _hasAudio = false;
    _pausedAfterStart = false;
  }

  /// 映像を開く。表示中のエラーは取り下げてから開く。
  ///
  /// 開くたびに字幕の選び直しを適用するため、字幕の on/off と非表示の既定
  /// ([initialSubtitlesEnabled]) はここで mpv へ反映される。
  Future<void> openUri(Uri url) async {
    _errorMessage = null;
    notifyListeners();
    await player.open(Media(url.toString()));
    await _applySubtitleSelection();
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
      if (seekToLiveEdgeOnResume && _pausedAfterStart) {
        _pausedAfterStart = false;
        // 溜まった過去データを捨てるだけなので、失敗しても再生自体には
        // 影響しない。
        unawaited(seekToLiveEdge(player));
      }
    } else if (_isPlaying) {
      _pausedAfterStart = true;
    }
    _isPlaying = playing;
    _clearErrorIfRecovered();
  }

  /// `video-params` 受信時の処理。有効な映像サイズと表示アスペクト比を拾う。
  void _onVideoParams(VideoParams params) {
    if (_disposed) return;
    if (hasValidVideoSize(
      dw: params.dw,
      dh: params.dh,
      w: params.w,
      h: params.h,
    )) {
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
    _videoDisplayAspect = aspect;
    notifyListeners();
  }

  /// `audio-params` 受信時の処理。有効な音声形式があれば回復済みとみなす。
  void _onAudioParams(AudioParams params) {
    if (hasValidAudioFormat(
      sampleRate: params.sampleRate,
      channelCount: params.channelCount,
    )) {
      _hasAudio = true;
      _clearErrorIfRecovered();
    }
  }

  /// `error` 受信時の処理。再生中の一過性エラーは無視し、それ以外は猶予時間
  /// 後にまだ回復していなければエラー表示する。
  void _onPlayerError(String message) {
    if (message.isEmpty || _disposed) return;
    if (_isRecovered()) return;
    _pendingError = message;
    _errorTimer?.cancel();
    _errorTimer = Timer(playerErrorGracePeriod, () {
      if (_disposed) return;
      // 猶予時間内に再生が始まっていれば一過性エラーだったものとして捨てる。
      if (_isRecovered()) return;
      _errorMessage = _pendingError;
      _pendingError = null;
      notifyListeners();
    });
  }

  /// 再生が軌道に乗っていれば、表示中・表示待ちのエラーを取り下げる。
  void _clearErrorIfRecovered() {
    if (!_isRecovered()) return;
    _errorTimer?.cancel();
    _errorTimer = null;
    _pendingError = null;
    if (_errorMessage != null && !_disposed) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  bool _isRecovered() => isPlayerRecovered(
    isPlaying: _isPlaying,
    hasVideo: _hasVideo,
    hasAudio: _hasAudio,
  );

  @override
  void dispose() {
    _disposed = true;
    _errorTimer?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _videoParamsSub?.cancel();
    _audioParamsSub?.cancel();
    danmakuPreferences.dispose();
    subtitlesEnabled.dispose();
    player.dispose();
    super.dispose();
  }
}
