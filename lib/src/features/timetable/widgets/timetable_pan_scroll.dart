import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../timetable_scroll_link.dart';

/// 番組表のドラッグを両軸同時に受け、ホイールも両軸へ配る。
///
/// グリッドは横列 (`ListView.builder`) の内側に縦方向の内容を持つ2軸構造。
/// 縦の実 `Scrollable` はガターの `ListView` だけで、チャンネル列は
/// スクロールを持たない (`Transform` で追従する)。それでも横向きの
/// `ListView` は軸でロックされた `DragGestureRecognizer` を持つため、
/// 斜めのドラッグでは深い側が先にジェスチャーを取って1軸しか動かない。
///
/// そのためスクロール可能な `ListView` は `NeverScrollableScrollPhysics`
/// にして recognizer を外し、ここで「両軸を同時に動かすパン」を1本だけ
/// 受ける。受け取った量は縦横の [TimetableScrollLink] へ流すので、斜めでも
/// 1軸だけでも同じ経路で動く。端のクランプ・慣性は各 `ScrollPosition` の
/// 物理に委ね、従来のホイール・スクロールバー操作もそのまま動く。
///
/// セルのタップ (番組詳細・視聴遷移) はパンが動き出すまで残る。パンは
/// スロップを超えて初めて有効になるので、タップと競合しない。
class TimetablePanScroll extends StatefulWidget {
  const TimetablePanScroll({
    super.key,
    required this.verticalLink,
    required this.horizontalLink,
    required this.child,
  });

  /// 縦 (時間) スクロールの連動。
  final TimetableScrollLink verticalLink;

  /// 横 (チャンネル) スクロールの連動。
  final TimetableScrollLink horizontalLink;

  final Widget child;

  @override
  State<TimetablePanScroll> createState() => _TimetablePanScrollState();
}

class _TimetablePanScrollState extends State<TimetablePanScroll> {
  late final Map<Type, GestureRecognizerFactory> _gestures =
      <Type, GestureRecognizerFactory>{
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              () => PanGestureRecognizer(supportedDevices: _dragDevices),
              (PanGestureRecognizer instance) {
                instance
                  // タッチに加え、デスクトップのマウスドラッグでも斜めに
                  // スクロールできるようにする。
                  ..supportedDevices = _dragDevices
                  ..dragStartBehavior = DragStartBehavior.start
                  ..onUpdate = _onPanUpdate
                  ..onEnd = _onPanEnd;
              },
            ),
      };

  void _onPanUpdate(DragUpdateDetails details) {
    widget.verticalLink.dragBy(details.delta.dy);
    widget.horizontalLink.dragBy(details.delta.dx);
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    widget.verticalLink.flingBy(velocity.dy);
    widget.horizontalLink.flingBy(velocity.dx);
  }

  /// 内側の scrollable はホイールを受けない (`NeverScrollableScrollPhysics`)
  /// ため、ここで受けて両軸へ配る。マウスホイールの横傾き (dx) は横軸、
  /// トラックパッドの2本指スクロール (dx・dy 同時) は斜めになる。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    widget.verticalLink.pointerScrollBy(event.scrollDelta.dy);
    widget.horizontalLink.pointerScrollBy(event.scrollDelta.dx);
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: _gestures,
      behavior: HitTestBehavior.opaque,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: _onPointerSignal,
        child: widget.child,
      ),
    );
  }
}

/// パンを拾うデバイス (セル内のタップは妨げない。軸ロックのないパンは
/// スロップ超過まで有効にならないため)。
const _dragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
};
