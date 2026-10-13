import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/foundation.dart';

import '../../core/settings/app_settings_state.dart';

/// 弾幕の表示設定の既定値。
///
/// 永続化の既定値は [AppSettingsState] 側 ([core/settings]) が持つ。ここは
/// 実行時の既定値として同じ値を引くだけで、値を二重に持たない。
const bool defaultDanmakuEnabled = AppSettingsState.defaultDanmakuEnabled;

/// 字幕表示の既定値。既定は非表示 ([AppSettingsState] 側)。
const bool defaultSubtitlesEnabled = AppSettingsState.defaultSubtitlesEnabled;

/// 弾幕の表示設定 (on/off と3項目)。プレイヤー側で持つ実行時の値。
///
/// 永続化はしない。呼び出し側 ([PlayerPlaybackController]) が初期値として受け取り、
/// 変更時にコールバックで保存する。保存先は `AppSettings` の notifier。
@immutable
class DanmakuPreferences {
  const DanmakuPreferences({
    this.enabled = defaultDanmakuEnabled,
    this.settings = const DanmakuDisplaySettings(),
  });

  /// 弾幕を映像に重ねるかどうか。
  final bool enabled;

  /// 文字サイズ・不透明度・速度。
  final DanmakuDisplaySettings settings;

  DanmakuPreferences copyWith({
    bool? enabled,
    DanmakuDisplaySettings? settings,
  }) {
    return DanmakuPreferences(
      enabled: enabled ?? this.enabled,
      settings: settings ?? this.settings,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DanmakuPreferences &&
            enabled == other.enabled &&
            settings == other.settings;
  }

  @override
  int get hashCode => Object.hash(enabled, settings);

  @override
  String toString() =>
      'DanmakuPreferences(enabled: $enabled, settings: $settings)';
}

/// 永続化済みの設定から実行時の値を作る純粋関数。
///
/// [settings] が null (読み込み中) のときは既定値。プレイヤーはバックエンドの
/// ベースURLが読めていないと開けず、到達時には設定の読み込みが済んでいる。
DanmakuPreferences danmakuPreferencesOf(AppSettingsState? settings) {
  if (settings == null) return const DanmakuPreferences();
  return DanmakuPreferences(
    enabled: settings.danmakuEnabled,
    settings: DanmakuDisplaySettings(
      fontSize: settings.danmakuFontSize,
      opacity: settings.danmakuOpacity,
      speed: settings.danmakuSpeed,
    ),
  );
}

/// 弾幕の表示設定。設定メニューから変更できる3項目だけを持つ。
///
/// 描画範囲 (`area`) や非表示位置 (`hideTop` / `hideBottom`)、描画方式
/// (`massiveMode` / `safeArea`) は読みやすさの事情で画面固定なので、ここには
/// 持たせない。固定値とこの設定の合成は [danmakuOptionOf] が担う。
///
/// エンジンの [DanmakuOption] をそのまま公開しない。エンジン側の
/// `copyWith` は `strokeWidth` を欠落させるため、そのまま持ち回すと変更の
/// 範囲がエンジン実装に晒される。ここでは変更を許す項目だけを公開する。
@immutable
class DanmakuDisplaySettings {
  const DanmakuDisplaySettings({
    this.fontSize = defaultFontSize,
    this.opacity = defaultOpacity,
    this.speed = defaultSpeed,
  });

  /// 文字サイズ (論理ピクセル)。エンジン既定の16では実況の高速コメントが
  /// 読めない。
  static const double defaultFontSize = AppSettingsState.defaultDanmakuFontSize;

  /// 不透明度。1.0 が不透明。
  static const double defaultOpacity = AppSettingsState.defaultDanmakuOpacity;

  /// 速度倍率。1.0 が等速で、大きいほど速い (表示時間を割る)。
  static const double defaultSpeed = AppSettingsState.defaultDanmakuSpeed;

  // 以下はスライダーの範囲と刻み。`Slider` の divisions と、値を作る側の
  // [danmakuFontSizeOf] などで同じものを使う。
  static const double minFontSize = 12;
  static const double maxFontSize = 48;
  static const int fontSizeSteps = 12;
  static const double minOpacity = 0.2;
  static const double maxOpacity = 1.0;
  static const int opacitySteps = 8;
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const int speedSteps = 6;

  /// 文字サイズ (論理ピクセル)。画面全体で1つだけなので、`mail` のサイズ
  /// コマンド (`small` / `big`) は表現できない ([buildJikkyoDanmaku] 参照)。
  final double fontSize;

