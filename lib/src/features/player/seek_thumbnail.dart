import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/video_thumbnail_tiles.dart';

/// サムネイルプレビューの幅。KonomiTV の Web クライアント (DPlayer) の
/// ビューポートと同じ値。
const seekThumbnailPreviewWidth = 180.0;

/// サムネイルプレビューの高さ。タイルのアスペクト比から求める純粋関数
/// (320x180 なら 101.25)。
double seekThumbnailPreviewHeight({
  required int tileWidth,
  required int tileHeight,
}) {
  if (tileWidth <= 0 || tileHeight <= 0) {
    return seekThumbnailPreviewWidth * 9 / 16;
  }
  return seekThumbnailPreviewWidth * tileHeight / tileWidth;
}

/// サムネイルをトラックの上に置く間隔。DPlayer の `thumbnailSpace` と同じ。
const seekThumbnailGap = 26.0;

/// ホバー位置 (0..1) からサムネイルのタイル番号を求める純粋関数。
///
/// KonomiTV の Web クライアントと同じく、尺に対する割合で枚数を引く
/// (トラックの幅に依存させない)。両端は内側に丸める。
int seekThumbnailTileIndex({
  required double fraction,
  required int totalTiles,
}) {
  if (totalTiles <= 0) return 0;
  if (fraction.isNaN) return 0;
  final clamped = math.min(1.0, math.max(0.0, fraction));
  final index = (clamped * totalTiles).floor();
  return math.min(totalTiles - 1, math.max(0, index));
}

/// タイル番号を並び (列・行) に変換する純粋関数。
///
/// KonomiTV は `column_count` 枚ずつ行方向に詰めて並べる (row-major)。
({int column, int row}) seekThumbnailTilePosition({
  required int index,
  required int columnCount,
}) {
  final columns = math.max(1, columnCount);
  final i = math.max(0, index);
  return (column: i % columns, row: i ~/ columns);
}

/// 切り抜き位置 ([OverflowBox.alignment]) を求める純粋関数。
///
/// 並べた画像全体を「プレビュー1枚の大きさ」に縮めて置いたとみなし、見たい
/// タイルがその中心に来る alignment を返す (CSS の `background-position` と
/// 同じ考え方)。[columnCount] / [rowCount] が1以下のときは並びが1枚きりなので
/// 位置は無関係。
Alignment seekThumbnailAlignment({
  required int column,
  required int row,
  required int columnCount,
  required int rowCount,
}) {
  return Alignment(
    _alignmentAxis(column, columnCount),
    _alignmentAxis(row, rowCount),
  );
}

double _alignmentAxis(int position, int count) {
  final cells = math.max(1, count);
  if (cells <= 1) return 0.0;
  final index = math.min(cells - 1, math.max(0, position));
  return 2.0 * index / (cells - 1) - 1.0;
}

/// プレビューの左端を求める純粋関数。ポインタを中心に置き、トラックの幅から
/// はみ出さない (DPlayer と同じ)。
double seekThumbnailPreviewLeft({
  required double pointerX,
  required double trackWidth,
  double previewWidth = seekThumbnailPreviewWidth,
}) {
  // 寸法が確定しないうちは左端に置く (NaN が流れるとレイアウトが死ぬ)。
  if (!pointerX.isFinite || !trackWidth.isFinite) return 0.0;
  final limit = math.max(0.0, trackWidth - previewWidth);
  return math.min(limit, math.max(0.0, pointerX - previewWidth / 2));
}

/// 並びの行数を求める純粋関数 (最後の行は黒埋めされることがある)。
int seekThumbnailRowCount({
  required int totalTiles,
  required int columnCount,
}) {
  final columns = math.max(1, columnCount);
  if (totalTiles <= 0) return 1;
  return (totalTiles + columns - 1) ~/ columns;
}

/// シークバーに重ねるサムネイルプレビュー。
///
/// 1枚に並べたタイル画像 ([VideoThumbnailTiles]) から、ホバー位置
/// ([fraction]) に対応する1枚を切り出して表示する。切り出しは
/// [seekThumbnailAlignment] で求めた位置へのずらしだけで行う (`ClipRect` +
/// `OverflowBox`)。**座標計算は純関数に寄せてあり、この中では行わない。**
///
/// 画像は「プレビュー1枚の大きさ」に縮小して読む (`cacheWidth` /
/// `cacheHeight`)。縮小前は 51 列 x 数十行 (横幅 16320px) になるため、
/// そのままデコードすると表示の数倍のメモリを食う。表示サイズと同尺寸まで
/// 落とせば質は落ちない (タイル1枚がプレビュー幅と一致するため)。
///
/// **親はこのウィジェットへ tight な幅を渡してはいけない。** `Stack` の
/// `Positioned` で left と right を両方指定すると子に tight な幅が渡り、
/// `Container(width: …)` は `BoxConstraints.enforce` でそれまで押し広げられ、
/// 切り出し枠ごと伸びてタイルが横に何枚も見える (`Stack` の position された
/// 子は非有界の制約をもらうので、通常は left だけ指定すれば伸びない)。
/// 水平位置は親側のずらしで与えること。クロップ枠は
/// [seekThumbnailPreviewWidth] ぴったりでなければならない。
class SeekThumbnailPreview extends StatelessWidget {
  const SeekThumbnailPreview({
    super.key,
    required this.tiles,
    required this.fraction,
  });

  /// 並べたサムネイルの情報。
  final VideoThumbnailTiles tiles;

  /// ホバー位置 (0..1)。
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final columns = math.max(1, tiles.columnCount);
    final rows = seekThumbnailRowCount(
      totalTiles: tiles.totalTiles,
      columnCount: columns,
    );
    final position = seekThumbnailTilePosition(
      index: seekThumbnailTileIndex(
        fraction: fraction,
        totalTiles: tiles.totalTiles,
      ),
      columnCount: columns,
    );
    // 1枚をプレビュー幅に縮めたときの並び全体の大きさ。タイルのアスペクト比を
    // 保つので、高さは幅から一意に決まる (切り出しの縮尺も均一になる)。
    final spriteWidth = seekThumbnailPreviewWidth * columns;
    final tilePreviewHeight = seekThumbnailPreviewHeight(
      tileWidth: tiles.tileWidth,
      tileHeight: tiles.tileHeight,
    );
    final spriteHeight = tilePreviewHeight * rows;
    return IgnorePointer(
      child: Container(
        width: seekThumbnailPreviewWidth,
        height: tilePreviewHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0x88000000),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: ClipRect(
          child: OverflowBox(
            alignment: seekThumbnailAlignment(
              column: position.column,
              row: position.row,
              columnCount: columns,
              rowCount: rows,
            ),
            minWidth: spriteWidth,
            maxWidth: spriteWidth,
            minHeight: spriteHeight,
            maxHeight: spriteHeight,
            child: Image.network(
              tiles.url,
              width: spriteWidth,
              height: spriteHeight,
              fit: BoxFit.fill,
              cacheWidth: spriteWidth.round(),
              cacheHeight: spriteHeight.round(),
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
