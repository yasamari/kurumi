import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 横画面での情報パネルの幅。
const double playerPanelWidth = 400.0;

/// 縦画面での映像のアスペクト比。
const double playerVideoAspectRatio = 16 / 9;

/// 矩形。横・縦位置と大きさ。
typedef PlayerRect = ({
  double left,
  double top,
  double width,
  double height,
});

/// 映像と情報パネルの配置を求める。
///
/// 横画面は映像の右に情報パネル (幅 [playerPanelWidth]) を置く。縦画面は映像
/// (16:9) を上に、その下に情報パネルを置く。
///
/// 縦画面で映像の高さが画面の高さを超える場合は高さを詰める。矩形制約を渡す
/// `Positioned` のままだとパネルが負の高さになり、はみ出してオーバーフロー
/// する。パネル幅も画面幅で打ち切る。
///
/// [pictureInPicture] は Android の PiP ウィンドウ。通常画面より数倍小さいので
/// 映像を全面に広げ、パネルは表示しない。**横画面の通常の計算だと PiP ウィンドウ
/// はパネル幅 ([playerPanelWidth]) 以下なので映像幅が 0 になってしまう**ため、
/// 向きより先にこちらで判定する。
///
/// [infoVisible] は情報パネルの表示可否。false のときも PiP と同じく映像を全面に
/// 広げ、パネルは表示しない。
///
/// 向きでも PiP でも親ウィジェットの型は変えない (要素を作り直させない)。
({PlayerRect video, PlayerRect info}) playerSplitRects({
  required bool isLandscape,
  required double width,
  required double height,
  bool pictureInPicture = false,
  bool infoVisible = true,
}) {
  if (pictureInPicture || !infoVisible) {
    return (
      video: (left: 0, top: 0, width: width, height: height),
      info: (left: 0, top: 0, width: 0, height: 0),
    );
  }
  final panelWidth = math.min(playerPanelWidth, width);
  final videoWidth = isLandscape ? width - panelWidth : width;
  final videoHeight = isLandscape
      ? height
      : math.min(width / playerVideoAspectRatio, height);
  return (
    video: (left: 0, top: 0, width: videoWidth, height: videoHeight),
    info: (
      left: isLandscape ? videoWidth : 0.0,
      top: isLandscape ? 0.0 : videoHeight,
      width: isLandscape ? panelWidth : width,
      height: isLandscape ? height : math.max(0.0, height - videoHeight),
    ),
  );
}

/// 映像と情報パネルを並べる土台。横画面は左右、縦画面は上下。
///
/// **映像の親は向きでも PiP でも変えない。** `Row` と `Column` で出し分けると、
/// ウィジェットの型が変わった時点でその下の Element がすべて作り直される。
/// `_LivePlayer` / `_VideoPlayer` は映像スロットの中に置かれており、向きが変わると
/// State ごと破棄される。State が持つ `Player` と再生セッション ([LiveSession]) は
/// そこで解放され、作り直しになる (PSI 取得とライブ追従の中断。実況コメントの
/// 接続だけ [_WatchLayoutState] 側の持ちなので保たれる)。
///
/// これが media_kit のフルスクリーンで黒画面になる直接の原因になる。フルスクリー
/// ンは先に `Navigator` へ**同じ `VideoController` を使う新しい `Video`** を積む
/// (`enterFullscreen`)。その後に向きが変わると、通常側は破棄されて新しい `Player`
/// で開き直すが、フルスクリーン側は破棄済みの `VideoController` を参照したままに
/// なる。結果として映像は黒く止まり、音声だけは作り直された `Player` から出る。
/// フルスクリーンから戻るとルートの pop で通常側の新しい `Player` が見えるので
/// 復活する、という症状になる。画面回転だけでも映像が作り直される。
///
/// そのため `Stack` + `Positioned` で親と並び順を固定し、矩形だけ
/// [playerSplitRects] で変える。`SafeArea` も有効辺を切り替えるだけにして、
/// 向きや PiP によってウィジェット自身を出し分けない。
class PlayerSplitLayout extends StatelessWidget {
  const PlayerSplitLayout({
    super.key,
    required this.video,
    required this.info,
    this.pictureInPicture = false,
    this.infoVisible,
  });

  /// 映像。レターボックス (黒帯・柱状) は黒で塗る。
  final Widget video;

  /// 情報パネル。表示しないときは描かない (矩形も 0 になる)。
  final Widget info;

  /// Android の PiP ウィンドウにいるか。映像を全面に広げる。
  final bool pictureInPicture;

  /// 情報パネルの表示状態の通知元。null なら常に表示。
  ///
  /// **購読はここ (このウィジェット) で行う。画面側で購読すると画面全体の
  /// build が回り、直下の `video` が新しいウィジェットインスタンスになって映像
  /// ([PlayerVideoView]) まで作り直される** (controls ビルダーが差し替わり mpv の
  /// 表示パラメータ通知が飛ぶ)。ここで購読すれば `video` は同じインスタンスの
  /// ままなので映像には触れない (`Element.updateChild` が同一インスタンスで
  /// 短絡する)。
  ///
  /// **デスクトップ平台的だけ従う。** モバイルは情報パネルが映像の下に常に
  /// 見えて切り離せないうえ、切り替えボタンを載せる標準コントロール
  /// (`AdaptiveVideoControls` のプラットフォーム判定) もデスクトップ用しか
  /// ないので、モバイルでは常に表示のままにする。
  final ValueListenable<bool>? infoVisible;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final pictureInPicture = this.pictureInPicture;
    final info = this.info;
    final video = this.video;
    final visibility =
        isDesktopPlatform(context) ? infoVisible : null;

    Widget layout(bool infoVisible) => LayoutBuilder(
      builder: (context, constraints) {
        final rects = playerSplitRects(
          isLandscape: isLandscape,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          pictureInPicture: pictureInPicture,
          infoVisible: infoVisible,
        );
        return Stack(
          children: [
            _place(rects.video, ColoredBox(color: Colors.black, child: video)),
            // 非表示のときは載せない。矩形を 0 にしても子ツリーは組まれるため、
            // PSI 更新やコメント一覧の作り直しを裏で続けてしまう。
            if (infoVisible && !pictureInPicture) _place(rects.info, info),
          ],
        );
      },
    );

    // 映像は横画面でも画面端まで描画する (フルブリード)。インカメラ等を避ける
    // ためだけに画面端へ寄せているので、縦画面のみ SafeArea でノッチ等を避ける。
    return SafeArea(
      left: !isLandscape,
      top: !isLandscape,
      right: !isLandscape,
      bottom: !isLandscape,
      child:
          visibility == null
              ? layout(true)
              : ValueListenableBuilder<bool>(
                valueListenable: visibility,
                builder: (context, visible, _) => layout(visible),
              ),
    );
  }

  /// [PlayerRect] の位置に配置する。
  Widget _place(PlayerRect rect, Widget child) => Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: child,
  );
}

/// デスクトップのプラットフォームか。
///
/// media_kit の `AdaptiveVideoControls` もプラットフォームで標準コントロールを
/// 切り替える (デスクトップだけ `MaterialDesktopVideoControls`) ので、
/// デスクトップ専用の表示切り替えもこれに揃える。幅では判定しない。
bool isDesktopPlatform(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
