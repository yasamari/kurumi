import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/settings/app_settings.dart';
import '../../domain/entities/backend_type.dart';
import '../../features/player/watch_screen.dart';
import '../../features/reservations/reservations_screen.dart';
import '../../features/settings/about_screen.dart';
import '../../features/settings/backend_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/adaptive_scaffold.dart';
import '../../features/shell/app_destinations.dart';
import '../../features/timetable/timetable_screen.dart';
import '../../features/tv/tv_screen.dart';
import '../../features/videos/videos_screen.dart';

part 'router.g.dart';

/// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
///
/// ライブ視聴 (`/watch/:channelId`) だけはシェルの外側・root Navigator上に
/// 積む。ナビゲーション (Bar/Rail/Drawer) を表示しないため。
///
/// Mirakurun 使用時はビデオ・録画予約へ遷移できない。ナビゲーションからは
/// 非表示にし、直リンク時は `/tv` へ戻す。
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/tv',
    redirect: (context, state) {
      // redirect 実行時点の種別を読む (URL 編集では refresh しない)。
      final backendType =
          ref.read(appSettingsProvider).value?.backendType ??
          BackendType.mirakurun;
      if (!isPathAvailable(state.uri.path, backendType)) {
        return '/tv';
      }
      return null;
    },
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
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutScreen(),
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
  // 種別切替時に redirect を再評価する。URL 編集では発火させない。
  ref.listen(appSettingsProvider, (previous, next) {
    const fallback = BackendType.mirakurun;
    if ((previous?.value?.backendType ?? fallback) !=
        (next.value?.backendType ?? fallback)) {
      router.refresh();
    }
  });
  return router;
}
