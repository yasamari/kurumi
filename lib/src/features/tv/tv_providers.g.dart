// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。

@ProviderFor(nowOnAirChannels)
final nowOnAirChannelsProvider = NowOnAirChannelsProvider._();

/// 放送中チャンネル一覧。未設定時は [BackendUnconfiguredException] を送出し、
/// UI側で設定誘導表示に切り替える。

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

String _$nowOnAirChannelsHash() => r'43274cd2f3459814525dab9d3227f061f1ae30e0';
