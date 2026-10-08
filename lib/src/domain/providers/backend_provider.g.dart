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
///
/// **接続先 (種別とベースURL) だけを選ぶ。** [appSettingsProvider] を丸ごと
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// リポジトリが作り直され、チャンネル一覧 → ライブストリームと伝って、視聴中の
/// プレイヤーまで作り直される (プレイヤーの破棄はセッションの切断を伴う)。
/// [videoRepository] と [backendDio] も同じ考えで接続先だけを見ている。

@ProviderFor(tvRepository)
final tvRepositoryProvider = TvRepositoryProvider._();

/// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
///
/// 新バックエンド追加時はこの switch に1行追加するだけ。
///
/// **接続先 (種別とベースURL) だけを選ぶ。** [appSettingsProvider] を丸ごと
/// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
/// リポジトリが作り直され、チャンネル一覧 → ライブストリームと伝って、視聴中の
/// プレイヤーまで作り直される (プレイヤーの破棄はセッションの切断を伴う)。
/// [videoRepository] と [backendDio] も同じ考えで接続先だけを見ている。

final class TvRepositoryProvider
    extends $FunctionalProvider<TvRepository, TvRepository, TvRepository>
    with $Provider<TvRepository> {
  /// 設定のバックエンド種別に応じた [TvRepository] を返す factory。
  ///
  /// 新バックエンド追加時はこの switch に1行追加するだけ。
  ///
  /// **接続先 (種別とベースURL) だけを選ぶ。** [appSettingsProvider] を丸ごと
  /// 購読すると、接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに
  /// リポジトリが作り直され、チャンネル一覧 → ライブストリームと伝って、視聴中の
  /// プレイヤーまで作り直される (プレイヤーの破棄はセッションの切断を伴う)。
  /// [videoRepository] と [backendDio] も同じ考えで接続先だけを見ている。
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

String _$tvRepositoryHash() => r'7b7ea5f7d9ca142978143f81f4c979d18b2c201b';

/// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
///
/// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
/// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
/// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。
///
/// [tvRepository] と同じく接続先だけを選ぶ。

@ProviderFor(videoRepository)
final videoRepositoryProvider = VideoRepositoryProvider._();

/// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
///
/// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
/// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
/// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。
///
/// [tvRepository] と同じく接続先だけを選ぶ。

final class VideoRepositoryProvider
    extends
        $FunctionalProvider<VideoRepository, VideoRepository, VideoRepository>
    with $Provider<VideoRepository> {
  /// ビデオ (録画番組) 用の [VideoRepository] を返す factory。
  ///
  /// 録画番組に対応するのはKonomiTVのみ。Mirakurun選択時は空URLのリポジトリを
  /// 返し、利用時に [BackendUnconfiguredException] として扱う。ビデオ画面自体は
  /// router の redirect で Mirakurun 時に `/tv` へ戻されるため、通常は到達しない。
  ///
  /// [tvRepository] と同じく接続先だけを選ぶ。
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

String _$videoRepositoryHash() => r'd270e459e9ddcbc789638463e676342404ab63b5';
