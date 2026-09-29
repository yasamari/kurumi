import 'package:media_kit/media_kit.dart';

/// ライブ視聴用のmpvオプションを適用する。
///
/// ARIB字幕 (地デジの文字スーパー) は ffmpeg の aribcaption デコーダで処理され、
/// 既定は `sub_type=ass` (整形テキスト) で描画される。放送と同じ見た目に
/// 近づけるため `sub_type=bitmap` を渡し、ビットマップ描画に切り替える。
///
/// 前提:
/// - mpv がリンクする ffmpeg に aribcaption デコーダが含まれていること
///   (nixpkgs の `ffmpeg` は非対応、`ffmpeg-full` のみ対応)
///
/// [player] の映像を開く前に呼ぶこと。デコーダ生成時に読み込まれる。
Future<void> applyLiveMpvOptions(Player player) async {
  final platform = player.platform;
  if (platform is! NativePlayer) {
    // web版など mpv を直接扱えない環境では何もしない。
    return;
  }
  await platform.setProperty('sub-lavc-o', 'sub_type=bitmap');
  await platform.setProperty('sub-visibility', 'yes');
}
