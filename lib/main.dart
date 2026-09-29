import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/core/router/router.dart';
import 'src/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit のネイティブ初期化。Linux 等で必須。
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: KurumiApp()));
}

class KurumiApp extends ConsumerWidget {
  const KurumiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // dynamic_color 2.x の配色型は Flutter の ColorScheme と別物のため、
        // システム由来の primary をシード色として受け渡す。
        final lightSeed = lightDynamic == null
            ? null
            : Color(lightDynamic.primary.toARGB32());
        final darkSeed = darkDynamic == null
            ? null
            : Color(darkDynamic.primary.toARGB32());
        return MaterialApp.router(
          title: 'Kurumi',
          theme: buildLightTheme(lightSeed),
          darkTheme: buildDarkTheme(darkSeed),
          routerConfig: router,
        );
      },
    );
  }
}
