import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/features/player/seek_thumbnail.dart';

void main() {
  group('seekThumbnailTileIndex', () {
    test('割合から枚数を引く', () {
      expect(
        seekThumbnailTileIndex(fraction: 0.0, totalTiles: 360),
        0,
      );
      expect(
        seekThumbnailTileIndex(fraction: 0.5, totalTiles: 360),
        180,
      );
      // 両端は内側に丸める (1.0 は範囲外)。
      expect(
        seekThumbnailTileIndex(fraction: 1.0, totalTiles: 360),
        359,
      );
      expect(
        seekThumbnailTileIndex(fraction: 0.999, totalTiles: 360),
        359,
      );
    });

    test('範囲外・不正値は内側に丸める', () {
      expect(seekThumbnailTileIndex(fraction: -0.5, totalTiles: 360), 0);
      expect(seekThumbnailTileIndex(fraction: 2.0, totalTiles: 360), 359);
      expect(seekThumbnailTileIndex(fraction: double.nan, totalTiles: 360), 0);
      expect(seekThumbnailTileIndex(fraction: 0.5, totalTiles: 0), 0);
      expect(seekThumbnailTileIndex(fraction: 0.5, totalTiles: -1), 0);
    });
  });

  group('seekThumbnailTilePosition', () {
    test('column_count 枚ずつ行方向に詰める', () {
      expect(
        seekThumbnailTilePosition(index: 0, columnCount: 51),
        (column: 0, row: 0),
      );
      expect(
        seekThumbnailTilePosition(index: 50, columnCount: 51),
        (column: 50, row: 0),
      );
      expect(
        seekThumbnailTilePosition(index: 51, columnCount: 51),
        (column: 0, row: 1),
      );
      expect(
        seekThumbnailTilePosition(index: 155, columnCount: 51),
        (column: 2, row: 3),
      );
    });

    test('列数が0以下・負の番号でも落ちない', () {
      expect(seekThumbnailTilePosition(index: 7, columnCount: 0), (column: 0, row: 7));
      expect(seekThumbnailTilePosition(index: -3, columnCount: 51), (column: 0, row: 0));
    });
  });

  group('seekThumbnailAlignment', () {
    test('見たいタイルが中心に来る位置を返す', () {
      // 先頭は左端、中央は0、末尾は右端。
      expect(
        seekThumbnailAlignment(
          column: 0,
          row: 0,
          columnCount: 51,
          rowCount: 8,
        ),
        const Alignment(-1.0, -1.0),
      );
      expect(
        seekThumbnailAlignment(
          column: 50,
          row: 7,
          columnCount: 51,
          rowCount: 8,
        ),
        const Alignment(1.0, 1.0),
      );
      expect(
        seekThumbnailAlignment(
          column: 25,
          row: 3,
          columnCount: 51,
          rowCount: 8,
        ),
        const Alignment(0.0, 2.0 * 3 / 7 - 1.0),
      );
    });

    test('1行・1列なら位置は無関係', () {
      expect(
        seekThumbnailAlignment(
          column: 0,
          row: 0,
          columnCount: 1,
          rowCount: 1,
        ),
        const Alignment(0.0, 0.0),
      );
      expect(
        seekThumbnailAlignment(
          column: 5,
          row: 5,
          columnCount: 0,
          rowCount: 0,
        ),
        const Alignment(0.0, 0.0),
      );
    });

    test('範囲外の番号は内側に丸める', () {
      final alignment = seekThumbnailAlignment(
        column: 99,
        row: -4,
        columnCount: 51,
        rowCount: 8,
      );
      expect(alignment.x, 1.0);
      expect(alignment.y, -1.0);
    });
  });

  group('seekThumbnailRowCount', () {
    test('column_count で割って切り上げる', () {
      expect(seekThumbnailRowCount(totalTiles: 408, columnCount: 51), 8);
      expect(seekThumbnailRowCount(totalTiles: 50, columnCount: 51), 1);
      expect(seekThumbnailRowCount(totalTiles: 51, columnCount: 51), 1);
      expect(seekThumbnailRowCount(totalTiles: 52, columnCount: 51), 2);
      expect(seekThumbnailRowCount(totalTiles: 0, columnCount: 51), 1);
      expect(seekThumbnailRowCount(totalTiles: 10, columnCount: 0), 10);
    });
  });

  group('seekThumbnailPreviewHeight', () {
    test('タイルのアスペクト比から求める', () {
      expect(
        seekThumbnailPreviewHeight(tileWidth: 320, tileHeight: 180),
        101.25,
      );
      // 旧仕様 (480x270) も同じ 16:9。
      expect(
        seekThumbnailPreviewHeight(tileWidth: 480, tileHeight: 270),
        101.25,
      );
      expect(
        seekThumbnailPreviewHeight(tileWidth: 160, tileHeight: 90),
        101.25,
      );
    });

    test('寸法が取れないときは16:9とみなす', () {
      expect(seekThumbnailPreviewHeight(tileWidth: 0, tileHeight: 0), 101.25);
      expect(seekThumbnailPreviewHeight(tileWidth: -1, tileHeight: 180), 101.25);
    });
  });

  group('seekThumbnailPreviewLeft', () {
    test('ポインタを中心に置く', () {
      expect(
        seekThumbnailPreviewLeft(pointerX: 500.0, trackWidth: 1000.0),
        410.0,
      );
    });

    test('トラックの端を越えない', () {
      expect(
        seekThumbnailPreviewLeft(pointerX: 20.0, trackWidth: 1000.0),
        0.0,
      );
      expect(
        seekThumbnailPreviewLeft(pointerX: 990.0, trackWidth: 1000.0),
        820.0,
      );
    });

    test('トラックがプレビューより狭いときは左端に置く', () {
      expect(
        seekThumbnailPreviewLeft(pointerX: 50.0, trackWidth: 100.0),
        0.0,
      );
      expect(
        seekThumbnailPreviewLeft(
          pointerX: 50.0,
          trackWidth: 100.0,
          previewWidth: 100.0,
        ),
        0.0,
      );
    });

    test('寸法が確定しないうちは左端に置く', () {
      expect(
        seekThumbnailPreviewLeft(pointerX: double.nan, trackWidth: 1000.0),
        0.0,
      );
      expect(
        seekThumbnailPreviewLeft(pointerX: 500.0, trackWidth: double.nan),
        0.0,
      );
      expect(
        seekThumbnailPreviewLeft(pointerX: 500.0, trackWidth: 0.0),
        0.0,
      );
    });
  });
}
