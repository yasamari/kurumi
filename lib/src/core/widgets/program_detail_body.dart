import 'package:flutter/material.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/tv_program.dart';
import '../utils/time_format.dart';
import 'channel_logo.dart';
import 'program_symbol_text.dart';

/// 番組情報の表示ブロック。ライブ視聴の情報タブとビデオ詳細で共有する。
///
/// 表示内容 (上から): チャンネルヘッダー (ロゴ+番号・局名) / 番組タイトル /
/// 放送時間 / サブタイトル (録画番組のみ) / ジャンル / 番組概要 (説明) /
/// 番組詳細。
///
/// 自身ではスクロールしない。呼び出し側で `SingleChildScrollView` 等に載せる。
class ProgramDetailBody extends StatelessWidget {
  const ProgramDetailBody({
    super.key,
    this.channel,
    required this.program,
    this.subtitle,
  });

  /// チャンネル情報。なければヘッダーを出さない。
  final Channel? channel;

  /// 表示する番組。null のときは「番組情報がありません」と出す。
  final TvProgram? program;

  /// 録画番組のサブタイトル。ライブ視聴では使わないため通常は null。
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final program = this.program;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (channel != null) _ChannelHeader(channel: channel!),
        if (program != null) ...[
          if (channel != null) const SizedBox(height: 12),
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
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: theme.textTheme.bodyMedium),
          ],
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
          if (channel != null) const SizedBox(height: 12),
          Text('番組情報がありません', style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

/// チャンネルロゴ+番号・局名のヘッダー。
class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoUrl = channel.logoUrl;
    final number = channel.channelNumber;

    return Row(
      children: [
        if (logoUrl != null) ...[
          ChannelLogo(channel: channel),
          const SizedBox(width: 12),
        ],
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
