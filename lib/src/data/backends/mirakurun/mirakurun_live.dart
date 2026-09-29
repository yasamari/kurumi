/// MirakurunのライブストリームURLを組み立てる純粋関数。
///
/// 仕様:
/// - `GET /api/services/{id}/stream?decode=1` を使う (`decode=1` 固定で配信必須化)
/// - [baseUrl] の末尾 `/` の有無に影響されない
/// - [serviceId] は [Channel.id] (service.id の文字列表現) をそのまま使う
///
/// [baseUrl] は設定画面で正規化済みの値を想定するが、末尾 `/` はここでも吸収する。
Uri buildMirakurunLiveStreamUrl({
  required String baseUrl,
  required String serviceId,
}) {
  final normalized = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return Uri.parse('$normalized/api/services/$serviceId/stream?decode=1');
}
