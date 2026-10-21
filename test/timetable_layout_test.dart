import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show TextScaler, TextStyle;
import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/domain/entities/channel.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';
import 'package:kurumi/src/domain/entities/timetable.dart';
import 'package:kurumi/src/domain/entities/tv_program.dart';
import 'package:kurumi/src/features/timetable/timetable_layout.dart';
import 'package:kurumi/src/features/timetable/widgets/timetable_cell_raster.dart';

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
      expect(isTimetableToday(dayStartMs, _utcMs(2026, 10, 8, 20)), isFalse);
    });
  });

  group('座標計算', () {
    test('1時間は180pxになる', () {
      expect(timetableOffsetPx(dayStartMs + 3600 * 1000, dayStartMs), 180);
    });

    test('期間の高さが求まる', () {
      expect(timetableHeightPx(dayStartMs, dayEndMs), 4320);
    });

    test('ズーム倍率が座標と高さに掛かる', () {
      expect(
        timetableOffsetPx(dayStartMs + 3600 * 1000, dayStartMs, zoom: 2),
        360,
      );
      expect(timetableHeightPx(dayStartMs, dayEndMs, zoom: 0.5), 2160);
      expect(timetablePxPerMinAt(1.5), 4.5);
      expect(timetableColumnWidthAt(2), timetableColumnWidth * 2);
    });

    test('ズーム倍率は範囲内に丸める', () {
      expect(timetableClampZoom(0.1), timetableMinZoom);
      expect(timetableClampZoom(10), timetableMaxZoom);
      expect(timetableClampZoom(1.5), 1.5);
      expect(timetableClampZoom(double.nan), 1.0);
    });

    test('ズームしても焦点位置の時刻が動かない', () {
      // 1倍・オフセット0で焦点200pxは放送日開始から200px (200/3分)。
      const focalPx = 200.0;
      final before = timetableTopVisibleTimeMs(
        offsetPx: focalPx,
        dayStartMs: dayStartMs,
        dayEndMs: dayEndMs,
      );
      final newOffset = timetableZoomedOffset(
        offsetPx: 0,
        focalPx: focalPx,
        oldZoom: 1,
        newZoom: 2,
        viewportHeightPx: 800,
        gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs, zoom: 2),
      );
      // 焦点は新しいオフセットからも200pxの位置にある。
      expect(newOffset, 200);
      expect(
        timetableTopVisibleTimeMs(
          offsetPx: newOffset + focalPx,
          dayStartMs: dayStartMs,
          dayEndMs: dayEndMs,
          zoom: 2,
        ),
        before,
      );
    });

    test('ズーム後のオフセットは両端でクランプされる', () {
      expect(
        timetableZoomedOffset(
          offsetPx: 0,
          focalPx: 0,
          oldZoom: 1,
          newZoom: 2,
          viewportHeightPx: 800,
          gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs, zoom: 2),
        ),
        0,
      );
      expect(
        timetableZoomedOffset(
          offsetPx: 0,
          focalPx: 9000,
          oldZoom: 1,
          newZoom: 2,
          viewportHeightPx: 800,
          gridHeightPx: timetableHeightPx(dayStartMs, dayEndMs, zoom: 2),
        ),
        timetableHeightPx(dayStartMs, dayEndMs, zoom: 2) - 800,
      );
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
      expect(timetableDragOffset(offset: 100, maxOffset: 1000, delta: 30), 70);
      expect(
        timetableDragOffset(offset: 100, maxOffset: 1000, delta: -30),
        130,
      );
    });

    test('両端でクランプする', () {
      // 下端 (先頭)。上へ引っ張っても 0 より行かない。
      expect(timetableDragOffset(offset: 10, maxOffset: 500, delta: 40), 0);
      // 上端 (末尾)。下へ引っ張っても最大値を超えない。
      expect(timetableDragOffset(offset: 490, maxOffset: 500, delta: -40), 500);
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
      expect(timetableGenreSeedColor(''), const Color(0xFF9E9E9E));
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

  group('表示窓', () {
    List<TimetableColumnSegment> segmentsOfHeights(List<double> heights) {
      final result = <TimetableColumnSegment>[];
      var top = 0.0;
      for (final height in heights) {
        result.add((topPx: top, heightPx: height, program: null));
        top += height;
      }
      return result;
    }

    test('空の列は空の窓になる', () {
      expect(
        timetableSegmentWindow(
          segments: const [],
          offsetPx: 0,
          viewportHeightPx: 900,
          cacheExtentPx: 250,
        ),
        (first: 0, last: 0),
      );
    });

    test('可視範囲と余白に重なるセグメントが入る', () {
      final segments = segmentsOfHeights([180, 180, 180, 180, 180]);
      // 2件目の先頭から1件分。余白なしなら2件目だけ。
      expect(
        timetableSegmentWindow(
          segments: segments,
          offsetPx: 180,
          viewportHeightPx: 180,
          cacheExtentPx: 0,
        ),
        (first: 1, last: 2),
      );
      // 前後に250pxの余白を足すと1〜4件目まで。
      expect(
        timetableSegmentWindow(
          segments: segments,
          offsetPx: 180,
          viewportHeightPx: 180,
          cacheExtentPx: 250,
        ),
        (first: 0, last: 4),
      );
    });

    test('半分だけ見えるセグメントも含む', () {
      final segments = segmentsOfHeights([180, 180, 180]);
      expect(
        timetableSegmentWindow(
          segments: segments,
          offsetPx: 90,
          viewportHeightPx: 180,
          cacheExtentPx: 0,
        ),
        (first: 0, last: 2),
      );
    });

    test('末尾を超えたオフセットでは最後のセグメントを返す', () {
      final segments = segmentsOfHeights([180, 180, 180]);
      expect(
        timetableSegmentWindow(
          segments: segments,
          offsetPx: 1000,
          viewportHeightPx: 180,
          cacheExtentPx: 0,
        ),
        (first: 2, last: 3),
      );
    });

    test('高さの異なるセグメントでも二分探索で正しく引ける', () {
      // 30・60・15・45分番組相当の高さを繰り返す。
      final segments = segmentsOfHeights([
        for (var i = 0; i < 100; i++) ...<double>[90, 180, 45, 135],
      ]);
      for (var i = 0; i < segments.length; i++) {
        final range = timetableSegmentWindow(
          segments: segments,
          offsetPx: segments[i].topPx,
          viewportHeightPx: 1,
          cacheExtentPx: 0,
        );
        expect(range.first, i, reason: 'topPx=${segments[i].topPx}');
        expect(range.last, i + 1, reason: 'topPx=${segments[i].topPx}');
      }
    });

    test('先頭より上へスクロールしても先頭から返す', () {
      final segments = segmentsOfHeights([180, 180]);
      expect(
        timetableSegmentWindow(
          segments: segments,
          offsetPx: -100,
          viewportHeightPx: 180,
          cacheExtentPx: 0,
        ),
        (first: 0, last: 1),
      );
    });
  });

  group('セグメントのヒットテスト', () {
    List<TimetableColumnSegment> segmentsOfHeights(List<double> heights) {
      final result = <TimetableColumnSegment>[];
      var top = 0.0;
      for (final height in heights) {
        result.add((topPx: top, heightPx: height, program: null));
        top += height;
      }
      return result;
    }

    test('境界は次のセグメントに属する', () {
      final segments = segmentsOfHeights([100, 50, 200]);
      expect(timetableSegmentIndexAt(segments: segments, yPx: 0), 0);
      expect(timetableSegmentIndexAt(segments: segments, yPx: 99.9), 0);
      expect(timetableSegmentIndexAt(segments: segments, yPx: 100), 1);
      expect(timetableSegmentIndexAt(segments: segments, yPx: 150), 2);
    });

    test('範囲外はnullになる', () {
      final segments = segmentsOfHeights([100, 50]);
      expect(timetableSegmentIndexAt(segments: segments, yPx: -0.1), isNull);
      expect(timetableSegmentIndexAt(segments: segments, yPx: 150), isNull);
      expect(timetableSegmentIndexAt(segments: const [], yPx: 0), isNull);
    });

    test('小さなセグメントが連続しても引ける', () {
      final segments = segmentsOfHeights([for (var i = 0; i < 100; i++) 4.5]);
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        expect(
          timetableSegmentIndexAt(
            segments: segments,
            yPx: segment.topPx + segment.heightPx / 2,
          ),
          i,
        );
      }
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
        timetableHourStartMs(timeMs: dayStartMs - 1, dayStartMs: dayStartMs),
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

  group('セル画像の解像度', () {
    test('ズーム倍率と DPR を掛けた倍率で焼く', () {
      expect(
        timetableCellRasterPixelScale(
          devicePixelRatio: 2,
          rasterZoom: 1,
          width: 100,
          height: 100,
        ),
        2,
      );
      expect(
        timetableCellRasterPixelScale(
          devicePixelRatio: 2,
          rasterZoom: 3,
          width: 100,
          height: 100,
        ),
        6,
      );
    });

    test('極端に大きいセルは最大ピクセル数に収める', () {
      final scale = timetableCellRasterPixelScale(
        devicePixelRatio: 3,
        rasterZoom: 3,
        width: 1024,
        height: 1024,
      );
      expect(scale, closeTo(2.828427, 0.0001));
    });
  });

  group('セル本文の行数', () {
    const titleStyle = TextStyle(fontSize: 12, height: 1.25);
    const descriptionStyle = TextStyle(fontSize: 12, height: 1.3);

    int maxLines(
      double height, {
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return timetableCellBodyMaxLines(
        availableHeight: height,
        titleStyle: titleStyle,
        descriptionStyle: descriptionStyle,
        textScaler: textScaler,
      );
    }

    test('表示高さに収まる行数に余裕を足す', () {
      // 行高の小さい titleStyle (12 * 1.25 = 15) で見積もる。
      expect(maxLines(70), 7);
    });

    test('文字が大きいほど行数は減る', () {
      expect(maxLines(70, textScaler: const TextScaler.linear(2)), 5);
    });

    test('高さが0以下でも1行は残す', () {
      expect(maxLines(0), 1);
      expect(maxLines(-10), 1);
    });
  });

  group('セル画像生成の割り当て', () {
    test('フレームごとに担当列がずれる', () {
      for (var frame = 0; frame < 3; frame++) {
        final allowed = [
          for (var i = 0; i < 6; i++)
            if (timetableRasterGateAllows(
              frame: frame,
              columnIndex: i,
              stride: 3,
            ))
              i,
        ];
        expect(allowed, [frame, frame + 3]);
      }
    });

    test('列ごとに stride フレームで一巡する', () {
      for (var i = 0; i < 10; i++) {
        final allowedFrames = [
          for (var frame = 0; frame < 30; frame++)
            if (timetableRasterGateAllows(
              frame: frame,
              columnIndex: i,
              stride: 3,
            ))
              frame,
        ];
        expect(allowedFrames.first, lessThan(3));
        expect(allowedFrames.take(10).toList(), [
          for (var n = 0; n < 10; n++) allowedFrames.first + n * 3,
        ]);
      }
    });

    test('stride 1 は制限しない', () {
      for (var frame = 0; frame < 5; frame++) {
        for (var i = 0; i < 5; i++) {
          expect(
            timetableRasterGateAllows(frame: frame, columnIndex: i, stride: 1),
            isTrue,
          );
        }
      }
    });
  });
}
