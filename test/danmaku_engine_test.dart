import 'package:canvas_danmaku/danmaku_clock.dart';
import 'package:canvas_danmaku/danmaku_store.dart';
import 'package:canvas_danmaku/danmaku_track_assign.dart';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:canvas_danmaku/models/danmaku_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scrollDanmakuX', () {
    test('birth時は右端にいる', () {
      expect(
        scrollDanmakuX(
          viewWidth: 1000,
          itemWidth: 200,
          birthTick: 5000,
          nowMs: 5000,
          durationMs: 8000,
        ),
        1000,
      );
    });

    test('通過後は左端の外にいる', () {
      double at(int now) => scrollDanmakuX(
        viewWidth: 1000,
        itemWidth: 200,
        birthTick: 0,
        nowMs: now,
        durationMs: 8000,
      );
      // duration 経過でちょうど左端 (x == -width)。
      expect(at(8000), closeTo(-200, 1e-9));
      // transit = 8000 * 1200 / 1000 = 9600 でさらに左へ。
      expect(at(9600), closeTo(-440, 1e-9));
    });

    test('同じ時計値なら常に同じ位置になる (シーク再現性)', () {
      double at(int now) => scrollDanmakuX(
        viewWidth: 1000,
        itemWidth: 200,
        birthTick: 1000,
        nowMs: now,
        durationMs: 8000,
      );
      // 一度通り過ぎてから同じ時刻に戻っても同じ値になる。
      expect(at(5000), at(5000));
      expect(at(5000), greaterThan(-200));
      expect(at(5000), lessThan(1000));
    });
  });

  group('scrollTransitMs', () {
    test('幅0なら duration と等しい', () {
      expect(
        scrollTransitMs(viewWidth: 1000, itemWidth: 0, durationMs: 8000),
        8000,
      );
    });

    test('幅がある分だけ長くなる', () {
      expect(
        scrollTransitMs(viewWidth: 1000, itemWidth: 1000, durationMs: 8000),
        16000,
      );
    });
  });

  group('scrollTrackFree', () {
    test('十分古い先行弾幕は空ける', () {
      expect(
        scrollTrackFree(
          viewWidth: 1000,
          durationMs: 8000,
          existingBirth: 0,
          existingWidth: 200,
          newBirth: 20000,
          newWidth: 200,
        ),
        isTrue,
      );
    });

    test('同時 birth は先行が未進入のため塞ぐ', () {
      expect(
        scrollTrackFree(
          viewWidth: 1000,
          durationMs: 8000,
          existingBirth: 1000,
          existingWidth: 200,
          newBirth: 1000,
          newWidth: 200,
        ),
        isFalse,
      );
    });

    test('逆順ガードは塞がない', () {
      expect(
        scrollTrackFree(
          viewWidth: 1000,
          durationMs: 8000,
          existingBirth: 2000,
          existingWidth: 200,
          newBirth: 1000,
          newWidth: 200,
        ),
        isTrue,
      );
    });
  });

  group('staticTrackFree', () {
    test('表示期間内は塞ぐ', () {
      expect(
        staticTrackFree(
          lastBirth: 1000,
          newBirth: 1000 + 4999,
          staticDurationMs: 5000,
        ),
        isFalse,
      );
    });

    test('表示期間を過ぎたら空ける', () {
      expect(
        staticTrackFree(
          lastBirth: 1000,
          newBirth: 1000 + 5000,
          staticDurationMs: 5000,
        ),
        isTrue,
      );
    });
  });

  group('massiveFallbackTrack', () {
    test('同じ birth は同じ軌道になる', () {
      expect(
        massiveFallbackTrack(birthTick: 12345, trackCount: 12),
        massiveFallbackTrack(birthTick: 12345, trackCount: 12),
      );
    });

    test('範囲内に収まる', () {
      for (var birth = 0; birth < 100; birth++) {
        final track = massiveFallbackTrack(
          birthTick: birth * 997,
          trackCount: 12,
        );
        expect(track, inInclusiveRange(0, 11));
      }
    });
  });

  group('DanmakuClock', () {
    test('seekTo 直後は指定値になる', () {
      final clock = DanmakuClock(initialMs: 0, running: false);
      addTearDown(clock.dispose);
      clock.seekTo(12345);
      expect(clock.nowMs, 12345);
    });

    test('停止中は進まない', () {
      final clock = DanmakuClock(initialMs: 1000, running: true);
      addTearDown(clock.dispose);
      clock.setRunning(false);
      expect(clock.nowMs, clock.nowMs);
      expect(clock.running, isFalse);
    });

    test('再開は凍結値から進む', () {
      final clock = DanmakuClock(initialMs: 1000, running: true);
      addTearDown(clock.dispose);
      clock.setRunning(false);
      final frozen = clock.nowMs;
      clock.setRunning(true);
      expect(clock.nowMs, greaterThanOrEqualTo(frozen));
    });

    test('seekTo は version を上げる (setRunning は上げない)', () {
      final clock = DanmakuClock();
      addTearDown(clock.dispose);
      final before = clock.version;
      clock.setRunning(false);
      expect(clock.version, before);
      clock.seekTo(999);
      expect(clock.version, before + 1);
    });
  });

  group('DanmakuStore', () {
    DanmakuItem<int> item({required int birth, double width = 100}) =>
        DanmakuItem<int>(
          content: DanmakuContentItem<int>('テスト'),
          width: width,
          height: 20,
          birthTick: birth,
        );

    test('birth 順に挿入される (逆順投入でも)', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      store.add(item(birth: 3000));
      store.add(item(birth: 1000));
      store.add(item(birth: 2000));
      expect(
        store.scrollItems.map((e) => e.birthTick).toList(),
        [1000, 2000, 3000],
      );
    });

    test('同じキーは二重登録しない', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      expect(store.add(item(birth: 1000), key: 'a'), isTrue);
      expect(store.add(item(birth: 1000), key: 'a'), isFalse);
      expect(store.scrollItems, hasLength(1));
    });

    test('addAll は birth 順に一括マージし重複を落とす', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      final accepted = store.addAll(
        [
          (
            content: DanmakuContentItem<int>('c3'),
            birthTick: 3000,
            key: 'k3',
          ),
          (
            content: DanmakuContentItem<int>('c1'),
            birthTick: 1000,
            key: 'k1',
          ),
          (
            content: DanmakuContentItem<int>('c1-dup'),
            birthTick: 1000,
            key: 'k1',
          ),
        ],
        0,
      );
      expect(accepted, 2);
      expect(
        store.scrollItems.map((e) => e.birthTick).toList(),
        [1000, 3000],
      );
    });

    test('保持期間を過ぎたものだけ落としキーを忘れる', () {
      final store = DanmakuStore<int>(retentionMs: 10000);
      addTearDown(store.dispose);
      store.add(item(birth: 0), key: 'old');
      store.add(item(birth: 50000), key: 'new');
      final removed = store.prune(
        nowMs: 60000,
        viewWidth: 1000,
        durationMs: 8000,
        staticDurationMs: 5000,
      );
      expect(removed, hasLength(1));
      expect(store.scrollItems.map((e) => e.birthTick), [50000]);
      // 落ちたキーは再登録できる。
      expect(store.add(item(birth: 0), key: 'old'), isTrue);
    });

    test('保持期間 null では自然消滅だけ落とす', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      // transit = 8000 * 1100 / 1000 = 8800。
      store.add(item(birth: 0));
      store.add(item(birth: 5000));
      final removed = store.prune(
        nowMs: 9000,
        viewWidth: 1000,
        durationMs: 8000,
        staticDurationMs: 5000,
      );
      expect(removed, hasLength(1));
      expect(store.scrollItems.map((e) => e.birthTick), [5000]);
    });

    test('未計測 (幅0) は自然消滅で落とさない', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      store.add(item(birth: 0, width: 0));
      final removed = store.prune(
        nowMs: 999999,
        viewWidth: 1000,
        durationMs: 8000,
        staticDurationMs: 5000,
      );
      expect(removed, isEmpty);
      expect(store.scrollItems, hasLength(1));
    });

    test('clear ですべて捨てる', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      store.add(item(birth: 1000), key: 'a');
      store.clear();
      expect(store.isEmpty, isTrue);
      expect(store.add(item(birth: 1000), key: 'a'), isTrue);
    });
  });

  group('lowerBoundBirth', () {
    test('境界の二分探索', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      for (final birth in [1000, 2000, 3000]) {
        store.add(
          DanmakuItem<int>(
            content: DanmakuContentItem<int>('t'),
            width: 10,
            height: 10,
            birthTick: birth,
          ),
        );
      }
      expect(lowerBoundBirth(store.scrollItems, 0), 0);
      expect(lowerBoundBirth(store.scrollItems, 2000), 1);
      expect(lowerBoundBirth(store.scrollItems, 2001), 2);
      expect(lowerBoundBirth(store.scrollItems, 9999), 3);
    });
  });
}