  /// 不透明度。0.2〜1.0。エンジン側では画面全体を包む `Opacity` になる。
  final double opacity;

  /// 速度倍率。1.0 が等速で、大きいほど速い。
  final double speed;

  DanmakuDisplaySettings copyWith({
    double? fontSize,
    double? opacity,
    double? speed,
  }) {
    return DanmakuDisplaySettings(
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      speed: speed ?? this.speed,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DanmakuDisplaySettings &&
            fontSize == other.fontSize &&
            opacity == other.opacity &&
            speed == other.speed;
  }

  @override
  int get hashCode => Object.hash(fontSize, opacity, speed);

  @override
  String toString() =>
      'DanmakuDisplaySettings('
      'fontSize: $fontSize, opacity: $opacity, speed: $speed)';
}

/// 既定の横流し弾幕の表示時間 (秒)。速度倍率の基準になる画面固定値。
const double _baseScrollDurationSeconds = 8.0;

/// 既定の静止弾幕 (`ue` / `shita`) の表示時間 (秒)。速度に追従させる。
const double _baseStaticDurationSeconds = 5.0;

/// 設定と画面固定値を合わせて `DanmakuOption` を組み立てる純粋関数。
///
/// 速度倍率 ([DanmakuDisplaySettings.speed]) は横流しと静止の表示時間両方を
/// 割る (大きいほど速い)。エンジンの不変条件「画面上の滞在時間は `duration`
/// ちょうどで幅に依存しない」があるため、幅の側ではなく `duration` を変える。
DanmakuOption danmakuOptionOf(DanmakuDisplaySettings settings) {
  return DanmakuOption(
    fontSize: settings.fontSize,
    // 黒背景で読みやすくする。
    strokeWidth: 2.0,
    duration: _baseScrollDurationSeconds / settings.speed,
    staticDuration: _baseStaticDurationSeconds / settings.speed,
    opacity: settings.opacity,
    // 全面に表示する。
    //
    // `safeArea` は `area == 1.0` のときだけ下端の字幕用トラックを1つ削る。
    // 全面表示を優先して無効にしている。字幕との重なりを優先する場合は true。
    area: 1.0,
    safeArea: false,
    // 軌道が埋まったら重ねずに捨てる (重ならない方が読みやすい)。
    massiveMode: false,
    // `ue` / `shita` を表現するため隠さない。
    hideTop: false,
    hideBottom: false,
  );
}

/// スライダーの値を範囲に収め、刻み幅に量子化する純粋関数。
double danmakuStepValue({
  required double value,
  required double min,
  required double max,
  required int steps,
}) {
  if (max < min) return min;
  final clamped = value.clamp(min, max).toDouble();
  if (steps <= 0) return clamped;
  final step = (max - min) / steps;
  if (step <= 0) return clamped;
  final snapped = min + ((clamped - min) / step).round() * step;
  return snapped.clamp(min, max).toDouble();
}

/// スライダーの値から文字サイズを作る純粋関数。
double danmakuFontSizeOf(double value) => danmakuStepValue(
  value: value,
  min: DanmakuDisplaySettings.minFontSize,
  max: DanmakuDisplaySettings.maxFontSize,
  steps: DanmakuDisplaySettings.fontSizeSteps,
);

/// スライダーの値から不透明度を作る純粋関数。
double danmakuOpacityOf(double value) => danmakuStepValue(
  value: value,
  min: DanmakuDisplaySettings.minOpacity,
  max: DanmakuDisplaySettings.maxOpacity,
  steps: DanmakuDisplaySettings.opacitySteps,
);

/// スライダーの値から速度倍率を作る純粋関数。
double danmakuSpeedOf(double value) => danmakuStepValue(
  value: value,
  min: DanmakuDisplaySettings.minSpeed,
  max: DanmakuDisplaySettings.maxSpeed,
  steps: DanmakuDisplaySettings.speedSteps,
);

/// 文字サイズのラベル。
String danmakuFontSizeLabel(double fontSize) => '${fontSize.round()}';

/// 不透明度のラベル。
String danmakuOpacityLabel(double opacity) => '${(opacity * 100).round()}%';

/// 速度倍率のラベル。
String danmakuSpeedLabel(double speed) => '${_danmakuNumberLabel(speed)}倍';

/// 小数点以下の余分な 0 を落とした数値表現 (0.5 → `0.5`、1.0 → `1`)。
String _danmakuNumberLabel(double value) {
  var text = value.toStringAsFixed(2);
  if (!text.contains('.')) return text;
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceFirst(RegExp(r'\.$'), '');
}
