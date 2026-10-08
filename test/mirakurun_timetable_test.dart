import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/data/backends/mirakurun/mirakurun_timetable.dart';
import 'package:kurumi/src/data/epg/epg_database.dart';

const _baseUrl = 'http://192.0.2.1:40772';
const _hourMs = 3600 * 1000;

EpgChannel _channel({
  required int serviceId,
  required String remoteId,
  required String name,
  required int sortOrder,
  String channelType = 'GR',
  String tunerChannel = '27',
  bool hasLogo = true,
}) {
  return EpgChannel(
    sourceBackend: 'mirakurun',
    networkId: 1,
    serviceId: serviceId,
    remoteId: remoteId,
    name: name,
    channelType: channelType,
    channelNumber: '011',
    tunerChannel: tunerChannel,
    hasLogo: hasLogo,
    sortOrder: sortOrder,
  );
}

EpgProgram _program({
  required int serviceId,
  required int eventId,
  required int startAtMs,
  required int endAtMs,
  String title = '番組',
}) {
  return EpgProgram(
    sourceBackend: 'mirakurun',
    networkId: 1,
    serviceId: serviceId,
    eventId: eventId,
    startAtMs: startAtMs,
    endAtMs: endAtMs,
    title: title,
    description: '概要',
    genresJson: '["ニュース・報道"]',
    detailJson: '{"出演者":"誰々"}',
  );
}

void main() {
  // 2026-10-08 10:30 JST 相当の固定時刻。
  final nowMs = DateTime(2026, 10, 8, 10, 30).millisecondsSinceEpoch;

  test('チャンネル順を保ち番組を開始時刻順に並べる', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(serviceId: 101, remoteId: '1', name: 'A局', sortOrder: 0),
        _channel(
          serviceId: 102,
          remoteId: '2',
          name: 'B局',
          sortOrder: 1,
          channelType: 'BS',
          hasLogo: false,
        ),
      ],
      programs: [
        // わざと逆順で入れる。
        _program(
          serviceId: 101,
          eventId: 12,
          startAtMs: nowMs + _hourMs,
          endAtMs: nowMs + 2 * _hourMs,
          title: 'A次',
        ),
        _program(
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: 'A現在',
        ),
      ],
      baseUrl: _baseUrl,
    );

    expect(columns.map((c) => c.channel.name), ['A局', 'B局']);
    expect(columns[0].programs.map((p) => p.title), ['A現在', 'A次']);
    expect(columns[0].programs.first.genres, ['ニュース・報道']);
    expect(columns[0].programs.first.detail, {'出演者': '誰々'});
    expect(columns[0].channel.logoUrl, '$_baseUrl/api/services/1/logo');
    expect(columns[0].channel.channelNumber, '011');
    // ロゴ無しチャンネルはURLを持たない。
    expect(columns[1].channel.logoUrl, isNull);
    // 番組の無いチャンネルは空列として残る。
    expect(columns[1].programs, isEmpty);
  });

  test('他サービスの番組は混ざらない', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(serviceId: 101, remoteId: '1', name: 'A局', sortOrder: 0),
      ],
      programs: [
        _program(
          serviceId: 999,
          eventId: 11,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
        ),
      ],
      baseUrl: _baseUrl,
    );

    expect(columns.single.programs, isEmpty);
  });

  test('同時放送のサブチャンネルは1列にまとまる', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(serviceId: 101, remoteId: '1', name: '親局', sortOrder: 0),
        _channel(serviceId: 102, remoteId: '2', name: 'サブ', sortOrder: 1),
      ],
      programs: [
        _program(
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: '同時放送',
        ),
        // 同じ eventId・同じ時間の同時放送。
        _program(
          serviceId: 102,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: '同時放送',
        ),
      ],
      baseUrl: _baseUrl,
    );

    // 先勝のチャンネル名で1列になり、番組は重複排除される。
    expect(columns.map((c) => c.channel.name), ['親局']);
    expect(columns.single.programs.map((p) => p.title), ['同時放送']);
  });

  test('時間が重ならない別番組は1列にまとまる', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(serviceId: 101, remoteId: '1', name: '親局', sortOrder: 0),
        _channel(serviceId: 102, remoteId: '2', name: 'サブ', sortOrder: 1),
      ],
      programs: [
        _program(
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs,
          title: '午前',
        ),
        _program(
          serviceId: 102,
          eventId: 12,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
          title: '午後',
        ),
      ],
      baseUrl: _baseUrl,
    );

    expect(columns.map((c) => c.channel.name), ['親局']);
    expect(
      columns.single.programs.map((p) => p.title),
      ['午前', '午後'],
    );
  });

  test('時間が重なる別番組があると列は分かれる', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(serviceId: 101, remoteId: '1', name: '親局', sortOrder: 0),
        _channel(serviceId: 102, remoteId: '2', name: 'サブ', sortOrder: 1),
      ],
      programs: [
        _program(
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: '親番組',
        ),
        // 同じ時間帯の別番組 (マルチ編成の分岐)。
        _program(
          serviceId: 102,
          eventId: 21,
          startAtMs: nowMs - _hourMs,
          endAtMs: nowMs + _hourMs,
          title: 'サブ番組',
        ),
      ],
      baseUrl: _baseUrl,
    );

    expect(columns.map((c) => c.channel.name), ['親局', 'サブ']);
    expect(columns[0].programs.map((p) => p.title), ['親番組']);
    expect(columns[1].programs.map((p) => p.title), ['サブ番組']);
  });

  test('物理チャンネルが空の行はまとめない', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(
          serviceId: 101,
          remoteId: '1',
          name: 'A局',
          sortOrder: 0,
          tunerChannel: '',
        ),
        _channel(
          serviceId: 102,
          remoteId: '2',
          name: 'B局',
          sortOrder: 1,
          tunerChannel: '',
        ),
      ],
      programs: [
        _program(
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
        ),
        _program(
          serviceId: 102,
          eventId: 11,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
        ),
      ],
      baseUrl: _baseUrl,
    );

    expect(columns.map((c) => c.channel.name), ['A局', 'B局']);
  });

  test('種別が違うとまとめない', () {
    final columns = buildMirakurunTimetableColumns(
      channels: [
        _channel(serviceId: 101, remoteId: '1', name: '地デジ局', sortOrder: 0),
        _channel(
          serviceId: 201,
          remoteId: '2',
          name: 'BS局',
          sortOrder: 1,
          channelType: 'BS',
        ),
      ],
      programs: [
        _program(
          serviceId: 101,
          eventId: 11,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
        ),
        _program(
          serviceId: 201,
          eventId: 11,
          startAtMs: nowMs,
          endAtMs: nowMs + _hourMs,
        ),
      ],
      baseUrl: _baseUrl,
    );

    expect(columns.map((c) => c.channel.name), ['地デジ局', 'BS局']);
  });
}
