import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/nx_jikkyo/jikkyo_comment_session.dart';
import '../../data/nx_jikkyo/jikkyo_endpoints.dart';
import '../../data/nx_jikkyo/jikkyo_watch_session.dart';

/// 受信したコメントをまとめて反映するまでの待ち時間。
///
/// 1コメント1フレームで届くため、そのまま反映すると 1コメントごとにリストが
/// 再構築される。短い間隔で束ねて描画回数を抑える。
const _commentFlushInterval = Duration(milliseconds: 100);

/// 実況コメントの取得と蓄積を管理する.
///
/// **Why `ChangeNotifier` であり Riverpod ではないのか**:
/// 視聴画面のレイアウトは `MediaQuery.orientationOf` に応じて `Row` と `Column`
/// を切り替える。ウィジェットの型が変わるとその下の Element が作り直される
/// ため、`Row`/`Column` の内側に置いたウィジェットは画面回転のたびに State を
/// 失う。実況コメントは回転で切断されては困るので、回転しても生き残れる
/// `_LivePlayerState` に所有させる。
///
/// [channelId] が空文字なら実非対応として扱い、接続しない。
/// 使用後は必ず [dispose] でソケットを閉じること。
class JikkyoCommentController extends ChangeNotifier {
  JikkyoCommentController({required String channelId})
    : _channelId = channelId,
      _state =
          channelId.isEmpty
              ? const JikkyoCommentsState(
                status: JikkyoCommentStatus.unsupported,
                message: unsupportedChannelMessage,
              )
              : const JikkyoCommentsState();

  /// 実況チャンネル ID (`jk1` 等)。空文字なら実非対応。
  final String _channelId;

  JikkyoCommentsState _state;

  JikkyoWatchSession? _watch;
  JikkyoCommentSession? _comment;
  StreamSubscription<JikkyoWatchEvent>? _watchSub;
  StreamSubscription<JikkyoComment>? _commentSub;
  StreamSubscription<void>? _subscribedSub;
  final _pending = <JikkyoComment>[];
  Timer? _flushTimer;
  bool _disposed = false;

  /// 現在の状態。
  JikkyoCommentsState get state => _state;

  /// 実況チャンネルとして対応しているか。
  bool get isSupported => _channelId.isNotEmpty;

  /// 接続を開始する。実非対応なら何もしない。
  ///
  /// 監視のみなので多重呼び出しは無視される。
  void start() {
    if (_disposed || _channelId.isEmpty) return;
    if (_watch != null) return;
    final watch = JikkyoWatchSession(channelId: _channelId);
    _watch = watch;
    _watchSub = watch.events.listen(_onWatchEvent);
    watch.start();
  }

  /// 接続をやり直す。保持済みのコメントは引き継ぐ。
  void retry() {
    if (_disposed || _channelId.isEmpty) return;
    _disposeSessions();
    _setState(_state.copyWith(status: JikkyoCommentStatus.connecting));
    start();
  }

  void _onWatchEvent(JikkyoWatchEvent event) {
    if (_disposed) return;
    switch (event) {
      case JikkyoWatchRoomEvent(:final room):
        _startCommentSession(room);
      case JikkyoWatchStatisticsEvent():
        // 視聴者数・コメント総数は表示しない。NX-Jikkyo が 60秒ごとに
        // 送ってくるだけなので何もしない。
        break;
      case JikkyoWatchEndedEvent():
        _disposeCommentSession();
        _setState(
          _state.copyWith(
            status: JikkyoCommentStatus.ended,
            message: '放送が終了しました',
          ),
        );
      case JikkyoWatchReconnectingEvent():
        _setState(_state.copyWith(status: JikkyoCommentStatus.connecting));
      case JikkyoWatchFailedEvent(:final failure, :final message):
        _disposeCommentSession();
        _setState(
          _state.copyWith(
            status: switch (failure) {
              JikkyoWatchFailure.unknownChannel =>
                JikkyoCommentStatus.unsupported,
              JikkyoWatchFailure.noActiveThread =>
                JikkyoCommentStatus.unavailable,
              JikkyoWatchFailure.connection => JikkyoCommentStatus.error,
            },
            message: message,
          ),
        );
    }
  }

  /// 部屋情報を受けてコメントセッションを購読する。
  ///
  /// 視聴セッションが再接続すると `room` が再度届くため、そのたびに張り直す。
  void _startCommentSession(JikkyoRoom room) {
    _disposeCommentSession();
    final session = JikkyoCommentSession(
      channelId: _channelId,
      threadId: room.threadId,
      threadKey: room.yourPostKey,
    );
    _comment = session;
    _commentSub = session.comments.listen(_enqueueComment);
    _subscribedSub = session.subscribed.listen((_) {
      if (_disposed) return;
      _setState(_state.copyWith(status: JikkyoCommentStatus.ready));
    });
    session.start();
  }

  void _disposeCommentSession() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _commentSub?.cancel();
    _commentSub = null;
    _subscribedSub?.cancel();
    _subscribedSub = null;
    _comment?.dispose();
    _comment = null;
  }

  void _disposeSessions() {
    _disposeCommentSession();
    _watchSub?.cancel();
    _watchSub = null;
    _watch?.dispose();
    _watch = null;
  }

  /// 受信したコメントを溜め、[_commentFlushInterval] 後にまとめて反映する。
  void _enqueueComment(JikkyoComment comment) {
    if (_disposed) return;
    _pending.add(comment);
    _flushTimer ??= Timer(_commentFlushInterval, _flush);
  }

  void _flush() {
    _flushTimer = null;
    if (_disposed || _pending.isEmpty) return;
    final batch = List<JikkyoComment>.of(_pending);
    _pending.clear();
    _setState(
      _state.copyWith(
        status: JikkyoCommentStatus.ready,
        comments: mergeJikkyoComments(
          existing: _state.comments,
          incoming: batch,
        ),
      ),
    );
  }

  void _setState(JikkyoCommentsState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disposeSessions();
    super.dispose();
  }
}
