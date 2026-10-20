import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/utils/program_text.dart';
import '../../../domain/entities/tv_program.dart';
import '../timetable_layout.dart';

/// セル本文の左端 (アクセントバー + 左パディング)。
const double timetableCellContentLeft = 4 + 6;

/// セル本文の上端パディング。
const double timetableCellContentTop = 2;

/// セル本文の幅。右のセル間余白・アクセントバー・左右パディングを除く。
const double timetableCellContentWidth =
    timetableColumnWidth - timetableCellGap - timetableCellContentLeft - 6;

/// セル本文の高さ。下のセル間余白と上下パディングを除く。
double timetableCellContentHeight(double cellHeightPx) =>
    math.max(0.0, cellHeightPx - timetableCellGap - 4);

/// 1枚のセル画像に焼く最大の高さ (論理px)。
///
/// 12時間番組のような極端に高いセルでも画像メモリが跳ねないようにする。
const double timetableCellRasterMaxHeight = 1024;

/// セル本文の描画スタイル。テーマ・文字スケール・DPR をスナップショットする。
class TimetableCellStyle {
  const TimetableCellStyle({
    required this.surfaceContainerHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.timeStyle,
    required this.titleStyle,
    required this.titleStyleOnAir,
    required this.descriptionStyle,
    required this.textScaler,
    required this.textDirection,
    required this.locale,
    required this.textHeightBehavior,
    required this.textWidthBasis,
    required this.devicePixelRatio,
  });

