import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/utils/time_format.dart';

void main() {
  test('日時を日本語形式に整形する', () {
    // 2026/09/29 は火曜日
    expect(
      formatDateTimeJa(DateTime(2026, 9, 29, 10, 5)),
      '2026/09/29 (火) 10:05',
    );
  });

  test('番組枠を整形する', () {
    expect(
      formatProgramSlot(
        DateTime(2026, 9, 29, 10, 5),
        DateTime(2026, 9, 29, 10, 55),
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
}
