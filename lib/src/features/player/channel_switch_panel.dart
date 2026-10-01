import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/channel_card.dart';
import '../../domain/entities/channel_item.dart';
import '../../domain/entities/channel_type.dart';
import '../tv/tv_providers.dart';

/// 視聴画面のチャンネル切替タブ。チャンネル種別ごとに上部のタブで絞り込む。
///
/// テレビ画面と同じ [ChannelCard] を1列で並べる。パネルは幅 400px のサイドバー
/// (横画面) または画面下部 (縦画面) に置かれるため、必ず1列にする。
///
/// 切替は [onChannelSelected] にチャンネルIDを通知するだけなので、`go` による
/// 画面の置き換えは呼び出し側の責務。視聴中のチャンネルも他のカードと区別しない
/// (縁取りや色の変更はしない。どれが映っているかは映像側で分かる)。
///
/// チャンネルを変えると `go` で画面ごと置き換わるため、実況コメントの接続も
/// 新しいチャンネルを作り直される (画面回転と異なり State は保たれない)。
class ChannelSwitchPanel extends ConsumerWidget {
  const ChannelSwitchPanel({
    super.key,
    required this.currentChannelId,
    required this.onChannelSelected,
  });

  /// いま視聴中のチャンネルID。
  final String currentChannelId;

  /// チャンネルを選ぶときのコールバック。チャンネルIDを通知する。
  final ValueChanged<String> onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(nowOnAirChannelsProvider);

    return channels.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Message(text: '$error'),
      data: (items) {
        if (items.isEmpty) {
          return const _Message(text: '放送中の番組がありません');
        }
        // 種別タブは正規順。視聴中のチャンネルがある種別を初期表示する。
        final types = channelTypesInOrder(
          items.map((item) => item.channel.channelType),
        );
        final currentType = items
            .where((item) => item.channel.id == currentChannelId)
            .map((item) => item.channel.channelType)
            .firstOrNull;
        final initialIndex = currentType == null
            ? 0
            : types.indexOf(currentType).clamp(0, types.length - 1);

        return DefaultTabController(
          length: types.length,
          initialIndex: initialIndex,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [for (final type in types) Tab(text: type.label)],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final type in types)
                      _ChannelList(
                        items: items
                            .where(
                              (item) => item.channel.channelType == type,
                            )
                            .toList(),
                        onChannelSelected: onChannelSelected,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 種別ごとのチャンネル一覧。1列のスクロール可能なリスト。
class _ChannelList extends StatelessWidget {
  const _ChannelList({required this.items, required this.onChannelSelected});

  final List<ChannelItem> items;
  final ValueChanged<String> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return ChannelCard(
          item: item,
          // 高さは放送中番組と次番組の内容量に合わせる (1列表示)。
          pinFooterToBottom: false,
          onTap: () => onChannelSelected(item.channel.id),
        );
      },
    );
  }
}

/// チャンネル一覧を取得できなかった場合のメッセージ。
class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