  factory TimetableCellStyle.of(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = DefaultTextStyle.of(context);
    final base = defaultStyle.style;
    final bodySmall = theme.textTheme.bodySmall;
    final labelSmall = theme.textTheme.labelSmall;
    final colorScheme = theme.colorScheme;

    TextStyle merge(TextStyle? style) =>
        style == null ? base : base.merge(style);

    final title = merge(bodySmall).copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
      height: 1.25,
    );
    return TimetableCellStyle(
      surfaceContainerHigh: colorScheme.surfaceContainerHigh,
      onSurface: colorScheme.onSurface,
      onSurfaceVariant: colorScheme.onSurfaceVariant,
      outlineVariant: colorScheme.outlineVariant,
      primary: colorScheme.primary,
      onPrimary: colorScheme.onPrimary,
      timeStyle: merge(labelSmall)
          .copyWith(color: colorScheme.onSurfaceVariant, height: 1.2),
      titleStyle: title,
      titleStyleOnAir: title.copyWith(fontWeight: FontWeight.bold),
      descriptionStyle: merge(bodySmall)
          .copyWith(color: colorScheme.onSurfaceVariant, height: 1.3),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior: defaultStyle.textHeightBehavior,
      textWidthBasis: defaultStyle.textWidthBasis,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  final Color surfaceContainerHigh;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color primary;
  final Color onPrimary;
  final TextStyle timeStyle;
  final TextStyle titleStyle;
  final TextStyle titleStyleOnAir;
  final TextStyle descriptionStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Locale? locale;
  final TextHeightBehavior? textHeightBehavior;
  final TextWidthBasis textWidthBasis;
  final double devicePixelRatio;

  @override
  bool operator ==(Object other) {
    return other is TimetableCellStyle &&
        other.surfaceContainerHigh == surfaceContainerHigh &&
        other.onSurface == onSurface &&
        other.onSurfaceVariant == onSurfaceVariant &&
        other.outlineVariant == outlineVariant &&
        other.primary == primary &&
        other.onPrimary == onPrimary &&
        other.timeStyle == timeStyle &&
        other.titleStyle == titleStyle &&
        other.titleStyleOnAir == titleStyleOnAir &&
        other.descriptionStyle == descriptionStyle &&
        other.textScaler == textScaler &&
        other.textDirection == textDirection &&
        other.locale == locale &&
        other.textHeightBehavior == textHeightBehavior &&
        other.textWidthBasis == textWidthBasis &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(
    surfaceContainerHigh,
    onSurface,
    onSurfaceVariant,
    outlineVariant,
    primary,
    onPrimary,
    timeStyle,
    titleStyle,
    titleStyleOnAir,
    descriptionStyle,
    textScaler,
    textDirection,
    locale,
    textHeightBehavior,
    textWidthBasis,
    devicePixelRatio,
  );
}

/// セル本文の内容キー。内容が同じなら番組の再取得をまたいで画像を再利用する。
class TimetableCellContentKey {
  const TimetableCellContentKey({
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.description,
    required this.isOnAir,
    required this.width,
    required this.height,
    required this.showText,
  });

  final int startMs;
  final int endMs;
  final String title;
  final String description;
  final bool isOnAir;
  final double width;
  final double height;
  final bool showText;

  @override
  bool operator ==(Object other) {
    return other is TimetableCellContentKey &&
        other.startMs == startMs &&
        other.endMs == endMs &&
        other.title == title &&
        other.description == description &&
        other.isOnAir == isOnAir &&
        other.width == width &&
        other.height == height &&
        other.showText == showText;
  }

  @override
  int get hashCode => Object.hash(
    startMs,
    endMs,
    title,
    description,
    isOnAir,
    width,
    height,
    showText,
  );
}

/// セル1件の本文を [ui.Picture] として記録し、非同期で [ui.Image] に焼く。
///
/// 画像ができるまでは [paint] が Picture を直接描く。スクロール中に
/// テキストのラスタライズを繰り返さないためのキャッシュ単位。
class TimetableCellRaster {
  TimetableCellRaster._({
    required this.key,
    required this.width,
    required this.height,
    required this._picture,
    required double devicePixelRatio,
    required this._onReady,
  }) : _devicePixelRatio = devicePixelRatio,
       pixelWidth = math.max(1, (width * devicePixelRatio).ceil()),
       pixelHeight = math.max(1, (height * devicePixelRatio).ceil());

  /// 画像化が完了するまで待つための Future。取得した時点で画像化を開始する。
  ///
  /// 呼び出し側は1件ずつ await して `toImage` の同時実行を避ける。
  Future<void> get ready => _ready ??= _rasterize();

  final TimetableCellContentKey key;
  final double width;
  final double height;
  final int pixelWidth;
  final int pixelHeight;

  /// GPU テクスチャの概算バイト数。
  int get byteSize => pixelWidth * pixelHeight * 4;

  final double _devicePixelRatio;
  final VoidCallback _onReady;
  ui.Picture? _picture;
  ui.Image? _image;
  Future<void>? _ready;
  bool _failed = false;
  bool _disposed = false;

  /// 画像化が完了したか。失敗した場合も Picture で表示できるため完了扱い。
  bool get isReady => _image != null || _failed;

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  Future<void> _rasterize() async {
    if (_disposed) return;
    final picture = _picture;
    if (picture == null) return;
    try {
      final image = await picture.toImage(pixelWidth, pixelHeight);
      if (_disposed) {
        image.dispose();
        return;
      }
      _image = image;
      _picture?.dispose();
      _picture = null;
      _onReady();
    } catch (_) {
      // 画像化に失敗しても Picture で描き続けられる。
      _failed = true;
    }
  }

  /// [offset] (論理px) に本文を描く。画像が未完成なら Picture を直接描く。
  void paint(Canvas canvas, Offset offset) {
    if (_disposed) return;
    final image = _image;
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          offset.dx,
          offset.dy,
          image.width / _devicePixelRatio,
          image.height / _devicePixelRatio,
        ),
        _paint,
      );
      return;
    }
    final picture = _picture;
    if (picture == null) return;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(1 / _devicePixelRatio);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _image?.dispose();
    _image = null;
    _picture?.dispose();
    _picture = null;
  }

  /// 内容から Picture を記録する。レイアウトはこの中で完結する。
  static TimetableCellRaster build({
    required TvProgram program,
    required bool isOnAir,
    required bool showText,
    required double cellHeightPx,
    required TimetableCellStyle style,
    required VoidCallback onReady,
  }) {
    final timeLabel = formatTimetableCellTime(program.startAt, program.endAt);
    final titleStyle = isOnAir ? style.titleStyleOnAir : style.titleStyle;

    final timePainter = TextPainter(
      text: TextSpan(text: timeLabel, style: style.timeStyle),
      textAlign: TextAlign.start,
      textDirection: style.textDirection,
      textScaler: style.textScaler,
      locale: style.locale,
      textHeightBehavior: style.textHeightBehavior,
      textWidthBasis: style.textWidthBasis,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: timetableCellContentWidth);

    final badges = <_BadgeLayout>[];
    final placeholderDimensions = <PlaceholderDimensions>[];
    final spans = <InlineSpan>[];
    for (final segment in parseProgramTextSymbols(program.title)) {
      if (segment.isSymbol) {
        final badge = _BadgeLayout.measure(
          symbol: segment.text,
          baseStyle: titleStyle,
          style: style,
        );
        badges.add(badge);
        placeholderDimensions.add(
          PlaceholderDimensions(
            size: badge.placeholderSize,
            alignment: PlaceholderAlignment.middle,
          ),
        );
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(
              width: badge.placeholderSize.width,
              height: badge.placeholderSize.height,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: segment.text));
      }
    }
    if (showText && program.description.isNotEmpty) {
      spans.add(
        TextSpan(
          text: program.title.isEmpty
              ? program.description
              : '\n${program.description}',
          style: style.descriptionStyle,
        ),
      );
    }

    final bodyPainter = TextPainter(
      text: TextSpan(style: titleStyle, children: spans),
      textAlign: TextAlign.start,
      textDirection: style.textDirection,
      textScaler: style.textScaler,
      locale: style.locale,
      textHeightBehavior: style.textHeightBehavior,
      textWidthBasis: style.textWidthBasis,
      maxLines: 1000,
      ellipsis: '…',
    );
    if (placeholderDimensions.isNotEmpty) {
      bodyPainter.setPlaceholderDimensions(placeholderDimensions);
    }
    bodyPainter.layout(maxWidth: timetableCellContentWidth);

    final naturalHeight = timePainter.height + bodyPainter.height;
    final contentHeight = timetableCellContentHeight(cellHeightPx);
    final height = showText
        ? math.max(1.0, math.min(contentHeight, timetableCellRasterMaxHeight))
        : math.max(1.0, naturalHeight);
    final key = TimetableCellContentKey(
      startMs: program.startAt.millisecondsSinceEpoch,
      endMs: program.endAt.millisecondsSinceEpoch,
      title: program.title,
      description: program.description,
      isOnAir: isOnAir,
      width: timetableCellContentWidth,
      height: showText ? height : -1,
      showText: showText,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dpr = style.devicePixelRatio;
    canvas.scale(dpr);
    canvas.clipRect(Rect.fromLTWH(0, 0, timetableCellContentWidth, height));
    timePainter.paint(canvas, Offset.zero);
    bodyPainter.paint(canvas, Offset(0, timePainter.height));

    final boxes = bodyPainter.inlinePlaceholderBoxes;
    if (boxes != null) {
      for (var i = 0; i < badges.length && i < boxes.length; i++) {
        final box = boxes[i];
        final badge = badges[i];
        final topLeft = Offset(
          box.left + badge.backgroundRect.left,
          timePainter.height + box.top + badge.backgroundRect.top,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            badge.backgroundRect.shift(topLeft),
            const Radius.circular(5),
          ),
          Paint()..color = style.primary,
        );
        badge.textPainter.paint(canvas, topLeft + badge.textOffset);
      }
    }
    final picture = recorder.endRecording();
    return TimetableCellRaster._(
      key: key,
      width: timetableCellContentWidth,
      height: height,
      picture: picture,
      devicePixelRatio: dpr,
      onReady: onReady,
    );
  }
}

