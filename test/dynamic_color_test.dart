import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/theme/dynamic_color.dart';

/// ロールごとに異なる色を割り当てる。
Map<String, Object?> _fakeRoles() {
  return <String, Object?>{
    for (final (index, name) in composeDynamicColorRoles.indexed)
      // index 0 が黒にならないよう 1 から始める。
      name: 0xff000000 | ((index + 1) * 0x000103),
  };
}

Color _expected(String name) {
  final index = composeDynamicColorRoles.indexOf(name);
  return Color(0xff000000 | ((index + 1) * 0x000103));
}

/// Flutter の [ColorScheme] からロール名を取り出す。
///
/// [composeDynamicColorRoles] の名前と 1 対 1 で対応させる。
Color _roleValue(ColorScheme scheme, String name) => switch (name) {
      'primary' => scheme.primary,
      'onPrimary' => scheme.onPrimary,
      'primaryContainer' => scheme.primaryContainer,
      'onPrimaryContainer' => scheme.onPrimaryContainer,
      'inversePrimary' => scheme.inversePrimary,
      'secondary' => scheme.secondary,
      'onSecondary' => scheme.onSecondary,
      'secondaryContainer' => scheme.secondaryContainer,
      'onSecondaryContainer' => scheme.onSecondaryContainer,
      'tertiary' => scheme.tertiary,
      'onTertiary' => scheme.onTertiary,
      'tertiaryContainer' => scheme.tertiaryContainer,
      'onTertiaryContainer' => scheme.onTertiaryContainer,
      'error' => scheme.error,
      'onError' => scheme.onError,
      'errorContainer' => scheme.errorContainer,
      'onErrorContainer' => scheme.onErrorContainer,
      'surface' => scheme.surface,
      'onSurface' => scheme.onSurface,
      'onSurfaceVariant' => scheme.onSurfaceVariant,
      'inverseSurface' => scheme.inverseSurface,
      'inverseOnSurface' => scheme.onInverseSurface,
      'outline' => scheme.outline,
      'outlineVariant' => scheme.outlineVariant,
      'scrim' => scheme.scrim,
      'surfaceBright' => scheme.surfaceBright,
      'surfaceDim' => scheme.surfaceDim,
      'surfaceContainerLowest' => scheme.surfaceContainerLowest,
      'surfaceContainerLow' => scheme.surfaceContainerLow,
      'surfaceContainer' => scheme.surfaceContainer,
      'surfaceContainerHigh' => scheme.surfaceContainerHigh,
      'surfaceContainerHighest' => scheme.surfaceContainerHighest,
      'surfaceTint' => scheme.surfaceTint,
      _ => throw ArgumentError('未知のロール: $name'),
    };

void main() {
  group('dynamicColorSchemeFromRoles', () {
    test('Compose の各ロールが 1 対 1 で Flutter の ColorScheme に載る', () {
      final scheme =
          dynamicColorSchemeFromRoles(_fakeRoles(), Brightness.light);

      for (final name in composeDynamicColorRoles) {
        expect(
          _roleValue(scheme, name),
          _expected(name),
          reason: '$name が Compose の値と一致していない',
        );
      }
    });

    test('primary 系と surfaceContainer 系が混同されない', () {
      // dynamic_color 経由で特に目立っていた問題。
      // surfaceContainer* は Compose では surface と同じ neutral 系から作られるが、
      // Flutter の fromSeed だと primary 由来のパレットになってしまう。
      final scheme =
          dynamicColorSchemeFromRoles(_fakeRoles(), Brightness.dark);

      expect(scheme.primary, isNot(scheme.primaryContainer));
      expect(scheme.surfaceContainer, isNot(scheme.primaryContainer));
      expect(scheme.surfaceContainerHighest, isNot(scheme.surfaceContainerLow));
    });

    test('brightness がそのまま反映される', () {
      final roles = _fakeRoles();
      expect(
        dynamicColorSchemeFromRoles(roles, Brightness.light).brightness,
        Brightness.light,
      );
      expect(
        dynamicColorSchemeFromRoles(roles, Brightness.dark).brightness,
        Brightness.dark,
      );
    });

    test('Compose が持たない role は Flutter の既定値に委ねられる', () {
      final scheme =
          dynamicColorSchemeFromRoles(_fakeRoles(), Brightness.light);

      // material3 1.3.1 の ColorScheme には fixed role が無い。
      expect(scheme.primaryFixed, scheme.primary);
      expect(scheme.onPrimaryFixedVariant, scheme.onPrimary);
      expect(scheme.tertiaryFixedDim, scheme.tertiary);
    });

    test('shadow は Compose の scrim に揃える', () {
      final scheme =
          dynamicColorSchemeFromRoles(_fakeRoles(), Brightness.light);

      expect(scheme.shadow, scheme.scrim);
    });

    test('ロールが欠けていれば例外になる', () {
      final roles = _fakeRoles()..remove('surfaceContainerHighest');

      expect(
        () => dynamicColorSchemeFromRoles(roles, Brightness.light),
        throwsArgumentError,
      );
    });
  });
}