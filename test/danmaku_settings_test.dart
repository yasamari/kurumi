import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/settings/app_settings_state.dart';
import 'package:kurumi/src/features/player/danmaku_settings.dart';

void main() {
  group('DanmakuPreferences', () {
    test('既定値は表示・標準サイズ', () {
      const preferences = DanmakuPreferences();
      expect(preferences.enabled, isTrue);
      expect(preferences.settings.fontSize, 24);
      expect(preferences.settings.opacity, 1.0);
      expect(preferences.settings.speed, 1.0);
    });

    test('copyWith は on/off だけを変えられる', () {
      const preferences = DanmakuPreferences();
      final hidden = preferences.copyWith(enabled: false);
      expect(hidden.enabled, isFalse);
      expect(hidden.settings, preferences.settings);
    });

    test('設定が違えば等価にならない', () {
      const shown = DanmakuPreferences();
      const bigger = DanmakuPreferences(
        settings: DanmakuDisplaySettings(fontSize: 36),
      );
      expect(shown, isNot(bigger));
      expect(shown, isNot(shown.copyWith(enabled: false)));
    });
  });

  group('danmakuPreferencesOf', () {
    test('未読 (null) は既定値', () {
      expect(danmakuPreferencesOf(null), const DanmakuPreferences());
    });

    test('永続化済みの値を取り出す', () {
      final preferences = danmakuPreferencesOf(
        const AppSettingsState(
          danmakuEnabled: false,
          danmakuFontSize: 30,
          danmakuOpacity: 0.5,
          danmakuSpeed: 1.5,
        ),
      );
      expect(preferences.enabled, isFalse);
      expect(preferences.settings.fontSize, 30);
      expect(preferences.settings.opacity, 0.5);
      expect(preferences.settings.speed, 1.5);
    });

    test('既定値と同じ設定からは既定の実行時値になる', () {
      expect(
        danmakuPreferencesOf(const AppSettingsState()),
        const DanmakuPreferences(),
      );
    });
  });

  group('DanmakuDisplaySettings', () {
    test('既定値は文字サイズ24・不透明・等速', () {
      const settings = DanmakuDisplaySettings();
      expect(settings.fontSize, 24);
      expect(settings.opacity, 1.0);
      expect(settings.speed, 1.0);
    });

    test('同じ値同士は等価になる', () {
      const a = DanmakuDisplaySettings(fontSize: 30, opacity: 0.5);
      const b = DanmakuDisplaySettings(fontSize: 30, opacity: 0.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const DanmakuDisplaySettings(fontSize: 31)));
      // ハッシュが同じでも equality は区別する。
      expect(
        a,
        isNot(
          const DanmakuDisplaySettings(fontSize: 30, opacity: 0.5, speed: 2),
        ),
      );
    });

    test('copyWith は渡した項目だけを変える', () {
      const settings = DanmakuDisplaySettings();
      final updated = settings.copyWith(fontSize: 36);
      expect(updated.fontSize, 36);
      expect(updated.opacity, settings.opacity);
      expect(updated.speed, settings.speed);
    });
  });

  group('danmakuOptionOf', () {
    test('設定がそのままエンジンへ渡る', () {
      final option = danmakuOptionOf(
        const DanmakuDisplaySettings(fontSize: 30, opacity: 0.6, speed: 2),
      );
      expect(option.fontSize, 30);
      expect(option.opacity, 0.6);
      // 速度2倍なら表示時間は半分 (既定8秒→4秒)。画面上の滞在時間は幅に依存しない。
      expect(option.duration, 4);
      expect(option.durationInMilliseconds, 4000);
      // 静止弾幕も速度に追従する (既定5秒→2.5秒)。
      expect(option.staticDuration, 2.5);
    });

    test('速度を下げると遅くなる', () {
      final option = danmakuOptionOf(
        const DanmakuDisplaySettings(speed: 0.5),
      );
      expect(option.duration, 16);
      expect(option.staticDuration, 10);
    });

    test('等速なら画面固定の値そのまま', () {
      final option = danmakuOptionOf(const DanmakuDisplaySettings());
      expect(option.fontSize, 24);
      expect(option.strokeWidth, 2.0);
      expect(option.opacity, 1.0);
      expect(option.duration, 8.0);
      expect(option.staticDuration, 5.0);
    });

    test('読みやすさのための固定値は変えない', () {
      final option = danmakuOptionOf(const DanmakuDisplaySettings());
      // 全面表示 (`safeArea` を切ると字幕用トラックを削らない)。
      expect(option.area, 1.0);
      expect(option.safeArea, isFalse);
      // 軌道が埋まったら重ねずに捨てる。
      expect(option.massiveMode, isFalse);
      // `ue` / `shita` を表現する。
      expect(option.hideTop, isFalse);
      expect(option.hideBottom, isFalse);
    });
  });

  group('スライダーの値の正規化', () {
    test('範囲外は端に寄せる', () {
      expect(danmakuFontSizeOf(0), DanmakuDisplaySettings.minFontSize);
      expect(danmakuFontSizeOf(999), DanmakuDisplaySettings.maxFontSize);
      expect(danmakuOpacityOf(0), DanmakuDisplaySettings.minOpacity);
      expect(danmakuOpacityOf(9), DanmakuDisplaySettings.maxOpacity);
      expect(danmakuSpeedOf(0), DanmakuDisplaySettings.minSpeed);
      expect(danmakuSpeedOf(9), DanmakuDisplaySettings.maxSpeed);
    });

    test('刻み幅に丸める', () {
      // 12〜48 を12段階なので3px刻み。
      expect(danmakuFontSizeOf(13), 12);
      expect(danmakuFontSizeOf(14), 15);
      expect(danmakuFontSizeOf(26), 27);
      expect(danmakuFontSizeOf(47), 48);
      // 0.2〜1.0 を8段階なので10%刻み。
      expect(danmakuOpacityOf(0.24), closeTo(0.2, 1e-9));
      expect(danmakuOpacityOf(0.64), closeTo(0.6, 1e-9));
      // 0.5〜2.0 を6段階なので0.25刻み。
      expect(danmakuSpeedOf(0.6), 0.5);
      expect(danmakuSpeedOf(1.6), closeTo(1.5, 1e-9));
    });

    test('刻みが0以下なら範囲内に収めるだけ', () {
      expect(danmakuStepValue(value: 30, min: 10, max: 20, steps: 0), 20);
      // 範囲が逆でも壊れない。
      expect(danmakuStepValue(value: 15, min: 20, max: 10, steps: 4), 20);
    });
  });

  group('ラベル', () {
    test('文字サイズは数値', () {
      expect(danmakuFontSizeLabel(24), '24');
    });

    test('不透明度はパーセント', () {
      expect(danmakuOpacityLabel(1.0), '100%');
      expect(danmakuOpacityLabel(0.6), '60%');
    });

    test('速度倍率は余分な0を落とした数値', () {
      expect(danmakuSpeedLabel(1.0), '1倍');
      expect(danmakuSpeedLabel(0.5), '0.5倍');
      expect(danmakuSpeedLabel(1.75), '1.75倍');
      expect(danmakuSpeedLabel(2.0), '2倍');
    });
  });

  group('永続化の既定値', () {
    test('弾幕は表示・字幕は非表示が既定', () {
      expect(defaultDanmakuEnabled, isTrue);
      expect(defaultSubtitlesEnabled, isFalse);
      expect(AppSettingsState.defaultSubtitlesEnabled, isFalse);
      expect(AppSettingsState().danmakuEnabled, isTrue);
      expect(AppSettingsState().subtitlesEnabled, isFalse);
    });

    test('実行時の既定値は永続化側の既定値と同じ', () {
      expect(
        DanmakuDisplaySettings.defaultFontSize,
        AppSettingsState.defaultDanmakuFontSize,
      );
      expect(
        DanmakuDisplaySettings.defaultOpacity,
        AppSettingsState.defaultDanmakuOpacity,
      );
      expect(
        DanmakuDisplaySettings.defaultSpeed,
        AppSettingsState.defaultDanmakuSpeed,
      );
    });
  });
}