/// 記号バッジ1件の寸法と描画位置。
class _BadgeLayout {
  const _BadgeLayout({
    required this.placeholderSize,
    required this.backgroundRect,
    required this.textPainter,
    required this.textOffset,
  });

  final Size placeholderSize;
  final Rect backgroundRect;
  final TextPainter textPainter;
  final Offset textOffset;

  static _BadgeLayout measure({
    required String symbol,
    required TextStyle baseStyle,
    required TimetableCellStyle style,
  }) {
    final badgeStyle = baseStyle
        .apply(color: style.onPrimary, fontSizeFactor: 0.85)
        .copyWith(height: 1.0);
    final textPainter = TextPainter(
      text: TextSpan(text: symbol, style: badgeStyle),
      textAlign: TextAlign.center,
      textDirection: style.textDirection,
      textScaler: style.textScaler,
      locale: style.locale,
      maxLines: 1,
    )..layout();

    if (symbol.runes.length == 1) {
      final dimension = (badgeStyle.fontSize ?? 14.0) + 8.0;
      final placeholder = Size(dimension + 4, dimension);
      final background = Rect.fromLTWH(2, 0, dimension, dimension);
      return _BadgeLayout(
        placeholderSize: placeholder,
        backgroundRect: background,
        textPainter: textPainter,
        textOffset: Offset(
          background.center.dx - textPainter.width / 2,
          background.center.dy - textPainter.height / 2,
        ),
      );
    }

    final background = Rect.fromLTWH(
      2,
      0,
      textPainter.width + 10,
      textPainter.height + 2,
    );
    return _BadgeLayout(
      placeholderSize: Size(background.width + 4, background.height),
      backgroundRect: background,
      textPainter: textPainter,
      textOffset: Offset(background.left + 5, background.top + 1),
    );
  }
}

