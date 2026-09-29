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

@ProviderFor(AppSettings)
final appSettingsProvider = AppSettingsProvider._();

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。
final class AppSettingsProvider
    extends $AsyncNotifierProvider<AppSettings, AppSettingsState> {
  /// SharedPreferences backed のアプリ設定。
  ///
  /// バックエンド種別と種別ごとのベースURLを保持する。
  /// 切替時に再入力が不要になるよう両方のURLを保持する。
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

String _$appSettingsHash() => r'7ca377c6630b5f05fad9ab5bca6e2a0b3bd6a54e';

/// SharedPreferences backed のアプリ設定。
///
/// バックエンド種別と種別ごとのベースURLを保持する。
/// 切替時に再入力が不要になるよう両方のURLを保持する。

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
