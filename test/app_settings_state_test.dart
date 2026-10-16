import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/network/network_type.dart';
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

    test('CM自動スキップは既定で無効', () {
      const settings = AppSettingsState();
      expect(settings.cmAutoSkipEnabled, isFalse);
      expect(
        settings.copyWith(cmAutoSkipEnabled: true).cmAutoSkipEnabled,
        isTrue,
      );
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
      expect(
        settings.copyWith(subtitlesEnabled: true).subtitlesEnabled,
        isTrue,
      );
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

  group('Mirakurunの更新間隔', () {
    test('既定は6時間', () {
      const settings = AppSettingsState();
      expect(settings.mirakurunEpgRefreshIntervalHours, 6);
      expect(
        settings
            .copyWith(mirakurunEpgRefreshIntervalHours: 12)
            .mirakurunEpgRefreshIntervalHours,
        12,
      );
    });

    test('1〜24時間に丸める', () {
      expect(clampMirakurunEpgRefreshIntervalHours(6), 6);
      expect(clampMirakurunEpgRefreshIntervalHours(1), 1);
      expect(clampMirakurunEpgRefreshIntervalHours(24), 24);
      expect(clampMirakurunEpgRefreshIntervalHours(0), 1);
      expect(clampMirakurunEpgRefreshIntervalHours(-3), 1);
      expect(clampMirakurunEpgRefreshIntervalHours(25), 24);
    });
  });

  group('画質設定', () {
    test('既定は Wi-Fi=original・モバイル=480p', () {
      const settings = AppSettingsState();
      expect(settings.konomiLiveQualityWifi, 'original');
      expect(settings.konomiLiveQualityMobile, '480p');
      expect(settings.konomiVideoQualityWifi, 'original');
      expect(settings.konomiVideoQualityMobile, '480p');
    });

    test('回線種別ごとの画質を返す', () {
      const settings = AppSettingsState(
        konomiLiveQualityWifi: '1080p',
        konomiLiveQualityMobile: '360p',
        konomiVideoQualityWifi: '720p',
        konomiVideoQualityMobile: '240p',
      );
      expect(settings.konomiLiveQualityFor(NetworkType.wifi), '1080p');
      expect(settings.konomiLiveQualityFor(NetworkType.mobile), '360p');
      expect(settings.konomiVideoQualityFor(NetworkType.wifi), '720p');
      expect(settings.konomiVideoQualityFor(NetworkType.mobile), '240p');
    });

    test('copyWith で画質4項目を差し替える', () {
      const settings = AppSettingsState();
      final updated = settings.copyWith(
        konomiLiveQualityWifi: '1080p',
        konomiLiveQualityMobile: '360p',
        konomiVideoQualityWifi: '720p',
        konomiVideoQualityMobile: '240p',
      );
      expect(updated.konomiLiveQualityWifi, '1080p');
      expect(updated.konomiLiveQualityMobile, '360p');
      expect(updated.konomiVideoQualityWifi, '720p');
      expect(updated.konomiVideoQualityMobile, '240p');
      // 指定しない項目は元のまま。
      expect(updated.backendType, settings.backendType);
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
