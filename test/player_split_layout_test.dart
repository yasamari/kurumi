import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/features/player/player_split_layout.dart';

void main() {
  group('映像と情報パネルの配置', () {
    test('横画面は映像の右にパネルを置く', () {
      final rects = playerSplitRects(
        isLandscape: true,
        width: 1920,
        height: 1080,
      );
      expect(rects.video.left, 0);
      expect(rects.video.top, 0);
      expect(rects.video.width, 1920 - playerPanelWidth);
      expect(rects.video.height, 1080);
      expect(rects.info.left, 1920 - playerPanelWidth);
      expect(rects.info.top, 0);
      expect(rects.info.width, playerPanelWidth);
      expect(rects.info.height, 1080);
    });

    test('縦画面は映像 (16:9) の下にパネルを置く', () {
      final rects = playerSplitRects(
        isLandscape: false,
        width: 1080,
        height: 1920,
      );
      final videoHeight = 1080 / playerVideoAspectRatio;
      expect(rects.video.left, 0);
      expect(rects.video.top, 0);
      expect(rects.video.width, 1080);
      expect(rects.video.height, videoHeight);
      expect(rects.info.left, 0);
      expect(rects.info.top, videoHeight);
      expect(rects.info.width, 1080);
      expect(rects.info.height, 1920 - videoHeight);
    });

    test('縦画面でも映像の高さは画面内に収める', () {
      // 極端に背の低いウィンドウでパネルが負の高さになるとオーバーフローする。
      final rects = playerSplitRects(
        isLandscape: false,
        width: 1080,
        height: 300,
      );
      expect(rects.video.height, 300);
      expect(rects.info.top, 300);
      expect(rects.info.height, 0);
    });

    test('パネル幅は画面幅を超えずに打ち切る', () {
      final rects = playerSplitRects(
        isLandscape: true,
        width: 300,
        height: 600,
      );
      expect(rects.video.width, 0);
      expect(rects.info.left, 0);
      expect(rects.info.width, 300);
    });
  });
}
