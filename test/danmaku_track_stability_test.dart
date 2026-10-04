import 'dart:math';

import 'package:canvas_danmaku/danmaku_store.dart';
import 'package:canvas_danmaku/danmaku_track_assign.dart';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:canvas_danmaku/models/danmaku_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// 弾幕の行が飛行の途中で変わらないことの検証。
///
/// `DanmakuScreen` の窓管理 (出生順に読み出す cursor / 作り直しでやり直す
/// rewind / 保持期間を満了したら prune して view が作り直す) をそのまま再現し、
/// 高流量のライブ視聴を模擬する。軌道割当本体 ([admitScrollTrack]) と
/// [DanmakuStore] は本物の実装を使うので、widget を介さず純粋に検証できる。
///
/// 検証する不変条件:
/// 1. 一度画面に出た弾幕は、表示し終わるまで行を換えない。
/// 2. 後から作られた view (回転・フルスクリーン) は既存 view と同じ行になる。
///
/// 1 が壊れるのは「作り直しのたびに軌道を決め直す」ときだけ。読み直しは出生順の
/// 別の場所から始まるので逐次処理と同じ結果にならず、画面外の古い弾幕が軌道
/// を確保しているかどうかで途中の弾幕の行が変わり、それが連鎖して表示中の
/// 弾幕まで動く。
const _viewWidth = 1000.0;
const _viewHeight = 500.0;
const _danmakuHeight = 38.4;
const _durationMs = 8000.0;
const _staticDurationMs = 5000.0;
const _frameMs = 16;
const _lazyEvery = 11;
const _retentionMs = 60000;

/// `DanmakuScreen` の 1 画面分の窓管理を模したもの。
class _View {
  _View(this.store, {int? trackCount})
      : trackCount = trackCount ?? (_viewHeight / _danmakuHeight).floor();

  final DanmakuStore<int> store;
  final int trackCount;

  /// 画面に出ている弾幕 (出生順)。
  final List<DanmakuItem<int>> alive = [];

  late final ScrollTrackAllocator _tracks = _newTracks();
  int _cursorBirth = 0;
  bool _cursorsInit = false;

  ScrollTrackAllocator _newTracks() => ScrollTrackAllocator(
        trackCount: trackCount,
        viewWidth: _viewWidth,
        durationMs: _durationMs,
      );

  void _initCursors(int now) {
    _cursorBirth = (now - trackReplaySpanMs(durationMs: _durationMs)).floor() - 1;
    _cursorsInit = true;
  }

  /// 窓を作り直す。軌道そのものは弾幕が持っているので、占有だけ空に戻す。
  void rebuild(int now) {
    alive.clear();
    _tracks.rewind();
    _initCursors(now);
    advance(now);
  }

  void advance(int now) {
    if (!_cursorsInit) _initCursors(now);
    final items = store.scrollItems;
    var index = lowerBoundBirth(items, _cursorBirth + 1);
    while (index < items.length && items[index].birthTick! <= now) {
      final item = items[index];
      _cursorBirth = item.birthTick!;
      index++;
      item.ensureMeasured(24, 4, 2);
      final track = admitScrollTrack(item, _tracks, massiveMode: false);
      if (track == null) continue;
      item.yPosition = track * _danmakuHeight;
      if (!scrollDanmakuGone(
        birthTick: item.birthTick!,
        nowMs: now,
        durationMs: _durationMs,
      )) {
        alive.add(item);
      }
    }
    while (alive.isNotEmpty &&
        scrollDanmakuGone(
          birthTick: alive.first.birthTick!,
          nowMs: now,
          durationMs: _durationMs,
        )) {
      alive.removeAt(0);
    }
  }

  /// `_lazyTick` と同じ間隔で保持期間を落とし、落ちたものがあった(view が
  /// 作り直すところまで含めて)回す。
  bool lazyTick(int now) {
    final removed = store.prune(
      nowMs: now,
      durationMs: _durationMs,
      staticDurationMs: _staticDurationMs,
    );
    if (removed.isEmpty) return false;
    rebuild(now);
    return true;
  }
}

DanmakuItem<int> _danmaku(int birth, int length, int serial) => DanmakuItem<int>(
      content: DanmakuContentItem<int>('#$serial', extra: serial),
      width: length * 26.0 + 2.0,
      height: _danmakuHeight,
      birthTick: birth,
    );

