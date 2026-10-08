import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/data/epg/epg_dao.dart';
import 'package:kurumi/src/data/epg/epg_database.dart';

const _backend = 'mirakurun';
const _hourMs = 3600 * 1000;

EpgChannelsCompanion _channel({
  required int networkId,
  required int serviceId,
  required String remoteId,
  required String name,
  required int sortOrder,
  String channelType = 'GR',
  String channelNumber = '',
  String tunerChannel = '27',
  bool hasLogo = true,
}) {
  return EpgChannelsCompanion(
    sourceBackend: const Value(_backend),
    networkId: Value(networkId),
    serviceId: Value(serviceId),
    remoteId: Value(remoteId),
    name: Value(name),
    channelType: Value(channelType),
    channelNumber: Value(channelNumber),
    tunerChannel: Value(tunerChannel),
    hasLogo: Value(hasLogo),
    sortOrder: Value(sortOrder),
  );
}

EpgProgramsCompanion _program({
  required int networkId,
  required int serviceId,
  required int eventId,
  required int startAtMs,
  required int endAtMs,
  String title = '番組',
}) {
  return EpgProgramsCompanion(
    sourceBackend: const Value(_backend),
    networkId: Value(networkId),
    serviceId: Value(serviceId),
    eventId: Value(eventId),
    startAtMs: Value(startAtMs),
    endAtMs: Value(endAtMs),
    title: Value(title),
    description: const Value('概要'),
  );
}

void main() {
  late EpgDatabase db;
  late EpgDao dao;

  // 2026-09-29 10:30 JST 相当の固定時刻。
  final nowMs =
      DateTime(2026, 9, 29, 10, 30).millisecondsSinceEpoch;

  setUp(() {
    db = EpgDatabase.forTesting(NativeDatabase.memory());
    dao = db.epgDao;
    addTearDown(db.close);
  });

  Future<void> seed({
    required List<EpgChannelsCompanion> channels,
    required List<EpgProgramsCompanion> programs,
  }) async {
    await dao.replaceEpg(
      sourceBackend: _backend,
      baseUrl: 'http://example.test:40772',
      channels: channels,
      programs: programs,
      fetchedAtMs: nowMs,
    );
  }

  test('現在・次番組が取得でき、出力順は応答順になる', () async {
    await seed(
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: 'A局',
          sortOrder: 0,
        ),
        _channel(
          networkId: 1,
          serviceId: 102,
          remoteId: '2',
          name: 'B局',
          sortOrder: 1,
          tunerChannel: '26',
        ),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: 'A現在',
        ),
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 12,
          startAtMs: nowMs + _hourMs,
          endAtMs: nowMs + 2 * _hourMs,
          title: 'A次',
        ),
        _program(
          networkId: 1,
          serviceId: 102,
          eventId: 21,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: 'B現在',
        ),
        _program(
          networkId: 1,
          serviceId: 102,
          eventId: 22,
          startAtMs: nowMs + _hourMs,
          endAtMs: nowMs + 2 * _hourMs,
          title: 'B次',
        ),
      ],
    );

    final rows = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs,
    );

    expect(rows.map((r) => r.name), ['A局', 'B局']);
    expect(rows[0].present?.title, 'A現在');
    expect(rows[0].next?.title, 'A次');
    expect(rows[1].present?.title, 'B現在');
    expect(rows[1].next?.title, 'B次');
  });

  test('放送中でないチャンネルは除外される', () async {
    await seed(
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: 'A局',
          sortOrder: 0,
        ),
        _channel(
          networkId: 1,
          serviceId: 102,
          remoteId: '2',
          name: 'B局',
          sortOrder: 1,
          tunerChannel: '26',
        ),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
        ),
        // B局には現在番組なし (未来の番組のみ)。
        _program(
          networkId: 1,
          serviceId: 102,
          eventId: 22,
          startAtMs: nowMs + _hourMs,
          endAtMs: nowMs + 2 * _hourMs,
        ),
      ],
    );

    final rows = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs,
    );

    expect(rows.map((r) => r.name), ['A局']);
  });

  test('同じ種別・物理チャンネル・eventIdは先勝の1行だけ残る', () async {
    await seed(
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: '親局',
          sortOrder: 0,
        ),
        _channel(
          networkId: 1,
          serviceId: 102,
          remoteId: '2',
          name: 'サブ',
          sortOrder: 1,
        ),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
        ),
        // 同じ eventId の同時放送。
        _program(
          networkId: 1,
          serviceId: 102,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
        ),
      ],
    );

    final rows = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs,
    );

    expect(rows.map((r) => r.name), ['親局']);
  });

  test('別eventId・別チャンネルは重複排除されない', () async {
    await seed(
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: '親局',
          sortOrder: 0,
        ),
        _channel(
          networkId: 1,
          serviceId: 102,
          remoteId: '2',
          name: 'サブ',
          sortOrder: 1,
        ),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
        ),
        _program(
          networkId: 1,
          serviceId: 102,
          eventId: 12,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
        ),
      ],
    );

    final rows = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs,
    );

    expect(rows.map((r) => r.name), ['親局', 'サブ']);
  });

  test('境界時刻ちょうどは開始側が現在・終了側は終了扱いになる', () async {
    await seed(
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: 'A局',
          sortOrder: 0,
        ),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 10,
          startAtMs: nowMs - 2 * _hourMs,
          endAtMs: nowMs,
          title: '終了済み',
        ),
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
          title: '開始ちょうど',
        ),
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 12,
          startAtMs: nowMs + _hourMs,
          endAtMs: nowMs + 2 * _hourMs,
          title: '次',
        ),
      ],
    );

    final rows = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs,
    );

    expect(rows, hasLength(1));
    expect(rows[0].present?.title, '開始ちょうど');
    expect(rows[0].next?.title, '次');
  });

  test('他バックエンドの行は混ざらない', () async {
    await dao.replaceEpg(
      sourceBackend: 'edcb',
      baseUrl: 'http://example.test:5510',
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: '他局',
          sortOrder: 0,
        ).copyWith(sourceBackend: const Value('edcb')),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
        ).copyWith(sourceBackend: const Value('edcb')),
      ],
      fetchedAtMs: nowMs,
    );

    final rows = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs,
    );

    expect(rows, isEmpty);
  });

  test('nowを進めると現在・次番組が入れ替わる', () async {
    await seed(
      channels: [
        _channel(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: 'A局',
          sortOrder: 0,
        ),
      ],
      programs: [
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: '前半',
        ),
        _program(
          networkId: 1,
          serviceId: 101,
          eventId: 12,
          startAtMs: nowMs + _hourMs,
          endAtMs: nowMs + 2 * _hourMs,
          title: '後半',
        ),
      ],
    );

    final later = await dao.nowOnAir(
      sourceBackend: _backend,
      nowMs: nowMs + _hourMs,
    );

    expect(later, hasLength(1));
    expect(later[0].present?.title, '後半');
    expect(later[0].next, isNull);
  });
}
