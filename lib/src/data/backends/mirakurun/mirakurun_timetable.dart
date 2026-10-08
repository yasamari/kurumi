import 'dart:convert';

import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';
import '../../epg/epg_database.dart';
import 'mirakurun_epg_channel_item.dart';

/// EPGキャッシュのチャンネル・番組行から番組表の列を組み立てる純粋関数。
///
/// 仕様:
/// - 出力順は取得APIの応答順 (`sortOrder` 順) を維持する
/// - 期間内に番組が無いチャンネルも空列として残す (番組表は全列表示が前提)
/// - 番組は開始時刻順に並べ直す (DB側も同順だがここで保証する)
/// - ロゴURLは保存せず、読み出し時の `baseUrl` から組み立てる
/// - 同一種別・物理チャンネルのサービス (サブチャンネル) はテレビ欄
///   (`EpgDao.nowOnAir` の重複排除) と同じ考えで1列にまとめる。時間が重なり
///   同じ `eventId` の番組は同時放送として重複排除し、先勝のチャンネル名・
///   ロゴを使う。時間が重なる別番組 (マルチ編成の分岐など) が1件でもあれば
///   まとめず列を分ける (その瞬間のテレビ欄が2行出すのと同じ)
List<TimetableChannel> buildMirakurunTimetableColumns({
  required List<EpgChannel> channels,
  required List<EpgProgram> programs,
  required String baseUrl,
}) {
  final byService = <String, List<EpgProgram>>{};
  for (final program in programs) {
    final key = '${program.networkId}:${program.serviceId}';
    (byService[key] ??= []).add(program);
  }
  List<TvProgram> programsOf(EpgChannel channel) {
    final list = [
      for (final program
          in byService['${channel.networkId}:${channel.serviceId}'] ??
              const <EpgProgram>[])
        _toTvProgram(program),
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    return list;
  }

  // 同一種別・物理チャンネルで束ねる。物理チャンネルが空の行は束ねない
  // (無関係なチャンネル同士をまとめてしまうため)。
  final groups = <List<EpgChannel>>[];
  final indexByKey = <String, int>{};
  for (final channel in channels) {
    final key = _siblingKey(channel);
    if (key == null) {
      groups.add([channel]);
      continue;
    }
    final index = indexByKey[key];
    if (index == null) {
      indexByKey[key] = groups.length;
      groups.add([channel]);
    } else {
      groups[index].add(channel);
    }
  }
  return [
    for (final group in groups)
      ..._mergeGroup(group, programsOf, baseUrl: baseUrl),
  ];
}

/// まとめキー。束ねない行は null。
String? _siblingKey(EpgChannel channel) {
  if (channel.tunerChannel.isEmpty) return null;
  return '${channel.channelType}\x1f${channel.tunerChannel}';
}

/// 1グループを1列か複数列に展開する。
List<TimetableChannel> _mergeGroup(
  List<EpgChannel> group,
  List<TvProgram> Function(EpgChannel channel) programsOf, {
  required String baseUrl,
}) {
  TimetableChannel columnOf(EpgChannel channel) => TimetableChannel(
    channel: channelFromEpgChannelRow(channel, baseUrl: baseUrl),
    programs: programsOf(channel),
  );
  if (group.length == 1) return [columnOf(group.first)];

  final merged = <TvProgram>[...programsOf(group.first)];
  var conflict = false;
  for (final sibling in group.skip(1)) {
    for (final program in programsOf(sibling)) {
      if (_isDuplicate(merged, program)) continue;
      if (_overlapsAny(merged, program)) {
        conflict = true;
        break;
      }
      merged.add(program);
    }
    if (conflict) break;
  }
  // 別番組の重なりがあればまとめず、列を分ける。
  if (conflict) return [for (final channel in group) columnOf(channel)];
  merged.sort((a, b) => a.startAt.compareTo(b.startAt));
  return [
    TimetableChannel(
      channel: channelFromEpgChannelRow(group.first, baseUrl: baseUrl),
      programs: merged,
    ),
  ];
}

/// 時間が重なる番組がすべて同じ `eventId` なら同時放送の重複とみなす。
///
/// 件数は1日数十件程度のため全走査する (追記で未ソートになり得るため
/// 開始時刻での打ち切りはしない)。
bool _isDuplicate(List<TvProgram> merged, TvProgram program) {
  final startMs = program.startAt.millisecondsSinceEpoch;
  final endMs = program.endAt.millisecondsSinceEpoch;
  var overlaps = false;
  for (final other in merged) {
    final otherStartMs = other.startAt.millisecondsSinceEpoch;
    final otherEndMs = other.endAt.millisecondsSinceEpoch;
    if (otherStartMs >= endMs || otherEndMs <= startMs) continue;
    overlaps = true;
    if (other.eventId != program.eventId) return false;
  }
  return overlaps;
}

/// 時間が重なる番組があるかどうか。
bool _overlapsAny(List<TvProgram> merged, TvProgram program) {
  final startMs = program.startAt.millisecondsSinceEpoch;
  final endMs = program.endAt.millisecondsSinceEpoch;
  for (final other in merged) {
    final otherStartMs = other.startAt.millisecondsSinceEpoch;
    final otherEndMs = other.endAt.millisecondsSinceEpoch;
    if (otherStartMs < endMs && otherEndMs > startMs) return true;
  }
  return false;
}

TvProgram _toTvProgram(EpgProgram program) {
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
