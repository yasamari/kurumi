// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
///
/// ライブ視聴 (`/watch/:channelId`) だけはシェルの外側・root Navigator上に
/// 積む。ナビゲーション (Bar/Rail/Drawer) を表示しないため。

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
///
/// ライブ視聴 (`/watch/:channelId`) だけはシェルの外側・root Navigator上に
/// 積む。ナビゲーション (Bar/Rail/Drawer) を表示しないため。

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
  ///
  /// ライブ視聴 (`/watch/:channelId`) だけはシェルの外側・root Navigator上に
  /// 積む。ナビゲーション (Bar/Rail/Drawer) を表示しないため。
  AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'17a03a02975e8e8ef001ad4f7184fc36df74d5b3';
