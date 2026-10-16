import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/core/network/network_type.dart';

void main() {
  group('networkTypeOf', () {
    test('Wi-Fi は Wi-Fi', () {
      expect(networkTypeOf([ConnectivityResult.wifi]), NetworkType.wifi);
    });

    test('有線も Wi-Fi 扱い', () {
      expect(networkTypeOf([ConnectivityResult.ethernet]), NetworkType.wifi);
    });

    test('モバイルはモバイル', () {
      expect(networkTypeOf([ConnectivityResult.mobile]), NetworkType.mobile);
    });

    test('衛星はモバイル扱い', () {
      expect(networkTypeOf([ConnectivityResult.satellite]), NetworkType.mobile);
    });

    test('Wi-Fi とモバイルが同時なら Wi-Fi を優先', () {
      expect(
        networkTypeOf([ConnectivityResult.mobile, ConnectivityResult.wifi]),
        NetworkType.wifi,
      );
    });

    test('衛星とモバイルの併記はモバイル', () {
      expect(
        networkTypeOf([
          ConnectivityResult.mobile,
          ConnectivityResult.satellite,
        ]),
        NetworkType.mobile,
      );
    });

    test('VPN 併用時は実回線で判定する', () {
      expect(
        networkTypeOf([ConnectivityResult.vpn, ConnectivityResult.wifi]),
        NetworkType.wifi,
      );
      expect(
        networkTypeOf([ConnectivityResult.vpn, ConnectivityResult.mobile]),
        NetworkType.mobile,
      );
    });

    test('判定できない場合は Wi-Fi', () {
      expect(networkTypeOf(const []), NetworkType.wifi);
      expect(networkTypeOf([ConnectivityResult.none]), NetworkType.wifi);
      expect(networkTypeOf([ConnectivityResult.bluetooth]), NetworkType.wifi);
      expect(networkTypeOf([ConnectivityResult.vpn]), NetworkType.wifi);
      expect(networkTypeOf([ConnectivityResult.other]), NetworkType.wifi);
    });
  });
}
