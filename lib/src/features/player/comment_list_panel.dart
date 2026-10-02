import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/utils/time_format.dart';
import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/nx_jikkyo/jikkyo_endpoints.dart';
import '../../data/nx_jikkyo/jikkyo_past_comment_filter.dart';
import 'jikkyo_comment_source.dart';

/// 遠方への移動をアニメーションせず瞬時に飛ぶ境目 (表示行からの件数)。
///
/// アニメーションで数千件を横切ると通過する行を全て組み立てるため、
/// コメント数に比例して重くなる。離れていれば [ItemScrollController.jumpTo]
/// で目的の窓だけ組み立てる。
///
/// 録画モードでのみ使う。ライブは下端への瞬時復帰に統一している
/// ([_CommentListPanelState._jumpToAnchor] 参照)。
const commentListFarItemDistance = 30;

/// ライブの追従を切る末端からの距離 (論理ピクセル)。
///
/// ライブ一覧は追記型の通常 `ListView` で作り、新着は末端
/// (`maxScrollExtent`) に足される。プログラム側の移動は `_programmatic` で
/// 除外済みのため、ここに届く通知はユーザー操作によるものだけになる。
/// 末端から少しでも離れたら離脱とみなす。
const liveFollowEndThreshold = 8.0;

/// ライブの末端移動を省略する誤差 (論理ピクセル)。
///
/// 追記で伸びた分だけ飛ぶため、既に末端にいるときの `jumpTo` は何も
/// 変えない。通知・再配置を走らせないよう、この誤差内なら飛ばさない。
const livePinEpsilon = 1.0;

/// 録画モードの再生位置に対応する行の表示添字を返す純粋関数。
///
/// リストは `reverse: true` (index 0 が最新・下端) のため、古い順の添字を
/// 反転する。[dueCount] は [countDuePastComments] の戻り値。再生位置より前の
/// コメントが無ければ最古 (末尾) を指す。
int playbackBuilderIndex({
  required int commentCount,
  required int dueCount,
}) {
  if (commentCount <= 0) return 0;
  return (commentCount - dueCount).clamp(0, commentCount - 1);
}

/// 追従先に戻るボタンの向きを返す純粋関数。
///
/// - ライブは追従先 (最新) が常に下端のため下向き。
/// - 録画は再生位置の行と表示範囲の前後で向きを変える。再生位置より先
///   (新しい方) へ進んでいれば上向き、前に戻っていれば下向き。範囲内なら
///   中央との前後で決める。範囲不明なら下向き。
IconData commentJumpIcon({
  required bool isPlayback,
  required int anchor,
  required ({int min, int max})? visibleRange,
}) {
  if (!isPlayback) return Icons.arrow_downward;
  final range = visibleRange;
  if (range == null) return Icons.arrow_downward;
  if (anchor < range.min) return Icons.arrow_downward;
  if (anchor > range.max) return Icons.arrow_upward;
  return anchor * 2 <= range.min + range.max
      ? Icons.arrow_downward
      : Icons.arrow_upward;
}

/// ニコニコ実況コメントの一覧表示。
///
/// コメント本文と投稿時刻のみを表示する。色・サイズ・位置は `mail` コマンドから
/// 来るがここでは解釈せず、文字色は一律 [ColorScheme.onSurface] に固定する。
/// (弾幕表示を実装する段で `parseJikkyoCommentMail` を使う。)
///
/// 接続とコメントの蓄積は [controller] が担う。このウィジェットが持つのは
/// スクロール位置と追従 on/off だけなので、破棄・再生成されても connecting に
/// 戻ったりコメントを失ったりしない。画面回転で [ProgramInfoPanel] ごと
/// 作り直される的就是このため (追従状態だけは初期値に戻る)。
///
/// リストはモードで使い分ける。
///
/// - ライブモード ([syncStart]/[positionStream] なし): 追記型の通常
///   `ListView` (非 reverse、古い順) を使う。新着は末端に足すだけなので
///   既存行の添字と内容がずれず、再構築では新着行だけが配置される
///   (既存行は同一文字列の更新として配置を省略する)。先頭に足す設計だと
///   可視行すべてが別内容に入れ替わり、毎回全文を整形し直すため
///   映像・弾幕と vsync を争ってカクつく。追従中は末端への `jumpTo`
///   だけで済み、位置指定リストのような再配置・全要素の計測は走らない。
/// - 録画モード (両方あり): 行高が可変でも遠方へ飛べるよう
///   [ScrollablePositionedList] を使う (オフセット計算では届かないため)。
///   こちらは取得後に内容が変わらないため、添字のずれは起きない。
///
/// - ライブモード ([syncStart]/[positionStream] なし): 下端 (最新) にいるとき
///   だけ新着に追従し、最新コメントを常に一番下に据える。一度スクロールして
///   離れたら、下向きの「最新に戻る」ボタンで戻るまで追従しない
///   (手動で下端に戻しても復帰しない)。
/// - 録画モード (両方あり): [positionStream] の再生位置に対応するコメントに
///   追従する。見えている間は据え置き、外れたら下端へ飛ぶ。ユーザー操作
///   (ドラッグ・ホイール) で離れると追従を切り、再生位置への向き (より先へ
///   進んでいれば上、前に戻っていれば下) の「再生位置に戻る」ボタンを出す。
///   復帰はボタンのみ。離脱判定はポインターイベントで行う。スクロール通知では
///   初回着地や移動の整定とユーザー操作を区別できないため (該当コメントの無い
///   冒頭で追従が外れる原因になる)。
class CommentListPanel extends StatefulWidget {
  const CommentListPanel({
    super.key,
    required this.controller,
    this.syncStart,
    this.positionStream,
  }) : assert(
         (syncStart == null) == (positionStream == null),
         'syncStart と positionStream は対で渡すこと',
       );

