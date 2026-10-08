import 'dart:convert';

import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_item.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/tv_program.dart';
import '../../epg/epg_dao.dart';
import '../../epg/epg_database.dart';

/// EPGキャッシュのチャンネル行を表示用 [Channel] に変換する純粋関数。
///
/// ロゴURLは保存せず、読み出し時の `baseUrl` から組み立てる。
Channel channelFromEpgChannelRow(
  EpgChannel row, {
  required String baseUrl,
}) {
  return Channel(
    id: row.remoteId,
    name: row.name,
    channelType: channelTypeFromString(row.channelType),
    networkId: row.networkId,
    serviceId: row.serviceId,
    channelNumber: row.channelNumber,
    logoUrl: row.hasLogo
        ? '$baseUrl/api/services/${row.remoteId}/logo'
        : null,
  );
}

/// EPGキャッシュ行を表示用 [ChannelItem] に変換する純粋関数。
///
/// ロゴURLは保存せず、読み出し時の `baseUrl` から組み立てる。
ChannelItem channelItemFromEpgRow(
  EpgNowOnAirRow row, {
  required String baseUrl,
}) {
  return ChannelItem(
    channel: Channel(
      id: row.remoteId,
      name: row.name,
      channelType: channelTypeFromString(row.channelType),
      networkId: row.networkId,
      serviceId: row.serviceId,
      channelNumber: row.channelNumber,
      logoUrl: row.hasLogo
          ? '$baseUrl/api/services/${row.remoteId}/logo'
          : null,
    ),
    nowOnAir: row.present == null ? null : _toTvProgram(row.present!),
    nextUp: row.next == null ? null : _toTvProgram(row.next!),
  );
}

TvProgram _toTvProgram(EpgNowOnAirProgram program) {
  return TvProgram(
    eventId: program.eventId,
    title: program.title,
    description: program.description,
    startAt: DateTime.fromMillisecondsSinceEpoch(program.startAtMs),
    endAt: DateTime.fromMillisecondsSinceEpoch(program.endAtMs),
    genres: (jsonDecode(program.genresJson) as List<dynamic>)
        .whereType<String>()
        .toList(),
    detail: (jsonDecode(program.detailJson) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value.toString()),
    ),
  );
}
