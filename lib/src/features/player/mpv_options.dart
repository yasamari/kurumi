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
  // ただし低遅延プロファイルは `avformat_find_stream_info()` を省略するため、
  // ARIB字幕の検出に必要なプローブだけ戻す。
  //
  // 理由: KonomiTV の再エンコード画質では字幕が ID3 timed-metadata
  // (`TIMED_ID3`) として流れる。字幕ストリームとして確定するのは、ffmpeg
  // パッチ (`mpegts-tsreadex.patch`) がパケット読み取り中に実際の
  // ARIB STD-B24 ペイロード (PRIV/aribb24.js) を読んだ時で、それまでは
  // `AVMEDIA_TYPE_DATA` のままである。mpv のトラック一覧は
  // `avformat_find_stream_info()` の後にしか構築されないため、
  // `original` のように PMT 時点で字幕ストリームが確定する性質とは異なり、
  // 再エンコード画質ではプローブを省くと字幕トラックが登録されないまま
  // 固定されてしまう。
  await platform.setProperty('demuxer-lavf-probe-info', 'auto');
  // 同プロファイルが 0.1 秒まで詰める解析時間も戻す (0 は ffmpeg 既定の
  // 5秒 = 上書き解除を意味する)。KonomiTV は字幕データが現れない場合も
  // 5秒ごとに代替データ (非表示) を挿入するため、その長さ読まないと
  // 字幕ストリームへの追従が間に合わない。
  await platform.setProperty('demuxer-lavf-analyzeduration', '0');
  // media_kit 既定 32M の溜め込み上限を絞る。MPEG-2 TS (15〜24Mbps) で
  // 数秒分の上限になる。シークしないライブのため後方向はさらに小さくする。
  await platform.setProperty('demuxer-max-bytes', '10M');
  await platform.setProperty('demuxer-max-back-bytes', '2M');
  await platform.setProperty('sub-lavc-o', 'sub_type=bitmap');
  await platform.setProperty('sub-visibility', 'yes');
  await platform.setProperty('deinterlace', deinterlace ? 'yes' : 'no');
}

/// ライブ配信の再生位置をライブエッジ (最新データ) に戻す。
///
/// ライブ配信では停止している間も Demuxer キャッシュとソケットバッファに
/// 過去的数据が溜まる。読み込み速度と再生速度が同じなので、再開してもその続き
/// から再生されるだけで、停止した時間だけ放送に遅れたままになる。
///
/// 前方向のシークでは追いつけない。`time-pos` の行先はキャッシュ内で頭打ちに
/// なるため、リモートTSでは無意味になるだけ (`relative` で
/// `demuxer-cache-time` ちょうどまでシークしても動かないことに実機確認済み)。
/// 溜まった過去データそのものを捨てる `drop-buffers` を使う。
///
/// デコード済みの映像/音声バッファも捨てるため映像が一瞬飛ぶが、トラック選択や
/// 音量などの状態は保たれる。
///
/// 古い mpv でコマンドが無い場合も、media_kit の command はエラーログのみで
/// 例外にならない。
Future<void> seekToLiveEdge(Player player) async {
  final platform = player.platform;
  if (platform is! NativePlayer) {
    // web版など mpv を直接扱えない環境では何もしない。
    return;
  }
  await platform.command(['drop-buffers']);
}

/// 録画再生用のmpvオプションを適用する。
///
/// ライブ用 ([applyLiveMpvOptions]) との差分:
/// - low-latency プロファイルを適用しない。VODはシークするため溜め込み
///   制限も既定のままにする。
/// - プローブ短縮をしない。HLS・ダウンロードTSのトラック検出 (字幕含む)
///   を通常の解析に任せる。
/// - 字幕の bitmap 描画とデインタレース制御はライブと共通。
///
/// [player] の映像を開く前に呼ぶこと。デコーダ生成時に読み込まれる。
Future<void> applyVideoMpvOptions(
  Player player, {
  required bool deinterlace,
}) async {
  final platform = player.platform;
  if (platform is! NativePlayer) {
    // web版など mpv を直接扱えない環境では何もしない。
    return;
  }
  await platform.setProperty('sub-lavc-o', 'sub_type=bitmap');
  await platform.setProperty('sub-visibility', 'yes');
  await platform.setProperty('deinterlace', deinterlace ? 'yes' : 'no');
}
