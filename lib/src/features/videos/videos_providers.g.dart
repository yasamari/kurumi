// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'videos_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ビデオ画面の検索キーワード。永続化しない。
///
/// 入力のたびに直接書き換えず、呼び出し側がデバウンスしてから [set] する。
/// 変更すると [videosListProvider] が1ページ目から取り直す。

@ProviderFor(VideosQuery)
final videosQueryProvider = VideosQueryProvider._();

/// ビデオ画面の検索キーワード。永続化しない。
///
/// 入力のたびに直接書き換えず、呼び出し側がデバウンスしてから [set] する。
/// 変更すると [videosListProvider] が1ページ目から取り直す。
final class VideosQueryProvider extends $NotifierProvider<VideosQuery, String> {
  /// ビデオ画面の検索キーワード。永続化しない。
  ///
  /// 入力のたびに直接書き換えず、呼び出し側がデバウンスしてから [set] する。
  /// 変更すると [videosListProvider] が1ページ目から取り直す。
  VideosQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videosQueryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videosQueryHash();

  @$internal
  @override
  VideosQuery create() => VideosQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$videosQueryHash() => r'92d8c257c3d23b559e2208bbbf7c264b9272f28e';

/// ビデオ画面の検索キーワード。永続化しない。
///
/// 入力のたびに直接書き換えず、呼び出し側がデバウンスしてから [set] する。
/// 変更すると [videosListProvider] が1ページ目から取り直す。

abstract class _$VideosQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// ビデオ画面の並び順。永続化しない。既定は新しい順。

@ProviderFor(VideosOrder)
final videosOrderProvider = VideosOrderProvider._();

/// ビデオ画面の並び順。永続化しない。既定は新しい順。
final class VideosOrderProvider
    extends $NotifierProvider<VideosOrder, VideoSortOrder> {
  /// ビデオ画面の並び順。永続化しない。既定は新しい順。
  VideosOrderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videosOrderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videosOrderHash();

  @$internal
  @override
  VideosOrder create() => VideosOrder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoSortOrder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoSortOrder>(value),
    );
  }
}

String _$videosOrderHash() => r'499222d7a22ee12c6dda6e12b7f95385bb3c137e';

/// ビデオ画面の並び順。永続化しない。既定は新しい順。