/// 列1本分のセル画像キャッシュ。
///
/// 可視範囲+先読み範囲の画像だけを保持し、上限を超えたら画面から遠い順に
/// 捨てる。Picture の作成時と画像化の完了時に [ChangeNotifier] で描画側へ
/// 通知する。
class TimetableCellRasterCache extends ChangeNotifier {
  TimetableCellRasterCache(this._style, {this.maxBytes = 10 * 1024 * 1024});

  /// 列あたりの目安。可視列数 (約4〜5) を掛けても48MB前後に収まる値。
  final int maxBytes;

  TimetableCellStyle _style;
  final Map<int, TimetableCellRaster> _entries = {};
  final Map<int, double> _topPx = {};
  final Map<int, double> _heightPx = {};
  int _bytes = 0;
  bool _disposed = false;

  TimetableCellStyle get style => _style;

  /// スタイルが変わったら全画像を捨てる (テーマ・文字スケール・DPR)。
  void updateStyle(TimetableCellStyle style) {
    if (_style == style) return;
    _style = style;
    clear();
  }

  TimetableCellRaster? rasterFor(TvProgram program) =>
      _entries[program.eventId];

  TimetableCellContentKey _keyOf({
    required TvProgram program,
    required bool isOnAir,
    required double cellHeightPx,
  }) {
    final showText = timetableCellShowsText(cellHeightPx);
    final contentHeight = timetableCellContentHeight(cellHeightPx);
    final height = showText
        ? math.max(1.0, math.min(contentHeight, timetableCellRasterMaxHeight))
        : -1.0;
    return TimetableCellContentKey(
      startMs: program.startAt.millisecondsSinceEpoch,
      endMs: program.endAt.millisecondsSinceEpoch,
      title: program.title,
      description: program.description,
      isOnAir: isOnAir,
      width: timetableCellContentWidth,
      height: height,
      showText: showText,
    );
  }

  /// Picture を作り直す必要があるか。スクロール中の可視セル用。
  bool needsEnsure({
    required TvProgram program,
    required bool isOnAir,
    required double cellHeightPx,
  }) {
    final existing = _entries[program.eventId];
    return existing == null ||
        existing.key !=
            _keyOf(
              program: program,
              isOnAir: isOnAir,
              cellHeightPx: cellHeightPx,
            );
  }

