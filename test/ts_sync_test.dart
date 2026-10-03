import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/ts/ts_sync.dart';

Uint8List _packet(int pid, int fill) {
  final packet = Uint8List(188);
  packet[0] = 0x47;
  packet[1] = (pid >> 8) & 0x1F;
  packet[2] = pid & 0xFF;
  packet[3] = 0x10;
  packet.fillRange(4, 188, fill);
  return packet;
}

void main() {
  group('TS同期バッファ', () {
    test('境界で分割された塊を復元する', () {
      final sync = TsSyncBuffer();
      final a = _packet(0x12, 0xAA);
      final b = _packet(0x100, 0xBB);
      // 100バイトずつに割って入れる
      final all = Uint8List.fromList([...a, ...b]);
      final out = <Uint8List>[];
      for (var i = 0; i < all.length; i += 100) {
        final end = (i + 100).clamp(0, all.length);
        out.addAll(sync.addBytes(all.sublist(i, end)));
      }
      expect(out, hasLength(2));
      expect(out[0], a);
      expect(out[1], b);
      expect(sync.pendingLength, 0);
    });

    test('端数は次回に持ち越す', () {
      final sync = TsSyncBuffer();
      final a = _packet(0x12, 0xAA);
      expect(sync.addBytes(a.sublist(0, 100)), isEmpty);
      expect(sync.pendingLength, 100);
      final out = sync.addBytes(a.sublist(100));
      expect(out, hasLength(1));
      expect(out.single, a);
    });

    test('先頭のゴミを読み飛ばす', () {
      final sync = TsSyncBuffer();
      final a = _packet(0x12, 0xAA);
      final b = _packet(0x12, 0xBB);
      // 単発の0x47を含むゴミの後に2パケット
      final out = sync.addBytes(
        Uint8List.fromList([0x00, 0x47, 0xFF, ...a, ...b]),
      );
      expect(out, hasLength(2));
      expect(out[0], a);
      expect(out[1], b);
    });

    test('同期バイト無しのゴミだけなら捨てる', () {
      final sync = TsSyncBuffer();
      expect(sync.addBytes(Uint8List.fromList([1, 2, 3])), isEmpty);
      expect(sync.pendingLength, 0);
    });
  });
}
