import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/eit.dart';
import 'package:kurumi/src/data/backends/konomi/live_program.dart';

EitSection _section({
  required int sectionNumber,
  required List<EitDescriptor> descriptors,
  int serviceId = 1,
  int networkId = 1,
  bool currentNext = true,
  int tableId = 0x4E,
}) {
  return EitSection(
    tableId: tableId,
    serviceId: serviceId,
    versionNumber: 0,
    currentNext: currentNext,
    sectionNumber: sectionNumber,
    transportStreamId: 1,
    originalNetworkId: networkId,
    events: [
      EitEvent(
        eventId: 100,
        startTimeBytes: Uint8List.fromList([0xEB, 0x96, 0x10, 0x00, 0x00]),
        durationBytes: Uint8List.fromList([0x01, 0x00, 0x00]),
        freeCaMode: false,
        descriptors: descriptors,
      ),
    ],
  );
}

/// `ESC ( J` + ASCII文字のARIBバイト列を作る。
Uint8List _aribAscii(String text) {
  final out = <int>[0x1B, 0x28, 0x4A];
  out.addAll(text.codeUnits);
  return Uint8List.fromList(out);
}

Uint8List _shortBytes(Uint8List name, Uint8List text) {
  final body = BytesBuilder();
  body.addByte(0x4D);
  body.addByte(3 + 1 + name.length + 1 + text.length);
  body.add([0x6A, 0x70, 0x6E]);
  body.addByte(name.length);
  body.add(name);
  body.addByte(text.length);
  body.add(text);
  return body.toBytes();
}

void main() {
  group('対象判定', () {
    test('NID/SID不一致は対象外', () {
      final eit = _section(sectionNumber: 0, descriptors: const []);
      expect(
        isLiveEitSection(eit, networkId: 999, serviceId: 1),
        isFalse,
      );
      expect(
        buildLiveTvProgram(eit, networkId: 999, serviceId: 1),
        isNull,
      );
    });

    test('current_nextなし・他TSは対象外', () {
      final eit = _section(
        sectionNumber: 0,
        descriptors: const [],
        currentNext: false,
      );
      expect(isLiveEitSection(eit, networkId: 1, serviceId: 1), isFalse);
      final other = _section(
        sectionNumber: 0,
        descriptors: const [],
        tableId: 0x4F,
      );
      expect(isLiveEitSection(other, networkId: 1, serviceId: 1), isFalse);
    });
  });

  group('番組組み立て', () {
    test('短形式・コンテント・拡張形式を反映する', () {
      final short = parseDescriptors(
        _shortBytes(_aribAscii('AB'), _aribAscii('C')),
      );
      // 拡張形式: 項目名ABC/本文DEF
      final items = BytesBuilder();
      final head = _aribAscii('ABC');
      items.addByte(head.length);
      items.add(head);
      final bodyText = _aribAscii('DEF');
      items.addByte(bodyText.length);
      items.add(bodyText);
      final itemsBytes = items.toBytes();
      final payload = BytesBuilder()
        ..addByte(0x00)
        ..add([0x6A, 0x70, 0x6E])
        ..addByte(itemsBytes.length)
        ..add(itemsBytes)
        ..addByte(0);
      final payloadBytes = payload.toBytes();
      final extended = Uint8List.fromList([
        0x4E,
        payloadBytes.length,
        ...payloadBytes,
      ]);
      // コンテント: スポーツ・野球 (0x11)
      const content = ContentDescriptor([
        ContentNibble(level1: 0x1, level2: 0x1, userNibble: 0xFF),
      ]);
      final descriptors = [
        ...short,
        ...parseDescriptors(extended),
        content,
      ];
      final program = buildLiveTvProgram(
        _section(sectionNumber: 0, descriptors: descriptors),
        networkId: 1,
        serviceId: 1,
      );
      expect(program, isNotNull);
      expect(program!.title, 'AB');
      expect(program.description, 'C');
      expect(program.genres, ['スポーツ・野球']);
      expect(program.detail, {'ABC': 'DEF'});
      expect(program.startAt.toUtc(), DateTime.utc(2024, 1, 1, 1, 0, 0));
      expect(program.endAt.toUtc(), DateTime.utc(2024, 1, 1, 2, 0, 0));
    });

    test('記述子なしでも既定文言で作る', () {
      final program = buildLiveTvProgram(
        _section(sectionNumber: 1, descriptors: const []),
        networkId: 1,
        serviceId: 1,
      );
      expect(program, isNotNull);
      expect(program!.title, '番組情報がありません');
      expect(program.genres, isEmpty);
      expect(program.detail, isEmpty);
    });

    test('未定時刻は基準値に倒す', () {
      final eit = EitSection(
        tableId: 0x4E,
        serviceId: 1,
        versionNumber: 0,
        currentNext: true,
        sectionNumber: 0,
        transportStreamId: 1,
        originalNetworkId: 1,
        events: [
          EitEvent(
            eventId: 5,
            startTimeBytes: Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
            durationBytes: Uint8List.fromList([0xFF, 0xFF, 0xFF]),
            freeCaMode: false,
            descriptors: const [],
          ),
        ],
      );
      final program = buildLiveTvProgram(eit, networkId: 1, serviceId: 1);
      expect(program!.startAt, liveProgramEmptyStart);
      expect(program.endAt, liveProgramEmptyStart);
    });
  });
}
