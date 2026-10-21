import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../timetable_scroll_link.dart';
import '../timetable_zoom.dart';

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
///
/// 2本指のピンチと Ctrl+ホイールは [zoom] に反映する。
/// 1本指 (またはマウスドラッグ) と通常のホイールは従来どおり両軸のパンになる。
class TimetablePanScroll extends StatefulWidget {
  const TimetablePanScroll({
    super.key,
    required this.verticalLink,
    required this.horizontalLink,
    required this.zoom,
    required this.onZoomFocal,
    required this.child,
  });

  /// 縦 (時間) スクロールの連動。
  final TimetableScrollLink verticalLink;

  /// 横 (チャンネル) スクロールの連動。
  final TimetableScrollLink horizontalLink;

  /// ピンチで変更するズーム倍率。
  final TimetableZoomController zoom;

  /// ピンチ / Ctrl+ホイールの中心のローカル座標。ズーム時にその位置の
  /// 時刻を固定するため、グリッドへ渡す。
  final ValueChanged<Offset> onZoomFocal;

  final Widget child;

  @override
  State<TimetablePanScroll> createState() => _TimetablePanScrollState();
}

class _TimetablePanScrollState extends State<TimetablePanScroll> {
  /// ピンチ開始時のズーム倍率。`details.scale` は開始時からの相対倍率。
  double _startZoom = 1.0;

  /// 2本指の操作中か。指を離したときに慣性スクロールさせない。
  bool _pinching = false;

  /// ピンチを始めた位置 (2本指になった最初の更新で決める)。
  ///
  /// 毎フレームの指の中心を使うと、2本の指のわずかな上下動がそのまま
  /// ズーム中心の移動になり、上下にガクつく。開始位置に固定して
  /// 拡大縮小だけを追従させる。
  Offset? _pinchFocal;

  late final Map<Type, GestureRecognizerFactory> _gestures =
      <Type, GestureRecognizerFactory>{
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
              () => ScaleGestureRecognizer(supportedDevices: _dragDevices),
              (ScaleGestureRecognizer instance) {
                instance
                  // タッチに加え、デスクトップのマウスドラッグでも斜めに
                  // スクロールできるようにする。
                  ..supportedDevices = _dragDevices
                  ..dragStartBehavior = DragStartBehavior.start
                  ..onStart = _onScaleStart
                  ..onUpdate = _onScaleUpdate
                  ..onEnd = _onScaleEnd;
              },
            ),
      };

  void _onScaleStart(ScaleStartDetails details) {
    _startZoom = widget.zoom.zoom;
    _pinching = false;
    _pinchFocal = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // 指が2本以上ある間はズームだけを行う。2本指のパンを併用すると、
    // 指の中心の上下動がスクロールとズーム中心の両方に効いてガクつく。
    if (details.pointerCount < 2) {
      // ピンチ中に片方の指が離れても、そのままパンへ移らない
      // (大きな `focalPointDelta` で跳ねるため)。
      if (_pinching) return;
      final delta = details.focalPointDelta;
      widget.verticalLink.dragBy(delta.dy);
      widget.horizontalLink.dragBy(delta.dx);
      return;
    }
    _pinching = true;
    final focal = _pinchFocal ??= details.localFocalPoint;
    final nextZoom = _startZoom * details.scale;
    // 範囲端で倍率が変わらないときは中心を残さない (次のボタン操作が
    // 古いピンチ位置を基準にしてしまうため)。
    if (!widget.zoom.canSetZoom(nextZoom)) return;
    widget.onZoomFocal(focal);
    widget.zoom.setZoom(nextZoom);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final wasPinching = _pinching;
    _pinchFocal = null;
    _pinching = false;
    // ピンチの終わりに慣性をかけると、指を広げた勢いで大きく流れる。
    if (wasPinching) return;
    // 指が増減したときにも `onEnd` が呼ばれる (2本目を置いた瞬間など)。
    // その速度で慣性をかけると、ピンチ開始直後に縦へ流れてガクつく。
    if (details.pointerCount > 0) return;
    final velocity = details.velocity.pixelsPerSecond;
    widget.verticalLink.flingBy(velocity.dy);
    widget.horizontalLink.flingBy(velocity.dx);
  }

  /// 内側の scrollable はホイールを受けない (`NeverScrollableScrollPhysics`)
  /// ため、ここで受けて両軸へ配る。マウスホイールの横傾き (dx) は横軸、
  /// トラックパッドの2本指スクロール (dx・dy 同時) は斜めになる。
  ///
  /// Ctrl+ホイールはポインタ位置を中心に拡大縮小する。ホイール1ノッチの
  /// 移動量は環境で異なるため、Δに比例した指数でなめらかに倍率を変える。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (HardwareKeyboard.instance.isControlPressed) {
      final nextZoom =
          widget.zoom.zoom *
          math.exp(-event.scrollDelta.dy * _ctrlWheelZoomFactor);
      if (!widget.zoom.canSetZoom(nextZoom)) return;
      widget.onZoomFocal(event.localPosition);
      widget.zoom.setZoom(nextZoom);
      return;
    }
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

/// Ctrl+ホイールのスクロール量から倍率への係数。
///
/// 1ノッチ (約100) でおよそ1.22倍になる。トラックパッドの小刻みな
/// デルタでも連続的に追従する。
const double _ctrlWheelZoomFactor = 0.002;

/// パンを拾うデバイス (セル内のタップは妨げない。軸ロックのないパンは
/// スロップ超過まで有効にならないため)。
const _dragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
};
