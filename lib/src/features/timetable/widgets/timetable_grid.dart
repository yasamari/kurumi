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
import 'timetable_pan_scroll.dart';
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
///
/// ドラッグ・ホイールは [TimetablePanScroll] が1本で受ける (斜めも可)。
/// 列の `ListView` は `NeverScrollableScrollPhysics` なので自分では
/// スクロールしない。慣性・端のクランプ・仮想化はこれまでどおり。
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
    final hourMarks = timetableHourMarksMs(data.startMs, data.endMs);
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
                                  _NowLine(data: data, offset: _vLink.offset),
                                ],
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
/// 列の再構築は起こさず、表示の切り替えだけを `AnimatedBuilder` で受ける。
/// コールバックが null の側は出さない。
class _EdgeButtons extends StatelessWidget {
  const _EdgeButtons({
    required this.verticalLink,
    required this.onRequestPreviousDay,
    required this.onRequestNextDay,
  });

  final TimetableScrollLink verticalLink;
  final VoidCallback? onRequestPreviousDay;
  final VoidCallback? onRequestNextDay;

  @override
  Widget build(BuildContext context) {
    if (onRequestPreviousDay == null && onRequestNextDay == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: verticalLink,
      builder: (context, _) {
        final max = verticalLink.maxOffset;
        // 内容がビューポートに収まる (max が 0) ときは出さない。
        final showTop =
            onRequestPreviousDay != null && max > 0 && verticalLink.offset <= 1;
        final showBottom =
            onRequestNextDay != null &&
            max > 0 &&
            verticalLink.offset >= max - 1;
        return Stack(
          children: [
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _EdgeButton(
                  visible: showTop,
                  icon: Icons.expand_less,
                  label: '前の日',
                  onPressed: onRequestPreviousDay ?? () {},
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: _EdgeButton(
                  visible: showBottom,
                  icon: Icons.expand_more,
                  label: '次の日',
                  onPressed: onRequestNextDay ?? () {},
                ),
              ),
            ),
          ],
        );
      },
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

  final bool visible;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          ),
        ),
      ),
    );
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
    final gridHeightPx = timetableHeightPx(data.startMs, data.endMs);
    // 空白埋めで全列がちょうど同じ高さになる。列の高さが揃っていないと
    // オフセット共有の前提が崩れ、短い列への追従で引き戻される。
    final segments = timetableColumnSegments(
      programs: widget.column.programs,
      rangeStartMs: data.startMs,
      rangeEndMs: data.endMs,
      gridHeightPx: gridHeightPx,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      // 波紋描画用の `Material` は列に1つだけ置く (セルごとの `Material` は
      // 初回構築のウィジェット数を膨らませるため)。
      child: Material(
        type: MaterialType.transparency,
        child: _NoScrollbar(
          child: ListView.custom(
            controller: _controller,
            // 斜めスクロールのためドラッグは `TimetablePanScroll` に
            // 一本化する。仮想化 (可視セルだけ作る) はコントローラーの
            // 駆動で残る。
            physics: const NeverScrollableScrollPhysics(),
            // 総高さは空白埋めで既知なので、`ListView` の推定に任せず
            // 正確に与える (番組のない列が早期にクランプして共有
            // オフセットを引き戻すのを防ぐ)。
            childrenDelegate: _ExactExtentChildDelegate(
              (context, index) {
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
              totalExtentPx: gridHeightPx,
              childCount: segments.length,
              addAutomaticKeepAlives: false,
              // セル内容は静的でスクロールでは再描画されないため、セル単位の
              // 境界は作らない (レイヤー数を抑える)。
              addRepaintBoundaries: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// 列の総高さが既知のときに `maxScrollExtent` を正確に与えるデリゲート。
///
/// 番組のない時間帯を1つの巨大な空白セルで埋めるため、`ListView` 既定の
/// `estimateMaxScrollOffset` は可視範囲より下の空白をまだ構築していない
/// 時点で総高さを過小評価する。過小評価された列はスクロール中に手前で
/// クランプし、その `ScrollPosition` の通知が [TimetableScrollLink] の
/// 共有オフセットを引き戻す (一部時間しか放送しない列で顕著)。総高さは
/// `timetableColumnSegments` の空白埋めで全列・ガターと一致するため、
/// それをそのまま `scrollExtent` として返す。
class _ExactExtentChildDelegate extends SliverChildBuilderDelegate {
  _ExactExtentChildDelegate(
    super.builder, {
    required this.totalExtentPx,
    super.childCount,
    super.addAutomaticKeepAlives,
    super.addRepaintBoundaries,
  });

  /// 全列で揃えた列の総高さ (px)。
  final double totalExtentPx;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    return totalExtentPx;
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
