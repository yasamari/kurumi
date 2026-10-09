import 'dart:convert';

import '../../../domain/entities/timetable.dart';
import '../../../domain/entities/tv_program.dart';
import '../../epg/epg_database.dart';
import 'mirakurun_epg_channel_item.dart';
import 'mirakurun_filter.dart';

/// EPGキャッシュのチャンネル・番組行から番組表の列を組み立てる純粋関数。
///
/// 仕様:
/// - 出力順は取得APIの応答順 (`sortOrder` 順) を維持する
/// - 期間内に番組が無いチャンネルも空列として残す (番組表は全列表示が前提。
///   ただし分岐で列を分けたときの空列は落とす)
/// - 番組は開始時刻順に並べ直す (DB側も同順だがここで保証する)
/// - ロゴURLは保存せず、読み出し時の `baseUrl` から組み立てる
/// - 兄弟サービス (サブチャンネル) はテレビ欄と同じ考え
///   ([isMirakurunSiblingService]: 同一種別・同一ネットワークで同名または
///   同一物理チャンネル) で1つに束ねる。時間が重なり同じ `eventId` の番組は
///   同時放送として重複排除し、先勝のチャンネル名・ロゴを使う。時間が重なる
///   別番組 (マルチ編成の分岐など) が1件でもあればまとめず列を分ける
///   (その瞬間のテレビ欄が2行出すのと同じ)
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

  // 兄弟同士を束ねる。同名または同一物理チャンネルで推移的に束ねる
  // (AとBが同名・BとCが同物理チャンネルの場合3つとも1束)。
  // 行数は数十件程度のため全ペア走査する。
  final parent = List<int>.generate(channels.length, (i) => i);
  int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
  void union(int a, int b) {
    parent[find(a)] = find(b);
  }

  bool isSibling(EpgChannel a, EpgChannel b) {
    return isMirakurunSiblingService(
      channelType: a.channelType,
      networkId: a.networkId,
      name: a.name,
      tunerChannel: a.tunerChannel,
      otherChannelType: b.channelType,
      otherNetworkId: b.networkId,
      otherName: b.name,
      otherTunerChannel: b.tunerChannel,
    );
  }

  for (var i = 0; i < channels.length; i++) {
    for (var j = i + 1; j < channels.length; j++) {
      if (isSibling(channels[i], channels[j])) union(i, j);
    }
  }
  final groups = <List<EpgChannel>>[];
  final indexByRoot = <int, int>{};
  for (var i = 0; i < channels.length; i++) {
    final root = find(i);
    final index = indexByRoot[root];
    if (index == null) {
      indexByRoot[root] = groups.length;
      groups.add([channels[i]]);
    } else {
      groups[index].add(channels[i]);
    }
  }
  return [
    for (final group in groups)
      ..._mergeGroup(group, programsOf, baseUrl: baseUrl),
  ];
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
  // 番組の無い行は落とす (空列を並べないため)。
  if (conflict) {
    return [
      for (final channel in group)
        if (programsOf(channel).isNotEmpty) columnOf(channel),
    ];
  }
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
