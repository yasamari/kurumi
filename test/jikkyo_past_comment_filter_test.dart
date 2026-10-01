import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_past_comment_filter.dart';

Map<String, dynamic> _chat({
  required int no,
  required int date,
  String content = 'コメント',
  String mail = '184',
  String? premium,
  String? deleted,
  int vpos = 0,
}) {
  final chat = <String, dynamic>{
    'thread': '1606417201',
    'no': '$no',
    'vpos': '$vpos',
    'date': '$date',
    'date_usec': '0',
    'user_id': 'user$no',
    'mail': mail,
    'content': content,
  };
  if (premium != null) chat['premium'] = premium;
  if (deleted != null) chat['deleted'] = deleted;
  return {'chat': chat};
}

JikkyoComment _comment({required int no, required int date}) {
  return JikkyoComment(
    threadId: '1',
    no: no,
    vpos: 0,
    postedAt: DateTime.fromMillisecondsSinceEpoch(date * 1000),
    content: 'c$no',
    userId: 'u',
    mail: '184',
  );
}

void main() {
  test('packetを投稿時刻順のコメントに変換する', () {
    final comments = parseKakologPacket([
      _chat(no: 2, date: 1606431602),
      _chat(no: 1, date: 1606431601),
    ]);

    expect(comments.map((e) => e.no).toList(), [1, 2]);
    expect(comments[0].content, 'コメント');
  });

  test('番組ID形式の thread でも取りこぼさない', () {
    // 新ニコ生時代の過去ログの thread は `lv...` 形式。数値変換で落とすと
    // ほぼ全件が消えるため、文字列のまま保持すること。
    final packet = [
      {
        'chat': {
          'thread': 'lv351438966',
          'no': '478',
          'vpos': '7376454',
          'date': '1790695773',
          'date_usec': '116429',
          'user_id': 'a:z1ryzS-JbGHJi2dS',
          'mail': '184',
          'anonymity': '1',
          'content': 'コメント',
        },
      },
    ];

    final comments = parseKakologPacket(packet);

    expect(comments.length, 1);
    expect(comments.single.threadId, 'lv351438966');
    expect(comments.single.no, 478);
  });

  test('削除済みと運営コメントを除外する', () {
    final comments = parseKakologPacket([
      _chat(no: 1, date: 1, content: '通常'),
      _chat(no: 2, date: 2, deleted: '1', content: '削除済み'),
      _chat(
        no: 3,
        date: 3,
        content: '/nicoad {"message": "広告"}',
        premium: '3',
      ),
      // premium が運営以外のコマンド付きは残す (サーバーと同規則)
      _chat(
        no: 4,
        date: 4,
        content: '/emotion happiness',
        premium: '1',
      ),
      _chat(no: 5, date: 5, content: ''),
    ]);

    expect(comments.map((e) => e.no).toList(), [1, 4]);
  });

  test('不正な要素と非リストは空にする', () {
    expect(parseKakologPacket([]), isEmpty);
    expect(parseKakologPacket(null), isEmpty);
    expect(parseKakologPacket({'packet': []}), isEmpty);
    expect(
      parseKakologPacket([
        {'chat': {'content': 'キー不足'}},
        '文字列',
        {'chat': '文字列'},
      ]),
      isEmpty,
    );
  });

  test('運営コマンド判定はサーバーと同規則', () {
    expect(
      isJikkyoOperatorComment(content: '/nicoad {}', premium: '3'),
      isTrue,
    );
    expect(
      isJikkyoOperatorComment(content: '/emotion hi', premium: '1'),
      isFalse,
    );
    expect(
      isJikkyoOperatorComment(content: '/nicoad {}', premium: null),
      isFalse,
    );
    expect(
      isJikkyoOperatorComment(content: '通常コメント', premium: '3'),
      isFalse,
    );
    expect(isJikkyoOperatorComment(content: null, premium: '3'), isFalse);
  });

  test('分割取得結果を結合し重複を除く', () {
    final merged = mergePastJikkyoComments([
      [_comment(no: 2, date: 2), _comment(no: 1, date: 1)],
      [_comment(no: 2, date: 2), _comment(no: 3, date: 3)],
    ]);

    expect(merged.map((e) => e.no).toList(), [1, 2, 3]);
  });

  test('取得範囲を上限以下に分割する', () {
    final start = DateTime(2026, 10, 1);
    final ranges = splitKakologRange(
      start: start,
      end: start.add(const Duration(days: 5)),
    );

    expect(ranges.length, 3);
    expect(ranges[0].$2.difference(ranges[0].$1), const Duration(days: 2));
    expect(ranges[2].$2.difference(ranges[2].$1), const Duration(days: 1));

    final single = splitKakologRange(
      start: start,
      end: start.add(const Duration(hours: 1)),
    );
    expect(single.length, 1);

    expect(
      splitKakologRange(start: start, end: start.subtract(const Duration(seconds: 1))),
      isEmpty,
    );
  });

  test('再生位置までの表示件数を数える', () {
    final comments = [
      _comment(no: 1, date: 100),
      _comment(no: 2, date: 200),
      _comment(no: 3, date: 300),
    ];
    final syncStart = DateTime.fromMillisecondsSinceEpoch(0);

    expect(
      countDuePastComments(
        comments: comments,
        syncStart: syncStart,
        position: const Duration(seconds: 150),
      ),
      1,
    );
    expect(
      countDuePastComments(
        comments: comments,
        syncStart: syncStart,
        position: const Duration(seconds: 300),
      ),
      3,
    );
    expect(
      countDuePastComments(
        comments: comments,
        syncStart: syncStart,
        position: Duration.zero,
      ),
      0,
    );
  });
}
