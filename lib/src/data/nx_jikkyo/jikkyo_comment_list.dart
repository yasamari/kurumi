import '../../domain/entities/channel.dart';
import 'jikkyo_channel_map.dart';
import 'jikkyo_comment.dart';

/// 保持するコメントの最大件数。
///
/// NX-Jikkyo は接続ごとの送信キュー (上限200件) が溢れると古いコメントを黙って
/// 捨てるため、コメ番の欠番は日常的に発生しうる。件数で区切ることで長時間視聴
/// 時のメモリ消費を抑えつつ、実況を追うのに足る量を確保する。
const jikkyoCommentBufferSize = 500;

/// コメント一覧の状態。
enum JikkyoCommentStatus {
  /// 接続中。コメントをまだ一つも受けていない。
  connecting,

  /// 購読済み。コメントを受け取るたびに [JikkyoCommentsState.comments] が増える。
  ready,

  /// 対応するニコニコ実況チャンネルが無い (CATV・SKY、実況非対応局など)。
  unsupported,

  /// 放送していない。
  unavailable,

  /// 放送が終了した。
  ended,

  /// 接続に失敗した。[JikkyoCommentsState.message] に理由が入る。
  error,
}

/// コメント一覧の状態。
class JikkyoCommentsState {
  const JikkyoCommentsState({
    this.status = JikkyoCommentStatus.connecting,
    this.comments = const [],
    this.message,
  });

  final JikkyoCommentStatus status;

  /// 受信済みのコメント。古い順に並ぶ (コメ番 `no` の昇順)。
  final List<JikkyoComment> comments;

  /// 非対応・終了・失敗理由のユーザー向け文言。
  final String? message;

  JikkyoCommentsState copyWith({
    JikkyoCommentStatus? status,
    List<JikkyoComment>? comments,
    String? message,
  }) {
    return JikkyoCommentsState(
      status: status ?? this.status,
      comments: comments ?? this.comments,
      message: message ?? this.message,
    );
  }
}

/// チャンネルの種別と MPEG-TS network_id / service_id から実況チャンネル ID を
/// 引く。
///
/// 対応する実況チャンネルが無ければ null。
String? jikkyoChannelIdFor(Channel channel) => resolveJikkyoChannelId(
  channelType: channel.channelType,
  networkId: channel.networkId,
  serviceId: channel.serviceId,
);

/// コメ番がバックログ（購読直後の過去ログ）の範囲内かどうか。
///
/// NX-Jikkyo は購読開始時に直近の過去コメント (既定100件) をまとめて送って
/// くる。弾幕は「いま届いた新規コメント」だけを出したいので、これらは弾幕に
/// 流さない。一覧には通常どおり全てのコメントを出してよい。
///
/// [boundary] は購読直後の最初のバッチに現れた最大コメ番。それ以下のコメ番は
/// 過去ログとみなす。`null` はまだ境界決めていない (購読直後) を意味し、
/// この場合は全てバックログ扱いとする。
///
/// バックログはまとめて短時間で届くため、最初のバッチでほぼ全体を捕捉
/// できる。厳密には 100ms のバッチ境界をまたいで届いた分だけ漏れる。
///
/// 時刻での判定はサーバーと端末の時計ずれでライブコメントを落としてしまう
/// 可能性があるため、コメ番で判定する。
bool isJikkyoBackfill({required int? boundary, required int no}) {
  if (boundary == null) return true;
  return no <= boundary;
}

/// 既存コメントと新着コメントをマージする純粋関数。
///
/// - コメ番 `no` が既にあるコメントは捨てる。再接続時の再送で重複して届くため。
/// - 常に `no` 昇順に並べ直す。届いた順番を信用できないため。
/// - [maxCount] を超えたら古いものから捨てる。
///
/// 引数化しているため単体テストしやすい。
List<JikkyoComment> mergeJikkyoComments({
  required List<JikkyoComment> existing,
  required Iterable<JikkyoComment> incoming,
  int maxCount = jikkyoCommentBufferSize,
}) {
  final byNo = <int, JikkyoComment>{};
  for (final comment in existing) {
    byNo[comment.no] = comment;
  }
  for (final comment in incoming) {
    byNo.putIfAbsent(comment.no, () => comment);
  }
  final merged = byNo.values.toList()..sort((a, b) => a.no.compareTo(b.no));
  if (merged.length <= maxCount) return merged;
  return merged.sublist(merged.length - maxCount);
}
