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

/// ライブの追従を切る下端からのずれ (論理ピクセル)。
///
/// ライブ一覧は `ListView(reverse: true)` で作り、下端 (最新) のオフセットが
/// 0 になる。プログラム側の移動は `_programmatic` で除外済みのため、ここに
/// 届く通知はユーザー操作によるものだけになる。わずかなずれでも離脱とみなす。
const liveFollowEdgeThreshold = 1.0;

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
/// - ライブモード ([syncStart]/[positionStream] なし): 通常の `ListView`
///   (`reverse: true`) を使う。下端 (最新) のオフセットは 0 に固定されるため、
///   新着が先頭に増えてもスクロール移動なしで下へ流れ込む。追従中は一覧の
///   再構築だけで済み、`ScrollablePositionedList` のような毎回の位置指定
///   (`jumpTo` による再配置・全要素の計測) が走らない。映像・弾幕と vsync を
///   争わないための使い分けで、追従中のカクつきが消える。
/// - 録画モード (両方あり): 行高が可変でも遠方へ飛べるよう
///   [ScrollablePositionedList] を使う (オフセット計算では届かないため)。
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

  /// ライブモード用。通常のスクロール位置 (`reverse: true` なので下端が 0)。
  ///
  /// 新着はオフセットアンカーで自動表示されるため、追従中にここを動かす
  /// 必要はない。動かすのは「最新に戻る」ボタンだけ。
  final _liveScroll = ScrollController();

  StreamSubscription<Duration>? _positionSub;

  /// 位置通知の前回反映キー (再生位置と可視範囲)。変化時のみ作り直す。
  Object? _positionsKey;

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
  /// 一度離れたらボタンで戻るまで復帰しない (手動で下端に戻しても復帰しない)。
  /// 録画モードはポインターイベントで判定するためここでは何もしない。
  ///
  /// ライブ一覧は `reverse: true` のため下端 (最新) のオフセットが 0 になる。
  /// プログラム側の移動は [_programmatic] で除外済みなので、しきい値を超えた
  /// らユーザー操作による離脱とみなす。下端に戻っても自動復帰はしない。
  bool _onScrollNotification(ScrollNotification notification) {
    if (_isPlayback || notification is! ScrollUpdateNotification) return false;
    if (_programmatic) return false;
    if (_following &&
        notification.metrics.pixels > liveFollowEdgeThreshold) {
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
  /// 位置通知はフレーム確定後に届くため、スクロール通知の時点では可視範囲が
  /// 1フレーム古い。ボタン表示中だけ変化分を作り直す (毎フレーム通知が来る
  /// ためキーが変わらなければ何もしない)。
  void _onPositionsChanged() {
    if (!mounted || _following || !_isPlayback) return;
    final key = (_lastDue, _visibleRange());
    if (key == _positionsKey) return;
    _positionsKey = key;
    setState(() {});
  }

  /// コメントの増減を反映し、追従中なら表示位置を保つ。
  ///
  /// ライブは新着が来るたび下端 (index 0) に寄せ直し、最新コメントを常に
  /// 一番下に据える。既に下端にいるときは見た目の変化は無い。
  ///
  /// ライブの移動は不要 (`reverse: true` の下端アンカーで新着が自動表示
  /// される)。毎回の `jumpTo` は位置指定リストの再配置・全要素の計測を
  /// 走らせて映像・弾幕のフレームを奪うため、録画モードでのみ寄せる。
  ///
  /// スクロール自体は [_schedulePin] で次フレームに寄せる。コントローラーの
  /// 通知中に `jumpTo` すると `ScrollablePositionedList` の内部 `setState` と
  /// 再入し、古い可視範囲での不要な移動や通知の誤検出を招くため。
  void _onCommentsChanged() {
    if (!mounted) return;
    if (_isPlayback) _lastDue = _dueCount();
    setState(() {});
    if (_following && _isPlayback) _schedulePin();
  }

  /// 再生位置の進行を反映する。該当コメントが変わったときだけ作り直して
  /// 追従先に飛ぶ (可視行だけの再構築で済む)。
  void _onPosition(Duration position) {
    if (!mounted || !_isPlayback) return;
    _position = position;
    final due = _dueCount();
    if (due == _lastDue) return;
    _lastDue = due;
    setState(() {});
    if (_following) _schedulePin();
  }

  /// 追従スクロールを次フレームに予約する。同一フレーム内の複数回到着は
  /// 1回に束ね、配置確定後の新しい可視範囲で移動要否を判定する。
  ///
  /// 録画モードでのみ使う。ライブは下端アンカーで自動追従するため予約しない。
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
    final target = _isPlayback
        ? playbackBuilderIndex(
            commentCount: comments.length,
            dueCount: _lastDue,
          )
        : 0;
    final range = _visibleRange();
    if (range != null && target >= range.min && target <= range.max) return;
    _moveTo(index: target, alignment: 0);
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
  /// ライブは下端 (offset 0) へ瞬時に戻す。アニメーションで横切ると通過行を
  /// 全て組み立てるため、近傍の滑らかさより1フレームで終わる瞬時移動を優先
  /// する (数行の瞬間移動は視覚的にも問題ない)。
  ///
  /// 録画は近傍だけ滑らかに寄せ、遠方は瞬時に飛ぶ。
  void _jumpToAnchor() {
    setState(() => _following = true);
    // 初回組み立て直後など未装着の場合に備えて次フレームで試す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isPlayback) {
        if (!_liveScroll.hasClients) return;
        _programmatic = true;
        _liveScroll.jumpTo(0);
        // スクロール通知は配置確定後に届くため、同期して旗を戻すと
        // プログラム側の移動をユーザー操作と誤検出して追従を切ってしまう。
        // 次フレームまで保つ。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _programmatic = false;
        });
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
              // ライブは通常の `ListView` で足りる。可変行高での任意位置
              // ジャンプはボタン復帰の下端 (offset 0) しか使わないため。
              // `reverse: true` の下端アンカーで新着が自動表示され、追従中に
              // 位置指定の移動が一切走らない (カクつきの原因だった毎回の
              // `jumpTo` が消える)。
              ListView.builder(
                controller: _liveScroll,
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  // `reverse: true` なので index 0 が最新 (下端)。
                  final ascending = comments.length - 1 - index;
                  return _CommentRow(comment: comments[ascending]);
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
