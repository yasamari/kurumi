import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_dtos.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_filter.dart';

const _baseUrl = 'http://example.test:7000';

KonomiProgramDto _program({required int eventId, required String title}) {
  return KonomiProgramDto(
    eventId: eventId,
    title: title,
    description: '概要',
    startTime: DateTime(2026, 9, 29, 10, 5),
    endTime: DateTime(2026, 9, 29, 10, 55),
  );
}

KonomiChannelDto _channel({
  required String displayId,
  required String name,
  bool isDisplay = true,
  KonomiProgramDto? present,
  KonomiProgramDto? following,
}) {
  return KonomiChannelDto(
    id: 'NID1-SID1',
    displayChannelId: displayId,
    networkId: 1,
    serviceId: 1,
    type: 'GR',
    name: name,
    isDisplay: isDisplay,
    channelNumber: '011',
    programPresent: present,
    programFollowing: following,
  );
}

void main() {
  test('is_display=false を除外し、番組なしチャンネルは残す', () {
    final response = KonomiChannelsResponse(
      gr: [
        _channel(
          displayId: 'gr011',
          name: 'A局',
          present: _program(eventId: 1, title: '今'),
          following: _program(eventId: 2, title: '次'),
        ),
        _channel(
          displayId: 'gr012',
          name: '非表示局',
          isDisplay: false,
          present: _program(eventId: 3, title: '裏'),
        ),
        _channel(displayId: 'gr013', name: '番組なし局'),
      ],
    );

    final items = buildKonomiChannelItems(
      response: response,
      baseUrl: _baseUrl,
    );

    expect(items.length, 2);
    expect(items[0].channel.name, 'A局');
    expect(items[0].nowOnAir?.title, '今');
    expect(items[0].nextUp?.title, '次');
    expect(
      items[0].channel.logoUrl,
      '$_baseUrl/api/channels/gr011/logo',
    );
    expect(items[1].channel.name, '番組なし局');
    expect(items[1].nowOnAir, isNull);
    expect(items[1].nextUp, isNull);
  });

  test('種別順 (GR→BS) と配列順を維持する', () {
    final response = KonomiChannelsResponse(
      gr: [
        _channel(
          displayId: 'gr012',
          name: 'B局',
          present: _program(eventId: 1, title: '今B'),
        ),
        _channel(
          displayId: 'gr011',
          name: 'A局',
          present: _program(eventId: 2, title: '今A'),
        ),
      ],
      bs: [
        _channel(
          displayId: 'bs101',
          name: 'BS局',
          present: _program(eventId: 3, title: '今BS'),
        ),
      ],
    );

    final items = buildKonomiChannelItems(
      response: response,
      baseUrl: _baseUrl,
    );

    expect(
      items.map((e) => e.channel.name).toList(),
      ['B局', 'A局', 'BS局'],
    );
  });

  test('ジャンルを表示用ラベルに変換する', () {
    final labels = konomiGenreLabels(const [
      KonomiGenreDto(major: 'ドラマ', middle: '国内ドラマ'),
      KonomiGenreDto(major: 'ドラマ', middle: '国内ドラマ'),
      KonomiGenreDto(major: 'ニュース', middle: 'ニュース'),
      KonomiGenreDto(major: 'スポーツ', middle: ''),
    ]);
    expect(labels, ['ドラマ・国内ドラマ', 'ニュース', 'スポーツ']);
  });

  test('ジャンル・詳細が番組に引き継がれる', () {
    final response = KonomiChannelsResponse(
      gr: [
        KonomiChannelDto(
          id: 'NID1-SID1',
          displayChannelId: 'gr011',
          networkId: 1,
          serviceId: 1,
          type: 'GR',
          name: 'A局',
          isDisplay: true,
          channelNumber: '011',
          programPresent: KonomiProgramDto(
            eventId: 1,
            title: '今',
            description: '概要',
            startTime: DateTime(2026, 9, 29, 10, 5),
            endTime: DateTime(2026, 9, 29, 10, 55),
            genres: const [
              KonomiGenreDto(major: 'アニメ', middle: 'アニメ'),
            ],
            detail: const {'出演者': 'テスト太郎'},
          ),
        ),
      ],
    );

    final items = buildKonomiChannelItems(
      response: response,
      baseUrl: _baseUrl,
    );

    expect(items.single.nowOnAir?.genres, ['アニメ']);
    expect(items.single.nowOnAir?.detail, {'出演者': 'テスト太郎'});
  });
}