void main() {
  group('弾幕の行の安定性', () {
    /// ライブを [seconds] 秒ぶん回し、飛行中に行が動いた回数を返す。
    int countRowChanges({
      required double perSecond,
      int seconds = 120,
      void Function(_View view, int now)? onTick,
    }) {
      final random = Random(7);
      final store = DanmakuStore<int>(retentionMs: _retentionMs);
      addTearDown(store.dispose);
      final view = _View(store);
      var rowChanges = 0;
      var rebuilds = 0;
      final previous = <int, int>{}; // serial -> track
      var nextArrival = 100;
      var serial = 0;
      var frame = 0;

      for (var now = _frameMs; now < seconds * 1000; now += _frameMs) {
        // 100ms ごとの束ね (`JikkyoCommentController` の flush)。
        if (now >= nextArrival) {
          nextArrival = now + 100;
          final count = max(
            1,
            (perSecond / 10).round() + (random.nextDouble() < 0.3 ? 1 : 0),
          );
          for (var i = 0; i < count; i++) {
            store.add(_danmaku(now, 1 + random.nextInt(15), serial++));
          }
        }
        view.advance(now);

        final current = <int, int>{};
        for (final item in view.alive) {
          current[item.content.extra!] = item.track!;
          final before = previous[item.content.extra!];
          if (before != null && before != item.track) rowChanges++;
        }
        previous
          ..clear()
          ..addAll(current);

        if (frame % _lazyEvery == 0 && view.lazyTick(now)) rebuilds++;
        frame++;
        onTick?.call(view, now);
      }
      // 放置されると経路を確かめられないので、再構築が最低 1 回は起きていることを要求する。
      expect(rebuilds, greaterThan(0));
      return rowChanges;
    }

    test('低流量でも表示中の行は変わらない', () {
      expect(countRowChanges(perSecond: 2), 0);
    });

    test('高流量でも表示中の行は変わらない', () {
      // 本件の回帰テスト。prune が落ちたたびに version が上がって窓が作り直される
      // (≒180ms ごと) ので、この経路で数千回の作り直しが起きている。
      expect(countRowChanges(perSecond: 100), 0);
    });

    test('後から作られた view は既存 view と同じ行になる', () {
      // 回転・フルスクリーンで新しい `DanmakuScreen` が同じ store から_window を
      // 作り直すとき、表示中の弾幕の行が既存 view と一致すること。
      final mismatches = <int>[];
      countRowChanges(
        perSecond: 100,
        seconds: 90,
        onTick: (view, now) {
          if (now % 30000 != 0) return;
          // 既存 view の行を先に控えてから (弾幕が持つ行を上書きされるため)、
          // 同じ store から新規 view を作って突き合わせる。
          final existing = {
            for (final item in view.alive) item.content.extra!: item.track!,
          };
          final fresh = _View(view.store)..advance(now);
          final freshTracks = {
            for (final item in fresh.alive) item.content.extra!: item.track!,
          };
          for (final entry in existing.entries) {
            final track = freshTracks[entry.key];
            if (track != null && track != entry.value) mismatches.add(entry.key);
          }
          expect(fresh.alive, isNotEmpty);
        },
      );
      expect(mismatches, isEmpty);
    });

    test('回転で軌道数が減っても行は保たれる', () {
      final store = DanmakuStore<int>(retentionMs: _retentionMs);
      addTearDown(store.dispose);
      final items = <DanmakuItem<int>>[
        for (var i = 0; i < 10; i++) _danmaku(i * 1500, 1 + i % 15, i),
      ];
      for (final item in items) {
        store.add(item);
      }
      _View(store, trackCount: 8).advance(14000);
      final before = [for (final item in items) item.track];
      expect(before, everyElement(isNotNull));

      // 軌道数が 4 に減った view (縦持ちなど) を作り直す。
      final narrow = _View(store, trackCount: 4)..advance(14000);
      expect(narrow.alive, isNotEmpty);
      for (var i = 0; i < items.length; i++) {
        final track = items[i].track;
        // 存在しなくなった行の弾幕だけ開き直される (軌道番号は 4 を超えない)。
        expect(track == null || track < 4, isTrue);
        // 残っている行の弾幕は行を替えない。
        if (before[i] != null && before[i]! < 4) {
          expect(track, before[i]);
        }
      }
    });
  });
}
