import 'package:flutter_test/flutter_test.dart';

import 'package:kurumi/src/data/backends/konomi/konomi_dtos.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_timetable_dtos.dart';
import 'package:kurumi/src/data/backends/konomi/konomi_timetable_filter.dart';

/// 2026-10-08 (木) 04:00 JST = 2026-10-07 19:00 UTC 始まりの1日。
int _utcMs(int y, int mo, int d, int h, [int min = 0]) =>
    DateTime.utc(y, mo, d, h, min).millisecondsSinceEpoch;

/// JST日時を番組表API形式の文字列にする。
String _jst(int mo, int d, int h, [int min = 0]) =>
    '2026-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}'
    'T${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:00+09:00';

Map<String, dynamic> _programJson({
  required int eventId,
  required String title,
  required String start,
  required String end,
  List<Map<String, String>> genres = const [],
  Map<String, String> detail = const {},
}) {
  return {
    'event_id': eventId,
    'title': title,
    'description': '$titleの概要',
    'start_time': start,
    'end_time': end,
    'genres': genres,
    'detail': detail,
  };
}

Map<String, dynamic> _channelJson({
  required String displayChannelId,
  required int serviceId,
  required String type,
  required String name,
}) {
  return {
    'display_channel_id': displayChannelId,
    'network_id': 1,
    'service_id': serviceId,
    'type': type,
    'name': name,
    'remocon_id': 1,
    'channel_number': '011',
  };
}

Map<String, dynamic> _liveChannelJson({
  required String displayChannelId,
  required String type,
  required bool isDisplay,
}) {
  return {
    'id': 'id-$displayChannelId',
    'display_channel_id': displayChannelId,
    'network_id': 1,
    'service_id': 101,
    'type': type,
    'name': displayChannelId,
    'is_display': isDisplay,
  };
}