  final JikkyoCommentSource controller;

  /// 再生位置0に対応する録画開始時刻。録画モードのときだけ渡す。
  final DateTime? syncStart;

  /// 録画の再生位置。録画モードのときだけ渡す。
  final Stream<Duration>? positionStream;

  @override
  State<CommentListPanel> createState() => _CommentListPanelState();
}

class _CommentListPanelState extends State<CommentListPanel> {
  /// 録画モード用。再生位置の行へ任意ジャンプするために使う。
  final _items = ItemScrollController();

  /// 録画モード用。追従先の表示判定と戻るボタンの向きに使う。
  late final _positions = ItemPositionsListener.create();

  /// ライブモード用。新着 (末端) への移動と離脱判定に使う。
  ///
  /// 一覧は追記型のため、追従中は末端への `jumpTo` だけを走らせる。
  /// 既存行の再配置は起きない。
  final _liveScroll = ScrollController();

  StreamSubscription<Duration>? _positionSub;

  /// 前回表示した戻るボタンの向き。向きが変わるときだけ作り直すための
  /// 比較対象 (録画・非追従時)。null は未確定。
  IconData? _jumpIcon;

  /// 最新 (ライブ) / 再生位置 (録画) に追従しているか。
  bool _following = true;

  /// プログラム側のスクロール中にスクロール通知を無視するための旗。
  bool _programmatic = false;

  /// 追従スクロールの post-frame 予約があるか。同一フレーム内の複数回の
  /// コメント到着を1回のスクロールに束ねる。
  bool _pinScheduled = false;

  Duration _position = Duration.zero;
  int _lastDue = 0;

