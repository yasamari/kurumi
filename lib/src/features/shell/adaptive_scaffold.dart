import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_destinations.dart';

/// 幅に応じて Bar / Rail / Drawer を切り替える Shell。
///
/// - < 600: NavigationBar (スマホ)
/// - 600〜1240: NavigationRail (タブレット)
/// - >= 1240: NavigationDrawer (デスクトップ)
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < AdaptiveBreakpoints.rail) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              destinations: [
                for (final destination in appDestinations)
                  NavigationDestination(
                    label: destination.label,
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
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
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in appDestinations)
                      NavigationRailDestination(
                        label: Text(destination.label),
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              NavigationDrawer(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goBranch,
                children: [
                  const SizedBox(height: 16),
                  for (var i = 0; i < appDestinations.length; i++)
                    NavigationDrawerDestination(
                      label: Text(appDestinations[i].label),
                      icon: Icon(appDestinations[i].icon),
                      selectedIcon: Icon(appDestinations[i].selectedIcon),
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
