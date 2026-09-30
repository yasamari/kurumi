import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_filter.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_genre.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_program_dto.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_service_dto.dart';

const _baseUrl = 'http://example.test:40772';

MirakurunServiceDto _service({
  required int id,
  required int serviceId,
  required int networkId,
  required String name,
  int? remoteControlKeyId,
  String channelType = 'GR',
  String channel = '27',
}) {
  return MirakurunServiceDto(
    id: id,
    serviceId: serviceId,
    networkId: networkId,
    name: name,
    remoteControlKeyId: remoteControlKeyId,
    hasLogoData: true,
    channel: MirakurunChannelDto(type: channelType, channel: channel),
  );
}

MirakurunProgramDto _program({
  required int eventId,
  required int serviceId,
  required int networkId,
  required int startAt,
  required int duration,
  String name = '番組',
}) {
  return MirakurunProgramDto(
    id: networkId * 100000 + serviceId,
    eventId: eventId,
    serviceId: serviceId,
    networkId: networkId,
    startAt: startAt,
    duration: duration,
    name: name,
    description: '概要',
  );
}

void main() {
  final now = DateTime(2026, 9, 29, 10, 30);
  final nowMs = now.millisecondsSinceEpoch;
  const hourMs = 3600 * 1000;

  test('放送中のサービスだけにフィルタされる', () {
    final services = [
      _service(id: 1, serviceId: 101, networkId: 1, name: 'A局'),
      _service(id: 2, serviceId: 102, networkId: 1, name: 'B局'),
    ];
    final programs = [
      _program(
        eventId: 1001,
        serviceId: 101,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
      ),
      // B局は放送時間が未来 = 除外対象
      _program(
        eventId: 1002,
        serviceId: 102,
        networkId: 1,
        startAt: nowMs + hourMs,
        duration: hourMs,
      ),
    ];

    final items = buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: now,
      baseUrl: _baseUrl,
    );

    expect(items.length, 1);
    expect(items.single.channel.name, 'A局');
    expect(items.single.nowOnAir, isNotNull);
  });

  test('同じチャンネルかつ同じeventIdは1つにまとまる', () {
    final services = [
      _service(id: 10, serviceId: 101, networkId: 1, name: '親局'),
      _service(id: 11, serviceId: 102, networkId: 1, name: 'サブ'),
    ];
    final programs = [
      _program(
        eventId: 2001,
        serviceId: 101,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
      ),
      _program(
        eventId: 2001,
        serviceId: 102,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
      ),
    ];

    final items = buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: now,
      baseUrl: _baseUrl,
    );

    // 先勝 (services順の最初) のみ残る
    expect(items.length, 1);
    expect(items.single.channel.name, '親局');
  });

  test('同じチャンネルでもeventIdが違えばまとめない', () {
    final services = [
      _service(id: 10, serviceId: 101, networkId: 1, name: '親局'),
      _service(id: 11, serviceId: 102, networkId: 1, name: 'サブ'),
    ];
    final programs = [
      _program(
        eventId: 2001,
        serviceId: 101,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
      ),
      _program(
        eventId: 2002,
        serviceId: 102,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
      ),
    ];

    final items = buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: now,
      baseUrl: _baseUrl,
    );

    expect(items.length, 2);
  });

  test('servicesの順番を維持し、次番組を拾う', () {
    final services = [
      _service(
        id: 3,
        serviceId: 103,
        networkId: 1,
        name: 'C局',
        remoteControlKeyId: 3,
      ),
      _service(
        id: 1,
        serviceId: 101,
        networkId: 1,
        name: 'A局',
        remoteControlKeyId: 1,
      ),
    ];
    final programs = [
      _program(
        eventId: 3001,
        serviceId: 103,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
        name: '今',
      ),
      _program(
        eventId: 3002,
        serviceId: 103,
        networkId: 1,
        startAt: nowMs + hourMs,
        duration: hourMs,
        name: '次',
      ),
      _program(
        eventId: 1001,
        serviceId: 101,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
      ),
    ];

    final items = buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: now,
      baseUrl: _baseUrl,
    );

    expect(items.map((e) => e.channel.name).toList(), ['C局', 'A局']);
    expect(items.first.nextUp?.title, '次');
  });

  test('ジャンルコードを表示用ラベルに変換する', () {
    // 大分類のみの場合は大分類名。
    expect(mirakurunGenreLabel(0), 'ニュース・報道');
    expect(mirakurunGenreLabel(7), 'アニメ・特撮');
    expect(mirakurunGenreLabel(15), 'その他');
    expect(mirakurunGenreLabel(12), isNull);
    expect(mirakurunGenreLabel(null), isNull);
    // 中分類まで判明している場合は `大分類・中分類`。
    expect(mirakurunGenreLabel(3, 0), 'ドラマ・国内ドラマ');
    expect(mirakurunGenreLabel(7, 0), 'アニメ・特撮・国内アニメ');
    expect(mirakurunGenreLabel(3, 0xE), 'ドラマ');

    final labels = mirakurunGenreLabels(const [
      MirakurunProgramGenreDto(lv1: 3, lv2: 0),
      MirakurunProgramGenreDto(lv1: 3, lv2: 0),
      MirakurunProgramGenreDto(lv1: 12),
    ]);
    expect(labels, ['ドラマ・国内ドラマ']);
  });

  test('ジャンル・詳細が番組に引き継がれる', () {
    final services = [
      _service(id: 1, serviceId: 101, networkId: 1, name: 'A局'),
    ];
    final programs = [
      MirakurunProgramDto(
        id: 101,
        eventId: 1001,
        serviceId: 101,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
        name: '今',
        description: '概要',
        genres: const [
          MirakurunProgramGenreDto(lv1: 1, lv2: 1),
        ],
        extended: const {'出演者': 'テスト太郎'},
      ),
    ];

    final items = buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: now,
      baseUrl: _baseUrl,
    );

    expect(items.single.nowOnAir?.genres, ['スポーツ・野球']);
    expect(items.single.nowOnAir?.detail, {'出演者': 'テスト太郎'});
  });

  test('タイトル・概要・詳細はKonomiTV形式に正規化される', () {
    final services = [
      _service(id: 1, serviceId: 101, networkId: 1, name: 'Ａ局'),
    ];
    final programs = [
      MirakurunProgramDto(
        id: 101,
        eventId: 1001,
        serviceId: 101,
        networkId: 1,
        startAt: nowMs - hourMs,
        duration: 2 * hourMs,
        name: 'ＴＥＳＴ番組！',
        description: '概要〜詳細',
        extended: const {'出演者': 'ＡＢＣ'},
      ),
    ];

    final items = buildMirakurunChannelItems(
      services: services,
      programs: programs,
      now: now,
      baseUrl: _baseUrl,
    );

    expect(items.single.channel.name, 'A局');
    expect(items.single.nowOnAir?.title, 'TEST番組！');
    expect(items.single.nowOnAir?.description, '概要～詳細');
    expect(items.single.nowOnAir?.detail, {'出演者': 'ABC'});
  });
}
