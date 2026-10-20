import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';
import '../timetable_layout.dart';
import '../timetable_scroll_link.dart';
import 'timetable_cell_raster.dart';

/// チャンネル1列。セルをウィジェットで並べず、1枚の [CustomPaint] で描く。
///
/// 背景・アクセント・本文画像はすべてキャンバス描画で、スクロール中は
/// [TimetableScrollLink] の通知で再描画するだけ。ウィジェットの構築・
/// レイアウトは発生しない。
class TimetableColumnView extends StatefulWidget {
  const TimetableColumnView({
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
  State<TimetableColumnView> createState() => _TimetableColumnViewState();
}

class _TimetableColumnViewState extends State<TimetableColumnView> {
  late List<TimetableColumnSegment> _segments = _buildSegments();

  TimetableCellStyle? _style;
  TimetableCellRasterCache? _cache;

  double _viewportHeight = 0;
  int _first = -1;
  int _last = -1;
  int _visibleFirst = -1;
  int _visibleLast = -1;
  final Queue<int> _pending = Queue<int>();
  final Set<int> _pendingSet = <int>{};
  bool _processScheduled = false;
  bool _generating = false;
  bool _needsRebuild = false;
  bool _disposed = false;
  double _lastOffset = 0;
  Timer? _resumeTimer;

  List<TimetableColumnSegment> _buildSegments() {
    return timetableColumnSegments(
      programs: widget.column.programs,
      rangeStartMs: widget.data.startMs,
      rangeEndMs: widget.data.endMs,
      gridHeightPx: timetableHeightPx(widget.data.startMs, widget.data.endMs),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.link.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final style = TimetableCellStyle.of(context);
    if (_style == style) return;
    _style = style;
    final cache = _cache;
    if (cache == null) {
      _cache = TimetableCellRasterCache(style);
    } else {
      cache.updateStyle(style);
    }
    _resetWindow();
  }

  @override
  void didUpdateWidget(covariant TimetableColumnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.link, widget.link)) {
      oldWidget.link.removeListener(_onScroll);
      widget.link.addListener(_onScroll);
      _resetWindow();
    }
    if (!identical(oldWidget.column, widget.column) ||
        !identical(oldWidget.data, widget.data)) {
      _segments = _buildSegments();
      _resetWindow();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _resumeTimer?.cancel();
    _pending.clear();
    _pendingSet.clear();
    widget.link.removeListener(_onScroll);
    _cache?.dispose();
    super.dispose();
  }

  void _resetWindow() {
    _first = -1;
    _last = -1;
    _visibleFirst = -1;
    _visibleLast = -1;
    _needsRebuild = true;
    _pending.clear();
    _pendingSet.clear();
  }

  void _onScroll() {
    if (_viewportHeight <= 0) return;
    _ensureWindow();
  }

  /// 表示窓の画像を用意し、窓外の画像を捨てる。窓が変わらない間は何もしない。
  ///
  /// 画像の作成は [TimetableCellRasterCache.ensure] 1件あたりが重いため、
  /// ここではキューに入れるだけにして、フレーム後に少しずつ焼く。スクロール
  /// 中に一度に何十件も焼くと UI スレッドが数十ms止まり、フレーム落ちする。
  void _ensureWindow() {
    final cache = _cache;
    if (cache == null || _viewportHeight <= 0) return;
    final range = timetableSegmentWindow(
      segments: _segments,
      offsetPx: widget.link.offset,
      viewportHeightPx: _viewportHeight,
      cacheExtentPx: math.max(600.0, math.min(1000.0, _viewportHeight)),
    );
    if (range.first != _first || range.last != _last) {
      _first = range.first;
      _last = range.last;
    }
    if (widget.link.isScrolling) {
      // スクロール中も可視セルの画像だけは1件ずつ作る。Picture を毎回
      // 組み立てたり直接描いたりすると重いので、ここではキューに入れるだけ。
      // retain/先読みの再構築は停止後にまとめて行う。
      _needsRebuild = true;
      _queueVisible(cache);
      _scheduleResume();
      return;
    }
    if (_needsRebuild) {
      _needsRebuild = false;
      _rebuildPending(cache);
    }
    _scheduleProcess();
  }

  /// スクロール中、いま見えているセルで画像が無いものだけをキューに積む。
  ///
  /// 可視範囲が変わった時だけ動かす。既存のキューは捨て、可視セルを
  /// 優先する。セルは1件ずつ Picture を作って通知するため、画像化が
  /// 終わる前でも文字はフォールバックで表示される。全セルの Picture を
  /// 同期生成するよりスクロールを軽く保てる。
  void _queueVisible(TimetableCellRasterCache cache) {
    if (_segments.isEmpty) return;
    final visible = timetableSegmentWindow(
      segments: _segments,
      offsetPx: widget.link.offset,
      viewportHeightPx: _viewportHeight,
      cacheExtentPx: 0,
    );
    if (visible.first == _visibleFirst && visible.last == _visibleLast) {
      return;
    }
    _visibleFirst = visible.first;
    _visibleLast = visible.last;
    _pending.clear();
    _pendingSet.clear();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var index = visible.first; index < visible.last; index++) {
      final segment = _segments[index];
      final program = segment.program;
      if (program == null) continue;
      final startMs = program.startAt.millisecondsSinceEpoch;
      final endMs = program.endAt.millisecondsSinceEpoch;
      if (!cache.needsWork(
        program: program,
        isOnAir: startMs <= nowMs && nowMs < endMs,
        cellHeightPx: segment.heightPx,
      )) {
        continue;
      }
      _pendingSet.add(index);
      _pending.add(index);
    }
    _scheduleProcess();
  }

  /// 現在の表示窓で不足している画像をキューへ積む。
  ///
  /// 既存のキューは捨てずに引き継ぐ。窓が変わるたびに捨てると、先読み側の
  /// 画像がスクロール中にいつまでも作られず、可視になってから fallback の
  /// テキストを描くことになる (raster が重い)。可視セルを最優先し、次に
  /// スクロール方向の先を積む。
  void _rebuildPending(TimetableCellRasterCache cache) {
    if (_segments.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final eventIds = <int>{};
    for (var index = _first; index < _last; index++) {
      final program = _segments[index].program;
      if (program != null) eventIds.add(program.eventId);
    }
    cache.retain(
      eventIds: eventIds,
      offsetPx: widget.link.offset,
      viewportHeightPx: _viewportHeight,
    );

    final previous = _pending.toList();
    _pending.clear();
    _pendingSet.clear();

    void queue(int index) {
      if (index < _first || index >= _last) return;
      if (_pendingSet.contains(index)) return;
      final segment = _segments[index];
      final program = segment.program;
      if (program == null) return;
      final startMs = program.startAt.millisecondsSinceEpoch;
      final endMs = program.endAt.millisecondsSinceEpoch;
      if (!cache.needsWork(
        program: program,
        isOnAir: startMs <= nowMs && nowMs < endMs,
        cellHeightPx: segment.heightPx,
      )) {
        return;
      }
      _pendingSet.add(index);
      _pending.add(index);
    }

    final visible = timetableSegmentWindow(
      segments: _segments,
      offsetPx: widget.link.offset,
      viewportHeightPx: _viewportHeight,
      cacheExtentPx: 0,
    );
    final direction = widget.link.offset >= _lastOffset ? 1 : -1;
    _lastOffset = widget.link.offset;

    // 1. いま見えているセル
    for (var index = visible.first; index < visible.last; index++) {
      queue(index);
    }
    // 2. スクロール方向の先読み
    if (direction >= 0) {
      for (var index = visible.last; index < _last; index++) {
        queue(index);
      }
    } else {
      for (var index = visible.first - 1; index >= _first; index--) {
        queue(index);
      }
    }
    // 3. 前フレームから残っているキュー (可視・先読み済みは重複しない)
    for (final index in previous) {
      queue(index);
    }
    // 4. 反対側の先読み
    if (direction >= 0) {
      for (var index = _first; index < visible.first; index++) {
        queue(index);
      }
    } else {
      for (var index = _last - 1; index >= visible.last; index--) {
        queue(index);
      }
    }
  }

  /// キューから画像を1件ずつ作る。
  ///
  /// 1件の完了を待ってから次を作るので、`toImage` が同時に走らない。
  /// スクロール中も可視セルを優先して進め、停止判定後は先読みを含めた
  /// 表示窓の再構築を行う。
  Future<void> _processPending() async {
    if (_disposed || _generating) return;
    final cache = _cache;
    if (cache == null) return;
    if (widget.link.isScrolling) {
      // 停止判定のタイマーを切らさない。キューが空のまま最後の通知が来て
      // タイマーが消費されると、停止後にフォールバック生成が走らなくなる。
      _scheduleResume();
    }
    if (_needsRebuild && !widget.link.isScrolling) {
      _needsRebuild = false;
      _rebuildPending(cache);
    }
    if (_pending.isEmpty) return;
    _generating = true;
    try {
      while (_pending.isNotEmpty) {
        final index = _pending.removeFirst();
        _pendingSet.remove(index);
        if (index < _first || index >= _last) continue;
        final segment = _segments[index];
        final program = segment.program;
        if (program == null) continue;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final startMs = program.startAt.millisecondsSinceEpoch;
        final endMs = program.endAt.millisecondsSinceEpoch;
        if (!cache.needsWork(
          program: program,
          isOnAir: startMs <= nowMs && nowMs < endMs,
          cellHeightPx: segment.heightPx,
        )) {
          continue;
        }
        await cache.ensure(
          program: program,
          isOnAir: startMs <= nowMs && nowMs < endMs,
          cellHeightPx: segment.heightPx,
          topPx: segment.topPx,
        );
        break;
      }
    } finally {
      _generating = false;
    }
    if (!_disposed && _pending.isNotEmpty) _scheduleProcess();
  }

  void _scheduleProcess() {
    if (_processScheduled ||
        _generating ||
        _disposed ||
        (_pending.isEmpty && !_needsRebuild)) {
      return;
    }
    _processScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _processScheduled = false;
      if (_disposed || !mounted) return;
      unawaited(_processPending());
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// スクロールが止まった頃に画像生成を再開する。
  ///
  /// スクロール中もタイマー自体は動かし続け、止まったことを確認してから
  /// キューを再構築する。ここで `_pending` を条件にすると、スクロール中に
  /// 窓が変わってキューが空になった時に再開されなくなる。
  void _scheduleResume() {
    if (_disposed || _resumeTimer != null) return;
    _resumeTimer = Timer(const Duration(milliseconds: 32), () {
      _resumeTimer = null;
      if (_disposed) return;
      _scheduleProcess();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = math.max(0.0, constraints.maxHeight);
        if (viewportHeight != _viewportHeight) {
          _viewportHeight = viewportHeight;
          _resetWindow();
        }
        final cache = _cache;
        final style = _style;
        if (cache == null || style == null) {
          return const SizedBox.expand();
        }
        _ensureWindow();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTap,
          child: CustomPaint(
            painter: _TimetableColumnPainter(
              segments: _segments,
              cache: cache,
              link: widget.link,
              style: style,
              onProgramTap: widget.onProgramTap,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _handleTap(TapUpDetails details) {
    final index = timetableSegmentIndexAt(
      segments: _segments,
      yPx: widget.link.offset + details.localPosition.dy,
    );
    if (index == null) return;
    final program = _segments[index].program;
    if (program != null) widget.onProgramTap(program);
  }
}

double _snap(double value, double devicePixelRatio) {
  if (devicePixelRatio <= 0) return value;
  return (value * devicePixelRatio).roundToDouble() / devicePixelRatio;
}

/// 列のセル・背景・アクセントを描く。本文はキャッシュ済み画像を貼る。
class _TimetableColumnPainter extends CustomPainter {
  _TimetableColumnPainter({
    required this.segments,
    required this.cache,
    required this.link,
    required this.style,
    required this.onProgramTap,
  }) : super(repaint: Listenable.merge([link, cache]));

  final List<TimetableColumnSegment> segments;
  final TimetableCellRasterCache cache;
  final TimetableScrollLink link;
  final TimetableCellStyle style;
  final void Function(TvProgram program) onProgramTap;

  @override
  SemanticsBuilderCallback get semanticsBuilder => _buildSemantics;

  List<CustomPainterSemantics> _buildSemantics(Size size) {
    final offset = _snap(link.offset, style.devicePixelRatio);
    final result = <CustomPainterSemantics>[];
    for (final segment in segments) {
      final program = segment.program;
      if (program == null) continue;
      final top = segment.topPx - offset;
      final bottom = top + segment.heightPx;
      if (bottom <= 0 || top >= size.height) continue;
      result.add(
        CustomPainterSemantics(
          rect: Rect.fromLTRB(
            0,
            math.max(0, top),
            size.width,
            math.min(size.height, bottom),
          ),
          properties: SemanticsProperties(
            label:
                '${formatTimetableCellTime(program.startAt, program.endAt)} '
                '${program.title}',
            button: true,
            onTap: () => onProgramTap(program),
          ),
        ),
      );
    }
    return result;
  }

  final Paint _fillPaint = Paint();
  final Paint _borderPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final dpr = style.devicePixelRatio;
    final offset = _snap(link.offset, dpr);
    final cellWidth = math.max(0.0, size.width - timetableCellGap);
    _borderPaint.color = style.outlineVariant;

    for (final segment in segments) {
      final top = segment.topPx - offset;
      if (top + segment.heightPx <= 0) continue;
      if (top >= size.height) break;
      final program = segment.program;
      if (program == null) continue;

      final topPx = _snap(top, dpr);
      final bottomPx = _snap(top + segment.heightPx - timetableCellGap, dpr);
      if (bottomPx <= topPx) continue;

      _fillPaint.color = style.surfaceContainerHigh;
      canvas.drawRect(Rect.fromLTRB(0, topPx, cellWidth, bottomPx), _fillPaint);
      _fillPaint.color = timetableGenreSeedColor(
        timetableGenreMajor(program.genres),
      );
      canvas.drawRect(Rect.fromLTRB(0, topPx, 4, bottomPx), _fillPaint);

      final raster = cache.rasterFor(program);
      if (raster != null) {
        final contentTop = _snap(top + timetableCellContentTop, dpr);
        final contentLeft = _snap(timetableCellContentLeft, dpr);
        final contentHeight = timetableCellContentHeight(segment.heightPx);
        if (contentHeight > 0) {
          canvas.save();
          canvas.clipRect(
            Rect.fromLTWH(
              contentLeft,
              contentTop,
              timetableCellContentWidth,
              contentHeight,
            ),
          );
          raster.paint(canvas, Offset(contentLeft, contentTop));
          canvas.restore();
        }
      }
    }

    // 列の右罫線。ListView のビューポートが右端を切る。
    canvas.drawRect(
      Rect.fromLTWH(size.width - 1, 0, 1, size.height),
      _borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimetableColumnPainter oldDelegate) {
    return !identical(oldDelegate.segments, segments) ||
        !identical(oldDelegate.cache, cache) ||
        !identical(oldDelegate.link, link) ||
        oldDelegate.style != style;
  }

  @override
  bool shouldRebuildSemantics(covariant _TimetableColumnPainter oldDelegate) {
    return shouldRepaint(oldDelegate);
  }
}
