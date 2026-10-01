import 'dart:math';

/// KonomiTVの録画ストリーミングで指定できる全画質。
///
/// 出典: KonomiTV `server/app/constants.py` の `QUALITY_TYPES`。
/// ライブと異なり `original` はHLSプレイリストで配信できない
/// (サーバーが422を返す) ため含めない。`original` 指定時はダウンロードAPI
/// (`/api/videos/{id}/download`) のMPEG-TS直接出力で再生する。
const konomiVideoQualities = [
  '1080p-60fps',
  '1080p-60fps-hevc',
  '1080p',
  '1080p-hevc',
  '810p',
  '810p-hevc',
  '720p',
  '720p-hevc',
  '540p',
  '540p-hevc',
  '480p',
  '480p-hevc',
  '360p',
  '360p-hevc',
  '240p',
  '240p-hevc',
];

/// 録画再生の既定画質。
const defaultKonomiVideoQuality = '1080p';

/// 再エンコード無しの画質指定。ダウンロードAPIで再生する。
const originalKonomiVideoQuality = 'original';

/// 指定画質が有効か判定する。不正値は [defaultKonomiVideoQuality] に
/// フォールバックする。`original` はダウンロード再生用として有効。
String normalizeKonomiVideoQuality(String quality) {
  if (quality == originalKonomiVideoQuality) return quality;
  return konomiVideoQualities.contains(quality)
      ? quality
      : defaultKonomiVideoQuality;
}

/// 再エンコード無し (`original`・ダウンロード再生) かを判定する。
///
/// `original` はインターレース放送のMPEG-2 TS直接出力のため、mpv側で
/// デインタレースする。HLS画質はサーバー側でプログレッシブに再エンコード
/// 済みのため不要。
bool isOriginalKonomiVideoQuality(String quality) {
  return normalizeKonomiVideoQuality(quality) == originalKonomiVideoQuality;
}

/// KonomiTVの録画HLSプレイリストURLを組み立てる純粋関数。
///
/// 仕様 (`server/app/routers/VideoStreamsRouter.py`):
/// - `GET /api/streams/video/{video_id}/{quality}/playlist` を使う
/// - [sessionId] はクライアント生成のランダム値。初回取得でセッション開始
/// - [quality] に `original` は使えない (サーバーが422)。呼び出し側で
///   [isOriginalKonomiVideoQuality] を見てダウンロードURLを使うこと
/// - [baseUrl] の末尾 `/` の有無に影響されない
Uri buildKonomiVideoHlsUrl({
  required String baseUrl,
  required int videoId,
  required String quality,
  required String sessionId,
}) {
  final normalized = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse(
    '$normalized/api/streams/video/$videoId/$quality/playlist'
    '?session_id=$sessionId',
  );
}

/// KonomiTVの録画ファイルダウンロードURLを組み立てる純粋関数。
///
/// `original` 画質の再生に使う。録画中の番組はサーバーが422を返す。
Uri buildKonomiVideoDownloadUrl({
  required String baseUrl,
  required int videoId,
}) {
  final normalized = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$normalized/api/videos/$videoId/download');
}

/// HLS視聴セッション ID を生成する。クライアント側で適宜生成した
/// ランダム値でよく、衝突しなければ形式は問わない (32桁hex)。
String generateVideoSessionId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
