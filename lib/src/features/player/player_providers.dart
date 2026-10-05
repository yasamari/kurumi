import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player_providers.g.dart';

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
@Riverpod(keepAlive: true)
InfoPanelVisibility infoPanelVisibility(Ref ref) {
  final visibility = InfoPanelVisibility();
  ref.onDispose(visibility.dispose);
  return visibility;
}

/// 情報パネルの表示状態 ([infoPanelVisibilityProvider] の値)。
class InfoPanelVisibility {
  InfoPanelVisibility({bool visible = true})
    : _visible = ValueNotifier(visible);

  final ValueNotifier<bool> _visible;

  /// 表示状態の通知元。購読はレイアウトと切替ボタンだけが行う。
  ValueListenable<bool> get visible => _visible;

  /// いまパネルを表示しているか。
  bool get isVisible => _visible.value;

  /// 表示と非表示を切り替える。
  void toggle() => _visible.value = !_visible.value;

  void dispose() => _visible.dispose();
}
