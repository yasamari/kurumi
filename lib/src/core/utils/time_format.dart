// 日本語の曜日付き日時整形ヘルパー。
//
// 例: `2026/09/29 (火) 10:05 〜 10:55 (50分)`
// 追加パッケージなしで動作するよう手書きしている。
//
// 番組表の時刻はJST基準のため、表示は端末タイムゾーンによらずJSTの壁時計に
// 統一する (KonomiTVサーバーはJST、Mirakurunはepoch由来の絶対時刻。どちらも
// 瞬間としては正しいため、表示時にJSTへ寄せるだけで全体のずれが解消する)。

const _japaneseWeekdays = ['日', '月', '火', '水', '木', '金', '土'];

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// JSTの壁時計に直す。UTC化して9時間進めた `DateTime` (isUtc) を返し、
/// フィールド参照でJSTの年月日時分秒が読めるようにする。
DateTime toJst(DateTime dateTime) =>
    dateTime.toUtc().add(const Duration(hours: 9));

/// `2026/09/29 (火) 10:05` 形式に整形する。JST表示。
String formatDateTimeJa(DateTime dateTime) {
  final jst = toJst(dateTime);
  final weekday = _japaneseWeekdays[jst.weekday % 7];
  return '${jst.year}/${_twoDigits(jst.month)}/${_twoDigits(jst.day)} '
      '($weekday) ${_twoDigits(jst.hour)}:${_twoDigits(jst.minute)}';
}

/// 番組枠 `開始 〜 終了 (分数)` 形式に整形する。JST表示。
String formatProgramSlot(DateTime startAt, DateTime endAt) {
  final minutes = endAt.difference(startAt).inMinutes;
  final start = formatDateTimeJa(startAt);
  final endJst = toJst(endAt);
  final end = '${_twoDigits(endJst.hour)}:${_twoDigits(endJst.minute)}';
  return '$start 〜 $end ($minutes分)';
}

/// `10:05:33` 形式に整形する。JST表示。
///
/// 実況コメントなど、時刻部分だけが必要な場面向け。
String formatClockJa(DateTime dateTime) {
  final jst = toJst(dateTime);
  return '${_twoDigits(jst.hour)}:${_twoDigits(jst.minute)}:'
      '${_twoDigits(jst.second)}';
}

/// 放送進捗率 0.0〜1.0 を返す。範囲外はクランプする。
double programProgress(DateTime startAt, DateTime endAt, DateTime now) {
  final total = endAt.difference(startAt).inMilliseconds;
  if (total <= 0) return 0;
  final elapsed = now.difference(startAt).inMilliseconds;
  return (elapsed / total).clamp(0.0, 1.0).toDouble();
}
