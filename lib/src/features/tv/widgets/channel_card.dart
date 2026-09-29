import 'package:flutter/material.dart';

import '../../../core/utils/time_format.dart';
import '../../../domain/entities/channel_item.dart';

/// チャンネルカード。デザイン差し替え時はこのファイルのみ変更する。
///
/// 構成 (上から): ヘッダー(ロゴ+番号・局名) / 放送中タイトル / 時間 / 概要 /
/// 区切り / 次番組 / 進捗バー。勢い・視聴数・ピン留めは表示しない。
///
/// [pinFooterToBottom] が true の場合、区切りより下をカード下部に寄せる
/// (グリッド表示用)。false の場合は内容量に応じた高さになる (1列表示用)。
class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.item,
    this.pinFooterToBottom = true,
    this.onTap,
  });

  final ChannelItem item;
  final bool pinFooterToBottom;

  /// カードタップ時のコールバック。視聴画面への遷移に使う。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nowOnAir = item.nowOnAir;
    final nextUp = item.nextUp;
    final now = DateTime.now();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: pinFooterToBottom
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            _Header(item: item),
            const SizedBox(height: 8),
            if (nowOnAir != null) ...[
              Text(
                nowOnAir.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                formatProgramSlot(nowOnAir.startAt, nowOnAir.endAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (nowOnAir.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  nowOnAir.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            // dividerより下はカード下部に寄せる (グリッド表示時のみ)。
            if (pinFooterToBottom)
              const Spacer()
            else
              const SizedBox(height: 12),
            if (nextUp != null) ...[
              const Divider(height: 16),
              Text(
                '次▶ ${nextUp.title}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                formatProgramSlot(nextUp.startAt, nextUp.endAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (nowOnAir != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: programProgress(
                  nowOnAir.startAt,
                  nowOnAir.endAt,
                  now,
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});

  final ChannelItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channel = item.channel;
    final logoUrl = channel.logoUrl;
    final number = channel.channelNumber;

    return Row(
      children: [
        if (logoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
          ),
        if (logoUrl != null) const SizedBox(width: 12),
        Expanded(
          child: Text(
            number.isEmpty ? channel.name : '$number ${channel.name}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
