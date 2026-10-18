import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/nx_jikkyo/jikkyo_endpoints.dart';
import '../../data/nx_jikkyo/jikkyo_kakolog_client.dart';
import '../../domain/entities/video_program.dart';
import 'jikkyo_comment_source.dart';

/// 録画再生時の過去ログコメント取得を管理する。
///
/// ライブ用 ([JikkyoCommentController]) と異なり WebSocket は張らず、
/// 過去ログAPI (`jikkyo.tsukumijima.net`) から録画期間分を一括取得する。
/// 取得した全件は [state] に置き、弾幕オーバーレイが時計 birth 付きで
/// 一括登録する。再生位置への追従は弾幕時計 ([DanmakuClock]) が担うため、
/// ここでは位置購読も送出ポインタも持たない。シークで飛ばした区間の
/// コメントも、表示期間内なら途中位置から描画される。
///
/// 回転耐性のため向きに依存しない State (`_VideoPlayerState`) が所有する。
/// 使用後は必ず [dispose] で購読を止めること。
class JikkyoPastCommentController extends ChangeNotifier
    implements JikkyoCommentSource {
  JikkyoPastCommentController({
    required VideoProgram video,
    JikkyoKakologClient? kakolog,
  }) : _kakolog = kakolog ?? JikkyoKakologClient(),
       _jkId = _resolveJkId(video),
       _syncStart = _resolveSyncStart(video),
       _fetchEnd = _resolveFetchEnd(video) {
    if (_jkId == null) {
      _state = const JikkyoCommentsState(
        status: JikkyoCommentStatus.unsupported,
        message: unsupportedChannelMessage,
      );
    }
  }

  final JikkyoKakologClient _kakolog;

  /// 実況チャンネル ID (`jk1` 等)。対応表に無ければ null (非対応)。
  final String? _jkId;

  /// 再生位置0に対応する録画開始時刻。録画時刻不明時は番組開始で代用する
  /// (録画マージン分のずれは許容する)。
  final DateTime _syncStart;

  /// 過去ログの取得終了時刻。録画時刻が無ければ番組終了で代用する。
  final DateTime _fetchEnd;

  var _state = const JikkyoCommentsState();
  final _live = StreamController<JikkyoComment>.broadcast();
  bool _started = false;
  bool _fetching = false;
  bool _disposed = false;

  /// 実況チャンネル ID を引く。チャンネル不明・非対応なら null。
  static String? _resolveJkId(VideoProgram video) {
    final channel = video.channel;
    if (channel == null) return null;
    return jikkyoChannelIdFor(channel);
  }

  /// 同期基準時刻を決める。録画開始が無ければ番組開始で代用する。
  static DateTime _resolveSyncStart(VideoProgram video) {
    return video.recordedFile?.recordingStartTime ?? video.startAt;
  }

  /// 取得終了時刻を決める。録画終了が無ければ番組終了で代用する。
  static DateTime _resolveFetchEnd(VideoProgram video) {
    return video.recordedFile?.recordingEndTime ?? video.endAt;
  }

  /// 過去ログの取得範囲。録画時刻が無ければ番組枠で代用する。
  (DateTime, DateTime) get _fetchRange => (_syncStart, _fetchEnd);

  /// 現在の取得状態と蓄積済みコメント。
  @override
  JikkyoCommentsState get state => _state;

  /// 実況チャンネルとして対応しているか。
  @override
  bool get isSupported => _jkId != null;

  /// 再生位置0に対応する録画開始時刻。コメントの弾幕 birth 換算に使う。
  DateTime get syncStart => _syncStart;

  /// 録画では弾幕オーバーレイが [state] から一括登録するため、ここからは
  /// 流さない (インターフェース互換のための空ストリーム)。
  @override
  Stream<JikkyoComment> get liveComments => _live.stream;

  /// 取得を開始する。非対応なら何もしない。多重呼び出しは無視される。
  void start() {
    if (_disposed || _started || _jkId == null) return;
    _started = true;
    _fetch();
  }

  /// 取得をやり直す。取得済みのコメントは捨てる。
  @override
  void retry() {
    if (_disposed || _jkId == null || _fetching) return;
    _setState(const JikkyoCommentsState());
    _fetch();
  }

  Future<void> _fetch() async {
    _fetching = true;
    try {
      final (start, end) = _fetchRange;
      final comments = await _kakolog.fetchPastComments(
        jkId: _jkId!,
        start: start,
        end: end,
      );
      if (_disposed) return;
      _setState(
        JikkyoCommentsState(
          status: JikkyoCommentStatus.ready,
          comments: comments,
        ),
      );
    } on JikkyoKakologException catch (e) {
      if (_disposed) return;
      _setState(
        JikkyoCommentsState(
          status: JikkyoCommentStatus.error,
          message: e.message,
        ),
      );
    } finally {
      _fetching = false;
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
    _live.close();
    super.dispose();
  }
}
