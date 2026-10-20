import 'dart:math' show max;
import 'dart:ui' show Color;

import '../../core/utils/time_format.dart';
import '../../domain/entities/channel_type.dart';
import '../../domain/entities/timetable.dart';
import '../../domain/entities/tv_program.dart';

// 番組表グリッドの寸法・座標・日付計算の純粋関数群。
//
// 描画はすべてこの値から組み立てる。ウィジェット側で時刻計算をしないこと。

/// 1分あたりの論理ピクセル。1時間=180px、24時間=4320px。
const double timetablePxPerMin = 3.0;

/// 番組表1日分の長さ (放送日は4時始まりの24時間)。
const int timetableDayLengthMs = 24 * 3600 * 1000;

/// 放送日の開始時刻 (JSTの壁時計)。
const int timetableDayStartHour = 4;

/// チャンネル1列の幅。
const double timetableColumnWidth = 168;

/// 時刻ガターの幅。
const double timetableGutterWidth = 48;

/// チャンネルヘッダーの高さ。
const double timetableHeaderHeight = 68;

/// セル間の余白 (縦・横)。
const double timetableCellGap = 2;

/// `nowMs` を含む放送日 (JST 4時始まり) の開始時刻 (ms epoch) を返す。
int timetableDayStartMs(int nowMs) {
  final jst = toJst(DateTime.fromMillisecondsSinceEpoch(nowMs));
  var dayStart = DateTime.utc(
    jst.year,
    jst.month,
    jst.day,
    timetableDayStartHour - 9,
  );
  if (jst.hour < timetableDayStartHour) {
    dayStart = dayStart.subtract(const Duration(hours: 24));
  }
  return dayStart.millisecondsSinceEpoch;
}

/// 基準日から `dayOffset` 日ずらした放送日の開始時刻 (ms epoch) を返す。
int timetableDayStartMsForOffset(int baseDayStartMs, int dayOffset) {
  return baseDayStartMs + dayOffset * timetableDayLengthMs;
}

/// 放送日の表示ラベル (`10/9（木）` 形式、JST) を返す。
String formatTimetableDay(int dayStartMs) {
  const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
  final jst = toJst(DateTime.fromMillisecondsSinceEpoch(dayStartMs));
  return '${jst.month}/${jst.day}（${weekdays[jst.weekday % 7]}）';
}

/// 放送日の短い表示ラベル (`10/9` 形式、JST) を返す。
///
/// 狭幅ツールバー用。
String formatTimetableDayShort(int dayStartMs) {
  final jst = toJst(DateTime.fromMillisecondsSinceEpoch(dayStartMs));
  return '${jst.month}/${jst.day}';
}

/// 放送日の開始時刻から基準日との日オフセットを求める。
///
/// 日付ピッカーで選んだ日の放送日開始時刻から `_dayOffset` への戻しに使う。
int timetableDayOffsetForDayStart({
  required int baseDayStartMs,
  required int targetDayStartMs,
}) {
  return ((targetDayStartMs - baseDayStartMs) / timetableDayLengthMs).round();
}

/// 放送日内の毎正時 (ms epoch) を日開始順に24件返す。
///
/// 時刻メニューの選択肢に使う。放送日は4時始まりのため、先頭は4時になる。
List<int> timetableDayHoursMs(int dayStartMs) {
  return [for (var i = 0; i < 24; i++) dayStartMs + i * 3600 * 1000];
}

/// 縦オフセット (px) の指す先頭時刻 (ms epoch) を返す。
///
/// グリッド上端に見えている時刻で、時刻ボタンの表示に使う。
/// [offsetPx] は縦スクロールの共有オフセット。範囲外は
/// `[dayStartMs, dayEndMs - 1]` に丸める。
int timetableTopVisibleTimeMs({
  required double offsetPx,
  required int dayStartMs,
  required int dayEndMs,
}) {
  final clampedOffset = offsetPx < 0 ? 0.0 : offsetPx;
  final timeMs =
      dayStartMs + (clampedOffset / timetablePxPerMin * 60000).round();
  if (timeMs < dayStartMs) return dayStartMs;
  if (timeMs >= dayEndMs) return dayEndMs - 1;
  return timeMs;
}

/// 縦オフセット (px) の指す先頭時刻を含む正時の開始時刻 (ms epoch) を返す。
///
/// 時刻ボタンは正時単位 (`4時` 形式) で表示するため、スクロール中は
/// 時間が変わったときだけ値が変わる。
int timetableVisibleHourMs({
  required double offsetPx,
  required int dayStartMs,
  required int dayEndMs,
}) {
  return timetableHourStartMs(
    timeMs: timetableTopVisibleTimeMs(
      offsetPx: offsetPx,
      dayStartMs: dayStartMs,
      dayEndMs: dayEndMs,
    ),
    dayStartMs: dayStartMs,
  );
}

