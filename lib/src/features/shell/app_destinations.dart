import 'package:flutter/material.dart';

/// ボトムナビ相当の行き先定義。Bar / Rail / Drawer で共有する。
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const appDestinations = [
  AppDestination(
    label: 'テレビ',
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv,
  ),
  AppDestination(
    label: 'ビデオ',
    icon: Icons.video_library_outlined,
    selectedIcon: Icons.video_library,
  ),
  AppDestination(
    label: '番組表',
    icon: Icons.calendar_view_day_outlined,
    selectedIcon: Icons.calendar_view_day,
  ),
  AppDestination(
    label: '録画予約',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
  ),
  AppDestination(
    label: '設定',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

/// アダプティブナビゲーションのブレークポイント。
class AdaptiveBreakpoints {
  /// これ未満: NavigationBar (スマホ)。
  static const double rail = 600;

  /// これ以上: NavigationDrawer (デスクトップ)。間は NavigationRail。
  static const double drawer = 1240;
}
