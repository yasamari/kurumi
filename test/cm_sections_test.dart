import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_video_dtos.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_video_filter.dart';
import 'package:kurumi/src/domain/entities/cm_section.dart';
import 'package:kurumi/src/features/player/cm_sections.dart';

void main() {
  group('normalizeCmSections', () {
    test('開始順に並べる', () {
      final sections = normalizeCmSections([
        const CmSection(startTime: 60, endTime: 90),
        const CmSection(startTime: 10, endTime: 20),
      ]);
      expect(sections, [
        const CmSection(startTime: 10, endTime: 20),
        const CmSection(startTime: 60, endTime: 90),
      ]);
    });

    test('無効な区間を落とす', () {
      final sections = normalizeCmSections([
        const CmSection(startTime: 10, endTime: 10),
        const CmSection(startTime: 20, endTime: 15),
        const CmSection(startTime: -5, endTime: 5),
        const CmSection(startTime: double.nan, endTime: 5),
        const CmSection(startTime: 30, endTime: 40),
      ]);
      expect(sections, [const CmSection(startTime: 30, endTime: 40)]);
    });

    test('重なり・隣接を結合する', () {
      final sections = normalizeCmSections([
        const CmSection(startTime: 10, endTime: 30),
        const CmSection(startTime: 20, endTime: 40),
        const CmSection(startTime: 40, endTime: 50),
        const CmSection(startTime: 100, endTime: 110),
      ]);
      expect(sections, [
        const CmSection(startTime: 10, endTime: 50),
        const CmSection(startTime: 100, endTime: 110),
      ]);
    });
  });

  group('buildCmSections', () {
    test('nullは空に畳む', () {
      expect(buildCmSections(null), isEmpty);
      expect(buildCmSections(const []), isEmpty);
    });

    test('DTOを変換して正規化する', () {
      final sections = buildCmSections([
        const KonomiCmSectionDto(startTime: 60, endTime: 90),
        const KonomiCmSectionDto(startTime: 10, endTime: 20),
      ]);
      expect(sections, [
        const CmSection(startTime: 10, endTime: 20),
        const CmSection(startTime: 60, endTime: 90),
      ]);
    });
  });

  group('cmSectionAt', () {
    const sections = [
      CmSection(startTime: 10, endTime: 20),
      CmSection(startTime: 60, endTime: 90),
    ];

    test('区間内を拾う', () {
      expect(cmSectionAt(sections, 10), sections[0]);
      expect(cmSectionAt(sections, 15), sections[0]);
      expect(cmSectionAt(sections, 75), sections[1]);
    });

    test('終端は含まない', () {
      expect(cmSectionAt(sections, 20), isNull);
      expect(cmSectionAt(sections, 90), isNull);
    });

    test('区間外はnull', () {
      expect(cmSectionAt(sections, 0), isNull);
      expect(cmSectionAt(sections, 30), isNull);
      expect(cmSectionAt(sections, 100), isNull);
    });
  });

  group('cmSkipTargetSec', () {
    const sections = [CmSection(startTime: 10, endTime: 20)];

    test('区間内は終端+余白に飛ぶ', () {
      expect(cmSkipTargetSec(sections, 15), 20 + cmSkipLandingOffsetSec);
    });

    test('区間外はnull', () {
      expect(cmSkipTargetSec(sections, 5), isNull);
      expect(cmSkipTargetSec(sections, 20), isNull);
    });
  });

  group('cmAutoSkipTargetSec', () {
    const sections = [CmSection(startTime: 10, endTime: 20)];

    test('無効なら飛ばさない', () {
      expect(
        cmAutoSkipTargetSec(
          sections: sections,
          positionSec: 15,
          enabled: false,
        ),
        isNull,
      );
    });

    test('有効で区間内なら飛ぶ', () {
      expect(
        cmAutoSkipTargetSec(sections: sections, positionSec: 15, enabled: true),
        20 + cmSkipLandingOffsetSec,
      );
    });
  });

  group('cmSectionFractions', () {
    test('再生尺に対する割合に直す', () {
      final fractions = cmSectionFractions(const [
        CmSection(startTime: 10, endTime: 20),
      ], 100);
      expect(fractions.single.start, closeTo(0.1, 1e-9));
      expect(fractions.single.end, closeTo(0.2, 1e-9));
    });

    test('範囲外は丸めて幅ゼロは落とす', () {
      final fractions = cmSectionFractions(const [
        CmSection(startTime: -10, endTime: 10),
        CmSection(startTime: 90, endTime: 200),
        CmSection(startTime: 150, endTime: 200),
      ], 100);
      expect(fractions.length, 2);
      expect(fractions[0].start, 0.0);
      expect(fractions[1].end, 1.0);
    });

    test('再生尺が不正なら空', () {
      const sections = [CmSection(startTime: 10, endTime: 20)];
      expect(cmSectionFractions(sections, 0), isEmpty);
      expect(cmSectionFractions(sections, double.nan), isEmpty);
    });
  });
}