/// [timeMs] を含む正時の開始時刻 (ms epoch) を返す。
///
/// 放送日は4時始まりのため、`dayStartMs` からの時間数で区切る
/// (JSTの正時に一致する)。範囲外は両端に丸める。
int timetableHourStartMs({required int timeMs, required int dayStartMs}) {
  if (timeMs <= dayStartMs) return dayStartMs;
  final dayEndMs = dayStartMs + timetableDayLengthMs;
  if (timeMs >= dayEndMs) return dayEndMs - 3600 * 1000;
  final elapsed = timeMs - dayStartMs;
  return dayStartMs + (elapsed ~/ (3600 * 1000)) * (3600 * 1000);
}

/// 時刻の表示ラベル (`4時` 形式、JST) を返す。
String formatTimetableHour(int timeMs) {
  final jst = toJst(DateTime.fromMillisecondsSinceEpoch(timeMs));
  return '${jst.hour}時';
}

/// 指定時刻へジャンプするときの縦オフセット(px)を返す。
///
/// 対象時刻が上から1/4の位置に来るようにし、両端でクランプする。初回表示の
/// 現在時刻ジャンプと、時刻メニュー・現在ボタンからのジャンプで共有する。
double timetableJumpTargetPx({
  required int timeMs,
  required int dayStartMs,
  required double viewportHeightPx,
  required double gridHeightPx,
}) {
  final target =
      timetableOffsetPx(timeMs, dayStartMs) - viewportHeightPx * 0.25;
  return target
      .clamp(0.0, max(0.0, gridHeightPx - viewportHeightPx))
      .toDouble();
}

/// 指定日が今日の放送日かどうか。
bool isTimetableToday(int dayStartMs, int nowMs) {
  return dayStartMs == timetableDayStartMs(nowMs);
}

/// 日開始からの経過msを縦オフセット(px)に変換する。
double timetableOffsetPx(int timeMs, int dayStartMs) {
  return (timeMs - dayStartMs) / 60000 * timetablePxPerMin;
}

/// 期間の縦幅(px)を返す。
double timetableHeightPx(int startMs, int endMs) {
  return (endMs - startMs) / 60000 * timetablePxPerMin;
}

/// 番組の表示範囲を `[rangeStartMs, rangeEndMs)` で切り詰める。
///
/// 重ならない場合は null。
({int startMs, int endMs})? clampProgramToRange({
  required int startMs,
  required int endMs,
  required int rangeStartMs,
  required int rangeEndMs,
}) {
  if (endMs <= rangeStartMs || startMs >= rangeEndMs) return null;
  return (
    startMs: startMs < rangeStartMs ? rangeStartMs : startMs,
    endMs: endMs > rangeEndMs ? rangeEndMs : endMs,
  );
}

/// 番組セルの上端オフセット(px)。範囲外の番組は範囲端に寄せる。
double timetableProgramTopPx({
  required int startMs,
  required int endMs,
  required int rangeStartMs,
  required int rangeEndMs,
}) {
  final clamped = clampProgramToRange(
    startMs: startMs,
    endMs: endMs,
    rangeStartMs: rangeStartMs,
    rangeEndMs: rangeEndMs,
  );
  final topMs = clamped?.startMs ?? rangeStartMs;
  return timetableOffsetPx(topMs, rangeStartMs);
}

/// 番組セルの高さ(px)。範囲外の番組は0。
double timetableProgramHeightPx({
  required int startMs,
  required int endMs,
  required int rangeStartMs,
  required int rangeEndMs,
}) {
  final clamped = clampProgramToRange(
    startMs: startMs,
    endMs: endMs,
    rangeStartMs: rangeStartMs,
    rangeEndMs: rangeEndMs,
  );
  if (clamped == null) return 0;
  return timetableHeightPx(clamped.startMs, clamped.endMs);
}

/// ドラッグ量から次のスクロールオフセットを求める。
///
/// [delta] は画面上の指の移動方向 (下・右が正)。内容は指に逆らって動くので
/// 符号を反転し、両端でクランプする。[maxOffset] が 0 以下 (内容が
/// ビューポートより短い) では 0 を返す。
///
/// 斜めスクロールでは縦横2軸が同じドラッグ量を別々に受け取るため、軸ごとの
/// クランプはこの純関数で行う (すべての列の高さが揃っていることが前提)。
double timetableDragOffset({
  required double offset,
  required double maxOffset,
  required double delta,
}) {
  if (maxOffset <= 0) return 0;
  return (offset - delta).clamp(0.0, maxOffset).toDouble();
}

