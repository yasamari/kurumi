import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/player/watch_screen.dart';
import '../../features/reservations/reservations_screen.dart';
import '../../features/settings/backend_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/adaptive_scaffold.dart';
import '../../features/timetable/timetable_screen.dart';
import '../../features/tv/tv_screen.dart';
import '../../features/videos/videos_screen.dart';

part 'router.g.dart';

/// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
///
/// ライブ視聴 (`/watch/:channelId`) だけはシェルの外側・root Navigator上に
/// 積む。ナビゲーション (Bar/Rail/Drawer) を表示しないため。
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/tv',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdaptiveScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tv',
                builder: (context, state) => const TvScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/videos',
                builder: (context, state) => const VideosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timetable',
                builder: (context, state) => const TimetableScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reservations',
                builder: (context, state) => const ReservationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'backend',
                    builder: (context, state) =>
                        const BackendSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // ライブ視聴はシェル外 (root Navigator) に置いてナビゲーションを隠す。
      GoRoute(
        path: '/watch/:channelId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => WatchScreen(
          channelId: state.pathParameters['channelId']!,
        ),
      ),
    ],
  );
}
