import 'package:flutter/foundation.dart';

import 'timetable_layout.dart';

/// 番組表のズーム倍率。画面が所有し、グリッドとバーで共有する。
///
/// ピンチ操作・キーボード・バーのボタンのどれからでも [setZoom] を呼ぶ。
/// 範囲は [timetableMinZoom, timetableMaxZoom] に丸める。
class TimetableZoomController extends ChangeNotifier {
  TimetableZoomController({double initialZoom = 1.0})
    : _zoom = timetableClampZoom(initialZoom);

  double _zoom;

  double get zoom => _zoom;

  bool get canZoomIn => _zoom < timetableMaxZoom - 1e-9;

  bool get canZoomOut => _zoom > timetableMinZoom + 1e-9;

  /// [setZoom] で実際に値が変わるか。範囲外・同じ値では通知されない。
  bool canSetZoom(double zoom) => timetableClampZoom(zoom) != _zoom;

  void setZoom(double zoom) {
    final next = timetableClampZoom(zoom);
    if (next == _zoom) return;
    _zoom = next;
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoom * timetableZoomStep);

  void zoomOut() => setZoom(_zoom / timetableZoomStep);

  void reset() => setZoom(1.0);
}
