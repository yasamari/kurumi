import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kurumi/src/core/network/dio_provider.dart';
import 'package:kurumi/src/core/settings/app_settings.dart';
import 'package:kurumi/src/domain/entities/backend_type.dart';
import 'package:kurumi/src/domain/providers/backend_provider.dart';

/// 接続先と無関係な設定 (弾幕・字幕の表示設定) を変えても、接続先を見る
/// provider が作り直されないことを保証する。
///
/// 作り直されると `Dio` -> `TvRepository` -> 放送中チャンネル一覧 -> ライブ
/// ストリームと伝って、視聴画面は読み込み表示になり、**視聴中のプレイヤー
/// (mpv とセッション) ごと破棄される**。弾幕スライダーを1つ動かすたびに映像が
/// 作り直される后果になる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer openContainer({
    String backendType = 'mirakurun',
    String mirakurunBaseUrl = 'http://192.0.2.1:40772',
  }) {
    SharedPreferences.setMockInitialValues({
      'backend_type': backendType,
      'mirakurun_base_url': mirakurunBaseUrl,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('弾幕の表示設定だけを変えても Dio とリポジトリは作り直されない', () async {
    final container = openContainer();
    await container.read(appSettingsProvider.future);

    final dio = container.read(backendDioProvider);
    final tvRepository = container.read(tvRepositoryProvider);
    final videoRepository = container.read(videoRepositoryProvider);

    final notifier = container.read(appSettingsProvider.notifier);
    await notifier.setDanmakuPreferences(
      enabled: false,
      fontSize: 32,
      opacity: 0.5,
      speed: 1.5,
    );
    await notifier.setSubtitlesEnabled(true);

    expect(identical(container.read(backendDioProvider), dio), isTrue);
    expect(identical(container.read(tvRepositoryProvider), tvRepository), isTrue);
    expect(
      identical(container.read(videoRepositoryProvider), videoRepository),
      isTrue,
    );
    // 保存自体は反映されている。
    final settings = container.read(appSettingsProvider).value!;
    expect(settings.danmakuEnabled, isFalse);
    expect(settings.danmakuFontSize, 32);
    expect(settings.subtitlesEnabled, isTrue);
  });

  test('EPG更新間隔だけを変えても Dio とリポジトリは作り直されない', () async {
    final container = openContainer();
    await container.read(appSettingsProvider.future);

    final dio = container.read(backendDioProvider);
    final tvRepository = container.read(tvRepositoryProvider);
    final videoRepository = container.read(videoRepositoryProvider);

    await container
        .read(appSettingsProvider.notifier)
        .setEpgRefreshIntervalHours(12);

    expect(identical(container.read(backendDioProvider), dio), isTrue);
    expect(identical(container.read(tvRepositoryProvider), tvRepository), isTrue);
    expect(
      identical(container.read(videoRepositoryProvider), videoRepository),
      isTrue,
    );
    // 保存自体は反映されている (範囲外は丸める)。
    expect(
      container.read(appSettingsProvider).value!.epgRefreshIntervalHours,
      12,
    );
    await container
        .read(appSettingsProvider.notifier)
        .setEpgRefreshIntervalHours(99);
    expect(
      container.read(appSettingsProvider).value!.epgRefreshIntervalHours,
      24,
    );
  });

  test('バックエンドのベースURLを変えると Dio とリポジトリは作り直される', () async {
    final container = openContainer();
    await container.read(appSettingsProvider.future);

    final dio = container.read(backendDioProvider);
    final tvRepository = container.read(tvRepositoryProvider);

    await container
        .read(appSettingsProvider.notifier)
        .setMirakurunBaseUrl('http://192.0.2.2:40772');

    final nextDio = container.read(backendDioProvider);
    expect(identical(nextDio, dio), isFalse);
    expect(nextDio.options.baseUrl, 'http://192.0.2.2:40772');
    expect(identical(container.read(tvRepositoryProvider), tvRepository), isFalse);
  });

  test('バックエンド種別を変えるとリポジトリの向き先が変わる', () async {
    final container = openContainer(
      backendType: BackendType.konomiTv.name,
      mirakurunBaseUrl: 'http://192.0.2.1:40772',
    );
    await container.read(appSettingsProvider.future);
    final repository = container.read(tvRepositoryProvider);

    // KonomiTV のベースURLを設定すると、種別がMirakurunでもKonomiTVの
    // 接続先へ切り替わる (activeBaseUrl に従う)。
    await container
        .read(appSettingsProvider.notifier)
        .setKonomiBaseUrl('http://192.0.2.3:10000');

    expect(identical(container.read(tvRepositoryProvider), repository), isFalse);
    expect(
      container.read(backendDioProvider).options.baseUrl,
      'http://192.0.2.3:10000',
    );
  });
}