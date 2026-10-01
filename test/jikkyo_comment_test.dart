import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment_mail.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment_session.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_endpoints.dart';

void main() {
  group('parseJikkyoChat', () {
    // NX-Jikkyo が返す最小の chat オブジェクト (premium/anonymity/yourpost は
    // 値が 0 のためキーごと欠落する)。
    final minimal = <String, dynamic>{
      'thread': '26985',
      'no': 42,
      'vpos': 1234,
      'date': 1700000000,
      'date_usec': 123456,
      'mail': '',
      'user_id': 'client-abc',
      'content': 'こんにちは',
    };

    test('最小の chat をパースできる', () {
      final comment = parseJikkyoChat(minimal);
      expect(comment, isNotNull);
      expect(comment!.threadId, '26985');
      expect(comment.no, 42);
      expect(comment.vpos, 1234);
      expect(comment.content, 'こんにちは');
      expect(comment.userId, 'client-abc');
      expect(comment.mail, '');
    });

    test('date と date_usec を合成して投稿時刻にする', () {
      final comment = parseJikkyoChat(minimal)!;
      // 1700000000秒 + 123456マイクロ秒 = 123ミリ秒
      expect(comment.postedAt.millisecondsSinceEpoch, 1700000000 * 1000 + 123);
    });

    test('anonymity 1 は匿名になる', () {
      final comment = parseJikkyoChat({...minimal, 'anonymity': 1})!;
      expect(comment.anonymity, isTrue);
      expect(comment.premium, isFalse);
      expect(comment.yourPost, isFalse);
    });

    test('yourpost 1 は自分のコメントになる', () {
      final comment = parseJikkyoChat({...minimal, 'yourpost': 1})!;
      expect(comment.yourPost, isTrue);
    });

    test('フラグが 0 のときはキーごと欠落しても false になる', () {
      // 0 のキーが存在する場合と欠落する場合で結果が変わらないこと。
      final withZero = parseJikkyoChat({
        ...minimal,
        'premium': 0,
        'anonymity': 0,
        'yourpost': 0,
      })!;
      final withoutKeys = parseJikkyoChat(minimal)!;
      expect(withZero.premium, withoutKeys.premium);
      expect(withZero.anonymity, withoutKeys.anonymity);
      expect(withZero.yourPost, withoutKeys.yourPost);
      expect(withZero.premium, isFalse);
      expect(withZero.anonymity, isFalse);
      expect(withZero.yourPost, isFalse);
    });

    test('thread が文字列で届いてもパースできる', () {
      // `no` や `date` は数値のことがあるが、`thread` は必ず文字列。
      final comment = parseJikkyoChat({...minimal, 'thread': '1'})!;
      expect(comment.threadId, '1');
    });

    test('過去ログAPIの番組ID形式の thread もパースできる', () {
      // 新ニコ生時代の過去ログは `lv351438966` のような番組ID形式で来る。
      final comment = parseJikkyoChat({
        ...minimal,
        'thread': 'lv351438966',
      })!;
      expect(comment.threadId, 'lv351438966');
    });

    test('必要なキーが欠けていれば null を返す', () {
      for (final key in [
        'thread',
        'no',
        'vpos',
        'date',
        'date_usec',
        'mail',
        'user_id',
        'content',
      ]) {
        final broken = Map<String, dynamic>.of(minimal)..remove(key);
        expect(parseJikkyoChat(broken), isNull, reason: '$key が欠けている');
      }
    });

    test('型が違う場合は null を返す', () {
      expect(parseJikkyoChat({...minimal, 'no': 'abc'}), isNull);
      expect(parseJikkyoChat({...minimal, 'content': 123}), isNull);
      expect(parseJikkyoChat({...minimal, 'user_id': null}), isNull);
    });

    test('数値が文字列で来ても読める', () {
      final comment = parseJikkyoChat({...minimal, 'no': '42'})!;
      expect(comment.no, 42);
    });
  });

  group('parseJikkyoCommentMail', () {
    test('空文字なら既定値になる', () {
      final style = parseJikkyoCommentMail('');
      expect(style.color, defaultJikkyoCommentColor);
      expect(style.size, JikkyoCommentSize.medium);
      expect(style.position, JikkyoCommentPosition.naka);
      expect(style.anonymous, isFalse);
    });

    test('184 で匿名になる', () {
      expect(parseJikkyoCommentMail('184').anonymous, isTrue);
      expect(parseJikkyoCommentMail('184 red').anonymous, isTrue);
    });

    test('色コマンドを読み取る', () {
      expect(parseJikkyoCommentMail('red').color, 'red');
      expect(parseJikkyoCommentMail('184 cyan ue big').color, 'cyan');
    });

    test('派生色 (red2) は先頭の色名に落とす', () {
      expect(parseJikkyoCommentMail('red2').color, 'red');
      expect(parseJikkyoCommentMail('blue4').color, 'blue');
    });

    test('位置コマンドを読み取る', () {
      expect(parseJikkyoCommentMail('ue').position, JikkyoCommentPosition.top);
      expect(
        parseJikkyoCommentMail('shita').position,
        JikkyoCommentPosition.bottom,
      );
      expect(
        parseJikkyoCommentMail('naka').position,
        JikkyoCommentPosition.naka,
      );
    });

    test('サイズコマンドを読み取る', () {
      expect(parseJikkyoCommentMail('small').size, JikkyoCommentSize.small);
      expect(parseJikkyoCommentMail('big').size, JikkyoCommentSize.big);
      expect(parseJikkyoCommentMail('medium').size, JikkyoCommentSize.medium);
    });

    test('フォントコマンドは無視する', () {
      final style = parseJikkyoCommentMail('defont red');
      expect(style.color, 'red');
      expect(style.size, JikkyoCommentSize.medium);
    });

    test('未知トークンは無視して既定値を維持する', () {
      final style = parseJikkyoCommentMail('??? gulim xyz9');
      expect(style.color, defaultJikkyoCommentColor);
      expect(style.size, JikkyoCommentSize.medium);
      expect(style.position, JikkyoCommentPosition.naka);
    });

    test('同じカテゴリが複数あれば最後のものが勝つ', () {
      final style = parseJikkyoCommentMail('red green small big ue shita');
      expect(style.color, 'green');
      expect(style.size, JikkyoCommentSize.big);
      expect(style.position, JikkyoCommentPosition.bottom);
    });

    test('NX-Jikkyo が組み立てる順序 (184 → 色 → 位置 → サイズ) を解釈する', () {
      final style = parseJikkyoCommentMail('184 white naka medium defont');
      expect(style.anonymous, isTrue);
      expect(style.color, 'white');
      expect(style.position, JikkyoCommentPosition.naka);
      expect(style.size, JikkyoCommentSize.medium);
    });
  });

  group('parseJikkyoCommentFrame', () {
    final chat = jsonEncode({
      'chat': {
        'thread': '26985',
        'no': 42,
        'vpos': 1234,
        'date': 1700000000,
        'date_usec': 0,
        'mail': '184',
        'user_id': 'client-abc',
        'content': 'こんにちは',
      },
    });

    test('chat は JSON オブジェクト単体のフレームで届く', () {
      // サーバーは Redis Pub/Sub の生 JSON を転送するため、配列ではなく
      // オブジェクト単体で送ってくる。配列前提で読むとライブコメントを
      // 全件落としてしまうため、ここが最重要。
      final frame = parseJikkyoCommentFrame(chat);
      expect(frame.comments, hasLength(1));
      expect(frame.comments.single.no, 42);
      // `mail` の解釈とは独立。匿名かどうかは `anonymity` キーで決まる。
      expect(frame.comments.single.anonymity, isFalse);
      expect(
        parseJikkyoCommentMail(frame.comments.single.mail).anonymous,
        isTrue,
      );
      expect(frame.subscribed, isFalse);
    });

    test('配列フレームにも対応する', () {
      final frame = parseJikkyoCommentFrame('[$chat]');
      expect(frame.comments, hasLength(1));
    });

    test('thread 応答は購読確定として扱う', () {
      final frame = parseJikkyoCommentFrame(
        jsonEncode({
          'thread': {
            'resultcode': 0,
            'thread': '26985',
            'last_res': 42,
            'ticket': '0x12345678',
            'revision': 1,
            'server_time': 1700000000,
          },
        }),
      );
      expect(frame.subscribed, isTrue);
      expect(frame.comments, isEmpty);
    });

    test('ping は無視する', () {
      final frame = parseJikkyoCommentFrame(
        jsonEncode({
          'ping': {'content': 'rf:0'},
        }),
      );
      expect(frame.comments, isEmpty);
      expect(frame.subscribed, isFalse);
    });

    test('壊れた JSON は空の結果になる', () {
      final frame = parseJikkyoCommentFrame('{not json');
      expect(frame.comments, isEmpty);
      expect(frame.subscribed, isFalse);
    });

    test('想定外の型は空の結果になる', () {
      expect(parseJikkyoCommentFrame('123').comments, isEmpty);
      expect(parseJikkyoCommentFrame('"text"').comments, isEmpty);
      expect(parseJikkyoCommentFrame('null').comments, isEmpty);
    });

    test('chat の内容が壊れていてもフレームは読み飛ばす', () {
      final frame = parseJikkyoCommentFrame(
        jsonEncode({
          'chat': {'thread': '26985'},
        }),
      );
      expect(frame.comments, isEmpty);
    });

    test('1フレームに複数の chat が混ざっていても全部取り出す', () {
      final frame = parseJikkyoCommentFrame(
        jsonEncode([
          {
            'chat': {
              'thread': '1',
              'no': 1,
              'vpos': 0,
              'date': 1,
              'date_usec': 0,
              'mail': '',
              'user_id': 'a',
              'content': 'a',
            },
          },
          {
            'ping': {'content': 'rf:0'},
          },
          {
            'chat': {
              'thread': '1',
              'no': 2,
              'vpos': 0,
              'date': 2,
              'date_usec': 0,
              'mail': '',
              'user_id': 'a',
              'content': 'b',
            },
          },
        ]),
      );
      expect(frame.comments.map((c) => c.no).toList(), [1, 2]);
    });
  });

  group('jikkyo_endpoints', () {
    test('https のベースURLは wss になる', () {
      expect(
        jikkyoWatchUri('jk1', baseUrl: 'https://example.test:5610').toString(),
        'wss://example.test:5610/api/v1/channels/jk1/ws/watch',
      );
    });

    test('http のベースURLは ws になる', () {
      expect(
        jikkyoCommentUri(
          'jk211',
          baseUrl: 'http://192.168.1.2:5610',
        ).toString(),
        'ws://192.168.1.2:5610/api/v1/channels/jk211/ws/comment',
      );
    });

    test('末尾のスラッシュは重複しない', () {
      expect(
        jikkyoWatchUri('jk1', baseUrl: 'https://example.test/').toString(),
        'wss://example.test/api/v1/channels/jk1/ws/watch',
      );
    });
  });
}
