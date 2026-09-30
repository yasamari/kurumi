import 'package:media_kit/media_kit.dart';

/// ライブ視聴用のmpvオプションを適用する。
///
/// ARIB字幕 (地デジの文字スーパー) は ffmpeg の aribcaption デコーダで処理され、
/// 既定は `sub_type=ass` (整形テキスト) で描画される。放送と同じ見た目に
/// 近づけるため `sub_type=bitmap` を渡し、ビットマップ描画に切り替える。
///
/// [deinterlace] が真の場合、mpv の自動デインタレース (`deinterlace=yes`)
/// を有効化する。再エンコード無しの生放送 (インターレース) 用。mpv は
/// インターレースと判定したフレームにだけフィルタを掛けるため、万一
/// プログレッシブが来ても画質に影響しない。
/// トランスコード済み画質 (プログレッシブ) では不要のため偽を渡す。
///
/// 前提:
/// - mpv がリンクする ffmpeg に aribcaption デコーダが含まれていること
///   (flake.nix の最小構成 ffmpeg に libaribcaption を有効化している)
///
/// [player] の映像を開く前に呼ぶこと。デコーダ生成時に読み込まれる。
Future<void> applyLiveMpvOptions(
  Player player, {
  required bool deinterlace,
}) async {
  final platform = player.platform;
  if (platform is! NativePlayer) {
    // web版など mpv を直接扱えない環境では何もしない。
    return;
  }
  // 組込み low-latency プロファイルを適用する。古い mpv で名前が無い場合も
  // media_kit の command はエラーログのみで例外にならない。
  await platform.command(['apply-profile', 'low-latency']);
  // media_kit 既定 32M の溜め込み上限を絞る。MPEG-2 TS (15〜24Mbps) で
  // 数秒分の上限になる。シークしないライブのため後方向はさらに小さくする。
  await platform.setProperty('demuxer-max-bytes', '10M');
  await platform.setProperty('demuxer-max-back-bytes', '2M');
  await platform.setProperty('sub-lavc-o', 'sub_type=bitmap');
  await platform.setProperty('sub-visibility', 'yes');
  await platform.setProperty('deinterlace', deinterlace ? 'yes' : 'no');
}
