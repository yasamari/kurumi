// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 情報パネル (番組情報・実況コメント) の表示状態。
///
/// デスクトップでは映像を最大化するためにパネルを隠せる。モバイルは映像の下に
/// 表示されたままで切り離せないうえ、切替ボタンの載る標準コントロールも
/// デスクトップ用 ([isDesktopPlatform]) だけのため、常に表示のまま使う。
///
/// セッション中は保持する (keepAlive)。画面 (ライブ視聴・録画再生) を離れても
/// 次の視聴へ引き継がれる。**画面回転では消えない** — provider が持つため。
///
/// **値は [visible] を読む側だけが購読する。** 映像 (`PlayerVideoView`) を
/// 作り直さないため、購読は [PlayerSplitLayout] と切替ボタンの中に閉じる。
/// `ref.watch` するのは provider の**インスタンス**で、値を購読すると画面全体の
/// build が回って映像まで作り直される。

@ProviderFor(infoPanelVisibility)
final infoPanelVisibilityProvider = InfoPanelVisibilityProvider._();

/// 情報パネル (番組情報・実況コメント) の表示状態。
///
/// デスクトップでは映像を最大化するためにパネルを隠せる。モバイルは映像の下に
/// 表示されたままで切り離せないうえ、切替ボタンの載る標準コントロールも
/// デスクトップ用 ([isDesktopPlatform]) だけのため、常に表示のまま使う。
///
/// セッション中は保持する (keepAlive)。画面 (ライブ視聴・録画再生) を離れても
/// 次の視聴へ引き継がれる。**画面回転では消えない** — provider が持つため。
///
/// **値は [visible] を読む側だけが購読する。** 映像 (`PlayerVideoView`) を
/// 作り直さないため、購読は [PlayerSplitLayout] と切替ボタンの中に閉じる。
/// `ref.watch` するのは provider の**インスタンス**で、値を購読すると画面全体の
/// build が回って映像まで作り直される。

final class InfoPanelVisibilityProvider
    extends
        $FunctionalProvider<
          InfoPanelVisibility,
          InfoPanelVisibility,
          InfoPanelVisibility
        >
    with $Provider<InfoPanelVisibility> {
  /// 情報パネル (番組情報・実況コメント) の表示状態。
  ///
  /// デスクトップでは映像を最大化するためにパネルを隠せる。モバイルは映像の下に
  /// 表示されたままで切り離せないうえ、切替ボタンの載る標準コントロールも
  /// デスクトップ用 ([isDesktopPlatform]) だけのため、常に表示のまま使う。
  ///
  /// セッション中は保持する (keepAlive)。画面 (ライブ視聴・録画再生) を離れても
  /// 次の視聴へ引き継がれる。**画面回転では消えない** — provider が持つため。
  ///
  /// **値は [visible] を読む側だけが購読する。** 映像 (`PlayerVideoView`) を
  /// 作り直さないため、購読は [PlayerSplitLayout] と切替ボタンの中に閉じる。
  /// `ref.watch` するのは provider の**インスタンス**で、値を購読すると画面全体の
  /// build が回って映像まで作り直される。
  InfoPanelVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'infoPanelVisibilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$infoPanelVisibilityHash();

  @$internal
  @override
  $ProviderElement<InfoPanelVisibility> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InfoPanelVisibility create(Ref ref) {
    return infoPanelVisibility(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InfoPanelVisibility value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InfoPanelVisibility>(value),
    );
  }
}

String _$infoPanelVisibilityHash() =>
    r'908324ef1450a5923fc72ebef0c00e8081c4ed42';
