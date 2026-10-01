import 'package:flutter/material.dart';

import '../../domain/entities/backend_type.dart';

/// ナビゲーションの区画。`appDestinations` および router のブランチと
/// 同じ順序で並べる。新区画の追加時は [isSectionAvailable] の switch にも
/// 1行追加する (網羅 switch のため書き忘れはコンパイルエラーになる)。
enum AppSection {
  tv,
  videos,
  timetable,
  reservations,
  settings,
}

/// ボトムナビ相当の行き先定義。Bar / Rail / Drawer で共有する。
///
/// `router.dart` の `StatefulShellBranch` の順序と対応している。
/// 順序を変える・増減するときは両方を同期すること。
class AppDestination {
  const AppDestination({
    required this.section,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  /// 対応する区画。利用可否の判定に使う。
  final AppSection section;

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// 対応するブランチのルートパス (`/tv` など)。
  final String path;
}

const appDestinations = [
  AppDestination(
    section: AppSection.tv,
    label: 'テレビ',
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv,
    path: '/tv',
  ),
  AppDestination(
    section: AppSection.videos,
    label: 'ビデオ',
    icon: Icons.video_library_outlined,
    selectedIcon: Icons.video_library,
    path: '/videos',
  ),
  AppDestination(
    section: AppSection.timetable,
    label: '番組表',
    icon: Icons.calendar_view_day_outlined,
    selectedIcon: Icons.calendar_view_day,
    path: '/timetable',
  ),
  AppDestination(
    section: AppSection.reservations,
    label: '録画予約',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
    path: '/reservations',
  ),
  AppDestination(
    section: AppSection.settings,
    label: '設定',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    path: '/settings',
  ),
];

/// 区画が指定バックエンドで利用可能かどうか。純粋関数。
///
/// バックエンドごとの対応可否は [BackendType] の能力 getter が持ち、
/// ここでは区画→能力の対応だけを定義する。新バックエンド追加時の
/// 更新は不要で、能力 getter 側の網羅 switch が検出する。
bool isSectionAvailable(AppSection section, BackendType backendType) =>
    switch (section) {
      AppSection.tv => true,
      AppSection.videos => backendType.supportsVideos,
      AppSection.timetable => true,
      AppSection.reservations => backendType.supportsRecordingReservations,
      AppSection.settings => true,
    };

/// 指定バックエンドで表示する行き先のブランチ index 一覧。純粋関数。
List<int> visibleBranchIndices(BackendType backendType) {
  return [
    for (var i = 0; i < appDestinations.length; i++)
      if (isSectionAvailable(appDestinations[i].section, backendType)) i,
  ];
}

/// 指定パスがそのバックエンドで利用可能かどうか。router の redirect 用。純粋関数。
bool isPathAvailable(String location, BackendType backendType) {
  for (final destination in appDestinations) {
    if (location == destination.path ||
        location.startsWith('${destination.path}/')) {
      return isSectionAvailable(destination.section, backendType);
    }
  }
  return true;
}

/// アダプティブナビゲーションのブレークポイント。
class AdaptiveBreakpoints {
  /// これ未満: NavigationBar (スマホ)。
  static const double rail = 600;

  /// これ以上: NavigationDrawer (デスクトップ)。間は NavigationRail。
  static const double drawer = 1240;
}