/// 範囲内の時境界 (JSTの毎正時) の一覧 (ms epoch) を返す。
///
/// ガターの時刻ラベルと横罫線の位置決めに使う。
List<int> timetableHourMarksMs(int rangeStartMs, int rangeEndMs) {
  final startJst = toJst(DateTime.fromMillisecondsSinceEpoch(rangeStartMs));
  var mark = DateTime.utc(
    startJst.year,
    startJst.month,
    startJst.day,
    startJst.hour - 9,
  );
  if (mark.millisecondsSinceEpoch <= rangeStartMs) {
    mark = mark.add(const Duration(hours: 1));
  }
  final marks = <int>[];
  while (mark.millisecondsSinceEpoch <= rangeEndMs) {
    marks.add(mark.millisecondsSinceEpoch);
    mark = mark.add(const Duration(hours: 1));
  }
  return marks;
}

/// 次の番組境界 (ms epoch) を返す。未来の境界がなければ null。
///
/// 番組の開始・終了のうち現在より未来で最も早いもの。表示データの
/// 作り直し (invalidate) 時刻の決定に使う。
int? nextTimetableTickMs({
  required List<TimetableChannel> columns,
  required int nowMs,
}) {
  int? tickMs;
  for (final column in columns) {
    for (final program in column.programs) {
      for (final candidate in [
        program.startAt.millisecondsSinceEpoch,
        program.endAt.millisecondsSinceEpoch,
      ]) {
        if (candidate > nowMs && (tickMs == null || candidate < tickMs)) {
          tickMs = candidate;
        }
      }
    }
  }
  return tickMs;
}

/// 指定種別の列だけを抜き出す。
List<TimetableChannel> timetableColumnsOfType(
  List<TimetableChannel> columns,
  ChannelType type,
) {
  return [
    for (final column in columns)
      if (column.channel.channelType == type) column,
  ];
}

/// ジャンルラベル列から大分類名を取り出す。
///
/// KonomiTV (`ニュース／報道`) と Mirakurun (`ニュース・報道`) の区切り文字の
/// 違いを吸収する。ジャンルが無ければ空文字。
String timetableGenreMajor(List<String> genres) {
  if (genres.isEmpty) return '';
  final label = genres.first;
  final index = label.indexOf(_genreSeparator);
  return index < 0 ? label : label.substring(0, index);
}

/// ジャンル文字列の大分類との区切り (`ニュース／報道` の `／` など)。
///
/// セルごとに `RegExp` を作るとスクロール中の新規セル構築で無駄な
/// コンパイルが走るため、1つを使い回す。
final _genreSeparator = RegExp('[／・/・]');

/// ジャンル大分類ごとのシード色。セルのアクセントバーと背景ティントに使う。
Color timetableGenreSeedColor(String major) {
  return _timetableGenreSeedColors[major] ?? const Color(0xFF9E9E9E);
}

const _timetableGenreSeedColors = <String, Color>{
  'ニュース': Color(0xFFEF5350),
  'スポーツ': Color(0xFF66BB6A),
  '情報': Color(0xFFFFCA28),
  'ドラマ': Color(0xFFEC407A),
  '音楽': Color(0xFFAB47BC),
  'バラエティ': Color(0xFFFFA726),
  '映画': Color(0xFF5C6BC0),
  'アニメ': Color(0xFF26C6DA),
  'ドキュメンタリー': Color(0xFF9CCC65),
  '劇場': Color(0xFF8D6E63),
  '趣味': Color(0xFF26A69A),
  '福祉': Color(0xFF78909C),
  '拡張': Color(0xFFBDBDBD),
  'その他': Color(0xFFBDBDBD),
};

/// セル用の短い時刻表示 (`10:05-10:55` 形式、JST) を返す。
String formatTimetableCellTime(DateTime startAt, DateTime endAt) {
  final start = toJst(startAt);
  final end = toJst(endAt);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${start.hour}:${two(start.minute)}-'
      '${end.hour}:${two(end.minute)}';
}

/// 番組表の列1本分の表示セグメント。番組ブロック (`program` あり) と
/// 番組のない時間の空白 (`program` なし) の並び。
typedef TimetableColumnSegment = ({
  double topPx,
  double heightPx,
  TvProgram? program,
});

