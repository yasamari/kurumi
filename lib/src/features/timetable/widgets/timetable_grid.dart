import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/channel_logo.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';
import '../timetable_layout.dart';
import '../timetable_scroll_link.dart';
import 'timetable_pan_scroll.dart';
import 'timetable_program_cell.dart';

/// 番組表グリッド。縦=時間・横=チャンネルの2軸スクロール。
///
/// 高フレームレートのための構成:
/// - 横方向はヘッダーと列の2本の `ListView.builder` を [TimetableScrollLink]
///   で連動させる。どちらも可視付近だけ作る (全列を `Row` に並べると不可視
///   列のセルまで初回フレームで作ってしまう)
/// - 縦方向の実スクロールはガターの `ListView` 1本だけ。各列は
///   [TimetableScrollLink.offset] を購読し、表示窓のセルだけを
///   `Transform` で平行移動する (列ごとの viewport 再レイアウトが無い)
/// - 罫線・nowラインはスクロール外のオーバーレイで、`Transform` の更新だけ
///   行う (罫線24本は日付が変わるまで作り直さない)
///
/// ドラッグ・ホイールは [TimetablePanScroll] が1本で受ける (斜めも可)。
/// ガター・ヘッダー・横列の `ListView` は `NeverScrollableScrollPhysics` なので
/// 自分ではスクロールしない。慣性・端のクランプはこれまでどおり。
class TimetableGrid extends StatefulWidget {
  const TimetableGrid({
    super.key,
    required this.data,
    required this.onProgramTap,
    required this.onChannelTap,
    this.visibleHourMs,
    this.jumpToTimeMs,
    this.scrollRequestId = 0,
    this.onRequestPreviousDay,
    this.onRequestNextDay,
  });

  /// 表示する1日分。
  final TimetableData data;

  /// 番組タップ時のコールバック。
  final void Function(TimetableChannel column, TvProgram program) onProgramTap;

  /// チャンネルヘッダータップ時のコールバック (視聴遷移用)。
  final void Function(Channel channel) onChannelTap;

  /// グリッド上端に見えている時刻の正時 (ms epoch) を書き込む先。
  ///
  /// 上部の時刻ボタンが購読する。`ValueNotifier` で直接渡すため、
  /// スクロール中の画面全体の作り直しは起きない。正時が変わったときだけ
  /// 書き込む。
  final ValueNotifier<int>? visibleHourMs;

  /// 外部からのスクロール要求 (時刻メニュー・現在ボタン用)。
  ///
  /// [scrollRequestId] が変わったら [jumpToTimeMs] へジャンプする。タブを
  /// 使わないため水平スワイプとの干渉はなく、ID 変化での宣言的ジャンプで
  /// 足りる。
  final int? jumpToTimeMs;

  /// スクロール要求の世代。変化したらジャンプする。
  final int scrollRequestId;

  /// 上端到達時に出す「前の日」ボタンのコールバック。null では出さない。
  final VoidCallback? onRequestPreviousDay;

  /// 下端到達時に出す「次の日」ボタンのコールバック。null では出さない。
  final VoidCallback? onRequestNextDay;

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  /// 縦スクロールの連動 (ガター+各チャンネル列)。
  late final TimetableScrollLink _vLink = TimetableScrollLink();

  /// 横スクロールの連動 (ヘッダー列+チャンネル列)。縦とは別インスタンス。
  late final TimetableScrollLink _hLink = TimetableScrollLink();

  late final ScrollController _headerController = _hLink.attach();
  late final ScrollController _columnsController = _hLink.attach();

  /// 初回表示のnowジャンプ済みの放送日。日替わりで再実行する。
  int _jumpedForDayMs = -1;

  /// 処理済みの外部スクロール要求の世代。
  int _handledRequestId = 0;

