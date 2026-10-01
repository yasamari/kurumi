import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/video_program.dart';
import '../../domain/repositories/tv_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../features/shell/app_destinations.dart';
import 'videos_providers.dart';
import 'widgets/video_detail_pane.dart';
import 'widgets/video_list_tile.dart';

/// ビデオ画面: 録画番組を一覧+詳細の2ペインで表示する。
///
/// Compose の `NavigableListDetailPaneScaffold` 相当を自前実装したもの。
/// 対応関係:
/// - listPane / detailPane: 下の [_VideoListView] / [_DetailSlot] が担う
///   (extraPane は使わない)。
/// - ウィンドウサイズ: 840px 未満は単ペイン (リストのみ。詳細は
///   `/videos/:id` へpush)、840px 以上は2ペイン並列。しきい値は
///   [AdaptiveBreakpoints.listDetail] を使い、タブレット縦画面では
///   単ペインにして操作しやすくする。
/// - `AnimatedPane`: 録画番組の選択切替にアニメーションは付けない
///   (デザイン指定)。詳細ペインは選択に応じて即座に切り替わる。
/// - `ThreePaneScaffoldNavigator` + `contentKey`: [selectedVideoIdProvider]
///   (keepAlive) と go_router のネストルートが担う。
/// - `defaultBackBehavior` (`PopUntilScaffoldValueChange`): 狭幅ではシステム
///   バックで詳細が閉じてリストに戻る。
///
/// なお `flutter_adaptive_scaffold` パッケージは discontinued のため使わず、
/// [`AdaptiveBreakpoints`] と go_router だけで組んでいる。
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  /// 検索入力のデバウンス時間。決定打ではなく入力確定待ちのため短めにする。
  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(videosQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      _debounceDuration,
      () => ref.read(videosQueryProvider.notifier).set(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchRow = _SearchRow(
              controller: _searchController,
              onChanged: _onSearchChanged,
            );
            // 広幅: リスト+詳細を並列表示する。検索バーはリストペイン内に置く。
            if (constraints.maxWidth >= AdaptiveBreakpoints.listDetail) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 480,
                    child: Column(
                      children: [
                        searchRow,
                        const Expanded(child: _VideoListView(wide: true)),
                      ],
                    ),
                  ),
                  const Expanded(child: _DetailSlot()),
                ],
              );
            }
            // 狭幅: リストのみ。詳細は `/videos/:id` へpushする。
            return Column(
              children: [
                searchRow,
                const Expanded(child: _VideoListView(wide: false)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 検索バー+ソートメニューの行。参考デザインどおり上端に置く。
class _SearchRow extends ConsumerWidget {
  const _SearchRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(videosOrderProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              controller: controller,
              hintText: '録画を検索',
              leading: const Icon(Icons.search),
              trailing: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    if (controller.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'クリア',
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    );
                  },
                ),
              ],
              onChanged: onChanged,
            ),
          ),
          PopupMenuButton<VideoSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: '並び順',
            initialValue: order,
            onSelected: (value) =>
                ref.read(videosOrderProvider.notifier).set(value),
            itemBuilder: (context) => [
              for (final value in VideoSortOrder.values)
                CheckedPopupMenuItem<VideoSortOrder>(
                  value: value,
                  checked: value == order,
                  child: Text(value.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 録画番組の一覧ペイン。検索・並び順の変更で先頭から取り直す。
class _VideoListView extends ConsumerStatefulWidget {
  const _VideoListView({required this.wide});

  /// 広幅2ペイン内かどうか。タップ時の遷移先が変わる。
  final bool wide;

  @override
  ConsumerState<_VideoListView> createState() => _VideoListViewState();
}

class _VideoListViewState extends ConsumerState<_VideoListView> {
  late final ScrollController _scrollController;

  /// 末尾手前で次ページを読み始める余裕。
  static const _loadMoreThreshold = 400.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (!position.hasPixels || position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(videosListProvider.notifier).loadMore();
    }
  }

  void _onTap(VideoProgram video) {
    ref.read(selectedVideoIdProvider.notifier).select(video.id);
    if (!widget.wide) {
      context.push('/videos/${video.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(videosListProvider);

    return list.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return _Unconfigured(
            onOpenSettings: () => context.go('/settings'),
          );
        }
        return _Error(
          message: '$error',
          onRetry: () => ref.invalidate(videosListProvider),
        );
      },
      data: (state) {
        if (state.items.isEmpty) {
          return _Empty(
            onRetry: () => ref.invalidate(videosListProvider),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(videosListProvider.future),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final video = state.items[index];
              return VideoListTile(
                video: video,
                onTap: () => _onTap(video),
              );
            },
          ),
        );
      },
    );
  }
}

/// 広幅時の詳細ペイン。選択が変わったらアニメーションなしで切り替える。
class _DetailSlot extends ConsumerWidget {
  const _DetailSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedVideoIdProvider);
    final items = ref.watch(videosListProvider).value?.items;
    final video = items
        ?.where((item) => item.id == selectedId)
        .firstOrNull;

    if (video == null) return const _NoSelection();
    return VideoDetailPane(video: video);
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '番組を選択してください',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
            Icons.video_library_outlined,
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
          Text('録画番組がありません', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('更新')),
        ],
      ),
    );
  }
}
