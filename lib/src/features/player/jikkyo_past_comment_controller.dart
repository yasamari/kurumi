import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/nx_jikkyo/jikkyo_endpoints.dart';
import '../../data/nx_jikkyo/jikkyo_kakolog_client.dart';
import '../../data/nx_jikkyo/jikkyo_past_comment_filter.dart';
import '../../domain/entities/video_program.dart';
import 'jikkyo_comment_source.dart';

/// シークと判定する再生位置の跳躍幅。通常再生の進行と区別するため。
const _seekThreshold = Duration(seconds: 2);

/// 録画再生時の過去ログコメント取得と弾幕タイミングを管理する。
///
/// ライブ用 ([JikkyoCommentController]) と異なり WebSocket は張らず、
/// 過去ログAPI (`jikkyo.tsukumijima.net`) から録画期間分を一括取得する。
/// [Player] の再生位置に追従して弾幕へ流す。
///
/// 回転耐性のため向きに依存しない State が所有する (ライブの
/// `_LivePlayerState` と同様)。使用後は必ず [dispose] で購読を止めること。
class JikkyoPastCommentController extends ChangeNotifier
    implements JikkyoCommentSource {
  JikkyoPastCommentController({
    required this._player,
    required this._video,
    JikkyoKakologClient? kakolog,
  })  : _kakolog = kakolog ?? JikkyoKakologClient(),
        _jkId = _resolveJkId(_video),
        _syncStart = _resolveSyncStart(_video) {
    if (_jkId == null) {
      _state = const JikkyoCommentsState(
        status: JikkyoCommentStatus.unsupported,
        message: unsupportedChannelMessage,
      );
    }
  }

  final Player _player;
  final VideoProgram _video;
  final JikkyoKakologClient _kakolog;

  /// 実況チャンネル ID (`jk1` 等)。対応表に無ければ null (非対応)。
  final String? _jkId;

  /// 再生位置0に対応する録画開始時刻。録画時刻不明時は番組開始で代用する
  /// (録画マージン分のずれは許容する)。
  final DateTime _syncStart;

  var _state = const JikkyoCommentsState();
  StreamSubscription<Duration>? _positionSub;
  final _live = StreamController<JikkyoComment>.broadcast();
  bool _started = false;
  bool _fetching = false;
  bool _disposed = false;

  /// 弾幕へ流し済みの件数 (投稿時刻順の先頭から)。
  int _emitted = 0;
  Duration _lastPosition = Duration.zero;

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

  /// 過去ログの取得範囲。録画時刻が無ければ番組枠で代用する。
  (DateTime, DateTime) get _fetchRange {
    final recorded = _video.recordedFile;
    final start = recorded?.recordingStartTime ?? _video.startAt;
    final end = recorded?.recordingEndTime ?? _video.endAt;
    return (start, end);
  }

  /// 現在の取得状態と蓄積済みコメント。
  @override
  JikkyoCommentsState get state => _state;

  /// 実況チャンネルとして対応しているか。
  @override
  bool get isSupported => _jkId != null;

  /// 再生位置に追従して弾幕に出すコメント。
  ///
  /// 一括取得のため「新規」の概念はなく、再生位置を過ぎた未送出分を流す。
  /// シークで飛ばした区間は弾幕に出さない (一覧には全件残る)。
  @override
  Stream<JikkyoComment> get liveComments => _live.stream;

  /// 取得を開始する。非対応なら何もしない。多重呼び出しは無視される。
  void start() {
    if (_disposed || _started || _jkId == null) return;
    _started = true;
    _positionSub = _player.stream.position.listen(_onPosition);
    _fetch();
  }

  /// 取得をやり直す。取得済みのコメントは捨て、ポインタも戻す。
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
      // 読み込み完了時点までに過ぎた分は弾幕に出さず飛ばす
      // (一斉表示の flood を避けるため)。
      _emitted = countDuePastComments(
        comments: comments,
        syncStart: _syncStart,
        position: _lastPosition,
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

  void _onPosition(Duration position) {
    if (_disposed) return;
    final advanced = position - _lastPosition;
    _lastPosition = position;
    final comments = _state.comments;
    if (comments.isEmpty) return;
    if (advanced.abs() > _seekThreshold) {
      // シーク (前後どちらも): 飛ばした区間は弾幕に出さずポインタだけ合わせる。
      // 巻き戻し後はその先のコメントが通常どおり流れる。
      _emitted = countDuePastComments(
        comments: comments,
        syncStart: _syncStart,
        position: position,
      );
      return;
    }
    final due = countDuePastComments(
      comments: comments,
      syncStart: _syncStart,
      position: position,
    );
    if (due <= _emitted) return;
    for (var i = _emitted; i < due; i++) {
      if (_live.isClosed) break;
      _live.add(comments[i]);
    }
    _emitted = due;
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
    _positionSub?.cancel();
    _live.close();
    super.dispose();
  }
}
