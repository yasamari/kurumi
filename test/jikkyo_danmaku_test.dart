import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment_list.dart';
import 'package:kurumi/src/data/nx_jikkyo/jikkyo_comment_mail.dart';
import 'package:kurumi/src/features/player/jikkyo_danmaku_item.dart';

void main() {
  final base = DateTime.utc(2026, 9, 30, 12);

  JikkyoComment comment({required int no, String mail = ''}) => JikkyoComment(
    threadId: '26985',
    no: no,
    vpos: no * 1000,
    postedAt: base.add(Duration(seconds: no)),
    content: 'コメント$no',
    userId: 'client-abc',
    mail: mail,
  );

  group('jikkyoCommentColorOf', () {
    test('固定の色は明るさによらず同じ値を返す', () {
      for (final brightness in Brightness.values) {
        expect(jikkyoCommentColorOf('red', brightness), const Color(0xFFFF0000));
        expect(jikkyoCommentColorOf('cyan', brightness), const Color(0xFF00FFFF));
        expect(
          jikkyoCommentColorOf('purple', brightness),
          const Color(0xFFCC00FF),
        );
      }
    });

    test('白と黒は明るさに応じて反転する', () {
      expect(jikkyoCommentColorOf('white', Brightness.light), const Color(0xFF000000));
      expect(jikkyoCommentColorOf('white', Brightness.dark), const Color(0xFFFFFFFF));
      expect(jikkyoCommentColorOf('black', Brightness.light), const Color(0xFFFFFFFF));
      expect(jikkyoCommentColorOf('black', Brightness.dark), const Color(0xFF000000));
    });

    test('未知の色名は白 (黒テーマ) / 黒 (ライトテーマ) として扱う', () {
      // 未知のトークンは `parseJikkyoCommentMail` が既定値に落とすため通常は
      // 流れないが、直接渡された場合も落ちないこと。
      expect(jikkyoCommentColorOf('???', Brightness.light), const Color(0xFF000000));
      expect(jikkyoCommentColorOf('???', Brightness.dark), const Color(0xFFFFFFFF));
    });
  });

  group('buildJikkyoDanmaku', () {
    test('位置コマンドが無い場合は横流れになる', () {
      final danmaku = buildJikkyoDanmaku(
        comment(no: 1),
        brightness: Brightness.light,
      );
      expect(danmaku.type, DanmakuItemType.scroll);
    });

    test('位置コマンドを弾幕の種別に反映する', () {
      // 地上波/BS いずれも `ue` / `shita` はそのまま表現する。
      expect(
        buildJikkyoDanmaku(
          comment(no: 1, mail: 'ue'),
          brightness: Brightness.light,
        ).type,
        DanmakuItemType.top,
      );
      expect(
        buildJikkyoDanmaku(
          comment(no: 1, mail: 'shita'),
          brightness: Brightness.light,
        ).type,
        DanmakuItemType.bottom,
      );
      expect(
        buildJikkyoDanmaku(
          comment(no: 1, mail: 'naka'),
          brightness: Brightness.light,
        ).type,
        DanmakuItemType.scroll,
      );
    });

    test('色コマンドを弾幕の色に反映する', () {
      final danmaku = buildJikkyoDanmaku(
        comment(no: 1, mail: '184 red naka medium'),
        brightness: Brightness.light,
      );
      expect(danmaku.color, const Color(0xFFFF0000));
    });

    test('本文とコメ番をそのまま保持する', () {
      final danmaku = buildJikkyoDanmaku(
        comment(no: 4242, mail: 'green'),
        brightness: Brightness.light,
      );
      expect(danmaku.text, 'コメント4242');
      // 将来 findDanmaku で当たり判定した際の識別用にコメ番を保持する。
      expect(danmaku.extra, 4242);
    });

    test('サイズコマンドは画面共通サイズのため無視する', () {
      // `DanmakuOption.fontSize` は画面全体で1つなので per-item の表現はできない。
      // `small` を付けても種別・色が既定のまま変化しないことを確認する。
      final danmaku = buildJikkyoDanmaku(
        comment(no: 1, mail: 'big red'),
        brightness: Brightness.light,
      );
      expect(danmaku.type, DanmakuItemType.scroll);
      expect(danmaku.color, const Color(0xFFFF0000));
    });

    test('匿名コメントも通常の色そのままにする', () {
      final danmaku = buildJikkyoDanmaku(
        comment(no: 1, mail: '184'),
        brightness: Brightness.light,
      );
      // 匿名の装飾は一覧側の関心事。弾幕では区別しない。
      expect(danmaku.color, jikkyoCommentColorOf('white', Brightness.light));
    });
  });

  group('isJikkyoBackfill', () {
    test('境界が未確定なら全てバックログ扱いにする', () {
      // 購読直後はまだ過去ログの続きが来ている可能性があるため弾幕に出さない。
      expect(isJikkyoBackfill(boundary: null, no: 1), isTrue);
      expect(isJikkyoBackfill(boundary: null, no: 999), isTrue);
    });

    test('境界以下のコメ番はバックログとする', () {
      expect(isJikkyoBackfill(boundary: 100, no: 1), isTrue);
      expect(isJikkyoBackfill(boundary: 100, no: 100), isTrue);
    });

    test('境界を超えるコメ番はライブコメントとする', () {
      expect(isJikkyoBackfill(boundary: 100, no: 101), isFalse);
      expect(isJikkyoBackfill(boundary: 100, no: 5000), isFalse);
    });

    test('欠番があっても判定はコメ番だけで行う', () {
      // NX-Jikkyo はキュー溢れで古いコメントを黙って捨てるため、コメ番に
      // 欠番があっても境界との大小比較だけで判定できる。
      expect(isJikkyoBackfill(boundary: 100, no: 900), isFalse);
      expect(isJikkyoBackfill(boundary: 900, no: 100), isTrue);
    });
  });
}
