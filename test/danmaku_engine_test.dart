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

  group('scrollDanmakuGone', () {
    test('duration 経過で画面を完全退出する', () {
      bool goneAt(int now) => scrollDanmakuGone(
        birthTick: 1000,
        nowMs: now,
        durationMs: 8000,
      );
      expect(goneAt(8999), isFalse);
      expect(goneAt(9000), isTrue);
      expect(goneAt(12000), isTrue);
    });

    test('幅に依存しない (画面から出る時刻は duration ちょうど)', () {
      // 幅の違う弾幕は速く流れるが、退出時刻は変わらない。
      // (幅で退出時刻を変えると、消滅順が出生順とズレて行が入れ替わる)
      for (final width in [0.0, 26.0, 300.0, 1000.0]) {
        expect(
          scrollDanmakuX(
            viewWidth: 1000,
            itemWidth: width,
            birthTick: 0,
            nowMs: 8000,
            durationMs: 8000,
          ),
          closeTo(-width, 1e-9),
        );
        expect(
          scrollDanmakuGone(birthTick: 0, nowMs: 8000, durationMs: 8000),
          isTrue,
        );
      }
    });
  });

  group('trackReplaySpanMs', () {
    test('duration の 2 倍 (塞ぎうる先行弾幕を全て含む)', () {
      expect(trackReplaySpanMs(durationMs: 8000), 16000);
      expect(trackReplaySpanMs(durationMs: 5000), 10000);
    });
  });

  group('ScrollTrackAllocator', () {
    const viewWidth = 1000.0;
    const durationMs = 8000.0;

    ScrollTrackAllocator newAllocator({int trackCount = 6}) =>
        ScrollTrackAllocator(
          trackCount: trackCount,
          viewWidth: viewWidth,
          durationMs: durationMs,
        );

    DanmakuItem<int> danmaku(int birth, double width, int serial) =>
        DanmakuItem<int>(
          content: DanmakuContentItem<int>('#$serial', extra: serial),
          width: width,
          height: 38.4,
          birthTick: birth,
        );

    test('空いていれば先頭軌道を使う', () {
      expect(newAllocator().take(birthTick: 0, width: 100), 0);
    });

    test('塞がれている軌道は飛ばして次を使う', () {
      final allocator = newAllocator()..occupy(0, birthTick: 0, width: 400);
      expect(allocator.take(birthTick: 100, width: 100), 1);
    });

    test('全軌道が埋まれば null (弾幕を捨てる)', () {
      final allocator = newAllocator(trackCount: 2)
        ..occupy(0, birthTick: 0, width: 400)
        ..occupy(1, birthTick: 0, width: 400);
      expect(allocator.take(birthTick: 100, width: 100), isNull);
    });

    test('duration 以上前の先行弾幕は塞がない', () {
      final allocator = newAllocator(trackCount: 2)
        ..occupy(0, birthTick: 0, width: 400)
        ..occupy(1, birthTick: 0, width: 400);
      expect(allocator.take(birthTick: 8000, width: 100), 0);
    });

    test('massiveMode は空き軌道に関係なく軌道を決める', () {
      final allocator = newAllocator(trackCount: 3)
        ..occupy(0, birthTick: 0, width: 400)
        ..occupy(1, birthTick: 0, width: 400)
        ..occupy(2, birthTick: 0, width: 400);
      expect(allocator.take(birthTick: 100, width: 100), isNull);
      expect(
        allocator.take(birthTick: 100, width: 100, massiveFallback: true),
        massiveFallbackTrack(birthTick: 100, trackCount: 3),
      );
    });

    test('rewind は占有だけ空にする', () {
      final allocator = newAllocator()..occupy(0, birthTick: 0, width: 400);
      allocator.rewind();
      expect(allocator.take(birthTick: 100, width: 100), 0);
    });

    test('記録された軌道は二度と変わらない (admitScrollTrack)', () {
      // 「消える少し前」の回帰: 幅の違う 2 本が 500ms 差で出生する配置。1 本目
      // (幅 26) がまだ右端付近なので 2 本目 (幅 300) はその軌道へ追いつくため
      // 下段へ落ちる。作り直しで 1 本目が画面外になっても 2 本目は動かない。
      final narrow = danmaku(0, 26, 0);
      final wide = danmaku(500, 300, 1);
      final tracks = newAllocator();
      expect(admitScrollTrack(narrow, tracks, massiveMode: false), 0);
      expect(admitScrollTrack(wide, tracks, massiveMode: false), 1);

      // 作り直し (回転 / フルスクリーン / prune) を模す。
      tracks.rewind();
      final rebuilt = newAllocator();
      expect(admitScrollTrack(narrow, rebuilt, massiveMode: false), 0);
      expect(admitScrollTrack(wide, rebuilt, massiveMode: false), 1);
      expect(narrow.track, 0);
      expect(wide.track, 1);
    });

    test('軌道数が減って範囲外になった記録だけ開き直す', () {
      final wide = danmaku(0, 26, 0);
      final narrow = newAllocator(trackCount: 4);
      expect(admitScrollTrack(wide, narrow, massiveMode: false), 0);

      // 縦持ちで軌道数が 1 になった view が見ても、範囲外ではない行は保たれる。
      final oneTrack = newAllocator(trackCount: 1);
      expect(admitScrollTrack(wide, oneTrack, massiveMode: false), 0);

      // 4 軌道のままなら記録どおり。
      final same = newAllocator(trackCount: 4);
      expect(admitScrollTrack(wide, same, massiveMode: false), 0);
      expect(wide.track, 0);
    });

    test('静的弾幕も記録された軌道を使い続ける', () {
      final tracks = StaticTrackAllocator(trackCount: 4, staticDurationMs: 5000);
      final first = danmaku(0, 100, 0);
      final second = danmaku(100, 100, 1);
      expect(admitStaticTrack(first, tracks), 0);
      // 表示期間 (< 5000ms) なので次の弾幕は同じ軌道に乗れない。
      expect(admitStaticTrack(second, tracks), 1);

      tracks.rewind();
      final rebuilt = StaticTrackAllocator(trackCount: 4, staticDurationMs: 5000);
      expect(admitStaticTrack(first, rebuilt), 0);
      expect(admitStaticTrack(second, rebuilt), 1);
    });

    test('静的弾幕は minTrack を下回らない', () {
      final tracks = StaticTrackAllocator(trackCount: 6, staticDurationMs: 5000);
      final item = danmaku(0, 100, 0);
      expect(admitStaticTrack(item, tracks, minTrack: 2), 2);
      expect(item.track, 2);
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
      // 自然消滅は birth + duration (= 8000) で判定する (幅には依存しない)。
      store.add(item(birth: 0));
      store.add(item(birth: 5000));
      final removed = store.prune(
        nowMs: 9000,
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

    test('resetTracks は記録された軌道だけを捨てる', () {
      final store = DanmakuStore<int>();
      addTearDown(store.dispose);
      final scroll = item(birth: 1000);
      final top = DanmakuItem<int>(
        content: DanmakuContentItem<int>(
          '上',
          type: DanmakuItemType.top,
        ),
        width: 50,
        height: 20,
        birthTick: 1000,
      );
      store.add(scroll);
      store.add(top);
      scroll.track = 3;
      top.track = 1;
      store.resetTracks();
      expect(scroll.track, isNull);
      expect(top.track, isNull);
      // 項目自体は残る (保持期間を捨てるのとは別)。
      expect(store.scrollItems, hasLength(1));
      expect(store.staticItems, hasLength(1));
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
