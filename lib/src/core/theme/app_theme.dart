import 'package:flutter/material.dart';

/// dynamic_color 対応のテーマ生成。
///
/// dynamic_color 2.x の `DynamicColorBuilder` が返す配色から primary を
/// シード色として受け取り (`main.dart` で変換)、Material 3 の配色を生成する。
/// シードが null の場合 (非対応OS等) は既定色にフォールバックする。
ThemeData buildLightTheme(Color? dynamicSeed) {
  return ThemeData(
    colorScheme:
        ColorScheme.fromSeed(seedColor: dynamicSeed ?? Colors.deepOrange),
    useMaterial3: true,
  );
}

ThemeData buildDarkTheme(Color? dynamicSeed) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? Colors.deepOrange,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
