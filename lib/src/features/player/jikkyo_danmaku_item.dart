import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_mail.dart';

/// コメ番を [DanmakuContentItem.extra] に入れて保持する。
///
/// `DanmakuController.findDanmaku` / `findSingleDanmaku` で当たり判定した
/// ときに、どのコメントだったかを識別できるようにするため。
typedef JikkyoDanmaku = DanmakuContentItem<int>;

/// コメントを弾幕1件のコンテンツに変換する純粋関数。
///
/// - 位置コマンド (`ue` / `shita`) はそのまま表現する。指定が無ければ横流れ。
/// - 色コマンドは `mail` の色をそのまま使う。
/// - **サイズコマンド (`small` / `big`) は表現できない**。
///   `DanmakuOption.fontSize` は画面全体で1つしかなく、`DanmakuScreen` が
///   全弾幕に同じサイズを適用するため。呼び出し側でひとまとめに決める。
/// - 匿名 (`184`) は通常の色そのまま。匿名かどうかを区別する装飾は一覧側の
///   関心事なのでここでは扱わない。
///
/// [brightness] は [parseJikkyoCommentMail] の色名を `Color` に変換するときの
/// 基準になる。映像は常に黒背景なので、テーマに合わせて白と黒を反転させて
/// そのまま受け取る。
JikkyoDanmaku buildJikkyoDanmaku(
  JikkyoComment comment, {
  required Brightness brightness,
}) {
  final style = parseJikkyoCommentMail(comment.mail);
  final type = switch (style.position) {
    JikkyoCommentPosition.top => DanmakuItemType.top,
    JikkyoCommentPosition.bottom => DanmakuItemType.bottom,
    JikkyoCommentPosition.naka => DanmakuItemType.scroll,
  };
  return JikkyoDanmaku(
    comment.content,
    color: jikkyoCommentColorOf(style.color, brightness),
    type: type,
    extra: comment.no,
  );
}
