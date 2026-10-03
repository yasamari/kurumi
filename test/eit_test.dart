import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/eit.dart';

/// 最小のEIT[p/f]セクションを組み立てる (イベント1件+短形式記述子)。
Uint8List _buildEitSection({
  required int serviceId,
  required int sectionNumber,
  required int eventId,
  required Uint8List shortEventDescriptor,
}) {
  final body = BytesBuilder();
  // table_id
  body.addByte(0x4E);
  // section_syntax_indicator(1)+reserved(3)+section_length(12) は後で埋める
  body.addByte(0xB0);
  body.addByte(0x00);
  body.addByte((serviceId >> 8) & 0xFF);
  body.addByte(serviceId & 0xFF);
  // reserved(2)+version(5)+current_next(1)
  body.addByte(0xC1);
  body.addByte(sectionNumber);
  body.addByte(0x00); // last_section_number
  body.addByte(0x00); // transport_stream_id (上位)
  body.addByte(0x01);
  body.addByte(0x00); // original_network_id (上位)
  body.addByte(0x01);
  body.addByte(0x01); // segment_last_section_number
  body.addByte(0x4E); // last_table_id
  // イベント1件: event_id(2) + start_time(5) + duration(3) + flags(2)
  body.addByte((eventId >> 8) & 0xFF);
  body.addByte(eventId & 0xFF);
  // 開始時刻: MJD 0xEB96 (2024-01-01) + 10:00:00 (BCD)
  body.add([0xEB, 0x96, 0x10, 0x00, 0x00]);
  // 継続時間: 01:00:00
  body.add([0x01, 0x00, 0x00]);
  // running_status(3)=0 + free_CA(1)=0 + loop_length(12)
  final loopLen = shortEventDescriptor.length;
  body.addByte((loopLen >> 8) & 0x0F);
  body.addByte(loopLen & 0xFF);
  body.add(shortEventDescriptor);

  final withoutHeader = body.toBytes();
  // section_length = 全体 - 先頭3バイト + CRC4
  final sectionLength = (withoutHeader.length - 3) + 4;
  withoutHeader[1] = 0xB0 | ((sectionLength >> 8) & 0x0F);
  withoutHeader[2] = sectionLength & 0xFF;
  final crc = mpeg2CrcOf(withoutHeader);
  final out = BytesBuilder();
  out.add(withoutHeader);
  out.add([
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ]);
  return out.toBytes();
}

Uint8List _shortEventDescriptor(List<int> name, List<int> text) {
  final body = BytesBuilder();
  body.addByte(0x4D);
  body.addByte(3 + 1 + name.length + 1 + text.length);
  body.add([0x6A, 0x70, 0x6E]); // jpn
  body.addByte(name.length);
  body.add(name);
  body.addByte(text.length);
  body.add(text);
  return body.toBytes();
}

