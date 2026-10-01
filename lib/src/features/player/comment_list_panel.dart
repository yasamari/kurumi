import 'package:flutter/material.dart';

import '../../core/utils/time_format.dart';
import '../../data/nx_jikkyo/jikkyo_comment.dart';
import '../../data/nx_jikkyo/jikkyo_comment_list.dart';
import '../../data/nx_jikkyo/jikkyo_endpoints.dart';
import 'jikkyo_comment_source.dart';

/// ニコニコ実況コメントの一覧表示。
///
/// コメント本文と投稿時刻のみを表示する。色・サイズ・位置は `mail` コマンドから
/// 来るがここでは解釈せず、文字色は一律 [ColorScheme.onSurface] に固定する。
/// (弾幕表示を実装する段で `parseJikkyoCommentMail` を使う。)
///
/// 接続とコメントの蓄積は [controller] が担う。このウィジェットは状態を一切
/// 持たないので、破棄・再生成されても connecting に戻ったりコメントを失ったり
/// しない。画面回転で [ProgramInfoPanel] ごと作り直される的就是このため。
///
/// リストは `reverse: true` で最新コメントを下端に据え、スクロール位置を保った
/// まま新着が下へ流れ込む。
class CommentListPanel extends StatelessWidget {
  const CommentListPanel({super.key, required this.controller});

  final JikkyoCommentSource controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildBody(context, controller.state),
    );
  }

  Widget _buildBody(BuildContext context, JikkyoCommentsState state) {
    return switch (state.status) {
      // 実況チャンネルが無い場合。サーバー側 (close 1008) とクライアント側の
      // 対応表の判定とで同じ文言に揃えている。
      JikkyoCommentStatus.unsupported => _Message(
        icon: Icons.chat_bubble_outline,
        message: state.message ?? unsupportedChannelMessage,
      ),
      // 実況チャンネルは対応しているが、いま放送していない。
      JikkyoCommentStatus.unavailable => _Message(
        icon: Icons.live_tv_outlined,
        message: state.message ?? 'このチャンネルは現在放送していません',
      ),
      JikkyoCommentStatus.ended => _Message(
        icon: Icons.live_tv_outlined,
        message: state.message ?? '放送が終了しました',
      ),
      JikkyoCommentStatus.error => _Message(
        icon: Icons.error_outline,
        message: state.message ?? '接続に失敗しました',
        action: FilledButton.tonal(
          onPressed: controller.retry,
          child: const Text('再試行'),
        ),
      ),
      JikkyoCommentStatus.connecting => const Center(
        child: CircularProgressIndicator(),
      ),
      // 購読済みだがまだコメント来ていなければ、そのまま空のリストにする。
      JikkyoCommentStatus.ready => _CommentList(comments: state.comments),
    };
  }
}

/// コメント一覧。最新コメントを下端に据える。
class _CommentList extends StatelessWidget {
  const _CommentList({required this.comments});

  /// 古い順に並んだコメント。
  final List<JikkyoComment> comments;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        // `reverse: true` なので index 0 が最新 (下端)。
        return _CommentRow(comment: comments[comments.length - 1 - index]);
      },
    );
  }
}

/// コメント1行。コメント本文と投稿時刻のみを表示する。
class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final JikkyoComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `mail` の色コマンドは使わない。文字色はテーマの onSurface に固定する。
    final color = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              comment.content,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatClockJa(comment.postedAt),
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// 状態メッセージ (非対応・終了・エラー・コメント待ち)。
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
