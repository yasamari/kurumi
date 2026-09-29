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

@ProviderFor(backendDio)
final backendDioProvider = BackendDioProvider._();

/// 現在選択中バックエンド向けの Dio。
///
/// baseUrl は設定画面で正規化済みの値をそのまま使う。

final class BackendDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// 現在選択中バックエンド向けの Dio。
  ///
  /// baseUrl は設定画面で正規化済みの値をそのまま使う。
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

String _$backendDioHash() => r'ece28dfb94d4f304f33766a2381522ddb6c8738b';