  @override
  void initState() {
    super.initState();
    _vLink.addListener(_reportVisibleHour);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 初回レイアウト後に共有オフセットを配信し、端ボタンの表示を更新する。
      // スクロール前は通知が飛ばないため、これが無いと端にいても
      // ボタンが出ない。
      _vLink.jumpTo(_vLink.offset);
    });
  }

  @override
  void didUpdateWidget(covariant TimetableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 種別切替では同じオフセットのまま列だけ変わる。時刻ボタンの表示を
    // 合わせるため再計算する。
    _reportVisibleHour();
  }

  @override
  void dispose() {
    _vLink.removeListener(_reportVisibleHour);
    _hLink.detach(_headerController);
    _hLink.detach(_columnsController);
    _vLink.dispose();
    _hLink.dispose();
    super.dispose();
  }

  /// 縦オフセットの変化を時刻ボタンの表示へ反映する。正時が変わった
  /// ときだけ書き込むため、スクロール中のボタンの作り直しは1時間に1回。
  void _reportVisibleHour() {
    final target = widget.visibleHourMs;
    if (target == null) return;
    final data = widget.data;
    final hourMs = timetableVisibleHourMs(
      offsetPx: _vLink.offset,
      dayStartMs: data.startMs,
      dayEndMs: data.endMs,
    );
    if (target.value != hourMs) {
      target.value = hourMs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TimetableData data = widget.data;
    final List<TimetableChannel> columns = data.channels;
    final gridHeight = timetableHeightPx(data.startMs, data.endMs);
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = max(
          0.0,
          constraints.maxHeight - timetableHeaderHeight,
        );
        _scheduleJumpToNow(viewportHeight, gridHeight);
        _handleScrollRequest(viewportHeight, gridHeight);
        // デスクトップのマウスドラッグ (スクロールバー自体を摘む操作) を
        // 受け付けるようにする。
        final grid = Row(
          children: [
            SizedBox(
              width: timetableGutterWidth,
              child: Column(
                children: [
                  Container(
                    height: timetableHeaderHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: outline),
                        right: BorderSide(color: outline),
                      ),
                    ),
                    child: Text(
                      '時刻',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _GutterList(link: _vLink, data: data),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: timetableHeaderHeight,
                    // 波紋描画用の `Material` はヘッダー行に1つだけ置く。
                    // ヘッダー側のスクロールバーは出さない (列側の1本だけ)。
                    child: Material(
                      type: MaterialType.transparency,
                      child: _NoScrollbar(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          controller: _headerController,
                          // 斜めスクロールのためドラッグは
                          // `TimetablePanScroll` に一本化する。
                          physics: const NeverScrollableScrollPhysics(),
                          itemExtent: timetableColumnWidth,
                          itemCount: columns.length,
                          itemBuilder: (context, index) => _ChannelHeader(
                            column: columns[index],
                            onTap: () =>
                                widget.onChannelTap(columns[index].channel),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: viewportHeight,
                    child: Stack(
                      children: [
                        ListView.builder(
                          scrollDirection: Axis.horizontal,
                          controller: _columnsController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemExtent: timetableColumnWidth,
                          itemCount: columns.length,
                          itemBuilder: (context, index) {
                            final column = columns[index];
                            return _ColumnList(
                              key: ValueKey(column.channel.id),
                              link: _vLink,
                              data: data,
                              column: column,
                              onProgramTap: (program) =>
                                  widget.onProgramTap(column, program),
                            );
                          },
                        ),
                        // 横スクロールしても横罫線の見え方は変わらないため、
                        // オーバーレイはスクロール外に置く。罫線・nowラインの
                        // 中身は日付が変わらない限り作り直さず、スクロール中は
                        // 平行移動の更新だけにする (`Transform` は再描画のみで
                        // 子の再構築を起こさない)。
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: gridHeight,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _vLink,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, -_vLink.offset),
                                child: child,
                              ),
                              child: RepaintBoundary(
                                child: _HourGridOverlay(
                                  data: data,
                                  outline: outline,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 端までスクロールしたら日送りボタンを出す。
                        // 罫線とは別に置く (ボタンはタップを受けるため)。
                        _EdgeButtons(
                          verticalLink: _vLink,
                          onRequestPreviousDay: widget.onRequestPreviousDay,
                          onRequestNextDay: widget.onRequestNextDay,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
          ),
          // 列の ListView はドラッグの競合を避けるため
          // `NeverScrollableScrollPhysics` にしてあり、ドラッグ・ホイールは
          // ここで受けて縦横のリンクへ流す (斜めスクロール)。
          child: TimetablePanScroll(
            verticalLink: _vLink,
            horizontalLink: _hLink,
            child: grid,
          ),
        );
      },
    );
  }

  /// 初回表示時に現在時刻へジャンプする。過去・未来日は何もしない。
  void _scheduleJumpToNow(double viewportHeight, double gridHeight) {
    if (_jumpedForDayMs == widget.data.startMs) return;
    _jumpedForDayMs = widget.data.startMs;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final data = widget.data;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs < data.startMs || nowMs >= data.endMs) return;
      _vLink.jumpTo(
        timetableJumpTargetPx(
          timeMs: nowMs,
          dayStartMs: data.startMs,
          viewportHeightPx: viewportHeight,
          gridHeightPx: gridHeight,
        ),
      );
    });
  }

  /// 時刻メニュー・現在ボタンからのスクロール要求を処理する。
  ///
  /// 要求の世代が変わったときだけ1回ジャンプする。日付が変わってデータが
  /// 届く前の要求は範囲外として捨てられるため、現在ボタンは日付を今日に
  /// 戻してから要求を出す (新データ到着後の build で世代変化を見る)。
  void _handleScrollRequest(double viewportHeight, double gridHeight) {
    final requestId = widget.scrollRequestId;
    final timeMs = widget.jumpToTimeMs;
    if (requestId == _handledRequestId || timeMs == null) return;
    _handledRequestId = requestId;
    final data = widget.data;
    if (timeMs < data.startMs || timeMs >= data.endMs) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vLink.jumpTo(
        timetableJumpTargetPx(
          timeMs: timeMs,
          dayStartMs: widget.data.startMs,
          viewportHeightPx: viewportHeight,
          gridHeightPx: gridHeight,
        ),
      );
    });
  }
}

/// 端到達時の日送りボタン。上端で「前の日」、下端で「次の日」を出す。
///
/// 表示の切り替えは端への到達/離脱でしか起きないため、スクロール中は
/// `ValueNotifier` の更新だけにしてボタンの再構築を起こさない。
/// コールバックが null の側は出さない。
class _EdgeButtons extends StatefulWidget {
  const _EdgeButtons({
    required this.verticalLink,
    required this.onRequestPreviousDay,
    required this.onRequestNextDay,
  });

  final TimetableScrollLink verticalLink;
  final VoidCallback? onRequestPreviousDay;
  final VoidCallback? onRequestNextDay;

  @override
  State<_EdgeButtons> createState() => _EdgeButtonsState();
}

class _EdgeButtonsState extends State<_EdgeButtons> {
  final ValueNotifier<bool> _showTop = ValueNotifier(false);
  final ValueNotifier<bool> _showBottom = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    widget.verticalLink.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(covariant _EdgeButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.verticalLink, widget.verticalLink) ||
        oldWidget.onRequestPreviousDay != widget.onRequestPreviousDay ||
        oldWidget.onRequestNextDay != widget.onRequestNextDay) {
      _sync();
    }
  }

  @override
  void dispose() {
    widget.verticalLink.removeListener(_sync);
    _showTop.dispose();
    _showBottom.dispose();
    super.dispose();
  }

  /// 端の表示状態を同期する。値が変わったときだけ listeners へ通知される。
  void _sync() {
    final max = widget.verticalLink.maxOffset;
    final offset = widget.verticalLink.offset;
    _showTop.value =
        widget.onRequestPreviousDay != null && max > 0 && offset <= 1;
    _showBottom.value =
        widget.onRequestNextDay != null && max > 0 && offset >= max - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onRequestPreviousDay == null &&
        widget.onRequestNextDay == null) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: _EdgeButton(
              visible: _showTop,
              icon: Icons.expand_less,
              label: '前の日',
              onPressed: widget.onRequestPreviousDay ?? () {},
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: _EdgeButton(
              visible: _showBottom,
              icon: Icons.expand_more,
              label: '次の日',
              onPressed: widget.onRequestNextDay ?? () {},
            ),
          ),
        ),
      ],
    );
  }
}

