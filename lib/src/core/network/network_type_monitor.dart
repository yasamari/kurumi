import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'network_type.dart';

/// 現在の回線種別を保持するプロセス内唯一の監視役。
///
/// PiP (`PipMode`) と同じく平台的機能なので Riverpod にはせず `core` に置く。
/// [start] を main で1回呼ぶと [value] が現在の回線種別に追従する。
///
/// 画質は**再生開始時に読むだけ**で購読はしない (`WatchQuality` /
/// `VideoPlayQuality` の `build` が `value.value` を読む)。再生中に回線が
/// 切り替わっても画質は変えず、ユーザーの画質メニュー操作に任せる。
class NetworkTypeMonitor {
  NetworkTypeMonitor._();

  static final NetworkTypeMonitor instance = NetworkTypeMonitor._();

  /// 現在の回線種別の通知元。既定は Wi-Fi (従量課金でない前提)。
  final ValueNotifier<NetworkType> value = ValueNotifier(NetworkType.wifi);

  bool _started = false;

  /// 監視を開始する。多重呼び出しは無視する。
  ///
  /// 監視できない環境 (NetworkManager の無い Linux 等) では例外を逸らして
  /// Wi-Fi のままにする。画質選択は設定値の出し分けだけなので、失敗しても
  /// 再生自体は続けられる。
  void start() {
    if (_started) return;
    _started = true;
    final connectivity = Connectivity();
    connectivity.checkConnectivity().then(
      (results) => _set(networkTypeOf(results)),
      onError: (_) {},
    );
    // 購読はアプリ生存期間ずっと続けるため参照を保持しない。
    connectivity.onConnectivityChanged.listen(
      (results) => _set(networkTypeOf(results)),
      onError: (_) {},
    );
  }

  void _set(NetworkType type) {
    if (value.value == type) return;
    value.value = type;
  }
}
