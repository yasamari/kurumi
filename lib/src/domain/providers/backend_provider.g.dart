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

/// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
///
/// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
/// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
/// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。

@ProviderFor(videoRepository)
final videoRepositoryProvider = VideoRepositoryProvider._();

/// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
///
/// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
/// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
/// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。

final class VideoRepositoryProvider
    extends
        $FunctionalProvider<VideoRepository, VideoRepository, VideoRepository>
    with $Provider<VideoRepository> {
  /// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
  ///
  /// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
  /// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
  /// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。
  VideoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoRepositoryHash();

  @$internal
  @override
  $ProviderElement<VideoRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideoRepository create(Ref ref) {
    return videoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoRepository>(value),
    );
  }
}

String _$videoRepositoryHash() => r'3148b2dc92b4a0c0b8efd20c7f07bf7f4cba2bb7';
