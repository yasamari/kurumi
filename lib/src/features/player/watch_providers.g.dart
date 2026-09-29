// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 視聴中の画質 (KonomiTV用)。永続化しない。既定は `original`。

@ProviderFor(WatchQuality)
final watchQualityProvider = WatchQualityProvider._();

/// 視聴中の画質 (KonomiTV用)。永続化しない。既定は `original`。
final class WatchQualityProvider
    extends $NotifierProvider<WatchQuality, String> {
  /// 視聴中の画質 (KonomiTV用)。永続化しない。既定は `original`。
  WatchQualityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchQualityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchQualityHash();

  @$internal
  @override
  WatchQuality create() => WatchQuality();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$watchQualityHash() => r'6a4cf75ac6389cc1ea0052061cd733a78247c65a';

/// 視聴中の画質 (KonomiTV用)。永続化しない。既定は `original`。

abstract class _$WatchQuality extends $Notifier<String> {
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

/// 指定チャンネルのライブストリーム情報。画質変更に追従する。
///
/// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
/// UI側で「見つかりません」表示に使う。

@ProviderFor(liveStream)
final liveStreamProvider = LiveStreamFamily._();

/// 指定チャンネルのライブストリーム情報。画質変更に追従する。
///
/// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
/// UI側で「見つかりません」表示に使う。

final class LiveStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<LiveStream>,
          LiveStream,
          FutureOr<LiveStream>
        >
    with $FutureModifier<LiveStream>, $FutureProvider<LiveStream> {
  /// 指定チャンネルのライブストリーム情報。画質変更に追従する。
  ///
  /// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
  /// UI側で「見つかりません」表示に使う。
  LiveStreamProvider._({
    required LiveStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'liveStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$liveStreamHash();

  @override
  String toString() {
    return r'liveStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LiveStream> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LiveStream> create(Ref ref) {
    final argument = this.argument as String;
    return liveStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LiveStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$liveStreamHash() => r'd8f6f3bb755f079f2ef680d0818a2828c7377509';

/// 指定チャンネルのライブストリーム情報。画質変更に追従する。
///
/// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
/// UI側で「見つかりません」表示に使う。

final class LiveStreamFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LiveStream>, String> {
  LiveStreamFamily._()
    : super(
        retry: null,
        name: r'liveStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 指定チャンネルのライブストリーム情報。画質変更に追従する。
  ///
  /// チャンネル解決は放送中一覧のキャッシュから行う。見つからなければ例外送出し、
  /// UI側で「見つかりません」表示に使う。

  LiveStreamProvider call(String channelId) =>
      LiveStreamProvider._(argument: channelId, from: this);

  @override
  String toString() => r'liveStreamProvider';
}
