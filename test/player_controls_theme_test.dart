import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/features/player/player_controls_theme.dart';

void main() {
  const portraitInsets = EdgeInsets.only(top: 47, bottom: 34);
  const landscapeInsets = EdgeInsets.only(bottom: 24);

  group('インセットの回避', () {
    test('横画面 (フルブリード) はシステムインセットを避ける', () {
      // 横画面は外側の SafeArea が無いので、コントロール側で避ける必要がある。
      final insets = playerMobileControlsInsets(
        fullBleed: true,
        fullscreen: false,
        systemPadding: landscapeInsets,
      );
      expect(insets.padding, landscapeInsets);
    });

    test('縦画面の通常表示は SafeArea が消費済みなので空ける', () {
      // 余白まで指定すると縦画面で二重に空いてしまう。
      final insets = playerMobileControlsInsets(
        fullBleed: false,
        fullscreen: false,
        systemPadding: portraitInsets,
      );
      expect(insets.padding, EdgeInsets.zero);
    });

    test('縦画面でもフルスクリーンならインセットを避ける', () {
      // フルスクリーンは映像が画面端まで描画され、外側の SafeArea も無い。
      // `padding` を明示すると media_kit 自身の回避 (`padding` が null の
      // ときだけ効く) が無効化されるので、必ず値を渡すこと。
      final insets = playerMobileControlsInsets(
        fullBleed: false,
        fullscreen: true,
        systemPadding: portraitInsets,
      );
      expect(insets.padding, portraitInsets);
    });
  });

  group('シークバーの位置', () {
    test('横画面とフルスクリーンはボタン行の上に出す', () {
      for (final fullscreen in [false, true]) {
        final insets = playerMobileControlsInsets(
          fullBleed: true,
          fullscreen: fullscreen,
          systemPadding: landscapeInsets,
        );
        // ボタン行 (時刻表示・フルスクリーンボタン) の上にシークバーが来る。
        expect(insets.seekBarMargin.bottom, playerButtonBarHeight);
        expect(insets.seekBarMargin.left, 16);
        expect(insets.seekBarMargin.right, 16);
      }
    });

    test('縦画面の通常表示は下端のままにする', () {
      // 既定 (`EdgeInsets.zero`) はボタン行の下・画面下端に落ちる。縦画面の
      // 通常表示は外側の SafeArea 内に収まるので、このままで良い。
      final insets = playerMobileControlsInsets(
        fullBleed: false,
        fullscreen: false,
        systemPadding: portraitInsets,
      );
      expect(insets.seekBarMargin, EdgeInsets.zero);
    });
  });

  group('シークバーの配色', () {
    final light = ColorScheme.fromSeed(seedColor: Colors.deepOrange);
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.dark,
    );

    test('ダークテーマでは primary を使う', () {
      final colors = seekBarColorsFrom(dark);
      expect(colors.position, dark.primary);
      expect(colors.thumb, dark.primary);
    });

    test('ライトテーマでは黒の上でも見える primaryContainer を使う', () {
      // ライトテーマの primary は暗い調で、映像 (黒) の上だと見えない。
      final colors = seekBarColorsFrom(light);
      expect(colors.position, light.primaryContainer);
      expect(colors.thumb, light.primaryContainer);
    });

    test('トラックとバッファは再生位置より薄い', () {
      // 進んだ分・バッファ済み・未読の3段階が区別できること。
      for (final scheme in [light, dark]) {
        final colors = seekBarColorsFrom(scheme);
        expect(colors.track.a, lessThan(colors.buffer.a));
        expect(colors.buffer.a, lessThan(colors.position.a));
        expect(colors.position.a, 1.0);
        expect(colors.thumb, colors.position);
      }
    });
  });
}
