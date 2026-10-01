/// KonomiTVの日付文字列を解釈する純粋関数。
///
/// サーバーはJST基準で日時を扱う (DB timezone Asia/Tokyo、番組不在時の
/// 基準値も `2000-01-01T00:00:00+09:00`)。オフセット付き (`+09:00` / `Z`)
/// はそれを尊重し、オフセットの無い素朴な表記はJSTとみなす。素朴に
/// `DateTime.parse` すると端末タイムゾーンで解釈され、JST以外の端末では
/// 全体的にずれて表示される。
DateTime parseKonomiDateTime(String value) {
  final text = value.trim().replaceFirst(' ', 'T');
  if (_tzSuffix.hasMatch(text)) return DateTime.parse(text);
  return DateTime.parse('$text+09:00');
}

/// ISO8601末尾のタイムゾーン指定 (`Z` / `+09:00` / `+0900`)。
final _tzSuffix = RegExp(r'([Zz]|[+-]\d{2}:?\d{2})$');

/// [parseKonomiDateTime] のnullable版。欠落・nullはnullのまま返す。
DateTime? parseKonomiNullableDateTime(String? value) =>
    value == null ? null : parseKonomiDateTime(value);
