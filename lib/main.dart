import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/core/licenses/app_licenses.dart';
import 'src/core/router/router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/theme/dynamic_color.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Flutter が自動収録しないネイティブ分 (mpv/FFmpeg 等) の帰属表示。
  registerAppLicenses();
  // media_kit のネイティブ初期化。Linux 等で必須。
  MediaKit.ensureInitialized();
  // Android では Compose Material 3 の ColorScheme をそのまま受け取る。
  // 初回フレームで既定色が不过来、取得できるまで待ってから描画を始める。
  final dynamicColorSchemes = await loadDynamicColorSchemes();
  runApp(
    ProviderScope(
      child: KurumiApp(dynamicColorSchemes: dynamicColorSchemes),
    ),
  );
}

class KurumiApp extends ConsumerWidget {
  const KurumiApp({super.key, required this.dynamicColorSchemes});

  final DynamicColorSchemes? dynamicColorSchemes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Kurumi',
      theme: buildLightTheme(dynamicColorSchemes?.light),
      darkTheme: buildDarkTheme(dynamicColorSchemes?.dark),
      routerConfig: router,
    );
  }
}