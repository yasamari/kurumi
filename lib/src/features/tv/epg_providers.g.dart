// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// EPGキャッシュのデータベース。アプリ存続中は開きっぱなしにする。

@ProviderFor(epgDatabase)
final epgDatabaseProvider = EpgDatabaseProvider._();

/// EPGキャッシュのデータベース。アプリ存続中は開きっぱなしにする。

final class EpgDatabaseProvider
    extends $FunctionalProvider<EpgDatabase, EpgDatabase, EpgDatabase>
    with $Provider<EpgDatabase> {
  /// EPGキャッシュのデータベース。アプリ存続中は開きっぱなしにする。
  EpgDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'epgDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$epgDatabaseHash();

  @$internal
  @override
  $ProviderElement<EpgDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EpgDatabase create(Ref ref) {
    return epgDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EpgDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EpgDatabase>(value),
    );
  }
}

String _$epgDatabaseHash() => r'f590d95397a8477011e6fa0052f8a16616bf5d9e';

/// 視聴対象チャンネルの解決。EPGキャッシュのチャンネル行を one-shot で読む。
///
/// 時刻に依存しないため、テレビ欄の毎分再計算の影響を受けない。
/// 視聴中のプレイヤー作り直しを避けるにはここを噛ませること
/// ([liveStream] のコメント参照)。見つからなければ
/// [ChannelNotFoundException] を送出する。

@ProviderFor(mirakurunEpgChannel)
final mirakurunEpgChannelProvider = MirakurunEpgChannelFamily._();

/// 視聴対象チャンネルの解決。EPGキャッシュのチャンネル行を one-shot で読む。
///
/// 時刻に依存しないため、テレビ欄の毎分再計算の影響を受けない。
/// 視聴中のプレイヤー作り直しを避けるにはここを噛ませること
/// ([liveStream] のコメント参照)。見つからなければ
/// [ChannelNotFoundException] を送出する。

final class MirakurunEpgChannelProvider
    extends $FunctionalProvider<AsyncValue<Channel>, Channel, FutureOr<Channel>>
    with $FutureModifier<Channel>, $FutureProvider<Channel> {
  /// 視聴対象チャンネルの解決。EPGキャッシュのチャンネル行を one-shot で読む。
  ///
  /// 時刻に依存しないため、テレビ欄の毎分再計算の影響を受けない。
  /// 視聴中のプレイヤー作り直しを避けるにはここを噛ませること
  /// ([liveStream] のコメント参照)。見つからなければ
  /// [ChannelNotFoundException] を送出する。
  MirakurunEpgChannelProvider._({
    required MirakurunEpgChannelFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mirakurunEpgChannelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mirakurunEpgChannelHash();

  @override
  String toString() {
    return r'mirakurunEpgChannelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Channel> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Channel> create(Ref ref) {
    final argument = this.argument as String;
    return mirakurunEpgChannel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MirakurunEpgChannelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mirakurunEpgChannelHash() =>
    r'f016a9834e87ee497aba98bf9eea661ba484a7b6';

/// 視聴対象チャンネルの解決。EPGキャッシュのチャンネル行を one-shot で読む。
///
/// 時刻に依存しないため、テレビ欄の毎分再計算の影響を受けない。
/// 視聴中のプレイヤー作り直しを避けるにはここを噛ませること
/// ([liveStream] のコメント参照)。見つからなければ
/// [ChannelNotFoundException] を送出する。

final class MirakurunEpgChannelFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Channel>, String> {
  MirakurunEpgChannelFamily._()
    : super(
        retry: null,
        name: r'mirakurunEpgChannelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 視聴対象チャンネルの解決。EPGキャッシュのチャンネル行を one-shot で読む。
  ///
  /// 時刻に依存しないため、テレビ欄の毎分再計算の影響を受けない。
  /// 視聴中のプレイヤー作り直しを避けるにはここを噛ませること
  /// ([liveStream] のコメント参照)。見つからなければ
  /// [ChannelNotFoundException] を送出する。

  MirakurunEpgChannelProvider call(String channelId) =>
      MirakurunEpgChannelProvider._(argument: channelId, from: this);

  @override
  String toString() => r'mirakurunEpgChannelProvider';
}

/// Mirakurun EPGの同期状態。取得は使用中のバックエンドがMirakurunのときのみ。
///
/// - 鮮度内なら何もせず状態を返す (切替時の再取得防止)
/// - 期限切れ・未取得なら取得してDBを全置換する
/// - 接続先変更時は旧行を消してから取得する
/// - 取得失敗時は古いキャッシュがあればそれを返し、なければ例外を送出する
///   (UI側の既存エラー表示に載せる)
///
/// 次回更新時刻にタイマーを張り、自分を invalidate して再評価する。
/// KonomiTV 選択時は null を返し、何もしない。

@ProviderFor(mirakurunEpgSync)
final mirakurunEpgSyncProvider = MirakurunEpgSyncProvider._();

/// Mirakurun EPGの同期状態。取得は使用中のバックエンドがMirakurunのときのみ。
///
/// - 鮮度内なら何もせず状態を返す (切替時の再取得防止)
/// - 期限切れ・未取得なら取得してDBを全置換する
/// - 接続先変更時は旧行を消してから取得する
/// - 取得失敗時は古いキャッシュがあればそれを返し、なければ例外を送出する
///   (UI側の既存エラー表示に載せる)
///
/// 次回更新時刻にタイマーを張り、自分を invalidate して再評価する。
/// KonomiTV 選択時は null を返し、何もしない。

final class MirakurunEpgSyncProvider
    extends
        $FunctionalProvider<
          AsyncValue<EpgSyncState?>,
          EpgSyncState?,
          FutureOr<EpgSyncState?>
        >
    with $FutureModifier<EpgSyncState?>, $FutureProvider<EpgSyncState?> {
  /// Mirakurun EPGの同期状態。取得は使用中のバックエンドがMirakurunのときのみ。
  ///
  /// - 鮮度内なら何もせず状態を返す (切替時の再取得防止)
  /// - 期限切れ・未取得なら取得してDBを全置換する
  /// - 接続先変更時は旧行を消してから取得する
  /// - 取得失敗時は古いキャッシュがあればそれを返し、なければ例外を送出する
  ///   (UI側の既存エラー表示に載せる)
  ///
  /// 次回更新時刻にタイマーを張り、自分を invalidate して再評価する。
  /// KonomiTV 選択時は null を返し、何もしない。
  MirakurunEpgSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mirakurunEpgSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mirakurunEpgSyncHash();

  @$internal
  @override
  $FutureProviderElement<EpgSyncState?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EpgSyncState?> create(Ref ref) {
    return mirakurunEpgSync(ref);
  }
}

String _$mirakurunEpgSyncHash() => r'f5b1370570cfa51de2a3482fb0c6e8ba4cefb71e';
