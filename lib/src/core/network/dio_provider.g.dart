// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 現在選択中バックエンド向けの Dio。
///
/// baseUrl は設定画面で正規化済みの値をそのまま使う。
///
/// **ベースURLだけを選択する。** `appSettingsProvider` を丸ごと購読すると、
/// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに Dio  ->
/// `TvRepository` -> チャンネル一覧 -> ライブストリーム が作り直され、
/// 視聴中のプレイヤーが作り直される。

@ProviderFor(backendDio)
final backendDioProvider = BackendDioProvider._();

/// 現在選択中バックエンド向けの Dio。
///
/// baseUrl は設定画面で正規化済みの値をそのまま使う。
///
/// **ベースURLだけを選択する。** `appSettingsProvider` を丸ごと購読すると、
/// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに Dio  ->
/// `TvRepository` -> チャンネル一覧 -> ライブストリーム が作り直され、
/// 視聴中のプレイヤーが作り直される。

final class BackendDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// 現在選択中バックエンド向けの Dio。
  ///
  /// baseUrl は設定画面で正規化済みの値をそのまま使う。
  ///
  /// **ベースURLだけを選択する。** `appSettingsProvider` を丸ごと購読すると、
  /// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに Dio  ->
  /// `TvRepository` -> チャンネル一覧 -> ライブストリーム が作り直され、
  /// 視聴中のプレイヤーが作り直される。
  BackendDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendDioProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return backendDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$backendDioHash() => r'5c4216437ffad304b97f8bdb893b7e5ccc0ee184';