void main() {
  group('MPEG-2 CRC', () {
    test('CRC付きセクションの剰余は0になる', () {
      final desc = _shortEventDescriptor([0x41], [0x42]);
      final section = _buildEitSection(
        serviceId: 1,
        sectionNumber: 0,
        eventId: 100,
        shortEventDescriptor: desc,
      );
      expect(mpeg2CrcRemainder(section), 0);
    });

    test('1ビット化けると剰余が0でなくなる', () {
      final desc = _shortEventDescriptor([0x41], [0x42]);
      final section = _buildEitSection(
        serviceId: 1,
        sectionNumber: 0,
        eventId: 100,
        shortEventDescriptor: desc,
      );
      section[10] ^= 0x01;
      expect(mpeg2CrcRemainder(section), isNot(0));
      expect(parseEitSection(section), isNull);
    });
  });

  group('EIT時刻', () {
    test('MJD+BCDをJSTの瞬間として解釈する', () {
      // 2024-01-01 10:00:00 JST = 2024-01-01 01:00:00 UTC
      final start = decodeEitStartTime(
        Uint8List.fromList([0xEB, 0x96, 0x10, 0x00, 0x00]),
      );
      expect(start, isNotNull);
      expect(start!.toUtc(), DateTime.utc(2024, 1, 1, 1, 0, 0));
    });

    test('全ビット1は未定としてnullを返す', () {
      expect(
        decodeEitStartTime(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF])),
        isNull,
      );
      expect(
        decodeEitDuration(Uint8List.fromList([0xFF, 0xFF, 0xFF])),
        isNull,
      );
    });

    test('継続時間を秒に変換する', () {
      expect(
        decodeEitDuration(Uint8List.fromList([0x01, 0x30, 0x00])),
        5400,
      );
    });
  });

  group('記述子パース', () {
    test('短形式イベントを切り出す', () {
      final bytes = _shortEventDescriptor([0x41, 0x42], [0x43]);
      final descriptors = parseDescriptors(bytes);
      expect(descriptors, hasLength(1));
      final short = descriptors.single as ShortEventDescriptor;
      expect(short.language, 'jpn');
      expect(short.eventName, [0x41, 0x42]);
      expect(short.text, [0x43]);
    });

    test('コンテント記述子を切り出す', () {
      // tag 0x54, len 2, level1=0x1 level2=0x1 user=0xFF
      final descriptors = parseDescriptors(
        Uint8List.fromList([0x54, 0x02, 0x11, 0xFF]),
      );
      final content = descriptors.single as ContentDescriptor;
      expect(content.contents, hasLength(1));
      expect(content.contents.single.level1, 0x1);
      expect(content.contents.single.level2, 0x1);
      expect(content.contents.single.userNibble, 0xFF);
    });
  });

  group('EITセクションパース', () {
    test('1イベントのセクションを読める', () {
      final desc = _shortEventDescriptor([0x41], [0x42]);
      final section = _buildEitSection(
        serviceId: 7,
        sectionNumber: 0,
        eventId: 123,
        shortEventDescriptor: desc,
      );
      final eit = parseEitSection(section);
      expect(eit, isNotNull);
      expect(eit!.tableId, 0x4E);
      expect(eit.serviceId, 7);
      expect(eit.sectionNumber, 0);
      expect(eit.currentNext, isTrue);
      expect(eit.events, hasLength(1));
      expect(eit.events.single.eventId, 123);
      expect(eit.events.single.descriptors.single, isA<ShortEventDescriptor>());
    });

    test('table_idがEITでなければnull', () {
      final desc = _shortEventDescriptor([0x41], [0x42]);
      final section = _buildEitSection(
        serviceId: 7,
        sectionNumber: 0,
        eventId: 123,
        shortEventDescriptor: desc,
      );
      section[0] = 0x50;
      expect(parseEitSection(section), isNull);
    });
  });

  group('TSセクション再構成', () {
    test('複数パケットに分割されたセクションを復元する', () {
      final desc = _shortEventDescriptor(
        List.filled(100, 0x41),
        List.filled(100, 0x42),
      );
      final section = _buildEitSection(
        serviceId: 7,
        sectionNumber: 1,
        eventId: 456,
        shortEventDescriptor: desc,
      );
      // 184バイトずつに区切り、先頭にpointer_field(0)を付けてTS化する
      final packets = BytesBuilder();
      var offset = 0;
      var first = true;
      while (offset < section.length) {
        final packet = Uint8List(188);
        var payloadStart = 4;
        if (first) {
          packet[4] = 0x00; // pointer_field
          payloadStart = 5;
          first = false;
        }
        final room = 188 - payloadStart;
        final chunk = section.sublist(
          offset,
          (offset + room).clamp(0, section.length),
        );
        packet.setRange(payloadStart, payloadStart + chunk.length, chunk);
        // 残りは0xFF詰め
        for (var i = payloadStart + chunk.length; i < 188; i++) {
          packet[i] = 0xFF;
        }
        packets.add(packet);
        offset += chunk.length;
      }
      final raw = packets.toBytes();
      // ヘッダを設定する
      final counters = <int, int>{};
      // ignore: unused_local_variable
      for (var i = 0; i < raw.length; i += 188) {}
      final assembler = TsSectionAssembler();
      // ヘッダを手動設定 (PID 0x12、先頭PUSI)
      for (var i = 0; i < raw.length; i += 188) {
        raw[i] = 0x47;
        raw[i + 1] = (i == 0 ? 0x40 : 0x00) | 0x00;
        raw[i + 2] = 0x12;
        raw[i + 3] = 0x10 | ((i ~/ 188) & 0x0F);
      }
      expect(counters, isEmpty);
      final sections = assembler.addPackets(raw);
      expect(sections, hasLength(1));
      expect(sections.single.pid, 0x12);
      expect(sections.single.section, section);
      final eit = parseEitSection(sections.single.section);
      expect(eit!.sectionNumber, 1);
      expect(eit.events.single.eventId, 456);
    });
  });
}
