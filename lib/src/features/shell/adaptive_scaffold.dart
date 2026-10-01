import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/app_settings.dart';
import '../../domain/entities/backend_type.dart';
import 'app_destinations.dart';

/// 幅に応じて Bar / Rail / Drawer を切り替える Shell。
///
/// - < 600: NavigationBar (スマホ)
/// - 600〜1240: NavigationRail (タブレット)
/// - >= 1240: NavigationDrawer (デスクトップ)
///
/// 使用中バックエンドで未対応の行き先 (Mirakurun 時のビデオ・録画予約)
/// は表示しない。ブランチ index と表示 index の対応は
/// [visibleBranchIndices] で取る。
class AdaptiveScaffold extends ConsumerWidget {
  const AdaptiveScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(
    StatefulNavigationShell navigationShell,
    List<int> visibleIndices,
    int visibleIndex,
  ) {
    final branchIndex = visibleIndices[visibleIndex];
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendType =
        ref.watch(appSettingsProvider).value?.backendType ??
        BackendType.mirakurun;
    final visibleIndices = visibleBranchIndices(backendType);
    // 切替直後など非表示ブランチにいるときは先頭を選択扱いにして
    // NavigationBar 等の範囲外アクセスを避ける (router の redirect が追って戻す)。
    var selectedVisibleIndex = visibleIndices.indexOf(
      navigationShell.currentIndex,
    );
    if (selectedVisibleIndex < 0) {
      selectedVisibleIndex = 0;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < AdaptiveBreakpoints.rail) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedVisibleIndex,
              onDestinationSelected: (visibleIndex) =>
                  _goBranch(navigationShell, visibleIndices, visibleIndex),
              destinations: [
                for (final branchIndex in visibleIndices)
                  NavigationDestination(
                    label: appDestinations[branchIndex].label,
                    icon: Icon(appDestinations[branchIndex].icon),
                    selectedIcon: Icon(
                      appDestinations[branchIndex].selectedIcon,
                    ),
                  ),
              ],
            ),
          );
        }
        if (width < AdaptiveBreakpoints.drawer) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedVisibleIndex,
                  onDestinationSelected: (visibleIndex) =>
                      _goBranch(navigationShell, visibleIndices, visibleIndex),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final branchIndex in visibleIndices)
                      NavigationRailDestination(
                        label: Text(appDestinations[branchIndex].label),
                        icon: Icon(appDestinations[branchIndex].icon),
                        selectedIcon: Icon(
                          appDestinations[branchIndex].selectedIcon,
                        ),
                      ),
                  ],
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              NavigationDrawer(
                selectedIndex: selectedVisibleIndex,
                onDestinationSelected: (visibleIndex) =>
                    _goBranch(navigationShell, visibleIndices, visibleIndex),
                children: [
                  const SizedBox(height: 16),
                  for (final branchIndex in visibleIndices)
                    NavigationDrawerDestination(
                      label: Text(appDestinations[branchIndex].label),
                      icon: Icon(appDestinations[branchIndex].icon),
                      selectedIcon: Icon(
                        appDestinations[branchIndex].selectedIcon,
                      ),
                    ),
                ],
              ),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }
}
