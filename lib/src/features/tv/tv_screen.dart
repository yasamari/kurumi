import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/channel_item.dart';
import '../../domain/entities/channel_type.dart';
import '../../domain/repositories/tv_repository.dart';
import 'tv_providers.dart';
import 'widgets/channel_card.dart';

/// テレビ画面: 放送中チャンネルをチャンネル種別タブ+グリッドで表示する。
class TvScreen extends ConsumerWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(nowOnAirChannelsProvider);

    return channels.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        if (error is BackendUnconfiguredException) {
          return Scaffold(
            appBar: AppBar(title: const Text('テレビ')),
            body: _Unconfigured(
              onOpenSettings: () => context.go('/settings'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('テレビ')),
          body: _Error(
            message: '$error',
            onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
          ),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('テレビ')),
            body: _Empty(
              onRetry: () => ref.invalidate(nowOnAirChannelsProvider),
            ),
          );
        }
        final types = channelTypesInOrder(
          items.map((item) => item.channel.channelType),
        );
        return DefaultTabController(
          length: types.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('テレビ'),
              bottom: TabBar(
                tabs: [for (final type in types) Tab(text: type.label)],
              ),
            ),
            body: TabBarView(
              children: [
                for (final type in types)
                  _ChannelGrid(
                    items: items
                        .where(
                          (item) => item.channel.channelType == type,
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChannelGrid extends ConsumerWidget {
  const _ChannelGrid({required this.items});

  final List<ChannelItem> items;

  /// カードの最小幅。大きくするほど列数が減る。
  static const double _maxCrossAxisExtent = 640;
  static const double _spacing = 12;
  static const EdgeInsets _padding = EdgeInsets.all(12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(nowOnAirChannelsProvider.future),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // グリッドと同じ条件で列数を見積もり、1列なら高さ可変のリストにする。
          final usableWidth =
              constraints.maxWidth - _padding.horizontal;
          final singleColumn =
              usableWidth <= _maxCrossAxisExtent + _spacing;
          if (singleColumn) {
            return ListView.separated(
              padding: _padding,
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: _spacing),
              itemBuilder: (context, index) => ChannelCard(
                item: items[index],
                pinFooterToBottom: false,
              ),
            );
          }
          return GridView.builder(
            padding: _padding,
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _maxCrossAxisExtent,
              mainAxisSpacing: _spacing,
              crossAxisSpacing: _spacing,
              mainAxisExtent: 280,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                ChannelCard(item: items[index]),
          );
        },
      ),
    );
  }
}

class _Unconfigured extends StatelessWidget {
  const _Unconfigured({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tv_off_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('サーバーが設定されていません', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onOpenSettings,
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('取得に失敗しました', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('放送中の番組がありません', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('更新')),
        ],
      ),
    );
  }
}
