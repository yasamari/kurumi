import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/channel_logo.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';
import '../timetable_layout.dart';
import '../timetable_scroll_link.dart';
import 'timetable_program_cell.dart';

/// 番組表グリッド。縦=時間・横=チャンネルの2軸スクロール。
///
/// 高フレームレートのための構成:
/// - 横方向はヘッダーと列の2本の `ListView.builder` を [TimetableScrollLink]
///   で連動させる。どちらも可視付近だけ作る (全列を `Row` に並べると不可視
///   列のセルまで初回フレームで作ってしまう)
/// - 縦方向は列ごとの `ListView.builder` (番組境界が列で異なるため) を
///   [TimetableScrollLink] で連動させる。どちらも仮想化される
/// - 罫線・nowラインは `AnimatedBuilder` で線だけ作り直し、列の再構築は
///   起きない
class TimetableGrid extends StatefulWidget {
  const TimetableGrid({
    super.key,
    required this.data,
    required this.onProgramTap,
    required this.onChannelTap,
  });

  /// 表示する1日分。
  final TimetableData data;

  /// 番組タップ時のコールバック。
  final void Function(TimetableChannel column, TvProgram program) onProgramTap;

  /// チャンネルヘッダータップ時のコールバック (視聴遷移用)。
  final void Function(Channel channel) onChannelTap;

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid>
    with AutomaticKeepAliveClientMixin {
  /// 縦スクロールの連動 (ガター+各チャンネル列)。
  late final TimetableScrollLink _vLink = TimetableScrollLink();

  /// 横スクロールの連動 (ヘッダー列+チャンネル列)。縦とは別インスタンス。
  late final TimetableScrollLink _hLink = TimetableScrollLink();

  late final ScrollController _headerController = _hLink.attach();
  late final ScrollController _columnsController = _hLink.attach();

  /// 初回表示のnowジャンプ済みの放送日。日替わりで再実行する。
  int _jumpedForDayMs = -1;

  // タブ切替で破棄されるとスクロール位置とnowジャンプ済み状態を失い、
  // 戻るたびに先頭へ戻ってしまうため、タブの状態は保持する。
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _hLink.detach(_headerController);
    _hLink.detach(_columnsController);
    _vLink.dispose();
    _hLink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final TimetableData data = widget.data;
    final List<TimetableChannel> columns = data.channels;
    final gridHeight = timetableHeightPx(data.startMs, data.endMs);
    final hourMarks = timetableHourMarksMs(data.startMs, data.endMs);
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = max(
          0.0,
          constraints.maxHeight - timetableHeaderHeight,
        );
        _scheduleJumpToNow(viewportHeight, gridHeight);
        // デスクトップのマウスドラッグでもスクロールできるようにする。
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
                          itemExtent: timetableColumnWidth,
                          itemCount: columns.length,
                          itemBuilder: (context, index) => _ChannelHeader(
                            column: columns[index],
                            onTap: () => widget.onChannelTap(
                              columns[index].channel,
                            ),
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
                          itemExtent: timetableColumnWidth,
                          itemCount: columns.length,
                          itemBuilder: (context, index) {
                            final column = columns[index];
                            return _ColumnList(
                              link: _vLink,
                              data: data,
                              column: column,
                              onProgramTap: (program) =>
                                  widget.onProgramTap(column, program),
                            );
                          },
                        ),
                        // 横スクロールしても横罫線の見え方は変わらないため、
                        // オーバーレイはスクロール外に置く。
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _vLink,
                              builder: (context, _) => Stack(
                                children: [
                                  for (final mark in hourMarks)
                                    Positioned(
                                      top:
                                          timetableOffsetPx(
                                            mark,
                                            data.startMs,
                                          ) -
                                          _vLink.offset,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1,
                                        color: outline,
                                      ),
                                    ),
                                  _NowLine(
                                    data: data,
                                    offset: _vLink.offset,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
          child: grid,
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
      final target = min(
        max(
          timetableOffsetPx(nowMs, data.startMs) - viewportHeight * 0.25,
          0.0,
        ),
        max(0.0, gridHeight - viewportHeight),
      );
      _vLink.jumpTo(target);
    });
  }
}

/// 子のスクロールバーを出さない。列ごとの縦リスト用。
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
    final hours =
        (widget.data.endMs - widget.data.startMs) ~/ 3600000;
    return _NoScrollbar(
      child: ListView.builder(
        controller: _controller,
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
              border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Text(
              '$hour',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
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
  late final ScrollController _controller = widget.link.attach();

  @override
  void dispose() {
    widget.link.detach(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // 空白埋めで全列がちょうど同じ高さになる。列の高さが揃っていないと
    // オフセット共有の前提が崩れ、短い列への追従で引き戻される。
    final segments = timetableColumnSegments(
      programs: widget.column.programs,
      rangeStartMs: data.startMs,
      rangeEndMs: data.endMs,
      gridHeightPx: timetableHeightPx(data.startMs, data.endMs),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      // 波紋描画用の `Material` は列に1つだけ置く (セルごとの `Material` は
      // 初回構築のウィジェット数を膨らませるため)。
      child: Material(
        type: MaterialType.transparency,
        child: _NoScrollbar(
          child: ListView.builder(
            controller: _controller,
            itemCount: segments.length,
            addAutomaticKeepAlives: false,
            // セル内容は静的でスクロールでは再描画されないため、セル単位の
            // 境界は作らない (レイヤー数を抑える)。
            addRepaintBoundaries: false,
            itemBuilder: (context, index) {
              final segment = segments[index];
              final program = segment.program;
              if (program == null) {
                return SizedBox(height: segment.heightPx);
              }
              final startMs = program.startAt.millisecondsSinceEpoch;
              final endMs = program.endAt.millisecondsSinceEpoch;
              return SizedBox(
                height: segment.heightPx,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

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
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                          ),
                        Text(
                          channel.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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

/// 現在時刻のライン。30秒ごとに自分だけ作り直す。
class _NowLine extends StatefulWidget {
  const _NowLine({required this.data, required this.offset});

  final TimetableData data;
  final double offset;

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
    final top = timetableOffsetPx(_nowMs, data.startMs) - widget.offset;
    final gridHeight = timetableHeightPx(data.startMs, data.endMs);
    if (top < 0 || top > gridHeight) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final label = formatTimetableCellTime(
      DateTime.fromMillisecondsSinceEpoch(_nowMs),
      DateTime.fromMillisecondsSinceEpoch(_nowMs),
    ).split('-').first;
    // 外側のオーバーレイ `Stack` に対して配置するため `Positioned.fill` で
    // 包む。素の `Stack` を返すと0サイズになり、子の `Positioned` の基準が
    // ずれて線が見えなくなる。
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onError,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
