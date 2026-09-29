import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../settings/app_settings.dart';
import '../settings/app_settings_state.dart';

part 'dio_provider.g.dart';

/// 現在選択中バックエンド向けの Dio。
///
/// baseUrl は設定画面で正規化済みの値をそのまま使う。
@riverpod
Dio backendDio(Ref ref) {
  final settings =
      ref.watch(appSettingsProvider).value ?? const AppSettingsState();
  return Dio(
    BaseOptions(
      baseUrl: settings.activeBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}
