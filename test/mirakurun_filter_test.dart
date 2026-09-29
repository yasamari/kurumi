import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_filter.dart';
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
}