  /// 録画モードかどうか。
  bool get _isPlayback =>
      widget.syncStart != null && widget.positionStream != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCommentsChanged);
    _positions.itemPositions.addListener(_onPositionsChanged);
    _positionSub = widget.positionStream?.listen(_onPosition);
    _lastDue = _dueCount();
    // ライブは初回配置の直後に末端 (最新) へ寄せる。通常リストの初期位置は
    // 先頭 (最古) のため、この1回が無いと新着まで最古が表示され続ける。
    if (!_isPlayback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinLiveToEnd();
      });
    }
  }

  @override
  void didUpdateWidget(CommentListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCommentsChanged);
      widget.controller.addListener(_onCommentsChanged);
      _lastDue = _dueCount();
    }
    if (oldWidget.positionStream != widget.positionStream) {
      _positionSub?.cancel();
      _positionSub = widget.positionStream?.listen(_onPosition);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _liveScroll.dispose();
    widget.controller.removeListener(_onCommentsChanged);
    _positions.itemPositions.removeListener(_onPositionsChanged);
    super.dispose();
  }

  int _dueCount() {
    final comments = widget.controller.state.comments;
    final syncStart = widget.syncStart;
    if (comments.isEmpty || syncStart == null) return 0;
    return countDuePastComments(
      comments: comments,
      syncStart: syncStart,
      position: _position,
    );
  }

  /// 表示中の行の添字の範囲。追従先が画面内か判定する。
  ({int min, int max})? _visibleRange() {
    var min = -1;
    var max = -1;
    for (final position in _positions.itemPositions.value) {
      if (min < 0 || position.index < min) min = position.index;
      if (max < 0 || position.index > max) max = position.index;
    }
    if (min < 0) return null;
    return (min: min, max: max);
  }

  /// スクロール通知による追従解除 (ライブモードのみ)。
  ///
  /// 一度離れたらボタンで戻るまで復帰しない (手動で末端に戻しても復帰しない)。
  /// 録画モードはポインターイベントで判定するためここでは何もしない。
  ///
  /// ライブ一覧は追記型のため新着は末端 (`maxScrollExtent`) に足される。
  /// プログラム側の移動は [_programmatic] で除外済みなので、末端からの
  /// 距離が開いたらユーザー操作による離脱とみなす。
  bool _onScrollNotification(ScrollNotification notification) {
    if (_isPlayback || notification is! ScrollUpdateNotification) return false;
    if (_programmatic) return false;
    if (!_following) return false;
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent - metrics.pixels > liveFollowEndThreshold) {
      setState(() => _following = false);
    }
    return false;
  }

  /// 録画モードの追従解除。指のドラッグだけを見る。
  ///
  /// スクロール通知では初回着地や移動の整定とユーザー操作を区別できない。
  /// ホバー (ボタンなしの移動) は無視する。
  void _onPointerMove(PointerMoveEvent event) {
    if (!_isPlayback || event.buttons == 0) return;
    if (_following) setState(() => _following = false);
  }

  /// 録画モードの追従解除。ホイール・トラックパッドのスクロールを見る。
  void _onPointerSignal(PointerSignalEvent event) {
    if (!_isPlayback || event is! PointerScrollEvent) return;
    if (_following) setState(() => _following = false);
  }

  /// 可視範囲の確定に合わせて戻るボタンの向きを更新する。
  ///
  /// 向きが変わるときだけ作り直す (スクロール中は毎フレーム通知が来るため、
  /// 毎回作り直すと映像のフレームを奪う)。
  void _onPositionsChanged() {
    if (!mounted || _following || !_isPlayback) return;
    _refreshJumpIcon();
  }

  /// 追従先の行が画面内にあるかを返す。
  ///
  /// 録画・追従中の据え置き判定に使う。範囲不明 (配置前) は画面外扱いに
  /// して移動側に倒す (初回着地など)。
  bool _isAnchorVisible(int due) {
    final comments = widget.controller.state.comments;
    if (comments.isEmpty) return true;
    final target = playbackBuilderIndex(
      commentCount: comments.length,
      dueCount: due,
    );
    final range = _visibleRange();
    return range != null && target >= range.min && target <= range.max;
  }

  /// 戻るボタンの向きを最新に保つ (録画・非追従時のみ)。
  ///
  /// 向きが変わるときだけ作り直す。再生位置の通知は高頻度に届くため、
  /// 向きに関わらない通知ごとの再構築は映像のフレームを奪う。
  void _refreshJumpIcon() {
    if (!mounted || _following || !_isPlayback) return;
    final comments = widget.controller.state.comments;
    final icon = commentJumpIcon(
      isPlayback: true,
      anchor: playbackBuilderIndex(
        commentCount: comments.length,
        dueCount: _lastDue,
      ),
      visibleRange: _visibleRange(),
    );
    if (icon == _jumpIcon) return;
    _jumpIcon = icon;
    setState(() {});
  }

  /// コメントの増減を反映し、追従中なら表示位置を保つ。
  ///
  /// ライブは追記で伸びた末端へ寄せ直し、最新コメントを常に一番下に据える。
  /// 既存行の添字と内容は不変のため、再構築では新着行だけが配置される。
  ///
  /// スクロール自体は次フレームに寄せる ([_scheduleLivePin]/[_schedulePin])。
  /// 通知中に同期して動かすと配置確定前の計測で不要な移動を招くため。
  void _onCommentsChanged() {
    if (!mounted) return;
    if (_isPlayback) _lastDue = _dueCount();
    setState(() {});
    if (!_following) return;
    if (_isPlayback) {
      _schedulePin();
    } else {
      _scheduleLivePin();
    }
  }

  /// 再生位置の進行を反映する。
  ///
  /// 位置通知は再生中ずっと高頻度に届く。該当コメントが変わったときだけ
  /// 扱い、さらに表示に変化がない通知は捨てる:
  ///
  /// - 追従中は追従先が画面外に出たときだけ作り直す (スクロール移動を伴う)。
  ///   画面内なら行の内容も位置も変わらないため、通知ごとの再構築は
  ///   映像・弾幕のフレームを奪うだけになる。これが録画追従中の
  ///   カクつきの主因だった。
  /// - 非追従は戻るボタンの向きが変わるときだけ作り直す。
  void _onPosition(Duration position) {
    if (!mounted || !_isPlayback) return;
    _position = position;
    final due = _dueCount();
    if (due == _lastDue) return;
    _lastDue = due;
    if (_following) {
      if (_isAnchorVisible(due)) return;
      setState(() {});
      _schedulePin();
      return;
    }
    _refreshJumpIcon();
  }

  /// ライブ一覧を末端 (最新) へ飛ばす。
  ///
  /// 配置確定後 (post-frame) に呼ぶこと。追記で伸びた分だけの移動であり、
  /// 既存行の再配置は起きない。既に末端にいるときは何もしない。
  void _pinLiveToEnd() {
    if (!mounted || !_liveScroll.hasClients) return;
    final position = _liveScroll.position;
    if (position.maxScrollExtent - position.pixels <= livePinEpsilon) return;
    _programmatic = true;
    _liveScroll.jumpTo(position.maxScrollExtent);
    // スクロール通知は配置確定後に届くため、同期して旗を戻すと
    // プログラム側の移動をユーザー操作と誤検出して追従を切ってしまう。
    // 次フレームまで保つ。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmatic = false;
    });
  }

  /// ライブの末端への移動を次フレームに予約する (追従中のみ)。
  ///
  /// 同一フレーム内の複数回到着は1回に束ねる。
  void _scheduleLivePin() {
    if (_pinScheduled) return;
    _pinScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinScheduled = false;
      if (!mounted || _isPlayback || !_following) return;
      _pinLiveToEnd();
    });
  }

  /// 追従スクロールを次フレームに予約する。同一フレーム内の複数回到着は
  /// 1回に束ね、配置確定後の新しい可視範囲で移動要否を判定する。
  ///
  /// 録画モードでのみ使う。ライブは [_scheduleLivePin] で末端へ寄せる。
  void _schedulePin() {
    if (_pinScheduled) return;
    _pinScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinScheduled = false;
      if (!mounted) return;
      // ボタンで追従を切り直した直後は [_jumpToAnchor] 側が移動するため、
      // ここでは追従中のまま残っている場合だけ寄せる。
      if (_following) _pinToTarget();
    });
  }

  /// 追従先を下端に据える。既に見えていれば何もしない。
  ///
  /// 録画モードでのみ使う ([_schedulePin] から配置確定後に呼ぶこと)。
  /// 通知中に同期して呼ぶと可視範囲が1フレーム古く、不要な移動で
  /// 映像・弾幕のフレームを奪う。
  ///
  /// 瞬時に飛ぶ (アニメーションで横切ると通過する行を全て組み立てるため、
  /// コメント数に比例して固まる)。同じ位置への移動は見た目の変化が無い。
  /// 一覧の端 (録画の冒頭など) では可視範囲に収まっている間は飛ばず、
  /// 初回着地のまま再生位置を迎える。
  void _pinToTarget() {
    if (!mounted || !_items.isAttached) return;
    final comments = widget.controller.state.comments;
    if (comments.isEmpty) return;
    if (_isAnchorVisible(_lastDue)) return;
    _moveTo(
      index: playbackBuilderIndex(
        commentCount: comments.length,
        dueCount: _lastDue,
      ),
      alignment: 0,
    );
  }

  /// 指定行へ移動する。近傍だけアニメーションし、遠方は瞬時に飛ぶ。
  ///
  /// 録画モードでのみ使う (ライブの復帰は `_liveScroll` への瞬時移動)。
  void _moveTo({required int index, required double alignment, bool animate = false}) {
    if (!mounted || !_items.isAttached) return;
    if (animate) {
      _programmatic = true;
      unawaited(
        _items
            .scrollTo(
              index: index,
              alignment: alignment,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            )
            .then((_) => _programmatic = false),
      );
    } else {
      _programmatic = true;
      _items.jumpTo(index: index, alignment: alignment);
      // スクロール通知は配置確定後に届くため、同期して旗を戻すと
      // プログラム側の移動をユーザー操作と誤検出して追従を切ってしまう
      // (余計な作り直しで映像・弾幕のフレームを奪う)。次フレームまで保つ。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _programmatic = false;
      });
    }
  }

  /// ボタンで追従に復帰する。
  ///
  /// ライブは末端 (最新) へ瞬時に戻す ([_pinLiveToEnd])。アニメーションで
  /// 横切ると通過行を全て組み立てるため、近傍の滑らかさより1フレームで
  /// 終わる瞬時移動を優先する (数行の瞬間移動は視覚的にも問題ない)。
  ///
  /// 録画は近傍だけ滑らかに寄せ、遠方は瞬時に飛ぶ。
  void _jumpToAnchor() {
    setState(() => _following = true);
    // 初回組み立て直後など未装着の場合に備えて次フレームで試す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isPlayback) {
        _pinLiveToEnd();
        return;
      }
      if (!_items.isAttached) return;
      final comments = widget.controller.state.comments;
      if (comments.isEmpty) return;
      final target = playbackBuilderIndex(
        commentCount: comments.length,
        dueCount: _lastDue,
      );
      final range = _visibleRange();
      var distance = -1;
      if (range != null) {
        distance = target < range.min
            ? range.min - target
            : target - range.max;
      }
      if (distance > 0 && distance <= commentListFarItemDistance) {
        _moveTo(index: target, alignment: 0, animate: true);
      } else {
        _moveTo(index: target, alignment: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // controller の通知は [_onCommentsChanged] で受けて作り直す。
    final state = widget.controller.state;
    return switch (state.status) {
      // 実況チャンネルが無い場合。サーバー側 (close 1008) とクライアント側の
      // 対応表の判定とで同じ文言に揃えている。
      JikkyoCommentStatus.unsupported => _Message(
        icon: Icons.chat_bubble_outline,
        message: state.message ?? unsupportedChannelMessage,
      ),
      // 実況チャンネルは対応しているが、いま放送していない。
      JikkyoCommentStatus.unavailable => _Message(
        icon: Icons.live_tv_outlined,
        message: state.message ?? 'このチャンネルは現在放送していません',
      ),
      JikkyoCommentStatus.ended => _Message(
        icon: Icons.live_tv_outlined,
        message: state.message ?? '放送が終了しました',
      ),
      JikkyoCommentStatus.error => _Message(
        icon: Icons.error_outline,
        message: state.message ?? '接続に失敗しました',
        action: FilledButton.tonal(
          onPressed: widget.controller.retry,
          child: const Text('再試行'),
        ),
      ),
      JikkyoCommentStatus.connecting => const Center(
        child: CircularProgressIndicator(),
      ),
      // 購読済みだがまだコメント来ていなければ、そのまま空のリストにする。
      JikkyoCommentStatus.ready => _buildList(state.comments),
    };
  }

  Widget _buildList(List<JikkyoComment> comments) {
    if (comments.isEmpty) {
      return const _Message(
        icon: Icons.chat_bubble_outline,
        message: 'コメントはまだありません',
      );
    }
    // 録画の再生位置に対応する行 (表示添字)。追従先とボタンの向きに使う。
    // ライブのボタンは常に下向きなので添字は不要。
    final anchor = _isPlayback
        ? playbackBuilderIndex(
            commentCount: comments.length,
            dueCount: _lastDue,
          )
        : -1;
    return Listener(
      onPointerMove: _onPointerMove,
      onPointerSignal: _onPointerSignal,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          children: [
            if (_isPlayback)
              ScrollablePositionedList.builder(
                itemScrollController: _items,
                itemPositionsListener: _positions,
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: comments.length,
                // 録画は初回から再生位置に着地させる (末尾一瞬映りを避ける)。
                initialScrollIndex: anchor,
                initialAlignment: 0,
                itemBuilder: (context, index) {
                  // `reverse: true` なので index 0 が最新 (下端)。
                  final ascending = comments.length - 1 - index;
                  return _CommentRow(comment: comments[ascending]);
                },
              )
            else
              // ライブは追記型の通常 `ListView` で足りる。可変行高での任意位置
              // ジャンプは不要で、追従も末端への `jumpTo` だけで済む
              // ([_pinLiveToEnd])。新着以外の行は添字も内容も不変のため、
              // 再構築では新着行だけが配置される。
              //
              // 行は状態を持たないため KeepAlive 管理は外す (行ごとの購読・
              // 保持の overhead を避ける)。
              ListView.builder(
                controller: _liveScroll,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: comments.length,
                addAutomaticKeepAlives: false,
                itemBuilder: (context, index) {
                  // 追記型のため添字は古い順のまま (index 0 が最古・上端、
                  // 末尾が最新・下端)。
                  return _CommentRow(comment: comments[index]);
                },
              ),
            if (!_following)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: _isPlayback ? '再生位置に戻る' : '最新に戻る',
                    onPressed: _jumpToAnchor,
                    child: Icon(
                      commentJumpIcon(
                        isPlayback: _isPlayback,
                        anchor: anchor,
                        // ライブは常に下向きなので可視範囲は不要。
                        visibleRange: _isPlayback ? _visibleRange() : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// コメント1行。コメント本文と投稿時刻のみを表示する。
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final JikkyoComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `mail` の色コマンドは使わない。文字色はテーマの onSurface に固定する。
    final color = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              comment.content,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatClockJa(comment.postedAt),
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// 状態メッセージ (非対応・終了・エラー・コメント待ち)。
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
