import 'dart:async';

/// システムのメディア操作 (通知・MPRIS・SMTC・ヘッドセット) の委譲先。
///
/// 再生実体は mpv (`PlayerPlaybackController`) が持つ。`KurumiAudioHandler` は
/// 操作を受けてここへ流すだけで、プレイヤー自体は知らない。ライブ視聴と録画再生
/// でできることが違うため、可否は [supportsSeek]/[supportsZap] で表し、
/// 対応しない操作は呼ばれない ([KurumiAudioHandler] が弾く)。
abstract class MediaControlTarget {
  /// 再生を開始・再開する。
  Future<void> play();

  /// 再生を一時停止する。
  Future<void> pause();

  /// [position] へシークする。録画再生のみ。
  Future<void> seekTo(Duration position);

  /// 次のチャンネルへ切り替える。ライブ視聴のみ。
  Future<void> zapToNext();

  /// 前のチャンネルへ切り替える。ライブ視聴のみ。
  Future<void> zapToPrevious();

  /// シークに対応しているか。録画再生のみ真。
  bool get supportsSeek;

  /// 前/次チャンネル送りに対応しているか。ライブ視聴のみ真。
  bool get supportsZap;
}

/// 現在再生中の画面を1つだけ保持する登録所。
///
/// **Riverpod にも画面ごとの State にもしない。** PiP と同じくプラットフォーム
/// 機能の相手先なので、ライブ視聴・録画再生のどちらの画面からも同じ1つの
/// 状態 ([target]) を見る。`PlayerPlaybackController.notifyListeners` にも
/// 映像の再構築にも関与しない。
///
/// 登録・解除はプレイヤー画面の `initState`/`dispose` で行う。チャンネル切替は
/// 視聴画面ごと置き換わるため **新旧画面の破棄順が固定できない**。新画面の
/// `attach` 後に旧画面の `detach` が走っても新しい登録を壊さないよう、
/// [detach] は持ち主 ([owner]、普通は `this`) の同一性で判別する
/// ([PipMode.disable] と同じ流儀)。
class MediaControls {
  MediaControls._();

  /// プロセス内で唯一点のインスタンス。
  static final MediaControls instance = MediaControls._();

  /// 現在システム操作を受け付ける画面。なければ null。
  MediaControlTarget? get target => _target;

  MediaControlTarget? _target;

  /// いま登録している画面。同一性の判別だけに使う。
  Object? _owner;

  /// プレイヤー画面が mount したときの登録。既存の登録は上書きする。
  void attach({required Object owner, required MediaControlTarget target}) {
    _owner = owner;
    _target = target;
  }

  /// プレイヤー画面を離れたときの解除。実際に外したときだけ真を返す。
  ///
  /// [owner] が現在の持ち主でなければ何もしない (チャンネル切替で新画面の
  /// 登録を消さないため)。真のとき、呼び出し側は通知の消去
  /// ([KurumiAudioHandler.deactivate]) まで行う。
  bool detach({required Object owner}) {
    if (!identical(_owner, owner)) return false;
    _owner = null;
    _target = null;
    return true;
  }
}
