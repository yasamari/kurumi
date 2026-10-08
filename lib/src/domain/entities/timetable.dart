import 'package:freezed_annotation/freezed_annotation.dart';

import 'channel.dart';
import 'tv_program.dart';

part 'timetable.freezed.dart';

/// 番組表のチャンネル1列分。チャンネル + 期間内の番組列。
@freezed
abstract class TimetableChannel with _$TimetableChannel {
  const factory TimetableChannel({
    required Channel channel,
    @Default([]) List<TvProgram> programs,
  }) = _TimetableChannel;
}

/// 番組表1日分。`startMs` (含む) 〜 `endMs` (含まない) の期間を表す。
@freezed
abstract class TimetableData with _$TimetableData {
  const factory TimetableData({
    required int startMs,
    required int endMs,
    @Default([]) List<TimetableChannel> channels,
  }) = _TimetableData;
}
