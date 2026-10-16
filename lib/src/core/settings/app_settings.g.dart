// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
///
/// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
/// on/off、CM自動スキップ) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。
///
/// KonomiTV の画質 (テレビ/ビデオ × Wi-Fi/モバイル回線) もここに永続化する。
/// 再生開始時に現在の回線種別 ([NetworkTypeMonitor]) で選ぶ。

@ProviderFor(AppSettings)
final appSettingsProvider = AppSettingsProvider._();

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
///
/// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
/// on/off、CM自動スキップ) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。
///
/// KonomiTV の画質 (テレビ/ビデオ × Wi-Fi/モバイル回線) もここに永続化する。
/// 再生開始時に現在の回線種別 ([NetworkTypeMonitor]) で選ぶ。
final class AppSettingsProvider
    extends $AsyncNotifierProvider<AppSettings, AppSettingsState> {
  /// SharedPreferences backed のアプリ設定。
  ///
  /// バックエンド種別と種別ごとのベースURLを保持する。
  /// 切替時に再入力が不要になるよう両方のURLを保持する。
  ///
  /// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
  /// on/off、CM自動スキップ) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
  /// 初期値を作る ([AppSettingsState] の既定値参照)。
  ///
  /// KonomiTV の画質 (テレビ/ビデオ × Wi-Fi/モバイル回線) もここに永続化する。
  /// 再生開始時に現在の回線種別 ([NetworkTypeMonitor]) で選ぶ。
  AppSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  AppSettings create() => AppSettings();
}

String _$appSettingsHash() => r'f9a980d3307fcd09534555aeef98dbe688a85c16';

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
///
/// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
/// on/off、CM自動スキップ) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。
///
/// KonomiTV の画質 (テレビ/ビデオ × Wi-Fi/モバイル回線) もここに永続化する。
/// 再生開始時に現在の回線種別 ([NetworkTypeMonitor]) で選ぶ。

abstract class _$AppSettings extends $AsyncNotifier<AppSettingsState> {
  FutureOr<AppSettingsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AppSettingsState>, AppSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettingsState>, AppSettingsState>,
              AsyncValue<AppSettingsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
