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
/// on/off) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。

@ProviderFor(AppSettings)
final appSettingsProvider = AppSettingsProvider._();

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
///
/// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
/// on/off) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。
final class AppSettingsProvider
    extends $AsyncNotifierProvider<AppSettings, AppSettingsState> {
  /// SharedPreferences backed のアプリ設定。
  ///
  /// バックエンド種別と種別ごとのベースURLを保持する。
  /// 切替時に再入力が不要になるよう両方のURLを保持する。
  ///
  /// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
  /// on/off) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
  /// 初期値を作る ([AppSettingsState] の既定値参照)。
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

String _$appSettingsHash() => r'9094fd798b7358da7d013276aa435a3ed48c9c12';

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
///
/// プレイヤー側の表示設定 (弾幕の on/off・文字サイズ・不透明度・速度、字幕の
/// on/off) もここに永続化する。プレイヤーは開くたびにこのスナップショットから
/// 初期値を作る ([AppSettingsState] の既定値参照)。

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
