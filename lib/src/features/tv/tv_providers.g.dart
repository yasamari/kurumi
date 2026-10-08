// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。
///
/// KonomiTV はリポジトリから都度取得する。Mirakurun はEPGキャッシュから
/// 組み立てる (通信なし)。Mirakurun の表示は時刻の進行でのみ再計算される。
///
/// **設定の有無だけを選ぶ。** [appSettingsProvider.future] をそのまま購読すると、
/// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに future の
/// インスタンスが変わって取り直しが始まり、視聴中のプレイヤーが作り直される。

@ProviderFor(nowOnAirChannels)
final nowOnAirChannelsProvider = NowOnAirChannelsProvider._();

/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。
///
/// KonomiTV はリポジトリから都度取得する。Mirakurun はEPGキャッシュから
/// 組み立てる (通信なし)。Mirakurun の表示は時刻の進行でのみ再計算される。
///
/// **設定の有無だけを選ぶ。** [appSettingsProvider.future] をそのまま購読すると、
/// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに future の
/// インスタンスが変わって取り直しが始まり、視聴中のプレイヤーが作り直される。

final class NowOnAirChannelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChannelItem>>,
          List<ChannelItem>,
          FutureOr<List<ChannelItem>>
        >
    with
        $FutureModifier<List<ChannelItem>>,
        $FutureProvider<List<ChannelItem>> {
  /// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
  /// UI側で設定誘導表示に切り替える。
  ///
  /// KonomiTV はリポジトリから都度取得する。Mirakurun はEPGキャッシュから
  /// 組み立てる (通信なし)。Mirakurun の表示は時刻の進行でのみ再計算される。
  ///
  /// **設定の有無だけを選ぶ。** [appSettingsProvider.future] をそのまま購読すると、
  /// 接続先と無関係な設定 (弾幕・字幕の表示設定など) を変えるたびに future の
  /// インスタンスが変わって取り直しが始まり、視聴中のプレイヤーが作り直される。
  NowOnAirChannelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nowOnAirChannelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nowOnAirChannelsHash();

  @$internal
  @override
  $FutureProviderElement<List<ChannelItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChannelItem>> create(Ref ref) {
    return nowOnAirChannels(ref);
  }
}

String _$nowOnAirChannelsHash() => r'7c7d59ac5e542118fe287515eee35373bdeb683f';
