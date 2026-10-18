import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';

/// コメント数グラフの集計解像度 (秒)。この幅ごとに件数を数える。
const commentGraphBucketSec = 2.0;

/// 平滑化の窓 (半径。バケット数)。この前後を三角窓で平均する。
///
/// [commentGraphBucketSec] が 2 秒なので、既定は前後 10 秒を均す。窓を広げる
/// ほど山がなだらかになる ([commentGraphPath] の補間と合わせて曲線が滑らかに
/// なる)。
const commentGraphSmoothingWindow = 5;

/// グラフ帯の高さ。トラックの直上に置く。
const commentGraphHeight = 20.0;

/// コメント数の時間分布。正規化済みのサンプル列を保持する。
///
/// 中央値・件数ではなく、シークバーへ重ねる形だけに関心を絞る。値は
/// `[0, 1]` に正規化済みで、時刻は [bucketSec] 間隔の等間隔サンプルとして
/// 扱う (描画時に再生尺で `x` へ写す)。
class CommentGraph {
  const CommentGraph({required this.samples, required this.bucketSec});

  /// 正規化済みのコメント数 (`0..1`)。等間隔。
  final List<double> samples;

  /// サンプル1つの時間幅 (秒)。
  final double bucketSec;

  bool get isEmpty => samples.isEmpty;
}

/// コメントを [bucketSec] ごとの件数へ集計する純粋関数。
///
/// [syncStart] は再生位置0に対応する録画開始時刻 (弾幕の birth 換算と同じ
/// 基準)。負のオフセット (録画開始前) は落とす。戻り値の長さは最古から
/// 最新のバケットまでで、空 (すべて範囲外) なら空リスト。
List<double> commentBucketCounts({
  required List<JikkyoComment> comments,
  required DateTime syncStart,
  double bucketSec = commentGraphBucketSec,
}) {
  if (comments.isEmpty) return const [];
  if (!bucketSec.isFinite || bucketSec <= 0) return const [];
  final bucketMs = bucketSec * 1000;
  final counts = <int, int>{};
  var maxIndex = -1;
  for (final comment in comments) {
    final offsetMs = comment.postedAt.difference(syncStart).inMilliseconds;
    if (offsetMs < 0) continue;
    final index = (offsetMs / bucketMs).floor();
    counts.update(index, (value) => value + 1, ifAbsent: () => 1);
    if (index > maxIndex) maxIndex = index;
  }
  if (maxIndex < 0) return const [];
  return List<double>.generate(
    maxIndex + 1,
    (index) => (counts[index] ?? 0).toDouble(),
  );
}

/// 三角窓の移動平均で平滑化する純粋関数。
///
/// 山が尖らず、線がなめらかになるようにする。窓の端は使用した重みの和で
/// 割るため、両端の値が沈まない。空・[window] が 0 以下なら入力をそのまま
/// 返す。
List<double> smoothCommentCounts(
  List<double> counts, {
  int window = commentGraphSmoothingWindow,
}) {
  final length = counts.length;
  if (length == 0 || window <= 0) return List<double>.from(counts);
  final radius = math.min(window, length - 1);
  if (radius <= 0) return List<double>.from(counts);
  final out = List<double>.filled(length, 0);
  for (var i = 0; i < length; i++) {
    var sum = 0.0;
    var weightSum = 0.0;
    final lo = math.max(0, i - radius);
    final hi = math.min(length - 1, i + radius);
    for (var j = lo; j <= hi; j++) {
      final weight = (radius + 1 - (i - j).abs()).toDouble();
      sum += counts[j] * weight;
      weightSum += weight;
    }
    out[i] = weightSum > 0 ? sum / weightSum : 0;
  }
  return out;
}

/// 最大値で `[0, 1]` へ正規化する純粋関数。
///
/// 空・最大値が 0 以下なら同じ長さの 0 を返す。
List<double> normalizeCommentCounts(List<double> counts) {
  if (counts.isEmpty) return const [];
  var max = 0.0;
  for (final value in counts) {
    if (value > max) max = value;
  }
  if (max <= 0) return List<double>.filled(counts.length, 0);
  return [for (final value in counts) (value / max).clamp(0.0, 1.0)];
}

