import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/program_detail_body.dart';
import '../../../domain/entities/video_program.dart';
import 'video_file_info_sheet.dart';

/// 録画番組の詳細ペイン。広幅2ペイン時と狭幅プッシュ遷移先で共有する.
///
/// 構成 (上から): 大サムネイル (上・左右にぴったり付け、上部の角丸なし) /
/// 再生ボタン+ファイル情報ボタン / 共有の番組情報 ([ProgramDetailBody])。
///
/// サムネイルはペイン幅いっぱいに広げ、高さは幅の 0.35 倍 (約 10:3.5) に
/// する。16:9 のままだと広い画面で縦に長くなりすぎるため、はみ出した
/// ぶんは [BoxFit.cover] で上下にクロップする。
///
/// 再生ボタンは録画再生画面 (`/videos/:id/play`) へ遷移する。
/// ダウンロード機能は対象外のためボタンは置いていない。
class VideoDetailPane extends StatelessWidget {
  const VideoDetailPane({super.key, required this.video});

  final VideoProgram video;

  /// サムネイルの高さを幅の何倍にするか (0.35 ≒ 10:3.5)。
  static const double thumbnailHeightFactor = 0.35;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordedFile = video.recordedFile;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: double.infinity,
                  height: constraints.maxWidth * thumbnailHeightFactor,
                  child: Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.video_library_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/videos/${video.id}/play'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('再生'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: recordedFile == null
                          ? null
                          : () => showVideoFileInfoSheet(
                                context: context,
                                info: recordedFile,
                              ),
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'ファイル情報',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ProgramDetailBody(
                  channel: video.channel,
                  program: video.toTvProgram(),
                  subtitle: video.subtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
