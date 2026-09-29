import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/backend_type.dart';
import 'app_settings_state.dart';

part 'app_settings.g.dart';

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  static const _keyBackendType = 'backend_type';
  static const _keyMirakurunBaseUrl = 'mirakurun_base_url';
  static const _keyKonomiBaseUrl = 'konomi_base_url';

  @override
  Future<AppSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsState(
      backendType:
          BackendType.fromName(prefs.getString(_keyBackendType)),
      mirakurunBaseUrl: prefs.getString(_keyMirakurunBaseUrl) ?? '',
      konomiBaseUrl: prefs.getString(_keyKonomiBaseUrl) ?? '',
    );
  }

  Future<void> setBackendType(BackendType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendType, type.name);
    final current = await future;
    state = AsyncData(current.copyWith(backendType: type));
  }

  Future<void> setMirakurunBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMirakurunBaseUrl, url);
    final current = await future;
    state = AsyncData(current.copyWith(mirakurunBaseUrl: url));
  }

  Future<void> setKonomiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKonomiBaseUrl, url);
    final current = await future;
    state = AsyncData(current.copyWith(konomiBaseUrl: url));
  }
}
