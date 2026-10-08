import '../../../domain/entities/channel.dart';
import '../../../domain/entities/channel_type.dart';
import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';
import 'konomi_dtos.dart';
import 'konomi_filter.dart';
import 'konomi_timetable_dtos.dart';

/// `GET /api/programs/timetable` のレスポンスから番組表の列を組み立てる純粋関数。
///
/// 仕様:
/// - サブチャンネルは親チャンネルの直後に列として展開する
/// - `channels` (`GET /api/channels`) で `is_display` が false のチャンネルは
///   除外する。番組表API側に表示可否の情報が無いための突合で、不明な
///   チャンネル (突合不能) は残す
/// - 出力順は番組表APIの応答順 (種別・配列順) を維持する
/// - `[startMs, endMs)` と重ならない番組は落とす。範囲内判定のためだけに
///   使い、番組自体の時刻は変えない (表示時のクランプはレイアウト側で行う)
/// - 番組は開始時刻順に並べ直す
List<TimetableChannel> buildKonomiTimetableColumns({
  required KonomiTimetableResponse timetable,
  required KonomiChannelsResponse channels,
  required String baseUrl,
  required int startMs,
  required int endMs,
}) {
  final displayById = <String, bool>{
    for (final channel in channels.allInOrder)
      channel.displayChannelId: channel.isDisplay,
  };
  final columns = <TimetableChannel>[];
  for (final entry in timetable.channels) {
    _appendColumn(
      columns,
      info: entry.channel,
      programs: entry.programs,
      displayById: displayById,
      baseUrl: baseUrl,
      startMs: startMs,
      endMs: endMs,
    );
    for (final sub in entry.subchannels ?? const []) {
      _appendColumn(
        columns,
        info: sub.channel,
        programs: sub.programs,
        displayById: displayById,
        baseUrl: baseUrl,
        startMs: startMs,
        endMs: endMs,
      );
    }
  }
  return columns;
}

void _appendColumn(
  List<TimetableChannel> columns, {
  required KonomiTimetableChannelInfoDto info,
  required List<KonomiTimetableProgramDto> programs,
  required Map<String, bool> displayById,
  required String baseUrl,
  required int startMs,
  required int endMs,
}) {
  // 明示的に非表示のチャンネルだけ落とす。不明なIDは残す。
  if (displayById[info.displayChannelId] == false) return;
  final ranged = [
    for (final program in programs)
      if (_overlaps(program, startMs: startMs, endMs: endMs))
        _toTvProgram(program),
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  columns.add(
    TimetableChannel(
      channel: Channel(
        id: info.displayChannelId,
        name: info.name,
        channelType: channelTypeFromString(info.type),
        networkId: info.networkId,
        serviceId: info.serviceId,
        channelNumber: info.channelNumber ?? '',
        logoUrl: '$baseUrl/api/channels/${info.displayChannelId}/logo',
      ),
      programs: ranged,
    ),
  );
}

/// 番組が `[startMs, endMs)` と重なるかどうか。
bool _overlaps(
  KonomiTimetableProgramDto program, {
  required int startMs,
  required int endMs,
}) {
  final start = program.startTime.millisecondsSinceEpoch;
  final end = program.endTime.millisecondsSinceEpoch;
  return start < endMs && end > startMs;
}

TvProgram _toTvProgram(KonomiTimetableProgramDto dto) {
  return TvProgram(
    eventId: dto.eventId,
    title: dto.title,
    description: dto.description,
    startAt: dto.startTime,
    endAt: dto.endTime,
    genres: konomiGenreLabels(dto.genres),
    detail: Map<String, String>.of(dto.detail),
  );
}
