import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'jikkyo_endpoints.dart';

/// 視聴セッション (`/ws/watch`) から得られる部屋情報。
class JikkyoRoom {
  const JikkyoRoom({
    required this.threadId,
    required this.yourPostKey,
    required this.vposBaseTime,
  });

  /// コメントセッションで購読するスレッド ID。
  final String threadId;

  /// `yourpost` フラグを付けるためのキー。
  ///
  /// NX-Jikkyo は投稿されたコメントの `user_id` に視聴セッションのクライアント
  /// ID を入れるため、これをそのまま `thread` コマンドの `threadkey` に指定する。
  final String yourPostKey;

  /// `vpos: 0` の基準時刻 (ISO 8601)。
  final String vposBaseTime;
}

/// 視聴統計情報。接続直後と 60秒ごとに通知される。
///
/// 現在 UI では表示していない (コメント一覧は本文と時刻のみ表示する)。
/// 視聴セッションが受け取るべきサーバーからのメッセージは取りこぼさず解析して
/// おく。表に出したいときにそのまま使える。
class JikkyoStatistics {
  const JikkyoStatistics({required this.viewers, required this.comments});

  final int viewers;
  final int comments;
}

/// 接続できなかった理由。
enum JikkyoWatchFailure {
  /// チャンネルIDが不正、または NX-Jikkyo に登録が無い (close 1008)。
  unknownChannel,

  /// 放送中でない (close 1002)。再接続しても解決しない。
  noActiveThread,

  /// その他の接続断。
  connection,
}

/// 視聴セッションの出力。
sealed class JikkyoWatchEvent {
  const JikkyoWatchEvent();
}

/// 部屋情報を受信した。コメントセッションはこの情報で購読を始める。
class JikkyoWatchRoomEvent extends JikkyoWatchEvent {
  const JikkyoWatchRoomEvent(this.room);
  final JikkyoRoom room;
}

class JikkyoWatchStatisticsEvent extends JikkyoWatchEvent {
  const JikkyoWatchStatisticsEvent(this.statistics);
  final JikkyoStatistics statistics;
}

/// 放送が終了した (`disconnect` の `END_PROGRAM`)。再接続しない。
class JikkyoWatchEndedEvent extends JikkyoWatchEvent {
  const JikkyoWatchEndedEvent();
}

/// 回復可能な切断。再接続を試みる。
class JikkyoWatchReconnectingEvent extends JikkyoWatchEvent {
  const JikkyoWatchReconnectingEvent();
}

/// 回復不能な失敗。終了後に再接続しない。
class JikkyoWatchFailedEvent extends JikkyoWatchEvent {
  const JikkyoWatchFailedEvent(this.failure, this.message);
  final JikkyoWatchFailure failure;
  final String message;
}

/// NX-Jikkyo の視聴セッション WebSocket。
///
/// 接続して `startWatching` を送り、部屋情報・統計・放送終了を通知する。
/// 回復可能な切断は 1秒から最大 30秒 までの指数バックオフで再接続する。
///
/// 使用後は [dispose] で必ず解放すること。
class JikkyoWatchSession {
  JikkyoWatchSession({required this.channelId, this.baseUrl = nxJikkyoBaseUrl});

  /// 再接続バックオフの上限 (秒)。
  static const maxRetrySeconds = 30;

  /// 実況チャンネル ID (`jk1` 等)。
  final String channelId;
  final String baseUrl;

  final _controller = StreamController<JikkyoWatchEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _disposed = false;
  bool _stopped = false;

  /// 部屋情報・統計・終了・失敗の通知。
  Stream<JikkyoWatchEvent> get events => _controller.stream;

