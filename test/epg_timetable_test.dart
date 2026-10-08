import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/data/epg/epg_dao.dart';
import 'package:kurumi/src/data/epg/epg_database.dart';

const _backend = 'mirakurun';
const _hourMs = 3600 * 1000;

EpgChannelsCompanion _channel({
  required int serviceId,
  required String remoteId,
  required int sortOrder,
}) {
  return EpgChannelsCompanion(
    sourceBackend: const Value(_backend),
    networkId: const Value(1),
    serviceId: Value(serviceId),
    remoteId: Value(remoteId),
    name: Value('局$serviceId'),
    channelType: const Value('GR'),
    sortOrder: Value(sortOrder),
  );
}

EpgProgramsCompanion _program({
  required int serviceId,
  required int eventId,
  required int startAtMs,
  required int endAtMs,
}) {
  return EpgProgramsCompanion(
    sourceBackend: const Value(_backend),
    networkId: const Value(1),
    serviceId: Value(serviceId),
    eventId: Value(eventId),
    startAtMs: Value(startAtMs),
    endAtMs: Value(endAtMs),
    title: const Value('番組'),
  );
}

void main() {
  late EpgDatabase db;
  late EpgDao dao;

  // 2026-10-08 10:30 JST 相当の固定時刻。
  final nowMs = DateTime(2026, 10, 8, 10, 30).millisecondsSinceEpoch;
  final dayStartMs = nowMs - 2 * _hourMs;
  final dayEndMs = dayStartMs + 6 * _hourMs;

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

  test('チャンネルは応答順に返る', () async {
    await seed(
      channels: [
        _channel(serviceId: 102, remoteId: '2', sortOrder: 1),
        _channel(serviceId: 101, remoteId: '1', sortOrder: 0),
      ],
      programs: const [],
    );

    final channels = await dao.timetableChannels(sourceBackend: _backend);

    expect(channels.map((c) => c.remoteId), ['1', '2']);
  });

  test('期間と重なる番組だけ返す', () async {
    await seed(
      channels: [_channel(serviceId: 101, remoteId: '1', sortOrder: 0)],
      programs: [
        // 期間より前。
        _program(
          serviceId: 101,
          eventId: 1,
          startAtMs: dayStartMs - 2 * _hourMs,
          endAtMs: dayStartMs - _hourMs,
        ),
        // 終了ちょうどは重ならない。
        _program(
          serviceId: 101,
          eventId: 2,
          startAtMs: dayStartMs - _hourMs,
          endAtMs: dayStartMs,
        ),
        // 開始境界に掛かる。
        _program(
          serviceId: 101,
          eventId: 3,
          startAtMs: dayStartMs - _hourMs,
          endAtMs: dayStartMs + _hourMs,
        ),
        // 期間内。
        _program(
          serviceId: 101,
          eventId: 4,
          startAtMs: dayStartMs + _hourMs,
          endAtMs: dayStartMs + 2 * _hourMs,
        ),
        // 終了境界に掛かる。
        _program(
          serviceId: 101,
          eventId: 5,
          startAtMs: dayEndMs - _hourMs,
          endAtMs: dayEndMs + _hourMs,
        ),
        // 開始ちょうどは重ならない。
        _program(
          serviceId: 101,
          eventId: 6,
          startAtMs: dayEndMs,
          endAtMs: dayEndMs + _hourMs,
        ),
        // 期間より後。
        _program(
          serviceId: 101,
          eventId: 7,
          startAtMs: dayEndMs + _hourMs,
          endAtMs: dayEndMs + 2 * _hourMs,
        ),
      ],
    );

    final programs = await dao.timetablePrograms(
      sourceBackend: _backend,
      startMs: dayStartMs,
      endMs: dayEndMs,
    );

    expect(programs.map((p) => p.eventId), [3, 4, 5]);
  });

  test('他バックエンドの行は混ざらない', () async {
    await seed(
      channels: [_channel(serviceId: 101, remoteId: '1', sortOrder: 0)],
      programs: [
        _program(
          serviceId: 101,
          eventId: 1,
          startAtMs: dayStartMs,
          endAtMs: dayStartMs + _hourMs,
        ),
      ],
    );

    final channels = await dao.timetableChannels(sourceBackend: 'edcb');
    final programs = await dao.timetablePrograms(
      sourceBackend: 'edcb',
      startMs: dayStartMs,
      endMs: dayEndMs,
    );

    expect(channels, isEmpty);
    expect(programs, isEmpty);
  });
}
