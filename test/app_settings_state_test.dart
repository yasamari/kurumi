import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/settings/app_settings_state.dart';
import 'package:kurumi/src/domain/entities/backend_type.dart';

void main() {
  group('既定値', () {
    test('バックエンドは Mirakurun・URL は空', () {
      const settings = AppSettingsState();
      expect(settings.backendType.name, 'mirakurun');
      expect(settings.mirakurunBaseUrl, '');
      expect(settings.konomiBaseUrl, '');
      expect(settings.isConfigured, isFalse);
    });

    test('弾幕は表示・字幕は非表示', () {
      const settings = AppSettingsState();
      expect(settings.danmakuEnabled, isTrue);
      expect(settings.danmakuFontSize, 24);
      expect(settings.danmakuOpacity, 1.0);
      expect(settings.danmakuSpeed, 1.0);
      // 字幕は既定で隠す。mpv は既定で `sid=auto` なので、プレイヤーが
      // 明示的に `sid=no` を適用する。
      expect(settings.subtitlesEnabled, isFalse);
    });
  });

  group('copyWith', () {
    test('指定した項目だけを変える', () {
      const settings = AppSettingsState(
        mirakurunBaseUrl: 'http://192.168.0.1:40772',
      );
      final updated = settings.copyWith(danmakuFontSize: 36);
      expect(updated.danmakuFontSize, 36);
      expect(updated.mirakurunBaseUrl, 'http://192.168.0.1:40772');
      expect(updated.danmakuEnabled, settings.danmakuEnabled);
    });

    test('字幕の on/off を差し替える', () {
      const settings = AppSettingsState();
      expect(settings.copyWith(subtitlesEnabled: true).subtitlesEnabled, isTrue);
    });

    test('弾幕の表示設定4項目をまとめて差し替える', () {
      const settings = AppSettingsState();
      final updated = settings.copyWith(
        danmakuEnabled: false,
        danmakuFontSize: 18,
        danmakuOpacity: 0.5,
        danmakuSpeed: 2.0,
      );
      expect(updated.danmakuEnabled, isFalse);
      expect(updated.danmakuFontSize, 18);
      expect(updated.danmakuOpacity, 0.5);
      expect(updated.danmakuSpeed, 2.0);
    });
  });

  group('activeBaseUrl', () {
    test('選択中のバックエンドの URL を返す', () {
      const settings = AppSettingsState(
        backendType: BackendType.konomiTv,
        mirakurunBaseUrl: 'http://mirakurun',
        konomiBaseUrl: 'http://konomi',
      );
      expect(settings.activeBaseUrl, 'http://konomi');
      expect(settings.isConfigured, isTrue);
    });

    test('Mirakurun なら Mirakurun の URL', () {
      const settings = AppSettingsState(
        mirakurunBaseUrl: 'http://mirakurun',
        konomiBaseUrl: 'http://konomi',
      );
      expect(settings.activeBaseUrl, 'http://mirakurun');
    });
  });
}