import 'package:flutter/material.dart';

import '../../core/utils/time_format.dart';
import '../../core/widgets/program_symbol_text.dart';
import '../../domain/entities/channel_item.dart';

/// 視聴画面用の番組情報パネル。
///
/// 表示内容 (上から): チャンネルヘッダー (ロゴ+番号・局名) / 番組タイトル /
/// 放送時間 / ジャンル / 番組概要 (説明) / 番組詳細。
///
/// 自身でスクロールする (`SingleChildScrollView`)。呼び出し側は縦画面なら
/// 映像の下の `Expanded` に、横画面なら映像の右の固定幅ボックスに置く。
class ProgramInfoPanel extends StatelessWidget {
  const ProgramInfoPanel({super.key, required this.item});

  final ChannelItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final program = item.nowOnAir;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChannelHeader(item: item),
          const SizedBox(height: 12),
          if (program != null) ...[
            ProgramSymbolText(
              program.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatProgramSlot(program.startAt, program.endAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (program.genres.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final genre in program.genres) Chip(label: Text(genre)),
                ],
              ),
            ],
            if (program.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '番組概要',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ProgramSymbolText(
                program.description,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (program.detail.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '番組詳細',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              for (final entry in program.detail.entries) ...[
                _DetailRow(title: entry.key, body: entry.value),
                const SizedBox(height: 8),
              ],
            ],
          ] else ...[
            Text('番組情報がありません', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// チャンネルロゴ+番号・局名のヘッダー。
class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.item});

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

/// 番組詳細の1項目 (見出し+本文)。
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        ProgramSymbolText(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
