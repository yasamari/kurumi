import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/backend_type.dart';
import 'app_settings_state.dart';

part 'app_settings.g.dart';

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
///
/// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
/// on/off、CM自動スキップ) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。
@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  static const _keyBackendType = 'backend_type';
  static const _keyMirakurunBaseUrl = 'mirakurun_base_url';
  static const _keyKonomiBaseUrl = 'konomi_base_url';
  static const _keyDanmakuEnabled = 'danmaku_enabled';
  static const _keyDanmakuFontSize = 'danmaku_font_size';
  static const _keyDanmakuOpacity = 'danmaku_opacity';
  static const _keyDanmakuSpeed = 'danmaku_speed';
  static const _keySubtitlesEnabled = 'subtitles_enabled';
  static const _keyCmAutoSkipEnabled = 'cm_auto_skip_enabled';
  static const _keyEpgRefreshIntervalHours = 'epg_refresh_interval_hours';

  @override
  Future<AppSettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsState(
      backendType:
          BackendType.fromName(prefs.getString(_keyBackendType)),
      mirakurunBaseUrl: prefs.getString(_keyMirakurunBaseUrl) ?? '',
      konomiBaseUrl: prefs.getString(_keyKonomiBaseUrl) ?? '',
      danmakuEnabled:
          prefs.getBool(_keyDanmakuEnabled) ??
          AppSettingsState.defaultDanmakuEnabled,
      danmakuFontSize:
          prefs.getDouble(_keyDanmakuFontSize) ??
          AppSettingsState.defaultDanmakuFontSize,
      danmakuOpacity:
          prefs.getDouble(_keyDanmakuOpacity) ??
          AppSettingsState.defaultDanmakuOpacity,
      danmakuSpeed:
          prefs.getDouble(_keyDanmakuSpeed) ??
          AppSettingsState.defaultDanmakuSpeed,
      subtitlesEnabled:
          prefs.getBool(_keySubtitlesEnabled) ??
          AppSettingsState.defaultSubtitlesEnabled,
      cmAutoSkipEnabled:
          prefs.getBool(_keyCmAutoSkipEnabled) ??
          AppSettingsState.defaultCmAutoSkipEnabled,
      epgRefreshIntervalHours: clampEpgRefreshIntervalHours(
        prefs.getInt(_keyEpgRefreshIntervalHours) ??
            AppSettingsState.defaultEpgRefreshIntervalHours,
      ),
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

  /// 弾幕の表示設定 (on/off と文字サイズ・不透明度・速度) をまとめて保存する。
  ///
  /// スライダーは1項目しか動かないのに4キー書くが、状態の更新は1回にまとめ
  /// られる。読み戻して書き戻すことはしない (呼び出し側が現在の値を持つ)。
  Future<void> setDanmakuPreferences({
    required bool enabled,
    required double fontSize,
    required double opacity,
    required double speed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDanmakuEnabled, enabled);
    await prefs.setDouble(_keyDanmakuFontSize, fontSize);
    await prefs.setDouble(_keyDanmakuOpacity, opacity);
    await prefs.setDouble(_keyDanmakuSpeed, speed);
    final current = await future;
    state = AsyncData(
      current.copyWith(
        danmakuEnabled: enabled,
        danmakuFontSize: fontSize,
        danmakuOpacity: opacity,
        danmakuSpeed: speed,
      ),
    );
  }

  /// 字幕の表示を保存する。
  Future<void> setSubtitlesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySubtitlesEnabled, enabled);
    final current = await future;
    state = AsyncData(current.copyWith(subtitlesEnabled: enabled));
  }

  /// CM自動スキップの on/off を保存する。既定は無効。
  Future<void> setCmAutoSkipEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCmAutoSkipEnabled, enabled);
    final current = await future;
    state = AsyncData(current.copyWith(cmAutoSkipEnabled: enabled));
  }

  /// EPGキャッシュの更新間隔 (時間) を保存する。範囲外は1〜24に丸める。
  Future<void> setEpgRefreshIntervalHours(int hours) async {
    final clamped = clampEpgRefreshIntervalHours(hours);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEpgRefreshIntervalHours, clamped);
    final current = await future;
    state = AsyncData(current.copyWith(epgRefreshIntervalHours: clamped));
  }
}