/// 端ボタン本体。フェードで出入りする。
class _EdgeButton extends StatelessWidget {
  const _EdgeButton({
    required this.visible,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final ValueListenable<bool> visible;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, visible, child) => ExcludeSemantics(
        excluding: !visible,
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: child,
          ),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

/// 子のスクロールバーを出さない。ガター・ヘッダー用。
///
/// 列ごとにスクロールバーが出ると30本近く並んでうるさいため消す。
/// 横スクロールバー (単一) は残す。
class _NoScrollbar extends StatelessWidget {
  const _NoScrollbar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
  }
}

/// 時刻ガター。1時間=180px固定の `ListView` で列と連動する。
class _GutterList extends StatefulWidget {
  const _GutterList({required this.link, required this.data});

  final TimetableScrollLink link;
  final TimetableData data;

  @override
  State<_GutterList> createState() => _GutterListState();
}

class _GutterListState extends State<_GutterList> {
  late final ScrollController _controller = widget.link.attach();

  @override
  void dispose() {
    widget.link.detach(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hours = (widget.data.endMs - widget.data.startMs) ~/ 3600000;
    return _NoScrollbar(
      child: ListView.builder(
        controller: _controller,
        // 斜めスクロールのためドラッグは `TimetablePanScroll` に一本化する。
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: 60 * timetablePxPerMin,
        itemCount: hours,
        addAutomaticKeepAlives: false,
        // 時刻ラベルは静的なため境界は作らない。
        addRepaintBoundaries: false,
        itemBuilder: (context, index) {
          final hour = toJst(
            DateTime.fromMillisecondsSinceEpoch(
              widget.data.startMs + index * 3600000,
            ),
          ).hour;
          return Container(
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Text(
              '$hour',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          );
        },
      ),
    );
  }
}

/// チャンネル1列。番組ブロックを番組尺通りの高さで並べる。
class _ColumnList extends StatefulWidget {
  const _ColumnList({
    super.key,
    required this.link,
    required this.data,
    required this.column,
    required this.onProgramTap,
  });

  final TimetableScrollLink link;
  final TimetableData data;
  final TimetableChannel column;
  final void Function(TvProgram program) onProgramTap;

  @override
  State<_ColumnList> createState() => _ColumnListState();
}

class _ColumnListState extends State<_ColumnList> {
  /// この列のセグメント列 (空白埋めで1日分の高さに揃う)。データが
  /// 変わらない限り作り直さない。
  late List<TimetableColumnSegment> _segments = _buildSegments();

  /// 縦方向の表示窓 `[first, last)`。窓がずれたときだけ作り直す。
  int _first = 0;
  int _last = 0;

  /// 窓内セグメントの構築済みウィジェット。窓がずれたとき、新しく
  /// 入った添字だけを構築する (同じ添字のウィジェットを作り直すと
  /// 要素が総入れ替えになり、窓内の全セルが再構築されてしまう)。
  final Map<int, Widget> _cellCache = {};

  /// 列の高さ (横 `ListView` のアイテム高)。窓の計算に使う。
  double _viewportHeight = 0;

  List<TimetableColumnSegment> _buildSegments() {
    final data = widget.data;
    return timetableColumnSegments(
      programs: widget.column.programs,
      rangeStartMs: data.startMs,
      rangeEndMs: data.endMs,
      gridHeightPx: timetableHeightPx(data.startMs, data.endMs),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.link.addListener(_syncWindow);
  }

  @override
  void didUpdateWidget(covariant _ColumnList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.link, widget.link)) {
      oldWidget.link.removeListener(_syncWindow);
      widget.link.addListener(_syncWindow);
    }
    if (!identical(oldWidget.column, widget.column) ||
        !identical(oldWidget.data, widget.data)) {
      _segments = _buildSegments();
      _cellCache.clear();
    }
  }

  @override
  void dispose() {
    widget.link.removeListener(_syncWindow);
    super.dispose();
  }

  /// 共有オフセットの変化に合わせて表示窓を追従させる。窓の出入りが
  /// 起きたときだけ再構築する (スクロール中はここで setState しない)。
  void _syncWindow() {
    if (_updateWindow()) setState(() {});
  }

  /// 窓を再計算する。変化があれば true。
  bool _updateWindow() {
    if (_viewportHeight <= 0) return false;
    final range = timetableSegmentWindow(
      segments: _segments,
      offsetPx: widget.link.offset,
      viewportHeightPx: _viewportHeight,
      cacheExtentPx: _windowCacheExtentPx,
    );
    if (range.first == _first && range.last == _last) return false;
    _first = range.first;
    _last = range.last;
    _cellCache.removeWhere((index, _) => index < _first || index >= _last);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      // 波紋描画用の `Material` は列に1つだけ置く (セルごとの `Material` は
      // 初回構築のウィジェット数を膨らませるため)。
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewportHeight = constraints.maxHeight;
            _updateWindow();
            // スクロール中は平行移動の更新だけ行い、セルツリーを
            // 作り直さない (`child` は窓がずれたときにだけ更新される)。
            return AnimatedBuilder(
              animation: widget.link,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -widget.link.offset),
                child: child,
              ),
              child: _buildCells(),
            );
          },
        ),
      ),
    );
  }

  /// 表示窓のセルを1日分の座標に配置する。列の外へはみ出した分は
  /// 横 `ListView` のビューポートが切る。
  Widget _buildCells() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final segments = _segments;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var index = _first; index < _last; index++)
          _cellCache.putIfAbsent(
            index,
            () => _buildSegment(index, segments[index], nowMs),
          ),
      ],
    );
  }

  Widget _buildSegment(int index, TimetableColumnSegment segment, int nowMs) {
    final program = segment.program;
    if (program == null) {
      return Positioned(
        key: ValueKey('gap-$index'),
        top: segment.topPx,
        left: 0,
        right: 0,
        height: segment.heightPx,
        child: const SizedBox.shrink(),
      );
    }
    final startMs = program.startAt.millisecondsSinceEpoch;
    final endMs = program.endAt.millisecondsSinceEpoch;
    return Positioned(
      key: ValueKey(program.eventId),
      top: segment.topPx,
      left: 0,
      right: 0,
      height: segment.heightPx,
      // セルは内容が変わらないため、動かないセルのレイヤーは合成だけで
      // 済ませる (スクロールで描き直さない)。
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: timetableCellGap,
            right: timetableCellGap,
          ),
          child: TimetableProgramCell(
            program: program,
            heightPx: segment.heightPx,
            isOnAir: startMs <= nowMs && nowMs < endMs,
            onTap: () => widget.onProgramTap(program),
          ),
        ),
      ),
    );
  }
}

