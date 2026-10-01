import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/nx_jikkyo/jikkyo_comment_session.dart';
import '../../data/nx_jikkyo/jikkyo_endpoints.dart';
import '../../data/nx_jikkyo/jikkyo_watch_session.dart';
import 'jikkyo_comment_source.dart';

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
class JikkyoCommentController extends ChangeNotifier
    implements JikkyoCommentSource {
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

  /// 弾幕表示専用の通知。購読直後のバックログは含まない。
  final _live = StreamController<JikkyoComment>.broadcast();
  Timer? _flushTimer;
  bool _disposed = false;

  /// バックログとライブコメントの境界コメ番。`null` は未確定。
  int? _backfillBoundary;
  /// 現在の状態。
  @override
  JikkyoCommentsState get state => _state;

  /// 実況チャンネルとして対応しているか。
  @override
  bool get isSupported => _channelId.isNotEmpty;

  /// 弾幕に出す新規コメント。
  ///
  /// NX-Jikkyo は購読開始時に直近の過去コメントをまとめて送ってくる。その
  /// 一斉表示は弾幕では不自然なため、初回バッチはすべて過去ログ扱いにして
  /// 流向しない。一覧表示は [state] を見ており、バックログも含まれる。
  @override
  Stream<JikkyoComment> get liveComments => _live.stream;

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
  @override
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
      // 再購読のたびにバックログ境界をリセットする。サーバーは購読の直後に
      // 過去ログを返し直すので、境界を戻さないと再接続のたびに湧く。
      _backfillBoundary = null;
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
    _emitLive(batch);
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

  /// 弾幕に出すコメントだけを [_live] へ流す。
  ///
  /// 購読直後 (境界未確定) の最初のバッチはバックログとみなして弾幕に出さない。
  /// そのバッチの最大コメ番を境界に固定し、以降はコメ番が境界を超えるものだけ
  /// を弾幕に出す。
  void _emitLive(List<JikkyoComment> batch) {
    if (_live.isClosed) return;

    if (_backfillBoundary == null) {
      // 最初のバッチは過去ログ。最大コメ番を境界にする。
      var max = 0;
      for (final comment in batch) {
        if (comment.no > max) max = comment.no;
      }
      _backfillBoundary = max;
      return;
    }

    for (final comment in batch) {
      if (isJikkyoBackfill(boundary: _backfillBoundary, no: comment.no)) {
        continue;
      }
      _live.add(comment);
    }
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
    _live.close();
    super.dispose();
  }
}
