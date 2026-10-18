import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/time_format.dart';
import '../../domain/entities/channel_type.dart';
import '../../domain/entities/timetable.dart';
import '../../domain/repositories/tv_repository.dart';
import '../shell/app_destinations.dart';
import '../tv/epg_providers.dart';
import 'timetable_layout.dart';
import 'timetable_providers.dart';
import 'widgets/timetable_grid.dart';
import 'widgets/timetable_program_sheet.dart';

/// 番組表画面: 縦=時間・横=チャンネルの番組表を1行バー+グリッドで表示する。
///
/// チャンネル種別はタブで切り替えない。`TabBarView` の水平スワイプが
/// グリッドの斜めスクロール (`TimetablePanScroll`) と干渉するため、
/// メニューからの選択にしている。種別・日付・時刻・現在ボタンは
/// 1行のバー (`_TimetableBar`) に収める。
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  /// 今日の放送日からのずれ (日単位)。シェルに保持されるためタブ切替で保たれる。
  int _dayOffset = 0;

  /// 種別の選択。未選択・範囲外のときは先頭種別を使う。
  ChannelType? _selectedType;

  /// 外部スクロール要求の世代と対象時刻 (時刻メニュー・現在ボタン用)。
  int _scrollRequestId = 0;
  int? _scrollRequestMs;

  /// グリッド上端に見えている時刻の正時 (ms epoch)。時刻ボタンに表示する。
  ///
  /// スクロールで毎フレーム変わるため、`setState` では持たない。
  /// グリッドが書き込み、バーが `ValueListenableBuilder` で読むだけなので
  /// 画面全体の作り直しは起きない。
  late final ValueNotifier<int> _visibleHourMs = ValueNotifier(
    _initialVisibleHourMs(),
  );

  /// [_visibleHourMs] を初期化したときの放送日開始時刻。日送りでずれたら
  /// 初期値に戻す (スクロール位置はグリッドの作り直しで先頭へ戻るため)。
  late int _visibleDayStartMs = timetableDayStartMsForOffset(
    timetableDayStartMs(DateTime.now().millisecondsSinceEpoch),
    _dayOffset,
  );

  @override
  void dispose() {
    _visibleHourMs.dispose();
    super.dispose();
  }

  /// 初回表示の時刻ボタンの初期値。今日なら現在時刻の正時、過去・未来日は
  /// その日の先頭 (4時)。
  int _initialVisibleHourMs() {
    final baseDayStartMs = timetableDayStartMs(
      DateTime.now().millisecondsSinceEpoch,
    );
    final dayStartMs = timetableDayStartMsForOffset(baseDayStartMs, _dayOffset);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < dayStartMs || nowMs >= dayStartMs + timetableDayLengthMs) {
      return dayStartMs;
    }
    return timetableHourStartMs(timeMs: nowMs, dayStartMs: dayStartMs);
  }

  /// 日送りで放送日が変わったら時刻ボタンを初期値に戻す。
  void _syncVisibleHourMs(int dayStartMs) {
    if (_visibleDayStartMs == dayStartMs) return;
    _visibleDayStartMs = dayStartMs;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs >= dayStartMs && nowMs < dayStartMs + timetableDayLengthMs) {
      _visibleHourMs.value = timetableHourStartMs(
        timeMs: nowMs,
        dayStartMs: dayStartMs,
      );
    } else {
      _visibleHourMs.value = dayStartMs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseDayStartMs = timetableDayStartMs(
      DateTime.now().millisecondsSinceEpoch,
    );
    final dayStartMs = timetableDayStartMsForOffset(baseDayStartMs, _dayOffset);
    _syncVisibleHourMs(dayStartMs);
    final timetable = ref.watch(timetableDataProvider(dayStartMs));
    // 狭幅では詰めた表示にし、「番組表」ラベルを隠して操作部を優先する。
    final compact = MediaQuery.sizeOf(context).width < AdaptiveBreakpoints.rail;

    // 再計算・裏更新のたびに読み込み表示に戻すとグリッドが点滅する。
    // 前回データを出し続ける。
    return timetable.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(
        appBar: _TimetableBar(
          compact: compact,
          types: const [],
          selectedType: null,
          onTypeSelected: (_) {},
          dayStartMs: dayStartMs,
          visibleHourMs: _visibleHourMs,
          onPickDate: _pickDate,
          onTimeSelected: _jumpToTime,
          onGoNow: _goNow,
          onRefresh: () => _refresh(dayStartMs),
        ),
        // 読み込み中もバーと時刻ガターは出す。グリッドは空列で組み、
        // 中央に読み込み表示を重ねる。種別メニューは取得後に生える。
        body: Stack(
          children: [
            TimetableGrid(
              data: TimetableData(
                startMs: dayStartMs,
                endMs: dayStartMs + timetableDayLengthMs,
                channels: const [],
              ),
              visibleHourMs: _visibleHourMs,
              onProgramTap: (_, _) {},
              onChannelTap: (_) {},
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      error: (error, _) {
        if (error is BackendUnconfiguredException) {
          return Scaffold(
            appBar: AppBar(title: const Text('番組表')),
            body: _Unconfigured(onOpenSettings: () => context.go('/settings')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('番組表')),
          body: _Error(message: '$error', onRetry: () => _refresh(dayStartMs)),
        );
      },
      data: (data) {
        final types = channelTypesInOrder(
          data.channels.map((column) => column.channel.channelType),
        );
        if (types.isEmpty) {
          return Scaffold(
            appBar: _TimetableBar(
              compact: compact,
              types: types,
              selectedType: null,
              onTypeSelected: (_) {},
              dayStartMs: dayStartMs,
              visibleHourMs: _visibleHourMs,
              onPickDate: _pickDate,
              onTimeSelected: _jumpToTime,
              onGoNow: _goNow,
              onRefresh: () => _refresh(dayStartMs),
            ),
            body: _Empty(onRetry: () => _refresh(dayStartMs)),
          );
        }
        final selectedType =
            (_selectedType != null && types.contains(_selectedType))
            ? _selectedType!
            : types.first;
        final filtered = data.copyWith(
          channels: timetableColumnsOfType(data.channels, selectedType),
        );
        return Scaffold(
          appBar: _TimetableBar(
            compact: compact,
            types: types,
            selectedType: selectedType,
            onTypeSelected: (type) => setState(() => _selectedType = type),
            dayStartMs: dayStartMs,
            visibleHourMs: _visibleHourMs,
            onPickDate: _pickDate,
            onTimeSelected: _jumpToTime,
            onGoNow: _goNow,
            onRefresh: () => _refresh(dayStartMs),
          ),
          // 日替わりでグリッドを作り直す (先頭へ戻す)。種別切替では
          // 作り直さないため、同じ時刻位置を保ったまま列だけ変わる。
          body: TimetableGrid(
            key: ValueKey(dayStartMs),
            data: filtered,
            visibleHourMs: _visibleHourMs,
            jumpToTimeMs: _scrollRequestMs,
            scrollRequestId: _scrollRequestId,
            onRequestPreviousDay: _goPreviousDayBottom,
            onRequestNextDay: _goNextDayTop,
            onProgramTap: (column, program) => showTimetableProgramSheet(
              context: context,
              column: column,
              program: program,
            ),
            onChannelTap: (channel) => context.push('/watch/${channel.id}'),
          ),
        );
      },
    );
  }

  /// 時刻メニューからのジャンプ。対象時刻へスクロール要求を出す。
  void _jumpToTime(int timeMs) {
    setState(() {
      _scrollRequestId++;
      _scrollRequestMs = timeMs;
    });
  }

  /// 現在時刻へ移動する。日付を今日に戻してから要求を出すため、新データ
  /// 到着後の build で世代変化を見てジャンプする。
  void _goNow() {
    setState(() {
      _dayOffset = 0;
      _scrollRequestId++;
      _scrollRequestMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  /// 上端の「前の日」ボタンからの移動。前日の末尾へ出る
  /// (今見ている先頭と時刻がつながる)。
  void _goPreviousDayBottom() {
    final previousStartMs = timetableDayStartMsForOffset(
      timetableDayStartMs(DateTime.now().millisecondsSinceEpoch),
      _dayOffset - 1,
    );
    setState(() {
      _dayOffset--;
      _scrollRequestId++;
      _scrollRequestMs = previousStartMs + timetableDayLengthMs - 60000;
    });
  }

  /// 下端の「次の日」ボタンからの移動。翌日の先頭へ出る
  /// (今見ている末尾と時刻がつながる)。
  void _goNextDayTop() {
    final nextStartMs = timetableDayStartMsForOffset(
      timetableDayStartMs(DateTime.now().millisecondsSinceEpoch),
      _dayOffset + 1,
    );
    setState(() {
      _dayOffset++;
      _scrollRequestId++;
      _scrollRequestMs = nextStartMs;
    });
  }

  /// 日付ピッカーで放送日を選ぶ。正午基準で求める
  /// (0〜4時は前日の放送日に属するため)。
  Future<void> _pickDate() async {
    final dayStartMs = timetableDayStartMsForOffset(
      timetableDayStartMs(DateTime.now().millisecondsSinceEpoch),
      _dayOffset,
    );
    final initialJst = toJst(DateTime.fromMillisecondsSinceEpoch(dayStartMs));
    final initialDate = DateTime(
      initialJst.year,
      initialJst.month,
      initialJst.day,
    );
    final todayJst = toJst(DateTime.now());
    final today = DateTime(todayJst.year, todayJst.month, todayJst.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    final pickedStartMs = timetableDayStartMs(
      DateTime.utc(
        picked.year,
        picked.month,
        picked.day,
        3,
      ).millisecondsSinceEpoch,
    );
    setState(() {
      _dayOffset = timetableDayOffsetForDayStart(
        baseDayStartMs: timetableDayStartMs(
          DateTime.now().millisecondsSinceEpoch,
        ),
        targetDayStartMs: pickedStartMs,
      );
    });
  }

  void _refresh(int dayStartMs) {
    ref.invalidate(mirakurunEpgSyncProvider);
    ref.invalidate(timetableDataProvider(dayStartMs));
  }
}

/// バー内のテキストボタンの見た目。トーンを付けてボタンと分かるようにする。
/// 狭幅では詰める。
ButtonStyle _barButtonStyle({bool compact = false}) {
  return FilledButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
    minimumSize: Size(0, compact ? 36 : 40),
    textStyle: const TextStyle(fontSize: 14),
    tapTargetSize: compact
        ? MaterialTapTargetSize.shrinkWrap
        : MaterialTapTargetSize.padded,
  );
}

/// 番組表の1行バー。種別・日付・時刻・現在ボタンを1行に収める。
///
/// 狭幅では詰めた表示にし、入り切らない場合もスクロールではなく縮小で
/// 収める (`FittedBox`)。タブ (`TabBar`/`TabBarView`) は使わない。
/// 水平スワイプがグリッドの斜めスクロールと干渉するため。
class _TimetableBar extends StatelessWidget implements PreferredSizeWidget {
  const _TimetableBar({
    required this.compact,
    required this.types,
    required this.selectedType,
    required this.onTypeSelected,
    required this.dayStartMs,
    required this.visibleHourMs,
    required this.onPickDate,
    required this.onTimeSelected,
    required this.onGoNow,
    required this.onRefresh,
  });

  /// 狭幅向けの詰めた表示にするか。「番組表」ラベルは出さない。
  final bool compact;

  /// 利用可能な種別 (正規順)。
  final List<ChannelType> types;

  /// 選択中の種別。データなしのときは null。
  final ChannelType? selectedType;

  final ValueChanged<ChannelType> onTypeSelected;
  final int dayStartMs;

  /// グリッド上端に見えている時刻の正時。時刻ボタンに表示する。
  final ValueListenable<int> visibleHourMs;

  final VoidCallback onPickDate;
  final ValueChanged<int> onTimeSelected;
  final VoidCallback onGoNow;
  final VoidCallback onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final dateLabel = compact
        ? formatTimetableDayShort(dayStartMs)
        : formatTimetableDay(dayStartMs);
    // トーン付きボタン同士の間隔。区切り線は置かない。
    final gap = SizedBox(width: compact ? 4 : 8);
    return AppBar(
      backgroundColor: colorScheme.surface,
      foregroundColor: onSurface,
      scrolledUnderElevation: 0,
      titleSpacing: 4,
      centerTitle: false,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('番組表'),
              ),
            if (!compact) gap,
            if (selectedType != null)
              _TypeMenu(
                types: types,
                selected: selectedType!,
                onSelected: onTypeSelected,
                compact: compact,
              ),
            gap,
            if (compact)
              FilledButton.tonal(
                onPressed: onPickDate,
                style: _barButtonStyle(compact: true),
                child: Text(dateLabel),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onPickDate,
                style: _barButtonStyle(),
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: Text(dateLabel),
              ),
            gap,
            _TimeMenu(
              dayStartMs: dayStartMs,
              visibleHourMs: visibleHourMs,
              onSelected: onTimeSelected,
              compact: compact,
            ),
          ],
        ),
      ),
      actions: [
        IconButton.filledTonal(
          tooltip: '現在時刻に移動',
          icon: const Icon(Icons.my_location, size: 20),
          onPressed: onGoNow,
        ),
        IconButton(
          tooltip: '更新',
          color: onSurface,
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

/// チャンネル種別の選択メニュー。タップ操作のみで切り替える。
class _TypeMenu extends StatelessWidget {
  const _TypeMenu({
    required this.types,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final List<ChannelType> types;
  final ChannelType selected;
  final ValueChanged<ChannelType> onSelected;

  /// 狭幅ではラベル+矢印だけの詰めた表示にする。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, _) {
        void toggleTypeMenu() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        return FilledButton.tonal(
          onPressed: toggleTypeMenu,
          style: _barButtonStyle(compact: compact),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                const Icon(Icons.live_tv_outlined, size: 20),
                const SizedBox(width: 4),
              ],
              Text(selected.label),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        );
      },
      menuChildren: [
        for (final type in types)
          MenuItemButton(
            leadingIcon: type == selected
                ? const Icon(Icons.check, size: 20)
                : null,
            onPressed: () => onSelected(type),
            child: Text(type.label),
          ),
      ],
    );
  }
}

/// 時刻の選択メニュー。選んだ正時へジャンプする。
/// ボタンの表示はグリッド上端に見えている時刻の正時 (`4時` 形式)。
class _TimeMenu extends StatelessWidget {
  const _TimeMenu({
    required this.dayStartMs,
    required this.visibleHourMs,
    required this.onSelected,
    this.compact = false,
  });

  final int dayStartMs;
  final ValueListenable<int> visibleHourMs;
  final ValueChanged<int> onSelected;

  /// 狭幅では詰めた表示にする。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(200, 400)),
      ),
      builder: (context, controller, _) {
        void toggleTimeMenu() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        return ValueListenableBuilder<int>(
          valueListenable: visibleHourMs,
          builder: (context, hourMs, _) {
            final label = formatTimetableHour(hourMs);
            if (compact) {
              return FilledButton.tonal(
                onPressed: toggleTimeMenu,
                style: _barButtonStyle(compact: true),
                child: Text(label),
              );
            }
            return FilledButton.tonalIcon(
              onPressed: toggleTimeMenu,
              style: _barButtonStyle(),
              icon: const Icon(Icons.schedule_outlined, size: 20),
              label: Text(label),
            );
          },
        );
      },
      menuChildren: [
        for (final hourMs in timetableDayHoursMs(dayStartMs))
          MenuItemButton(
            onPressed: () => onSelected(hourMs),
            child: Text(formatTimetableHour(hourMs)),
          ),
      ],
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
          FilledButton(onPressed: onOpenSettings, child: const Text('設定を開く')),
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
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
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
