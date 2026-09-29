// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
///
/// 新バックエンド追加時はこの switch に1行追加するだけ。

@ProviderFor(tvRepository)
final tvRepositoryProvider = TvRepositoryProvider._();

/// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
///
/// 新バックエンド追加時はこの switch に1行追加するだけ。

final class TvRepositoryProvider
    extends $FunctionalProvider<TvRepository, TvRepository, TvRepository>
    with $Provider<TvRepository> {
  /// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
  ///
  /// 新バックエンド追加時はこの switch に1行追加するだけ。
  TvRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tvRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tvRepositoryHash();

  @$internal
  @override
  $ProviderElement<TvRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TvRepository create(Ref ref) {
    return tvRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TvRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TvRepository>(value),
    );
  }
}

String _$tvRepositoryHash() => r'f0a0b0b298f57c0d00c572032aae6dccd5286f5c';
