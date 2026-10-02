import 'package:flutter/material.dart';

/// Dynamic Color 非対応 (Android 12 未満、Android 以外、取得失敗) 時のシード色。
const Color _fallbackSeed = Colors.deepOrange;

/// ライトテーマを生成する。
///
/// [dynamicScheme] が非 null ならそれがそのまま使われる。null のときは
/// [_fallbackSeed] から Material 3 の配色を作る。
ThemeData buildLightTheme(ColorScheme? dynamicScheme) {
  return ThemeData(
    colorScheme:
        dynamicScheme ?? ColorScheme.fromSeed(seedColor: _fallbackSeed),
    useMaterial3: true,
  );
}

/// ダークテーマを生成する。引数の意味は [buildLightTheme] と同じ。
ThemeData buildDarkTheme(ColorScheme? dynamicScheme) {
  return ThemeData(
    colorScheme: dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: _fallbackSeed,
          brightness: Brightness.dark,
        ),
    useMaterial3: true,
  );
}