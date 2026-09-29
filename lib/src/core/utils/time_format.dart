// 日本語の曜日付き日時整形ヘルパー。
//
// 例: `2026/09/29 (火) 10:05 〜 10:55 (50分)`
// 追加パッケージなしで動作するよう手書きしている。

const _japaneseWeekdays = ['日', '月', '火', '水', '木', '金', '土'];

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// `2026/09/29 (火) 10:05` 形式に整形する。
String formatDateTimeJa(DateTime dateTime) {
  final weekday = _japaneseWeekdays[dateTime.weekday % 7];
  return '${dateTime.year}/${_twoDigits(dateTime.month)}/${_twoDigits(dateTime.day)} '
      '($weekday) ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
}

/// 番組枠 `開始 〜 終了 (分数)` 形式に整形する。
String formatProgramSlot(DateTime startAt, DateTime endAt) {
  final minutes = endAt.difference(startAt).inMinutes;
  final start = formatDateTimeJa(startAt);
  final end =
      '${_twoDigits(endAt.hour)}:${_twoDigits(endAt.minute)}';
  return '$start 〜 $end ($minutes分)';
}

/// 放送進捗率 0.0〜1.0 を返す。範囲外はクランプする。
double programProgress(DateTime startAt, DateTime endAt, DateTime now) {
  final total = endAt.difference(startAt).inMilliseconds;
  if (total <= 0) return 0;
  final elapsed = now.difference(startAt).inMilliseconds;
  return (elapsed / total).clamp(0.0, 1.0).toDouble();
}
