import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// システムが返す Dynamic Color (light / dark の一対)。
class DynamicColorSchemes {
  const DynamicColorSchemes({required this.light, required this.dark});

  final ColorScheme light;
  final ColorScheme dark;
}

/// Android の Jetpack Compose Material 3 から受け取る ColorScheme のロール名。
///
/// Android 側 `DynamicColorBridge.kt` が送るキーと 1 対 1 で対応する。
/// ここに無いキーは [dynamicColorSchemeFromRoles] で参照されない。
const List<String> composeDynamicColorRoles = <String>[
  'primary',
  'onPrimary',
  'primaryContainer',
  'onPrimaryContainer',
  'inversePrimary',
  'secondary',
  'onSecondary',
  'secondaryContainer',
  'onSecondaryContainer',
  'tertiary',
  'onTertiary',
  'tertiaryContainer',
  'onTertiaryContainer',
  'error',
  'onError',
  'errorContainer',
  'onErrorContainer',
  'surface',
  'onSurface',
  'onSurfaceVariant',
  'inverseSurface',
  'inverseOnSurface',
  'outline',
  'outlineVariant',
  'scrim',
  'surfaceBright',
  'surfaceDim',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'surfaceTint',
];

const MethodChannel _androidChannel =
    MethodChannel('io.github.yasamari.kurumi/dynamic_color');

/// システムの Dynamic Color を取得する。取得できない場合は null。
///
/// Android 12 (API 31) 以上では Jetpack Compose Material 3 の
/// `dynamicLightColorScheme()` / `dynamicDarkColorScheme()` の返り値をそのまま使うので、
/// 同じ端末・同じ壁紙なら Compose 側の ColorScheme と一致する。
/// Android 以外では OS のアクセント色から Flutter 側で配色を作る
/// (macOS / Windows / GTK 系の Linux に対応している [dynamic_color] パッケージ経由)。
Future<DynamicColorSchemes?> loadDynamicColorSchemes() async {
  final android = await _loadFromAndroid();
  if (android != null) {
    return android;
  }
  return _loadFromAccentColor();
}

/// Compose の ColorScheme をロール単位の整数 (ARGB) に分解して受け取る。
///
/// Android 12 (API 31) 未満には system color resource が無いため null。
/// Android 以外にも MethodChannel のハンドラが無いので null。
Future<DynamicColorSchemes?> _loadFromAndroid() async {
  final Object? result;
  try {
    result = await _androidChannel.invokeMethod<Object?>('getDynamicColorSchemes');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
  if (result is! Map) {
    return null;
  }
  final light = result['light'];
  final dark = result['dark'];
  if (light is! Map || dark is! Map) {
    return null;
  }
  return DynamicColorSchemes(
    light: dynamicColorSchemeFromRoles(light, Brightness.light),
    dark: dynamicColorSchemeFromRoles(dark, Brightness.dark),
  );
}

/// Android 以外のプラットフォームの Dynamic Color (macOS / Windows / GTK 系 Linux) 。
Future<DynamicColorSchemes?> _loadFromAccentColor() async {
  final Color? accent;
  try {
    accent = await DynamicColorPlugin.getAccentColor();
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
  if (accent == null) {
    return null;
  }
  return DynamicColorSchemes(
    light: ColorScheme.fromSeed(seedColor: accent),
    dark: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
  );
}

/// Compose の ColorScheme を Flutter の [ColorScheme] に写す。
///
/// Android 側から受け取った値を 1 対 1 で割り当てるだけで、Flutter 側で tonal palette を
/// 組み立て直すことはしない。組み立て直しをすると Compose と role ごとに値がずれるため。
///
/// Compose 1.3.1 の ColorScheme に無い `primaryFixed` などの fixed role は Flutter 側の
/// 既定値に委ねる。Compose にはあるが Flutter では非推奨の `background` / `onBackground` /
/// `surfaceVariant` は転送せず、Flutter 側のフォールバック (`surface` / `onSurface`) に
/// 委ねる。
ColorScheme dynamicColorSchemeFromRoles(
  Map<Object?, Object?> roles,
  Brightness brightness,
) {
  Color role(String name) {
    final value = roles[name];
    if (value is! int) {
      throw ArgumentError.value(
        roles,
        name,
        'Compose ColorScheme に $name がありません',
      );
    }
    return Color(value);
  }

  return ColorScheme(
    brightness: brightness,
    primary: role('primary'),
    onPrimary: role('onPrimary'),
    primaryContainer: role('primaryContainer'),
    onPrimaryContainer: role('onPrimaryContainer'),
    inversePrimary: role('inversePrimary'),
    secondary: role('secondary'),
    onSecondary: role('onSecondary'),
    secondaryContainer: role('secondaryContainer'),
    onSecondaryContainer: role('onSecondaryContainer'),
    tertiary: role('tertiary'),
    onTertiary: role('onTertiary'),
    tertiaryContainer: role('tertiaryContainer'),
    onTertiaryContainer: role('onTertiaryContainer'),
    error: role('error'),
    onError: role('onError'),
    errorContainer: role('errorContainer'),
    onErrorContainer: role('onErrorContainer'),
    surface: role('surface'),
    onSurface: role('onSurface'),
    onSurfaceVariant: role('onSurfaceVariant'),
    inverseSurface: role('inverseSurface'),
    onInverseSurface: role('inverseOnSurface'),
    outline: role('outline'),
    outlineVariant: role('outlineVariant'),
    surfaceBright: role('surfaceBright'),
    surfaceDim: role('surfaceDim'),
    surfaceContainerLowest: role('surfaceContainerLowest'),
    surfaceContainerLow: role('surfaceContainerLow'),
    surfaceContainer: role('surfaceContainer'),
    surfaceContainerHigh: role('surfaceContainerHigh'),
    surfaceContainerHighest: role('surfaceContainerHighest'),
    surfaceTint: role('surfaceTint'),
    // Compose は shadow の role を持たない。scrim と同じ動的色を使う。
    shadow: role('scrim'),
    scrim: role('scrim'),
  );
}