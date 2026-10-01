// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
///
/// ライブ視聴 (`/watch/:channelId`) と録画再生 (`/videos/:videoId/play`) は
/// シェルの外側・root Navigator上に積む。ナビゲーション (Bar/Rail/Drawer)
/// を表示しないため。
///
/// Mirakurun 使用時はビデオ・録画予約へ遷移できない。ナビゲーションからは
/// 非表示にし、直リンク時は `/tv` へ戻す。

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
///
/// ライブ視聴 (`/watch/:channelId`) と録画再生 (`/videos/:videoId/play`) は
/// シェルの外側・root Navigator上に積む。ナビゲーション (Bar/Rail/Drawer)
/// を表示しないため。
///
/// Mirakurun 使用時はビデオ・録画予約へ遷移できない。ナビゲーションからは
/// 非表示にし、直リンク時は `/tv` へ戻す。

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// 5タブ構成のルーター。テレビ/ビデオ/番組表/録画予約/設定。
  ///
  /// ライブ視聴 (`/watch/:channelId`) と録画再生 (`/videos/:videoId/play`) は
  /// シェルの外側・root Navigator上に積む。ナビゲーション (Bar/Rail/Drawer)
  /// を表示しないため。
  ///
  /// Mirakurun 使用時はビデオ・録画予約へ遷移できない。ナビゲーションからは
  /// 非表示にし、直リンク時は `/tv` へ戻す。
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

String _$appRouterHash() => r'0db7b97aa19d1bf57583a00ac4a2c2004a8a9ec6';
