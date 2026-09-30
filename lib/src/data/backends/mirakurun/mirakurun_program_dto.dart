import 'package:json_annotation/json_annotation.dart';

part 'mirakurun_program_dto.g.dart';

/// `GET /api/programs` の1要素。
///
/// `startAt` は UNIX時間(ms)、`duration` はミリ秒。
/// `genres` は ARIB ジャンルコード、`extended` は番組詳細 (キー→説明文)。
@JsonSerializable()
class MirakurunProgramDto {
  const MirakurunProgramDto({
    required this.id,
    required this.eventId,
    required this.serviceId,
    required this.networkId,
    required this.startAt,
    required this.duration,
    this.name,
    this.description,
    this.genres = const [],
    this.extended = const {},
  });

  factory MirakurunProgramDto.fromJson(Map<String, dynamic> json) =>
      _$MirakurunProgramDtoFromJson(json);

  final int id;
  final int eventId;
  final int serviceId;
  final int networkId;
  final int startAt;
  final int duration;
  final String? name;
  final String? description;
  final List<MirakurunProgramGenreDto> genres;

  /// 番組詳細。値は文字列とは限らないため dynamic 受けし、filter で文字列化する。
  final Map<String, dynamic> extended;

  Map<String, dynamic> toJson() => _$MirakurunProgramDtoToJson(this);
}

/// `Program.genres` の1要素 (ARIB ジャンルコード)。
@JsonSerializable()
class MirakurunProgramGenreDto {
  const MirakurunProgramGenreDto({this.lv1, this.lv2});

  factory MirakurunProgramGenreDto.fromJson(Map<String, dynamic> json) =>
      _$MirakurunProgramGenreDtoFromJson(json);

  final int? lv1;
  final int? lv2;

  Map<String, dynamic> toJson() => _$MirakurunProgramGenreDtoToJson(this);
}
