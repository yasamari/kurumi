import 'package:freezed_annotation/freezed_annotation.dart';

part 'jikkyo_comment.freezed.dart';

/// ニコニコ実況コメント1件。
///
/// NX-Jikkyo のコメントセッションが `chat` メッセージとして流す
/// ニコ生 XML 互換のフィールドを 그대로保持する。
@freezed
abstract class JikkyoComment with _$JikkyoComment {
  const factory JikkyoComment({
    /// 対象のスレッド ID。NX-Jikkyo は文字列で送ってくる。
    required String threadId,

    /// コメ番。スレッド内で単調増加し、**欠番があり得る**。
    ///
    /// NX-Jikkyo は接続ごとの送信キュー (上限200件) が溢れると古いコメントを
    /// 黙って捨てるため、連続性は保証されない。dup 判定と並び順の鍵に使う。
    required int no,

    /// 番組開始からの経過ミリ秒。スレッド開始時刻を基準とした相対時刻。
    required int vpos,

    /// 投稿日時。サーバーの `date` (UNIX秒) と `date_usec` (マイクロ秒) を
    /// 合成した絶対時刻。
    required DateTime postedAt,

    /// コメント本文。
    required String content,

    /// 投稿者 ID。NX-Jikkyo では視聴セッションのクライアント ID が入るため、
    /// ニコニコのユーザー ID ではない。
    required String userId,

    /// コメントコマンド列 (空白区切り)。サーバーは一切解釈しない不透明文字列。
    /// 表示属性への変換は `parseJikkyoCommentMail` で行う。
    required String mail,

    /// プレミアムコメントか。0 のときはキーごと欠落する。
    @Default(false) bool premium,

    /// 匿名コメントか。0 のときはキーごと欠落する。
    @Default(false) bool anonymity,

    /// 自分が投げたコメントか。0 のときはキーごと欠落する。
    @Default(false) bool yourPost,
  }) = _JikkyoComment;
}

/// `chat` メッセージの `chat` オブジェクトをパースする。
///
/// `thread` / `no` / `vpos` / `date` / `date_usec` / `content` / `user_id` /
/// `mail` は常に存在する。`premium` / `anonymity` / `yourpost` は値が 0 の
/// ときキーごと欠落する（本家ニコ生の仕様を NX-Jikkyo が模している）ため、
/// 欠落と 0 を区別せずどちらも false として扱う。
///
/// 想定外の構造 (キー不足・型違い) の場合は null を返す。
JikkyoComment? parseJikkyoChat(Map<String, dynamic> json) {
  final threadId = _asInt(json['thread'])?.toString();
  final no = _asInt(json['no']);
  final vpos = _asInt(json['vpos']);
  final date = _asInt(json['date']);
  final dateUsec = _asInt(json['date_usec']);
  final content = json['content'];
  final userId = json['user_id'];
  final mail = json['mail'];
  if (threadId == null ||
      no == null ||
      vpos == null ||
      date == null ||
      dateUsec == null ||
      content is! String ||
      userId is! String ||
      mail is! String) {
    return null;
  }

  return JikkyoComment(
    threadId: threadId,
    no: no,
    vpos: vpos,
    postedAt: DateTime.fromMillisecondsSinceEpoch(
      date * 1000 + dateUsec ~/ 1000,
    ),
    content: content,
    userId: userId,
    mail: mail,
    premium: _asInt(json['premium']) == 1,
    anonymity: _asInt(json['anonymity']) == 1,
    yourPost: _asInt(json['yourpost']) == 1,
  );
}

int? _asInt(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  // 数値をそのまま文字列にして返すのは稀だが、`thread` は文字列で返る。
  final String v => int.tryParse(v),
  _ => null,
};