/// 過去コメントから表示用のグラフを作る純粋関数。
///
/// 集計 → 平滑化 → 正規化をまとめて行う。コメントが空なら空のグラフ。
CommentGraph buildCommentGraph({
  required List<JikkyoComment> comments,
  required DateTime syncStart,
  double bucketSec = commentGraphBucketSec,
  int smoothingWindow = commentGraphSmoothingWindow,
}) {
  final counts = commentBucketCounts(
    comments: comments,
    syncStart: syncStart,
    bucketSec: bucketSec,
  );
  if (counts.isEmpty) {
    return CommentGraph(samples: const [], bucketSec: bucketSec);
  }
  return CommentGraph(
    samples: normalizeCommentCounts(
      smoothCommentCounts(counts, window: smoothingWindow),
    ),
    bucketSec: bucketSec,
  );
}

/// サンプル列を描画座標の頂点列に変換する純粋関数。
///
/// `x` は `(i + 0.5) * bucketSec` を [durationSec] で割った割合、`y` は値が
/// 大きいほど上 (`size.height * (1 - value)`)。再生尺が未確定 (0以下・非有限)
/// や [size] が潰れているときは空。範囲外のサンプルは右端・上端へクランプする。
List<Offset> commentGraphVertices({
  required List<double> samples,
  required double bucketSec,
  required double durationSec,
  required Size size,
}) {
  if (samples.isEmpty) return const [];
  if (!durationSec.isFinite || durationSec <= 0) return const [];
  if (!bucketSec.isFinite || bucketSec <= 0) return const [];
  if (size.width <= 0 || size.height <= 0) return const [];
  return [
    for (var i = 0; i < samples.length; i++)
      Offset(
        ((i + 0.5) * bucketSec / durationSec).clamp(0.0, 1.0) * size.width,
        size.height * (1.0 - samples[i].clamp(0.0, 1.0)),
      ),
  ];
}

/// 頂点列をなめらかな曲線の [Path] にする純粋関数。
///
/// 全頂点を通る Catmull-Rom スプラインを三次ベジェに変換して結ぶ。各頂点での
/// 接線が隣接点と連続する (C1) ため、中点二次ベジェより曲線が滑らかで、かつ
/// 実際のサンプル点上を必ず通過する。端点は自身を複製して接線を安定させる。
Path commentGraphPath(List<Offset> vertices) {
  final path = Path();
  if (vertices.isEmpty) return path;
  path.moveTo(vertices.first.dx, vertices.first.dy);
  if (vertices.length == 1) return path;
  for (var i = 0; i < vertices.length - 1; i++) {
    final previous = i > 0 ? vertices[i - 1] : vertices[i];
    final current = vertices[i];
    final next = vertices[i + 1];
    final following = i + 2 < vertices.length ? vertices[i + 2] : next;
    final control1 = Offset(
      current.dx + (next.dx - previous.dx) / 6,
      current.dy + (next.dy - previous.dy) / 6,
    );
    final control2 = Offset(
      next.dx - (following.dx - current.dx) / 6,
      next.dy - (following.dy - current.dy) / 6,
    );
    path.cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      next.dx,
      next.dy,
    );
  }
  return path;
}

/// シークバーのトラック直上に重ねるコメント数グラフ。
///
/// 曲線を [lineColor] で描き、下側を [fillColor] の縦グラデーション (上ほど
/// 濃い) で塗る。座標計算は [commentGraphVertices] に寄せ、ここでは描画だけを
/// 行う。Catmull-Rom の補間は点によって上下へ僅かに張り出すため、描画は帯の
/// 矩形へクリップしてトラックや映像に食み出させない。
class CommentGraphPainter extends CustomPainter {
  const CommentGraphPainter({
    required this.samples,
    required this.bucketSec,
    required this.durationSec,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> samples;
  final double bucketSec;
  final double durationSec;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final vertices = commentGraphVertices(
      samples: samples,
      bucketSec: bucketSec,
      durationSec: durationSec,
      size: size,
    );
    if (vertices.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final fillPath = commentGraphPath(vertices)
      ..lineTo(vertices.last.dx, size.height)
      ..lineTo(vertices.first.dx, size.height)
      ..close();
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [
        fillColor,
        fillColor.withValues(alpha: 0),
      ]);
    canvas.drawPath(fillPath, fillPaint);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = lineColor;
    canvas.drawPath(commentGraphPath(vertices), linePaint);
  }

  @override
  bool shouldRepaint(covariant CommentGraphPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.bucketSec != bucketSec ||
        oldDelegate.durationSec != durationSec ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}