/// 列1本分のセグメント列を作る。
///
/// 番組のない時間帯は空白で埋め、全列がちょうど `gridHeightPx` になる。
/// 列の高さが揃っていないと、列ごとのスクロールオフセットが同じ時刻を
/// 指さなくなり、短い列に触れた瞬間に他の列が引き戻される。番組同士が
/// 重なるデータ不備では先行番組を優先し、はみ出しを切り詰める
/// (二重計上すると合計が全体高さを超えるため)。範囲外の番組は落とす。
List<TimetableColumnSegment> timetableColumnSegments({
  required List<TvProgram> programs,
  required int rangeStartMs,
  required int rangeEndMs,
  required double gridHeightPx,
}) {
  final sorted = [...programs]..sort((a, b) => a.startAt.compareTo(b.startAt));
  final segments = <TimetableColumnSegment>[];
  var cursor = 0.0;
  for (final program in sorted) {
    final startMs = program.startAt.millisecondsSinceEpoch;
    final endMs = program.endAt.millisecondsSinceEpoch;
    final top = timetableProgramTopPx(
      startMs: startMs,
      endMs: endMs,
      rangeStartMs: rangeStartMs,
      rangeEndMs: rangeEndMs,
    );
    final height = timetableProgramHeightPx(
      startMs: startMs,
      endMs: endMs,
      rangeStartMs: rangeStartMs,
      rangeEndMs: rangeEndMs,
    );
    if (height <= 0) continue;
    // 重なりは先行番組を優先し、はみ出しを切り詰める。二重計上すると
    // 合計が全体高さを超え、列の高さ不揃いが再発するため。
    final clippedTop = max(top, cursor);
    if (clippedTop > cursor) {
      segments.add((
        topPx: cursor,
        heightPx: clippedTop - cursor,
        program: null,
      ));
    }
    final bottom = max(top + height, clippedTop);
    if (bottom > clippedTop) {
      segments.add((
        topPx: clippedTop,
        heightPx: bottom - clippedTop,
        program: program,
      ));
    }
    cursor = bottom;
  }
  if (cursor < gridHeightPx) {
    segments.add((
      topPx: cursor,
      heightPx: gridHeightPx - cursor,
      program: null,
    ));
  }
  return segments;
}

/// セグメント列のうち表示窓に入る添字の半開区間 `[first, last)` を返す。
///
/// 窓は可視範囲 (`[offsetPx, offsetPx + viewportHeightPx)`) の前後に
/// [cacheExtentPx] の余白を足したもの。列の描画は窓内のセルだけを構築し、
/// スクロール中は平行移動だけで済ませる (窓がずれたときだけ出入りする)。
/// 窓は連続スクロールで1件ずつずれるため、構築のやり直しは最小になる。
({int first, int last}) timetableSegmentWindow({
  required List<TimetableColumnSegment> segments,
  required double offsetPx,
  required double viewportHeightPx,
  required double cacheExtentPx,
}) {
  if (segments.isEmpty) return (first: 0, last: 0);
  final top = offsetPx - cacheExtentPx;
  final bottom = offsetPx + viewportHeightPx + cacheExtentPx;
  // 下端が窓の上端を超える最初のセグメント (二分探索)。セグメントは
  // 上から順に隙間なく並んでいるため、添字がそのまま表示順になる。
  var lo = 0;
  var hi = segments.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (segments[mid].topPx + segments[mid].heightPx <= top) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  final first = lo < segments.length ? lo : segments.length - 1;
  var last = first;
  while (last < segments.length && segments[last].topPx < bottom) {
    last++;
  }
  return (first: first, last: last);
}

/// セル高さから文章表示の要否を決める。この高さ以上では省略記号付きの
/// 通常表示になり、未満では切り詰め表示 (見切れ上等) になる。
bool timetableCellShowsText(double heightPx) => heightPx >= 36;

/// 縦位置 [yPx] を含むセグメントの添字を返す。範囲外は null。
///
/// セグメントは上から隙間なく並んでいる。境界は次のセグメントに属する
/// (半開区間 `[top, top + height)`)。列のタップ位置から番組を引くのに使う。
int? timetableSegmentIndexAt({
  required List<TimetableColumnSegment> segments,
  required double yPx,
}) {
  if (segments.isEmpty || yPx < 0) return null;
  if (yPx >= segments.last.topPx + segments.last.heightPx) return null;
  var lo = 0;
  var hi = segments.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final segment = segments[mid];
    final bottom = segment.topPx + segment.heightPx;
    if (yPx < segment.topPx) {
      hi = mid - 1;
    } else if (yPx >= bottom) {
      lo = mid + 1;
    } else {
      return mid;
    }
  }
  return null;
}
