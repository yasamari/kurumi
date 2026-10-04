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
/// - 色は常に黒背景 (映像の上) 前提で決める。アプリのテーマ (ライト/ダーク) に
///   追従して白黒を反転させてはいけない。ライトテーマで反転すると無指定色
///   (`white`) が黒になり、映像の上で読めなくなる。
JikkyoDanmaku buildJikkyoDanmaku(JikkyoComment comment) {
  final style = parseJikkyoCommentMail(comment.mail);
  final type = switch (style.position) {
    JikkyoCommentPosition.top => DanmakuItemType.top,
    JikkyoCommentPosition.bottom => DanmakuItemType.bottom,
    JikkyoCommentPosition.naka => DanmakuItemType.scroll,
  };
  return JikkyoDanmaku(
    comment.content,
    color: jikkyoCommentColorOf(style.color, Brightness.dark),
    type: type,
    extra: comment.no,
  );
}

/// 録画再生でコメントを弾幕時計の birth (ms) に換算する純粋関数。
///
/// [syncStart] は再生位置0に対応する録画開始時刻。投稿時刻との差がそのまま
/// メディアオフセットになる。録画開始前のコメントは負値になり、再生開始時に
/// 残り表示期間だけ途中から描画される。
int danmakuBirthMsOf({
  required JikkyoComment comment,
  required DateTime syncStart,
}) {
  return comment.postedAt.difference(syncStart).inMilliseconds;
}

/// 弾幕時計を進めてよいかを判定する純粋関数。
///
/// バッファ (`paused-for-cache`) 中は映像が止まっているため、弾幕の
/// スクロールも止める (時計を凍結する)。一時停止中も同様。mpv の `playing`
/// はキャッシュ停滞で変わらないため、`buffering` との合成が必要。
bool danmakuClockShouldRun({
  required bool playing,
  required bool buffering,
}) {
  return playing && !buffering;
}

/// ライブ再開時の時計合わせを計算する純粋関数。
///
/// 一時停止中も実況コメントは届き続けるため、凍結値のまま再開すると停止中の
/// コメントが一斉に現れる。停止していた壁時計分 ([pausedAt]→[resumedAt]) だけ
/// 進めてライブエッジに追従させる。バッファ解消時は使わない (遅延分だけ
/// 映像に追従させるため)。
int danmakuLiveResumeMs({
  required int frozenNowMs,
  required DateTime pausedAt,
  required DateTime resumedAt,
}) {
  return frozenNowMs + resumedAt.difference(pausedAt).inMilliseconds;
}
