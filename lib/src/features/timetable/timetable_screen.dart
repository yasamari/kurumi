import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/channel_type.dart';
import '../../domain/entities/timetable.dart';
import '../../domain/entities/tv_program.dart';
import '../../domain/repositories/tv_repository.dart';
import '../tv/epg_providers.dart';
import 'timetable_layout.dart';
import 'timetable_providers.dart';
import 'widgets/timetable_grid.dart';
import 'widgets/timetable_program_sheet.dart';

/// 番組表画面: 縦=時間・横=チャンネルの番組表を種別タブ+日送りで表示する。
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  /// 今日の放送日からのずれ (日単位)。シェルに保持されるためタブ切替で保たれる。
  int _dayOffset = 0;

  /// 種別タブの選択位置。再読み込みで先頭に戻らないよう状態で持つ。
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final baseDayStartMs = timetableDayStartMs(
      DateTime.now().millisecondsSinceEpoch,
    );
    final dayStartMs = timetableDayStartMsForOffset(baseDayStartMs, _dayOffset);
    final isToday = _dayOffset == 0;
    final timetable = ref.watch(timetableDataProvider(dayStartMs));

    return Scaffold(
      appBar: AppBar(
        title: const Text('番組表'),
        actions: [
          IconButton(
            tooltip: '今日に戻る',
            icon: const Icon(Icons.today_outlined),
            onPressed: isToday ? null : () => setState(() => _dayOffset = 0),
          ),
          IconButton(
            tooltip: '更新',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(dayStartMs),
          ),
        ],
      ),
      body: Column(
        children: [
          _DayPager(
            dayStartMs: dayStartMs,
            isToday: isToday,
            onPrevious: () => setState(() => _dayOffset--),
            onNext: () => setState(() => _dayOffset++),
            onToday: () => setState(() => _dayOffset = 0),
          ),
          Expanded(
            // 再計算・裏更新のたびに読み込み表示に戻すとグリッドが点滅する。
            // 前回データを出し続ける。
            child: timetable.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) {
                if (error is BackendUnconfiguredException) {
                  return _Unconfigured(
                    onOpenSettings: () => context.go('/settings'),
                  );
                }
                return _Error(
                  message: '$error',
                  onRetry: () => _refresh(dayStartMs),
                );
              },
              data: (data) => _TimetableBody(
                data: data,
                tabIndex: _tabIndex,
                onTabChanged: (index) => setState(() => _tabIndex = index),
                onProgramTap: (column, program) =>
                    showTimetableProgramSheet(
                      context: context,
                      column: column,
                      program: program,
                    ),
                onChannelTap: (channel) =>
                    context.push('/watch/${channel.id}'),
                onRetry: () => _refresh(dayStartMs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refresh(int dayStartMs) {
    ref.invalidate(mirakurunEpgSyncProvider);
    ref.invalidate(timetableDataProvider(dayStartMs));
  }
}

/// 放送日の送り。中央ラベルタップで今日に戻る。
class _DayPager extends StatelessWidget {
  const _DayPager({
    required this.dayStartMs,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final int dayStartMs;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = formatTimetableDay(dayStartMs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '前の日',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          TextButton(
            onPressed: isToday ? null : onToday,
            child: Text(
              isToday ? '$label (今日)' : label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: '次の日',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// 種別タブ+グリッド。チャンネルが無ければ空表示にする。
class _TimetableBody extends StatelessWidget {
  const _TimetableBody({
    required this.data,
    required this.tabIndex,
    required this.onTabChanged,
    required this.onProgramTap,
    required this.onChannelTap,
    required this.onRetry,
  });

  final TimetableData data;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final void Function(TimetableChannel column, TvProgram program) onProgramTap;
  final void Function(Channel channel) onChannelTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (data.channels.isEmpty) {
      return _Empty(onRetry: onRetry);
    }
    final types = channelTypesInOrder(
      data.channels.map((column) => column.channel.channelType),
    );
    final initialIndex = tabIndex.clamp(0, types.length - 1);
    return DefaultTabController(
      length: types.length,
      initialIndex: initialIndex,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            onTap: onTabChanged,
            tabs: [for (final type in types) Tab(text: type.label)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (var i = 0; i < types.length; i++)
                  TimetableGrid(
                    key: ValueKey('${data.startMs}-$i'),
                    data: data.copyWith(
                      channels: timetableColumnsOfType(
                        data.channels,
                        types[i],
                      ),
                    ),
                    onProgramTap: (column, program) =>
                        onProgramTap(column, program),
                    onChannelTap: onChannelTap,
                  ),
              ],
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
          Text('この日の番組データがありません', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('更新')),
        ],
      ),
    );
  }
}
