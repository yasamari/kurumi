import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_item.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/tv_program.dart';
import 'mirakurun_program_dto.dart';
import 'mirakurun_service_dto.dart';

/// Mirakurunのサービス+番組一覧から表示用 [ChannelItem] を組み立てる純粋関数。
///
/// 仕様:
/// - `/api/programs` を参照し、現在放送中の番組があるサービスだけ残す
/// - 同じチャンネル (`channel.type` + `channel.channel`) かつ
///   同じ `eventId` のサービスは1つにまとめる (サブチャンネルの同時放送対策)
/// - 出力順は `/api/services` のレスポンス順を維持する (ソートしない)
///
/// [now] を引数化しているため単体テストしやすい。
List<ChannelItem> buildMirakurunChannelItems({
  required List<MirakurunServiceDto> services,
  required List<MirakurunProgramDto> programs,
  required DateTime now,
  required String baseUrl,
}) {
  final nowMs = now.millisecondsSinceEpoch;

  final programsByService = <String, List<MirakurunProgramDto>>{};
  for (final program in programs) {
    final key = '${program.networkId}:${program.serviceId}';
    (programsByService[key] ??= []).add(program);
  }

  final seenDedupeKeys = <String>{};
  final items = <ChannelItem>[];

  for (final service in services) {
    final candidates =
        programsByService['${service.networkId}:${service.serviceId}'] ??
            const <MirakurunProgramDto>[];

    MirakurunProgramDto? present;
    MirakurunProgramDto? next;
    for (final program in candidates) {
      final endMs = program.startAt + program.duration;
      if (program.startAt <= nowMs && nowMs < endMs) {
        present ??= program;
      } else if (program.startAt > nowMs) {
        if (next == null || program.startAt < next.startAt) {
          next = program;
        }
      }
    }

    // 放送中でないサービスは除外する。
    if (present == null) continue;

    // 同じチャンネルかつ同じ eventId は1つにまとめる。先勝
    // (services の順序 = サーバーのチャンネル順を尊重)。
    final channel = service.channel;
    final dedupeKey =
        '${channel?.type}:${channel?.channel}:${present.eventId}';
    if (!seenDedupeKeys.add(dedupeKey)) continue;

    items.add(
      ChannelItem(
        channel: Channel(
          id: service.id.toString(),
          name: service.name,
          channelType: channelTypeFromString(channel?.type),
          channelNumber: service.remoteControlKeyId != null
              ? service.remoteControlKeyId.toString().padLeft(3, '0')
              : '',
          logoUrl: service.hasLogoData == true
              ? '$baseUrl/api/services/${service.id}/logo'
              : null,
        ),
        nowOnAir: _toTvProgram(present),
        nextUp: next == null ? null : _toTvProgram(next),
      ),
    );
  }

  return items;
}

TvProgram _toTvProgram(MirakurunProgramDto dto) {
  final startAt = DateTime.fromMillisecondsSinceEpoch(dto.startAt);
  return TvProgram(
    eventId: dto.eventId,
    title: dto.name ?? '',
    description: dto.description ?? '',
    startAt: startAt,
    endAt: startAt.add(Duration(milliseconds: dto.duration)),
  );
}
