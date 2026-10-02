// モバイル標準コントロール (`MaterialVideoControls`) の余白・配色 (pure 関数群)。
//
// 既定のテーマデータは「フルスクリーンのときだけシステムナビゲーションを
// 避ける」作りになっている。`MaterialVideoControlsThemeData.padding` が null の
// 場合、`MaterialVideoControls` 自身がフルスクリーン時のみ
// `MediaQuery.padding` を使う。視聴・録画再生は通常フルスクリーンではないため、
// 横画面 (画面端まで描画する) では下端のコントロールがそのまま画面最下端に載り、
// システムナビゲーションに重なる。標準コントロールの余白・配色はテーマデータ
// 側でしか変えられないため、視聴 (`watch_screen.dart`) と録画再生
// (`video_play_screen.dart`) が共有する値としてここにまとめる。
import 'package:flutter/material.dart';

/// モバイル標準コントロールのボタン行の高さ。
///
/// `MaterialVideoControlsThemeData.buttonBarHeight` の既定値と同じ。
const playerButtonBarHeight = 56.0;

/// 標準コントロールに与える余白。
///
/// [fullBleed] は映像が画面端まで描画されているかどうか (横画面)、
/// [fullscreen] は media_kit のフルスクリーンモードかどうかを表す。
/// 既定のテーマデータと同じものを通常/フルスクリーンの両方に使うと、この2つの
/// 組み合わせを出し分けられないので、テーマデータの `normal` と `fullscreen`
/// に別の値を渡す。
///
/// - インセット ([padding]): 横画面とフルスクリーンのときは下端のコントロールが
///   システムナビゲーションに重なるため `systemPadding` を空ける。縦画面の通常
///   表示は外側の `SafeArea` がインセットを消費済み (`MediaQuery.removePadding`)
///   なので空けない (指定すると二重に空く)。映像はどちらの向きでも画面端まで
///   描画されるため、この余白はコントロールにだけ効く。
/// - シークバー ([seekBarMargin]): 既定は余白ゼロなので、シークバーがボタン行
///   (時刻表示・フルスクリーンボタン) の下・画面端に落ちる。横画面と
///   フルスクリーンのときは画面端がシステムナビゲーションに被るため、ボタン行の
///   上へ持ち上げる。縦画面の通常表示は元々ボタン行の下・画面下端にあるので
///   既定のままにする。
({EdgeInsets padding, EdgeInsets seekBarMargin}) playerMobileControlsInsets({
  required bool fullBleed,
  required bool fullscreen,
  required EdgeInsets systemPadding,
}) {
  final lifted = fullscreen || fullBleed;
  return (
    padding: lifted ? systemPadding : EdgeInsets.zero,
    seekBarMargin: lifted
        ? const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: playerButtonBarHeight,
          )
        : EdgeInsets.zero,
  );
}

/// シークバーの色。標準コントロールの既定は白 (トラック) + 赤 (再生位置)。
///
/// アプリの Dynamic Color ([ColorScheme]) に合わせて変更する。
///
/// シークバーは映像の上 (明度に関係なく黒) に描くため、ライトテーマの
/// `primary` (暗い調) をそのまま使うと暗くて見えない。ライトテーマでは同じ
/// パレットの明るい調 ([ColorScheme.primaryContainer]) を使う。
///
/// トラック・バッファは再生位置より薄く、進んだ分と未読분이区別できるように
/// する (既定はトラックとバッファが同じ色で、バッファが見えない)。
({Color track, Color buffer, Color position, Color thumb}) seekBarColorsFrom(
  ColorScheme scheme,
) {
  final accent = scheme.brightness == Brightness.dark
      ? scheme.primary
      : scheme.primaryContainer;
  return (
    track: accent.withValues(alpha: 0.32),
    buffer: accent.withValues(alpha: 0.56),
    position: accent,
    thumb: accent,
  );
}