void main() {
  final dayStartMs = _utcMs(2026, 10, 7, 19);
  final dayEndMs = dayStartMs + 24 * 3600 * 1000;

  KonomiTimetableResponse timetableOf(List<Map<String, dynamic>> channels) {
    return KonomiTimetableResponse.fromJson({'channels': channels});
  }

  KonomiChannelsResponse channelsOf(Map<String, List<Map<String, dynamic>>> byType) {
    return KonomiChannelsResponse.fromJson(byType);
  }

  test('チャンネル順を保ち番組を開始時刻順に並べる', () {
    final timetable = timetableOf([
      {
        'channel': _channelJson(
          displayChannelId: 'GR_A',
          serviceId: 101,
          type: 'GR',
          name: 'A局',
        ),
        'programs': [
          // わざと逆順で入れる。
          _programJson(
            eventId: 2,
            title: '昼番組',
            start: _jst(10, 8, 12),
            end: _jst(10, 8, 13),
          ),
          _programJson(
            eventId: 1,
            title: '朝番組',
            start: _jst(10, 8, 4),
            end: _jst(10, 8, 5),
            genres: [
              {'major': 'ニュース', 'middle': '定時・総合'},
            ],
            detail: {'出演者': '誰々'},
          ),
        ],
      },
      {
        'channel': _channelJson(
          displayChannelId: 'BS_B',
          serviceId: 201,
          type: 'BS',
          name: 'B局',
        ),
        'programs': [
          _programJson(
            eventId: 3,
            title: 'BS番組',
            start: _jst(10, 8, 6),
            end: _jst(10, 8, 7),
          ),
        ],
      },
    ]);
    final channels = channelsOf({
      'GR': [_liveChannelJson(displayChannelId: 'GR_A', type: 'GR', isDisplay: true)],
      'BS': [_liveChannelJson(displayChannelId: 'BS_B', type: 'BS', isDisplay: true)],
    });

    final columns = buildKonomiTimetableColumns(
      timetable: timetable,
      channels: channels,
      baseUrl: 'http://192.0.2.1:10000',
      startMs: dayStartMs,
      endMs: dayEndMs,
    );

    expect(columns.map((c) => c.channel.id), ['GR_A', 'BS_B']);
    expect(columns[0].programs.map((p) => p.title), ['朝番組', '昼番組']);
    expect(columns[0].programs.first.genres, ['ニュース・定時・総合']);
    expect(columns[0].programs.first.detail, {'出演者': '誰々'});
    expect(
      columns[0].channel.logoUrl,
      'http://192.0.2.1:10000/api/channels/GR_A/logo',
    );
  });

  test('非表示チャンネルは除外し不明IDは残す', () {
    final timetable = timetableOf([
      {
        'channel': _channelJson(
          displayChannelId: 'GR_HIDDEN',
          serviceId: 102,
          type: 'GR',
          name: '隠し局',
        ),
        'programs': [],
      },
      {
        'channel': _channelJson(
          displayChannelId: 'GR_UNKNOWN',
          serviceId: 103,
          type: 'GR',
          name: '不明局',
        ),
        'programs': [],
      },
    ]);
    final channels = channelsOf({
      'GR': [
        _liveChannelJson(displayChannelId: 'GR_HIDDEN', type: 'GR', isDisplay: false),
      ],
    });

    final columns = buildKonomiTimetableColumns(
      timetable: timetable,
      channels: channels,
      baseUrl: 'http://192.0.2.1:10000',
      startMs: dayStartMs,
      endMs: dayEndMs,
    );

    expect(columns.map((c) => c.channel.id), ['GR_UNKNOWN']);
  });

  test('サブチャンネルは親の直後に展開する', () {
    final timetable = timetableOf([
      {
        'channel': _channelJson(
          displayChannelId: 'GR_PARENT',
          serviceId: 101,
          type: 'GR',
          name: '親局',
        ),
        'programs': [],
        'subchannels': [
          {
            'channel': _channelJson(
              displayChannelId: 'GR_SUB',
              serviceId: 102,
              type: 'GR',
              name: 'サブ',
            ),
            'programs': [
              _programJson(
                eventId: 9,
                title: 'サブ番組',
                start: _jst(10, 8, 8),
                end: _jst(10, 8, 9),
              ),
            ],
          },
        ],
      },
    ]);
    final channels = channelsOf(const {});

    final columns = buildKonomiTimetableColumns(
      timetable: timetable,
      channels: channels,
      baseUrl: 'http://192.0.2.1:10000',
      startMs: dayStartMs,
      endMs: dayEndMs,
    );

    expect(columns.map((c) => c.channel.id), ['GR_PARENT', 'GR_SUB']);
    expect(columns[1].programs.map((p) => p.title), ['サブ番組']);
  });

  test('期間外の番組は落とし境界掛かりは時刻を変えず残す', () {
    final timetable = timetableOf([
      {
        'channel': _channelJson(
          displayChannelId: 'GR_A',
          serviceId: 101,
          type: 'GR',
          name: 'A局',
        ),
        'programs': [
          // 期間より前 (終了ちょうど)。
          _programJson(
            eventId: 1,
            title: '前',
            start: _jst(10, 8, 3),
            end: _jst(10, 8, 4),
          ),
          // 開始境界に掛かる。
          _programJson(
            eventId: 2,
            title: '跨ぎ開始',
            start: _jst(10, 8, 3, 30),
            end: _jst(10, 8, 4, 30),
          ),
          // 期間内。
          _programJson(
            eventId: 3,
            title: '昼',
            start: _jst(10, 8, 12),
            end: _jst(10, 8, 13),
          ),
          // 終了境界に掛かる (28:00=翌4:00)。
          _programJson(
            eventId: 4,
            title: '跨ぎ終了',
            start: _jst(10, 9, 3, 30),
            end: _jst(10, 9, 4, 30),
          ),
          // 期間より後 (開始ちょうど)。
          _programJson(
            eventId: 5,
            title: '後',
            start: _jst(10, 9, 4),
            end: _jst(10, 9, 5),
          ),
        ],
      },
    ]);
    final channels = channelsOf(const {});

    final columns = buildKonomiTimetableColumns(
      timetable: timetable,
      channels: channels,
      baseUrl: 'http://192.0.2.1:10000',
      startMs: dayStartMs,
      endMs: dayEndMs,
    );

    final titles = columns.single.programs.map((p) => p.title).toList();
    expect(titles, ['跨ぎ開始', '昼', '跨ぎ終了']);
    // 番組自体の時刻は変えない (クランプはレイアウト側)。
    expect(
      columns.single.programs.first.startAt.millisecondsSinceEpoch,
      lessThan(dayStartMs),
    );
  });
}
