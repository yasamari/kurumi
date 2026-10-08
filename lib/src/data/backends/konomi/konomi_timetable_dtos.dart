import 'package:json_annotation/json_annotation.dart';

import 'konomi_dtos.dart';
import 'konomi_time.dart';

part 'konomi_timetable_dtos.g.dart';

/// `GET /api/programs/timetable` の番組1件。
///
/// 使うフィールドだけ定義し、未知フィールドは読み捨てる。ジャンル・詳細の
/// 形式は `/api/channels` の番組と同一。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiTimetableProgramDto {
  const KonomiTimetableProgramDto({
    required this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.genres = const [],
    this.detail = const {},
  });

  factory KonomiTimetableProgramDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiTimetableProgramDtoFromJson(json);

  final int eventId;
  final String title;
  final String description;
  @JsonKey(fromJson: parseKonomiDateTime)
  final DateTime startTime;
  @JsonKey(fromJson: parseKonomiDateTime)
  final DateTime endTime;
  final List<KonomiGenreDto> genres;
  final Map<String, String> detail;

  Map<String, dynamic> toJson() => _$KonomiTimetableProgramDtoToJson(this);
}

/// `GET /api/programs/timetable` 配下のチャンネル情報。
///
/// `/api/channels` のチャンネルと異なり `is_display` を持たないため、
/// 表示可否の判定はチャンネル一覧側で行う。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiTimetableChannelInfoDto {
  const KonomiTimetableChannelInfoDto({
    required this.displayChannelId,
    required this.networkId,
    required this.serviceId,
    required this.type,
    required this.name,
    this.remoconId,
    this.channelNumber,
  });

  factory KonomiTimetableChannelInfoDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiTimetableChannelInfoDtoFromJson(json);

  final String displayChannelId;
  final int networkId;
  final int serviceId;
  final String type;
  final String name;
  final int? remoconId;
  final String? channelNumber;

  Map<String, dynamic> toJson() => _$KonomiTimetableChannelInfoDtoToJson(this);
}

/// `GET /api/programs/timetable` のチャンネル1件 (番組列付き)。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiTimetableChannelDto {
  const KonomiTimetableChannelDto({
    required this.channel,
    this.programs = const [],
    this.subchannels,
  });

  factory KonomiTimetableChannelDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiTimetableChannelDtoFromJson(json);

  final KonomiTimetableChannelInfoDto channel;
  final List<KonomiTimetableProgramDto> programs;
  final List<KonomiTimetableSubchannelDto>? subchannels;

  Map<String, dynamic> toJson() => _$KonomiTimetableChannelDtoToJson(this);
}

/// `GET /api/programs/timetable` のサブチャンネル1件 (番組列付き)。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiTimetableSubchannelDto {
  const KonomiTimetableSubchannelDto({
    required this.channel,
    this.programs = const [],
  });

  factory KonomiTimetableSubchannelDto.fromJson(Map<String, dynamic> json) =>
      _$KonomiTimetableSubchannelDtoFromJson(json);

  final KonomiTimetableChannelInfoDto channel;
  final List<KonomiTimetableProgramDto> programs;

  Map<String, dynamic> toJson() => _$KonomiTimetableSubchannelDtoToJson(this);
}

/// `GET /api/programs/timetable` のレスポンス。
@JsonSerializable(fieldRename: FieldRename.snake)
class KonomiTimetableResponse {
  const KonomiTimetableResponse({this.channels = const []});

  factory KonomiTimetableResponse.fromJson(Map<String, dynamic> json) =>
      _$KonomiTimetableResponseFromJson(json);

  final List<KonomiTimetableChannelDto> channels;

  Map<String, dynamic> toJson() => _$KonomiTimetableResponseToJson(this);
}
