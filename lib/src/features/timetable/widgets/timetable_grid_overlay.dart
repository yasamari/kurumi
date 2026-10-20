import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/timetable.dart';
import '../timetable_layout.dart';
import '../timetable_scroll_link.dart';

/// 番組表の罫線とnowライン。ビューポート全体を1枚のキャンバスで描く。
///
/// 罫線24本をウィジェットとして積まず、スクロール中は [TimetableScrollLink]
/// の通知で位置だけを再計算する。nowラインのラベルは30秒ごとに作り直す。
class TimetableGridOverlay extends StatefulWidget {
  const TimetableGridOverlay({
    super.key,
    required this.data,
    required this.link,
  });

  final TimetableData data;
  final TimetableScrollLink link;

  @override
  State<TimetableGridOverlay> createState() => _TimetableGridOverlayState();
}

class _TimetableGridOverlayState extends State<TimetableGridOverlay> {
  late Timer _timer;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onError,
      height: 1.0,
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);

    // 時刻ラベルは30秒ごとにしか変わらない。毎フレームの paint で
    // TextPainter を組み直さないよう、ここで1回だけレイアウトする。
    TextPainter? labelPainter;
    if (labelStyle != null) {
      final label = formatTimetableCellTime(
        DateTime.fromMillisecondsSinceEpoch(_nowMs),
        DateTime.fromMillisecondsSinceEpoch(_nowMs),
      ).split('-').first;
      labelPainter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textAlign: TextAlign.start,
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        maxLines: 1,
      )..layout();
    }

    return CustomPaint(
      painter: _TimetableGridOverlayPainter(
        data: widget.data,
        link: widget.link,
        marks: timetableHourMarksMs(widget.data.startMs, widget.data.endMs),
        nowMs: _nowMs,
        outline: colorScheme.outlineVariant,
        error: colorScheme.error,
        labelPainter: labelPainter,
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TimetableGridOverlayPainter extends CustomPainter {
  _TimetableGridOverlayPainter({
    required this.data,
    required this.link,
    required this.marks,
    required this.nowMs,
    required this.outline,
    required this.error,
    required this.labelPainter,
    required this.textScaler,
    required this.textDirection,
    required this.locale,
    required this.devicePixelRatio,
  }) : super(repaint: link);

  final TimetableData data;
  final TimetableScrollLink link;
  final List<int> marks;
  final int nowMs;
  final Color outline;
  final Color error;
  final TextPainter? labelPainter;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Locale? locale;
  final double devicePixelRatio;

  final Paint _linePaint = Paint();
  final Paint _nowPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final offset = _snap(link.offset, devicePixelRatio);
    _linePaint.color = outline;
    for (final mark in marks) {
      final y = _snap(
        timetableOffsetPx(mark, data.startMs) - offset,
        devicePixelRatio,
      );
      if (y < 0 || y > size.height) continue;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), _linePaint);
    }

    if (nowMs < data.startMs || nowMs >= data.endMs) return;
    final y = _snap(
      timetableOffsetPx(nowMs, data.startMs) - offset,
      devicePixelRatio,
    );
    if (y < -20 || y > size.height + 20) return;

    _nowPaint.color = error;
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), _nowPaint);

    final textPainter = labelPainter;
    if (textPainter == null) return;
    final pill = Rect.fromLTWH(4, y - 11, textPainter.width + 12, 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pill, const Radius.circular(8)),
      _nowPaint,
    );
    textPainter.paint(canvas, Offset(pill.left + 6, pill.top + 2));
  }

  @override
  bool shouldRepaint(covariant _TimetableGridOverlayPainter oldDelegate) {
    return !identical(oldDelegate.data, data) ||
        !identical(oldDelegate.link, link) ||
        oldDelegate.nowMs != nowMs ||
        oldDelegate.outline != outline ||
        oldDelegate.error != error ||
        !identical(oldDelegate.labelPainter, labelPainter) ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.locale != locale ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

double _snap(double value, double devicePixelRatio) {
  if (devicePixelRatio <= 0) return value;
  return (value * devicePixelRatio).roundToDouble() / devicePixelRatio;
}
