import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/domain/entities/backend_type.dart';
import 'package:kurumi/src/features/shell/app_destinations.dart';

void main() {
  group('行き先の表示制御', () {
    test('区画の利用可否はバックエンドの能力に従う', () {
      expect(
        isSectionAvailable(AppSection.videos, BackendType.mirakurun),
        BackendType.mirakurun.supportsVideos,
      );
      expect(
        isSectionAvailable(AppSection.reservations, BackendType.mirakurun),
        BackendType.mirakurun.supportsRecordingReservations,
      );
      expect(
        isSectionAvailable(AppSection.videos, BackendType.konomiTv),
        BackendType.konomiTv.supportsVideos,
      );
      expect(
        isSectionAvailable(AppSection.reservations, BackendType.konomiTv),
        BackendType.konomiTv.supportsRecordingReservations,
      );
    });

    test('Mirakurun時はビデオと録画予約を除く', () {
      expect(
        visibleBranchIndices(BackendType.mirakurun),
        const [0, 2, 4],
      );
    });

    test('KonomiTV時は全て表示する', () {
      expect(
        visibleBranchIndices(BackendType.konomiTv),
        const [0, 1, 2, 3, 4],
      );
    });

    test('Mirakurun時はビデオと録画予約のパスを利用不可にする', () {
      expect(isPathAvailable('/videos', BackendType.mirakurun), isFalse);
      expect(isPathAvailable('/reservations', BackendType.mirakurun), isFalse);
      expect(isPathAvailable('/tv', BackendType.mirakurun), isTrue);
      expect(isPathAvailable('/timetable', BackendType.mirakurun), isTrue);
      expect(isPathAvailable('/settings', BackendType.mirakurun), isTrue);
      expect(
        isPathAvailable('/settings/backend', BackendType.mirakurun),
        isTrue,
      );
    });

    test('KonomiTV時は全パスを利用可能にする', () {
      expect(isPathAvailable('/videos', BackendType.konomiTv), isTrue);
      expect(isPathAvailable('/reservations', BackendType.konomiTv), isTrue);
    });
  });
}
