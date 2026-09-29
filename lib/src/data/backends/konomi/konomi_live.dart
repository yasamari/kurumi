/// KonomiTVのライブストリーミングで指定できる全画質。
///
/// 出典: KonomiTV `server/app/constants.py` の `LIVE_STREAMING_QUALITY_TYPES`
/// (`original` + 16種)。サーバー側に一覧APIが無いため定数化する。
/// `original` は再エンコード無しのMPEG-2 TS直接出力 (既定値)。
const konomiLiveQualities = [
  'original',
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

/// 既定の画質。永続化はしない。
const defaultKonomiQuality = 'original';

/// 指定画質が有効か判定する。不正値は [defaultKonomiQuality] にフォールバックする。
String normalizeKonomiQuality(String quality) {
  return konomiLiveQualities.contains(quality) ? quality : defaultKonomiQuality;
}

/// KonomiTVのライブMPEG-TSストリームURLを組み立てる純粋関数。
///
/// 仕様:
/// - `GET /api/streams/live/{display_channel_id}/{quality}/mpegts` を使う
/// - [displayChannelId] は [Channel.id] (例: `gr011`) をそのまま使う
/// - [quality] は [konomiLiveQualities] のいずれか。不正値は `original` に正規化する
/// - [baseUrl] の末尾 `/` の有無に影響されない
Uri buildKonomiLiveStreamUrl({
  required String baseUrl,
  required String displayChannelId,
  required String quality,
}) {
  final normalized = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final q = normalizeKonomiQuality(quality);
  return Uri.parse('$normalized/api/streams/live/$displayChannelId/$q/mpegts');
}