/// 表示窓の前後に付ける余白 (px)。
///
/// 高速な慣性スクロールでも窓の追従が1フレーム遅れない距離として
/// `ListView` の既定キャッシュ (250px) と同程度にする。
const double _windowCacheExtentPx = 250;

/// チャンネルヘッダー。ロゴ+番号・局名。タップで視聴へ遷移する。
class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.column, required this.onTap});

  final TimetableChannel column;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final channel = column.channel;
    return Container(
      width: timetableColumnWidth,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
          right: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // 波紋描画用の `Material` はヘッダー行が持つ。
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (channel.logoUrl != null)
                  ChannelLogo(channel: channel, width: 52),
                if (channel.logoUrl != null) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (channel.channelNumber.isNotEmpty)
                        Text(
                          channel.channelNumber,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                        ),
                      Text(
                        channel.name,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 罫線とnowラインの重ね描き。日付が変わらない限り作り直さない。
///
/// スクロールへの追従は親の `Transform` が行うため、ここでは1日分の
/// 絶対座標 (日開始からのオフセット) で配置する。
class _HourGridOverlay extends StatelessWidget {
  const _HourGridOverlay({required this.data, required this.outline});

  final TimetableData data;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final mark in timetableHourMarksMs(data.startMs, data.endMs))
          Positioned(
            top: timetableOffsetPx(mark, data.startMs),
            left: 0,
            right: 0,
            child: Container(height: 1, color: outline),
          ),
        _NowLine(data: data),
      ],
    );
  }
}

/// 現在時刻のライン。30秒ごとに自分だけ作り直す。
class _NowLine extends StatefulWidget {
  const _NowLine({required this.data});

  final TimetableData data;

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> {
  late Timer _timer;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (_nowMs < data.startMs || _nowMs >= data.endMs) {
      return const SizedBox.shrink();
    }
    final top = timetableOffsetPx(_nowMs, data.startMs);
    final gridHeight = timetableHeightPx(data.startMs, data.endMs);
    if (top < 0 || top > gridHeight) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final label = formatTimetableCellTime(
      DateTime.fromMillisecondsSinceEpoch(_nowMs),
      DateTime.fromMillisecondsSinceEpoch(_nowMs),
    ).split('-').first;
    // 親のオーバーレイ `Stack` は1日分の高さを持つため、`Positioned.fill`
    // でその全面を占有してから内側で配置する。
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Container(height: 2, color: colorScheme.error),
          ),
          Positioned(
            top: top - 11,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colorScheme.onError, height: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
