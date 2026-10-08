import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/data/epg/epg_database.dart';
import 'package:kurumi/src/data/epg/epg_sync_policy.dart';

const _baseUrl = 'http://example.test:40772';
const _hourMs = 3600 * 1000;

EpgSyncMetaData _meta({required String baseUrl, required int fetchedAtMs}) {
  // DataClass は直接作れないため Companion 経由で組み立てる。
  final companion = EpgSyncMetaCompanion(
    sourceBackend: const Value('mirakurun'),
    baseUrl: Value(baseUrl),
    fetchedAtMs: Value(fetchedAtMs),
    channelCount: const Value(10),
    programCount: const Value(100),
  );
  return EpgSyncMetaData(
    sourceBackend: companion.sourceBackend.value,
    baseUrl: companion.baseUrl.value,
    fetchedAtMs: companion.fetchedAtMs.value,
    channelCount: companion.channelCount.value,
    programCount: companion.programCount.value,
  );
}

void main() {
  group('epgCacheExpiresAtMs', () {
    test('取得時刻＋間隔が期限になる', () {
      expect(
        epgCacheExpiresAtMs(fetchedAtMs: 1000, intervalHours: 6),
        1000 + 6 * _hourMs,
      );
    });
  });

  group('isEpgCacheFresh', () {
    test('期限内は新鮮・期限ちょうどは期限切れ', () {
      const fetchedAt = 1000;
      expect(
        isEpgCacheFresh(
          fetchedAtMs: fetchedAt,
          intervalHours: 6,
          nowMs: fetchedAt + 6 * _hourMs - 1,
        ),
        isTrue,
      );
      expect(
        isEpgCacheFresh(
          fetchedAtMs: fetchedAt,
          intervalHours: 6,
          nowMs: fetchedAt + 6 * _hourMs,
        ),
        isFalse,
      );
    });
  });

  group('decideEpgSync', () {
    test('未取得なら取得する', () {
      expect(
        decideEpgSync(
          meta: null,
          baseUrl: _baseUrl,
          intervalHours: 6,
          nowMs: 0,
        ),
        EpgSyncDecision.fetch,
      );
    });

    test('URLが変わったら消してから取得する', () {
      expect(
        decideEpgSync(
          meta: _meta(baseUrl: 'http://old.test:40772', fetchedAtMs: 0),
          baseUrl: _baseUrl,
          intervalHours: 6,
          nowMs: 1,
        ),
        EpgSyncDecision.clearThenFetch,
      );
    });

    test('鮮度内なら取得しない', () {
      const fetchedAt = 1000;
      expect(
        decideEpgSync(
          meta: _meta(baseUrl: _baseUrl, fetchedAtMs: fetchedAt),
          baseUrl: _baseUrl,
          intervalHours: 6,
          nowMs: fetchedAt + 6 * _hourMs - 1,
        ),
        EpgSyncDecision.useCache,
      );
    });

    test('期限切れなら取得する', () {
      const fetchedAt = 1000;
      expect(
        decideEpgSync(
          meta: _meta(baseUrl: _baseUrl, fetchedAtMs: fetchedAt),
          baseUrl: _baseUrl,
          intervalHours: 6,
          nowMs: fetchedAt + 6 * _hourMs,
        ),
        EpgSyncDecision.fetch,
      );
    });
  });

  group('EpgSyncState.fromMeta', () {
    test('件数と取得時刻を引き継ぐ', () {
      final state = EpgSyncState.fromMeta(
        _meta(baseUrl: _baseUrl, fetchedAtMs: 1234),
      );
      expect(state.fetchedAtMs, 1234);
      expect(state.channelCount, 10);
      expect(state.programCount, 100);
    });
  });
}
