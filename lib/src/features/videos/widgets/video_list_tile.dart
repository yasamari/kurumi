import 'package:flutter/material.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/channel_logo.dart';
import '../../../core/widgets/program_symbol_text.dart';
import '../../../domain/entities/video_program.dart';

/// 録画番組一覧の1行。参考デザインどおり左サムネイル+右テキストにする。
///
/// 構成 (右列・上から): 番組タイトル (最大2行) / 放送時間 / チャンネル行
/// (ロゴ+番号・局名)。選択中の強調表示はしない。
class VideoListTile extends StatelessWidget {
  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
  });

  final VideoProgram video;
  final VoidCallback onTap;

  /// 一覧サムネイルの幅。高さは 16:9 から求める。
  static const double thumbnailWidth = 168;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channel = video.channel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: thumbnailWidth,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.video_library_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProgramSymbolText(
                        video.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatProgramSlot(video.startAt, video.endAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (channel != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (channel.logoUrl != null) ...[
                              ChannelLogo(channel: channel, width: 56),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                channel.channelNumber.isEmpty
                                    ? channel.name
                                    : '${channel.channelNumber} ${channel.name}',
                                style: theme.textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
