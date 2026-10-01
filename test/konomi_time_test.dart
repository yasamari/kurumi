import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_time.dart';

void main() {
  test('オフセット無しはJSTとみなす', () {
    expect(
      parseKonomiDateTime('2026-10-01T01:00:00'),
      DateTime.utc(2026, 9, 30, 16, 0),
    );
  });

  test('オフセット付きは尊重する', () {
    expect(
      parseKonomiDateTime('2026-10-01T01:00:00+09:00'),
      DateTime.utc(2026, 9, 30, 16, 0),
    );
    expect(
      parseKonomiDateTime('2026-09-30T16:00:00Z'),
      DateTime.utc(2026, 9, 30, 16, 0),
    );
  });

  test('空白区切りと秒小数も解釈する', () {
    expect(
      parseKonomiDateTime('2026-10-01 01:00:00'),
      DateTime.utc(2026, 9, 30, 16, 0),
    );
    expect(
      parseKonomiDateTime('2026-10-01T01:00:00.123456'),
      DateTime.utc(2026, 9, 30, 16, 0, 0, 123, 456),
    );
  });

  test('nullable版はnullをそのまま返す', () {
    expect(parseKonomiNullableDateTime(null), isNull);
    expect(
      parseKonomiNullableDateTime('2026-10-01T01:00:00'),
      DateTime.utc(2026, 9, 30, 16, 0),
    );
  });
}
