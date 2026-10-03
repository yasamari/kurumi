import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/arib_tables.dart';
import 'package:kurumi/src/data/backends/konomi/arib_text.dart';

void main() {
  group('ARIB文字列デコード', () {
    test('ESCでG0にASCIIを指定して英字を読む', () {
      // ESC ( J でG0=ASCII、その後GLでABC。全角で出る (半角化はformat側)。
      final text = decodeAribText(
        Uint8List.fromList([0x1B, 0x28, 0x4A, 0x41, 0x42, 0x43]),
      );
      expect(text, 'ＡＢＣ');
    });

    test('ESCでG0にひらがなを指定して読む', () {
      final text = decodeAribText(
        Uint8List.fromList([0x1B, 0x28, 0x30, 0x22, 0x24]),
      );
      expect(text, 'あい');
    });

    test('既定G0(漢字)の2バイトで漢字を読む', () {
      // ARIB (0x34,0x41) -> SJIS (0x8A,0xBF) = 漢
      final text = decodeAribText(Uint8List.fromList([0x34, 0x41]));
      expect(text, '漢');
    });

    test('外字はUnicode変換表で復元する', () {
      final text = decodeAribText(Uint8List.fromList([0x7A, 0x4D]));
      expect(text, aribGaiji1Unicode[0x7A4D]);
      expect(text.isNotEmpty, isTrue);
    });

    test('空入力は空文字を返す', () {
      expect(decodeAribText(Uint8List(0)), '');
    });
  });
}
