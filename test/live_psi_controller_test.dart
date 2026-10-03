import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/eit.dart';
import 'package:kurumi/src/features/player/live_psi_controller.dart';

Uint8List _aribAscii(String text) {
  return Uint8List.fromList([0x1B, 0x28, 0x4A, ...text.codeUnits]);
}

Uint8List _sectionBytes({required int sectionNumber, required int eventId}) {
  final name = _aribAscii('AB');
  final bodyText = _aribAscii('C');
  final desc = BytesBuilder()
    ..addByte(0x4D)
    ..addByte(3 + 1 + name.length + 1 + bodyText.length)
    ..add([0x6A, 0x70, 0x6E])
    ..addByte(name.length)
    ..add(name)
    ..addByte(bodyText.length)
    ..add(bodyText);
  final descBytes = desc.toBytes();
  final body = BytesBuilder()
    ..addByte(0x4E)
    ..addByte(0xB0)
    ..addByte(0x00)
    ..addByte(0x00)
    ..addByte(0x07)
    ..addByte(0xC1)
    ..addByte(sectionNumber)
    ..addByte(0x00)
    ..addByte(0x00)
    ..addByte(0x01)
    ..addByte(0x00)
    ..addByte(0x01)
    ..addByte(0x01)
    ..addByte(0x4E)
    ..addByte((eventId >> 8) & 0xFF)
    ..addByte(eventId & 0xFF)
    ..add([0xEB, 0x96, 0x10, 0x00, 0x00])
    ..add([0x01, 0x00, 0x00])
    ..addByte((descBytes.length >> 8) & 0x0F)
    ..addByte(descBytes.length & 0xFF)
    ..add(descBytes);
  final without = body.toBytes();
  final sectionLength = (without.length - 3) + 4;
  without[1] = 0xB0 | ((sectionLength >> 8) & 0x0F);
  without[2] = sectionLength & 0xFF;
  final crc = mpeg2CrcOf(without);
  final out = BytesBuilder()
    ..add(without)
    ..add([(crc >> 24) & 0xFF, (crc >> 16) & 0xFF, (crc >> 8) & 0xFF, crc & 0xFF]);
  return out.toBytes();
}

void main() {
  group('番組情報コントローラー', () {
    test('初期状態は未受信', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        streamFactory: (_) async => const Stream.empty(),
      );
      expect(controller.present, isNull);
      expect(controller.following, isNull);
      expect(controller.hasLive, isFalse);
      controller.dispose();
    });

    test('Present/Followingをsection_numberで振り分ける', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        streamFactory: (_) async => const Stream.empty(),
      );
      // serviceId不一致のセクションは無視される
      final other = _sectionBytes(sectionNumber: 0, eventId: 1);
      other[3] = 0x08; // service_id書き換え (CRCは壊れるため無視される)
      expect(controller.handleSection(other), isFalse);
      expect(controller.present, isNull);

      // 正規のPresentを受信する
      final presentBytes = _sectionBytes(sectionNumber: 0, eventId: 10);
      // serviceIdを7に合わせて組み立て直す
      presentBytes[3] = 0x00;
      presentBytes[4] = 0x07;
      final crc = mpeg2CrcOf(
        presentBytes.sublist(0, presentBytes.length - 4),
      );
      presentBytes[presentBytes.length - 4] = (crc >> 24) & 0xFF;
      presentBytes[presentBytes.length - 3] = (crc >> 16) & 0xFF;
      presentBytes[presentBytes.length - 2] = (crc >> 8) & 0xFF;
      presentBytes[presentBytes.length - 1] = crc & 0xFF;
      expect(controller.handleSection(presentBytes), isTrue);
      expect(controller.present, isNotNull);
      expect(controller.present!.title, 'AB');
      expect(controller.hasLive, isTrue);

      // 同一内容の再受信は更新しない
      expect(controller.handleSection(presentBytes), isFalse);

      controller.dispose();
    });

    test('空ストリームでも落ちない', () async {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        streamFactory: (_) async => const Stream.empty(),
      );
      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.present, isNull);
      controller.dispose();
    });

    test('取得失敗でも落ちない', () async {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        streamFactory: (_) async {
          throw DioException(requestOptions: RequestOptions(path: '/'));
        },
      );
      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.present, isNull);
      controller.dispose();
    });
  });
}
