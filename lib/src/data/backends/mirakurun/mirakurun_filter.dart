import '../../../core/utils/program_text.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_item.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/tv_program.dart';
import 'mirakurun_genre.dart';
import 'mirakurun_program_dto.dart';
import 'mirakurun_service_dto.dart';

/// Mirakurunのサービス+番組一覧から表示用 [ChannelItem] を組み立てる純粋関数。

/// 兄弟サービス (同じ放送のサブチャンネル) かどうかを判定する純粋関数。
///
/// Mirakurun の `service.channel.channel` (物理チャンネル文字) はサーバー
/// 設定依存で、BS の Service形式スキャン (`BS15_1` のような `BSxx_N` 形式)
/// では兄弟サービスごとに異なる文字列になるため、物理チャンネルの一致
/// だけでは兄弟を束ねられない (BS-TBS の 161/162/163 など)。同名サービス
/// も兄弟とみなす。`networkId` で別ネットワーク (BS とCATV再送信など) の
/// 同名局や、別地域の同物理チャンネルを区別する。
///
/// テレビ欄SQL (`EpgDao.nowOnAir`)・番組表 (`buildMirakurunTimetableColumns`)
/// と同じ規則を使うこと。
bool isMirakurunSiblingService({
  required String channelType,
  required int networkId,
  required String name,
  required String tunerChannel,
  required String otherChannelType,
  required int otherNetworkId,
  required String otherName,
  required String otherTunerChannel,
}) {
  if (channelType != otherChannelType || networkId != otherNetworkId) {
    return false;
  }
  if (name.isNotEmpty && name == otherName) return true;
  if (tunerChannel.isNotEmpty && tunerChannel == otherTunerChannel) {
    return true;
  }
  return false;
}

/// 表示済みサービスの記録 (重複排除用)。
typedef _SeenService = ({
  String channelType,
  int networkId,
  String name,
  String tunerChannel,
  int eventId,
});

/// 仕様:
/// - `/api/programs` を参照し、現在放送中の番組があるサービスだけ残す
/// - 同じ放送のサービス (サブチャンネル) で同じ `eventId` は1つにまとめる
///   (同時放送対策。兄弟判定は [isMirakurunSiblingService])
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

  final seenSiblings = <_SeenService>[];
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
    // クロージャ内では昇格しないため final に受ける。
    final presentProgram = present;

    // 兄弟サービスの同じ eventId は1つにまとめる。先勝
    // (services の順序 = サーバーのチャンネル順を尊重)。
    final channel = service.channel;
    final channelType = channel?.type ?? '';
    final tunerChannel = channel?.channel ?? '';
    final duplicate = seenSiblings.any(
      (seen) =>
          seen.eventId == presentProgram.eventId &&
          isMirakurunSiblingService(
            channelType: channelType,
            networkId: service.networkId,
            name: service.name,
            tunerChannel: tunerChannel,
            otherChannelType: seen.channelType,
            otherNetworkId: seen.networkId,
            otherName: seen.name,
            otherTunerChannel: seen.tunerChannel,
          ),
    );
    if (duplicate) continue;
    seenSiblings.add((
      channelType: channelType,
      networkId: service.networkId,
      name: service.name,
      tunerChannel: tunerChannel,
      eventId: present.eventId,
    ));

    items.add(
      ChannelItem(
        channel: Channel(
          id: service.id.toString(),
          // Mirakurun の生文字列は KonomiTV 形式に正規化して表示する。
          name: formatProgramText(service.name),
          channelType: channelTypeFromString(channel?.type),
          networkId: service.networkId,
          serviceId: service.serviceId,
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
    title: formatProgramText(dto.name ?? ''),
    description: formatProgramText(dto.description ?? ''),
    startAt: startAt,
    endAt: startAt.add(Duration(milliseconds: dto.duration)),
    genres: mirakurunGenreLabels(dto.genres),
    detail: mirakurunDetailStrings(dto.extended),
  );
}

/// Mirakurun の `extended` (番組詳細) を表示用の文字列マップに変換する。
///
/// 値は文字列とは限らないため文字列化し、キー・値とも KonomiTV 形式に
/// 正規化する。空文字は除く。
Map<String, String> mirakurunDetailStrings(Map<String, dynamic> extended) {
  final detail = <String, String>{};
  for (final entry in extended.entries) {
    final value = entry.value;
    if (value == null) continue;
    final text = value is String ? value : value.toString();
    if (text.isEmpty) continue;
    detail[formatProgramText(entry.key)] = formatProgramText(text);
  }
  return detail;
}