abstract class _$VideosOrder extends $Notifier<VideoSortOrder> {
  VideoSortOrder build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VideoSortOrder, VideoSortOrder>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VideoSortOrder, VideoSortOrder>,
              VideoSortOrder,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// ビデオ画面で選択中の録画番組 ID。永続化しない。
///
/// Compose の `ThreePaneScaffoldNavigator` の `contentKey` に相当する。
/// 広幅2ペイン時の詳細表示と狭幅プッシュ遷移 (`/videos/:id`) の両方で使い、
/// 回転・再訪でも選択を保つため keepAlive にする。

@ProviderFor(SelectedVideoId)
final selectedVideoIdProvider = SelectedVideoIdProvider._();

/// ビデオ画面で選択中の録画番組 ID。永続化しない。
///
/// Compose の `ThreePaneScaffoldNavigator` の `contentKey` に相当する。
/// 広幅2ペイン時の詳細表示と狭幅プッシュ遷移 (`/videos/:id`) の両方で使い、
/// 回転・再訪でも選択を保つため keepAlive にする。
final class SelectedVideoIdProvider
    extends $NotifierProvider<SelectedVideoId, int?> {
  /// ビデオ画面で選択中の録画番組 ID。永続化しない。
  ///
  /// Compose の `ThreePaneScaffoldNavigator` の `contentKey` に相当する。
  /// 広幅2ペイン時の詳細表示と狭幅プッシュ遷移 (`/videos/:id`) の両方で使い、
  /// 回転・再訪でも選択を保つため keepAlive にする。
  SelectedVideoIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedVideoIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedVideoIdHash();

  @$internal
  @override
  SelectedVideoId create() => SelectedVideoId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$selectedVideoIdHash() => r'572379b79feec9da9c4bbae92e5c369dcf6943f8';

/// ビデオ画面で選択中の録画番組 ID。永続化しない。
///
/// Compose の `ThreePaneScaffoldNavigator` の `contentKey` に相当する。
/// 広幅2ペイン時の詳細表示と狭幅プッシュ遷移 (`/videos/:id`) の両方で使い、
/// 回転・再訪でも選択を保つため keepAlive にする。

abstract class _$SelectedVideoId extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 録画番組一覧。検索・並び順の変更で1ページ目から取り直す。

@ProviderFor(VideosList)
final videosListProvider = VideosListProvider._();

/// 録画番組一覧。検索・並び順の変更で1ページ目から取り直す。
final class VideosListProvider
    extends $AsyncNotifierProvider<VideosList, VideosListState> {
  /// 録画番組一覧。検索・並び順の変更で1ページ目から取り直す。
  VideosListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videosListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videosListHash();

  @$internal
  @override
  VideosList create() => VideosList();
}

String _$videosListHash() => r'043edfcc086040c357119c43af0915bd64dc8de7';

/// 録画番組一覧。検索・並び順の変更で1ページ目から取り直す。

abstract class _$VideosList extends $AsyncNotifier<VideosListState> {
  FutureOr<VideosListState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<VideosListState>, VideosListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideosListState>, VideosListState>,
              AsyncValue<VideosListState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 録画番組1件の詳細。一覧キャッシュにあればそれを使い、なければ取得する。

@ProviderFor(videoDetail)
final videoDetailProvider = VideoDetailFamily._();

/// 録画番組1件の詳細。一覧キャッシュにあればそれを使い、なければ取得する。

final class VideoDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<VideoProgram>,
          VideoProgram,
          FutureOr<VideoProgram>
        >
    with $FutureModifier<VideoProgram>, $FutureProvider<VideoProgram> {
  /// 録画番組1件の詳細。一覧キャッシュにあればそれを使い、なければ取得する。
  VideoDetailProvider._({
    required VideoDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'videoDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoDetailHash();

  @override
  String toString() {
    return r'videoDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<VideoProgram> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VideoProgram> create(Ref ref) {
    final argument = this.argument as int;
    return videoDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoDetailHash() => r'4831f92db624cafc1b0031a043e85c9be3752139';

/// 録画番組1件の詳細。一覧キャッシュにあればそれを使い、なければ取得する。

final class VideoDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VideoProgram>, int> {
  VideoDetailFamily._()
    : super(
        retry: null,
        name: r'videoDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 録画番組1件の詳細。一覧キャッシュにあればそれを使い、なければ取得する。

  VideoDetailProvider call(int videoId) =>
      VideoDetailProvider._(argument: videoId, from: this);

  @override
  String toString() => r'videoDetailProvider';
}

/// 録画再生中の画質。永続化しない。既定は `1080p`。
///
/// HLSでは `original` を選べないため、選択時はダウンロード再生になる。
/// 再生画面を離れても保持する (keepAlive)。画質切替でプレイヤーを作り直す
/// ときに初期値に戻らないようにするため。

@ProviderFor(VideoPlayQuality)
final videoPlayQualityProvider = VideoPlayQualityProvider._();

/// 録画再生中の画質。永続化しない。既定は `1080p`。
///
/// HLSでは `original` を選べないため、選択時はダウンロード再生になる。
/// 再生画面を離れても保持する (keepAlive)。画質切替でプレイヤーを作り直す
/// ときに初期値に戻らないようにするため。
final class VideoPlayQualityProvider
    extends $NotifierProvider<VideoPlayQuality, String> {
  /// 録画再生中の画質。永続化しない。既定は `1080p`。
  ///
  /// HLSでは `original` を選べないため、選択時はダウンロード再生になる。
  /// 再生画面を離れても保持する (keepAlive)。画質切替でプレイヤーを作り直す
  /// ときに初期値に戻らないようにするため。
  VideoPlayQualityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoPlayQualityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoPlayQualityHash();

  @$internal
  @override
  VideoPlayQuality create() => VideoPlayQuality();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$videoPlayQualityHash() => r'2c9219392874a353e16338e3adc646da25ae3d86';

/// 録画再生中の画質。永続化しない。既定は `1080p`。
///
/// HLSでは `original` を選べないため、選択時はダウンロード再生になる。
/// 再生画面を離れても保持する (keepAlive)。画質切替でプレイヤーを作り直す
/// ときに初期値に戻らないようにするため。

abstract class _$VideoPlayQuality extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 録画再生画面の情報タブ。永続化しない。0=番組情報、1=コメント。
///
/// 再生画面の `Row` / `Column` 切り替えの内側にあるため、選択を保つには
/// この keepAlive provider が持つ必要がある (ライブの
/// `watchInfoTabProvider` と同様)。

@ProviderFor(VideoInfoTab)
final videoInfoTabProvider = VideoInfoTabProvider._();

/// 録画再生画面の情報タブ。永続化しない。0=番組情報、1=コメント。
///
/// 再生画面の `Row` / `Column` 切り替えの内側にあるため、選択を保つには
/// この keepAlive provider が持つ必要がある (ライブの
/// `watchInfoTabProvider` と同様)。
final class VideoInfoTabProvider extends $NotifierProvider<VideoInfoTab, int> {
  /// 録画再生画面の情報タブ。永続化しない。0=番組情報、1=コメント。
  ///
  /// 再生画面の `Row` / `Column` 切り替えの内側にあるため、選択を保つには
  /// この keepAlive provider が持つ必要がある (ライブの
  /// `watchInfoTabProvider` と同様)。
  VideoInfoTabProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoInfoTabProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoInfoTabHash();

  @$internal
  @override
  VideoInfoTab create() => VideoInfoTab();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$videoInfoTabHash() => r'b1b7356b28ddfde38c7bf64a7f7f88cdb52ca1f3';

/// 録画再生画面の情報タブ。永続化しない。0=番組情報、1=コメント。
///
/// 再生画面の `Row` / `Column` 切り替えの内側にあるため、選択を保つには
/// この keepAlive provider が持つ必要がある (ライブの
/// `watchInfoTabProvider` と同様)。

abstract class _$VideoInfoTab extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