  /// 画像化まで必要か。停止後のキュー投入で使う。
  bool needsWork({
    required TvProgram program,
    required bool isOnAir,
    required double cellHeightPx,
  }) {
    if (needsEnsure(
      program: program,
      isOnAir: isOnAir,
      cellHeightPx: cellHeightPx,
    )) {
      return true;
    }
    return !_entries[program.eventId]!.isReady;
  }

  /// 表示窓内の番組画像を用意する。既存と同じ内容なら作り直さない。
  ///
  /// Picture を記録した時点で描画側へ通知する。画像化が終わる前でも
  /// フォールバックの文字を次のフレームで出せる。
  ///
  /// 返り値の Future は画像化の完了で解決する。呼び出し側が1件ずつ await
  /// することで `Picture.toImage` が同時に走らないようにできる。
  Future<void> ensure({
    required TvProgram program,
    required bool isOnAir,
    required double cellHeightPx,
    required double topPx,
  }) {
    final showText = timetableCellShowsText(cellHeightPx);
    final key = _keyOf(
      program: program,
      isOnAir: isOnAir,
      cellHeightPx: cellHeightPx,
    );
    final existing = _entries[program.eventId];
    if (existing != null && existing.key == key) {
      _topPx[program.eventId] = topPx;
      _heightPx[program.eventId] = cellHeightPx;
      return existing.ready;
    }
    if (existing != null) _remove(program.eventId);
    if (_disposed) return Future.value();

    final raster = TimetableCellRaster.build(
      program: program,
      isOnAir: isOnAir,
      showText: showText,
      cellHeightPx: cellHeightPx,
      style: _style,
      onReady: () {
        if (!_disposed) notifyListeners();
      },
    );
    _entries[program.eventId] = raster;
    _topPx[program.eventId] = topPx;
    _heightPx[program.eventId] = cellHeightPx;
    _bytes += raster.byteSize;
    notifyListeners();
    return raster.ready;
  }

  /// 窓内の番組だけを残し、上限を超えた分を遠い順に捨てる。
  ///
  /// 可視範囲に掛かる画像は、上限を超えていても捨てない (スクロール中に
  /// 画像が消えると文字が一瞬消えるため)。上限は先読み側の調整に使う。
  void retain({
    required Set<int> eventIds,
    required double offsetPx,
    required double viewportHeightPx,
  }) {
    final removable = _entries.keys
        .where((eventId) => !eventIds.contains(eventId))
        .toList();
    for (final eventId in removable) {
      _remove(eventId);
    }
    if (_bytes <= maxBytes) return;
    final center = offsetPx + viewportHeightPx / 2;
    final active =
        _entries.keys.where((eventId) {
          final top = _topPx[eventId] ?? 0;
          final height = _heightPx[eventId] ?? 0;
          return top + height <= offsetPx || top >= offsetPx + viewportHeightPx;
        }).toList()..sort((a, b) {
          final da = ((_topPx[a] ?? 0) - center).abs();
          final db = ((_topPx[b] ?? 0) - center).abs();
          return db.compareTo(da);
        });
    for (final eventId in active) {
      if (_bytes <= maxBytes) break;
      _remove(eventId);
    }
  }

  void _remove(int eventId) {
    final raster = _entries.remove(eventId);
    _topPx.remove(eventId);
    _heightPx.remove(eventId);
    if (raster == null) return;
    _bytes -= raster.byteSize;
    // このフレームの描画が終わってから破棄する。
    SchedulerBinding.instance.addPostFrameCallback((_) => raster.dispose());
  }

  void clear() {
    final rasters = _entries.values.toList();
    _entries.clear();
    _topPx.clear();
    _heightPx.clear();
    _bytes = 0;
    if (rasters.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final raster in rasters) {
          raster.dispose();
        }
      });
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final rasters = _entries.values.toList();
    _entries.clear();
    _topPx.clear();
    _heightPx.clear();
    _bytes = 0;
    for (final raster in rasters) {
      raster.dispose();
    }
    super.dispose();
  }
}
