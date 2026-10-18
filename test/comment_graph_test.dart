import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment.dart';
import 'package:kurumi/src/features/player/comment_graph.dart';

void main() {
  final syncStart = DateTime.utc(2026, 1, 1, 12);

  JikkyoComment comment({required int no, required Duration offset}) {
    return JikkyoComment(
      threadId: '26985',
      no: no,
      vpos: no * 1000,
      postedAt: syncStart.add(offset),
      content: 'x',
      userId: 'client-abc',
      mail: '',
    );
  }

  group('commentBucketCounts', () {
    test('時間帯ごとの件数に集計する', () {
      final counts = commentBucketCounts(
        comments: [
          comment(no: 1, offset: Duration.zero),
          comment(no: 2, offset: const Duration(seconds: 1)),
          comment(no: 3, offset: const Duration(seconds: 3)),
        ],
        syncStart: syncStart,
        bucketSec: 2,
      );
      expect(counts, [2, 1]);
    });

    test('録画開始前 (負のオフセット) を落とす', () {
      final counts = commentBucketCounts(
        comments: [
          comment(no: 1, offset: const Duration(seconds: -5)),
          comment(no: 2, offset: const Duration(seconds: 2)),
        ],
        syncStart: syncStart,
        bucketSec: 2,
      );
      expect(counts, [0, 1]);
    });

    test('空・すべて範囲外は空', () {
      expect(
        commentBucketCounts(
          comments: const [],
          syncStart: syncStart,
          bucketSec: 2,
        ),
        isEmpty,
      );
      expect(
        commentBucketCounts(
          comments: [comment(no: 1, offset: const Duration(seconds: -1))],
          syncStart: syncStart,
          bucketSec: 2,
        ),
        isEmpty,
      );
    });
  });

  group('smoothCommentCounts', () {
    test('三角窓で山をなめらかにする', () {
      final smoothed = smoothCommentCounts([0, 0, 10, 0, 0], window: 1);
      expect(smoothed, [0, 2.5, 5, 2.5, 0]);
    });

    test('窓が0以下・空なら入力をそのまま返す', () {
      expect(smoothCommentCounts(const [], window: 2), isEmpty);
      expect(smoothCommentCounts([1, 2, 3], window: 0), [1, 2, 3]);
    });
  });

  group('normalizeCommentCounts', () {
    test('最大値で0..1に正規化する', () {
      expect(normalizeCommentCounts([2, 4, 1]), [0.5, 1.0, 0.25]);
    });

    test('空・すべて0は同じ長さの0', () {
      expect(normalizeCommentCounts(const []), isEmpty);
      expect(normalizeCommentCounts([0, 0, 0]), [0, 0, 0]);
    });
  });

  group('commentGraphVertices', () {
    test('割合に応じた描画座標にする', () {
      final vertices = commentGraphVertices(
        samples: [1, 0],
        bucketSec: 1,
        durationSec: 2,
        size: const Size(100, 10),
      );
      expect(vertices.length, 2);
      expect(vertices[0], const Offset(25, 0));
      expect(vertices[1], const Offset(75, 10));
    });

    test('再生尺・サイズが不正なら空', () {
      const size = Size(100, 10);
      expect(
        commentGraphVertices(
          samples: [1, 0],
          bucketSec: 1,
          durationSec: 0,
          size: size,
        ),
        isEmpty,
      );
      expect(
        commentGraphVertices(
          samples: [1, 0],
          bucketSec: 1,
          durationSec: 2,
          size: Size.zero,
        ),
        isEmpty,
      );
    });

    test('範囲外のサンプルは右端へクランプする', () {
      final vertices = commentGraphVertices(
        samples: [1, 1, 1],
        bucketSec: 2,
        durationSec: 2,
        size: const Size(100, 10),
      );
      // 2番目以降の時刻 (3s, 5s) は尺 (2s) を越えるため右端。
      expect(vertices[1].dx, 100);
      expect(vertices[2].dx, 100);
    });
  });

  group('commentGraphPath', () {
    test('空・1点でも例外を出さない', () {
      expect(commentGraphPath(const []).computeMetrics().isEmpty, isTrue);
      expect(
        commentGraphPath(const [Offset(1, 1)]).computeMetrics().isEmpty,
        isTrue,
      );
    });

    test('2点を直線で結ぶ', () {
      final path = commentGraphPath(const [Offset(0, 0), Offset(10, 10)]);
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('3点以上は全点を通る滑らかな曲線になる', () {
      final path = commentGraphPath(const [
        Offset(0, 0),
        Offset(5, 10),
        Offset(10, 0),
      ]);
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });
  });

  group('buildCommentGraph', () {
    test('空コメントは空のグラフ', () {
      final graph = buildCommentGraph(comments: const [], syncStart: syncStart);
      expect(graph.isEmpty, isTrue);
    });

    test('集計・平滑化・正規化を通したサンプルを作る', () {
      final graph = buildCommentGraph(
        comments: [
          comment(no: 1, offset: Duration.zero),
          comment(no: 2, offset: const Duration(milliseconds: 500)),
          comment(no: 3, offset: const Duration(seconds: 10)),
        ],
        syncStart: syncStart,
      );
      expect(graph.bucketSec, commentGraphBucketSec);
      expect(graph.samples.length, 6);
      expect(graph.samples.reduce((a, b) => a > b ? a : b), closeTo(1.0, 1e-9));
      for (final value in graph.samples) {
        expect(value, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