  /// 接続を開始する。監視のみなので多重呼び出しは無視される。
  void start() {
    if (_disposed || _stopped) return;
    if (_channel != null) return;
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _stopped) return;
    final uri = jikkyoWatchUri(channelId, baseUrl: baseUrl);
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    try {
      // 接続が確立するまでは送信できない。
      await channel.ready;
    } catch (_) {
      if (_disposed || _stopped) return;
      _scheduleRetry();
      return;
    }
    if (_disposed || _stopped || !identical(_channel, channel)) {
      await channel.sink.close();
      return;
    }
    // 接続直後の `room` でリセットする。
    _retryCount = 0;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (Object _) => _onClosed(),
      onDone: _onClosed,
      cancelOnError: false,
    );
    _send({'type': 'startWatching', 'data': {}});
  }

  void _onMessage(Object? raw) {
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    switch (decoded['type']) {
      case 'room':
        final room = _parseRoom(decoded['data']);
        if (room != null) _add(JikkyoWatchRoomEvent(room));
      case 'statistics':
        final data = decoded['data'];
        if (data is! Map<String, dynamic>) return;
        final viewers = data['viewers'];
        final comments = data['comments'];
        if (viewers is! num || comments is! num) return;
        _add(
          JikkyoWatchStatisticsEvent(
            JikkyoStatistics(
              viewers: viewers.toInt(),
              comments: comments.toInt(),
            ),
          ),
        );
      case 'disconnect':
        final data = decoded['data'];
        final reason = data is Map<String, dynamic> ? data['reason'] : null;
        if (reason == 'END_PROGRAM') {
          _stopped = true;
          _add(const JikkyoWatchEndedEvent());
          _closeChannel();
        } else {
          _scheduleRetry();
        }
      case 'ping':
        // NX-Jikkyo は 30秒ごとに `ping` を送る。`pong` は内容を見ない。
        _send({'type': 'pong'});
    }
  }

  void _onClosed() {
    if (_disposed || _stopped) return;
    // NX-Jikkyo は状態異常を close コードで伝える。理由を見て回復可否を判断する。
    final code = _channel?.closeCode;
    if (code == 1008) {
      _stopped = true;
      _add(
        const JikkyoWatchFailedEvent(
          JikkyoWatchFailure.unknownChannel,
          unsupportedChannelMessage,
        ),
      );
      _closeChannel();
      return;
    }
    if (code == 1002) {
      _stopped = true;
      _add(
        const JikkyoWatchFailedEvent(
          JikkyoWatchFailure.noActiveThread,
          'このチャンネルは現在放送していません',
        ),
      );
      _closeChannel();
      return;
    }
    if (code == 1000) {
      // 放送終了時の正常クローズ。理由は `disconnect` で先に届く。
      _stopped = true;
      _add(const JikkyoWatchEndedEvent());
      _closeChannel();
      return;
    }
    _scheduleRetry();
  }

  /// 回復可能な切断。1秒から [maxRetrySeconds] までの指数バックオフで再接続する。
  void _scheduleRetry() {
    _closeChannel();
    if (_disposed || _stopped) return;
    _add(const JikkyoWatchReconnectingEvent());
    final delay = _retryDelaySeconds(_retryCount);
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), _connect);
  }

  static int _retryDelaySeconds(int retryCount) {
    final delay = 1 << retryCount.clamp(0, 8);
    return delay > maxRetrySeconds ? maxRetrySeconds : delay;
  }

  static JikkyoRoom? _parseRoom(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final threadId = raw['threadId'];
    final yourPostKey = raw['yourPostKey'];
    final vposBaseTime = raw['vposBaseTime'];
    if (threadId is! String ||
        yourPostKey is! String ||
        vposBaseTime is! String) {
      return null;
    }
    return JikkyoRoom(
      threadId: threadId,
      yourPostKey: yourPostKey,
      vposBaseTime: vposBaseTime,
    );
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(message));
    } catch (_) {
      // 送信できない場合は切断ハンドラ側で再接続する。
    }
  }

  void _add(JikkyoWatchEvent event) {
    if (_disposed || _controller.isClosed) return;
    _controller.add(event);
  }

  void _closeChannel() {
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    channel?.sink.close();
  }

  /// 接続を切断して監視を終了する。
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopped = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _closeChannel();
    await _controller.close();
  }
}
