import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/ts/audio_layout.dart';
import 'package:kurumi/src/data/ts/eit.dart';
import 'package:kurumi/src/features/player/live_psi_controller.dart';

Uint8List _aribAscii(String text) {
  return Uint8List.fromList([0x1B, 0x28, 0x4A, ...text.codeUnits]);
}

/// 音声コンポーネント記述子 (0xC4)。`componentType` は component_type と
/// component_tag を詰めた2バイト目の値。
Uint8List _audioComponent(int componentType, {bool main = true}) {
  return Uint8List.fromList([
    0xC4,
    9,
    0xF2, // reserved + stream_content 0b0010 (音声)
    componentType,
    0x01, // component_tag
    0x0F, // stream_type
    0x00, // simulcast_group_tag
    main ? 0x4A : 0x8A, // main_component_flag + sampling_rate
    0x6A, 0x70, 0x6E, // language
  ]);
}

Uint8List _sectionBytes({
  required int sectionNumber,
  required int eventId,
  List<Uint8List> extraDescriptors = const [],
}) {
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
  for (final extra in extraDescriptors) {
    desc.add(extra);
  }
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

  group('音声構成', () {
    test('初期状態は判定不能', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      expect(controller.audioLayout, LiveAudioLayout.unknown);
      controller.dispose();
    });

    test('現在番組のEITから音声構成を判定する', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      // 現在の番組 (section_number 0) の 1/0+1/0 モード。
      expect(
        controller.handleSection(
          _sectionBytes(
            sectionNumber: 0,
            eventId: 30,
            extraDescriptors: [_audioComponent(0x02)],
          ),
        ),
        isTrue,
      );
      expect(controller.audioLayout, LiveAudioLayout.dualMono);
      controller.dispose();
    });

    test('次の番組のEITでは判定しない', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      controller.handleSection(
        _sectionBytes(
          sectionNumber: 1,
          eventId: 40,
          extraDescriptors: [_audioComponent(0x02)],
        ),
      );
      expect(controller.following, isNotNull);
      expect(controller.audioLayout, LiveAudioLayout.unknown);
      controller.dispose();
    });

    test('副音声だけの記述子では判定しない', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      controller.handleSection(
        _sectionBytes(
          sectionNumber: 0,
          eventId: 50,
          extraDescriptors: [_audioComponent(0x03, main: false)],
        ),
      );
      expect(controller.audioLayout, LiveAudioLayout.unknown);
      controller.dispose();
    });

    test('音声コンポーネントを含まないEITでは判定を保持する', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      controller.handleSection(
        _sectionBytes(
          sectionNumber: 0,
          eventId: 60,
          extraDescriptors: [_audioComponent(0x02)],
        ),
      );
      expect(controller.audioLayout, LiveAudioLayout.dualMono);

      // 記述子の無い再送で「判定不能」に戻さない (選択可能だった音声が
      // 突然できなくなるのを避けるため)。
      final withoutAudio = _sectionBytes(sectionNumber: 0, eventId: 60);
      expect(controller.handleSection(withoutAudio), isFalse);
      expect(controller.audioLayout, LiveAudioLayout.dualMono);
      controller.dispose();
    });

    test('判定が変わったら通知する', () {
      final controller = LivePsiController(
        networkId: 1,
        serviceId: 7,
        packets: const Stream.empty(),
      );
      var notified = 0;
      controller.addListener(() => notified++);

      controller.handleSection(
        _sectionBytes(
          sectionNumber: 0,
          eventId: 70,
          extraDescriptors: [_audioComponent(0x02)],
        ),
      );
      expect(notified, 1);

      // 既に受信した内容と同じなら通知しない。
      controller.handleSection(
        _sectionBytes(
          sectionNumber: 0,
          eventId: 70,
          extraDescriptors: [_audioComponent(0x02)],
        ),
      );
      expect(notified, 1);

      // 音声構成だけが変わっても通知する。
      controller.handleSection(
        _sectionBytes(
          sectionNumber: 0,
          eventId: 70,
          extraDescriptors: [_audioComponent(0x03)],
        ),
      );
      expect(controller.audioLayout, LiveAudioLayout.mainAudioOnly);
      expect(notified, 2);
      controller.dispose();
    });
  });
}
