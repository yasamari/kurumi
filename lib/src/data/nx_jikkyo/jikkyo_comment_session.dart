import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'jikkyo_comment.dart';
import 'jikkyo_endpoints.dart';

/// 1 フレームから取り出せる情報。
typedef JikkyoCommentFrame = ({List<JikkyoComment> comments, bool subscribed});

/// サーバー→クライアントの 1 フレームを解釈する。
///
/// **フレームは JSON オブジェクト単体のことがある**点に注意が必要。配列形式は
/// クライアント→サーバー (購読コマンド列) の話で、サーバーが返す `chat` と
/// `thread` はいずれも `{"chat": {...}}` / `{"thread": {...}}` というオブジェクト
/// 1つである。ライブ配信は Redis Pub/Sub の生 JSON をそのまま転送するため特に
/// 確実。配列を見ないとライブコメントを全件落とす。
///
/// パースできないフレームや ping は空の結果になる。
JikkyoCommentFrame parseJikkyoCommentFrame(String raw) {
  final comments = <JikkyoComment>[];
  var subscribed = false;

  void handle(Object? element) {
    if (element is! Map<String, dynamic>) return;
    // 購読の確定通知。`thread` コマンドの応答 (resultcode) で来る。
    if (element['thread'] is Map<String, dynamic>) {
      subscribed = true;
      return;
    }
    // サーバーの `ping` は受信した内容そのまま返ってくるので何もしない。
    if (element.containsKey('ping')) return;
    final chat = element['chat'];
    if (chat is! Map<String, dynamic>) return;
    final comment = parseJikkyoChat(chat);
    if (comment != null) comments.add(comment);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return (comments: comments, subscribed: subscribed);
  }
  if (decoded is List) {
    for (final element in decoded) {
      handle(element);
    }
  } else {
    handle(decoded);
  }
  return (comments: comments, subscribed: subscribed);
}

/// NX-Jikkyo のコメントセッション WebSocket。
///
/// 接続して本家ニコ生互換のコマンド列を送ると購読が始まり、以降
/// `chat` メッセージが push される。購読開始時に [initialResFrom] 件だけ
/// 過去コメントを取り込み、以降のライブコメントも同じ経路で届く。
///
/// 使用後は [dispose] で必ず解放すること。
class JikkyoCommentSession {
  JikkyoCommentSession({
    required this.channelId,
    required this.threadId,
    required this.threadKey,
    this.baseUrl = nxJikkyoBaseUrl,

    /// 購読開始時に取得する過去コメントの件数。
    this.initialResFrom = defaultResFrom,
  });

  /// 購読開始時に取得する過去コメントの件数。
  static const defaultResFrom = 100;

  /// 再接続バックオフの上限 (秒)。
  static const maxRetrySeconds = 30;

  /// 本家ニコ生が要求するバージョン値。NX-Jikkyo は検証しない。
  static const _protocolVersion = '20061206';

  final String channelId;
  final String threadId;
  final String threadKey;
  final String baseUrl;
  final int initialResFrom;

  final _comments = StreamController<JikkyoComment>.broadcast();
  final _controller = StreamController<void>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  int _retryCount = 0;
  bool _disposed = false;
  bool _stopped = false;

  /// 受信したコメント。`no` 順で届くとは限らないため、並び順は呼び出し側で
  /// 積み直すること。
  Stream<JikkyoComment> get comments => _comments.stream;

  /// 購読が (再)確立された通知。
  Stream<void> get subscribed => _controller.stream;

  /// 接続を開始する。監視のみなので多重呼び出しは無視される。
  void start() {
    if (_disposed || _stopped) return;
    if (_channel != null) return;
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed || _stopped) return;
    final uri = jikkyoCommentUri(channelId, baseUrl: baseUrl);
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    try {
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
    // 接続が張れたら購読コマンドを送り直す (再接続時は先頭の何件かで再購読)。
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (Object _) => _onClosed(),
      onDone: _onClosed,
      cancelOnError: false,
    );
    _sendSubscribe();
  }

  void _onMessage(Object? raw) {
    if (raw is! String) return;
    final frame = parseJikkyoCommentFrame(raw);
    if (frame.subscribed) _notifySubscribed();
    if (frame.comments.isEmpty) return;
    if (_comments.isClosed) return;
    for (final comment in frame.comments) {
      _comments.add(comment);
    }
  }

  void _onClosed() {
    if (_disposed || _stopped) return;
    // 1002 (スレッド無し) / 1008 (不正なメッセージ) は再送で解消しない。
    final code = _channel?.closeCode;
    if (code == 1002 || code == 1008) {
      _stopped = true;
      _closeChannel();
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _closeChannel();
    if (_disposed || _stopped) return;
    final delay = _retryDelaySeconds(_retryCount);
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delay), _connect);
  }

  static int _retryDelaySeconds(int retryCount) {
    final delay = 1 << retryCount.clamp(0, 8);
    return delay > maxRetrySeconds ? maxRetrySeconds : delay;
  }

  /// 購読コマンド列を送る。
  ///
  /// 本家ニコ生と同じ以下のシーケンスを 1 フレーム (JSON 配列) で送る。
  /// サーバーは受信した `ping` をそのまま返すだけなので、`rs` / `ps` / `pf` /
  /// `rf` の内容には意味がなく、バックログの開始・終了の境界として使う。
  void _sendSubscribe() {
    final channel = _channel;
    if (channel == null) return;
    // `res_from` は取得する過去コメントの件数の符号反転値。正値は受け付け
    // られないので必ず負で送る。
    final thread = <String, Object?>{
      'version': _protocolVersion,
      'thread': threadId,
      'threadkey': threadKey,
      'user_id': '',
      'res_from': -initialResFrom,
    };

    final frame = jsonEncode([
      {'ping': {'content': 'rs:0'}},
      {'ping': {'content': 'ps:0'}},
      {'thread': thread},
      {'ping': {'content': 'pf:0'}},
      {'ping': {'content': 'rf:0'}},
    ]);
    try {
      channel.sink.add(frame);
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _notifySubscribed() {
    _retryCount = 0;
    if (_disposed || _controller.isClosed) return;
    _controller.add(null);
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
    await _comments.close();
    await _controller.close();
  }
}
