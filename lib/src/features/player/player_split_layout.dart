import 'dart:math' as math;

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
({PlayerRect video, PlayerRect info}) playerSplitRects({
  required bool isLandscape,
  required double width,
  required double height,
}) {
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
/// **映像の親は向きで変えない。** `Row` と `Column` で出し分けると、ウィジェット
/// の型が変わった時点でその下の Element がすべて作り直される。`_LivePlayer` /
/// `_VideoPlayer` は映像スロットの中に置かれており、向きが変わると State ごと
/// 破棄される。State が持つ `Player` と再生セッション ([LiveSession]) はそこで
/// 解放され、作り直しになる (PSI 取得とライブ追従の中断。実況コメントの接続
/// だけ [_WatchLayoutState] 側の持ちなので保たれる)。
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
/// 向きによってウィジェット自身を出し分けない。
class PlayerSplitLayout extends StatelessWidget {
  const PlayerSplitLayout({
    super.key,
    required this.video,
    required this.info,
  });

  /// 映像。レターボックス (黒帯・柱状) は黒で塗る。
  final Widget video;

  /// 情報パネル。
  final Widget info;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final rects = playerSplitRects(
          isLandscape: isLandscape,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        return Stack(
          children: [
            _place(rects.video, ColoredBox(color: Colors.black, child: video)),
            _place(rects.info, info),
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
      child: content,
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
