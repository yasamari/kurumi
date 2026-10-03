import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/ts/eit.dart';
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

/// セクションを184バイトずつに区切り、TSヘッダー付きパケット列にする。
Uint8List _toTsPackets(Uint8List section, int pid) {
  final out = BytesBuilder();
  var offset = 0;
  var first = true;
  var continuity = 0;
  while (offset < section.length) {
    final packet = Uint8List(188);
    var payloadStart = 4;
    if (first) {
      packet[4] = 0x00; // pointer_field
      payloadStart = 5;
      first = false;
    }
    final room = 188 - payloadStart;
    final end = (offset + room).clamp(0, section.length);
    final chunk = section.sublist(offset, end);
    packet.setRange(payloadStart, payloadStart + chunk.length, chunk);
    for (var i = payloadStart + chunk.length; i < 188; i++) {
      packet[i] = 0xFF;
    }
    packet[0] = 0x47;
    packet[1] = (offset == 0 ? 0x40 : 0x00) | ((pid >> 8) & 0x1F);
    packet[2] = pid & 0xFF;
    packet[3] = 0x10 | (continuity++ & 0x0F);
    out.add(packet);
    offset = end;
  }
  return out.toBytes();
}

void main() {
  group('番組情報コントローラー', () {
    test('初期状態は未受信', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
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
        packets: const Stream.empty(),
      );
      // serviceId不一致のセクションは無視される
      final other = _sectionBytes(sectionNumber: 0, eventId: 1);
      other[3] = 0x08; // service_id書き換え (CRCは壊れるため無視される)
      expect(controller.handleSection(other), isFalse);
      expect(controller.present, isNull);

      // 正規のPresentを受信する
      final presentBytes = _sectionBytes(sectionNumber: 0, eventId: 10);
      expect(controller.handleSection(presentBytes), isTrue);
      expect(controller.present, isNotNull);
      expect(controller.present!.title, 'AB');
      expect(controller.hasLive, isTrue);

      // 同一内容の再受信は更新しない
      expect(controller.handleSection(presentBytes), isFalse);

      controller.dispose();
    });

    test('TSパケット列からEITだけ抜き出して反映する', () async {
      final section = _sectionBytes(sectionNumber: 1, eventId: 20);
      // 映像PIDのダミーと混ぜてもEITだけ処理する
      final mixed = BytesBuilder()
        ..add(_toTsPackets(Uint8List.fromList(List.filled(300, 0xAA)), 0x100))
        ..add(_toTsPackets(section, 0x12));
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: Stream.value(mixed.toBytes()),
      );
      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.present, isNull);
      expect(controller.following, isNotNull);
      expect(controller.following!.title, 'AB');
      controller.dispose();
    });

    test('空ストリームでも落ちない', () async {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.present, isNull);
      controller.dispose();
    });

    test('異常ストリームでも落ちない', () async {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: Stream.error(StateError('切断')),
      );
      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.present, isNull);
      controller.dispose();
    });
  });
}
