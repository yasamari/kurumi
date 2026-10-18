import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/data/backends/mirakurun/mirakurun_epg_channel_item.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_epg_mapping.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_program_dto.dart';
import 'package:kurumi/src/data/backends/mirakurun/mirakurun_service_dto.dart';
import 'package:kurumi/src/data/epg/epg_dao.dart';
import 'package:kurumi/src/data/epg/epg_database.dart';
import 'package:kurumi/src/domain/entities/channel_type.dart';

const _baseUrl = 'http://example.test:40772';
const _hourMs = 3600 * 1000;

void main() {
  group('epgChannelFromService', () {
    test('表示用に正規化される', () {
      final companion = epgChannelFromService(
        MirakurunServiceDto(
          id: 32736,
          serviceId: 101,
          networkId: 1,
          name: 'Ａ局',
          remoteControlKeyId: 1,
          hasLogoData: true,
          channel: MirakurunChannelDto(type: 'GR', channel: '27'),
        ),
        sortOrder: 3,
      );
      expect(companion.sourceBackend.value, 'mirakurun');
      expect(companion.remoteId.value, '32736');
      expect(companion.name.value, 'A局');
      expect(companion.channelType.value, 'GR');
      expect(companion.channelNumber.value, '001');
      expect(companion.tunerChannel.value, '27');
      expect(companion.hasLogo.value, isTrue);
      expect(companion.sortOrder.value, 3);
    });

    test('欠落値は空・偽で埋める', () {
      final companion = epgChannelFromService(
        const MirakurunServiceDto(
          id: 1,
          serviceId: 102,
          networkId: 1,
          name: 'B局',
        ),
        sortOrder: 0,
      );
      expect(companion.channelNumber.value, '');
      expect(companion.tunerChannel.value, '');
      expect(companion.channelType.value, '');
      expect(companion.hasLogo.value, isFalse);
    });
  });

  group('epgProgramFromDto', () {
    test('終了時刻・表示文言・JSONが組み立てられる', () {
      const startAt = 1000000000000;
      final companion = epgProgramFromDto(
        MirakurunProgramDto(
          id: 1,
          eventId: 1001,
          serviceId: 101,
          networkId: 1,
          startAt: startAt,
          duration: 2 * _hourMs,
          name: 'ＴＥＳＴ番組！',
          description: '概要〜詳細',
          genres: const [],
          extended: const {'出演者': 'ＡＢＣ'},
        ),
      );
      expect(companion.eventId.value, 1001);
      expect(companion.startAtMs.value, startAt);
      expect(companion.endAtMs.value, startAt + 2 * _hourMs);
      expect(companion.title.value, 'TEST番組！');
      expect(companion.description.value, '概要～詳細');
      expect(jsonDecode(companion.genresJson.value), isA<List<dynamic>>());
      expect(jsonDecode(companion.detailJson.value), {'出演者': 'ABC'});
    });
  });

  group('channelItemFromEpgRow', () {
    EpgNowOnAirRow row() {
      return const EpgNowOnAirRow(
        networkId: 1,
        serviceId: 101,
        remoteId: '32736',
        name: 'A局',
        channelType: 'GR',
        channelNumber: '011',
        hasLogo: true,
        present: EpgNowOnAirProgram(
          eventId: 1001,
          startAtMs: 1000000000000,
          endAtMs: 1000000000000 + _hourMs,
          title: '今',
          description: '概要',
          genresJson: '["ニュース・報道"]',
          detailJson: '{"出演者":"誰か"}',
        ),
        next: null,
      );
    }

    test('ChannelItem に組み立てられる', () {
      final item = channelItemFromEpgRow(row(), baseUrl: _baseUrl);
      expect(item.channel.id, '32736');
      expect(item.channel.name, 'A局');
      expect(item.channel.channelType, const ChannelType.gr());
      expect(item.channel.networkId, 1);
      expect(item.channel.serviceId, 101);
      expect(item.channel.channelNumber, '011');
      expect(item.channel.logoUrl, '$_baseUrl/api/services/32736/logo');
      expect(item.nowOnAir?.eventId, 1001);
      expect(item.nowOnAir?.title, '今');
      expect(item.nowOnAir?.genres, ['ニュース・報道']);
      expect(item.nowOnAir?.detail, {'出演者': '誰か'});
      expect(item.nextUp, isNull);
    });

    test('ロゴなしなら logoUrl は null', () {
      final item = channelItemFromEpgRow(
        const EpgNowOnAirRow(
          networkId: 1,
          serviceId: 101,
          remoteId: '1',
          name: 'A局',
          channelType: 'GR',
          channelNumber: '',
          hasLogo: false,
          present: null,
          next: null,
        ),
        baseUrl: _baseUrl,
      );
      expect(item.channel.logoUrl, isNull);
      expect(item.nowOnAir, isNull);
    });
  });

  group('channelFromEpgChannelRow', () {
    test('視聴解決用 Channel に組み立てられる', () {
      final channel = channelFromEpgChannelRow(
        EpgChannel(
          sourceBackend: 'mirakurun',
          networkId: 1,
          serviceId: 101,
          remoteId: '32736',
          name: 'A局',
          channelType: 'BS',
          channelNumber: '',
          tunerChannel: '211',
          hasLogo: false,
          sortOrder: 5,
        ),
        baseUrl: _baseUrl,
      );
      expect(channel.id, '32736');
      expect(channel.channelType, const ChannelType.bs());
      expect(channel.networkId, 1);
      expect(channel.serviceId, 101);
      expect(channel.logoUrl, isNull);
    });
  });
}
