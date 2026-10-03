import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/psi_archived_data.dart';

void main() {
  group('PSIアーカイブURL組み立て', () {
    test('チャンネルIDと画質を埋め込む', () {
      final url = buildKonomiPsiArchivedDataUrl(
        baseUrl: 'http://192.168.1.2:7000',
        displayChannelId: 'gr011',
        quality: '720p',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/gr011/720p/psi-archived-data',
      );
    });

    test('不正な画質はoriginalに正規化される', () {
      final url = buildKonomiPsiArchivedDataUrl(
        baseUrl: 'http://192.168.1.2:7000',
        displayChannelId: 'gr011',
        quality: '存在しない画質',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/gr011/original/psi-archived-data',
      );
    });

    test('ベースURL末尾のスラッシュを吸収する', () {
      final url = buildKonomiPsiArchivedDataUrl(
        baseUrl: 'http://192.168.1.2:7000/',
        displayChannelId: 'bs101',
        quality: 'original',
      );
      expect(
        url.toString(),
        'http://192.168.1.2:7000/api/streams/live/bs101/original/psi-archived-data',
      );
    });
  });

  group('TSパケットヘッダ設定', () {
    test('先頭のみPUSIを立て連番を振る', () {
      final packets = Uint8List(188 * 2);
      final counters = <int, int>{};
      setTsPacketHeader(packets, 0x12, counters);
      expect(packets[0], 0x47);
      expect(packets[1], 0x40 | 0x00);
      expect(packets[2], 0x12);
      expect(packets[3], 0x10 | 0x00);
      expect(packets[188], 0x47);
      expect(packets[189] & 0x40, 0x00);
      expect(packets[191] & 0x0F, 0x01);
      expect(counters[0x12], 2);
    });
  });

  group('PSIアーカイブパーサー', () {
    test('空入力は空を返す', () {
      final parser = PsiArchivedDataParser();
      expect(parser.addBytes(Uint8List(0)), isEmpty);
      expect(parser.pendingLength, 0);
    });

    test('32バイト未満は次回に持ち越す', () {
      final parser = PsiArchivedDataParser();
      final out = parser.addBytes(Uint8List.fromList([1, 2, 3]));
      expect(out, isEmpty);
      expect(parser.pendingLength, 3);
    });

    test('マジック不正で例外を送出する', () {
      final parser = PsiArchivedDataParser();
      expect(
        () => parser.addBytes(Uint8List(32)),
        throwsA(isA<StateError>()),
      );
    });
  });
}
