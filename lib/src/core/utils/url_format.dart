/// ベースURL正規化ヘルパー。
///
/// - 前後の空白を除去
/// - 末尾の `/` を除去
/// - スキームがなければ `http://` を付与
String normalizeBaseUrl(String input) {
  var url = input.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.isEmpty) return url;
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://$url';
  }
  return url;
}

/// URLとして有効かどうかを簡易判定する。
bool isValidBaseUrl(String input) {
  final normalized = normalizeBaseUrl(input);
  final uri = Uri.tryParse(normalized);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}
