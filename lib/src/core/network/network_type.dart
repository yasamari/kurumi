import 'package:connectivity_plus/connectivity_plus.dart';

/// 画質設定の出し分けに使う回線種別。
///
/// 従量課金の有無だけを区別する。Wi-Fi と有線は同じ扱い、衛星回線はモバイルと
/// 同じ扱いにする (衛星も従量課金の可能性があるため)。
enum NetworkType {
  /// Wi-Fi・有線・その他 (従量課金でない想定)。
  wifi,

  /// モバイル回線 (セルラー・衛星)。
  mobile,
}

/// [ConnectivityResult] の一覧から回線種別を決める純粋関数。
///
/// Wi-Fi・有線が1つでもあれば [NetworkType.wifi] を優先する (VPN 併用時に
/// 実回線が Wi-Fi のことがあるため)。モバイル・衛星のみなら
/// [NetworkType.mobile]。判定できない場合 (none / bluetooth / vpn 単独 / 空) は
/// [NetworkType.wifi] にする (従量課金でない前提で高画質を選ぶ)。
NetworkType networkTypeOf(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return NetworkType.wifi;
  }
  if (results.contains(ConnectivityResult.mobile) ||
      results.contains(ConnectivityResult.satellite)) {
    return NetworkType.mobile;
  }
  return NetworkType.wifi;
}
