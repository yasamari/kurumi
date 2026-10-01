import 'package:flutter/foundation.dart';

import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';

/// 実況コメントの取得状態を公開する共通インターフェース。
///
/// ライブ視聴 ([JikkyoCommentController]) と録画再生
/// ([JikkyoPastCommentController]) の両方が実装し、一覧表示
/// ([CommentListPanel]) と弾幕 ([JikkyoDanmakuOverlay]) が共有する。
abstract interface class JikkyoCommentSource extends ChangeNotifier {
  /// 現在の取得状態と蓄積済みコメント。
  JikkyoCommentsState get state;

  /// 弾幕に出す新規コメント。
  Stream<JikkyoComment> get liveComments;

  /// コメント取得に対応しているか。
  bool get isSupported;

  /// 取得をやり直す。
  void retry();
}
