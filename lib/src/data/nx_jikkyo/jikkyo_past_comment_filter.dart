import 'jikkyo_comment.dart';

/// kakolog API (`format=json`) の応答1件分から過去コメントを取り出す純粋関数。
///
/// - `{"packet": [...]}` の `chat` を1件ずつ [parseJikkyoChat] で解釈する
/// - 本文が空・削除済み (`deleted == '1'`) は捨てる (KonomiTVサーバーと同様)
/// - 運営コマンド付きコメントは捨てる (同上。規則は
///   [isJikkyoOperatorComment])
/// - コメント0件の空packetは空リストを返す (エラーにしない。API仕様どおり)
/// - 結果は投稿時刻順に並べ直す。`no` の単調増加は保証されないため
///   (APIドキュメント推奨どおり) 時刻でソートする
List<JikkyoComment> parseKakologPacket(Object? packet) {
  if (packet is! List) return [];
  final comments = <JikkyoComment>[];
  for (final entry in packet) {
    if (entry is! Map) continue;
    final chat = entry['chat'];
    if (chat is! Map) continue;
    final chatMap = chat.cast<String, dynamic>();
    final content = chatMap['content'];
    if (content is! String || content.isEmpty) continue;
    if (chatMap['deleted']?.toString() == '1') continue;
    if (isJikkyoOperatorComment(
      content: content,
      premium: chatMap['premium'],
    )) {
      continue;
    }
    final comment = parseJikkyoChat(chatMap);
    if (comment == null) continue;
    comments.add(comment);
  }
  comments.sort((a, b) => a.postedAt.compareTo(b.postedAt));
  return comments;
}

/// 運営コマンド付きコメントかを判定する純粋関数。
///
/// KonomiTVサーバーの `JikkyoClient.isSpecialCommandComment` と同じ規則:
/// `/nicoad ...` のような `/[a-z]` 始まりかつ `premium == '3'` (運営) の
/// ものを運営コメントとみなす。`premium` 欠落時は判定不能のため通常扱い。
bool isJikkyoOperatorComment({
  required Object? content,
  required Object? premium,
}) {
  if (content is! String) return false;
  if (!RegExp(r'^/[a-z][a-z0-9_-]*(?:\s|$)').hasMatch(content)) {
    return false;
  }
  return premium?.toString() == '3';
}

/// 分割取得した結果を結合する純粋関数。範囲境界の重複を除き投稿時刻順に
/// 並べ直す。
///
/// 同一 `(threadId, no, vpos)` は1件にまとめる。コメ番はスレッドごとに
/// 振られるためスレッドIDもキーに含める。
List<JikkyoComment> mergePastJikkyoComments(
  Iterable<List<JikkyoComment>> chunks,
) {
  final byKey = <String, JikkyoComment>{};
  for (final chunk in chunks) {
    for (final comment in chunk) {
      byKey.putIfAbsent(
        '${comment.threadId}:${comment.no}:${comment.vpos}',
        () => comment,
      );
    }
  }
  final merged = byKey.values.toList()
    ..sort((a, b) => a.postedAt.compareTo(b.postedAt));
  return merged;
}

/// 取得範囲をAPI上限 (3日) 以下に分割する純粋関数。
///
/// 上限ちょうどでは拒否されうるため、余裕を見て [maxSpan] (既定2日) で
/// 区切る。[end] が [start] より前の場合は空リストを返す。
List<(DateTime, DateTime)> splitKakologRange({
  required DateTime start,
  required DateTime end,
  Duration maxSpan = const Duration(days: 2),
}) {
  final ranges = <(DateTime, DateTime)>[];
  var cursor = start;
  while (cursor.isBefore(end)) {
    final next = cursor.add(maxSpan);
    ranges.add((cursor, next.isAfter(end) ? end : next));
    cursor = next;
  }
  return ranges;
}

/// [position] 再生時点で表示すべきコメント件数を返す純粋関数。
///
/// [syncStart] は録画開始時刻 (再生位置0に対応)。コメントは投稿時刻順で
/// あること。二分探索で求める。シーク後の emission ポインタ再計算にも使う。
int countDuePastComments({
  required List<JikkyoComment> comments,
  required DateTime syncStart,
  required Duration position,
}) {
  final threshold = syncStart.add(position);
  var lo = 0;
  var hi = comments.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (!comments[mid].postedAt.isAfter(threshold)) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
