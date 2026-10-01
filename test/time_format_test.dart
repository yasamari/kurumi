import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/utils/time_format.dart';

void main() {
  test('日時を日本語形式に整形する', () {
    // 2026/09/29 は火曜日。UTCで作った瞬間をJSTの壁時計で表示する。
    expect(
      formatDateTimeJa(DateTime.utc(2026, 9, 29, 1, 5)),
      '2026/09/29 (火) 10:05',
    );
  });

  test('番組枠を整形する', () {
    expect(
      formatProgramSlot(
        DateTime.utc(2026, 9, 29, 1, 5),
        DateTime.utc(2026, 9, 29, 1, 55),
      ),
      '2026/09/29 (火) 10:05 〜 10:55 (50分)',
    );
  });

  test('進捗率を計算する', () {
    final start = DateTime(2026, 9, 29, 10, 0);
    final end = DateTime(2026, 9, 29, 11, 0);
    expect(programProgress(start, end, DateTime(2026, 9, 29, 10, 30)), 0.5);
    expect(programProgress(start, end, DateTime(2026, 9, 29, 9, 0)), 0.0);
    expect(programProgress(start, end, DateTime(2026, 9, 29, 12, 0)), 1.0);
  });

  test('時刻だけを整形する', () {
    // 秒は 0 埋めされる。JSTの壁時計で表示する。
    expect(formatClockJa(DateTime.utc(2026, 9, 29, 1, 5, 3)), '10:05:03');
    expect(formatClockJa(DateTime.utc(2026, 9, 28, 15, 0, 0)), '00:00:00');
    expect(formatClockJa(DateTime.utc(2026, 9, 29, 14, 59, 59)), '23:59:59');
  });
}
