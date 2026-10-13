import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/domain/entities/channel.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';
import 'package:kurumi/src/domain/entities/timetable.dart';
import 'package:kurumi/src/domain/entities/tv_program.dart';
import 'package:kurumi/src/features/timetable/timetable_layout.dart';

/// 2026-10-08 (木) 10:00 JST = 2026-10-08 01:00 UTC。
int _utcMs(int y, int mo, int d, int h, [int min = 0]) =>
    DateTime.utc(y, mo, d, h, min).millisecondsSinceEpoch;

TvProgram _program({
  required int startMs,
  required int endMs,
  String title = '番組',
  List<String> genres = const [],
}) {
  return TvProgram(
    eventId: 1,
    title: title,
    startAt: DateTime.fromMillisecondsSinceEpoch(startMs),
    endAt: DateTime.fromMillisecondsSinceEpoch(endMs),
    genres: genres,
  );
}

TimetableChannel _column(
  String id,
  ChannelType type,
  List<TvProgram> programs,
) {
  return TimetableChannel(
    channel: Channel(
      id: id,
      name: id,
      channelType: type,
      networkId: 1,
      serviceId: 1,
    ),
    programs: programs,
  );
}

void main() {
  // 2026-10-08 04:00 JST = 2026-10-07 19:00 UTC。
  final dayStartMs = _utcMs(2026, 10, 7, 19);
  final dayEndMs = dayStartMs + timetableDayLengthMs;

  group('放送日の開始時刻', () {
    test('日中はその日の4時になる', () {
      // 2026-10-08 10:00 JST。
      expect(timetableDayStartMs(_utcMs(2026, 10, 8, 1)), dayStartMs);
    });

    test('4時ちょうどはその日の4時になる', () {
      expect(timetableDayStartMs(_utcMs(2026, 10, 7, 19)), dayStartMs);
    });

    test('4時前は前日の4時になる', () {
      // 2026-10-08 03:59 JST = 2026-10-07 18:59 UTC。
      expect(
        timetableDayStartMs(_utcMs(2026, 10, 7, 18, 59)),
        dayStartMs - timetableDayLengthMs,
      );
    });

    test('深夜は前日の放送日に属する', () {
      // 2026-10-09 03:00 JST = 2026-10-08 18:00 UTC。
      expect(timetableDayStartMs(_utcMs(2026, 10, 8, 18)), dayStartMs);
    });

    test('日オフセットでずらせる', () {
      expect(
        timetableDayStartMsForOffset(dayStartMs, 1),
        dayStartMs + timetableDayLengthMs,
      );
      expect(
        timetableDayStartMsForOffset(dayStartMs, -1),
        dayStartMs - timetableDayLengthMs,
      );
    });

    test('放送日の開始時刻から日オフセットが求まる', () {
      expect(
        timetableDayOffsetForDayStart(
          baseDayStartMs: dayStartMs,
          targetDayStartMs: dayStartMs,
        ),
        0,
      );
      expect(
        timetableDayOffsetForDayStart(
          baseDayStartMs: dayStartMs,
          targetDayStartMs: dayStartMs + timetableDayLengthMs,
        ),
        1,
      );
      expect(
        timetableDayOffsetForDayStart(
          baseDayStartMs: dayStartMs,
          targetDayStartMs: dayStartMs - timetableDayLengthMs,
        ),
        -1,
      );
    });

    test('日ラベルは月日と曜日になる', () {
      expect(formatTimetableDay(dayStartMs), '10/8（木）');
    });

    test('短い日ラベルは月日だけになる', () {
      expect(formatTimetableDayShort(dayStartMs), '10/8');
    });

    test('今日判定ができる', () {
      expect(isTimetableToday(dayStartMs, _utcMs(2026, 10, 8, 1)), isTrue);
      expect(
        isTimetableToday(dayStartMs, _utcMs(2026, 10, 8, 20)),
        isFalse,
      );
    });
  });

  group('座標計算', () {
    test('1時間は180pxになる', () {
      expect(timetableOffsetPx(dayStartMs + 3600 * 1000, dayStartMs), 180);
    });

    test('期間の高さが求まる', () {
      expect(timetableHeightPx(dayStartMs, dayEndMs), 4320);
    });

    test('範囲切り詰めができる', () {
      final clamped = clampProgramToRange(
        startMs: dayStartMs - 3600 * 1000,
        endMs: dayStartMs + 3600 * 1000,
        rangeStartMs: dayStartMs,
        rangeEndMs: dayEndMs,
      );
      expect(clamped?.startMs, dayStartMs);
      expect(clamped?.endMs, dayStartMs + 3600 * 1000);
    });

    test('範囲外は切り詰め不能になる', () {
      expect(
        clampProgramToRange(
          startMs: dayStartMs - 2 * 3600 * 1000,
          endMs: dayStartMs - 3600 * 1000,
          rangeStartMs: dayStartMs,
          rangeEndMs: dayEndMs,
        ),
        isNull,
      );
      // 終了ちょうど・開始ちょうどは重ならない。
      expect(
        clampProgramToRange(
          startMs: dayStartMs - 3600 * 1000,
          endMs: dayStartMs,
          rangeStartMs: dayStartMs,
          rangeEndMs: dayEndMs,
        ),
        isNull,
      );
      expect(
        clampProgramToRange(
          startMs: dayEndMs,
          endMs: dayEndMs + 3600 * 1000,
          rangeStartMs: dayStartMs,
          rangeEndMs: dayEndMs,
        ),
        isNull,
      );
    });

    test('範囲外番組の高さは0になる', () {
      expect(
        timetableProgramHeightPx(
          startMs: dayStartMs - 3600 * 1000,
          endMs: dayStartMs,
          rangeStartMs: dayStartMs,
          rangeEndMs: dayEndMs,
        ),
        0,
      );
    });
  });

  group('ドラッグオフセット', () {
    test('指の移動と逆方向へ動く', () {
      expect(
        timetableDragOffset(offset: 100, maxOffset: 1000, delta: 30),
        70,
      );
      expect(
        timetableDragOffset(offset: 100, maxOffset: 1000, delta: -30),
        130,
      );
    });

    test('両端でクランプする', () {
      // 下端 (先頭)。上へ引っ張っても 0 より行かない。
      expect(timetableDragOffset(offset: 10, maxOffset: 500, delta: 40), 0);
      // 上端 (末尾)。下へ引っ張っても最大値を超えない。
      expect(
        timetableDragOffset(offset: 490, maxOffset: 500, delta: -40),
        500,
      );
    });

    test('内容がビューポートより短ければ動かない', () {
      expect(timetableDragOffset(offset: 0, maxOffset: 0, delta: 40), 0);
      expect(timetableDragOffset(offset: 0, maxOffset: -1, delta: -40), 0);
    });
  });

  group('時境界', () {
    test('1日分は24件で5時から28時までになる', () {
      final marks = timetableHourMarksMs(dayStartMs, dayEndMs);
      expect(marks, hasLength(24));
      expect(marks.first, dayStartMs + 3600 * 1000);
      expect(marks.last, dayEndMs);
    });

    test('放送日内の毎正時が24件並ぶ', () {
      final hours = timetableDayHoursMs(dayStartMs);
      expect(hours, hasLength(24));
      expect(hours.first, dayStartMs);
      for (var i = 1; i < hours.length; i++) {
        expect(hours[i] - hours[i - 1], 3600 * 1000);
      }
    });

    test('時刻ラベルはJSTの時になる', () {
      expect(formatTimetableHour(dayStartMs), '4時');
      expect(formatTimetableHour(dayStartMs + 8 * 3600 * 1000), '12時');
    });
  });

  group('ジャンプ先オフセット', () {
    test('対象時刻が上から1/4に来る', () {
      // 2時間後=360px、ビューポート800pxなら160pxになる。
      expect(
        timetableJumpTargetPx(
          timeMs: dayStartMs + 2 * 3600 * 1000,
          dayStartMs: dayStartMs,
          viewportHeightPx: 800,
          gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs),
        ),
        160,
      );
    });

    test('先頭では0にクランプする', () {
      expect(
        timetableJumpTargetPx(
          timeMs: dayStartMs,
          dayStartMs: dayStartMs,
          viewportHeightPx: 800,
          gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs),
        ),
        0,
      );
    });

    test('末尾では最大値にクランプする', () {
      expect(
        timetableJumpTargetPx(
          timeMs: dayEndMs,
          dayStartMs: dayStartMs,
          viewportHeightPx: 800,
          gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs),
        ),
        timetableHeightPx(dayStartMs, dayEndMs) - 800,
      );
    });

    test('内容がビューポートより短ければ0になる', () {
      expect(
        timetableJumpTargetPx(
          timeMs: dayStartMs + 3600 * 1000,
          dayStartMs: dayStartMs,
          viewportHeightPx: 5000,
          gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs),
        ),
        0,
      );
    });
  });

  group('次回更新時刻', () {
    test('未来で最も早い番組境界を返す', () {
      final nowMs = _utcMs(2026, 10, 8, 1); // 10:00 JST。
      final columns = [
        _column('a', const ChannelType.gr(), [
          _program(startMs: nowMs - 3600 * 1000, endMs: nowMs + 1800 * 1000),
          _program(startMs: nowMs + 1800 * 1000, endMs: nowMs + 3600 * 1000),
        ]),
        _column('b', const ChannelType.bs(), [
          _program(startMs: nowMs - 3600 * 1000, endMs: nowMs + 600 * 1000),
        ]),
      ];
      expect(
        nextTimetableTickMs(columns: columns, nowMs: nowMs),
        nowMs + 600 * 1000,
      );
    });

    test('未来の境界がなければnullになる', () {
      final nowMs = _utcMs(2026, 10, 8, 1);
      final columns = [
        _column('a', const ChannelType.gr(), [
          _program(startMs: nowMs - 3600 * 1000, endMs: nowMs - 1000),
        ]),
      ];
      expect(nextTimetableTickMs(columns: columns, nowMs: nowMs), isNull);
      expect(nextTimetableTickMs(columns: const [], nowMs: nowMs), isNull);
    });
  });

  group('列の絞り込み', () {
    test('指定種別の列だけ残る', () {
      final columns = [
        _column('a', const ChannelType.gr(), const []),
        _column('b', const ChannelType.bs(), const []),
      ];
      final filtered = timetableColumnsOfType(columns, const ChannelType.gr());
      expect(filtered.map((c) => c.channel.id), ['a']);
    });
  });

  group('ジャンル', () {
    test('大分類を取り出せる', () {
      expect(timetableGenreMajor(['ニュース／報道']), 'ニュース');
      expect(timetableGenreMajor(['アニメ・特撮']), 'アニメ');
      expect(timetableGenreMajor(['映画']), '映画');
      expect(timetableGenreMajor(const []), '');
    });

    test('未知の大分類は灰色になる', () {
      expect(
        timetableGenreSeedColor(''), const Color(0xFF9E9E9E),
      );
      expect(
        timetableGenreSeedColor('ニュース') == const Color(0xFF9E9E9E),
        isFalse,
      );
    });
  });

  group('列セグメント', () {
    List<TimetableColumnSegment> segmentsOf(List<TvProgram> programs) {
      return timetableColumnSegments(
        programs: programs,
        rangeStartMs: dayStartMs,
        rangeEndMs: dayEndMs,
        gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs),
      );
    }

    test('空列は全体が空白1件になる', () {
      final segments = segmentsOf(const []);
      expect(segments, hasLength(1));
      expect(segments.single.program, isNull);
      expect(segments.single.heightPx, timetableHeightPx(dayStartMs, dayEndMs));
    });

    test('前後の空白が埋まり合計が全体高さになる', () {
      final segments = segmentsOf([
        _program(
          startMs: dayStartMs + 3600 * 1000,
          endMs: dayStartMs + 2 * 3600 * 1000,
          title: '番組',
        ),
      ]);
      expect(segments, hasLength(3));
      expect(segments[0].program, isNull);
      expect(segments[0].heightPx, 180);
      expect(segments[1].program?.title, '番組');
      expect(segments[1].heightPx, 180);
      expect(segments[2].program, isNull);
      final total = segments.fold<double>(0, (sum, s) => sum + s.heightPx);
      expect(total, timetableHeightPx(dayStartMs, dayEndMs));
    });

    test('連続番組には空白が入らない', () {
      final segments = segmentsOf([
        _program(startMs: dayStartMs, endMs: dayStartMs + 3600 * 1000),
        _program(
          startMs: dayStartMs + 3600 * 1000,
          endMs: dayStartMs + 2 * 3600 * 1000,
        ),
      ]);
      expect(segments.where((s) => s.program == null), hasLength(1));
      // 末尾の空白のみ。
      expect(segments.last.program, isNull);
    });

    test('重なる番組でも負の高さが出ず合計が全体高さになる', () {
      final segments = segmentsOf([
        _program(startMs: dayStartMs, endMs: dayStartMs + 2 * 3600 * 1000),
        _program(
          startMs: dayStartMs + 3600 * 1000,
          endMs: dayStartMs + 3 * 3600 * 1000,
        ),
      ]);
      for (final segment in segments) {
        expect(segment.heightPx, greaterThanOrEqualTo(0));
      }
      final total = segments.fold<double>(0, (sum, s) => sum + s.heightPx);
      expect(total, timetableHeightPx(dayStartMs, dayEndMs));
    });

    test('範囲外の番組は落ちる', () {
      final segments = segmentsOf([
        _program(
          startMs: dayStartMs - 2 * 3600 * 1000,
          endMs: dayStartMs - 3600 * 1000,
        ),
      ]);
      expect(segments, hasLength(1));
      expect(segments.single.program, isNull);
    });
  });

  group('セルの表示量', () {
    test('文章表示の要否が決まる', () {
      expect(timetableCellShowsText(35.9), isFalse);
      expect(timetableCellShowsText(36), isTrue);
    });

    test('セル時刻は時:分-時:分になる', () {
      expect(
        formatTimetableCellTime(
          DateTime.fromMillisecondsSinceEpoch(_utcMs(2026, 10, 8, 0, 5)),
          DateTime.fromMillisecondsSinceEpoch(_utcMs(2026, 10, 8, 1)),
        ),
        '9:05-10:00',
      );
    });
  });

  group('表示中時刻', () {
    test('オフセット0では先頭時刻になる', () {
      expect(
        timetableTopVisibleTimeMs(
          offsetPx: 0,
          dayStartMs: dayStartMs,
          dayEndMs: dayEndMs,
        ),
        dayStartMs,
      );
    });

    test('1時間で180px進む', () {
      expect(
        timetableTopVisibleTimeMs(
          offsetPx: 180,
          dayStartMs: dayStartMs,
          dayEndMs: dayEndMs,
        ),
        dayStartMs + 3600 * 1000,
      );
    });

    test('範囲外は両端に丸める', () {
      expect(
        timetableTopVisibleTimeMs(
          offsetPx: -10,
          dayStartMs: dayStartMs,
          dayEndMs: dayEndMs,
        ),
        dayStartMs,
      );
      expect(
        timetableTopVisibleTimeMs(
          offsetPx: 10000,
          dayStartMs: dayStartMs,
          dayEndMs: dayEndMs,
        ),
        dayEndMs - 1,
      );
    });

    test('正時に切り捨てられる', () {
      // 10:30 JST = 01:30 UTC。
      final halfPast = _utcMs(2026, 10, 8, 1, 30);
      final offset = timetableOffsetPx(halfPast, dayStartMs);
      expect(
        timetableVisibleHourMs(
          offsetPx: offset,
          dayStartMs: dayStartMs,
          dayEndMs: dayEndMs,
        ),
        _utcMs(2026, 10, 8, 1),
      );
    });

    test('含む正時の開始時刻が求まる', () {
      expect(
        timetableHourStartMs(timeMs: dayStartMs, dayStartMs: dayStartMs),
        dayStartMs,
      );
      expect(
        timetableHourStartMs(
          timeMs: dayStartMs + 90 * 60 * 1000,
          dayStartMs: dayStartMs,
        ),
        dayStartMs + 3600 * 1000,
      );
      // 範囲外は両端に丸める。
      expect(
        timetableHourStartMs(
          timeMs: dayStartMs - 1,
          dayStartMs: dayStartMs,
        ),
        dayStartMs,
      );
      expect(
        timetableHourStartMs(
          timeMs: dayStartMs + timetableDayLengthMs,
          dayStartMs: dayStartMs,
        ),
        dayStartMs + timetableDayLengthMs - 3600 * 1000,
      );
    });
  });
}
