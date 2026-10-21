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
import '../timetable_zoom.dart';
import 'timetable_cell_raster.dart';
import 'timetable_column_view.dart';
import 'timetable_grid_overlay.dart';
import 'timetable_pan_scroll.dart';

/// 番組表グリッド。縦=時間・横=チャンネルの2軸スクロール。
///
/// 高フレームレートのための構成:
/// - 横方向はヘッダーと列の2本の `ListView.builder` を [TimetableScrollLink]
///   で連動させる。どちらも可視付近だけ作る
/// - 縦方向の実スクロールはガターの `ListView` 1本だけ。各列は
///   [TimetableScrollLink.offset] を購読し、1枚の `CustomPaint` で
///   セル背景と事前ラスタライズ済みの本文画像を描く (セルごとのウィジェット
///   構築・テキストの再ラスタライズをスクロール中に行わない)
/// - 罫線・nowラインもビューポート全体の1枚の `CustomPaint` で描く
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
    required this.zoom,
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

  /// 表示倍率。ピンチ・キーボード・バーのボタンで変更される。
  final TimetableZoomController zoom;

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

  /// スクロール中のセル画像生成を列間で分散させる。
  final TimetableRasterGate _rasterGate = TimetableRasterGate();

  /// 直近にレイアウトしたズーム倍率とビューポート寸法。
  ///
  /// ズーム変更時に「同じ画面位置の時刻」を保つオフセット計算へ使う。
  late double _zoomApplied = widget.zoom.zoom;
  double _viewportHeight = 0;
  double _viewportWidth = 0;

  /// ピンチ中心 (パン領域のローカル座標)。ボタン・キー操作では null。
  Offset? _zoomFocal;

  @override
  void initState() {
    super.initState();
    _vLink.addListener(_reportVisibleHour);
    widget.zoom.addListener(_onZoomChanged);
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
    if (!identical(oldWidget.zoom, widget.zoom)) {
      oldWidget.zoom.removeListener(_onZoomChanged);
      widget.zoom.addListener(_onZoomChanged);
    }
    // 種別切替では同じオフセットのまま列だけ変わる。時刻ボタンの表示を
    // 合わせるため再計算する。
    _reportVisibleHour();
  }

  @override
  void dispose() {
    widget.zoom.removeListener(_onZoomChanged);
    _vLink.removeListener(_reportVisibleHour);
    _hLink.detach(_headerController);
    _hLink.detach(_columnsController);
    _vLink.dispose();
    _hLink.dispose();
    super.dispose();
  }

  /// ズーム倍率が変わったら、ピンチ中心 (無ければビューポート中央) の
  /// 時刻・チャンネルを固定したままスクロール位置を合わせ直す。
  ///
  /// 列幅・1分あたりの高さが変わるため、単に倍率を反映するだけだと
  /// 見ている位置が飛ぶ。オフセットは次のレイアウトに入る前に
  /// [TimetableScrollLink.jumpToUnclamped] で適用する。レイアウト後に
  /// `jumpTo` すると、新しい倍率で描かれた1フレームだけ旧オフセットの
  /// 位置に見え、ピンチ中に上下へ揺れる (高倍率ほど顕著)。
  void _onZoomChanged() {
    if (!mounted) return;
    final newZoom = widget.zoom.zoom;
    final oldZoom = _zoomApplied;
    if (newZoom == oldZoom) return;
    final data = widget.data;
    final focal = _zoomFocal;
    _zoomFocal = null;

    // ヘッダーとガターは固定寸法なのでビューポートも変わらない。
    final verticalFocal = focal == null
        ? _viewportHeight / 2
        : (focal.dy - timetableHeaderHeight).clamp(0.0, _viewportHeight);
    final horizontalFocal = focal == null
        ? _viewportWidth / 2
        : (focal.dx - timetableGutterWidth).clamp(0.0, _viewportWidth);

    final gridHeight = timetableHeightPx(
      data.startMs,
      data.endMs,
      zoom: newZoom,
    );
    final gridWidth = data.channels.length * timetableColumnWidthAt(newZoom);

    _zoomApplied = newZoom;
    _vLink.jumpToUnclamped(
      timetableZoomedOffset(
        offsetPx: _vLink.offset,
        focalPx: verticalFocal,
        oldZoom: oldZoom,
        newZoom: newZoom,
        viewportHeightPx: _viewportHeight,
        gridHeightPx: gridHeight,
      ),
    );
    _hLink.jumpToUnclamped(
      timetableZoomedOffset(
        offsetPx: _hLink.offset,
        focalPx: horizontalFocal,
        oldZoom: oldZoom,
        newZoom: newZoom,
        viewportHeightPx: _viewportWidth,
        gridHeightPx: gridWidth,
      ),
    );
    setState(() {});
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
      zoom: widget.zoom.zoom,
    );
    if (target.value != hourMs) {
      target.value = hourMs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TimetableData data = widget.data;
    final List<TimetableChannel> columns = data.channels;
    final zoom = widget.zoom.zoom;
    final gridHeight = timetableHeightPx(data.startMs, data.endMs, zoom: zoom);
    final columnWidth = timetableColumnWidthAt(zoom);
    // 時刻ガターとチャンネルヘッダーはズームしても固定サイズにする
    // (時間軸・局名の視認性を一定に保つ)。
    const gutterWidth = timetableGutterWidth;
    const headerHeight = timetableHeaderHeight;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = max(0.0, constraints.maxHeight - headerHeight);
        _viewportHeight = viewportHeight;
        _viewportWidth = max(0.0, constraints.maxWidth - gutterWidth);
        _scheduleJumpToNow(viewportHeight, gridHeight);
        _handleScrollRequest(viewportHeight, gridHeight);
        // デスクトップのマウスドラッグ (スクロールバー自体を摘む操作) を
        // 受け付けるようにする。
        final grid = Row(
          children: [
            SizedBox(
              width: gutterWidth,
              child: Column(
                children: [
                  Container(
                    height: headerHeight,
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
                    child: _GutterList(link: _vLink, data: data, zoom: zoom),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    // 縦スクロール中もヘッダーは動かない。グリッド全体の
                    // 再描画に巻き込まれないよう独立したレイヤーにする
                    // (ロゴ・局名のラスタライズを毎フレームやり直さない)。
                    child: RepaintBoundary(
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
                            itemExtent: columnWidth,
                            itemCount: columns.length,
                            itemBuilder: (context, index) => _ChannelHeader(
                              column: columns[index],
                              width: columnWidth,
                              onTap: () =>
                                  widget.onChannelTap(columns[index].channel),
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
                          physics: const NeverScrollableScrollPhysics(),
                          itemExtent: columnWidth,
                          itemCount: columns.length,
                          // 列はスクロール中すべて再描画されるため、列ごとの
                          // レイヤーは合成コストになるだけ。1枚にまとめる。
                          addRepaintBoundaries: false,
                          itemBuilder: (context, index) {
                            final column = columns[index];
                            return TimetableColumnView(
                              key: ValueKey(column.channel.id),
                              link: _vLink,
                              data: data,
                              column: column,
                              zoom: zoom,
                              columnIndex: index,
                              rasterGate: _rasterGate,
                              horizontalLink: _hLink,
                              onProgramTap: (program) =>
                                  widget.onProgramTap(column, program),
                            );
                          },
                        ),
                        // 罫線・nowラインはビューポート1枚のキャンバスに描く。
                        // スクロール中は共有オフセットの通知で再描画するだけ。
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TimetableGridOverlay(
                              data: data,
                              link: _vLink,
                              zoom: zoom,
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
            zoom: widget.zoom,
            onZoomFocal: (focal) => _zoomFocal = focal,
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
          zoom: widget.zoom.zoom,
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
          zoom: widget.zoom.zoom,
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

/// 時刻ガター。1時間=180px (×ズーム倍率) の `ListView` で列と連動する。
/// 時刻ラベルの文字サイズは倍率によらず固定。
class _GutterList extends StatefulWidget {
  const _GutterList({
    required this.link,
    required this.data,
    required this.zoom,
  });

  final TimetableScrollLink link;
  final TimetableData data;
  final double zoom;

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
    final hourStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colorScheme.onSurfaceVariant);
    return _NoScrollbar(
      child: ListView.builder(
        controller: _controller,
        // 斜めスクロールのためドラッグは `TimetablePanScroll` に一本化する。
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: 60 * timetablePxPerMinAt(widget.zoom),
        itemCount: hours,
        addAutomaticKeepAlives: false,
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
            child: Text('$hour', style: hourStyle),
          );
        },
      ),
    );
  }
}

/// チャンネルヘッダー。ロゴ+番号・局名。タップで視聴へ遷移する。
class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.column,
    required this.width,
    required this.onTap,
  });

  final TimetableChannel column;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final channel = column.channel;
    return Container(
      width: width,
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
